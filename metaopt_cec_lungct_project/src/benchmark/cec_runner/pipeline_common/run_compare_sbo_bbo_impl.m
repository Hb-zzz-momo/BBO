function output = run_compare_sbo_bbo_impl(cfg)
% run_compare_sbo_bbo_impl
% Canonical SBO-vs-BBO comparison workflow routed through the unified core entry.

    if nargin < 1
        cfg = struct();
    end

    this_file = mfilename('fullpath');
    common_dir = fileparts(this_file);
    runner_dir = fileparts(common_dir);
    addpath(fullfile(runner_dir, 'entry'));
    addpath(fullfile(runner_dir, 'core'));

    main_cfg = local_normalize_compare_cfg(cfg);
    report = run_main_entry(main_cfg);
    output = report.output;
end

function main_cfg = local_normalize_compare_cfg(cfg)
    suite_name = local_get_field(cfg, 'suite', 'cec2017');
    if isfield(cfg, 'suites') && ~isempty(cfg.suites)
        suites = cellstr(string(cfg.suites));
    else
        suites = {char(string(suite_name))};
    end

    func_ids = local_get_field(cfg, 'func_ids', local_default_func_ids(suites{1}));
    runs = local_get_field(cfg, 'runs', 30);
    dim = local_get_field(cfg, 'dim', 10);
    pop_size = local_get_field(cfg, 'pop_size', 30);
    rng_seed = local_get_field(cfg, 'rng_seed', 20260323);
    max_fes = local_pick_max_fes(cfg);
    algorithms = cellstr(string(local_get_field(cfg, 'algorithms', {'SBO', 'BBO'})));

    main_cfg = struct();
    main_cfg.mode = char(string(local_get_field(cfg, 'mode', 'formal')));
    main_cfg.suites = suites;
    main_cfg.algorithms = algorithms;
    main_cfg.dim = dim;
    main_cfg.pop_size = pop_size;
    main_cfg.maxFEs = max_fes;
    main_cfg.rng_seed = rng_seed;

    if isfield(cfg, 'result_root')
        main_cfg.result_root = cfg.result_root;
    end
    if isfield(cfg, 'result_group')
        main_cfg.result_group = cfg.result_group;
    end
    if isfield(cfg, 'result_layout')
        main_cfg.result_layout = cfg.result_layout;
    end
    if isfield(cfg, 'save_curve')
        main_cfg.save_curve = cfg.save_curve;
    end
    if isfield(cfg, 'save_mat')
        main_cfg.save_mat = cfg.save_mat;
    end
    if isfield(cfg, 'save_csv')
        main_cfg.save_csv = cfg.save_csv;
    end
    if isfield(cfg, 'plot')
        main_cfg.plot = cfg.plot;
    end
    if isfield(cfg, 'experiment_name') && ~isempty(cfg.experiment_name)
        main_cfg.explicit_experiment_name = cfg.experiment_name;
    end

    main_cfg.smoke = struct('runs', runs, 'func_ids', local_make_func_spec(suites, func_ids));
    main_cfg.formal = struct('runs', runs, 'func_ids', local_make_func_spec(suites, func_ids));
end

function value = local_get_field(cfg, field_name, default_value)
    value = default_value;
    if isfield(cfg, field_name) && ~isempty(cfg.(field_name))
        value = cfg.(field_name);
    end
end

function max_fes = local_pick_max_fes(cfg)
    if isfield(cfg, 'maxFEs') && ~isempty(cfg.maxFEs)
        max_fes = cfg.maxFEs;
    elseif isfield(cfg, 'max_fes') && ~isempty(cfg.max_fes)
        max_fes = cfg.max_fes;
    else
        max_fes = 300000;
    end
end

function func_spec = local_make_func_spec(suites, func_ids)
    if isstruct(func_ids)
        func_spec = func_ids;
        return;
    end

    func_spec = struct();
    for i = 1:numel(suites)
        suite_name = char(string(suites{i}));
        func_spec.(suite_name) = func_ids;
    end
end

function ids = local_default_func_ids(suite_name)
    if strcmpi(string(suite_name), "cec2022")
        ids = 1:12;
    else
        ids = 1:30;
    end
end
