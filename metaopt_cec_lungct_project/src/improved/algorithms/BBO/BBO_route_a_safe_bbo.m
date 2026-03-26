function [best_fitness, best_solution, Convergence_curve] = BBO_route_a_safe_bbo(N, Max_iteration, lb, ub, dim, fobj)
% BBO_route_a_safe_bbo
% A_safe: add safe acceptance with shrink-and-recheck fallback.
% Boundary: no p-best reference, no gated differential activation.

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

    safe_step_limit = 0.35;
    safe_shrink = 0.35;
    late_guard_start = 0.70;
    late_step_limit = 0.10;
    late_f_scale_min = 0.35;
    late_disturb_scale_min = 0.25;

    range_norm = norm(ub - lb) + eps;

    population = lb + (ub - lb) .* rand(N, dim);
    fitness = zeros(N, 1);
    for i = 1:N
        fitness(i) = fobj(population(i, :));
    end

    [best_fitness, best_idx] = min(fitness);
    best_solution = population(best_idx, :);
    Convergence_curve = zeros(1, Max_iteration);

    for t = 1:Max_iteration
        progress = t / Max_iteration;
        E = sin((pi / 2) * progress);
        F = F_max - (F_max - F_min) * progress;
        [F, disturb_scale, active_step_limit] = late_stage_guard( ...
            progress, F, safe_step_limit, late_guard_start, late_step_limit, late_f_scale_min, late_disturb_scale_min);
        CR = scheduled_cr(progress, CR_max, CR_min, cr_shrink_start);
        [~, sorted_idx] = sort(fitness);
        architects_idx = sorted_idx(1:max(2, round(N * 0.25)));

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
                            disturbance = disturb_scale * cos((pi / 2) * progress) * (ub(j) - lb(j)) * randn / 10;
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

            if isfinite(fw) && fw < fitness(i)
                accepted = winner;
                accepted_f = fw;

                move_ratio = norm(accepted - xi) / range_norm;
                if move_ratio > active_step_limit
                    shrink_factor = safe_shrink * active_step_limit / max(move_ratio, eps);
                    shrink_factor = min(shrink_factor, safe_shrink);
                    shrink_factor = max(shrink_factor, 0.10);
                    safe_trial = xi + shrink_factor * (accepted - xi);
                    safe_trial = bound_clip(safe_trial, lb, ub);
                    fs = fobj(safe_trial);
                    if isfinite(fs) && fs < accepted_f
                        accepted = safe_trial;
                        accepted_f = fs;
                    end
                end

                if accepted_f < fitness(i)
                    population(i, :) = accepted;
                    fitness(i) = accepted_f;
                    if accepted_f < best_fitness
                        best_fitness = accepted_f;
                        best_solution = accepted;
                    end
                end
            end
        end

        Convergence_curve(t) = best_fitness;
    end
end

function [F_eff, disturb_scale, step_limit] = late_stage_guard(progress, F_raw, base_step_limit, guard_start, late_step_limit, f_scale_min, disturb_scale_min)
    F_eff = F_raw;
    disturb_scale = 1.0;
    step_limit = base_step_limit;

    if progress <= guard_start
        return;
    end

    alpha = (progress - guard_start) / (1 - guard_start);
    alpha = max(0, min(1, alpha));

    % Late stage anti-explosion guard:
    % 1) compress differential step size,
    % 2) compress Gaussian disturbance,
    % 3) tighten safe acceptance step limit.
    f_scale = 1 - (1 - f_scale_min) * alpha;
    F_eff = F_raw * f_scale;
    disturb_scale = 1 - (1 - disturb_scale_min) * alpha;
    step_limit = base_step_limit - (base_step_limit - late_step_limit) * alpha;
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
