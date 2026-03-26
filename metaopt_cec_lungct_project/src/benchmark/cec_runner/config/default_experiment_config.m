function cfg = default_experiment_config(cfg)
% default_experiment_config
% Central default config for unified benchmark entry.
% Why: keep smoke/formal settings consistent and reproducible.

    if nargin < 1 || isempty(cfg)
        cfg = struct();
    end

    if ~isfield(cfg, 'mode') || isempty(cfg.mode)
        cfg.mode = 'smoke';
    end

    if ~isfield(cfg, 'algorithm_profile') || isempty(cfg.algorithm_profile)
        cfg.algorithm_profile = 'research_core';
    end

    if ~isfield(cfg, 'suites') || isempty(cfg.suites)
        cfg.suites = {'cec2017', 'cec2022'};
    end

    if ~isfield(cfg, 'dim')
        cfg.dim = 10;
    end
    if ~isfield(cfg, 'pop_size')
        cfg.pop_size = 30;
    end
    if ~isfield(cfg, 'maxFEs')
        cfg.maxFEs = 3000;
    end
    if ~isfield(cfg, 'rng_seed')
        cfg.rng_seed = 20260315;
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

    if ~isfield(cfg, 'experiment_name_base') || isempty(cfg.experiment_name_base)
        cfg.experiment_name_base = 'unified_benchmark';
    end

    if ~isfield(cfg, 'explicit_experiment_name')
        cfg.explicit_experiment_name = '';
    end

    if ~isfield(cfg, 'timestamp') || isempty(cfg.timestamp)
        cfg.timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    end

    if ~isfield(cfg, 'output_language') || isempty(cfg.output_language)
        cfg.output_language = 'zh';
    end
    if ~isfield(cfg, 'localize_output_files_zh')
        cfg.localize_output_files_zh = false;
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

    if ~isfield(cfg, 'plot') || ~isstruct(cfg.plot)
        cfg.plot = struct();
    end
    if ~isfield(cfg.plot, 'enable')
        cfg.plot.enable = true;
    end
    if ~isfield(cfg.plot, 'show')
        cfg.plot.show = false;
    end
    if ~isfield(cfg.plot, 'save')
        cfg.plot.save = true;
    end
    if ~isfield(cfg.plot, 'formats') || isempty(cfg.plot.formats)
        cfg.plot.formats = {'png'};
    end

    if ~isfield(cfg, 'smoke') || ~isstruct(cfg.smoke)
        cfg.smoke = struct();
    end
    if ~isfield(cfg.smoke, 'runs')
        cfg.smoke.runs = 1;
    end
    if ~isfield(cfg.smoke, 'func_ids') || isempty(cfg.smoke.func_ids)
        cfg.smoke.func_ids = struct('cec2017', 1:3, 'cec2022', 1:3);
    end

    if ~isfield(cfg, 'formal') || ~isstruct(cfg.formal)
        cfg.formal = struct();
    end
    if ~isfield(cfg.formal, 'runs')
        cfg.formal.runs = 5;
    end
    if ~isfield(cfg.formal, 'func_ids') || isempty(cfg.formal.func_ids)
        cfg.formal.func_ids = struct('cec2017', 1:30, 'cec2022', 1:12);
    end

    % Reserve extension hook only. Keep benchmark objective semantics unchanged.
    if ~isfield(cfg, 'objective_wrapper_hook')
        cfg.objective_wrapper_hook = [];
    end
    if ~isfield(cfg, 'objective_wrapper_note')
        cfg.objective_wrapper_note = 'reserved_only_not_applied';
    end

    if ~isfield(cfg, 'export') || ~isstruct(cfg.export)
        cfg.export = struct();
    end
    if ~isfield(cfg.export, 'aggregate_csv')
        cfg.export.aggregate_csv = true;
    end
    if ~isfield(cfg.export, 'aggregate_xlsx')
        cfg.export.aggregate_xlsx = true;
    end
    if ~isfield(cfg.export, 'aggregate_mat')
        cfg.export.aggregate_mat = true;
    end
    if ~isfield(cfg.export, 'wilcoxon')
        cfg.export.wilcoxon = true;
    end
    if ~isfield(cfg.export, 'friedman')
        cfg.export.friedman = true;
    end
    if ~isfield(cfg.export, 'pvalue_placeholder')
        cfg.export.pvalue_placeholder = true;
    end
    if ~isfield(cfg.export, 'summary_markdown')
        cfg.export.summary_markdown = true;
    end
end
