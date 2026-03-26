function [best_fitness, best_solution, Convergence_curve] = BBO_route_a_sel_gdp_reference(N, Max_iteration, lb, ub, dim, fobj)
% BBO_route_a_sel_gdp_reference
% Route A minimal prototype:
% keep SEL + GDP as reference line, disable ESC.

    runtime_cfg = struct( ...
        'mode', 'v1_full', ...
        'enable_selective_elite_learning', true, ...
        'enable_gated_directional_push', true, ...
        'enable_anti_stagnation_escape', false);

    [best_fitness, best_solution, Convergence_curve] = run_v1_with_runtime_cfg( ...
        runtime_cfg, N, Max_iteration, lb, ub, dim, fobj);
end

function [best_fitness, best_solution, Convergence_curve] = run_v1_with_runtime_cfg(runtime_cfg, N, Max_iteration, lb, ub, dim, fobj)
    old_exists = isappdata(0, 'BBO_V1_RUNTIME_CFG');
    if old_exists
        old_cfg = getappdata(0, 'BBO_V1_RUNTIME_CFG');
    else
        old_cfg = [];
    end

    setappdata(0, 'BBO_V1_RUNTIME_CFG', runtime_cfg);
    cleanup_obj = onCleanup(@() restore_runtime_cfg(old_exists, old_cfg)); %#ok<NASGU>

    [best_fitness, best_solution, Convergence_curve] = BBO_improved_v1(N, Max_iteration, lb, ub, dim, fobj);
end

function restore_runtime_cfg(old_exists, old_cfg)
    if old_exists
        setappdata(0, 'BBO_V1_RUNTIME_CFG', old_cfg);
    else
        if isappdata(0, 'BBO_V1_RUNTIME_CFG')
            rmappdata(0, 'BBO_V1_RUNTIME_CFG');
        end
    end
end
