function [best_fitness, best_solution, Convergence_curve] = BBO_route_a_pbest_gated_bbo(N, Max_iteration, lb, ub, dim, fobj)
% BBO_route_a_pbest_gated_bbo
% A_pbest_gated: combine p-best reference and gated differential activation.
% Boundary: no safe acceptance.

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

    pbest_ratio = 0.20;
    gate_p_min = 0.20;
    gate_p_max = 0.90;
    gate_start = 0.45;

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
        gate_prob = scheduled_gate(progress, gate_p_min, gate_p_max, gate_start);

        [~, sorted_idx] = sort(fitness);
        architects_idx = sorted_idx(1:max(2, round(N * 0.25)));
        pbest_k = max(2, round(N * pbest_ratio));
        pbest_k = min(pbest_k, N);
        pbest_pool = sorted_idx(1:pbest_k);

        for i = 1:N
            xi = population(i, :);
            pbest_ref = population(pbest_pool(randi(numel(pbest_pool))), :);

            bbo_trial = xi;
            if rand < E
                for j = 1:dim
                    k = randi([1, N]);
                    while k == i
                        k = randi([1, N]);
                    end
                    bbo_trial(j) = bbo_trial(j) + rand * (population(k, j) - bbo_trial(j)) ...
                        + rand * (pbest_ref(j) - bbo_trial(j));
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

            fb = fobj(bbo_trial);
            fd = inf;
            de_trial = xi;

            if rand < gate_prob
                [r1, r2, r3] = pick_three(N, i);
                gate_scale = 0.40 + 0.60 * progress;
                F_eff = gate_scale * F;
                donor = xi + beta_best * (pbest_ref - xi) + F_eff * (population(r1, :) - population(r2, :)) ...
                    + 0.5 * F_eff * (population(r3, :) - xi);

                jrand = randi(dim);
                for j = 1:dim
                    if rand < CR || j == jrand
                        de_trial(j) = donor(j);
                    end
                end
                de_trial = bound_clip(de_trial, lb, ub);
                fd = fobj(de_trial);
            end

            if fd < fb
                winner = de_trial;
                fw = fd;
            else
                winner = bbo_trial;
                fw = fb;
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

function gp = scheduled_gate(progress, gp_min, gp_max, gate_start)
    if progress <= gate_start
        gp = gp_min;
        return;
    end
    alpha = (progress - gate_start) / (1 - gate_start);
    gp = gp_min + (gp_max - gp_min) * alpha;
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
