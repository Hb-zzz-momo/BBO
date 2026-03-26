function cfg = rac_fill_default_config(cfg)
% Fill default benchmark config values with backward-compatible aliases.

    if ~isfield(cfg, 'suites')
        cfg.suites = {'cec2017', 'cec2022'};
    end
    if ~isfield(cfg, 'algorithms')
        cfg.algorithms = {'BBO', 'SBO', 'HGS', 'SMA', 'HHO', 'RUN', 'INFO', 'MGO', 'PLO', 'PO'};
    end
    if ~isfield(cfg, 'func_ids')
        cfg.func_ids = [];
    end
    if ~isfield(cfg, 'dim')
        cfg.dim = 10;
    end
    if ~isfield(cfg, 'pop_size')
        cfg.pop_size = 30;
    end
    if ~isfield(cfg, 'maxFEs')
        if isfield(cfg, 'max_fes')
            cfg.maxFEs = cfg.max_fes;
        else
            cfg.maxFEs = 3000;
        end
    end
    if ~isfield(cfg, 'runs')
        cfg.runs = 5;
    end
    if ~isfield(cfg, 'rng_seed')
        cfg.rng_seed = 20260313;
    end
    if ~isfield(cfg, 'experiment_name') || isempty(cfg.experiment_name)
        cfg.experiment_name = datestr(now, 'yyyymmdd_HHMMSS');
    end
    if ~isfield(cfg, 'result_root') || isempty(cfg.result_root)
        cfg.result_root = 'results';
    end
    if ~isfield(cfg, 'result_group')
        cfg.result_group = '';
    end
    if ~isfield(cfg, 'result_layout') || isempty(cfg.result_layout)
        cfg.result_layout = 'suite_then_experiment';
    end
    if ~isfield(cfg, 'save_curve')
        cfg.save_curve = true;
    end
    if ~isfield(cfg, 'save_mat')
        cfg.save_mat = true;
    end
    if ~isfield(cfg, 'save_csv')
        cfg.save_csv = true;
    end
    if ~isfield(cfg, 'hard_stop_on_fe_limit')
        cfg.hard_stop_on_fe_limit = true;
    end
    if ~isfield(cfg, 'strict_path_guard')
        cfg.strict_path_guard = true;
    end
    if ~isfield(cfg, 'plot') || ~isstruct(cfg.plot)
        cfg.plot = struct();
    end
    if ~isfield(cfg.plot, 'enable')
        if isfield(cfg, 'enable_plots')
            cfg.plot.enable = logical(cfg.enable_plots);
        else
            cfg.plot.enable = true;
        end
    end
    if ~isfield(cfg.plot, 'show')
        if isfield(cfg, 'show_plots')
            cfg.plot.show = logical(cfg.show_plots);
        else
            cfg.plot.show = false;
        end
    end
    if ~isfield(cfg.plot, 'save')
        if isfield(cfg, 'save_plots')
            cfg.plot.save = logical(cfg.save_plots);
        else
            cfg.plot.save = true;
        end
    end
    if ~isfield(cfg.plot, 'formats') || isempty(cfg.plot.formats)
        if isfield(cfg, 'plot_formats') && ~isempty(cfg.plot_formats)
            cfg.plot.formats = cfg.plot_formats;
        else
            cfg.plot.formats = {'png'};
        end
    end
    if ~isfield(cfg.plot, 'dpi')
        if isfield(cfg, 'plot_dpi')
            cfg.plot.dpi = cfg.plot_dpi;
        else
            cfg.plot.dpi = 200;
        end
    end
    if ~isfield(cfg.plot, 'tight')
        cfg.plot.tight = true;
    end
    if ~isfield(cfg.plot, 'close_after_save')
        cfg.plot.close_after_save = true;
    end
    if ~isfield(cfg.plot, 'overwrite')
        cfg.plot.overwrite = true;
    end
    if ~isfield(cfg.plot, 'selected_funcs')
        cfg.plot.selected_funcs = [];
    end
    if ~isfield(cfg.plot, 'selected_algorithms')
        cfg.plot.selected_algorithms = {};
    end
    if ~isfield(cfg.plot, 'subdir') || isempty(cfg.plot.subdir)
        if isfield(cfg, 'plot_subdir') && ~isempty(cfg.plot_subdir)
            cfg.plot.subdir = cfg.plot_subdir;
        else
            cfg.plot.subdir = 'figures';
        end
    end
    if ~isfield(cfg.plot, 'types') || ~isstruct(cfg.plot.types)
        cfg.plot.types = struct();
    end
    if ~isfield(cfg.plot.types, 'convergence_curves')
        cfg.plot.types.convergence_curves = true;
    end
    if ~isfield(cfg.plot.types, 'boxplots')
        cfg.plot.types.boxplots = true;
    end
    if ~isfield(cfg.plot.types, 'friedman_radar')
        cfg.plot.types.friedman_radar = true;
    end
    if ~isfield(cfg.plot.types, 'search_process_overview')
        cfg.plot.types.search_process_overview = true;
    end
    if ~isfield(cfg.plot.types, 'mean_fitness')
        cfg.plot.types.mean_fitness = true;
    end
    if ~isfield(cfg.plot.types, 'trajectory_first_dim')
        cfg.plot.types.trajectory_first_dim = true;
    end
    if ~isfield(cfg.plot.types, 'final_population')
        cfg.plot.types.final_population = true;
    end
    if ~isfield(cfg.plot, 'behavior') || ~isstruct(cfg.plot.behavior)
        cfg.plot.behavior = struct();
    end
    if ~isfield(cfg.plot.behavior, 'only_for_algorithms') || isempty(cfg.plot.behavior.only_for_algorithms)
        cfg.plot.behavior.only_for_algorithms = {'BBO'};
    end
    if ~isfield(cfg.plot.behavior, 'require_dim2')
        cfg.plot.behavior.require_dim2 = true;
    end
    if ~isfield(cfg.plot.behavior, 'max_funcs')
        cfg.plot.behavior.max_funcs = 3;
    end
    if ~isfield(cfg.plot, 'log_skipped')
        cfg.plot.log_skipped = true;
    end

    cfg.enable_plots = cfg.plot.enable;
    cfg.show_plots = cfg.plot.show;
    cfg.save_plots = cfg.plot.save;
    cfg.plot_formats = cfg.plot.formats;
    cfg.plot_dpi = cfg.plot.dpi;
    cfg.plot_subdir = cfg.plot.subdir;
end
