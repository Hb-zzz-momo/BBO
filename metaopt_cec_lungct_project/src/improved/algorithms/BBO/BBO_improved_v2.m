function [best_fitness, best_solution, Convergence_curve] = BBO_improved_v2(N, Max_iteration, lb, ub, dim, fobj)
% BBO_improved_v2
% Modification:
% 1) Stagnation-aware perturbation and partial restart.
% 2) Restart strength decays with progress.
% Motivation:
% Recover from long no-improvement phases and improve robustness on rugged landscapes.
% Target:
% Functions with frequent local trapping.
% Risk:
% Restarts can damage late-stage exploitation if triggered too often.

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

    no_improve_count = 0;
    stall_window = max(5, round(0.08 * Max_iteration));

    for t = 1:Max_iteration
        progress = t / Max_iteration;
        E = sin((pi / 2) * progress);
        improved_this_iter = false;

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
                    improved_this_iter = true;
                end
            end
        end

        if improved_this_iter
            no_improve_count = 0;
        else
            no_improve_count = no_improve_count + 1;
        end

        if no_improve_count >= stall_window
            restart_count = max(1, round(0.2 * N));
            [~, idx_sort] = sort(fitness, 'descend');
            worst_idx = idx_sort(1:restart_count);
            restart_sigma = 0.25 * (1 - progress) + 0.02;
            for r = 1:restart_count
                i = worst_idx(r);
                candidate = best_solution + restart_sigma * (ub - lb) .* randn(1, dim);
                candidate = max(candidate, lb);
                candidate = min(candidate, ub);
                cand_fit = fobj(candidate);
                population(i, :) = candidate;
                fitness(i) = cand_fit;
                if cand_fit < best_fitness
                    best_fitness = cand_fit;
                    best_solution = candidate;
                end
            end
            no_improve_count = 0;
        end

        Convergence_curve(t) = best_fitness;
    end
end
