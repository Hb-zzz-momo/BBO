function [best_fitness, best_solution, Convergence_curve] = BBO_improved_v4(N, Max_iteration, lb, ub, dim, fobj)
% BBO_improved_v4
% Minimal-intrusion upgrade over V3 with paper-friendly motivations:
% 1) Fix population-fitness consistency by strict greedy commit semantics.
% 2) Refine existing elite differential local search using conditional trigger.
% 3) Propagate local-search gain into population via worst-individual replacement.
% 4) Keep baseline BBO-style main driver unchanged in structure.

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

    % Trigger is intentionally simple for interpretability.
    local_search_start = 0.55;
    stall_window = max(5, round(0.08 * Max_iteration));
    no_improve_count = 0;

    for t = 1:Max_iteration
        progress = t / Max_iteration;
        E = sin((pi / 2) * progress);
        improved_this_iter = false;

        [~, sorted_idx] = sort(fitness);
        architects_idx = sorted_idx(1:max(2, round(N * 0.25)));

        for i = 1:N
            old_position = population(i, :);
            old_fitness = fitness(i);
            trial = old_position;

            if rand < E
                for j = 1:dim
                    k = randi([1, N]);
                    while k == i
                        k = randi([1, N]);
                    end
                    trial(j) = trial(j) + rand * (population(k, j) - trial(j)) ...
                        + rand * (best_solution(j) - trial(j));
                end
            else
                if ismember(i, architects_idx)
                    for j = 1:dim
                        if rand < 0.5
                            k = architects_idx(randi(length(architects_idx)));
                            trial(j) = trial(j) + rand * (population(k, j) - trial(j));
                        end
                    end
                else
                    for j = 1:dim
                        if rand < 0.5
                            k = architects_idx(randi(length(architects_idx)));
                            trial(j) = trial(j) + rand * (population(k, j) - trial(j));
                        else
                            % Keep a tiny tail disturbance to avoid over-early freeze.
                            disturbance_scale = 0.10 * cos((pi / 2) * progress) + 0.02;
                            disturbance = disturbance_scale * (ub(j) - lb(j)) * randn;
                            trial(j) = trial(j) + disturbance;
                        end
                    end
                end
            end

            trial = max(trial, lb);
            trial = min(trial, ub);
            trial_fitness = fobj(trial);

            % Strict greedy commit keeps population/fitness ranking truthful.
            if trial_fitness < old_fitness
                population(i, :) = trial;
                fitness(i) = trial_fitness;

                if trial_fitness < best_fitness
                    best_fitness = trial_fitness;
                    best_solution = trial;
                    improved_this_iter = true;
                end
            else
                population(i, :) = old_position;
                fitness(i) = old_fitness;
            end
        end

        if improved_this_iter
            no_improve_count = 0;
        else
            no_improve_count = no_improve_count + 1;
        end

        elite_pool_size = max(4, round(0.2 * N));
        [~, elite_sorted] = sort(fitness);
        elite_pool = population(elite_sorted(1:elite_pool_size), :);

        if size(elite_pool, 1) >= 3
            stage = max(0, (progress - local_search_start) / max(1e-12, 1 - local_search_start));
            trigger_prob = 0.10 + 0.25 * stage;
            trigger_ls = (progress >= local_search_start) && ...
                (no_improve_count >= stall_window || rand < trigger_prob);

            if trigger_ls
                ids = randperm(size(elite_pool, 1), 3);
                e1 = elite_pool(ids(1), :);
                e2 = elite_pool(ids(2), :);
                e3 = elite_pool(ids(3), :);

                % Slow-then-fast schedule: keep exploration window, tighten late.
                F_max = 0.65;
                F_min = 0.18;
                F = F_max - (F_max - F_min) * (stage ^ 1.6);
                tail = 0.06 + 0.04 * (1 - stage);

                candidate = best_solution + F * (e1 - e2) + tail * randn(1, dim) .* (e3 - best_solution);
                candidate = max(candidate, lb);
                candidate = min(candidate, ub);

                candidate_fitness = fobj(candidate);

                % Propagate local-search gain into population to avoid isolated best-only update.
                [worst_fitness, worst_idx] = max(fitness);
                if candidate_fitness < worst_fitness
                    population(worst_idx, :) = candidate;
                    fitness(worst_idx) = candidate_fitness;
                end

                if candidate_fitness < best_fitness
                    best_fitness = candidate_fitness;
                    best_solution = candidate;
                    no_improve_count = 0;
                end
            end
        end

        Convergence_curve(t) = best_fitness;
    end
end