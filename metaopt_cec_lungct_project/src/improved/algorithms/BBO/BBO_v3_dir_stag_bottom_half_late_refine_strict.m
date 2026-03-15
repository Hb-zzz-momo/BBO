function [best_fitness, best_solution, Convergence_curve] = BBO_v3_dir_stag_bottom_half_late_refine_strict(N, Max_iteration, lb, ub, dim, fobj)
% Compatibility alias to strict clipped directional variant for ablation naming.
    [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3_ablation_core( ...
        N, Max_iteration, lb, ub, dim, fobj, 'dir_clipped_stag_bottom_half_late_refine');
end
