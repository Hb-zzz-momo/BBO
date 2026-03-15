function report = run_v3_dual_objective_ablation(cfg)
% run_v3_dual_objective_ablation
% Dual-objective ablation around v3:
% 1) simple-function convergence enhancement modules
% 2) conditional directional enhancement modules

    if nargin < 1
        cfg = struct();
    end
    cfg = fill_default_cfg(cfg);

    paths = resolve_paths();
    out_root = fullfile(paths.repo_root, cfg.result_root, 'benchmark', 'research_pipeline', cfg.experiment_name);
    ensure_dir(out_root);

    scan_info = scan_key_files(paths, cfg);
    save(fullfile(out_root, 'scan_snapshot.mat'), 'scan_info', 'cfg');
    write_scan_markdown(fullfile(out_root, 'scan_snapshot.md'), scan_info, cfg);

    smoke_cfg = build_smoke_cfg(cfg);
    smoke_output = run_all_compare(smoke_cfg);
    smoke_health = evaluate_smoke_health(smoke_output, cfg);

    formal_output = [];
    formal_cfg = struct();
    formal_analysis = make_empty_formal_analysis();

    if cfg.run_formal && (~cfg.skip_formal_on_smoke_fail || smoke_health.pass)
        formal_cfg = build_formal_cfg(cfg);
        formal_output = run_all_compare(formal_cfg);
        formal_analysis = analyze_formal_output(formal_output, cfg);

        if ~isempty(formal_analysis.version_summary)
            writetable(formal_analysis.version_summary, fullfile(out_root, 'version_summary.csv'));
        end
        if ~isempty(formal_analysis.pairwise_detail)
            writetable(formal_analysis.pairwise_detail, fullfile(out_root, 'pairwise_detail.csv'));
        end
        if ~isempty(formal_analysis.recommendation_table)
            writetable(formal_analysis.recommendation_table, fullfile(out_root, 'recommendation_scores.csv'));
        end
    end

    report = struct();
    report.pipeline_root = out_root;
    report.scan = scan_info;
    report.smoke_cfg = smoke_cfg;
    report.smoke_output = smoke_output;
    report.smoke_health = smoke_health;
    report.formal_cfg = formal_cfg;
    report.formal_output = formal_output;
    report.formal_analysis = formal_analysis;

    save(fullfile(out_root, 'pipeline_report.mat'), 'report');
    write_analysis_markdown(fullfile(out_root, 'analysis_summary.md'), report, cfg);
    write_recommendation_markdown(fullfile(out_root, 'recommendation.md'), report, cfg);
end

function cfg = fill_default_cfg(cfg)
    if ~isfield(cfg, 'suites')
        cfg.suites = {'cec2017'};
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
        cfg.rng_seed = 20260314;
    end
    if ~isfield(cfg, 'result_root')
        cfg.result_root = 'results';
    end
    if ~isfield(cfg, 'experiment_name') || isempty(cfg.experiment_name)
        cfg.experiment_name = ['v3_dual_objective_' datestr(now, 'yyyymmdd_HHMMSS')];
    end

    if ~isfield(cfg, 'candidate_algorithms')
        cfg.candidate_algorithms = {
            'V3_BASELINE', ...
            'V3_FAST_SIMPLE_A', ...
            'V3_FAST_SIMPLE_B', ...
            'V3_DIR_LATE', ...
            'V3_DIR_STAGNATION', ...
            'V3_DIR_ELITE_ONLY', ...
            'V3_DIR_SMALL_STEP', ...
            'V3_HYBRID_A_DIR_STAG', ...
            'V3_HYBRID_B_DIR_SMALL'};
    end

    if ~isfield(cfg, 'comparison_algorithms')
        cfg.comparison_algorithms = {'BBO_BASE', 'SBO', 'MGO', 'PLO'};
    end

    if ~isfield(cfg, 'smoke_runs')
        cfg.smoke_runs = 1;
    end
    if ~isfield(cfg, 'smoke_func_ids')
        cfg.smoke_func_ids = struct('cec2017', 1:3, 'cec2022', 1:3);
    end

    if ~isfield(cfg, 'run_formal')
        cfg.run_formal = true;
    end
    if ~isfield(cfg, 'formal_runs')
        cfg.formal_runs = 5;
    end
    if ~isfield(cfg, 'formal_func_ids')
        cfg.formal_func_ids = struct('cec2017', 1:30, 'cec2022', 1:12);
    end

    if ~isfield(cfg, 'simple_func_ids')
        cfg.simple_func_ids = struct('cec2017', 1:10, 'cec2022', 1:4);
    end

    if ~isfield(cfg, 'skip_formal_on_smoke_fail')
        cfg.skip_formal_on_smoke_fail = true;
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
        cfg.plot.types.search_process_overview = false;
    end
    if ~isfield(cfg.plot.types, 'mean_fitness')
        cfg.plot.types.mean_fitness = false;
    end
    if ~isfield(cfg.plot.types, 'trajectory_first_dim')
        cfg.plot.types.trajectory_first_dim = false;
    end
    if ~isfield(cfg.plot.types, 'final_population')
        cfg.plot.types.final_population = false;
    end
end

function paths = resolve_paths()
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);

    paths = struct();
    paths.repo_root = fullfile(this_dir, '..', '..', '..');
    paths.runner_file = fullfile(paths.repo_root, 'src', 'benchmark', 'cec_runner', 'run_all_compare.m');
    paths.pipeline_file = fullfile(paths.repo_root, 'src', 'benchmark', 'cec_runner', 'run_bbo_research_pipeline.m');
    paths.v3_file = fullfile(paths.repo_root, 'src', 'improved', 'algorithms', 'BBO', 'BBO_improved_v3.m');
    paths.v4_file = fullfile(paths.repo_root, 'src', 'improved', 'algorithms', 'BBO', 'BBO_improved_v4.m');
    paths.base_bbo_2017 = fullfile(paths.repo_root, 'src', 'baselines', 'metaheuristics', 'BBO', ...
        'Source_code_BBO_MATLAB_VERSION_extracted', 'Source_code_BBO_MATLAB_VERSION', 'CEC2017', 'BBO.m');
end

function scan = scan_key_files(paths, cfg)
    scan = struct();
    scan.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    scan.files = struct();
    scan.files.run_all_compare = isfile(paths.runner_file);
    scan.files.run_bbo_research_pipeline = isfile(paths.pipeline_file);
    scan.files.BBO_improved_v3 = isfile(paths.v3_file);
    scan.files.BBO_improved_v4 = isfile(paths.v4_file);
    scan.files.BBO_base_cec2017 = isfile(paths.base_bbo_2017);

    improved_root = fullfile(paths.repo_root, 'src', 'improved', 'algorithms', 'BBO');
    for i = 1:numel(cfg.candidate_algorithms)
        alg = char(cfg.candidate_algorithms{i});
        entry = lower(alg);
        file_name = [name_from_algorithm(alg) '.m'];
        scan.files.(matlab.lang.makeValidName(entry)) = isfile(fullfile(improved_root, file_name));
    end
end

function smoke_cfg = build_smoke_cfg(cfg)
    smoke_cfg = struct();
    smoke_cfg.suites = cfg.suites;
    smoke_cfg.algorithms = unique([cfg.candidate_algorithms, cfg.comparison_algorithms], 'stable');
    smoke_cfg.func_ids = cfg.smoke_func_ids;
    smoke_cfg.dim = cfg.dim;
    smoke_cfg.pop_size = cfg.pop_size;
    smoke_cfg.maxFEs = cfg.maxFEs;
    smoke_cfg.runs = cfg.smoke_runs;
    smoke_cfg.rng_seed = cfg.rng_seed;
    smoke_cfg.experiment_name = [cfg.experiment_name '_smoke'];
    smoke_cfg.result_root = cfg.result_root;
    smoke_cfg.save_curve = cfg.save_curve;
    smoke_cfg.save_mat = cfg.save_mat;
    smoke_cfg.save_csv = cfg.save_csv;
    smoke_cfg.plot = cfg.plot;
end

function formal_cfg = build_formal_cfg(cfg)
    formal_cfg = struct();
    formal_cfg.suites = cfg.suites;
    formal_cfg.algorithms = unique([cfg.candidate_algorithms, cfg.comparison_algorithms], 'stable');
    formal_cfg.func_ids = cfg.formal_func_ids;
    formal_cfg.dim = cfg.dim;
    formal_cfg.pop_size = cfg.pop_size;
    formal_cfg.maxFEs = cfg.maxFEs;
    formal_cfg.runs = cfg.formal_runs;
    formal_cfg.rng_seed = cfg.rng_seed;
    formal_cfg.experiment_name = [cfg.experiment_name '_formal'];
    formal_cfg.result_root = cfg.result_root;
    formal_cfg.save_curve = cfg.save_curve;
    formal_cfg.save_mat = cfg.save_mat;
    formal_cfg.save_csv = cfg.save_csv;
    formal_cfg.plot = cfg.plot;
end

function health = evaluate_smoke_health(smoke_output, cfg)
    health = struct();
    health.pass = true;
    health.status = 'pass';
    health.missing_algorithms = {};
    health.missing_suites = {};
    health.anomalies = {};
    health.nan_or_inf_runs = 0;
    health.non_monotonic_curve_runs = 0;
    health.raw_run_files_checked = 0;

    expected_suites = unique(cfg.suites, 'stable');
    expected_algorithms = unique([cfg.candidate_algorithms, cfg.comparison_algorithms], 'stable');

    if ~isfield(smoke_output, 'suite_results') || isempty(smoke_output.suite_results)
        health.pass = false;
        health.status = 'fail';
        health.anomalies{end + 1} = 'smoke output has no suite_results'; %#ok<AGROW>
        return;
    end

    observed_suites = {};
    observed_algorithms = {};

    for i = 1:numel(smoke_output.suite_results)
        suite_item = smoke_output.suite_results(i);
        suite_name = char(string(suite_item.suite));
        observed_suites{end + 1} = suite_name; %#ok<AGROW>

        if isempty(suite_item.summary) || ~istable(suite_item.summary)
            health.anomalies{end + 1} = sprintf('%s summary missing/invalid', suite_name); %#ok<AGROW>
            continue;
        end

        summary_table = suite_item.summary;
        if height(summary_table) == 0
            health.anomalies{end + 1} = sprintf('%s summary empty', suite_name); %#ok<AGROW>
        else
            observed_algorithms = [observed_algorithms, unique(cellstr(string(summary_table.algorithm_name)), 'stable')]; %#ok<AGROW>
            if any(~isfinite(summary_table.mean)) || any(~isfinite(summary_table.std))
                health.anomalies{end + 1} = sprintf('%s summary has NaN/Inf in mean/std', suite_name); %#ok<AGROW>
            end
        end

        raw_dir = fullfile(suite_item.result_dir, 'raw_runs');
        if ~isfolder(raw_dir)
            health.anomalies{end + 1} = sprintf('%s raw_runs folder missing', suite_name); %#ok<AGROW>
            continue;
        end

        files = dir(fullfile(raw_dir, '*.mat'));
        for k = 1:numel(files)
            fpath = fullfile(raw_dir, files(k).name);
            S = load(fpath, 'run_result');
            if ~isfield(S, 'run_result')
                health.anomalies{end + 1} = sprintf('invalid run file: %s', files(k).name); %#ok<AGROW>
                continue;
            end

            rr = S.run_result;
            health.raw_run_files_checked = health.raw_run_files_checked + 1;

            if ~isfinite(rr.best_score) || ~isfinite(rr.runtime)
                health.nan_or_inf_runs = health.nan_or_inf_runs + 1;
                health.anomalies{end + 1} = sprintf('NaN/Inf score/runtime: %s', files(k).name); %#ok<AGROW>
            end

            if any(~isfinite(rr.best_position)) || any(~isfinite(rr.convergence_curve))
                health.nan_or_inf_runs = health.nan_or_inf_runs + 1;
                health.anomalies{end + 1} = sprintf('NaN/Inf in position/curve: %s', files(k).name); %#ok<AGROW>
            end

            diffs = diff(rr.convergence_curve(:));
            if any(diffs > 1e-10)
                health.non_monotonic_curve_runs = health.non_monotonic_curve_runs + 1;
                health.anomalies{end + 1} = sprintf('non-monotonic best curve: %s', files(k).name); %#ok<AGROW>
            end
        end
    end

    observed_suites = unique(observed_suites, 'stable');
    observed_algorithms = unique(observed_algorithms, 'stable');

    health.missing_suites = setdiff(expected_suites, observed_suites, 'stable');
    health.missing_algorithms = setdiff(expected_algorithms, observed_algorithms, 'stable');

    if ~isempty(health.missing_suites) || ~isempty(health.missing_algorithms) || ...
            ~isempty(health.anomalies) || health.raw_run_files_checked == 0
        health.pass = false;
        health.status = 'fail';
    end
end

function out = make_empty_formal_analysis()
    out = struct();
    out.version_summary = table();
    out.pairwise_detail = table();
    out.recommendation_table = table();
    out.recommended_version = '';
    out.recommendation_note = 'formal not executed';
end

function analysis = analyze_formal_output(formal_output, cfg)
    analysis = make_empty_formal_analysis();

    summary_all = table();
    for i = 1:numel(formal_output.suite_results)
        T = formal_output.suite_results(i).summary;
        if isempty(T)
            continue;
        end
        T.suite = repmat(string(formal_output.suite_results(i).suite), height(T), 1);
        summary_all = [summary_all; T]; %#ok<AGROW>
    end

    if isempty(summary_all)
        analysis.recommendation_note = 'formal output has empty summary';
        return;
    end

    base_alg = "V3_BASELINE";
    candidates = string(cfg.candidate_algorithms);

    detail_rows = table();
    version_rows = table();

    suites = unique(summary_all.suite, 'stable');
    for c = 1:numel(candidates)
        alg = candidates(c);
        if alg == base_alg
            continue;
        end

        [detail_alg, agg] = compare_against_baseline(summary_all, suites, alg, base_alg, cfg.simple_func_ids);
        detail_rows = [detail_rows; detail_alg]; %#ok<AGROW>

        row = table(alg, agg.improved, agg.tie, agg.degraded, agg.net_gain, ...
            agg.avg_improvement, agg.avg_degradation, agg.std_delta_mean, ...
            agg.simple_delta_mean, agg.complex_delta_mean, agg.avg_runtime, ...
            agg.avg_rank, 'VariableNames', ...
            {'algorithm','improved','tie','degraded','net_gain', ...
            'avg_improvement','avg_degradation','std_delta_mean', ...
            'simple_delta_mean','complex_delta_mean','avg_runtime','avg_rank'});
        version_rows = [version_rows; row]; %#ok<AGROW>
    end

    if isempty(version_rows)
        analysis.recommendation_note = 'no candidate rows can be compared with V3_BASELINE';
        analysis.pairwise_detail = detail_rows;
        analysis.version_summary = version_rows;
        return;
    end

    rec_table = score_versions(version_rows);
    analysis.recommendation_table = rec_table;
    analysis.version_summary = sortrows(version_rows, {'net_gain','avg_rank'}, {'descend','ascend'});
    analysis.pairwise_detail = detail_rows;

    top_alg = string(rec_table.algorithm(1));
    top_score = rec_table.total_score(1);
    if top_score <= 0 || rec_table.net_gain(1) <= 0
        analysis.recommended_version = '';
        analysis.recommendation_note = 'No candidate shows robust formal superiority over V3_BASELINE.';
    else
        analysis.recommended_version = char(top_alg);
        analysis.recommendation_note = sprintf('Recommend %s as next v3 branch candidate.', char(top_alg));
    end
end

function [detail_table, agg] = compare_against_baseline(summary_all, suites, alg, base_alg, simple_func_ids)
    detail_table = table();

    improved = 0;
    tie_count = 0;
    degraded = 0;
    pos_deltas = [];
    neg_deltas = [];
    std_deltas = [];
    simple_deltas = [];
    complex_deltas = [];
    ranks = [];
    runtimes = [];

    for s = 1:numel(suites)
        suite_name = suites(s);
        Ts = summary_all(summary_all.suite == suite_name, :);
        fids = unique(Ts.function_id, 'stable');

        for f = 1:numel(fids)
            fid = fids(f);
            row_base = Ts(Ts.function_id == fid & string(Ts.algorithm_name) == base_alg, :);
            row_alg = Ts(Ts.function_id == fid & string(Ts.algorithm_name) == alg, :);
            if isempty(row_base) || isempty(row_alg)
                continue;
            end

            delta = row_base.mean(1) - row_alg.mean(1);
            std_delta = row_alg.std(1) - row_base.std(1);

            status = "tie";
            if delta > 0
                status = "improved";
                improved = improved + 1;
                pos_deltas(end + 1) = delta; %#ok<AGROW>
            elseif delta < 0
                status = "degraded";
                degraded = degraded + 1;
                neg_deltas(end + 1) = abs(delta); %#ok<AGROW>
            else
                tie_count = tie_count + 1;
            end

            if is_simple_function(char(suite_name), fid, simple_func_ids)
                simple_deltas(end + 1) = delta; %#ok<AGROW>
            else
                complex_deltas(end + 1) = delta; %#ok<AGROW>
            end

            std_deltas(end + 1) = std_delta; %#ok<AGROW>
            runtimes(end + 1) = row_alg.avg_runtime(1); %#ok<AGROW>

            sub = Ts(Ts.function_id == fid, :);
            [~, order] = sort(sub.mean, 'ascend');
            alg_names = string(sub.algorithm_name);
            rank_idx = find(alg_names(order) == alg, 1, 'first');
            if ~isempty(rank_idx)
                ranks(end + 1) = rank_idx; %#ok<AGROW>
            end

            drow = table(string(suite_name), fid, alg, row_base.mean(1), row_alg.mean(1), delta, std_delta, status, ...
                'VariableNames', {'suite','function_id','algorithm','base_mean','alg_mean','mean_delta','std_delta','status'});
            detail_table = [detail_table; drow]; %#ok<AGROW>
        end
    end

    agg = struct();
    agg.improved = improved;
    agg.tie = tie_count;
    agg.degraded = degraded;
    agg.net_gain = improved - degraded;
    agg.avg_improvement = safe_mean(pos_deltas);
    agg.avg_degradation = safe_mean(neg_deltas);
    agg.std_delta_mean = safe_mean(std_deltas);
    agg.simple_delta_mean = safe_mean(simple_deltas);
    agg.complex_delta_mean = safe_mean(complex_deltas);
    agg.avg_runtime = safe_mean(runtimes);
    agg.avg_rank = safe_mean(ranks);
end

function tf = is_simple_function(suite_name, fid, simple_func_ids)
    tf = false;
    if isstruct(simple_func_ids) && isfield(simple_func_ids, suite_name)
        tf = ismember(fid, simple_func_ids.(suite_name));
    end
end

function m = safe_mean(x)
    if isempty(x)
        m = nan;
    else
        m = mean(x);
    end
end

function rec = score_versions(version_rows)
    rec = version_rows;

    rec.simple_score = normalize_zero_one(rec.simple_delta_mean);
    rec.complex_score = normalize_zero_one(rec.complex_delta_mean);
    rec.stability_score = normalize_zero_one(-rec.std_delta_mean);
    rec.rank_score = normalize_zero_one(-rec.avg_rank);
    rec.net_gain_score = normalize_zero_one(rec.net_gain);

    rec.total_score = 0.35 .* rec.net_gain_score + ...
        0.25 .* rec.simple_score + ...
        0.15 .* rec.complex_score + ...
        0.15 .* rec.stability_score + ...
        0.10 .* rec.rank_score;

    rec = sortrows(rec, {'total_score','net_gain','avg_rank'}, {'descend','descend','ascend'});
end

function y = normalize_zero_one(x)
    x = double(x);
    bad = ~isfinite(x);
    if all(bad)
        y = zeros(size(x));
        return;
    end

    x(bad) = min(x(~bad));
    xmin = min(x);
    xmax = max(x);

    if abs(xmax - xmin) < 1e-12
        y = ones(size(x));
    else
        y = (x - xmin) ./ (xmax - xmin);
    end
end

function write_scan_markdown(file_path, scan_info, cfg)
    fid = fopen(file_path, 'w');
    c = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# Dual-Objective V3 Ablation: Repository Scan\n\n');
    fprintf(fid, '- Timestamp: %s\n', scan_info.timestamp);
    fprintf(fid, '- Experiment: %s\n\n', cfg.experiment_name);

    keys = fieldnames(scan_info.files);
    for i = 1:numel(keys)
        fprintf(fid, '- %s: %d\n', keys{i}, scan_info.files.(keys{i}));
    end
end

function write_analysis_markdown(file_path, report, ~)
    fid = fopen(file_path, 'w');
    c = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# Dual-Objective Ablation Summary (V3 trunk)\n\n');
    fprintf(fid, '## 1. Task understanding\n');
    fprintf(fid, '- Objective A: improve v3 on simple/easy-to-exploit landscapes.\n');
    fprintf(fid, '- Objective B: keep directional enhancement conditional and conservative.\n\n');

    fprintf(fid, '## 2. Workflow placement\n');
    fprintf(fid, '- This stage belongs to benchmark + ablation + paper-support analysis.\n');
    fprintf(fid, '- Benchmark backend remains run_all_compare.\n\n');

    fprintf(fid, '## 3. Smoke status\n');
    fprintf(fid, '- Smoke status: %s\n', report.smoke_health.status);
    fprintf(fid, '- Raw run files checked: %d\n', report.smoke_health.raw_run_files_checked);
    fprintf(fid, '- NaN/Inf run anomalies: %d\n', report.smoke_health.nan_or_inf_runs);
    fprintf(fid, '- Non-monotonic curve runs: %d\n', report.smoke_health.non_monotonic_curve_runs);
    if ~isempty(report.smoke_health.missing_suites)
        fprintf(fid, '- Missing suites: %s\n', strjoin(report.smoke_health.missing_suites, ', '));
    end
    if ~isempty(report.smoke_health.missing_algorithms)
        fprintf(fid, '- Missing algorithms: %s\n', strjoin(report.smoke_health.missing_algorithms, ', '));
    end
    for i = 1:numel(report.smoke_health.anomalies)
        fprintf(fid, '- Smoke anomaly: %s\n', report.smoke_health.anomalies{i});
    end
    fprintf(fid, '\n');

    fprintf(fid, '## 4. Formal protocol\n');
    if isempty(fieldnames(report.formal_cfg))
        fprintf(fid, '- Formal skipped (smoke failed or run_formal=false).\n\n');
    else
        fprintf(fid, '- suites: %s\n', strjoin(report.formal_cfg.suites, ', '));
        fprintf(fid, '- dim=%d, pop_size=%d, maxFEs=%d, runs=%d, seed=%d\n', ...
            report.formal_cfg.dim, report.formal_cfg.pop_size, report.formal_cfg.maxFEs, report.formal_cfg.runs, report.formal_cfg.rng_seed);
        fprintf(fid, '- algorithms: %s\n\n', strjoin(report.formal_cfg.algorithms, ', '));
    end

    fprintf(fid, '## 5. Formal summary\n');
    if isempty(report.formal_analysis.version_summary)
        fprintf(fid, '- No formal comparison table available.\n\n');
    else
        T = report.formal_analysis.version_summary;
        for i = 1:height(T)
            fprintf(fid, '- %s: improved=%d, tie=%d, degraded=%d, net=%d, avg_imp=%.4g, avg_deg=%.4g, std_delta=%.4g, simple_delta=%.4g, complex_delta=%.4g, avg_rank=%.3f\n', ...
                char(T.algorithm(i)), T.improved(i), T.tie(i), T.degraded(i), T.net_gain(i), ...
                T.avg_improvement(i), T.avg_degradation(i), T.std_delta_mean(i), ...
                T.simple_delta_mean(i), T.complex_delta_mean(i), T.avg_rank(i));
        end
        fprintf(fid, '\n');
    end

    fprintf(fid, '## 6. Interpretation\n');
    fprintf(fid, '- fast_simple modules target convergence acceleration and late precision on simple functions.\n');
    fprintf(fid, '- directional modules are intentionally conditional to avoid v4-like global over-guidance.\n');
    fprintf(fid, '- hybrid modules test whether local convergence gains can coexist with conservative directional rescue.\n\n');

    fprintf(fid, '## 7. Recommendation\n');
    fprintf(fid, '- %s\n\n', report.formal_analysis.recommendation_note);

    fprintf(fid, '## 8. Risks and assumptions\n');
    fprintf(fid, '- simple-vs-complex split uses function-id proxy from cfg.simple_func_ids and must be reported explicitly in paper.\n');
    fprintf(fid, '- if no robust winner appears, keep v3 trunk and continue conservative tuning only.\n');
end

function write_recommendation_markdown(file_path, report, cfg)
    fid = fopen(file_path, 'w');
    c = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# Recommendation\n\n');
    fprintf(fid, '## Candidate set\n');
    fprintf(fid, '- %s\n\n', strjoin(cfg.candidate_algorithms, ', '));

    fprintf(fid, '## Recommended next v3 branch\n');
    if isempty(report.formal_analysis.recommended_version)
        fprintf(fid, '- No robust replacement for V3_BASELINE found in this formal run.\n');
        fprintf(fid, '- Recommendation: keep V3_BASELINE as trunk and retain best hybrid/directional as optional branch only.\n\n');
    else
        fprintf(fid, '- %s\n', report.formal_analysis.recommended_version);
        fprintf(fid, '- Evidence: recommendation score table + improved/tie/degraded + simple/complex delta.\n\n');
    end

    fprintf(fid, '## Potentially retireable directions\n');
    if isempty(report.formal_analysis.recommendation_table)
        fprintf(fid, '- Not available because formal analysis is empty.\n');
    else
        T = report.formal_analysis.recommendation_table;
        worst_n = min(2, height(T));
        for i = height(T)-worst_n+1:height(T)
            fprintf(fid, '- %s (score=%.4f, net=%d, simple_delta=%.4g, complex_delta=%.4g)\n', ...
                char(T.algorithm(i)), T.total_score(i), T.net_gain(i), T.simple_delta_mean(i), T.complex_delta_mean(i));
        end
    end
end

function s = name_from_algorithm(alg)
    switch upper(string(alg))
        case "V3_BASELINE"
            s = 'BBO_v3_baseline';
        case "V3_FAST_SIMPLE_A"
            s = 'BBO_v3_fast_simple_A';
        case "V3_FAST_SIMPLE_B"
            s = 'BBO_v3_fast_simple_B';
        case "V3_DIR_LATE"
            s = 'BBO_v3_dir_late';
        case "V3_DIR_STAGNATION"
            s = 'BBO_v3_dir_stagnation';
        case "V3_DIR_ELITE_ONLY"
            s = 'BBO_v3_dir_elite_only';
        case "V3_DIR_SMALL_STEP"
            s = 'BBO_v3_dir_small_step';
        case "V3_HYBRID_A_DIR_STAG"
            s = 'BBO_v3_hybrid_A_dir_stag';
        case "V3_HYBRID_B_DIR_SMALL"
            s = 'BBO_v3_hybrid_B_dir_small';
        otherwise
            error('Unknown algorithm alias: %s', char(alg));
    end
end

function ensure_dir(path_str)
    if ~isfolder(path_str)
        mkdir(path_str);
    end
end
