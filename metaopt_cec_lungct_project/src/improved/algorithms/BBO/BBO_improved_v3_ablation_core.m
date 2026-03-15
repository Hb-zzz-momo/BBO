function [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3_ablation_core(N, Max_iteration, lb, ub, dim, fobj, mode)
% BBO_improved_v3_ablation_core
% Shared core for dual-objective ablation around v3:
% 1) simple-function convergence enhancement modules
% 2) conservative, condition-triggered directional modules

    if nargin < 7 || isempty(mode)
        mode = 'baseline';
    end
    mode = lower(string(mode));

    if any(size(lb) == 1)
        lb = lb .* ones(1, dim);
        ub = ub .* ones(1, dim);
    end

    cfg = mode_config(mode, Max_iteration);

    population = lb + (ub - lb) .* rand(N, dim);
    fitness = zeros(N, 1);
    for i = 1:N
        fitness(i) = fobj(population(i, :));
    end

    [best_fitness, idx] = min(fitness);
    best_solution = population(idx, :);
    Convergence_curve = zeros(1, Max_iteration);

    no_improve_count = 0;

    for t = 1:Max_iteration
        progress = t / Max_iteration;
        E = sin((pi / 2) * progress);
        improved_this_iter = false;

        [~, sorted_idx] = sort(fitness);
        architect_count = max(2, round(N * 0.25));
        architects_idx = sorted_idx(1:architect_count);

        for i = 1:N
            old_position = population(i, :);
            old_fitness = fitness(i);
            trial = old_position;

            if rand < E
                for j = 1:dim
                    k = randi([1, N]);
                    while k == i
                        k = randi([1, N]);
                    end
                    trial(j) = trial(j) + rand * (population(k, j) - trial(j)) ...
                        + rand * (best_solution(j) - trial(j));
                end
            else
                if ismember(i, architects_idx)
                    for j = 1:dim
                        if rand < 0.5
                            k = architects_idx(randi(length(architects_idx)));
                            trial(j) = trial(j) + rand * (population(k, j) - trial(j));
                        end
                    end
                else
                    for j = 1:dim
                        if rand < 0.5
                            k = architects_idx(randi(length(architects_idx)));
                            trial(j) = trial(j) + rand * (population(k, j) - trial(j));
                        else
                            disturbance = cos((pi / 2) * progress) * (ub(j) - lb(j)) * randn / 10;
                            trial(j) = trial(j) + disturbance;
                        end
                    end
                end
            end

            trial = apply_simple_modules(trial, old_position, best_solution, progress, lb, ub, cfg);
            trial = max(trial, lb);
            trial = min(trial, ub);

            if ~all(isfinite(trial))
                trial = old_position;
            end

            trial_fitness = fobj(trial);
            if trial_fitness < old_fitness
                population(i, :) = trial;
                fitness(i) = trial_fitness;
                if trial_fitness < best_fitness
                    best_fitness = trial_fitness;
                    best_solution = trial;
                    improved_this_iter = true;
                end
            else
                population(i, :) = old_position;
                fitness(i) = old_fitness;
            end
        end

        if improved_this_iter
            no_improve_count = 0;
        else
            no_improve_count = no_improve_count + 1;
        end

        pop_diversity = population_diversity(population, lb, ub);

        [population, fitness, best_fitness, best_solution, no_improve_count] = ...
            apply_directional_module(population, fitness, best_fitness, best_solution, ...
            progress, no_improve_count, pop_diversity, lb, ub, cfg, fobj);

        [population, fitness, best_fitness, best_solution] = ...
            apply_late_local_refine(population, fitness, best_fitness, best_solution, ...
            progress, no_improve_count, pop_diversity, lb, ub, cfg, fobj);

        Convergence_curve(t) = best_fitness;
    end
end

function cfg = mode_config(mode, max_iter)
    cfg = struct();

    cfg.use_fast_A = false;
    cfg.use_fast_B = false;
    cfg.dir_late = false;
    cfg.dir_stagnation = false;
    cfg.dir_elite_only = false;
    cfg.dir_small_step = false;
    cfg.use_late_local_refine = false;
    cfg.use_directional_gate = false;

    cfg.stall_window = max(5, round(0.08 * max_iter));
    cfg.late_start = 0.60;
    cfg.local_refine_start = 0.70;
    cfg.local_refine_no_improve_max = max(2, round(0.03 * max_iter));
    cfg.local_refine_diversity_threshold = 0.12;
    cfg.local_refine_prob = 0.20;
    cfg.gate_stall_window = max(4, round(0.06 * max_iter));
    cfg.gate_lag_ratio = 0.18;
    cfg.gate_min_diversity = 0.08;
    cfg.gate_early_stage = 0.35;

    switch char(mode)
        case 'baseline'
        case 'fast_simple_a'
            cfg.use_fast_A = true;
        case 'fast_simple_b'
            cfg.use_fast_B = true;
        case 'dir_late'
            cfg.dir_late = true;
        case 'dir_stagnation'
            cfg.dir_stagnation = true;
        case 'dir_elite_only'
            cfg.dir_elite_only = true;
        case 'dir_small_step'
            cfg.dir_small_step = true;
            cfg.dir_late = true;
        case 'hybrid_a_dir_stag'
            cfg.use_fast_A = true;
            cfg.dir_stagnation = true;
        case 'hybrid_b_dir_small'
            cfg.use_fast_B = true;
            cfg.dir_small_step = true;
            cfg.dir_late = true;
        case 'dir_small_step_late_local_refine'
            cfg.dir_small_step = true;
            cfg.dir_late = true;
            cfg.use_late_local_refine = true;
        case 'dir_small_step_gate_late_local_refine'
            cfg.dir_small_step = true;
            cfg.dir_late = true;
            cfg.use_late_local_refine = true;
            cfg.use_directional_gate = true;
        otherwise
            error('Unsupported v3 ablation mode: %s', mode);
    end
end

function trial = apply_simple_modules(trial, old_position, best_solution, progress, lb, ub, cfg)
    if cfg.use_fast_A
        shrink = 1 - 0.50 * progress;
        trial = old_position + shrink .* (trial - old_position);

        if progress > 0.65 && rand < 0.35
            trial = trial + (0.08 + 0.18 * progress) .* (best_solution - trial);
        end

        if progress > 0.80
            fine_scale = 0.008 * (1 - progress + 0.1);
            trial = trial + fine_scale .* (ub - lb) .* randn(size(trial));
        end
    end

    if cfg.use_fast_B
        contraction = 0.06 + 0.24 * progress;
        trial = trial + contraction .* (best_solution - trial);

        if progress > 0.70
            trial = 0.75 * trial + 0.25 * best_solution;
        end

        if progress > 0.85
            fine_scale = 0.005 * (1 - progress + 0.05);
            trial = best_solution + fine_scale .* (ub - lb) .* randn(size(trial));
        end
    end
end

function [population, fitness, best_fitness, best_solution, no_improve_count] = apply_directional_module( ...
    population, fitness, best_fitness, best_solution, progress, no_improve_count, pop_diversity, lb, ub, cfg, fobj)

    if ~(cfg.dir_late || cfg.dir_stagnation || cfg.dir_elite_only || cfg.dir_small_step)
        return;
    end

    elite_pool_size = max(4, round(0.2 * size(population, 1)));
    [~, elite_sorted] = sort(fitness);
    elite_pool = population(elite_sorted(1:elite_pool_size), :);

    if size(elite_pool, 1) < 3
        return;
    end

    if cfg.use_directional_gate
        if progress <= cfg.gate_early_stage
            return;
        end
        if no_improve_count < cfg.gate_stall_window
            return;
        end
        if pop_diversity < cfg.gate_min_diversity
            return;
        end

        elite_mid_f = median(fitness(elite_sorted(1:elite_pool_size)));
        [worst_fitness, ~] = max(fitness);
        lag_ratio = (worst_fitness - elite_mid_f) / (abs(elite_mid_f) + 1e-12);
        if lag_ratio < cfg.gate_lag_ratio
            return;
        end
    end

    trigger = false;
    if cfg.dir_late && progress >= cfg.late_start
        trigger = true;
    end
    if cfg.dir_stagnation && no_improve_count >= cfg.stall_window
        trigger = true;
    end

    if ~trigger
        base_prob = 0.08 + 0.12 * progress;
        if cfg.dir_elite_only
            base_prob = base_prob * 0.75;
        end
        if cfg.dir_small_step
            base_prob = base_prob * 0.85;
        end
        trigger = rand < base_prob;
    end

    if ~trigger
        return;
    end

    ids = randperm(size(elite_pool, 1), 3);
    e1 = elite_pool(ids(1), :);
    e2 = elite_pool(ids(2), :);
    e3 = elite_pool(ids(3), :);

    F = 0.52 - 0.30 * progress;
    tail = 0.05 + 0.03 * (1 - progress);

    if cfg.dir_small_step
        F = 0.5 * F;
        tail = 0.35 * tail;
    end

    if cfg.dir_elite_only
        elite_mid = elite_pool(max(2, round(size(elite_pool, 1) / 2)), :);
        candidate = best_solution + F .* (e1 - elite_mid) + tail .* randn(size(best_solution)) .* (e3 - best_solution);
    else
        candidate = best_solution + F .* (e1 - e2) + tail .* randn(size(best_solution)) .* (e3 - best_solution);
    end

    candidate = max(candidate, lb);
    candidate = min(candidate, ub);

    if ~all(isfinite(candidate))
        return;
    end

    candidate_fitness = fobj(candidate);

    [worst_fitness, worst_idx] = max(fitness);
    if candidate_fitness < worst_fitness
        population(worst_idx, :) = candidate;
        fitness(worst_idx) = candidate_fitness;
    end

    if candidate_fitness < best_fitness
        best_fitness = candidate_fitness;
        best_solution = candidate;
        no_improve_count = 0;
    end
end

function [population, fitness, best_fitness, best_solution] = apply_late_local_refine( ...
    population, fitness, best_fitness, best_solution, progress, no_improve_count, pop_diversity, lb, ub, cfg, fobj)

    if ~cfg.use_late_local_refine
        return;
    end

    if progress <= cfg.local_refine_start
        return;
    end

    if no_improve_count > cfg.local_refine_no_improve_max
        return;
    end

    if pop_diversity >= cfg.local_refine_diversity_threshold
        return;
    end

    if rand > cfg.local_refine_prob
        return;
    end

    elite_count = max(3, round(0.15 * size(population, 1)));
    [~, elite_sorted] = sort(fitness);
    elite = population(elite_sorted(1:elite_count), :);
    elite_centroid = mean(elite, 1);

    base_radius = 0.008 * (1 - progress + 0.08);
    local_noise = base_radius .* (ub - lb) .* randn(size(best_solution));

    candidate_a = 0.88 .* best_solution + 0.12 .* elite_centroid + local_noise;
    candidate_b = best_solution + 0.16 .* (elite_centroid - best_solution) + 0.5 .* local_noise;

    candidate_a = min(max(candidate_a, lb), ub);
    candidate_b = min(max(candidate_b, lb), ub);

    fit_a = fobj(candidate_a);
    fit_b = fobj(candidate_b);

    candidate = candidate_a;
    candidate_fit = fit_a;
    if fit_b < fit_a
        candidate = candidate_b;
        candidate_fit = fit_b;
    end

    [worst_fit, worst_idx] = max(fitness);
    if candidate_fit < worst_fit
        population(worst_idx, :) = candidate;
        fitness(worst_idx) = candidate_fit;
    end

    if candidate_fit < best_fitness
        best_fitness = candidate_fit;
        best_solution = candidate;
    end
end

function d = population_diversity(population, lb, ub)
    span = ub - lb;
    span(span <= 1e-12) = 1;
    scaled_std = std(population, 0, 1) ./ span;
    d = mean(scaled_std);
    if ~isfinite(d)
        d = 0;
    end
end
