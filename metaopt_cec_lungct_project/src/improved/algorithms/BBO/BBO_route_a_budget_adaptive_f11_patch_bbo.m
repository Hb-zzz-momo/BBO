function [best_fitness, best_solution, Convergence_curve] = BBO_route_a_budget_adaptive_f11_patch_bbo(N, Max_iteration, lb, ub, dim, fobj)
% BBO_route_a_budget_adaptive_f11_patch_bbo
% Single-point patch for Route A budget-adaptive mainline.
% Scope: add one controlled local escape for F11 stagnation relief.
% Fairness: does not change benchmark protocol config fields.

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

    % Controlled local-escape parameters (single added mechanism)
    escape_cfg = struct();
    escape_cfg.stagnation_iter_threshold = 10;
    escape_cfg.trigger_ratio = 0.18;
    escape_cfg.tail_fraction = 0.35;
    escape_cfg.only_tail = true;
    escape_cfg.require_better_than_elite = true;
    escape_cfg.enable_progress = 0.55;
    escape_cfg.move_to_best = 0.20;
    escape_cfg.move_to_peer = 0.35;
    escape_cfg.noise_scale = 0.02;

    if is_short_budget
        % Low-budget F11 can be over-conservative. Tune only threshold/ratio.
        escape_cfg.stagnation_iter_threshold = 6;
        escape_cfg.trigger_ratio = 0.28;
    end

    fid = parse_func_id_from_handle(fobj);
    is_comp_or_hybrid = ismember(fid, [10, 11, 12, 13:30]);
    if is_comp_or_hybrid
        % Keep conservative bias, but avoid over-suppressing low-budget trigger.
        escape_cfg.trigger_ratio = max(0.12, 0.70 * escape_cfg.trigger_ratio);
        escape_cfg.move_to_best = 0.15;
        escape_cfg.move_to_peer = 0.22;
        escape_cfg.noise_scale = 0.012;
    end

    population = lb + (ub - lb) .* rand(N, dim);
    fitness = zeros(N, 1);
    for i = 1:N
        fitness(i) = fobj(population(i, :));
    end

    [best_fitness, best_idx] = min(fitness);
    best_solution = population(best_idx, :);
    Convergence_curve = zeros(1, Max_iteration);

    stagnation_counter = 0;

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

        best_before_iter = best_fitness;

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

        if best_fitness < best_before_iter
            stagnation_counter = 0;
        else
            stagnation_counter = stagnation_counter + 1;
        end

        if progress >= escape_cfg.enable_progress && stagnation_counter >= escape_cfg.stagnation_iter_threshold
            [population, fitness, best_fitness, best_solution, applied] = ...
                apply_controlled_local_escape(population, fitness, best_fitness, best_solution, lb, ub, fobj, escape_cfg);
            if applied > 0
                stagnation_counter = 0;
            end
        end

        Convergence_curve(t) = best_fitness;
    end
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

function [X, fit, best_f, best_x, accepted] = apply_controlled_local_escape(X, fit, best_f, best_x, lb, ub, fobj, cfg)
    N = size(X, 1);
    dim = size(X, 2);

    [~, idx] = sort(fit, 'ascend');
    elite_f = fit(idx(1));

    if cfg.only_tail
        tail_start = max(2, floor((1 - cfg.tail_fraction) * N));
        candidates = idx(tail_start:end);
    else
        candidates = idx;
    end

    if isempty(candidates)
        accepted = 0;
        return;
    end

    n_try = max(1, round(cfg.trigger_ratio * N));
    n_try = min(n_try, numel(candidates));
    chosen = candidates(randperm(numel(candidates), n_try));

    accepted = 0;
    for k = 1:numel(chosen)
        i = chosen(k);
        xi = X(i, :);

        peer = X(candidates(randi(numel(candidates))), :);
        trial = xi + cfg.move_to_best * rand * (best_x - xi) + cfg.move_to_peer * rand * (peer - xi) ...
            + cfg.noise_scale * (ub - lb) .* randn(1, dim);
        trial = bound_clip(trial, lb, ub);

        ft = fobj(trial);
        if ~isfinite(ft)
            continue;
        end

        if cfg.require_better_than_elite
            if ~(ft < elite_f && ft < fit(i))
                continue;
            end
        else
            if ~(ft < fit(i))
                continue;
            end
        end

        X(i, :) = trial;
        fit(i) = ft;
        accepted = accepted + 1;

        if ft < best_f
            best_f = ft;
            best_x = trial;
        end
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

function fid = parse_func_id_from_handle(fobj)
    fid = -1;
    try
        ftxt = char(func2str(fobj));
        tokens = regexp(ftxt, 'cec(?:17|22)_func\s*\([^,]+,\s*(\d+)', 'tokens', 'once');
        if ~isempty(tokens)
            fid = str2double(tokens{1});
        end
    catch
        fid = -1;
    end
end
