function plot_cfg = rac_finalize_plot_config_for_suite(plot_cfg, selected_func_ids, selected_algorithms)
    if isempty(plot_cfg.selected_funcs)
        plot_cfg.selected_funcs_resolved = selected_func_ids;
    else
        plot_cfg.selected_funcs_resolved = intersect(selected_func_ids, plot_cfg.selected_funcs, 'stable');
    end

    selected_algorithms = upper(cellstr(string(selected_algorithms)));
    if isempty(plot_cfg.selected_algorithms)
        plot_cfg.selected_algorithms_resolved = selected_algorithms;
    else
        requested_algs = upper(cellstr(string(plot_cfg.selected_algorithms)));
        plot_cfg.selected_algorithms_resolved = intersect(selected_algorithms, requested_algs, 'stable');
    end

    behavior_funcs = plot_cfg.selected_funcs_resolved;
    if numel(behavior_funcs) > plot_cfg.behavior.max_funcs
        behavior_funcs = behavior_funcs(1:plot_cfg.behavior.max_funcs);
    end
    plot_cfg.behavior.capture_func_ids = behavior_funcs;
    plot_cfg.behavior.capture_algorithms = upper(cellstr(string(plot_cfg.behavior.only_for_algorithms)));
end
