function [best_fitness, best_solution, Convergence_curve] = BBO_improved_v1(N, Max_iteration, lb, ub, dim, fobj)
% BBO_improved_v1
% V1 mainline + controllable modules:
% 1) selective_elite_learning
% 2) gated_directional_push
% 3) anti_stagnation_escape
% The benchmark call signature and FE-control semantics remain unchanged.

    if any(size(lb) == 1)
        lb = lb .* ones(1, dim);
        ub = ub .* ones(1, dim);
    end

    ensure_v1_module_paths();
    runtime_cfg = load_v1_runtime_cfg(Max_iteration);

    population = lb + (ub - lb) .* rand(N, dim);
    fitness = zeros(N, 1);
    for i = 1:N
        fitness(i) = fobj(population(i, :));
    end

    [best_fitness, idx] = min(fitness);
    best_solution = population(idx, :);
    Convergence_curve = zeros(1, Max_iteration);
    stagnation_age = zeros(N, 1);
    no_improve_count = 0;
    directional_push_state = 0;

    for t = 1:Max_iteration
        progress = t / Max_iteration;
        E = sin((pi / 2) * (progress ^ 0.85));
        improved_this_iter = false;
        accepted_count = 0;

        architect_ratio = 0.15 + 0.20 * (1 - progress);
        architect_count = max(2, min(N, round(N * architect_ratio)));

        [~, sorted_idx] = sort(fitness);
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

            trial = max(trial, lb);
            trial = min(trial, ub);

            new_fitness = fobj(trial);
            if new_fitness < old_fitness
                population(i, :) = trial;
                fitness(i) = new_fitness;
                stagnation_age(i) = 0;
                accepted_count = accepted_count + 1;

                [population(i, :), sel_accepted, sel_fit] = selective_elite_learning( ...
                    population(i, :), old_position, old_fitness, population, fitness, best_solution, ...
                    lb, ub, progress, runtime_cfg, fobj);
                if sel_accepted
                    fitness(i) = sel_fit;
                end

                if new_fitness < best_fitness
                    best_fitness = new_fitness;
                    best_solution = population(i, :);
                    improved_this_iter = true;
                end
                if sel_accepted && fitness(i) < best_fitness
                    best_fitness = fitness(i);
                    best_solution = population(i, :);
                    improved_this_iter = true;
                end
            else
                population(i, :) = old_position;
                fitness(i) = old_fitness;
                stagnation_age(i) = stagnation_age(i) + 1;
            end
        end

        no_improve_count = stagnation_detector(improved_this_iter, no_improve_count);
        pop_diversity = diversity_metric(population, lb, ub);
        success_rate = accepted_count / max(1, N);

        [population, fitness, best_fitness, best_solution, directional_push_state] = gated_directional_push( ...
            population, fitness, best_fitness, best_solution, lb, ub, progress, ...
            no_improve_count, success_rate, pop_diversity, directional_push_state, runtime_cfg, fobj);

        [population, fitness, best_fitness, best_solution, stagnation_age] = anti_stagnation_escape( ...
            population, fitness, best_fitness, best_solution, stagnation_age, lb, ub, progress, ...
            no_improve_count, success_rate, pop_diversity, runtime_cfg, fobj);

        Convergence_curve(t) = best_fitness;
    end
end

function ensure_v1_module_paths()
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
    end
end

function cfg = load_v1_runtime_cfg(max_iter)
    mode = "v1_full";
    runtime_cfg = [];

    if isappdata(0, 'BBO_V1_RUNTIME_CFG')
        runtime_cfg = getappdata(0, 'BBO_V1_RUNTIME_CFG');
        if isstruct(runtime_cfg) && isfield(runtime_cfg, 'mode')
            mode = string(runtime_cfg.mode);
        end
    end

    cfg = v1_module_config_factory(mode, max_iter);
    if isstruct(runtime_cfg)
        cfg = apply_runtime_override(cfg, runtime_cfg);
    end
end

function cfg = apply_runtime_override(cfg, runtime_cfg)
    fields = fieldnames(runtime_cfg);
    for i = 1:numel(fields)
        key = fields{i};
        if strcmpi(key, 'mode')
            continue;
        end
        if isfield(cfg, key)
            cfg.(key) = runtime_cfg.(key);
        end
    end
end
