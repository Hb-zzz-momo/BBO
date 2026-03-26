function [best_fitness, best_solution, Convergence_curve] = BBO_route_c_success_history_pool_bbo(N, Max_iteration, lb, ub, dim, fobj)
% Archived implementation placeholder.

    persistent warned_once;
    if isempty(warned_once)
        warning('ROUTE_C_ARCHIVED: Route C archived to archive/achieve/unused_versions; fallback to V3 baseline kernel.');
        warned_once = true;
    end

    [best_fitness, best_solution, Convergence_curve] = BBO_v3_baseline(N, Max_iteration, lb, ub, dim, fobj);
end
