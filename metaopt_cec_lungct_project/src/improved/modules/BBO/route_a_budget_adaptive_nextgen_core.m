function [best_fitness, best_solution, Convergence_curve] = route_a_budget_adaptive_nextgen_core(N, Max_iteration, lb, ub, dim, fobj, cfg)
% route_a_budget_adaptive_nextgen_core
% Unified kernel for layered ablations:
% baseline -> +archive/replay -> +success-history -> +state-triggered controlled dispersal.

    if any(size(lb) == 1)
        lb = lb .* ones(1, dim);
        ub = ub .* ones(1, dim);
    end

    F_max = 0.8;
    F_min = 0.4;
    CR_max = 0.9;
    CR_min = 0.55;
    cr_shrink_start = 0.6;
    beta_best = 0.2;

    short_budget_iter_threshold = 1500;
    pbest_ratio = 0.20;
    is_short_budget = Max_iteration <= short_budget_iter_threshold;

    cfg = fill_cfg_defaults(cfg, N, Max_iteration, is_short_budget);

    population = lb + (ub - lb) .* rand(N, dim);
    fitness = zeros(N, 1);
    for i = 1:N
        fitness(i) = fobj(population(i, :));
    end

    [best_fitness, best_idx] = min(fitness);
    best_solution = population(best_idx, :);
    Convergence_curve = zeros(1, Max_iteration);

    no_improve_count = 0;

    archive_state = [];
    if cfg.enable_archive
        archive_state = archive_escape_controller('init', [], struct('dim', dim), cfg.archive);
    end

    replay_state = init_replay_state(dim, cfg.replay.max_size);

    if cfg.enable_success_history
        shsa_state = success_history_step_controller("init", [], [], cfg.shsa);
    else
        shsa_state = [];
    end

    trigger_count = 0;
    rescue_success_count = 0;
    last_trigger_iter = -1e9;
    trigger_event_rows = repmat(make_rescue_trigger_event_template(), 1, 0);
    trigger_event_idx = 0;

    for t = 1:Max_iteration

        progress = t / Max_iteration;
        E = sin((pi / 2) * progress);
        F = F_max - (F_max - F_min) * progress;
        CR = scheduled_cr(progress, CR_max, CR_min, cr_shrink_start);
        [~, sorted_idx] = sort(fitness);
        architects_idx = sorted_idx(1:max(2, round(N * 0.25)));

        pbest_k = max(2, round(N * pbest_ratio));
        pbest_k = min(pbest_k, N);
        pbest_pool = sorted_idx(1:pbest_k);

        [elite_ratio, pbest_prob] = resolve_budget_stage_policy(is_short_budget, progress);
        elite_k = max(2, round(N * elite_ratio));
        elite_idx = sorted_idx(1:elite_k);

        rec_k = max(2, min(N, round(0.10 * N)));
        improved_this_iter = 0;
        if cfg.enable_success_history
            shsa_improved = 0;
        end

        for i = 1:N
            xi = population(i, :);

            step_scale = 1.0;
            if cfg.enable_success_history && progress >= cfg.shsa.enable_progress
                step_scale = shsa_state.mu_step + cfg.shsa.sample_sigma * randn;
                step_scale = max(cfg.shsa.step_scale_min, min(cfg.shsa.step_scale_max, step_scale));
                if progress >= cfg.shsa.boost_progress || no_improve_count >= cfg.shsa.boost_when_stagnation
                    step_scale = min(cfg.shsa.step_scale_max, 1.08 * step_scale);
                end
            end

            bbo_trial = xi;
            if rand < E
                for j = 1:dim
                    k = randi([1, N]);
                    while k == i
                        k = randi([1, N]);
                    end
                    bbo_trial(j) = bbo_trial(j) + step_scale * rand * (population(k, j) - bbo_trial(j)) ...
                        + step_scale * rand * (best_solution(j) - bbo_trial(j));
                end
            else
                if ismember(i, architects_idx)
                    for j = 1:dim
                        if rand < 0.5
                            k = architects_idx(randi(length(architects_idx)));
                            bbo_trial(j) = bbo_trial(j) + step_scale * rand * (population(k, j) - bbo_trial(j));
                        end
                    end
                else
                    for j = 1:dim
                        if rand < 0.5
                            k = architects_idx(randi(length(architects_idx)));
                            bbo_trial(j) = bbo_trial(j) + step_scale * rand * (population(k, j) - bbo_trial(j));
                        else
                            disturbance = step_scale * cos((pi / 2) * progress) * (ub(j) - lb(j)) * randn / 10;
                            bbo_trial(j) = bbo_trial(j) + disturbance;
                        end
                    end
                end
            end
            bbo_trial = bound_clip(bbo_trial, lb, ub);

            [r1, r2, r3] = pick_three(N, i);
            donor = xi + beta_best * (best_solution - xi) + step_scale * F * (population(r1, :) - population(r2, :)) ...
                + 0.5 * step_scale * F * (population(r3, :) - xi);

            de_trial = xi;
            jrand = randi(dim);
            for j = 1:dim
                if rand < CR || j == jrand
                    de_trial(j) = donor(j);
                end
            end
            de_trial = bound_clip(de_trial, lb, ub);

            fb = fobj(bbo_trial);
            fd = fobj(de_trial);
            if fd < fb
                winner = de_trial;
                fw = fd;
            else
                winner = bbo_trial;
                fw = fb;
            end

            if ismember(i, elite_idx) && rand < pbest_prob
                pbest_ref = population(pbest_pool(randi(numel(pbest_pool))), :);
                pbest_trial = xi + 0.3 * step_scale * (pbest_ref - xi) + 0.25 * step_scale * F * (population(r1, :) - population(r2, :));
                pbest_trial = bound_clip(pbest_trial, lb, ub);
                fp = fobj(pbest_trial);
                if isfinite(fp) && fp < fw
                    winner = pbest_trial;
                    fw = fp;
                end
            end

            if fw < fitness(i)
                population(i, :) = winner;
                fitness(i) = fw;
                improved_this_iter = improved_this_iter + 1;
                if cfg.enable_success_history
                    shsa_improved = shsa_improved + 1;
                    shsa_state = success_history_step_controller("record", shsa_state, step_scale, cfg.shsa);
                end
                if fw < best_fitness
                    best_fitness = fw;
                    best_solution = winner;
                end
            end
        end

        if cfg.enable_archive
            [~, rec_order] = sort(fitness, 'ascend');
            record_payload = struct('positions', population(rec_order(1:rec_k), :), 'fitness', fitness(rec_order(1:rec_k)));
            archive_state = archive_escape_controller('record', archive_state, record_payload, cfg.archive);
        end

        if improved_this_iter > 0
            no_improve_count = 0;
        else
            no_improve_count = no_improve_count + 1;
        end

        if cfg.enable_success_history
            if shsa_improved == 0
                % keep no_improve_count gate from core loop as the primary trigger source
            end
            shsa_state = success_history_step_controller("update", shsa_state, [], cfg.shsa);
        end

        if cfg.enable_archive || cfg.enable_dispersal
            cooldown_ok = (t - last_trigger_iter) >= cfg.rescue.cooldown_iters;
            can_trigger = trigger_count < cfg.rescue.max_triggers_per_run;
            if (no_improve_count >= cfg.rescue.stagnation_iters) && cooldown_ok && can_trigger
                trigger_count = trigger_count + 1;
                last_trigger_iter = t;

                best_before_rescue = best_fitness;
                best_before_rescue_pos = best_solution;

                accepted_count = 0;
                used_replay = false;
                if cfg.enable_archive
                    [population, fitness, accepted_count, used_replay] = run_archive_or_replay_step(population, fitness, best_solution, lb, ub, fobj, archive_state, replay_state, cfg);
                end

                if (accepted_count == 0) && cfg.enable_dispersal
                    [population, fitness, disp_accept] = apply_stagnation_dispersal(population, fitness, lb, ub, fobj, cfg.dispersal);
                    accepted_count = accepted_count + disp_accept;
                    used_replay = false;
                end

                [iter_best, iter_idx] = min(fitness);
                if iter_best < best_fitness
                    best_fitness = iter_best;
                    best_solution = population(iter_idx, :);
                end

                best_after_rescue = best_fitness;
                improve_abs = max(0, best_before_rescue - best_after_rescue);
                improve_rel = improve_abs / max(1, abs(best_before_rescue));

                if accepted_count > 0
                    rescue_success_count = rescue_success_count + 1;
                    no_improve_count = 0;
                    if cfg.enable_replay
                        delta_best = best_solution - best_before_rescue_pos;
                        if all(isfinite(delta_best)) && norm(delta_best) > 1e-12
                            replay_state = record_replay_step(replay_state, delta_best);
                        end
                    end
                    if cfg.enable_archive
                        best_record_payload = struct('positions', best_solution, 'fitness', best_fitness);
                        archive_state = archive_escape_controller('record', archive_state, best_record_payload, cfg.archive);
                    end
                end

                trigger_event_idx = trigger_event_idx + 1;
                trigger_event_rows(trigger_event_idx) = build_rescue_trigger_event_row( ...
                    trigger_event_idx, trigger_count, t, t * N, best_before_rescue, best_after_rescue, improve_abs, improve_rel, accepted_count > 0);
                trigger_event_rows(trigger_event_idx).used_replay = logical(used_replay);
            end
        end

        Convergence_curve(t) = best_fitness;
        publish_rescue_diag(cfg.algorithm_entry, trigger_count, rescue_success_count, Max_iteration, trigger_event_rows);
    end

    publish_rescue_diag(cfg.algorithm_entry, trigger_count, rescue_success_count, Max_iteration, trigger_event_rows);
end

function cfg = fill_cfg_defaults(cfg, N, Max_iteration, is_short_budget)
    if ~isfield(cfg, 'algorithm_entry')
        cfg.algorithm_entry = 'BBO_route_a_budget_adaptive_nextgen_core';
    end

    defaults = struct();
    defaults.enable_archive = false;
    defaults.enable_replay = false;
    defaults.enable_success_history = false;
    defaults.enable_dispersal = false;
    defaults.archive = struct('max_archive_size', max(8, round(0.35 * N)), 'max_escape_targets', max(1, round(0.10 * N)), ...
        'escape_fraction', 0.08, 'escape_apply_prob', 0.16, 'escape_w_best', 0.24, 'escape_w_diff', 0.42, 'escape_noise_scale', 0.015);
    defaults.rescue = struct('stagnation_iters', 5, 'cooldown_iters', max(30, round(0.06 * Max_iteration)), 'max_triggers_per_run', 3);
    defaults.replay = struct('max_size', max(8, round(0.25 * N)), 'apply_prob', 0.60, 'target_fraction', 0.08, ...
        'w_replay', 0.30, 'w_best', 0.18, 'noise_scale', 0.010);
    defaults.shsa = struct('init_mu_step', 1.00, 'max_hist', max(8, round(0.15 * N)), 'mu_lr', 0.18, ...
        'step_scale_min', 0.25, 'step_scale_max', 1.80, 'sample_sigma', 0.12, ...
        'enable_progress', 0.45, 'boost_progress', 0.70, 'boost_when_stagnation', 6);
    defaults.dispersal = struct('target_fraction', 0.08, 'elite_ratio', 0.20, 'rediffuse_ratio', 0.35, 'mix_best_ratio', 0.25);

    cfg = merge_struct(defaults, cfg);

    if is_short_budget
        cfg.rescue.stagnation_iters = max(4, cfg.rescue.stagnation_iters - 1);
        cfg.rescue.max_triggers_per_run = max(2, cfg.rescue.max_triggers_per_run - 1);
    end

    if ~cfg.enable_archive
        cfg.enable_replay = false;
    end
end

function [X, fit, accepted_count, used_replay] = run_archive_or_replay_step(X, fit, best_pos, lb, ub, fobj, archive_state, replay_state, cfg)
    used_replay = false;

    can_replay = cfg.enable_replay && ~isempty(replay_state.steps) && (rand < cfg.replay.apply_prob);
    if can_replay
        [X, fit, accepted_count] = apply_archive_guided_replay(X, fit, best_pos, lb, ub, fobj, replay_state, cfg.replay);
        used_replay = true;
        if accepted_count > 0
            return;
        end
    end

    escape_payload = struct('X', X, 'fitness', fit, 'best_pos', best_pos, 'lb', lb, 'ub', ub, 'fobj', fobj);
    escaped = archive_escape_controller('escape', archive_state, escape_payload, cfg.archive);
    X = escaped.X;
    fit = escaped.fitness;
    accepted_count = escaped.accepted_count;
end

function [X, fit, accepted_count] = apply_archive_guided_replay(X, fit, best_pos, lb, ub, fobj, replay_state, cfg)
    N = size(X, 1);
    [~, order] = sort(fit, 'descend');
    n_targets = max(1, min(N, round(cfg.target_fraction * N)));
    targets = order(1:n_targets);
    span = ub - lb;

    accepted_count = 0;
    for k = 1:numel(targets)
        i = targets(k);
        step = replay_state.steps(randi(size(replay_state.steps, 1)), :);
        candidate = X(i, :) + cfg.w_replay * step + cfg.w_best * rand * (best_pos - X(i, :)) ...
            + cfg.noise_scale * randn(1, size(X, 2)) .* span;
        candidate = bound_clip(candidate, lb, ub);
        fc = fobj(candidate);
        if isfinite(fc) && fc < fit(i)
            X(i, :) = candidate;
            fit(i) = fc;
            accepted_count = accepted_count + 1;
        end
    end
end

function [X, fit, accepted_count] = apply_stagnation_dispersal(X, fit, lb, ub, fobj, cfg)
    N = size(X, 1);
    [~, idx] = sort(fit, 'ascend');
    elite_k = max(2, min(N, round(cfg.elite_ratio * N)));
    elite_center = mean(X(idx(1:elite_k), :), 1);

    target_k = max(1, min(N, round(cfg.target_fraction * N)));
    targets = idx(end - target_k + 1:end);

    accepted_count = 0;
    for p = 1:numel(targets)
        i = targets(p);
        rediffuse = lb + rand(1, size(X, 2)) .* (ub - lb);
        candidate = (1 - cfg.rediffuse_ratio) * X(i, :) + cfg.rediffuse_ratio * rediffuse ...
            + cfg.mix_best_ratio * rand(1, size(X, 2)) .* (elite_center - X(i, :));
        candidate = bound_clip(candidate, lb, ub);
        fc = fobj(candidate);
        if isfinite(fc) && fc < fit(i)
            X(i, :) = candidate;
            fit(i) = fc;
            accepted_count = accepted_count + 1;
        end
    end
end

function state = init_replay_state(dim, max_size)
    state = struct();
    state.steps = zeros(0, dim);
    state.max_size = max_size;
end

function state = record_replay_step(state, step)
    state.steps(end + 1, :) = step; %#ok<AGROW>
    if size(state.steps, 1) > state.max_size
        state.steps = state.steps(end - state.max_size + 1:end, :);
    end
end

function out = merge_struct(base, override)
    out = base;
    keys = fieldnames(override);
    for i = 1:numel(keys)
        k = keys{i};
        if isstruct(override.(k)) && isfield(base, k) && isstruct(base.(k))
            out.(k) = merge_struct(base.(k), override.(k));
        else
            out.(k) = override.(k);
        end
    end
end

function row = make_rescue_trigger_event_template()
    row = struct('event_id', 0, 'trigger_id', 0, 'iter', 0, 'trigger_fe', 0, ...
        'best_before', 0, 'best_after', 0, 'improve_abs', 0, 'improve_rel', 0, ...
        'success', false, 'used_replay', false);
end

function row = build_rescue_trigger_event_row(event_id, trigger_id, iter, trigger_fe, best_before, best_after, improve_abs, improve_rel, success)
    row = make_rescue_trigger_event_template();
    row.event_id = event_id;
    row.trigger_id = trigger_id;
    row.iter = iter;
    row.trigger_fe = trigger_fe;
    row.best_before = best_before;
    row.best_after = best_after;
    row.improve_abs = improve_abs;
    row.improve_rel = improve_rel;
    row.success = logical(success);
end

function [elite_ratio, pbest_prob] = resolve_budget_stage_policy(is_short_budget, progress)
    if is_short_budget
        if progress < 0.85
            elite_ratio = 0.10;
            pbest_prob = 0.00;
        else
            elite_ratio = 0.10;
            pbest_prob = 0.15;
        end
        return;
    end

    if progress < 0.50
        elite_ratio = 0.10;
        pbest_prob = 0.00;
    elseif progress < 0.80
        alpha = (progress - 0.50) / 0.30;
        elite_ratio = 0.12;
        pbest_prob = 0.10 + 0.25 * alpha;
    else
        elite_ratio = 0.20;
        pbest_prob = 0.55;
    end
end

function CR = scheduled_cr(progress, CR_max, CR_min, shrink_start)
    if progress <= shrink_start
        CR = CR_max;
        return;
    end
    alpha = (progress - shrink_start) / (1 - shrink_start);
    CR = CR_max - (CR_max - CR_min) * alpha;
end

function x = bound_clip(x, lb, ub)
    x = max(x, lb);
    x = min(x, ub);
    if ~all(isfinite(x))
        x(~isfinite(x)) = lb(~isfinite(x));
    end
end

function [r1, r2, r3] = pick_three(N, i)
    ids = randperm(N, min(N, 4));
    ids(ids == i) = [];
    if numel(ids) < 3
        pool = setdiff(1:N, i);
        if numel(pool) >= 3
            ids = pool(randperm(numel(pool), 3));
        else
            ids = randi([1, N], 1, 3);
        end
    else
        ids = ids(1:3);
    end
    r1 = ids(1);
    r2 = ids(2);
    r3 = ids(3);
end

function publish_rescue_diag(algorithm_entry, trigger_count, rescue_success_count, max_iteration, trigger_events)
    diag = struct();
    diag.algorithm_entry = algorithm_entry;
    diag.trigger_count = trigger_count;
    diag.success_count = rescue_success_count;
    diag.success_rate = rescue_success_count / max(1, trigger_count);
    diag.max_iteration = max_iteration;
    diag.trigger_events = trigger_events;
    setappdata(0, 'bbo_rescue_diag_last', diag);
end
