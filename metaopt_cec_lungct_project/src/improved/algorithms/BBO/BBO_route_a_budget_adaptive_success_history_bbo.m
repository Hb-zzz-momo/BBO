function [best_fitness, best_solution, Convergence_curve] = BBO_route_a_budget_adaptive_success_history_bbo(N, Max_iteration, lb, ub, dim, fobj)
% BBO_route_a_budget_adaptive_success_history_bbo
% Mainline B: Budget_adaptive + success-history step adaptation.
% No archive/replay/dispersal in this version.

    ensure_module_paths();

    cfg = struct();
    cfg.algorithm_entry = 'BBO_route_a_budget_adaptive_success_history_bbo';
    cfg.enable_archive = false;
    cfg.enable_replay = false;
    cfg.enable_success_history = true;
    cfg.enable_dispersal = false;

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
