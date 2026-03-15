function [best_fitness, best_solution, Convergence_curve] = BBO_v3_hybrid_B_dir_small(N, Max_iteration, lb, ub, dim, fobj)
% Hybrid B: fast-simple B plus conservative small-step directional module.
    [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3_ablation_core( ...
        N, Max_iteration, lb, ub, dim, fobj, 'hybrid_b_dir_small');
end
