function [best_fitness, best_solution, Convergence_curve] = BBO_v3_dir_stagnation(N, Max_iteration, lb, ub, dim, fobj)
% V3 directional module: activated by stagnation signal.
    [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3_ablation_core( ...
        N, Max_iteration, lb, ub, dim, fobj, 'dir_stagnation');
end
