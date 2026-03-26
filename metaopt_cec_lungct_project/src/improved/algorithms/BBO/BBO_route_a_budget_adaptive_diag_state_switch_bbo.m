function [best_fitness, best_solution, Convergence_curve] = BBO_route_a_budget_adaptive_diag_state_switch_bbo(N, Max_iteration, lb, ub, dim, fobj)
% BBO_route_a_budget_adaptive_diag_state_switch_bbo
% Diagnostic-driven Route A variant.
% State trigger uses: stagnation length + diversity + head-tail fitness gap.
% Two states are switched online:
% 1) conservative mode: keep stability first.
% 2) escape mode: activate archive-based cross-basin jumps.

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

    cfg_state = struct();
    if is_short_budget
        cfg_state.stagnation_iters = 6;
        cfg_state.diversity_low = 0.070;
        cfg_state.gap_threshold = 0.14;
    else
        cfg_state.stagnation_iters = 8;
        cfg_state.diversity_low = 0.050;
        cfg_state.gap_threshold = 0.18;
    end
    cfg_state.escape_enable_progress = 0.45;

    cfg_escape = struct();
    cfg_escape.max_archive_size = max(8, round(0.50 * N));
    cfg_escape.max_escape_targets = max(2, round(0.18 * N));
    cfg_escape.escape_fraction = 0.22;
    cfg_escape.escape_apply_prob = 0.60;
    cfg_escape.escape_w_best = 0.20;
    cfg_escape.escape_w_diff = 0.65;
    cfg_escape.escape_noise_scale = 0.03;
    cfg_escape.enable_progress = cfg_state.escape_enable_progress;
    cfg_escape.stagnation_iters = cfg_state.stagnation_iters;

    population = lb + (ub - lb) .* rand(N, dim);
    fitness = zeros(N, 1);
    for i = 1:N
        fitness(i) = fobj(population(i, :));
    end

    [best_fitness, best_idx] = min(fitness);
    best_solution = population(best_idx, :);
    Convergence_curve = zeros(1, Max_iteration);

    init_payload = struct('dim', dim);
    archive_state = archive_escape_controller('init', [], init_payload, cfg_escape);
    no_improve_count = 0;

    for t = 1:Max_iteration
        progress = t / Max_iteration;
        E = sin((pi / 2) * progress);
        F = F_max - (F_max - F_min) * progress;
        CR = scheduled_cr(progress, CR_max, CR_min, cr_shrink_start);

        [fitness_sorted, sorted_idx] = sort(fitness, 'ascend');
        architects_idx = sorted_idx(1:max(2, round(N * 0.25)));
        pbest_k = min(N, max(2, round(N * pbest_ratio)));
        pbest_pool = sorted_idx(1:pbest_k);

        [elite_ratio_base, pbest_prob_base] = resolve_budget_stage_policy(is_short_budget, progress);

        pop_div = population_diversity(population, lb, ub);
        gap = head_tail_gap(fitness_sorted);
        c1 = no_improve_count >= cfg_state.stagnation_iters;
        c2 = pop_div <= cfg_state.diversity_low;
        c3 = gap >= cfg_state.gap_threshold;
        trigger_count = double(c1) + double(c2) + double(c3);
        escape_mode = (progress >= cfg_state.escape_enable_progress) && (trigger_count >= 2);

        if escape_mode
            elite_ratio = min(0.16, elite_ratio_base + 0.02);
            pbest_prob = min(0.70, pbest_prob_base + 0.10);
        else
            elite_ratio = max(0.08, elite_ratio_base - 0.02);
            pbest_prob = 0.75 * pbest_prob_base;
        end

        elite_k = max(2, round(N * elite_ratio));
        elite_idx = sorted_idx(1:elite_k);

        improved_positions = zeros(0, dim);
        improved_fitness = zeros(0, 1);
        improved_this_iter = 0;
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
                improved_this_iter = improved_this_iter + 1;
                improved_positions(end + 1, :) = winner; %#ok<AGROW>
                improved_fitness(end + 1, 1) = fw; %#ok<AGROW>
                if fw < best_fitness
                    best_fitness = fw;
                    best_solution = winner;
                end
            end
        end

        if ~isempty(improved_fitness)
            record_payload = struct('positions', improved_positions, 'fitness', improved_fitness);
            archive_state = archive_escape_controller('record', archive_state, record_payload, cfg_escape);
        end

        if best_fitness < best_before_iter || improved_this_iter > 0
            no_improve_count = 0;
        else
            no_improve_count = no_improve_count + 1;
        end

        if escape_mode
            escape_payload = struct( ...
                'X', population, ...
                'fitness', fitness, ...
                'best_pos', best_solution, ...
                'lb', lb, ...
                'ub', ub, ...
                'fobj', fobj);
            escaped = archive_escape_controller('escape', archive_state, escape_payload, cfg_escape);
            population = escaped.X;
            fitness = escaped.fitness;
            [iter_best, iter_idx] = min(fitness);
            if iter_best < best_fitness
                best_fitness = iter_best;
                best_solution = population(iter_idx, :);
                no_improve_count = 0;
            end
        end

        Convergence_curve(t) = best_fitness;
    end
end

function d = population_diversity(population, lb, ub)
    span = ub - lb;
    span(span == 0) = 1;
    z = std(population, 0, 1) ./ span;
    d = mean(z);
end

function g = head_tail_gap(fitness_sorted)
    n = numel(fitness_sorted);
    k = max(2, round(0.2 * n));
    head = mean(fitness_sorted(1:k));
    tail = mean(fitness_sorted(end-k+1:end));
    g = (tail - head) / max(1, abs(head));
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

function ensure_module_paths()
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    project_root = fileparts(fileparts(fileparts(fileparts(this_dir))));

    module_dir = fullfile(project_root, 'src', 'improved', 'modules', 'BBO');
    if exist(module_dir, 'dir') && isempty(strfind(path, module_dir)) %#ok<STREMP>
        addpath(module_dir);
    end
end
