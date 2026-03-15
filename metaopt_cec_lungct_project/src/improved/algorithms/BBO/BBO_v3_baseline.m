function [best_fitness, best_solution, Convergence_curve] = BBO_v3_baseline(N, Max_iteration, lb, ub, dim, fobj)
% V3 baseline wrapper for dual-objective ablation study.
    [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3(N, Max_iteration, lb, ub, dim, fobj);
end
