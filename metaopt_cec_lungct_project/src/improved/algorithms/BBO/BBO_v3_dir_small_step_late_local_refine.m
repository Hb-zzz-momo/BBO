function [best_fitness, best_solution, Convergence_curve] = BBO_v3_dir_small_step_late_local_refine(N, Max_iteration, lb, ub, dim, fobj)
% V3 directional small-step + late contraction-style local refine.
    [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3_ablation_core( ...
        N, Max_iteration, lb, ub, dim, fobj, 'dir_small_step_late_local_refine');
end
