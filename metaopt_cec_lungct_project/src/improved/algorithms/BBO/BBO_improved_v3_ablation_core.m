function [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3_ablation_core(N, Max_iteration, lb, ub, dim, fobj, mode)
% BBO_improved_v3_ablation_core
% Shared core for dual-objective ablation around v3:
% 1) simple-function convergence enhancement modules
% 2) conservative, condition-triggered directional modules

    if nargin < 7 || isempty(mode)
        mode = 'baseline';
    end
    mode = lower(string(mode));

    if any(size(lb) == 1)
        lb = lb .* ones(1, dim);
        ub = ub .* ones(1, dim);
    end

    ensure_module_paths();
    cfg = mode_config_factory(mode, Max_iteration);

    population = lb + (ub - lb) .* rand(N, dim);
    fitness = zeros(N, 1);
    for i = 1:N
        fitness(i) = fobj(population(i, :));
    end

    [best_fitness, idx] = min(fitness);
    best_solution = population(idx, :);
    Convergence_curve = zeros(1, Max_iteration);

    no_improve_count = 0;

    for t = 1:Max_iteration
        progress = t / Max_iteration;
        E = sin((pi / 2) * progress);
        improved_this_iter = false;

        [~, sorted_idx] = sort(fitness);
        architect_count = max(2, round(N * 0.25));
        architects_idx = sorted_idx(1:architect_count);

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
                            disturbance = cos((pi / 2) * progress) * (ub(j) - lb(j)) * randn / 10;
                            trial(j) = trial(j) + disturbance;
                        end
                    end
                end
            end

            trial = apply_simple_modules(trial, old_position, best_solution, progress, lb, ub, cfg);
            trial = max(trial, lb);
            trial = min(trial, ub);

            if ~all(isfinite(trial))
                trial = old_position;
            end

            trial_fitness = fobj(trial);
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

        no_improve_count = stagnation_detector(improved_this_iter, no_improve_count);
        pop_diversity = diversity_metric(population, lb, ub);

        [population, fitness, best_fitness, best_solution, no_improve_count] = ...
            directional_update(population, fitness, best_fitness, best_solution, ...
            progress, no_improve_count, pop_diversity, lb, ub, cfg, fobj);

        [population, fitness, best_fitness, best_solution] = ...
            local_refine(population, fitness, best_fitness, best_solution, ...
            progress, no_improve_count, pop_diversity, lb, ub, cfg, fobj);

        Convergence_curve(t) = best_fitness;
    end
end

function ensure_module_paths()
    this_file = mfilename('fullpath');
    bbo_alg_dir = fileparts(this_file);
    improved_root = fileparts(bbo_alg_dir);
    src_root = fileparts(improved_root);
    module_root = fullfile(src_root, 'modules');
    bbo_module_dir = fullfile(module_root, 'BBO');

    if isfolder(module_root)
        addpath(module_root);
    end
    if isfolder(bbo_module_dir)
        addpath(bbo_module_dir);
    else
        error('BBO module directory not found: %s', bbo_module_dir);
    end
end
