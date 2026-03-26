function [best_fitness, best_solution, Convergence_curve] = BBO_route_a_budget_adaptive_success_history_dispersal_bbo(N, Max_iteration, lb, ub, dim, fobj)
% BBO_route_a_budget_adaptive_success_history_dispersal_bbo
% Mainline C: Budget_adaptive + success-history + state-triggered controlled dispersal.
% Dispersal only triggers under stagnation state and only acts on a tail subset.

    ensure_module_paths();

    cfg = struct();
    cfg.algorithm_entry = 'BBO_route_a_budget_adaptive_success_history_dispersal_bbo';
    cfg.enable_archive = false;
    cfg.enable_replay = false;
    cfg.enable_success_history = true;
    cfg.enable_dispersal = true;

    % Conservative defaults for controlled dispersal.
    cfg.rescue = struct('stagnation_iters', 7, 'cooldown_iters', max(35, round(0.08 * Max_iteration)), 'max_triggers_per_run', 2);
    cfg.dispersal = struct('target_fraction', 0.08, 'elite_ratio', 0.20, 'rediffuse_ratio', 0.32, 'mix_best_ratio', 0.20);

    [best_fitness, best_solution, Convergence_curve] = route_a_budget_adaptive_nextgen_core( ...
        N, Max_iteration, lb, ub, dim, fobj, cfg);
end

function ensure_module_paths()
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    project_root = fileparts(fileparts(fileparts(fileparts(this_dir))));

    module_dir = fullfile(project_root, 'src', 'improved', 'modules', 'BBO');
    if exist(module_dir, 'dir') && isempty(strfind(path, module_dir)) %#ok<STREMP>
        addpath(module_dir);
    end
end
