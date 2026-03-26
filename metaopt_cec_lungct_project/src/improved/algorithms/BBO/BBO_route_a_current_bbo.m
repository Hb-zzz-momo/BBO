function [best_fitness, best_solution, Convergence_curve] = BBO_route_a_current_bbo(N, Max_iteration, lb, ub, dim, fobj)
% BBO_route_a_current_bbo
% A_current: keep current Route A behavior unchanged.

    [best_fitness, best_solution, Convergence_curve] = BBO_route_a_differential_generator_bbo(N, Max_iteration, lb, ub, dim, fobj);
end
