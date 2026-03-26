function report = run_routea_final_compare(cfg)
% run_routea_final_compare
% Final research delivery entry for ROUTE_A_BUDGET_ADAPTIVE_BBO comparison.
% Why: scan fixed algorithms, run smoke/formal via unified benchmark core,
% then assemble a paper-facing result package.

    if nargin < 1 || isempty(cfg)
        cfg = struct();
    end

    repo_root = local_bootstrap_runner();
    cfg = local_fill_defaults(cfg);
    if ~isempty(cfg.seed_list) && numel(cfg.seed_list) ~= cfg.runs
        error('run_routea_final_compare:SeedListLengthMismatch', ...
            'seed_list length (%d) must equal runs (%d).', numel(cfg.seed_list), cfg.runs);
    end

    paths = rac_resolve_common_paths();
    output_root_abs = local_make_abs_path(repo_root, cfg.output_root);
    runner_root_rel = fullfile(cfg.output_root, '_runner_artifacts');
    if ~isfolder(output_root_abs)
        mkdir(output_root_abs);
    end

    suites = cellstr(string(cfg.suites));
    per_suite = repmat(struct( ...
        'suite', '', ...
        'registry', table(), ...
        'smoke', struct(), ...
        'formal', struct(), ...
        'package', struct()), 1, numel(suites));

    for i = 1:numel(suites)
        suite_name = suites{i};
        registry = local_build_algorithm_registry(paths, suite_name, cfg);

        smoke_stage = local_run_stage(cfg, suite_name, cfg.algorithms, 'smoke', runner_root_rel);
        registry = local_apply_stage_status(registry, smoke_stage, 'smoke', cfg);

        formal_mask = local_select_formal_mask(registry, cfg);
        registry.selected_for_formal = formal_mask;
        formal_algs = cellstr(registry.algorithm_name(formal_mask))';
        formal_stage = local_run_stage(cfg, suite_name, formal_algs, 'formal', runner_root_rel);
        registry = local_apply_stage_status(registry, formal_stage, 'formal', cfg);
        registry.status = local_finalize_registry_status(registry);

        package_report = local_assemble_suite_package(repo_root, cfg, suite_name, registry, smoke_stage, formal_stage);

        per_suite(i).suite = suite_name;
        per_suite(i).registry = registry;
        per_suite(i).smoke = smoke_stage;
        per_suite(i).formal = formal_stage;
        per_suite(i).package = package_report;
    end

    report = struct();
    report.cfg = cfg;
    report.repo_root = repo_root;
    report.output_root = output_root_abs;
    report.runner_artifact_root = local_make_abs_path(repo_root, runner_root_rel);
    report.per_suite = per_suite;
end

function repo_root = local_bootstrap_runner()
    this_file = mfilename('fullpath');
    script_dir = fileparts(this_file);
    repo_root = fileparts(fileparts(fileparts(script_dir)));

    core_dir = fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'core');
    entry_dir = fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'entry');
    export_dir = fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'export');
    config_dir = fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'config');
    metrics_dir = fullfile(repo_root, 'src', 'benchmark', 'metrics');

    addpath(core_dir);
    setup_benchmark_paths();
    addpath(entry_dir);
    addpath(export_dir);
    addpath(config_dir);
    if isfolder(metrics_dir)
        addpath(metrics_dir);
    end
end

function cfg = local_fill_defaults(cfg)
    if ~isfield(cfg, 'timestamp') || isempty(cfg.timestamp)
        cfg.timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    end
    if ~isfield(cfg, 'suites') || isempty(cfg.suites)
        cfg.suites = {'cec2017', 'cec2022'};
    end
    if ~isfield(cfg, 'algorithms') || isempty(cfg.algorithms)
        cfg.algorithms = {'ROUTE_A_BUDGET_ADAPTIVE_BBO', 'BBO_BASE', 'PSO', 'DE', 'GWO', 'WOA', 'HHO', 'RIME', 'SBO', 'SHADE'};
    end
    if ~isfield(cfg, 'dim') || isempty(cfg.dim)
        cfg.dim = 10;
    end
    if ~isfield(cfg, 'pop_size') || isempty(cfg.pop_size)
        cfg.pop_size = 30;
    end
    if ~isfield(cfg, 'maxFEs') || isempty(cfg.maxFEs)
        cfg.maxFEs = 300000;
    end
    if ~isfield(cfg, 'runs') || isempty(cfg.runs)
        cfg.runs = 30;
    end
    if ~isfield(cfg, 'rng_seed') || isempty(cfg.rng_seed)
        cfg.rng_seed = 20260324;
    end
    if ~isfield(cfg, 'seed_list')
        cfg.seed_list = [];
    end
    if ~isfield(cfg, 'continue_on_failure')
        cfg.continue_on_failure = true;
    end
    if ~isfield(cfg, 'output_root') || isempty(cfg.output_root)
        cfg.output_root = fullfile('results', '算法结尾阶段');
    end
    if ~isfield(cfg, 'smoke_runs') || isempty(cfg.smoke_runs)
        cfg.smoke_runs = 1;
    end
    if ~isfield(cfg, 'smoke_maxFEs') || isempty(cfg.smoke_maxFEs)
        cfg.smoke_maxFEs = min(cfg.maxFEs, 3000);
    end
    if ~isfield(cfg, 'smoke_func_ids') || isempty(cfg.smoke_func_ids)
        cfg.smoke_func_ids = struct('cec2017', 1:3, 'cec2022', 1:3);
    end
    if ~isfield(cfg, 'formal_func_ids') || isempty(cfg.formal_func_ids)
        cfg.formal_func_ids = struct('cec2017', 1:30, 'cec2022', 1:12);
    end
    if ~isfield(cfg, 'paper_funcs') || isempty(cfg.paper_funcs)
        cfg.paper_funcs = struct('cec2017', [1, 12, 30], 'cec2022', [1, 6, 12]);
    end
    if ~isfield(cfg, 'plot') || ~isstruct(cfg.plot)
        cfg.plot = struct();
    end
    if ~isfield(cfg.plot, 'formats') || isempty(cfg.plot.formats)
        cfg.plot.formats = {'png'};
    end
    if ~isfield(cfg.plot, 'enable')
        cfg.plot.enable = true;
    end
    if ~isfield(cfg.plot, 'save')
        cfg.plot.save = true;
    end
    if ~isfield(cfg.plot, 'show')
        cfg.plot.show = false;
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
    if ~isfield(cfg, 'main_algorithm') || isempty(cfg.main_algorithm)
        cfg.main_algorithm = 'ROUTE_A_BUDGET_ADAPTIVE_BBO';
    end
    if ~isfield(cfg, 'base_algorithm') || isempty(cfg.base_algorithm)
        cfg.base_algorithm = 'BBO_BASE';
    end
end

function registry = local_build_algorithm_registry(paths, suite_name, cfg)
    rows = local_empty_registry_table();
    seed_mode = string(local_seed_mode(cfg));
    for i = 1:numel(cfg.algorithms)
        requested = char(string(cfg.algorithms{i}));
        resolved = resolve_algorithm_alias(requested);
        canonical = upper(string(resolved.canonical_token));
        entry_name = local_resolved_entry_name(resolved);
        spec = resolve_algorithm_runtime_spec(paths, suite_name, canonical, entry_name);
        entry_file = "";
        algorithm_dir = "";
        budget_arg = "";
        output_mode = "";
        source_group = "";
        pre_scan_status = "unsupported";
        if spec.is_supported
            entry_file = string(fullfile(spec.algorithm_dir, [spec.entry_name '.m']));
            algorithm_dir = string(spec.algorithm_dir);
            budget_arg = string(spec.budget_arg);
            output_mode = string(spec.output_mode);
            source_group = string(spec.source_group);
            if isfolder(spec.algorithm_dir) && isfile(entry_file)
                pre_scan_status = "runnable_pre_scan";
            else
                pre_scan_status = "missing_not_runnable";
            end
            note = local_scan_note(canonical, pre_scan_status, spec);
        else
            note = "No runtime spec available in benchmark resolver.";
        end

        row = table( ...
            string(suite_name), ...
            string(requested), ...
            canonical, ...
            string(resolved.paper_name), ...
            string(resolved.internal_id), ...
            string(spec.entry_name), ...
            entry_file, ...
            algorithm_dir, ...
            repmat("function", 1, 1), ...
            string(local_parameter_source_label(canonical, source_group)), ...
            string(local_parameter_defaults(canonical)), ...
            seed_mode, ...
            budget_arg, ...
            output_mode, ...
            false, ...
            pre_scan_status, ...
            "not_run", ...
            "not_selected", ...
            "not_run", ...
            string(note), ...
            'VariableNames', {'suite','requested_name','algorithm_name','paper_name','internal_id','entry_name','entry_file', ...
            'algorithm_dir','callable_type','parameter_source','parameter_defaults','seed_mode','budget_arg','output_mode', ...
            'selected_for_formal','pre_scan_status','smoke_status','formal_status','status','notes'});
        rows = [rows; row]; %#ok<AGROW>
    end

    registry = rows;
end

function stage = local_run_stage(cfg, suite_name, algorithms, stage_name, runner_root_rel)
    stage = struct();
    stage.stage_name = stage_name;
    stage.suite = suite_name;
    stage.algorithms = cellstr(string(algorithms));
    stage.pass = false;
    stage.error_message = "";
    stage.result_dir = "";
    stage.run_manifest = local_empty_manifest_table();
    stage.inventory = local_empty_inventory_table();
    stage.summary = local_empty_summary_table();
    stage.exact_match_warnings = local_empty_exact_match_table();

    if isempty(stage.algorithms)
        stage.pass = true;
        return;
    end

    runner_cfg = local_build_runner_cfg(cfg, suite_name, stage.algorithms, stage_name, runner_root_rel);
    stage.runner_cfg = runner_cfg;

    try
        run_report = run_main_entry(runner_cfg);
        suite_results = run_report.output.suite_results;
        if isempty(suite_results)
            error('run_routea_final_compare:EmptySuiteResult', 'No suite_results returned for %s/%s.', stage_name, suite_name);
        end

        stage.pass = true;
        stage.result_dir = string(suite_results(1).result_dir);
        stage.summary = suite_results(1).summary;

        manifest_csv = fullfile(stage.result_dir, 'run_manifest.csv');
        inventory_csv = fullfile(stage.result_dir, 'algorithm_inventory.csv');
        exact_match_csv = fullfile(stage.result_dir, 'exact_match_warnings.csv');
        if isfile(manifest_csv)
            stage.run_manifest = readtable(manifest_csv);
        end
        if isfile(inventory_csv)
            stage.inventory = readtable(inventory_csv);
        end
        if isfile(exact_match_csv)
            stage.exact_match_warnings = readtable(exact_match_csv);
        end
    catch ME
        stage.pass = false;
        stage.error_message = string(sprintf('[%s] %s', ME.identifier, ME.message));
        if ~cfg.continue_on_failure
            rethrow(ME);
        end
    end
end

function runner_cfg = local_build_runner_cfg(cfg, suite_name, algorithms, stage_name, runner_root_rel)
    stage_token = lower(stage_name);
    runner_cfg = struct();
    runner_cfg.mode = stage_token;
    runner_cfg.suites = {suite_name};
    runner_cfg.algorithms = algorithms;
    runner_cfg.dim = cfg.dim;
    runner_cfg.pop_size = cfg.pop_size;
    runner_cfg.result_root = runner_root_rel;
    runner_cfg.result_group = stage_token;
    runner_cfg.result_layout = 'experiment_then_suite';
    runner_cfg.save_curve = strcmpi(stage_token, 'formal') && cfg.save_curve;
    runner_cfg.save_mat = cfg.save_mat;
    runner_cfg.save_csv = cfg.save_csv;
    runner_cfg.plot = local_stage_plot_cfg(cfg, stage_name);
    runner_cfg.explicit_experiment_name = sprintf('routea_final_compare_%s_fes%d_runs%d_%s', ...
        lower(suite_name), local_stage_max_fes(cfg, stage_name), local_stage_runs(cfg, stage_name), cfg.timestamp);

    if strcmpi(stage_token, 'smoke')
        runner_cfg.maxFEs = cfg.smoke_maxFEs;
        runner_cfg.rng_seed = cfg.rng_seed;
        runner_cfg.smoke = struct('runs', cfg.smoke_runs, 'func_ids', local_stage_func_spec(cfg.smoke_func_ids, suite_name));
        runner_cfg.formal = struct('runs', cfg.smoke_runs, 'func_ids', local_stage_func_spec(cfg.smoke_func_ids, suite_name));
    else
        runner_cfg.maxFEs = cfg.maxFEs;
        runner_cfg.rng_seed = cfg.rng_seed;
        runner_cfg.smoke = struct('runs', cfg.runs, 'func_ids', local_stage_func_spec(cfg.formal_func_ids, suite_name));
        runner_cfg.formal = struct('runs', cfg.runs, 'func_ids', local_stage_func_spec(cfg.formal_func_ids, suite_name));
        if ~isempty(cfg.seed_list)
            runner_cfg.seed_list = cfg.seed_list;
        end
    end
end

function plot_cfg = local_stage_plot_cfg(cfg, stage_name)
    plot_cfg = cfg.plot;
    if strcmpi(stage_name, 'smoke')
        plot_cfg.enable = false;
        plot_cfg.save = false;
        plot_cfg.show = false;
    else
        plot_cfg.enable = true;
        plot_cfg.save = true;
        plot_cfg.show = false;
    end
end

function func_spec = local_stage_func_spec(spec_in, suite_name)
    if isstruct(spec_in)
        func_spec = struct(suite_name, spec_in.(suite_name));
    else
        func_spec = struct(suite_name, spec_in);
    end
end

function value = local_stage_runs(cfg, stage_name)
    if strcmpi(stage_name, 'smoke')
        value = cfg.smoke_runs;
    else
        value = cfg.runs;
    end
end

function value = local_stage_max_fes(cfg, stage_name)
    if strcmpi(stage_name, 'smoke')
        value = cfg.smoke_maxFEs;
    else
        value = cfg.maxFEs;
    end
end

function registry = local_apply_stage_status(registry, stage, stage_name, cfg)
    if strcmpi(stage_name, 'formal')
        registry.selected_for_formal = local_select_formal_mask(registry, cfg);
    end

    if ~stage.pass
        status_value = string(sprintf('%s_stage_error', lower(stage_name)));
        for i = 1:height(registry)
            if registry.pre_scan_status(i) == "runnable_pre_scan"
                registry.(sprintf('%s_status', lower(stage_name)))(i) = status_value;
                registry.notes(i) = local_append_note(registry.notes(i), char(stage.error_message));
            elseif strcmpi(stage_name, 'formal') && ~registry.selected_for_formal(i)
                registry.formal_status(i) = "not_selected";
            else
                registry.(sprintf('%s_status', lower(stage_name)))(i) = "skipped_not_runnable";
            end
        end
        return;
    end

    manifest = stage.run_manifest;
    if ~isempty(manifest)
        manifest.algorithm_name = string(manifest.algorithm_name);
        if ismember('status', manifest.Properties.VariableNames)
            manifest.status = string(manifest.status);
        end
    end

    for i = 1:height(registry)
        alg = registry.algorithm_name(i);
        if registry.pre_scan_status(i) ~= "runnable_pre_scan"
            registry.(sprintf('%s_status', lower(stage_name)))(i) = "skipped_not_runnable";
            continue;
        end
        if strcmpi(stage_name, 'formal') && ~registry.selected_for_formal(i)
            registry.formal_status(i) = "not_selected";
            continue;
        end

        subset = manifest(manifest.algorithm_name == alg, :);
        if isempty(subset)
            registry.(sprintf('%s_status', lower(stage_name)))(i) = string(sprintf('%s_no_rows', lower(stage_name)));
            continue;
        end

        statuses = unique(subset.status, 'stable');
        has_success = any(statuses == "completed" | statuses == "stopped_at_budget");
        has_failure = any(statuses == "failed");

        if has_success && ~has_failure
            out = string(sprintf('%s_pass', lower(stage_name)));
        elseif has_success && has_failure
            out = string(sprintf('%s_partial', lower(stage_name)));
        else
            out = string(sprintf('%s_failed', lower(stage_name)));
        end
        registry.(sprintf('%s_status', lower(stage_name)))(i) = out;
        registry.notes(i) = local_append_note(registry.notes(i), char(sprintf('%s statuses=%s', lower(stage_name), strjoin(cellstr(statuses), ','))));
    end
end

function mask = local_select_formal_mask(registry, cfg)
    if any(strcmpi('smoke_status', registry.Properties.VariableNames))
        mask = registry.pre_scan_status == "runnable_pre_scan" & registry.smoke_status == "smoke_pass";
    else
        mask = registry.pre_scan_status == "runnable_pre_scan";
    end

    if ~cfg.continue_on_failure
        mask = registry.pre_scan_status == "runnable_pre_scan";
    end
end

function status = local_finalize_registry_status(registry)
    status = strings(height(registry), 1);
    for i = 1:height(registry)
        if registry.pre_scan_status(i) ~= "runnable_pre_scan"
            status(i) = registry.pre_scan_status(i);
        elseif registry.formal_status(i) ~= "not_run" && registry.formal_status(i) ~= "not_selected"
            status(i) = registry.formal_status(i);
        else
            status(i) = registry.smoke_status(i);
        end
    end
end

function package = local_assemble_suite_package(repo_root, cfg, suite_name, registry, smoke_stage, formal_stage)
    package_root = fullfile(local_make_abs_path(repo_root, cfg.output_root), ...
        sprintf('final_algorithm_compare_%s_fes%d_runs%d_%s', lower(suite_name), cfg.maxFEs, cfg.runs, cfg.timestamp));
    dirs = local_prepare_package_dirs(package_root);

    formal_data = local_load_stage_data(formal_stage);
    smoke_data = local_load_stage_data(smoke_stage);
    exact_match_warnings = formal_data.exact_match_warnings;

    writetable(registry, fullfile(package_root, 'ALGORITHM_REGISTRY.csv'));
    local_copy_or_write_table(formal_data.run_manifest, fullfile(package_root, 'run_manifest.csv'));

    summary_mean_std = local_build_summary_mean_std(formal_data.summary_table);
    win_tie_loss = local_build_win_tie_loss(formal_data.summary_table, string(cfg.main_algorithm));
    rank_summary = local_build_rank_summary(formal_data.rank_table, formal_data.friedman_ranks);
    wilcoxon_pairwise = local_build_wilcoxon_pairwise(formal_data.run_results, string(cfg.main_algorithm));
    friedman_ranks = local_normalize_friedman_ranks(formal_data.friedman_ranks);
    improvement_delta = local_build_improvement_delta(formal_data.summary_table, string(cfg.main_algorithm), string(cfg.base_algorithm));
    per_run_records = local_build_per_run_records(formal_data.run_results, formal_data.run_manifest, cfg);
    failures = local_build_failures_table(registry, smoke_data, formal_data);
    seeds = local_build_seeds_table(formal_data.run_manifest, cfg);
    seed_check = local_build_seed_check(formal_data.run_manifest);

    local_copy_or_write_table(formal_data.summary_table, fullfile(dirs.summary, 'summary.csv'));
    local_copy_or_write_table(summary_mean_std, fullfile(dirs.summary, 'summary_mean_std.csv'));
    local_copy_or_write_table(win_tie_loss, fullfile(dirs.summary, 'win_tie_loss.csv'));
    local_copy_or_write_table(rank_summary, fullfile(dirs.summary, 'rank_summary.csv'));
    local_copy_or_write_table(wilcoxon_pairwise, fullfile(dirs.summary, 'wilcoxon_pairwise.csv'));
    local_copy_or_write_table(friedman_ranks, fullfile(dirs.summary, 'friedman_ranks.csv'));
    local_copy_or_write_table(per_run_records, fullfile(dirs.raw, 'per_run_records.csv'));
    local_copy_or_write_table(failures, fullfile(dirs.raw, 'failures.csv'));
    local_copy_or_write_table(seeds, fullfile(dirs.raw, 'seeds.csv'));
    local_copy_or_write_table(seed_check, fullfile(dirs.diagnostics, 'seed_check.csv'));
    local_copy_or_write_table(improvement_delta, fullfile(dirs.improvement, 'IMPROVEMENT_DELTA.csv'));

    local_copy_trace_curves(formal_stage.result_dir, dirs.raw_traces);
    local_copy_runner_figures(formal_stage.result_dir, dirs, suite_name, cfg);
    local_create_win_loss_figure(win_tie_loss, dirs.figures_win_loss, dirs.figures_paper_ready, suite_name);
    local_create_rank_summary_figure(rank_summary, dirs.figures_ranks, dirs.figures_paper_ready, suite_name);
    local_copy_paper_ready_curves(formal_stage.result_dir, dirs.figures_paper_ready, suite_name, cfg);

    local_write_table_variants(summary_mean_std, 'summary_mean_std', dirs.tables_csv, dirs.tables_markdown, dirs.tables_latex);
    local_write_table_variants(win_tie_loss, 'win_tie_loss', dirs.tables_csv, dirs.tables_markdown, dirs.tables_latex);
    local_write_table_variants(rank_summary, 'rank_summary', dirs.tables_csv, dirs.tables_markdown, dirs.tables_latex);
    local_write_table_variants(wilcoxon_pairwise, 'wilcoxon_pairwise', dirs.tables_csv, dirs.tables_markdown, dirs.tables_latex);
    local_write_table_variants(friedman_ranks, 'friedman_ranks', dirs.tables_csv, dirs.tables_markdown, dirs.tables_latex);
    local_write_table_variants(improvement_delta, 'improvement_delta', dirs.tables_csv, dirs.tables_markdown, dirs.tables_latex);

    local_write_readme(fullfile(package_root, 'README.md'), suite_name, cfg, registry, smoke_stage, formal_stage);
    local_write_experiment_protocol(fullfile(package_root, 'EXPERIMENT_PROTOCOL.md'), suite_name, cfg, registry, formal_stage);
    local_write_parameter_sources(fullfile(package_root, 'PARAMETER_SOURCES.md'), registry);
    local_write_reproducibility(fullfile(package_root, 'REPRODUCIBILITY.md'), suite_name, cfg, formal_stage, dirs);
    local_write_env_snapshot(fullfile(package_root, 'ENV_SNAPSHOT.txt'), repo_root, suite_name, cfg);
    local_write_compatibility_report(fullfile(dirs.diagnostics, 'compatibility_report.md'), registry, smoke_stage, formal_stage);
    local_write_missing_algorithms(fullfile(dirs.diagnostics, 'missing_algorithms.md'), registry);
    local_write_fairness_check(fullfile(dirs.diagnostics, 'fairness_check.md'), cfg, registry, formal_data.run_manifest, seed_check, exact_match_warnings, suite_name);
    local_write_statistical_tests(fullfile(dirs.summary, 'statistical_tests.md'), wilcoxon_pairwise, formal_data.friedman_summary, friedman_ranks, cfg);
    local_write_key_findings(fullfile(dirs.summary, 'key_findings.md'), registry, win_tie_loss, rank_summary, improvement_delta, cfg);
    local_write_main_vs_base(fullfile(dirs.improvement, 'MAIN_VS_BASE.md'), improvement_delta, cfg);
    local_write_failure_cases(fullfile(dirs.improvement, 'FAILURE_CASES.md'), improvement_delta, cfg);
    local_write_analysis_notes(fullfile(dirs.notes, 'analysis_notes.md'), suite_name, registry, smoke_stage, formal_stage, package_root);
    local_write_limitations(fullfile(dirs.notes, 'limitations.md'), cfg, registry, formal_stage);
    local_write_next_actions(fullfile(dirs.notes, 'next_actions.md'), cfg, registry, formal_stage);

    package = struct();
    package.root = package_root;
    package.summary_dir = dirs.summary;
    package.raw_dir = dirs.raw;
    package.figures_dir = dirs.figures;
    package.tables_dir = dirs.tables;
    package.diagnostics_dir = dirs.diagnostics;
    package.notes_dir = dirs.notes;
end

function data = local_load_stage_data(stage)
    data = struct();
    data.result_dir = "";
    data.summary_table = local_empty_summary_table();
    data.run_manifest = local_empty_manifest_table();
    data.run_results = repmat(local_empty_run_result(), 1, 0);
    data.rank_table = table();
    data.friedman_ranks = table();
    data.friedman_summary = table();
    data.exact_match_warnings = local_empty_exact_match_table();

    if ~stage.pass || strlength(string(stage.result_dir)) == 0
        return;
    end

    data.result_dir = stage.result_dir;
    data.summary_table = stage.summary;
    data.run_manifest = stage.run_manifest;
    data.exact_match_warnings = stage.exact_match_warnings;

    summary_mat = fullfile(stage.result_dir, 'summary.mat');
    if isfile(summary_mat)
        S = load(summary_mat, 'run_results', 'summary_table', 'run_manifest');
        if isfield(S, 'run_results')
            data.run_results = S.run_results;
        end
        if isfield(S, 'summary_table')
            data.summary_table = S.summary_table;
        end
        if isfield(S, 'run_manifest')
            data.run_manifest = S.run_manifest;
        end
    end

    rank_csv = fullfile(stage.result_dir, 'rank_table.csv');
    friedman_rank_csv = fullfile(stage.result_dir, 'friedman_ranks.csv');
    friedman_summary_csv = fullfile(stage.result_dir, 'friedman_summary.csv');
    if isfile(rank_csv)
        data.rank_table = readtable(rank_csv);
    end
    if isfile(friedman_rank_csv)
        data.friedman_ranks = readtable(friedman_rank_csv);
    end
    if isfile(friedman_summary_csv)
        data.friedman_summary = readtable(friedman_summary_csv);
    end
end

function dirs = local_prepare_package_dirs(package_root)
    dirs = struct();
    dirs.root = package_root;
    dirs.summary = fullfile(package_root, 'summary');
    dirs.raw = fullfile(package_root, 'raw');
    dirs.raw_traces = fullfile(dirs.raw, 'traces');
    dirs.figures = fullfile(package_root, 'figures');
    dirs.figures_convergence = fullfile(dirs.figures, 'convergence');
    dirs.figures_boxplots = fullfile(dirs.figures, 'boxplots');
    dirs.figures_ranks = fullfile(dirs.figures, 'ranks');
    dirs.figures_win_loss = fullfile(dirs.figures, 'win_loss');
    dirs.figures_paper_ready = fullfile(dirs.figures, 'paper_ready');
    dirs.tables = fullfile(package_root, 'tables');
    dirs.tables_csv = fullfile(dirs.tables, 'csv');
    dirs.tables_markdown = fullfile(dirs.tables, 'markdown');
    dirs.tables_latex = fullfile(dirs.tables, 'latex');
    dirs.diagnostics = fullfile(package_root, 'diagnostics');
    dirs.improvement = fullfile(package_root, 'improvement');
    dirs.notes = fullfile(package_root, 'notes');

    dir_list = struct2cell(dirs);
    for i = 1:numel(dir_list)
        if ischar(dir_list{i}) || isstring(dir_list{i})
            if ~isfolder(dir_list{i})
                mkdir(dir_list{i});
            end
        end
    end
end

function summary_mean_std = local_build_summary_mean_std(summary_table)
    if isempty(summary_table)
        summary_mean_std = local_empty_summary_table();
        return;
    end
    keep = {'algorithm_name', 'function_id', 'best', 'mean', 'std', 'worst', 'median', 'avg_runtime', 'avg_used_FEs'};
    summary_mean_std = summary_table(:, keep);
end

function win_tie_loss = local_build_win_tie_loss(summary_table, main_algorithm)
    empty_cols = {'main_algorithm','other_algorithm','comparable_functions','win_count','tie_count','loss_count','avg_mean_delta','avg_std_delta'};
    if isempty(summary_table)
        win_tie_loss = cell2table(cell(0, numel(empty_cols)), 'VariableNames', empty_cols);
        return;
    end

    algs = unique(string(summary_table.algorithm_name), 'stable');
    algs = algs(algs ~= main_algorithm);
    rows = cell2table(cell(0, numel(empty_cols)), 'VariableNames', empty_cols);
    tol = 1e-12;
    for i = 1:numel(algs)
        other = algs(i);
        fids = unique(summary_table.function_id, 'stable');
        win = 0;
        tie = 0;
        loss = 0;
        mean_delta = [];
        std_delta = [];
        comparable = 0;
        for j = 1:numel(fids)
            fid = fids(j);
            main_row = summary_table(string(summary_table.algorithm_name) == main_algorithm & summary_table.function_id == fid, :);
            other_row = summary_table(string(summary_table.algorithm_name) == other & summary_table.function_id == fid, :);
            if isempty(main_row) || isempty(other_row)
                continue;
            end
            comparable = comparable + 1;
            delta = other_row.mean(1) - main_row.mean(1);
            if abs(delta) <= tol * max([1, abs(main_row.mean(1)), abs(other_row.mean(1))])
                tie = tie + 1;
            elseif delta > 0
                win = win + 1;
            else
                loss = loss + 1;
            end
            mean_delta(end + 1, 1) = delta; %#ok<AGROW>
            std_delta(end + 1, 1) = other_row.std(1) - main_row.std(1); %#ok<AGROW>
        end
        row = table(main_algorithm, other, comparable, win, tie, loss, local_safe_mean(mean_delta), local_safe_mean(std_delta), ...
            'VariableNames', empty_cols);
        rows = [rows; row]; %#ok<AGROW>
    end
    win_tie_loss = rows;
end

function rank_summary = local_build_rank_summary(rank_table, friedman_ranks)
    empty_cols = {'algorithm_name','function_count','mean_rank','best_count','global_avg_rank','comparable_function_count'};
    if isempty(rank_table)
        rank_summary = cell2table(cell(0, numel(empty_cols)), 'VariableNames', empty_cols);
        return;
    end

    algs = unique(string(rank_table.algorithm_name), 'stable');
    rows = cell2table(cell(0, numel(empty_cols)), 'VariableNames', empty_cols);
    for i = 1:numel(algs)
        alg = algs(i);
        subset = rank_table(string(rank_table.algorithm_name) == alg, :);
        global_rank = NaN;
        comparable_count = NaN;
        if ~isempty(friedman_ranks)
            fr = friedman_ranks(string(friedman_ranks.algorithm_name) == alg, :);
            if ~isempty(fr)
                global_rank = fr.avg_rank(1);
                if ismember('comparable_function_count', fr.Properties.VariableNames)
                    comparable_count = fr.comparable_function_count(1);
                end
            end
        end
        row = table(alg, height(subset), mean(subset.rank), sum(subset.rank == 1), global_rank, comparable_count, ...
            'VariableNames', empty_cols);
        rows = [rows; row]; %#ok<AGROW>
    end
    rank_summary = sortrows(rows, {'global_avg_rank', 'mean_rank'}, {'ascend', 'ascend'});
end

function wilcoxon_pairwise = local_build_wilcoxon_pairwise(run_results, main_algorithm)
    empty_cols = {'function_id','main_algorithm','other_algorithm','main_mean','other_mean','delta_mean','p_value','h','z_value','sample_size','direction','note'};
    if isempty(run_results)
        wilcoxon_pairwise = cell2table(cell(0, numel(empty_cols)), 'VariableNames', empty_cols);
        return;
    end

    rows = cell2table(cell(0, numel(empty_cols)), 'VariableNames', empty_cols);
    funcs = unique([run_results.function_id]);
    algs = unique(string({run_results.algorithm_name}), 'stable');
    algs = algs(algs ~= main_algorithm);
    has_signrank = exist('signrank', 'file') == 2;

    for fi = 1:numel(funcs)
        fid = funcs(fi);
        subset_f = run_results([run_results.function_id] == fid);
        for ai = 1:numel(algs)
            other = algs(ai);
            main_runs = subset_f(strcmp(string({subset_f.algorithm_name}), main_algorithm));
            other_runs = subset_f(strcmp(string({subset_f.algorithm_name}), other));
            [paired_main, paired_other] = local_pair_run_scores(main_runs, other_runs);
            p = NaN;
            h = NaN;
            z = NaN;
            note = "insufficient_samples";
            if numel(paired_main) >= 2 && numel(paired_other) >= 2
                if has_signrank
                    try
                        [p, h, stats] = signrank(paired_main, paired_other);
                        if isstruct(stats) && isfield(stats, 'zval')
                            z = stats.zval;
                        end
                        note = "wilcoxon_signed_rank";
                    catch ME
                        note = string(['signrank_error_' ME.identifier]);
                    end
                else
                    note = "signrank_unavailable";
                end
            end
            delta_mean = mean(paired_other) - mean(paired_main);
            if delta_mean > 0
                direction = "main_better";
            elseif delta_mean < 0
                direction = "main_worse";
            else
                direction = "tie";
            end
            row = table(fid, main_algorithm, other, mean(paired_main), mean(paired_other), delta_mean, p, h, z, numel(paired_main), direction, note, ...
                'VariableNames', empty_cols);
            rows = [rows; row]; %#ok<AGROW>
        end
    end

    wilcoxon_pairwise = rows;
end

function friedman_ranks = local_normalize_friedman_ranks(friedman_ranks)
    if isempty(friedman_ranks)
        friedman_ranks = cell2table(cell(0, 3), 'VariableNames', {'algorithm_name','avg_rank','comparable_function_count'});
    end
end

function improvement_delta = local_build_improvement_delta(summary_table, main_algorithm, base_algorithm)
    cols = {'function_id','main_algorithm','base_algorithm','main_mean','base_mean','delta_mean','main_std','base_std','delta_std','outcome'};
    if isempty(summary_table)
        improvement_delta = cell2table(cell(0, numel(cols)), 'VariableNames', cols);
        return;
    end

    fids = unique(summary_table.function_id, 'stable');
    rows = cell2table(cell(0, numel(cols)), 'VariableNames', cols);
    for i = 1:numel(fids)
        fid = fids(i);
        main_row = summary_table(string(summary_table.algorithm_name) == main_algorithm & summary_table.function_id == fid, :);
        base_row = summary_table(string(summary_table.algorithm_name) == base_algorithm & summary_table.function_id == fid, :);
        if isempty(main_row) || isempty(base_row)
            continue;
        end
        delta_mean = base_row.mean(1) - main_row.mean(1);
        delta_std = base_row.std(1) - main_row.std(1);
        if delta_mean > 0
            outcome = "improved";
        elseif delta_mean < 0
            outcome = "degraded";
        else
            outcome = "tie";
        end
        row = table(fid, main_algorithm, base_algorithm, main_row.mean(1), base_row.mean(1), delta_mean, main_row.std(1), base_row.std(1), delta_std, outcome, ...
            'VariableNames', cols);
        rows = [rows; row]; %#ok<AGROW>
    end
    improvement_delta = rows;
end

function per_run_records = local_build_per_run_records(run_results, run_manifest, cfg)
    cols = {'algorithm_name','suite','function_id','run_id','seed','seed_source','best_score','runtime','dimension','population_size','maxFEs','used_FEs','fe_control_mode','fe_control_note','status','error_message','trace_file'};
    if isempty(run_results)
        per_run_records = cell2table(cell(0, numel(cols)), 'VariableNames', cols);
        return;
    end

    rows = cell2table(cell(0, numel(cols)), 'VariableNames', cols);
    for i = 1:numel(run_results)
        rr = run_results(i);
        mf = run_manifest(string(run_manifest.algorithm_name) == string(rr.algorithm_name) & run_manifest.function_id == rr.function_id & run_manifest.run_id == rr.run_id, :);
        status = "unknown";
        error_message = "";
        if ~isempty(mf)
            status = string(mf.status(1));
            error_message = string(mf.error_message(1));
        end
        trace_file = sprintf('%s_F%d_run%03d_curve.csv', lower(rr.algorithm_name), rr.function_id, rr.run_id);
        row = table(string(rr.algorithm_name), string(rr.suite), rr.function_id, rr.run_id, rr.seed, string(local_seed_mode(cfg)), ...
            rr.best_score, rr.runtime, rr.dimension, rr.population_size, rr.maxFEs, rr.used_FEs, string(rr.fe_control_mode), ...
            string(rr.fe_control_note), status, error_message, string(trace_file), 'VariableNames', cols);
        rows = [rows; row]; %#ok<AGROW>
    end
    per_run_records = rows;
end

function failures = local_build_failures_table(registry, smoke_data, formal_data)
    cols = {'suite','algorithm_name','stage','status','reason','entry_file'};
    rows = cell2table(cell(0, numel(cols)), 'VariableNames', cols);
    for i = 1:height(registry)
        alg = registry.algorithm_name(i);
        if registry.pre_scan_status(i) ~= "runnable_pre_scan"
            row = table(registry.suite(i), alg, "scan", registry.pre_scan_status(i), registry.notes(i), registry.entry_file(i), 'VariableNames', cols);
            rows = [rows; row]; %#ok<AGROW>
            continue;
        end
        if registry.smoke_status(i) == "smoke_failed" || registry.smoke_status(i) == "smoke_partial" || endsWith(registry.smoke_status(i), "_stage_error")
            row = table(registry.suite(i), alg, "smoke", registry.smoke_status(i), registry.notes(i), registry.entry_file(i), 'VariableNames', cols);
            rows = [rows; row]; %#ok<AGROW>
        elseif registry.formal_status(i) == "not_selected"
            row = table(registry.suite(i), alg, "formal", "not_selected", "Excluded from formal because smoke did not fully pass.", registry.entry_file(i), 'VariableNames', cols);
            rows = [rows; row]; %#ok<AGROW>
        elseif registry.formal_status(i) == "formal_failed" || registry.formal_status(i) == "formal_partial" || endsWith(registry.formal_status(i), "_stage_error")
            row = table(registry.suite(i), alg, "formal", registry.formal_status(i), registry.notes(i), registry.entry_file(i), 'VariableNames', cols);
            rows = [rows; row]; %#ok<AGROW>
        end
    end

    rows = [rows; local_manifest_failures(smoke_data.run_manifest, "smoke", registry); local_manifest_failures(formal_data.run_manifest, "formal", registry)]; %#ok<AGROW>
    failures = rows;
end

function rows = local_manifest_failures(run_manifest, stage_name, registry)
    cols = {'suite','algorithm_name','stage','status','reason','entry_file'};
    rows = cell2table(cell(0, numel(cols)), 'VariableNames', cols);
    if isempty(run_manifest)
        return;
    end
    run_manifest.algorithm_name = string(run_manifest.algorithm_name);
    run_manifest.status = string(run_manifest.status);
    failed = run_manifest(run_manifest.status == "failed", :);
    for i = 1:height(failed)
        idx = find(registry.algorithm_name == failed.algorithm_name(i), 1, 'first');
        entry_file = "";
        if ~isempty(idx)
            entry_file = registry.entry_file(idx);
        end
        row = table(string(failed.suite(i)), string(failed.algorithm_name(i)), string(stage_name), string(failed.status(i)), string(failed.error_message(i)), entry_file, ...
            'VariableNames', cols);
        rows = [rows; row]; %#ok<AGROW>
    end
end

function seeds = local_build_seeds_table(run_manifest, cfg)
    cols = {'suite','function_id','run_id','algorithm_name','seed','seed_source'};
    if isempty(run_manifest)
        seeds = cell2table(cell(0, numel(cols)), 'VariableNames', cols);
        return;
    end
    seeds = run_manifest(:, {'suite','function_id','run_id','algorithm_name','seed'});
    seeds.seed_source = repmat(string(local_seed_mode(cfg)), height(seeds), 1);
end

function seed_check = local_build_seed_check(run_manifest)
    cols = {'suite','function_id','run_id','algorithm_count','unique_seed_count','seed_values','pass'};
    if isempty(run_manifest)
        seed_check = cell2table(cell(0, numel(cols)), 'VariableNames', cols);
        return;
    end

    run_manifest.suite = string(run_manifest.suite);
    groups = findgroups(run_manifest.suite, run_manifest.function_id, run_manifest.run_id);
    suite = splitapply(@(x) x(1), run_manifest.suite, groups);
    fid = splitapply(@(x) x(1), run_manifest.function_id, groups);
    run_id = splitapply(@(x) x(1), run_manifest.run_id, groups);
    alg_count = splitapply(@numel, run_manifest.algorithm_name, groups);
    uniq_seed_count = splitapply(@(x) numel(unique(x)), run_manifest.seed, groups);
    seed_values = splitapply(@(x) {strjoin(string(unique(x))', ';')}, run_manifest.seed, groups);
    pass = uniq_seed_count == 1;
    seed_check = table(suite, fid, run_id, alg_count, uniq_seed_count, string(seed_values), pass, 'VariableNames', cols);
end

function local_copy_trace_curves(stage_result_dir, target_dir)
    if strlength(string(stage_result_dir)) == 0
        return;
    end
    src_dir = fullfile(stage_result_dir, 'curves');
    if ~isfolder(src_dir)
        return;
    end
    listing = dir(fullfile(src_dir, '*.csv'));
    for i = 1:numel(listing)
        copyfile(fullfile(listing(i).folder, listing(i).name), fullfile(target_dir, listing(i).name));
    end
end

function local_copy_runner_figures(stage_result_dir, dirs, suite_name, cfg)
    if strlength(string(stage_result_dir)) == 0
        return;
    end
    src_root = fullfile(stage_result_dir, 'figures');
    if ~isfolder(src_root)
        return;
    end
    dim_name = sprintf('D%d', cfg.dim);
    local_copy_dir_if_exists(fullfile(src_root, 'convergence_curves', dim_name), dirs.figures_convergence);
    local_copy_dir_if_exists(fullfile(src_root, 'boxplots', dim_name), dirs.figures_boxplots);
    local_copy_dir_if_exists(fullfile(src_root, 'friedman_radar', dim_name), dirs.figures_ranks);

    for fi = 1:numel(cfg.plot.formats)
        ext = cfg.plot.formats{fi};
        src = fullfile(src_root, 'friedman_radar', dim_name, sprintf('friedman_%s_D%d.%s', lower(suite_name), cfg.dim, ext));
        if isfile(src)
            copyfile(src, fullfile(dirs.figures_paper_ready, sprintf('friedman_%s_D%d.%s', lower(suite_name), cfg.dim, ext)));
        end
    end
end

function local_copy_paper_ready_curves(stage_result_dir, paper_ready_dir, suite_name, cfg)
    if strlength(string(stage_result_dir)) == 0
        return;
    end
    src_root = fullfile(stage_result_dir, 'figures', 'convergence_curves', sprintf('D%d', cfg.dim));
    if ~isfolder(src_root) || ~isfield(cfg.paper_funcs, suite_name)
        return;
    end
    fids = cfg.paper_funcs.(suite_name);
    for i = 1:numel(fids)
        for fi = 1:numel(cfg.plot.formats)
            ext = cfg.plot.formats{fi};
            file_name = sprintf('convergence_%s_D%d_F%d.%s', lower(suite_name), cfg.dim, fids(i), ext);
            src = fullfile(src_root, file_name);
            if isfile(src)
                copyfile(src, fullfile(paper_ready_dir, file_name));
            end
        end
    end
end

function local_create_win_loss_figure(win_tie_loss, out_dir, paper_ready_dir, suite_name)
    if isempty(win_tie_loss)
        return;
    end
    fig = figure('Visible', 'off');
    cleanup_obj = onCleanup(@() close(fig)); %#ok<NASGU>
    X = categorical(cellstr(win_tie_loss.other_algorithm));
    Y = [win_tie_loss.win_count, win_tie_loss.tie_count, win_tie_loss.loss_count];
    bar(X, Y, 'stacked');
    ylabel('Function count');
    title(sprintf('Win/Tie/Loss vs main on %s', upper(suite_name)));
    legend({'Win', 'Tie', 'Loss'}, 'Location', 'best');
    grid on;
    out_file = fullfile(out_dir, sprintf('win_loss_%s.png', lower(suite_name)));
    exportgraphics(fig, out_file, 'Resolution', 200);
    copyfile(out_file, fullfile(paper_ready_dir, sprintf('win_loss_%s.png', lower(suite_name))));
end

function local_create_rank_summary_figure(rank_summary, out_dir, paper_ready_dir, suite_name)
    if isempty(rank_summary)
        return;
    end
    fig = figure('Visible', 'off');
    cleanup_obj = onCleanup(@() close(fig)); %#ok<NASGU>
    vals = rank_summary.global_avg_rank;
    vals(~isfinite(vals)) = rank_summary.mean_rank(~isfinite(vals));
    bar(categorical(cellstr(rank_summary.algorithm_name)), vals);
    ylabel('Average rank');
    title(sprintf('Rank summary on %s', upper(suite_name)));
    grid on;
    out_file = fullfile(out_dir, sprintf('rank_summary_%s.png', lower(suite_name)));
    exportgraphics(fig, out_file, 'Resolution', 200);
    copyfile(out_file, fullfile(paper_ready_dir, sprintf('rank_summary_%s.png', lower(suite_name))));
end

function local_write_table_variants(T, base_name, csv_dir, markdown_dir, latex_dir)
    local_copy_or_write_table(T, fullfile(csv_dir, [base_name '.csv']));
    local_write_markdown_table(fullfile(markdown_dir, [base_name '.md']), T);
    local_write_latex_table(fullfile(latex_dir, [base_name '.tex']), T, base_name);
end

function local_write_readme(file_path, suite_name, cfg, registry, smoke_stage, formal_stage)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# 算法结尾阶段结果包\n\n');
    fprintf(fid, '- suite: `%s`\n', suite_name);
    fprintf(fid, '- 主算法: `%s`（入口映射为 `BBO_route_a_budget_adaptive_bbo`）\n', cfg.main_algorithm);
    fprintf(fid, '- 对比算法请求集: `%s`\n', strjoin(cellstr(string(cfg.algorithms)), '`, `'));
    fprintf(fid, '- 实际 formal 进入算法: `%s`\n', strjoin(cellstr(registry.algorithm_name(registry.selected_for_formal)), '`, `'));
    fprintf(fid, '\n## 复现与结果\n\n');
    fprintf(fid, '- smoke 结果目录: `%s`\n', char(smoke_stage.result_dir));
    fprintf(fid, '- formal 结果目录: `%s`\n', char(formal_stage.result_dir));
    fprintf(fid, '- 关键文件: `summary/summary_mean_std.csv`, `summary/win_tie_loss.csv`, `summary/wilcoxon_pairwise.csv`, `summary/friedman_ranks.csv`, `diagnostics/fairness_check.md`, `improvement/IMPROVEMENT_DELTA.csv`\n');
end

function local_write_experiment_protocol(file_path, suite_name, cfg, registry, formal_stage)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# EXPERIMENT_PROTOCOL\n\n');
    fprintf(fid, '- suite: `%s`\n', suite_name);
    fprintf(fid, '- functions: `%s`\n', mat2str(cfg.formal_func_ids.(suite_name)));
    fprintf(fid, '- dimension: `%d`\n', cfg.dim);
    fprintf(fid, '- population size: `%d`\n', cfg.pop_size);
    fprintf(fid, '- maxFEs: `%d`\n', cfg.maxFEs);
    fprintf(fid, '- runs: `%d`\n', cfg.runs);
    fprintf(fid, '- stopping criteria: `hard_stop_on_fe_limit=true`, counted-objective wrapper active\n');
    fprintf(fid, '- seed mode: `%s`\n', local_seed_mode(cfg));
    fprintf(fid, '- formal gate: mex runtime input_data readability required for CEC suites\n');
    fprintf(fid, '- protocol invariants kept: suite / func_ids / dim / pop_size / maxFEs / runs / stop criteria\n');
    if ~formal_stage.pass
        fprintf(fid, '- formal stage error: `%s`\n', char(formal_stage.error_message));
    end
    excluded = registry.algorithm_name(~registry.selected_for_formal & registry.pre_scan_status == "runnable_pre_scan");
    if ~isempty(excluded)
        fprintf(fid, '- formal excluded algorithms: `%s`\n', strjoin(cellstr(excluded), '`, `'));
    end
end

function local_write_parameter_sources(file_path, registry)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# PARAMETER_SOURCES\n\n');
    fprintf(fid, '| algorithm | parameter_source | defaults | entry_file | notes |\n');
    fprintf(fid, '| --- | --- | --- | --- | --- |\n');
    for i = 1:height(registry)
        fprintf(fid, '| %s | %s | %s | %s | %s |\n', ...
            local_md_escape(registry.algorithm_name(i)), ...
            local_md_escape(registry.parameter_source(i)), ...
            local_md_escape(registry.parameter_defaults(i)), ...
            local_md_escape(registry.entry_file(i)), ...
            local_md_escape(registry.notes(i)));
    end
end

function local_write_reproducibility(file_path, suite_name, cfg, formal_stage, dirs)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# REPRODUCIBILITY\n\n');
    fprintf(fid, '```matlab\n');
    fprintf(fid, 'cfg = struct();\n');
    fprintf(fid, 'cfg.suites = {''%s''};\n', suite_name);
    fprintf(fid, 'cfg.dim = %d;\n', cfg.dim);
    fprintf(fid, 'cfg.pop_size = %d;\n', cfg.pop_size);
    fprintf(fid, 'cfg.maxFEs = %d;\n', cfg.maxFEs);
    fprintf(fid, 'cfg.runs = %d;\n', cfg.runs);
    fprintf(fid, 'cfg.rng_seed = %d;\n', cfg.rng_seed);
    fprintf(fid, 'cfg.output_root = fullfile(''results'',''算法结尾阶段'');\n');
    fprintf(fid, 'report = run_routea_final_compare(cfg);\n');
    fprintf(fid, '```\n\n');
    fprintf(fid, '- seed policy: `%s`\n', local_seed_mode(cfg));
    fprintf(fid, '- formal result dir: `%s`\n', char(formal_stage.result_dir));
    fprintf(fid, '- traces dir: `%s`\n', dirs.raw_traces);
    fprintf(fid, '- paper-ready figures dir: `%s`\n', dirs.figures_paper_ready);
end

function local_write_env_snapshot(file_path, repo_root, suite_name, cfg)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, 'timestamp=%s\n', cfg.timestamp);
    fprintf(fid, 'suite=%s\n', suite_name);
    fprintf(fid, 'matlab_version=%s\n', version);
    fprintf(fid, 'computer=%s\n', computer);
    fprintf(fid, 'repo_root=%s\n', repo_root);
    fprintf(fid, 'rng_seed=%d\n', cfg.rng_seed);
    fprintf(fid, 'seed_mode=%s\n', local_seed_mode(cfg));
    fprintf(fid, 'cec_runtime_dir_mode=%s\n', getenv('CEC_RUNTIME_DIR_MODE'));
    fprintf(fid, 'git_commit=%s\n', strtrim(local_system_capture(sprintf('git -C "%s" rev-parse HEAD', repo_root))));
    fprintf(fid, 'git_branch=%s\n', strtrim(local_system_capture(sprintf('git -C "%s" rev-parse --abbrev-ref HEAD', repo_root))));
end

function local_write_compatibility_report(file_path, registry, smoke_stage, formal_stage)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# compatibility_report\n\n');
    fprintf(fid, '- smoke stage pass: `%d`\n', smoke_stage.pass);
    fprintf(fid, '- formal stage pass: `%d`\n', formal_stage.pass);
    if ~smoke_stage.pass
        fprintf(fid, '- smoke error: `%s`\n', char(smoke_stage.error_message));
    end
    if ~formal_stage.pass
        fprintf(fid, '- formal error: `%s`\n', char(formal_stage.error_message));
    end
    fprintf(fid, '\n| algorithm | entry_file | pre_scan | smoke | formal | selected_for_formal | notes |\n');
    fprintf(fid, '| --- | --- | --- | --- | --- | --- | --- |\n');
    for i = 1:height(registry)
        fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s |\n', ...
            local_md_escape(registry.algorithm_name(i)), ...
            local_md_escape(registry.entry_file(i)), ...
            local_md_escape(registry.pre_scan_status(i)), ...
            local_md_escape(registry.smoke_status(i)), ...
            local_md_escape(registry.formal_status(i)), ...
            local_md_escape(string(registry.selected_for_formal(i))), ...
            local_md_escape(registry.notes(i)));
    end
end

function local_write_missing_algorithms(file_path, registry)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# missing_algorithms\n\n');
    missing = registry(registry.pre_scan_status ~= "runnable_pre_scan", :);
    if isempty(missing)
        fprintf(fid, '- 无预扫描缺失算法。\n');
    else
        for i = 1:height(missing)
            fprintf(fid, '- `%s`: `%s`，entry=`%s`，原因=`%s`\n', ...
                missing.algorithm_name(i), missing.pre_scan_status(i), missing.entry_file(i), missing.notes(i));
        end
    end
end

function local_write_fairness_check(file_path, cfg, registry, run_manifest, seed_check, exact_match_warnings, suite_name)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# fairness_check\n\n');
    fprintf(fid, '- suite: `%s`\n', suite_name);
    fprintf(fid, '- protocol fixed: dim=`%d`, pop_size=`%d`, maxFEs=`%d`, runs=`%d`\n', cfg.dim, cfg.pop_size, cfg.maxFEs, cfg.runs);
    fprintf(fid, '- paired seeds pass groups: `%d/%d`\n', sum(seed_check.pass), height(seed_check));
    fprintf(fid, '- exact-match warnings: `%d`\n', height(exact_match_warnings));
    fprintf(fid, '- selected formal algorithms: `%s`\n', strjoin(cellstr(registry.algorithm_name(registry.selected_for_formal)), '`, `'));
    if ~isempty(run_manifest)
        algs = unique(string(run_manifest.algorithm_name), 'stable');
        fprintf(fid, '\n## used_FEs by algorithm\n\n');
        for i = 1:numel(algs)
            subset = run_manifest(string(run_manifest.algorithm_name) == algs(i), :);
            fprintf(fid, '- `%s`: min=%d, mean=%.2f, max=%d, modes=`%s`\n', ...
                algs(i), min(subset.used_FEs), mean(subset.used_FEs), max(subset.used_FEs), ...
                strjoin(cellstr(unique(string(subset.fe_control_mode), 'stable')), ','));
        end
    end
end

function local_write_statistical_tests(file_path, wilcoxon_pairwise, friedman_summary, friedman_ranks, cfg)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# statistical_tests\n\n');
    fprintf(fid, '- 主算法: `%s`\n', cfg.main_algorithm);
    if isempty(wilcoxon_pairwise)
        fprintf(fid, '- Wilcoxon pairwise: 无可用结果。\n');
    else
        others = unique(string(wilcoxon_pairwise.other_algorithm), 'stable');
        for i = 1:numel(others)
            subset = wilcoxon_pairwise(string(wilcoxon_pairwise.other_algorithm) == others(i), :);
            sig = sum(isfinite(subset.p_value) & subset.p_value < 0.05 & subset.direction == "main_better");
            bad = sum(isfinite(subset.p_value) & subset.p_value < 0.05 & subset.direction == "main_worse");
            fprintf(fid, '- `%s`: functions=%d, significant_main_better=%d, significant_main_worse=%d, notes=`%s`\n', ...
                others(i), height(subset), sig, bad, strjoin(cellstr(unique(string(subset.note), 'stable')), ','));
        end
    end
    if ~isempty(friedman_summary)
        F = friedman_summary(1, :);
        fprintf(fid, '- Friedman p_value=`%s`, note=`%s`\n', num2str(F.p_value(1)), string(F.note(1)));
    end
    if ~isempty(friedman_ranks)
        fprintf(fid, '- best average rank: `%s`\n', string(friedman_ranks.algorithm_name(1)));
    end
end

function local_write_key_findings(file_path, registry, win_tie_loss, rank_summary, improvement_delta, cfg)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# key_findings\n\n');
    if isempty(rank_summary)
        fprintf(fid, '- 当前无 formal 汇总结果，无法形成有效结论。\n');
        return;
    end
    fprintf(fid, '- 平均秩最优算法：`%s`\n', string(rank_summary.algorithm_name(1)));
    if ~isempty(improvement_delta)
        fprintf(fid, '- 主算法相对 `%s`：improved=%d, degraded=%d, avg_delta_mean=%.6g, avg_delta_std=%.6g\n', ...
            cfg.base_algorithm, sum(improvement_delta.delta_mean > 0), sum(improvement_delta.delta_mean < 0), ...
            local_safe_mean(improvement_delta.delta_mean), local_safe_mean(improvement_delta.delta_std));
    end
    missing = registry(registry.pre_scan_status ~= "runnable_pre_scan", :);
    if ~isempty(missing)
        fprintf(fid, '- 覆盖受缺失算法影响：`%s`\n', strjoin(cellstr(missing.algorithm_name), '`, `'));
    end
    if ~isempty(win_tie_loss)
        fprintf(fid, '- 主算法对各基线的胜负统计详见 `summary/win_tie_loss.csv`。\n');
    end
end

function local_write_main_vs_base(file_path, improvement_delta, cfg)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# MAIN_VS_BASE\n\n');
    fprintf(fid, '- main: `%s`\n', cfg.main_algorithm);
    fprintf(fid, '- base: `%s`\n', cfg.base_algorithm);
    if isempty(improvement_delta)
        fprintf(fid, '- 无可用对比结果。\n');
        return;
    end
    fprintf(fid, '- improved=%d, degraded=%d, tie=%d\n', ...
        sum(improvement_delta.delta_mean > 0), ...
        sum(improvement_delta.delta_mean < 0), ...
        sum(improvement_delta.delta_mean == 0));
    fprintf(fid, '- avg delta mean = %.6g\n', local_safe_mean(improvement_delta.delta_mean));
    fprintf(fid, '- avg delta std = %.6g\n', local_safe_mean(improvement_delta.delta_std));
end

function local_write_failure_cases(file_path, improvement_delta, cfg)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# FAILURE_CASES\n\n');
    fprintf(fid, '- main: `%s`\n', cfg.main_algorithm);
    if isempty(improvement_delta)
        fprintf(fid, '- 无可用数据。\n');
        return;
    end
    bad = improvement_delta(improvement_delta.delta_mean <= 0, :);
    if isempty(bad)
        fprintf(fid, '- 当前结果中未发现相对 `%s` 的均值退化函数。\n', cfg.base_algorithm);
        return;
    end
    for i = 1:height(bad)
        fprintf(fid, '- F%d: delta_mean=%.6g, delta_std=%.6g, outcome=%s\n', ...
            bad.function_id(i), bad.delta_mean(i), bad.delta_std(i), bad.outcome(i));
    end
end

function local_write_analysis_notes(file_path, suite_name, registry, smoke_stage, formal_stage, package_root)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# analysis_notes\n\n');
    fprintf(fid, '- suite: `%s`\n', suite_name);
    fprintf(fid, '- package_root: `%s`\n', package_root);
    fprintf(fid, '- smoke_dir: `%s`\n', char(smoke_stage.result_dir));
    fprintf(fid, '- formal_dir: `%s`\n', char(formal_stage.result_dir));
    fprintf(fid, '- requested algorithms: `%s`\n', strjoin(cellstr(registry.algorithm_name), '`, `'));
    fprintf(fid, '- formal selected algorithms: `%s`\n', strjoin(cellstr(registry.algorithm_name(registry.selected_for_formal)), '`, `'));
end

function local_write_limitations(file_path, cfg, registry, formal_stage)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# limitations\n\n');
    if cfg.maxFEs ~= 300000 || cfg.runs ~= 30 || cfg.dim ~= 10 || cfg.pop_size ~= 30
        fprintf(fid, '- 当前执行不是默认最终 formal 口径（默认 D10 / pop30 / FE300000 / runs30）。\n');
    end
    missing = registry(registry.pre_scan_status ~= "runnable_pre_scan", :);
    if ~isempty(missing)
        fprintf(fid, '- 固定对比集未完整覆盖：`%s`\n', strjoin(cellstr(missing.algorithm_name), '`, `'));
    end
    partial = registry(registry.formal_status == "formal_partial" | registry.formal_status == "formal_failed", :);
    if ~isempty(partial)
        fprintf(fid, '- formal 期间存在失败或部分失败算法：`%s`\n', strjoin(cellstr(partial.algorithm_name), '`, `'));
    end
    if ~formal_stage.pass
        fprintf(fid, '- formal stage 未成功完成：`%s`\n', char(formal_stage.error_message));
    end
    fprintf(fid, '- `PSO/DE/GWO/WOA/SHADE` 当前来自 mealpy 转写 MATLAB 版本，不应误写成官方原始 MATLAB 包。\n');
end

function local_write_next_actions(file_path, cfg, registry, formal_stage)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# next_actions\n\n');
    if cfg.maxFEs ~= 300000 || cfg.runs ~= 30
        fprintf(fid, '- 先按默认最终协议补跑：D10 / pop30 / FE300000 / runs30。\n');
    end
    if any(registry.pre_scan_status ~= "runnable_pre_scan")
        fprintf(fid, '- 补齐缺失算法，优先确认 `RIME` 是否存在真实 MATLAB 入口。\n');
    end
    if any(registry.formal_status == "formal_failed" | registry.formal_status == "formal_partial")
        fprintf(fid, '- 对 formal 失败算法做专项补跑和入口修复，再更新结果包。\n');
    end
    fprintf(fid, '- 若主算法与基线差距已明确，下一轮优先补：消融、参数敏感性、应用验证。\n');
    if ~formal_stage.pass
        fprintf(fid, '- formal stage 尚未稳定完成，当前首先应解决 formal gate/运行错误再下结论。\n');
    end
end

function local_copy_or_write_table(T, file_path)
    if isempty(T)
        T = local_empty_table_from_path(file_path);
    end
    writetable(T, file_path);
end

function T = local_empty_table_from_path(file_path)
    [~, name, ~] = fileparts(file_path);
    switch lower(name)
        case 'run_manifest'
            T = local_empty_manifest_table();
        case {'summary', 'summary_mean_std'}
            T = local_empty_summary_table();
        case 'win_tie_loss'
            T = cell2table(cell(0, 8), 'VariableNames', {'main_algorithm','other_algorithm','comparable_functions','win_count','tie_count','loss_count','avg_mean_delta','avg_std_delta'});
        case 'rank_summary'
            T = cell2table(cell(0, 6), 'VariableNames', {'algorithm_name','function_count','mean_rank','best_count','global_avg_rank','comparable_function_count'});
        case 'wilcoxon_pairwise'
            T = cell2table(cell(0, 12), 'VariableNames', {'function_id','main_algorithm','other_algorithm','main_mean','other_mean','delta_mean','p_value','h','z_value','sample_size','direction','note'});
        case 'friedman_ranks'
            T = cell2table(cell(0, 3), 'VariableNames', {'algorithm_name','avg_rank','comparable_function_count'});
        case 'improvement_delta'
            T = cell2table(cell(0, 10), 'VariableNames', {'function_id','main_algorithm','base_algorithm','main_mean','base_mean','delta_mean','main_std','base_std','delta_std','outcome'});
        case 'per_run_records'
            T = cell2table(cell(0, 17), 'VariableNames', {'algorithm_name','suite','function_id','run_id','seed','seed_source','best_score','runtime','dimension','population_size','maxFEs','used_FEs','fe_control_mode','fe_control_note','status','error_message','trace_file'});
        case 'failures'
            T = cell2table(cell(0, 6), 'VariableNames', {'suite','algorithm_name','stage','status','reason','entry_file'});
        case 'seeds'
            T = cell2table(cell(0, 6), 'VariableNames', {'suite','function_id','run_id','algorithm_name','seed','seed_source'});
        case 'seed_check'
            T = cell2table(cell(0, 7), 'VariableNames', {'suite','function_id','run_id','algorithm_count','unique_seed_count','seed_values','pass'});
        otherwise
            T = table();
    end
end

function local_write_markdown_table(file_path, T)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    if isempty(T)
        fprintf(fid, 'No rows.\n');
        return;
    end
    vars = T.Properties.VariableNames;
    fprintf(fid, '| %s |\n', strjoin(vars, ' | '));
    fprintf(fid, '| %s |\n', strjoin(repmat({'---'}, 1, numel(vars)), ' | '));
    data = table2cell(T);
    for i = 1:size(data, 1)
        row = cell(1, size(data, 2));
        for j = 1:size(data, 2)
            row{j} = local_md_escape(local_to_string(data{i, j}));
        end
        fprintf(fid, '| %s |\n', strjoin(row, ' | '));
    end
end

function local_write_latex_table(file_path, T, label_base)
    fid = fopen(file_path, 'w');
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    if isempty(T)
        fprintf(fid, '%% empty table\n');
        return;
    end
    vars = T.Properties.VariableNames;
    fprintf(fid, '\\begin{table}[htbp]\n\\centering\n');
    fprintf(fid, '\\caption{%s}\n', local_latex_escape(label_base));
    fprintf(fid, '\\label{tab:%s}\n', local_latex_escape(label_base));
    fprintf(fid, '\\begin{tabular}{%s}\n', repmat('l', 1, numel(vars)));
    fprintf(fid, '\\hline\n');
    fprintf(fid, '%s \\\\\n', strjoin(cellfun(@local_latex_escape, vars, 'UniformOutput', false), ' & '));
    fprintf(fid, '\\hline\n');
    data = table2cell(T);
    for i = 1:size(data, 1)
        row = cell(1, size(data, 2));
        for j = 1:size(data, 2)
            row{j} = local_latex_escape(local_to_string(data{i, j}));
        end
        fprintf(fid, '%s \\\\\n', strjoin(row, ' & '));
    end
    fprintf(fid, '\\hline\n\\end{tabular}\n\\end{table}\n');
end

function seed_mode = local_seed_mode(cfg)
    if ~isempty(cfg.seed_list)
        seed_mode = 'explicit_seed_list_paired';
    else
        seed_mode = 'paired_seed_derived_by_runner';
    end
end

function note = local_scan_note(canonical, pre_scan_status, spec)
    switch upper(canonical)
        case 'ROUTE_A_BUDGET_ADAPTIVE_BBO'
            note = sprintf('Main algorithm mapped to %s.', spec.entry_name);
        case 'BBO_BASE'
            note = 'Suite-specific BBO raw source from third_party/bbo_raw.';
        case {'PSO', 'DE', 'GWO', 'WOA', 'SHADE'}
            note = sprintf('Direct MATLAB port under %s.', spec.source_group);
        case 'RIME'
            note = 'Original raw MATLAB source from third_party/sbo_raw/Rime Optimization Algorithm (RIME)-2023.';
        otherwise
            note = sprintf('pre_scan=%s', pre_scan_status);
    end
end

function label = local_parameter_source_label(canonical, source_group)
    switch upper(canonical)
        case 'ROUTE_A_BUDGET_ADAPTIVE_BBO'
            label = 'src_improved_bbo_internal_defaults';
        case 'BBO_BASE'
            label = 'third_party_bbo_raw_internal_defaults';
        case {'PSO', 'DE', 'GWO', 'WOA', 'SHADE', 'BBO_ORIG'}
            label = 'mealpy_converted_originals_embedded_defaults';
        case {'SBO', 'HHO'}
            label = 'third_party_sbo_raw_internal_defaults';
        case 'RIME'
            label = 'third_party_sbo_raw_internal_defaults';
        otherwise
            label = char(source_group);
    end
end

function txt = local_parameter_defaults(canonical)
    switch upper(canonical)
        case 'ROUTE_A_BUDGET_ADAPTIVE_BBO'
            txt = 'Internal fixed schedules in source; public inputs are N, Max_iteration, lb, ub, dim, fobj.';
        case 'BBO_BASE'
            txt = 'Original raw MATLAB code; no extra public opts beyond N, Max_iteration, lb, ub, dim, fobj.';
        case 'PSO'
            txt = 'c1=2.05, c2=2.05, w=0.4';
        case 'DE'
            txt = 'wf=0.1, cr=0.9, strategy=0';
        case 'GWO'
            txt = 'No extra public opts.';
        case 'WOA'
            txt = 'No extra public opts.';
        case 'HHO'
            txt = 'Original raw MATLAB code; no extra public opts.';
        case 'SBO'
            txt = 'Original raw MATLAB code; internal defaults, public MaxFEs.';
        case 'SHADE'
            txt = 'miu_f=0.5, miu_cr=0.5';
        case 'RIME'
            txt = 'Original raw MATLAB code; internal W=5 soft-rime parameter, public inputs are N, Max_iter, lb, ub, dim, fobj.';
        otherwise
            txt = 'Not documented.';
    end
end

function name = local_resolved_entry_name(resolved)
    name = '';
    if isfield(resolved, 'entry_name') && ~isempty(resolved.entry_name)
        name = resolved.entry_name;
    elseif isfield(resolved, 'entry_func') && ~isempty(resolved.entry_func)
        name = resolved.entry_func;
    end
end

function out = local_append_note(old_note, new_note)
    if strlength(string(old_note)) == 0
        out = string(new_note);
    elseif strlength(string(new_note)) == 0
        out = string(old_note);
    else
        out = string(old_note) + " | " + string(new_note);
    end
end

function [xa, xb] = local_pair_run_scores(main_runs, other_runs)
    xa = [];
    xb = [];
    if isempty(main_runs) || isempty(other_runs)
        return;
    end
    main_ids = [main_runs.run_id];
    other_ids = [other_runs.run_id];
    common_ids = intersect(main_ids, other_ids, 'stable');
    xa = zeros(numel(common_ids), 1);
    xb = zeros(numel(common_ids), 1);
    for i = 1:numel(common_ids)
        xa(i) = main_runs(find(main_ids == common_ids(i), 1, 'first')).best_score;
        xb(i) = other_runs(find(other_ids == common_ids(i), 1, 'first')).best_score;
    end
end

function local_copy_dir_if_exists(src_dir, dst_dir)
    if ~isfolder(src_dir)
        return;
    end
    listing = dir(fullfile(src_dir, '*'));
    listing = listing(~[listing.isdir]);
    for i = 1:numel(listing)
        copyfile(fullfile(listing(i).folder, listing(i).name), fullfile(dst_dir, listing(i).name));
    end
end

function txt = local_system_capture(cmd)
    [~, txt] = system(cmd);
end

function out = local_make_abs_path(repo_root, p)
    p = char(string(p));
    if isempty(p)
        out = repo_root;
        return;
    end
    if local_is_abs_path(p)
        out = p;
    else
        out = fullfile(repo_root, p);
    end
end

function tf = local_is_abs_path(p)
    p = char(string(p));
    tf = numel(p) >= 2 && p(2) == ':';
end

function value = local_safe_mean(x)
    if isempty(x)
        value = NaN;
    else
        value = mean(x);
    end
end

function txt = local_to_string(v)
    if isstring(v) || ischar(v)
        txt = char(string(v));
    elseif isnumeric(v) || islogical(v)
        if isempty(v)
            txt = '';
        elseif isscalar(v)
            txt = num2str(v);
        else
            txt = mat2str(v);
        end
    else
        txt = char(string(v));
    end
end

function txt = local_md_escape(v)
    txt = strrep(char(string(v)), '|', '\|');
    txt = strrep(txt, newline, '<br>');
end

function txt = local_latex_escape(v)
    txt = char(string(v));
    txt = strrep(txt, '\', '\textbackslash ');
    txt = strrep(txt, '_', '\_');
    txt = strrep(txt, '%', '\%');
    txt = strrep(txt, '&', '\&');
    txt = strrep(txt, '#', '\#');
end

function T = local_empty_manifest_table()
    T = table(strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
        'VariableNames', {'algorithm_name','suite','function_id','run_id','seed','maxFEs','used_FEs','fe_control_mode','status','error_message'});
end

function T = local_empty_registry_table()
    T = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
        strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), false(0, 1), strings(0, 1), strings(0, 1), ...
        strings(0, 1), strings(0, 1), strings(0, 1), ...
        'VariableNames', {'suite','requested_name','algorithm_name','paper_name','internal_id','entry_name','entry_file','algorithm_dir', ...
        'callable_type','parameter_source','parameter_defaults','seed_mode','budget_arg','output_mode','selected_for_formal','pre_scan_status', ...
        'smoke_status','formal_status','status','notes'});
end

function T = local_empty_inventory_table()
    T = table(strings(0, 1), false(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
        'VariableNames', {'algorithm_name','is_runnable','entry_name','algorithm_dir','budget_arg','fe_control_mode','note'});
end

function T = local_empty_summary_table()
    T = table(strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
        'VariableNames', {'algorithm_name','function_id','best','mean','std','worst','median','avg_runtime','avg_used_FEs'});
end

function T = local_empty_exact_match_table()
    T = table(zeros(0, 1), strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), false(0, 1), ...
        'VariableNames', {'function_id','algorithm_a','algorithm_b','equal_run_count','expected_runs','is_full_exact_match'});
end

function rr = local_empty_run_result()
    rr = struct();
    rr.algorithm_name = '';
    rr.suite = '';
    rr.function_id = 0;
    rr.run_id = 0;
    rr.best_score = NaN;
    rr.best_position = [];
    rr.convergence_curve = [];
    rr.runtime = NaN;
    rr.seed = NaN;
    rr.dimension = 0;
    rr.population_size = 0;
    rr.maxFEs = 0;
    rr.used_FEs = 0;
    rr.fe_control_mode = '';
    rr.fe_control_note = '';
    rr.behavior_trace = struct();
end
