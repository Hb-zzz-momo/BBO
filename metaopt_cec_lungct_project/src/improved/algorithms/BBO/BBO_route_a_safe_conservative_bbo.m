function [best_fitness, best_solution, Convergence_curve] = BBO_route_a_safe_conservative_bbo(N, Max_iteration, lb, ub, dim, fobj)
% BBO_route_a_safe_conservative_bbo
% Direction 2: keep SAFE line with conservative style.
% Design constraints:
% 1) Small step, small disturbance.
% 2) Strong move constraint and shrink-and-recheck acceptance.
% 3) No p-best, no gated scheduling.

    if any(size(lb) == 1)
        lb = lb .* ones(1, dim);
        ub = ub .* ones(1, dim);
    end

    F_max = 0.65;
    F_min = 0.30;
    CR_max = 0.85;
    CR_min = 0.50;
    cr_shrink_start = 0.6;
    beta_best = 0.18;

    safe_step_limit = 0.20;
    safe_shrink = 0.25;
    donor_step_cap_ratio = 0.15;

    range_vec = ub - lb;
    range_norm = norm(range_vec) + eps;

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
                    bbo_trial(j) = bbo_trial(j) + 0.8 * rand * (population(k, j) - bbo_trial(j)) ...
                        + 0.6 * rand * (best_solution(j) - bbo_trial(j));
                end
            else
                if ismember(i, architects_idx)
                    for j = 1:dim
                        if rand < 0.5
                            k = architects_idx(randi(length(architects_idx)));
                            bbo_trial(j) = bbo_trial(j) + 0.6 * rand * (population(k, j) - bbo_trial(j));
                        end
                    end
                else
                    for j = 1:dim
                        if rand < 0.5
                            k = architects_idx(randi(length(architects_idx)));
                            bbo_trial(j) = bbo_trial(j) + 0.6 * rand * (population(k, j) - bbo_trial(j));
                        else
                            disturbance = 0.6 * cos((pi / 2) * progress) * (ub(j) - lb(j)) * randn / 14;
                            bbo_trial(j) = bbo_trial(j) + disturbance;
                        end
                    end
                end
            end
            bbo_trial = bound_clip(bbo_trial, lb, ub);

            [r1, r2, r3] = pick_three(N, i);
            donor = xi + beta_best * (best_solution - xi) + F * (population(r1, :) - population(r2, :)) ...
                + 0.35 * F * (population(r3, :) - xi);

            donor_delta = donor - xi;
            donor_cap = donor_step_cap_ratio * range_vec;
            donor = xi + max(min(donor_delta, donor_cap), -donor_cap);

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
                if move_ratio > safe_step_limit
                    shrink_factor = safe_shrink * safe_step_limit / max(move_ratio, eps);
                    shrink_factor = min(shrink_factor, safe_shrink);
                    shrink_factor = max(shrink_factor, 0.08);
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
