function report = run_route_a_de_next_round(cfg)
% run_route_a_de_next_round
% Next-round focused experiment:
% A: conservative mainline baseline
% D: A + lightweight local refine (F10-oriented)
% E: A + long-budget late controlled rescue

    if nargin < 1
        cfg = struct();
    end
    cfg = fill_defaults(cfg);

    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    repo_root = fullfile(this_dir, '..', '..', '..');

    addpath(fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'entry'));
    addpath(this_dir);

    run_cfg = struct();
    run_cfg.mode = 'smoke';
    run_cfg.suites = {cfg.suite};
    run_cfg.algorithms = {'A_BUDGET_ADAPTIVE', 'D_F10_LOCAL_REFINE', 'E_LONG_BUDGET_CONTROLLED_RESCUE'};
    run_cfg.baseline_algorithm = 'A_BUDGET_ADAPTIVE';
    run_cfg.dim = cfg.dim;
    run_cfg.pop_size = cfg.pop_size;
    run_cfg.maxFEs = cfg.maxFEs;
    run_cfg.rng_seed = cfg.rng_seed;
    run_cfg.result_root = cfg.result_root;
    run_cfg.result_group = fullfile('benchmark', 'research_pipeline');
    run_cfg.result_layout = 'suite_then_experiment';
    run_cfg.explicit_experiment_name = cfg.experiment_name;
    run_cfg.save_curve = true;
    run_cfg.save_mat = true;
    run_cfg.save_csv = true;
    run_cfg.plot = struct('enable', false, 'show', false, 'save', false, 'formats', {{'png'}});

    if strcmpi(cfg.suite, 'cec2022')
        run_cfg.smoke = struct('runs', cfg.runs, 'func_ids', struct('cec2022', cfg.func_ids));
    else
        run_cfg.smoke = struct('runs', cfg.runs, 'func_ids', struct('cec2017', cfg.func_ids));
    end
    run_cfg.export = struct('summary_markdown', true);

    report = run_main_entry(run_cfg);

    result_dir = report.output.suite_results(1).result_dir;
    plateau_csv = compute_plateau_fe_summary(result_dir);
    risk_out = compute_runlevel_risk_summary(result_dir, 'ROUTE_A_BUDGET_ADAPTIVE_BBO');

    report.next_round = struct();
    report.next_round.result_dir = result_dir;
    report.next_round.plateau_csv = plateau_csv;
    report.next_round.run_level_csv = risk_out.run_level_csv;
    report.next_round.bad_run_csv = risk_out.bad_run_csv;
    report.next_round.dist_csv = risk_out.dist_csv;

    disp(result_dir);
end

function cfg = fill_defaults(cfg)
    if ~isfield(cfg, 'suite') || strlength(string(cfg.suite)) == 0
        cfg.suite = 'cec2022';
    end
    if ~isfield(cfg, 'func_ids') || isempty(cfg.func_ids)
        cfg.func_ids = [10, 11, 8, 7, 12, 6];
    end
    if ~isfield(cfg, 'runs') || isempty(cfg.runs)
        cfg.runs = 10;
    end
    if ~isfield(cfg, 'dim') || isempty(cfg.dim)
        cfg.dim = 10;
    end
    if ~isfield(cfg, 'pop_size') || isempty(cfg.pop_size)
        cfg.pop_size = 30;
    end
    if ~isfield(cfg, 'rng_seed') || isempty(cfg.rng_seed)
        cfg.rng_seed = 20260321;
    end
    if ~isfield(cfg, 'maxFEs') || isempty(cfg.maxFEs)
        cfg.maxFEs = 30000;
    end
    if isfield(cfg, 'use_long_budget') && logical(cfg.use_long_budget)
        cfg.maxFEs = 300000;
    end
    if ~isfield(cfg, 'result_root') || strlength(string(cfg.result_root)) == 0
        cfg.result_root = 'results';
    end
    if ~isfield(cfg, 'experiment_name') || strlength(string(cfg.experiment_name)) == 0
        cfg.experiment_name = sprintf('ade_next_round_fes%d_runs%d_%s', cfg.maxFEs, cfg.runs, char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
    end
end
