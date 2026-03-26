function [best_fitness, best_solution, Convergence_curve] = BBO_route_b_dual_population_bbo(N, Max_iteration, lb, ub, dim, fobj)
% Archived implementation placeholder.

    persistent warned_once;
    if isempty(warned_once)
        warning('ROUTE_B_ARCHIVED: Route B archived to archive/achieve/unused_versions; fallback to V3 baseline kernel.');
        warned_once = true;
    end

    [best_fitness, best_solution, Convergence_curve] = BBO_v3_baseline(N, Max_iteration, lb, ub, dim, fobj);
end
