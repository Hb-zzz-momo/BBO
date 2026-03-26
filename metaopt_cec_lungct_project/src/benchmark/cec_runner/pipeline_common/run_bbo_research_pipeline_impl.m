function report = run_bbo_research_pipeline_impl(cfg)
% run_bbo_research_pipeline_impl
% Compatibility/stage runner.
% Why: keep historical entry while long-term framework logic moves to core.
% End-to-end, minimally invasive research pipeline for BBO improvement study.
% It reuses the core benchmark entry as the unified backend.
%
% Main workflow:
% 1) Repository scan and evidence snapshot
% 2) Smoke execution validation only (health check)
% 3) Optional formal benchmark run under fixed protocol
% 4) Formal-only variant evaluation for method judgement
% 5) Auto analysis report for paper writing support

    if nargin < 1
        cfg = struct();
    end
    paths = resolve_pipeline_paths();
    cfg = fill_default_pipeline_cfg(cfg);
    out_root = fullfile(paths.repo_root, cfg.result_root, cfg.result_group, cfg.experiment_name);
    ensure_dir(out_root);

    scan_info = scan_repository_snapshot(paths);
    write_stage_scan(out_root, scan_info, cfg, @write_scan_markdown);

    smoke_cfg = make_smoke_cfg(cfg);
    if cfg.use_unified_entry
        smoke_phase_report = run_phase_via_unified(smoke_cfg, 'smoke');
        smoke_output = smoke_phase_report.output;
    else
        smoke_phase_report = run_phase_via_core(smoke_cfg, 'smoke');
        smoke_output = smoke_phase_report.output;
    end
    smoke_health = smoke_health_check(smoke_output, smoke_cfg.algorithms, smoke_cfg.suites);

    formal_output = [];
    formal_cfg = struct();
    formal_variant_scores = empty_variant_score_table();
    formal_variant_detail = struct();
    if cfg.run_formal
        formal_cfg = make_formal_cfg(cfg);
        if cfg.use_unified_entry
            formal_phase_report = run_phase_via_unified(formal_cfg, 'formal');
            formal_output = formal_phase_report.output;
        else
            formal_phase_report = run_phase_via_core(formal_cfg, 'formal');
            formal_output = formal_phase_report.output;
        end
        [formal_variant_scores, formal_variant_detail] = evaluate_variants_from_output( ...
            formal_output, cfg.variant_algorithms, cfg.base_algorithm);
    end

    report = struct();
    report.pipeline_root = out_root;
    report.scan = scan_info;
    report.smoke_cfg = smoke_cfg;
    report.smoke_output = smoke_output;
    report.smoke_health = smoke_health;
    report.conclusion_scope = 'formal_only';
    report.formal_cfg = formal_cfg;
    report.formal_output = formal_output;
    report.formal_variant_scores = formal_variant_scores;
    report.formal_variant_detail = formal_variant_detail;

    save_stage_report(out_root, report, 'pipeline_report.mat', 'analysis_summary.md', @write_analysis_markdown, cfg);
end

function cfg = fill_default_pipeline_cfg(cfg)
    cfg = fill_common_stage_cfg(cfg);

    smoke_profile = stage_profiles('benchmark_smoke');
    formal_profile = stage_profiles('benchmark_formal');

    if ~isfield(cfg, 'suites')
        cfg.suites = {'cec2017', 'cec2022'};
    end
    if ~isfield(cfg, 'rng_seed')
        cfg.rng_seed = 20260313;
    end
    if ~isfield(cfg, 'experiment_name') || isempty(cfg.experiment_name)
        cfg.experiment_name = ['bbo_pipeline_' datestr(now, 'yyyymmdd_HHMMSS')];
    end
    if ~isfield(cfg, 'result_group') || isempty(cfg.result_group)
        cfg.result_group = fullfile('benchmark', 'research_pipeline');
    end
    if ~isfield(cfg, 'result_layout') || isempty(cfg.result_layout)
        cfg.result_layout = 'experiment_then_suite';
    end

    if ~isfield(cfg, 'base_algorithm')
        cfg.base_algorithm = 'BBO_BASE';
    end
    if ~isfield(cfg, 'variant_algorithms')
        % V2 is retired from default research flow; V4 takes its default slot.
        cfg.variant_algorithms = {'BBO_IMPROVED_V1', 'BBO_IMPROVED_V3', 'BBO_IMPROVED_V4'};
    end
    if ~isfield(cfg, 'strong_baselines')
        cfg.strong_baselines = {'SBO','MGO', 'PLO'};
    end

    if ~isfield(cfg, 'smoke_runs')
        cfg.smoke_runs = smoke_profile.runs;
    end
    if ~isfield(cfg, 'smoke_func_ids')
        cfg.smoke_func_ids = smoke_profile.func_ids;
    end

    if ~isfield(cfg, 'run_formal')
        cfg.run_formal = true;
    end
    if ~isfield(cfg, 'formal_runs')
        cfg.formal_runs = formal_profile.runs;
    end
    if ~isfield(cfg, 'formal_func_ids')
        cfg.formal_func_ids = formal_profile.func_ids;
    end
end

function paths = resolve_pipeline_paths()
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    runner_dir = fileparts(this_dir);
    addpath(this_dir);
    addpath(fullfile(runner_dir, 'config'));
    addpath(fullfile(runner_dir, 'core'));
    addpath(fullfile(runner_dir, 'pipeline_common'));

    common_paths = rac_resolve_common_paths();

    paths = struct();
    paths.repo_root = common_paths.repo_root;
    paths.kernel_file = fullfile(paths.repo_root, 'src', 'benchmark', 'cec_runner', 'core', 'rac_run_benchmark_kernel.m');
    paths.compare_file = fullfile(paths.repo_root, 'src', 'benchmark', 'cec_runner', 'pipelines', 'run_compare_sbo_bbo.m');
    paths.bbo_2017 = fullfile(common_paths.bbo_root, 'CEC2017', 'BBO.m');
    paths.bbo_2022 = fullfile(common_paths.bbo_root, 'CEC2022', 'BBO.m');
    paths.cec2017_getter = fullfile(common_paths.bbo_root, 'CEC2017', 'Get_Functions_cec2017.m');
    paths.cec2022_getter = fullfile(common_paths.bbo_root, 'CEC2022', 'Get_Functions_cec2022.m');
    paths.improved_root = common_paths.improved_bbo_root;
end

function scan_info = scan_repository_snapshot(paths)
    scan_info = struct();
    scan_info.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    scan_info.files = struct();

    scan_info.files.benchmark_kernel = isfile(paths.kernel_file);
    scan_info.files.run_compare_sbo_bbo = isfile(paths.compare_file);
    scan_info.files.bbo_2017 = isfile(paths.bbo_2017);
    scan_info.files.bbo_2022 = isfile(paths.bbo_2022);
    scan_info.files.cec2017_getter = isfile(paths.cec2017_getter);
    scan_info.files.cec2022_getter = isfile(paths.cec2022_getter);

    v1 = fullfile(paths.improved_root, 'BBO_improved_v1.m');
    v2 = fullfile(paths.improved_root, 'BBO_improved_v2.m');
    v3 = fullfile(paths.improved_root, 'BBO_improved_v3.m');
    v4 = fullfile(paths.improved_root, 'BBO_improved_v4.m');
    scan_info.files.bbo_improved_v1 = isfile(v1);
    scan_info.files.bbo_improved_v2 = isfile(v2);
    scan_info.files.bbo_improved_v3 = isfile(v3);
    scan_info.files.bbo_improved_v4 = isfile(v4);

    scan_info.paths = paths;
end

function smoke_cfg = make_smoke_cfg(cfg)
    phase_cfg = cfg;
    phase_cfg.result_group = fullfile(cfg.result_group, cfg.experiment_name);
    phase_cfg.result_layout = 'experiment_then_suite';

    smoke_cfg = build_smoke_cfg( ...
        phase_cfg, ...
        [{cfg.base_algorithm}, cfg.variant_algorithms, cfg.strong_baselines], ...
        cfg.smoke_func_ids, ...
        cfg.smoke_runs, ...
        'smoke', ...
        cfg.result_root);
end

function formal_cfg = make_formal_cfg(cfg)
    phase_cfg = cfg;
    phase_cfg.result_group = fullfile(cfg.result_group, cfg.experiment_name);
    phase_cfg.result_layout = 'experiment_then_suite';

    formal_cfg = build_formal_cfg( ...
        phase_cfg, ...
        unique([{cfg.base_algorithm}, cfg.variant_algorithms, cfg.strong_baselines], 'stable'), ...
        cfg.formal_func_ids, ...
        cfg.formal_runs, ...
        'formal', ...
        cfg.result_root);
end

function [scores, detail] = evaluate_variants_from_output(output, variants, base_alg)
    scores = empty_variant_score_table();
    detail = struct();

    all_summaries = table();
    for i = 1:numel(output.suite_results)
        T = output.suite_results(i).summary;
        if isempty(T)
            continue;
        end
        T.suite = repmat(string(output.suite_results(i).suite), height(T), 1);
        all_summaries = [all_summaries; T]; %#ok<AGROW>
    end

    if isempty(all_summaries)
        return;
    end

    for i = 1:numel(variants)
        alg = string(variants{i});
        [improved, degraded] = compare_mean_against_base(all_summaries, alg, string(base_alg));
        scores = [scores; {alg, improved, degraded, improved - degraded}]; %#ok<AGROW>
        detail.(char(alg)) = struct('improved_funcs', improved, 'degraded_funcs', degraded);
    end

    scores = sortrows(scores, {'net_gain', 'improved_funcs'}, {'descend', 'descend'});
end

function scores = empty_variant_score_table()
    scores = table(string.empty(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'algorithm', 'improved_funcs', 'degraded_funcs', 'net_gain'});
end

function [improved, degraded] = compare_mean_against_base(summary_table, alg, base_alg)
    improved = 0;
    degraded = 0;

    suites = unique(summary_table.suite, 'stable');
    for s = 1:numel(suites)
        Ts = summary_table(summary_table.suite == suites(s), :);
        fids = unique(Ts.function_id, 'stable');
        for f = 1:numel(fids)
            base_row = Ts(Ts.function_id == fids(f) & string(Ts.algorithm_name) == base_alg, :);
            alg_row = Ts(Ts.function_id == fids(f) & string(Ts.algorithm_name) == alg, :);
            if isempty(base_row) || isempty(alg_row)
                continue;
            end
            if alg_row.mean(1) < base_row.mean(1)
                improved = improved + 1;
            elseif alg_row.mean(1) > base_row.mean(1)
                degraded = degraded + 1;
            end
        end
    end
end

function health = smoke_health_check(smoke_output, expected_algorithms, expected_suites)
    health = struct();
    health.pass = true;
    health.status = 'pass';
    health.missing_algorithms = {};
    health.missing_suites = {};
    health.abnormal_suites = {};
    health.info = {};

    if ~isstruct(smoke_output) || ~isfield(smoke_output, 'suite_results')
        health.pass = false;
        health.status = 'fail';
        health.abnormal_suites = {'missing output.suite_results'};
        health.info = {'Smoke output structure is invalid.'};
        return;
    end

    suite_results = smoke_output.suite_results;
    observed_suites = {};
    observed_algorithms = {};

    for i = 1:numel(suite_results)
        suite_item = suite_results(i);
        suite_name = '';
        if isfield(suite_item, 'suite')
            suite_name = char(string(suite_item.suite));
        end
        observed_suites{end + 1} = suite_name; %#ok<AGROW>

        if ~isfield(suite_item, 'summary') || isempty(suite_item.summary)
            health.abnormal_suites{end + 1} = sprintf('%s: empty summary', suite_name); %#ok<AGROW>
            continue;
        end

        summary_table = suite_item.summary;
        if ~istable(summary_table)
            health.abnormal_suites{end + 1} = sprintf('%s: summary is not a table', suite_name); %#ok<AGROW>
            continue;
        end

        if ~ismember('algorithm_name', summary_table.Properties.VariableNames)
            health.abnormal_suites{end + 1} = sprintf('%s: missing algorithm_name column', suite_name); %#ok<AGROW>
            continue;
        end

        if height(summary_table) == 0
            health.abnormal_suites{end + 1} = sprintf('%s: summary has zero rows', suite_name); %#ok<AGROW>
            continue;
        end

        suite_algorithms = unique(cellstr(string(summary_table.algorithm_name)), 'stable');
        observed_algorithms = [observed_algorithms, suite_algorithms]; %#ok<AGROW>
    end

    observed_suites = unique(observed_suites, 'stable');
    observed_algorithms = unique(observed_algorithms, 'stable');
    expected_algorithms = unique(expected_algorithms, 'stable');
    expected_suites = unique(expected_suites, 'stable');

    health.missing_suites = setdiff(expected_suites, observed_suites, 'stable');
    health.missing_algorithms = setdiff(expected_algorithms, observed_algorithms, 'stable');

    if ~isempty(health.missing_suites) || ~isempty(health.missing_algorithms) || ~isempty(health.abnormal_suites)
        health.pass = false;
        health.status = 'fail';
    end

    health.info{end + 1} = sprintf('Expected suites=%d, observed suites=%d.', numel(expected_suites), numel(observed_suites));
    health.info{end + 1} = sprintf('Expected algorithms=%d, observed algorithms=%d.', numel(expected_algorithms), numel(observed_algorithms));
end

function write_scan_markdown(file_path, scan_info, cfg)
    fid = fopen(file_path, 'w');
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# Repository Scan\n\n');
    fprintf(fid, '- Timestamp: %s\n', scan_info.timestamp);
    fprintf(fid, '- Experiment: %s\n\n', cfg.experiment_name);

    fields = fieldnames(scan_info.files);
    for i = 1:numel(fields)
        key = fields{i};
        fprintf(fid, '- %s: %d\n', key, scan_info.files.(key));
    end
end

function write_analysis_markdown(file_path, report, cfg)
    fid = fopen(file_path, 'w');
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# BBO Research Pipeline Summary\n\n');
    fprintf(fid, '## 1. Repository scan\n');
    fprintf(fid, '- benchmark kernel exists: %d\n', report.scan.files.benchmark_kernel);
    fprintf(fid, '- baseline BBO (CEC2017/CEC2022) exists: %d/%d\n', report.scan.files.bbo_2017, report.scan.files.bbo_2022);
    fprintf(fid, '- improved versions exist: v1=%d, v3=%d, v4=%d (v2 retired from default flow)\n\n', ...
        report.scan.files.bbo_improved_v1, report.scan.files.bbo_improved_v3, report.scan.files.bbo_improved_v4);

    fprintf(fid, '## 2. Minimal-intrusion plan\n');
    fprintf(fid, '- Reuse rac_run_benchmark_kernel via core entry as the single benchmark backend.\n');
    fprintf(fid, '- Keep baseline BBO unchanged and add versioned variants via algorithm catalog mapping.\n');
    fprintf(fid, '- Keep protocol fields (suite, func_ids, dim, pop_size, maxFEs, runs, rng_seed) explicit and fixed per run.\n\n');

    fprintf(fid, '## 3. Smoke stage result\n');
    fprintf(fid, '- Suites: %s\n', strjoin(cfg.suites, ', '));
    fprintf(fid, '- Algorithms in smoke: %s\n', strjoin([{cfg.base_algorithm}, cfg.variant_algorithms, cfg.strong_baselines], ', '));
    fprintf(fid, '- Smoke status: %s\n', report.smoke_health.status);
    fprintf(fid, '- Smoke is ONLY for execution health validation, not for final algorithm judgement.\n');
    if ~isempty(report.smoke_health.missing_suites)
        fprintf(fid, '- Missing suites in smoke output: %s\n', strjoin(report.smoke_health.missing_suites, ', '));
    end
    if ~isempty(report.smoke_health.missing_algorithms)
        fprintf(fid, '- Missing algorithms in smoke output: %s\n', strjoin(report.smoke_health.missing_algorithms, ', '));
    end
    if ~isempty(report.smoke_health.abnormal_suites)
        fprintf(fid, '- Abnormal smoke suites: %s\n', strjoin(report.smoke_health.abnormal_suites, ' | '));
    end
    for i = 1:numel(report.smoke_health.info)
        fprintf(fid, '- Smoke info: %s\n', report.smoke_health.info{i});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## 4. Formal stage and variant comparison\n');
    if cfg.run_formal
        fprintf(fid, '- Formal run requested and executed.\n');
        fprintf(fid, '- Formal is the ONLY stage used for algorithm superiority judgement.\n');
        fprintf(fid, '- Formal algorithms: %s\n', strjoin(report.formal_cfg.algorithms, ', '));
        fprintf(fid, '- Formal runs per function: %d\n\n', report.formal_cfg.runs);
    else
        fprintf(fid, '- Formal run disabled in current execution (run_formal=false).\n');
        fprintf(fid, '- Final algorithm superiority conclusion is NOT allowed without formal results.\n\n');
    end

    fprintf(fid, '## 5. Formal variant comparison (mean metric vs baseline)\n');
    if isempty(report.formal_variant_scores)
        fprintf(fid, '- No valid formal variant comparison table generated.\n\n');
    else
        for i = 1:height(report.formal_variant_scores)
            fprintf(fid, '- %s: improved=%d, degraded=%d, net=%d\n', ...
                char(report.formal_variant_scores.algorithm(i)), ...
                report.formal_variant_scores.improved_funcs(i), ...
                report.formal_variant_scores.degraded_funcs(i), ...
                report.formal_variant_scores.net_gain(i));
        end
        fprintf(fid, '\n');
    end

    fprintf(fid, '## 6. Risks and assumptions\n');
    fprintf(fid, '- No protocol fields were changed silently during smoke/formal evaluation.\n');
    fprintf(fid, '- Smoke evidence cannot be used as final algorithm superiority conclusion.\n');
    fprintf(fid, '- Conclusions are provisional if formal stage is not executed.\n');
    fprintf(fid, '- Failure cases are preserved through benchmark kernel logs and summaries.\n');
end

function ensure_dir(path_str)
    if ~isfolder(path_str)
        mkdir(path_str);
    end
end
