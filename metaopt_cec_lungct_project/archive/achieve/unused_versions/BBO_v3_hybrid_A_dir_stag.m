function [best_fitness, best_solution, Convergence_curve] = BBO_v3_hybrid_A_dir_stag(N, Max_iteration, lb, ub, dim, fobj)
% Hybrid A: fast-simple A plus stagnation-triggered directional module.
    [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3_ablation_core( ...
        N, Max_iteration, lb, ub, dim, fobj, 'hybrid_a_dir_stag');
end
