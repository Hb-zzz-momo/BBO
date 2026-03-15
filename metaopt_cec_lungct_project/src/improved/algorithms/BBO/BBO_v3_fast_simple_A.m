function [best_fitness, best_solution, Convergence_curve] = BBO_v3_fast_simple_A(N, Max_iteration, lb, ub, dim, fobj)
% V3 fast-simple A: adaptive shrinkage + incumbent-centered late fine search.
    [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3_ablation_core( ...
        N, Max_iteration, lb, ub, dim, fobj, 'fast_simple_a');
end
