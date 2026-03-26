function [population, fitness, best_fitness, best_solution, stagnation_age] = anti_stagnation_escape( ...
    population, fitness, best_fitness, best_solution, stagnation_age, lb, ub, progress, no_improve_count, success_rate, pop_diversity, cfg, fobj)
% anti_stagnation_escape
% Lightweight escape module for hybrid/composition stagnation recovery.

    if ~cfg.enable_anti_stagnation_escape
        return;
    end
    if isfield(cfg, 'escape_conditional_enabled') && cfg.escape_conditional_enabled
        hit_count = 0;

        if (~isfield(cfg, 'escape_use_stagnation_cond') || cfg.escape_use_stagnation_cond) ...
                && no_improve_count >= cfg.escape_trigger_stagnation
            hit_count = hit_count + 1;
        end

        if (~isfield(cfg, 'escape_use_stage_cond') || cfg.escape_use_stage_cond) ...
                && progress >= cfg.escape_stage_progress
            hit_count = hit_count + 1;
        end

        if (~isfield(cfg, 'escape_use_diversity_cond') || cfg.escape_use_diversity_cond) ...
                && pop_diversity <= cfg.escape_diversity_threshold
            hit_count = hit_count + 1;
        end

        if (~isfield(cfg, 'escape_use_success_cond') || cfg.escape_use_success_cond) ...
                && success_rate <= cfg.escape_success_threshold
            hit_count = hit_count + 1;
        end

        min_hits = 2;
        if isfield(cfg, 'escape_cond_min_hits')
            min_hits = cfg.escape_cond_min_hits;
        end
        if hit_count < min_hits
            return;
        end
    else
        if progress < cfg.escape_start_progress
            return;
        end
        if no_improve_count < cfg.escape_trigger_stagnation
            return;
        end
    end

    N = size(population, 1);
    dim = size(population, 2);
    target_count = max(1, round(cfg.escape_target_ratio * N));
    elite_count = max(3, round(cfg.escape_elite_ratio * N));

    [~, idx] = sort(fitness);
    elite_ids = idx(1:elite_count);
    worst_ids = idx(end - target_count + 1:end);

    elite_stagnant = elite_ids(stagnation_age(elite_ids) >= cfg.escape_stagnant_age);

    target_scope = 'both';
    if isfield(cfg, 'escape_target_scope')
        target_scope = lower(string(cfg.escape_target_scope));
    end

    switch char(target_scope)
        case 'stagnant_elites'
            targets = elite_stagnant(:);
        case 'worst'
            targets = worst_ids(:);
        otherwise
            targets = unique([elite_stagnant(:); worst_ids(:)], 'stable');
    end
    if isempty(targets)
        return;
    end

    elite_centroid = mean(population(elite_ids, :), 1);
    span = ub - lb;
    span(span <= 1e-12) = 1;

    for p = 1:numel(targets)
        i = targets(p);
        old_pos = population(i, :);
        old_fit = fitness(i);

        mate = population(idx(randi(elite_count)), :);

        levy = tan(pi * (rand(1, dim) - 0.5));
        levy = max(min(levy, 5), -5);

        rediffuse = lb + rand(1, dim) .* (ub - lb);
        candidate = old_pos ...
            + cfg.escape_levy_scale * (1 - 0.4 * progress) .* span .* levy ...
            + 0.35 * rand(1, dim) .* (elite_centroid - old_pos) ...
            + 0.25 * rand(1, dim) .* (mate - old_pos);
        candidate = (1 - cfg.escape_rediffuse_ratio) .* candidate + cfg.escape_rediffuse_ratio .* rediffuse;

        candidate = min(max(candidate, lb), ub);
        if ~all(isfinite(candidate))
            continue;
        end

        cand_fit = fobj(candidate);
        if cand_fit < old_fit
            population(i, :) = candidate;
            fitness(i) = cand_fit;
            stagnation_age(i) = 0;
            if cand_fit < best_fitness
                best_fitness = cand_fit;
                best_solution = candidate;
            end
        end
    end
end
