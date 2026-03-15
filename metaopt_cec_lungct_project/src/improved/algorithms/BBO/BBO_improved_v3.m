function [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3(N, Max_iteration, lb, ub, dim, fobj)
% BBO_improved_v3
% Modification:
% 1) Elite differential local search around incumbent best.
% 2) Keep baseline BBO body unchanged as main driver.
% Motivation:
% Strengthen late exploitation while preserving original BBO dynamics.
% Target:
% Functions where baseline converges but final precision is weak.
% Risk:
% Additional local search can reduce diversity if overused.

    if any(size(lb) == 1)
        lb = lb .* ones(1, dim);
        ub = ub .* ones(1, dim);
    end

    population = lb + (ub - lb) .* rand(N, dim);
    fitness = zeros(N, 1);
    for i = 1:N
        fitness(i) = fobj(population(i, :));
    end

    [best_fitness, idx] = min(fitness);
    best_solution = population(idx, :);
    Convergence_curve = zeros(1, Max_iteration);

    for t = 1:Max_iteration
        progress = t / Max_iteration;
        E = sin((pi / 2) * progress);

        [~, sorted_idx] = sort(fitness);
        architects_idx = sorted_idx(1:max(2, round(N * 0.25)));

        for i = 1:N
            if rand < E
                for j = 1:dim
                    k = randi([1, N]);
                    while k == i
                        k = randi([1, N]);
                    end
                    population(i, j) = population(i, j) + rand * (population(k, j) - population(i, j)) ...
                        + rand * (best_solution(j) - population(i, j));
                end
            else
                if ismember(i, architects_idx)
                    for j = 1:dim
                        if rand < 0.5
                            k = architects_idx(randi(length(architects_idx)));
                            population(i, j) = population(i, j) + rand * (population(k, j) - population(i, j));
                        end
                    end
                else
                    for j = 1:dim
                        if rand < 0.5
                            k = architects_idx(randi(length(architects_idx)));
                            population(i, j) = population(i, j) + rand * (population(k, j) - population(i, j));
                        else
                            disturbance = cos((pi / 2) * progress) * (ub(j) - lb(j)) * randn / 10;
                            population(i, j) = population(i, j) + disturbance;
                        end
                    end
                end
            end

            population(i, :) = max(population(i, :), lb);
            population(i, :) = min(population(i, :), ub);

            new_fitness = fobj(population(i, :));
            if new_fitness < fitness(i)
                fitness(i) = new_fitness;
                if new_fitness < best_fitness
                    best_fitness = new_fitness;
                    best_solution = population(i, :);
                end
            end
        end

        elite_pool_size = max(4, round(0.2 * N));
        [~, elite_sorted] = sort(fitness);
        elite_pool = population(elite_sorted(1:elite_pool_size), :);

        if size(elite_pool, 1) >= 3
            ids = randperm(size(elite_pool, 1), 3);
            e1 = elite_pool(ids(1), :);
            e2 = elite_pool(ids(2), :);
            e3 = elite_pool(ids(3), :);

            F = 0.6 - 0.4 * progress;
            candidate = best_solution + F * (e1 - e2) + 0.1 * rand(1, dim) .* (e3 - best_solution);
            candidate = max(candidate, lb);
            candidate = min(candidate, ub);

            candidate_fitness = fobj(candidate);
            if candidate_fitness < best_fitness
                best_fitness = candidate_fitness;
                best_solution = candidate;
            end
        end

        Convergence_curve(t) = best_fitness;
    end
end
