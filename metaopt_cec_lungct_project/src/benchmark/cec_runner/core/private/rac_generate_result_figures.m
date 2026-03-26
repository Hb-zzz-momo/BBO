function rac_generate_result_figures(run_results, summary_table, cfg, result_dir, run_log_file)
% rac_generate_result_figures
% Thin plotting dispatcher that routes chart generation to dedicated modules.

    if ~cfg.plot.enable
        rac_log_message(run_log_file, '[Plot] Plot module disabled.');
        return;
    end

    plot_log_file = fullfile(result_dir.logs, 'plot_generation.log');
    rac_log_message(plot_log_file, sprintf('[Plot] enabled=1 show=%d save=%d', cfg.plot.show, cfg.plot.save));

    if isempty(run_results)
        rac_log_message(plot_log_file, '[Plot] Skip plot generation because run_results is empty.');
        return;
    end

    plot_dirs = init_plot_dirs_local(result_dir, cfg);
    filtered_runs = filter_run_results_for_plot_local(run_results, cfg.plot);
    filtered_summary = filter_summary_for_plot_local(summary_table, cfg.plot);

    if isempty(filtered_runs)
        rac_log_message(plot_log_file, '[Plot] Skip plot generation because filtered run_results is empty.');
        return;
    end

    if cfg.plot.types.convergence_curves
        rac_log_message(plot_log_file, '[Plot] Generating convergence_curves.');
        rac_plot_convergence_curves(filtered_runs, cfg, plot_dirs, plot_log_file);
    end

    if cfg.plot.types.boxplots
        rac_log_message(plot_log_file, '[Plot] Generating boxplots.');
        rac_plot_boxplots(filtered_runs, cfg, plot_dirs, plot_log_file);
    end

    if cfg.plot.types.friedman_radar
        rac_log_message(plot_log_file, '[Plot] Generating friedman_radar.');
        rac_plot_friedman_radar(filtered_summary, cfg, plot_dirs, plot_log_file);
    end

    if has_behavior_plot_enabled_local(cfg.plot)
        rac_log_message(plot_log_file, '[Plot] Generating behavior plots.');
        rac_plot_algorithm_behavior(filtered_runs, cfg, plot_dirs, plot_log_file);
    end
end

function plot_dirs = init_plot_dirs_local(result_dir, cfg)
    dim_name = sprintf('D%d', cfg.dim);
    plot_dirs = struct();
    plot_dirs.root = result_dir.figures;
    plot_dirs.convergence_curves = fullfile(result_dir.figures, 'convergence_curves', dim_name);
    plot_dirs.boxplots = fullfile(result_dir.figures, 'boxplots', dim_name);
    plot_dirs.friedman_radar = fullfile(result_dir.figures, 'friedman_radar', dim_name);
    plot_dirs.search_process_overview = fullfile(result_dir.figures, 'search_process_overview');
    plot_dirs.mean_fitness = fullfile(result_dir.figures, 'mean_fitness');
    plot_dirs.trajectory_first_dim = fullfile(result_dir.figures, 'trajectory_first_dim');
    plot_dirs.final_population = fullfile(result_dir.figures, 'final_population');

    dir_list = {plot_dirs.root, plot_dirs.convergence_curves, plot_dirs.boxplots, plot_dirs.friedman_radar, ...
        plot_dirs.search_process_overview, plot_dirs.mean_fitness, plot_dirs.trajectory_first_dim, plot_dirs.final_population};
    for i = 1:numel(dir_list)
        if ~isfolder(dir_list{i})
            mkdir(dir_list{i});
        end
    end
end

function filtered_runs = filter_run_results_for_plot_local(run_results, plot_cfg)
    if isempty(run_results)
        filtered_runs = run_results;
        return;
    end

    alg_mask = ismember(upper(string({run_results.algorithm_name})), upper(string(plot_cfg.selected_algorithms_resolved)));
    fid_mask = ismember([run_results.function_id], plot_cfg.selected_funcs_resolved);
    filtered_runs = run_results(alg_mask & fid_mask);
end

function filtered_summary = filter_summary_for_plot_local(summary_table, plot_cfg)
    if isempty(summary_table)
        filtered_summary = summary_table;
        return;
    end
    alg_mask = ismember(upper(string(summary_table.algorithm_name)), upper(string(plot_cfg.selected_algorithms_resolved)));
    fid_mask = ismember(summary_table.function_id, plot_cfg.selected_funcs_resolved);
    filtered_summary = summary_table(alg_mask & fid_mask, :);
end

function tf = has_behavior_plot_enabled_local(plot_cfg)
    tf = plot_cfg.types.search_process_overview || plot_cfg.types.mean_fitness || ...
        plot_cfg.types.trajectory_first_dim || plot_cfg.types.final_population;
end
