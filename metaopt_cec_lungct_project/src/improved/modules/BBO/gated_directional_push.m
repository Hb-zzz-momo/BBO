function [population, fitness, best_fitness, best_solution, push_state] = gated_directional_push( ...
    population, fitness, best_fitness, best_solution, lb, ub, progress, no_improve_count, success_rate, pop_diversity, push_state, cfg, fobj)
% gated_directional_push
% Conditional short-term directional push adapted from v4-style direction idea.

    if ~cfg.enable_gated_directional_push
        return;
    end

    trigger_on = progress >= cfg.gdp_start_progress && ( ...
        no_improve_count >= cfg.gdp_trigger_stagnation || ...
        pop_diversity <= cfg.gdp_trigger_diversity || ...
        success_rate <= cfg.gdp_trigger_success);

    if trigger_on && push_state <= 0
        push_state = cfg.gdp_active_span;
    end

    if push_state <= 0
        return;
    end

    N = size(population, 1);
    target_count = max(1, round(cfg.gdp_target_ratio * N));

    [~, idx] = sort(fitness);
    elite_ratio = 0.2;
    if isfield(cfg, 'gdp_elite_ratio')
        elite_ratio = cfg.gdp_elite_ratio;
    end
    elite_count = max(4, round(elite_ratio * N));
    elite_pool = population(idx(1:elite_count), :);
    worst_ids = idx(end - target_count + 1:end);

    if size(elite_pool, 1) < 3
        push_state = push_state - 1;
        return;
    end

    ids = randperm(size(elite_pool, 1), 3);
    e1 = elite_pool(ids(1), :);
    e2 = elite_pool(ids(2), :);
    e3 = elite_pool(ids(3), :);

    ref_mode = "triad";
    if isfield(cfg, 'gdp_reference_mode')
        ref_mode = lower(string(cfg.gdp_reference_mode));
    end

    switch char(ref_mode)
        case 'blend_topk'
            blend_top = max(3, min(size(elite_pool, 1), round(0.5 * size(elite_pool, 1))));
            blend_weights = rand(1, blend_top);
            blend_weights = blend_weights / max(sum(blend_weights), eps);
            blend_ref = blend_weights * elite_pool(1:blend_top, :);
            direction = blend_ref - e3;
        otherwise
            direction = e1 - e2;
    end

    step_scale = 1.0;
    noise_scale = 1.0;
    if isfield(cfg, 'state_driven_enabled') && cfg.state_driven_enabled
        p1 = cfg.state_phase_1;
        p2 = cfg.state_phase_2;
        if progress < p1
            step_scale = cfg.state_early_step_scale;
            noise_scale = cfg.state_early_noise_scale;
        elseif progress < p2
            step_scale = cfg.state_mid_step_scale;
            noise_scale = cfg.state_mid_noise_scale;
        else
            step_scale = cfg.state_late_step_scale;
            noise_scale = cfg.state_late_noise_scale;
        end
    end

    span = ub - lb;
    span(span <= 1e-12) = 1;
    for k = 1:numel(worst_ids)
        i = worst_ids(k);
        old_pos = population(i, :);
        old_fit = fitness(i);

        step = step_scale * cfg.gdp_step_alpha * (1 - 0.55 * progress) .* direction;
        noise = noise_scale * cfg.gdp_noise_ratio * span .* randn(1, numel(span)) .* (e3 - old_pos);
        candidate = old_pos + step + noise;
        candidate = min(max(candidate, lb), ub);

        if ~all(isfinite(candidate))
            continue;
        end

        cand_fit = fobj(candidate);
        if cand_fit < old_fit
            population(i, :) = candidate;
            fitness(i) = cand_fit;
            if cand_fit < best_fitness
                best_fitness = cand_fit;
                best_solution = candidate;
            end
        end
    end

    push_state = push_state - 1;
end
