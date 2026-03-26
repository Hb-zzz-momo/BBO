function report = run_v3_direction_reduced_ablation_impl(cfg)
% run_v3_direction_reduced_ablation_impl
% Compatibility/stage runner.
% Why: keep historical entry while shared benchmark flow stays in core.
% Reduced-subset directional ablation around V3_DIR_SMALL_STEP trunk.
% Scope: smoke_reduced + formal_screen_reduced on CEC2017 selected functions.

    if nargin < 1
        cfg = struct();
    end
    paths = resolve_paths();
    cfg = fill_default_cfg(cfg);
    out_root = fullfile(paths.repo_root, cfg.result_root, cfg.result_group, cfg.experiment_name);
    ensure_dir(out_root);

    smoke_cfg = build_phase_cfg(cfg, 'smoke');
    if cfg.use_unified_entry
        smoke_phase_report = run_phase_via_unified(smoke_cfg, 'smoke');
        smoke_output = smoke_phase_report.output;
    else
        smoke_phase_report = run_phase_via_core(smoke_cfg, 'smoke');
        smoke_output = smoke_phase_report.output;
    end
    smoke_health = evaluate_phase_health(smoke_output, cfg);

    formal_cfg = build_phase_cfg(cfg, 'formal');
    if cfg.use_unified_entry
        formal_phase_report = run_phase_via_unified(formal_cfg, 'formal');
        formal_output = formal_phase_report.output;
    else
        formal_phase_report = run_phase_via_core(formal_cfg, 'formal');
        formal_output = formal_phase_report.output;
    end
    formal_analysis = analyze_formal_screen(formal_output, cfg);

    smoke_root = fullfile(out_root, 'smoke');
    formal_root = fullfile(out_root, 'formal');
    ensure_dir(smoke_root);
    ensure_dir(formal_root);

    export_phase_artifacts(smoke_root, smoke_output, smoke_cfg, cfg, smoke_health, 'smoke');
    export_phase_artifacts(formal_root, formal_output, formal_cfg, cfg, formal_analysis, 'formal');
    export_formal_analysis(formal_root, formal_analysis, cfg);

    report = struct();
    report.timestamp = cfg.timestamp;
    report.smoke_cfg = smoke_cfg;
    report.smoke_output = smoke_output;
    report.smoke_health = smoke_health;
    report.formal_cfg = formal_cfg;
    report.formal_output = formal_output;
    report.formal_analysis = formal_analysis;
    report.pipeline_root = out_root;
    report.smoke_root = smoke_root;
    report.formal_root = formal_root;

    save(fullfile(formal_root, sprintf('pipeline_report_%s.mat', cfg.timestamp)), 'report');
    write_formal_report_markdown(fullfile(formal_root, sprintf('report_%s.md', cfg.timestamp)), report, cfg);
end

function cfg = fill_default_cfg(cfg)
    cfg = fill_common_stage_cfg(cfg);
    profile = stage_profiles('v3_reduced_ablation');

    if ~isfield(cfg, 'timestamp') || isempty(cfg.timestamp)
        cfg.timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    end
    if ~isfield(cfg, 'experiment_name') || isempty(cfg.experiment_name)
        cfg.experiment_name = ['v3_direction_reduced_' cfg.timestamp];
    end
    if ~isfield(cfg, 'result_group') || isempty(cfg.result_group)
        cfg.result_group = fullfile('benchmark', 'v3_direction_reduced_ablation');
    end
    if ~isfield(cfg, 'result_layout') || isempty(cfg.result_layout)
        cfg.result_layout = 'experiment_then_suite';
    end

    if ~isfield(cfg, 'suite')
        cfg.suite = profile.suite;
    end

    if ~isfield(cfg, 'reduced_func_ids')
        cfg.reduced_func_ids = profile.reduced_func_ids;
    end

    if ~isfield(cfg, 'algorithms')
        cfg.algorithms = {
            'V3_BASELINE', ...
            'V3_DIR_STAG_ONLY', ...
            'V3_DIR_STAG_BOTTOM_HALF', ...
            'V3_DIR_STAG_BOTTOM_HALF_LATE_REFINE'};
    end

    if ~isfield(cfg, 'include_clipped_variant')
        cfg.include_clipped_variant = true;
    end
    if cfg.include_clipped_variant && ~ismember('V3_DIR_CLIPPED_STAG_BOTTOM_HALF_LATE_REFINE', cfg.algorithms)
        cfg.algorithms{end + 1} = 'V3_DIR_CLIPPED_STAG_BOTTOM_HALF_LATE_REFINE';
    end

    if ~isfield(cfg, 'rng_seed')
        cfg.rng_seed = 20260315;
    end

    if ~isfield(cfg, 'smoke_runs')
        cfg.smoke_runs = profile.smoke_runs;
    end
    if ~isfield(cfg, 'formal_runs')
        cfg.formal_runs = profile.formal_runs;
    end
end

function paths = resolve_paths()
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    runner_dir = fileparts(this_dir);
    addpath(this_dir);
    addpath(fullfile(runner_dir, 'pipeline_common'));
    addpath(fullfile(runner_dir, 'config'));
    addpath(fullfile(runner_dir, 'core'));
    paths = struct();
    paths.repo_root = fullfile(runner_dir, '..', '..', '..');
end

function phase_cfg = build_phase_cfg(cfg, phase)
    suites = {cfg.suite};
    func_ids = struct(cfg.suite, cfg.reduced_func_ids);
    algs = cfg.algorithms;
    cfg_base = cfg;
    cfg_base.suites = suites;
    cfg_base.result_group = fullfile(cfg.result_group, cfg.experiment_name);
    cfg_base.result_layout = 'experiment_then_suite';

    if strcmpi(phase, 'smoke')
        phase_cfg = build_smoke_cfg( ...
            cfg_base, ...
            algs, ...
            func_ids, ...
            cfg.smoke_runs, ...
            'smoke', ...
            cfg.result_root);
    else
        phase_cfg = build_formal_cfg( ...
            cfg_base, ...
            algs, ...
            func_ids, ...
            cfg.formal_runs, ...
            'formal', ...
            cfg.result_root);
    end
end

function health = evaluate_phase_health(output, cfg)
    health = struct();
    health.pass = true;
    health.anomalies = {};
    health.missing_algorithms = {};

    if ~isfield(output, 'suite_results') || isempty(output.suite_results)
        health.pass = false;
        health.anomalies{end + 1} = 'suite_results is empty'; %#ok<AGROW>
        return;
    end

    T = output.suite_results(1).summary;
    if isempty(T) || ~istable(T)
        health.pass = false;
        health.anomalies{end + 1} = 'summary is empty or invalid'; %#ok<AGROW>
        return;
    end

    observed = unique(cellstr(string(T.algorithm_name)), 'stable');
    expected = unique(cfg.algorithms, 'stable');
    health.missing_algorithms = setdiff(expected, observed, 'stable');

    if any(~isfinite(T.mean)) || any(~isfinite(T.std))
        health.pass = false;
        health.anomalies{end + 1} = 'summary contains NaN/Inf in mean/std'; %#ok<AGROW>
    end

    if ~isempty(health.missing_algorithms)
        health.pass = false;
        health.anomalies{end + 1} = sprintf('missing algorithms: %s', strjoin(health.missing_algorithms, ', ')); %#ok<AGROW>
    end
end

function analysis = analyze_formal_screen(formal_output, cfg)
    analysis = struct();
    analysis.per_function = table();
    analysis.ranking = table();
    analysis.best_version = '';
    analysis.recommend_full_formal = false;
    analysis.answers = struct();

    if ~isfield(formal_output, 'suite_results') || isempty(formal_output.suite_results)
        analysis.answers.note = 'formal output empty';
        return;
    end

    T = formal_output.suite_results(1).summary;
    T = T(ismember(string(T.algorithm_name), string(cfg.algorithms)) & ismember(T.function_id, cfg.reduced_func_ids), :);
    analysis.per_function = T(:, {'algorithm_name', 'function_id', 'mean', 'std', 'avg_runtime'});

    baseline = 'V3_BASELINE';
    candidates = setdiff(cfg.algorithms, {baseline}, 'stable');
    rank_rows = table();

    for i = 1:numel(candidates)
        alg = candidates{i};
        [stats_row, ~] = compare_to_baseline(T, baseline, alg, [1, 2, 3], [12, 13, 14, 15, 18, 19]);
        rank_rows = [rank_rows; stats_row]; %#ok<AGROW>
    end

    if ~isempty(rank_rows)
        score = rank_rows.net_gain + 0.8 .* rank_rows.simple_mean_delta + 0.6 .* rank_rows.complex_mean_delta - 0.2 .* rank_rows.std_delta_mean;
        rank_rows.screen_score = score;
        rank_rows = sortrows(rank_rows, {'screen_score', 'net_gain', 'std_delta_mean'}, {'descend', 'descend', 'ascend'});
    else
        rank_rows.screen_score = [];
    end

    analysis.ranking = rank_rows;

    if ~isempty(rank_rows)
        analysis.best_version = char(rank_rows.algorithm(1));
        analysis.recommend_full_formal = rank_rows.screen_score(1) > 0;
    end

    analysis.answers = build_required_answers(rank_rows, analysis.best_version, analysis.recommend_full_formal);
end

function [row, detail] = compare_to_baseline(T, baseline, alg, simple_ids, complex_ids)
    detail = table();
    improved = 0;
    degraded = 0;
    tie = 0;
    all_delta = [];
    std_delta = [];
    simple_delta = [];
    complex_delta = [];

    fids = unique(T.function_id, 'stable');
    for k = 1:numel(fids)
        fid = fids(k);
        rb = T(T.function_id == fid & strcmp(string(T.algorithm_name), string(baseline)), :);
        ra = T(T.function_id == fid & strcmp(string(T.algorithm_name), string(alg)), :);
        if isempty(rb) || isempty(ra)
            continue;
        end

        d = rb.mean(1) - ra.mean(1);
        s = ra.std(1) - rb.std(1);
        all_delta(end + 1) = d; %#ok<AGROW>
        std_delta(end + 1) = s; %#ok<AGROW>

        if ismember(fid, simple_ids)
            simple_delta(end + 1) = d; %#ok<AGROW>
        elseif ismember(fid, complex_ids)
            complex_delta(end + 1) = d; %#ok<AGROW>
        end

        if d > 0
            improved = improved + 1;
            status = "improved";
        elseif d < 0
            degraded = degraded + 1;
            status = "degraded";
        else
            tie = tie + 1;
            status = "tie";
        end

        detail = [detail; table(string(alg), fid, d, s, status, 'VariableNames', ...
            {'algorithm', 'function_id', 'mean_delta', 'std_delta', 'status'})]; %#ok<AGROW>
    end

    row = table(string(alg), improved, degraded, tie, improved - degraded, safe_mean(all_delta), ...
        safe_mean(simple_delta), safe_mean(complex_delta), safe_mean(std_delta), ...
        'VariableNames', {'algorithm', 'improved', 'degraded', 'tie', 'net_gain', ...
        'mean_delta', 'simple_mean_delta', 'complex_mean_delta', 'std_delta_mean'});
end

function answers = build_required_answers(ranking, best_version, recommend_full_formal)
    answers = struct();
    if isempty(ranking)
        answers.q1 = 'No formal rows available to verify F1/F2/F3 repair.';
        answers.q2 = 'No formal rows available to verify complex-function retention.';
        answers.q3 = 'late_local_refine effectiveness cannot be judged due to empty ranking.';
        answers.q4 = 'gate stability cannot be judged due to empty ranking.';
        answers.q5 = 'No version can be selected for full formal from current run.';
        answers.q6 = 'Risk: formal output missing or not aligned with required algorithms.';
        return;
    end

    row_stag_only = ranking(strcmp(ranking.algorithm, "V3_DIR_STAG_ONLY"), :);
    row_bottom = ranking(strcmp(ranking.algorithm, "V3_DIR_STAG_BOTTOM_HALF"), :);
    row_bottom_refine = ranking(strcmp(ranking.algorithm, "V3_DIR_STAG_BOTTOM_HALF_LATE_REFINE"), :);
    row_clipped = ranking(strcmp(ranking.algorithm, "V3_DIR_CLIPPED_STAG_BOTTOM_HALF_LATE_REFINE"), :);

    primary_row = row_bottom_refine;
    if isempty(primary_row)
        primary_row = row_bottom;
    end
    if isempty(primary_row)
        primary_row = row_stag_only;
    end

    if ~isempty(primary_row)
        if primary_row.simple_mean_delta(1) > 0
            answers.q1 = sprintf('F1/F2/F3 shows repair tendency (simple_mean_delta=%.4g > 0).', primary_row.simple_mean_delta(1));
        else
            answers.q1 = sprintf('F1/F2/F3 not repaired yet (simple_mean_delta=%.4g <= 0).', primary_row.simple_mean_delta(1));
        end

        if primary_row.complex_mean_delta(1) >= 0
            answers.q2 = sprintf('F12/F13/F14/F15/F18/F19 directional advantage is retained (complex_mean_delta=%.4g).', primary_row.complex_mean_delta(1));
        else
            answers.q2 = sprintf('Complex-function advantage weakened (complex_mean_delta=%.4g).', primary_row.complex_mean_delta(1));
        end

        if ~isempty(row_bottom_refine) && ~isempty(row_bottom)
            if row_bottom_refine.net_gain(1) >= row_bottom.net_gain(1)
                answers.q3 = 'state-triggered late_local_refine helps or maintains net_gain under bottom-half directional policy.';
            else
                answers.q3 = 'state-triggered late_local_refine is not yet consistently beneficial and needs threshold tuning.';
            end
        elseif primary_row.net_gain(1) > 0
            answers.q3 = sprintf('late_local_refine branch is acceptable in this screen (net_gain=%d).', primary_row.net_gain(1));
        else
            answers.q3 = sprintf('late_local_refine is not yet effective enough (net_gain=%d).', primary_row.net_gain(1));
        end
    else
        answers.q1 = 'Cannot answer F1/F2/F3 repair because directional candidate rows are missing.';
        answers.q2 = 'Cannot answer complex retention because directional candidate rows are missing.';
        answers.q3 = 'Cannot evaluate late_local_refine due to missing rows.';
    end

    if ~isempty(row_bottom_refine) && ~isempty(row_clipped)
        if (row_clipped.std_delta_mean(1) <= row_bottom_refine.std_delta_mean(1)) && (row_clipped.simple_mean_delta(1) >= row_bottom_refine.simple_mean_delta(1))
            answers.q4 = 'clipped directional step improves stability/simple-protection balance over non-clipped counterpart.';
        else
            answers.q4 = 'clipped directional step did not yet show a better stability-gain balance in this screen.';
        end
    else
        answers.q4 = 'Cannot compare clipped-step stability due to missing rows.';
    end

    answers.q5 = sprintf('Best candidate for full formal from this screen: %s.', best_version);

    if recommend_full_formal
        answers.q6 = 'Main risk is overfitting to reduced subset; proceed to full formal with same fairness protocol.';
    else
        answers.q6 = 'Risk remains high (screen score <= 0); continue tuning gate/local-refine thresholds before full formal.';
    end
end

function export_phase_artifacts(phase_root, output, phase_cfg, global_cfg, phase_info, phase)
    ensure_dir(phase_root);

    ts = global_cfg.timestamp;
    save(fullfile(phase_root, sprintf('config_snapshot_%s.mat', ts)), 'phase_cfg', 'global_cfg');

    meta = struct();
    meta.timestamp = ts;
    meta.phase = phase;
    meta.suite = global_cfg.suite;
    meta.algorithms = global_cfg.algorithms;
    meta.reduced_func_ids = global_cfg.reduced_func_ids;
    meta.source_result_dir = '';

    if isfield(output, 'suite_results') && ~isempty(output.suite_results)
        src = output.suite_results(1).result_dir;
        meta.source_result_dir = src;

        copy_if_exists(fullfile(src, 'summary.csv'), fullfile(phase_root, 'summary.csv'));
        copy_if_exists(fullfile(src, 'summary.mat'), fullfile(phase_root, 'summary.mat'));
        copy_if_exists(fullfile(src, 'logs', 'run_log.txt'), fullfile(phase_root, sprintf('run_log_%s.txt', ts)));

        copy_dir_if_exists(fullfile(src, 'raw_runs'), fullfile(phase_root, 'raw_runs'));
        copy_dir_if_exists(fullfile(src, 'curves'), fullfile(phase_root, 'curves'));
        copy_dir_if_exists(fullfile(src, 'figures'), fullfile(phase_root, 'figures'));
    end

    save(fullfile(phase_root, sprintf('meta_%s.mat', ts)), 'meta', 'phase_info');
end

function export_formal_analysis(formal_root, analysis, cfg)
    ts = cfg.timestamp;

    if ~isempty(analysis.per_function)
        writetable(analysis.per_function, fullfile(formal_root, 'per_function_mean_std.csv'));
    end

    if ~isempty(analysis.ranking)
        writetable(analysis.ranking, fullfile(formal_root, 'ranking_summary.csv'));
    end

    fid = fopen(fullfile(formal_root, sprintf('analysis_%s.md', ts)), 'w');
    c = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# Formal Screen Analysis (%s)\n\n', ts);
    fprintf(fid, '- Suite: %s\n', cfg.suite);
    fprintf(fid, '- Reduced subset: %s\n', mat2str(cfg.reduced_func_ids));
    fprintf(fid, '- Algorithms: %s\n\n', strjoin(cfg.algorithms, ', '));

    fprintf(fid, '## Required answers\n');
    fprintf(fid, '1. %s\n', analysis.answers.q1);
    fprintf(fid, '2. %s\n', analysis.answers.q2);
    fprintf(fid, '3. %s\n', analysis.answers.q3);
    fprintf(fid, '4. %s\n', analysis.answers.q4);
    fprintf(fid, '5. %s\n', analysis.answers.q5);
    fprintf(fid, '6. %s\n\n', analysis.answers.q6);

    fprintf(fid, '## Best version\n');
    if isempty(analysis.best_version)
        fprintf(fid, '- None\n');
    else
        fprintf(fid, '- %s\n', analysis.best_version);
    end

    fprintf(fid, '## Full formal recommendation\n');
    fprintf(fid, '- recommend_full_formal: %d\n', analysis.recommend_full_formal);
end

function write_formal_report_markdown(file_path, report, cfg)
    fid = fopen(file_path, 'w');
    c = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# V3 Direction Reduced Ablation Report\n\n');
    fprintf(fid, '- Timestamp: %s\n', cfg.timestamp);
    fprintf(fid, '- Smoke root: %s\n', report.smoke_root);
    fprintf(fid, '- Formal root: %s\n\n', report.formal_root);

    fprintf(fid, '## Smoke\n');
    fprintf(fid, '- pass: %d\n', report.smoke_health.pass);
    if ~isempty(report.smoke_health.anomalies)
        for i = 1:numel(report.smoke_health.anomalies)
            fprintf(fid, '- anomaly: %s\n', report.smoke_health.anomalies{i});
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Formal Screen Key Outputs\n');
    fprintf(fid, '- ranking_summary.csv\n');
    fprintf(fid, '- per_function_mean_std.csv\n');
    fprintf(fid, '- analysis_%s.md\n\n', cfg.timestamp);

    fprintf(fid, '## Best Version\n');
    if isempty(report.formal_analysis.best_version)
        fprintf(fid, '- None\n');
    else
        fprintf(fid, '- %s\n', report.formal_analysis.best_version);
    end

    fprintf(fid, '## Recommend Full Formal\n');
    fprintf(fid, '- %d\n', report.formal_analysis.recommend_full_formal);
end

function copy_if_exists(src, dst)
    if exist(src, 'file') == 2
        copyfile(src, dst);
    end
end

function copy_dir_if_exists(src, dst)
    if exist(src, 'dir') == 7
        if exist(dst, 'dir') == 7
            rmdir(dst, 's');
        end
        copyfile(src, dst);
    end
end

function m = safe_mean(x)
    if isempty(x)
        m = nan;
    else
        m = mean(x);
    end
end

function ensure_dir(path_str)
    if ~isfolder(path_str)
        mkdir(path_str);
    end
end
