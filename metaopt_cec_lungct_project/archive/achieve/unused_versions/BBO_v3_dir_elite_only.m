function [best_fitness, best_solution, Convergence_curve] = BBO_v3_dir_elite_only(N, Max_iteration, lb, ub, dim, fobj)
% V3 directional module: elite-only directional vector construction.
    [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3_ablation_core( ...
        N, Max_iteration, lb, ub, dim, fobj, 'dir_elite_only');
end
