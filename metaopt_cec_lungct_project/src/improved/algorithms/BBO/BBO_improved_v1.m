function [best_fitness, best_solution, Convergence_curve] = BBO_improved_v1(N, Max_iteration, lb, ub, dim, fobj)
% BBO_improved_v1
% Modification:
% 1) Adaptive architect ratio over iterations.
% 2) Smoother exploration->exploitation schedule.
% Motivation:
% Reduce premature exploitation on complex landscapes while keeping late-stage convergence.
% Target:
% Functions where early diversity is critical.
% Risk:
% Too much exploration may slow convergence on easy unimodal functions.

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
        E = sin((pi / 2) * (progress ^ 0.85));

        architect_ratio = 0.15 + 0.20 * (1 - progress);
        architect_count = max(2, min(N, round(N * architect_ratio)));

        [~, sorted_idx] = sort(fitness);
        architects_idx = sorted_idx(1:architect_count);

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

        Convergence_curve(t) = best_fitness;
    end
end
