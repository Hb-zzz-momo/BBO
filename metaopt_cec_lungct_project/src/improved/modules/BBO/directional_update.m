function [population, fitness, best_fitness, best_solution, no_improve_count] = directional_update( ...
    population, fitness, best_fitness, best_solution, progress, no_improve_count, pop_diversity, lb, ub, cfg, fobj)
% directional_update
% Reusable directional module for v3 ablation variants.

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
    if cfg.use_stag_trigger_only
        trigger = (no_improve_count >= cfg.tau_dir);
    else
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
    end

    if ~trigger
        return;
    end

    ids = randperm(size(elite_pool, 1), 3);
    e1 = elite_pool(ids(1), :);
    e2 = elite_pool(ids(2), :);
    e3 = elite_pool(ids(3), :);

    if cfg.dir_elite_only
        elite_mid = elite_pool(max(2, round(size(elite_pool, 1) / 2)), :);
        direction_vec = (e1 - elite_mid);
    else
        direction_vec = (e1 - e2);
    end

    if cfg.use_clipped_direction_step
        step = build_clipped_direction_step(direction_vec, population, best_solution, ub, lb, cfg);
        tail_cap = min(cfg.dir_cap_std_ratio .* std(population, 0, 1), cfg.dir_cap_range_ratio .* (ub - lb));
        tail_cap = max(tail_cap, 1e-12);
        candidate = best_solution + step + cfg.dir_noise_ratio .* tail_cap .* randn(size(best_solution));
    else
        F = 0.52 - 0.30 * progress;
        tail = 0.05 + 0.03 * (1 - progress);

        if cfg.dir_small_step
            F = 0.5 * F;
            tail = 0.35 * tail;
        end
        candidate = best_solution + F .* direction_vec + tail .* randn(size(best_solution)) .* (e3 - best_solution);
    end

    candidate = max(candidate, lb);
    candidate = min(candidate, ub);

    if ~all(isfinite(candidate))
        return;
    end

    candidate_fitness = fobj(candidate);

    if cfg.direction_bottom_half_only
        N = size(population, 1);
        bottom_ids = elite_sorted(floor(N / 2) + 1:end);
        if isempty(bottom_ids)
            return;
        end
        [worst_fitness, local_idx] = max(fitness(bottom_ids));
        worst_idx = bottom_ids(local_idx);
    else
        [worst_fitness, worst_idx] = max(fitness);
    end

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

function step = build_clipped_direction_step(direction_vec, population, best_solution, ub, lb, cfg)
    span = ub - lb;
    span(span <= 1e-12) = 1;

    pop_std = std(population, 0, 1);
    local_scale = max(pop_std, 1e-12);

    dir_norm = norm(direction_vec);
    if dir_norm <= 1e-12 || ~isfinite(dir_norm)
        step = zeros(size(direction_vec));
        return;
    end

    dir_unit = direction_vec ./ dir_norm;
    raw_step = cfg.alpha_dir .* dir_unit .* local_scale;

    cap_std = cfg.dir_cap_std_ratio .* pop_std;
    cap_range = cfg.dir_cap_range_ratio .* span;
    cap = min(cap_std, cap_range);
    cap = max(cap, 1e-12);

    step = sign(raw_step) .* min(abs(raw_step), cap);

    near_ratio = abs(best_solution - mean(population, 1)) ./ span;
    shrink_mask = near_ratio <= cfg.dir_near_best_ratio;
    step(shrink_mask) = cfg.dir_near_best_shrink .* step(shrink_mask);
end
