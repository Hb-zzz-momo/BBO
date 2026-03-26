function [trial, accepted, trial_fitness] = selective_elite_learning( ...
    trial, old_position, old_fitness, population, fitness, best_solution, lb, ub, progress, cfg, fobj)
% selective_elite_learning
% Selective elite learning: top-k pool reference + partial-dimension update + greedy keep.

    accepted = false;
    trial_fitness = old_fitness;

    if ~cfg.enable_selective_elite_learning
        return;
    end

    if rand > cfg.sel_apply_prob
        return;
    end

    N = size(population, 1);
    dim = size(population, 2);
    top_k = max(3, min(N, round(cfg.sel_topk_ratio * N)));
    [~, idx] = sort(fitness);
    elite_pool = population(idx(1:top_k), :);

    ref = elite_pool(randi(size(elite_pool, 1)), :);

    dim_ratio = cfg.sel_dim_ratio_early - (cfg.sel_dim_ratio_early - cfg.sel_dim_ratio_late) * progress;
    dim_ratio = min(1, max(1 / max(1, dim), dim_ratio));
    mask = rand(1, dim) < dim_ratio;
    if ~any(mask)
        mask(randi(dim)) = true;
    end

    candidate = trial;
    candidate(mask) = old_position(mask) ...
        + cfg.sel_step_ref * rand(1, nnz(mask)) .* (ref(mask) - old_position(mask)) ...
        + cfg.sel_step_best * rand(1, nnz(mask)) .* (best_solution(mask) - old_position(mask));

    candidate = min(max(candidate, lb), ub);
    if ~all(isfinite(candidate))
        return;
    end

    cand_fit = fobj(candidate);
    if cand_fit < old_fitness
        trial = candidate;
        trial_fitness = cand_fit;
        accepted = true;
    end
end
