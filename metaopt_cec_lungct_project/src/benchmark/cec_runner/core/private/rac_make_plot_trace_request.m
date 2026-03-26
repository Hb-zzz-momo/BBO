function trace_request = rac_make_plot_trace_request(plot_cfg, algorithm_name, fid, dim)
    trace_request = rac_make_trace_request_template();
    if ~plot_cfg.enable || ~has_behavior_plot_enabled_local(plot_cfg)
        return;
    end

    alg_name = upper(string(algorithm_name));
    if ~ismember(fid, plot_cfg.behavior.capture_func_ids)
        return;
    end
    if ~ismember(char(alg_name), plot_cfg.behavior.capture_algorithms)
        return;
    end
    if ~ismember(char(alg_name), plot_cfg.selected_algorithms_resolved)
        return;
    end
    trace_request.enable = true;
    trace_request.capture_mean_fitness = plot_cfg.types.mean_fitness || plot_cfg.types.search_process_overview;
    trace_request.capture_first_dim = plot_cfg.types.trajectory_first_dim || plot_cfg.types.search_process_overview;
    trace_request.capture_final_population = (plot_cfg.types.final_population || plot_cfg.types.search_process_overview) && ...
        (~plot_cfg.behavior.require_dim2 || dim == 2);
    trace_request.position_dims = min(dim, 2);
end

function tf = has_behavior_plot_enabled_local(plot_cfg)
    tf = plot_cfg.types.search_process_overview || plot_cfg.types.mean_fitness || ...
        plot_cfg.types.trajectory_first_dim || plot_cfg.types.final_population;
end
