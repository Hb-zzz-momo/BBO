function [best_fitness, best_solution, Convergence_curve] = BBO_v3_dir_late(N, Max_iteration, lb, ub, dim, fobj)
% V3 directional module: active mainly in late stage.
    [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3_ablation_core( ...
        N, Max_iteration, lb, ub, dim, fobj, 'dir_late');
end
