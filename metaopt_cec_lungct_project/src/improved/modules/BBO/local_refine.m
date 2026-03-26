function [population, fitness, best_fitness, best_solution] = local_refine( ...
    population, fitness, best_fitness, best_solution, progress, no_improve_count, pop_diversity, lb, ub, cfg, fobj)
% local_refine
% Reusable late local refine module for v3 ablation variants.

    if ~cfg.use_late_local_refine
        return;
    end

    if progress <= cfg.local_refine_start
        return;
    end

    elite_count = max(3, round(0.15 * size(population, 1)));
    [~, elite_sorted] = sort(fitness);
    elite = population(elite_sorted(1:elite_count), :);
    elite_centroid = mean(elite, 1);

    span = ub - lb;
    span(span <= 1e-12) = 1;
    elite_spread = mean(std(elite, 0, 1) ./ span);

    if cfg.local_refine_state_trigger
        if no_improve_count < cfg.tau_refine
            return;
        end
        if elite_spread > cfg.refine_elite_spread_threshold
            return;
        end
        if cfg.local_refine_use_gap_gate
            elite_fit = fitness(elite_sorted(1:elite_count));
            gap = median(elite_fit) - min(elite_fit);
            if gap > cfg.refine_gap_ratio_threshold * (abs(best_fitness) + 1e-12)
                return;
            end
        end
    else
        if no_improve_count > cfg.local_refine_no_improve_max
            return;
        end
        if pop_diversity >= cfg.local_refine_diversity_threshold
            return;
        end
    end

    if rand > cfg.local_refine_prob
        return;
    end

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
