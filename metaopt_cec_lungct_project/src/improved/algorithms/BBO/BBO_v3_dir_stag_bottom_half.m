function [best_fitness, best_solution, Convergence_curve] = BBO_v3_dir_stag_bottom_half(N, Max_iteration, lb, ub, dim, fobj)
% V3 directional module: stagnation trigger + apply direction on bottom-half only.
    [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3_ablation_core( ...
        N, Max_iteration, lb, ub, dim, fobj, 'dir_stag_bottom_half');
end
