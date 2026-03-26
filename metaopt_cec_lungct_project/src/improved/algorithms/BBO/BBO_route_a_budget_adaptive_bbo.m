function [best_fitness, best_solution, Convergence_curve] = BBO_route_a_budget_adaptive_bbo(N, Max_iteration, lb, ub, dim, fobj)
% BBO_route_a_budget_adaptive_bbo
% Direction 3: budget-aware route A.
% Design constraints:
% 1) Low-budget mode (short iteration budget): mostly CURRENT behavior.
% 2) High-budget mode: gradually increase late-stage PBEST refinement.

    ensure_module_paths();

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

    % Minimal archive rescue: keep Budget_adaptive as frozen base chain,
    % only add conservative trigger-based escape in long-budget stagnation.
    rescue_enabled = (~is_short_budget) && (Max_iteration >= 80);
    rescue = struct();
    rescue.stagnation_iters = 5;
    rescue.cooldown_iters = max(30, round(0.06 * Max_iteration));
    rescue.max_triggers_per_run = 3;
    rescue.tail_fraction = 0.08;
    rescue_cfg = struct();
    rescue_cfg.max_archive_size = max(8, round(0.35 * N));
    rescue_cfg.max_escape_targets = max(1, round(0.10 * N));
    rescue_cfg.escape_fraction = rescue.tail_fraction;
    rescue_cfg.escape_apply_prob = 0.16;
    rescue_cfg.escape_w_best = 0.24;
    rescue_cfg.escape_w_diff = 0.42;
    rescue_cfg.escape_noise_scale = 0.015;

    population = lb + (ub - lb) .* rand(N, dim);
    fitness = zeros(N, 1);
    for i = 1:N
        fitness(i) = fobj(population(i, :));
    end

    [best_fitness, best_idx] = min(fitness);
    best_solution = population(best_idx, :);
    Convergence_curve = zeros(1, Max_iteration);

    init_payload = struct('dim', dim);
    archive_state = archive_escape_controller('init', [], init_payload, rescue_cfg);
    no_improve_count = 0;
    trigger_count = 0;
    rescue_success_count = 0;
    last_trigger_iter = -1e9;
    trigger_event_rows = repmat(make_rescue_trigger_event_template(), 1, 0);
    trigger_event_idx = 0;

    for t = 1:Max_iteration
        best_before_iter = best_fitness;
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

        for i = 1:N
            xi = population(i, :);

            bbo_trial = xi;
            if rand < E
                for j = 1:dim
                    k = randi([1, N]);
                    while k == i
                        k = randi([1, N]);
                    end
                    bbo_trial(j) = bbo_trial(j) + rand * (population(k, j) - bbo_trial(j)) ...
                        + rand * (best_solution(j) - bbo_trial(j));
                end
            else
                if ismember(i, architects_idx)
                    for j = 1:dim
                        if rand < 0.5
                            k = architects_idx(randi(length(architects_idx)));
                            bbo_trial(j) = bbo_trial(j) + rand * (population(k, j) - bbo_trial(j));
                        end
                    end
                else
                    for j = 1:dim
                        if rand < 0.5
                            k = architects_idx(randi(length(architects_idx)));
                            bbo_trial(j) = bbo_trial(j) + rand * (population(k, j) - bbo_trial(j));
                        else
                            disturbance = cos((pi / 2) * progress) * (ub(j) - lb(j)) * randn / 10;
                            bbo_trial(j) = bbo_trial(j) + disturbance;
                        end
                    end
                end
            end
            bbo_trial = bound_clip(bbo_trial, lb, ub);

            [r1, r2, r3] = pick_three(N, i);
            donor = xi + beta_best * (best_solution - xi) + F * (population(r1, :) - population(r2, :)) ...
                + 0.5 * F * (population(r3, :) - xi);

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
                pbest_trial = xi + 0.3 * (pbest_ref - xi) + 0.25 * F * (population(r1, :) - population(r2, :));
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
                if fw < best_fitness
                    best_fitness = fw;
                    best_solution = winner;
                end
            end
        end

        % Record a small elite snapshot each iteration for later rescue attempts.
        rec_k = max(2, min(N, round(0.10 * N)));
        [~, rec_order] = sort(fitness, 'ascend');
        record_payload = struct( ...
            'positions', population(rec_order(1:rec_k), :), ...
            'fitness', fitness(rec_order(1:rec_k)));
        archive_state = archive_escape_controller('record', archive_state, record_payload, rescue_cfg);

        if best_fitness < best_before_iter
            no_improve_count = 0;
        else
            no_improve_count = no_improve_count + 1;
        end

        if rescue_enabled
            cooldown_ok = (t - last_trigger_iter) >= rescue.cooldown_iters;
            can_trigger = trigger_count < rescue.max_triggers_per_run;
            if (no_improve_count >= rescue.stagnation_iters) && cooldown_ok && can_trigger
                trigger_count = trigger_count + 1;
                last_trigger_iter = t;
                best_before_rescue = best_fitness;

                escape_payload = struct( ...
                    'X', population, ...
                    'fitness', fitness, ...
                    'best_pos', best_solution, ...
                    'lb', lb, ...
                    'ub', ub, ...
                    'fobj', fobj);
                escaped = archive_escape_controller('escape', archive_state, escape_payload, rescue_cfg);

                population = escaped.X;
                fitness = escaped.fitness;
                [iter_best, iter_idx] = min(fitness);
                if iter_best < best_fitness
                    best_fitness = iter_best;
                    best_solution = population(iter_idx, :);
                end

                best_after_rescue = best_fitness;
                improve_abs = max(0, best_before_rescue - best_after_rescue);
                improve_rel = improve_abs / max(1, abs(best_before_rescue));
                rescue_success = escaped.accepted_count > 0;
                if rescue_success
                    rescue_success_count = rescue_success_count + 1;
                    no_improve_count = 0;
                end

                trigger_event_idx = trigger_event_idx + 1;
                trigger_event_rows(trigger_event_idx) = build_rescue_trigger_event_row( ...
                    trigger_event_idx, trigger_count, t, t * N, best_before_rescue, best_after_rescue, ...
                    improve_abs, improve_rel, rescue_success);
            end
        end

        Convergence_curve(t) = best_fitness;
        publish_rescue_diag(trigger_count, rescue_success_count, Max_iteration, trigger_event_rows);
    end

    publish_rescue_diag(trigger_count, rescue_success_count, Max_iteration, trigger_event_rows);
end

function row = make_rescue_trigger_event_template()
    row = struct( ...
        'event_id', 0, ...
        'trigger_id', 0, ...
        'iter', 0, ...
        'trigger_fe', 0, ...
        'best_before', 0, ...
        'best_after', 0, ...
        'improve_abs', 0, ...
        'improve_rel', 0, ...
        'success', false);
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

function ensure_module_paths()
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    project_root = fileparts(fileparts(fileparts(fileparts(this_dir))));

    module_dir = fullfile(project_root, 'src', 'improved', 'modules', 'BBO');
    if exist(module_dir, 'dir') && isempty(strfind(path, module_dir)) %#ok<STREMP>
        addpath(module_dir);
    end
end

function publish_rescue_diag(trigger_count, rescue_success_count, max_iteration, trigger_events)
    diag = struct();
    diag.algorithm_entry = 'BBO_route_a_budget_adaptive_bbo';
    diag.trigger_count = trigger_count;
    diag.success_count = rescue_success_count;
    diag.success_rate = rescue_success_count / max(1, trigger_count);
    diag.max_iteration = max_iteration;
    diag.trigger_events = trigger_events;
    setappdata(0, 'bbo_rescue_diag_last', diag);
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
