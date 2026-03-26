function report = run_bbo_prototype_routes_smoke(cfg)
% run_bbo_prototype_routes_smoke
% Unified smoke pipeline for lightweight multi-route prototypes.
% Stage 1: unified skeleton + registration + summary.
% Stage 2: each route keeps one core innovation only.

    if nargin < 1
        cfg = struct();
    end

    cfg = fill_defaults(cfg);

    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    repo_root = fullfile(this_dir, '..', '..', '..');

    addpath(fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'entry'));

    run_cfg = struct();
    run_cfg.mode = 'smoke';
    run_cfg.suites = {'cec2017'};
    run_cfg.algorithms = {'ROUTE_A', 'ROUTE_B', 'ROUTE_C', 'ROUTE_D'};
    run_cfg.dim = cfg.dim;
    run_cfg.pop_size = cfg.pop_size;
    run_cfg.maxFEs = cfg.maxFEs;
    run_cfg.rng_seed = cfg.rng_seed;
    run_cfg.result_root = 'results';
    run_cfg.result_group = fullfile('benchmark', 'research_pipeline');
    run_cfg.result_layout = 'suite_then_experiment';
    run_cfg.explicit_experiment_name = cfg.experiment_name;
    run_cfg.save_curve = true;
    run_cfg.save_mat = true;
    run_cfg.save_csv = true;
    run_cfg.plot = struct('enable', false, 'show', false, 'save', false, 'formats', {{'png'}});
    run_cfg.smoke = struct('runs', cfg.runs, 'func_ids', struct('cec2017', cfg.func_ids));
    run_cfg.export = struct('summary_markdown', true);

    report = run_main_entry(run_cfg);

    suite_result = report.output.suite_results(1);
    result_dir = suite_result.result_dir;
    summary = suite_result.summary;

    route_notes = build_route_notes();
    route_notes_csv = fullfile(result_dir, 'route_notes.csv');
    writetable(route_notes, route_notes_csv);

    compare_table = build_compare_table(summary);
    compare_csv = fullfile(result_dir, 'prototype_routes_compare.csv');
    writetable(compare_table, compare_csv);

    round2_reco = build_round2_recommendation(compare_table);
    round2_csv = fullfile(result_dir, 'prototype_routes_round2_recommendation.csv');
    writetable(round2_reco, round2_csv);

    write_summary_md(fullfile(result_dir, 'prototype_routes_summary.md'), cfg, route_notes, compare_table, round2_reco, result_dir);

    report.prototype = struct();
    report.prototype.route_notes_csv = route_notes_csv;
    report.prototype.compare_csv = compare_csv;
    report.prototype.round2_csv = round2_csv;

    disp(result_dir);
end

function cfg = fill_defaults(cfg)
    if ~isfield(cfg, 'func_ids') || isempty(cfg.func_ids)
        cfg.func_ids = [1, 5, 13, 24, 30, 18, 26];
    end
    if ~isfield(cfg, 'maxFEs')
        cfg.maxFEs = 30000;
    end
    if ~isfield(cfg, 'runs')
        cfg.runs = 5;
    end
    if ~isfield(cfg, 'dim')
        cfg.dim = 10;
    end
    if ~isfield(cfg, 'pop_size')
        cfg.pop_size = 30;
    end
    if ~isfield(cfg, 'rng_seed')
        cfg.rng_seed = 20260317;
    end
    if ~isfield(cfg, 'experiment_name') || strlength(string(cfg.experiment_name)) == 0
        cfg.experiment_name = sprintf('prototype_routes_smoke_30000fe_%s', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
    end
end

function notes = build_route_notes()
    notes = table();
    notes.route = string({ ...
        'route_a: sel_gdp_reference', ...
        'route_b: state_driven_bbo', ...
        'route_c: dimension_selective_bbo', ...
        'route_d: multi_elite_reference_bbo'})';
    notes.algorithm_name = string({ ...
        'ROUTE_A_SEL_GDP_REFERENCE', ...
        'ROUTE_B_STATE_DRIVEN_BBO', ...
        'ROUTE_C_DIMENSION_SELECTIVE_BBO', ...
        'ROUTE_D_MULTI_ELITE_REFERENCE_BBO'})';
    notes.core_idea = string({ ...
        'SEL+GDP reference line without ESC', ...
        'Three-state GDP schedule (early/mid/late)', ...
        'Fixed-ratio dimension-selective SEL', ...
        'Top-k blended multi-elite directional reference'})';
    notes.weakness = string({ ...
        'May still underperform on hard composition tails', ...
        'State transition thresholds may be sensitive', ...
        'No macro directional correction in late stage', ...
        'May inject excessive directional bias on simple functions'})';
    notes.expected_gain = string({ ...
        'Stable mixed-performance reference baseline', ...
        'Better adaptation under stage-dependent stagnation', ...
        'Lower dimensional noise and improved robustness', ...
        'Faster escape from poor basins via richer elite cues'})';
    notes.expected_risk = string({ ...
        'Can miss occasional escape opportunities', ...
        'If thresholds mis-set, trigger may lag/overshoot', ...
        'May converge slowly on hybrid/composition cases', ...
        'May enlarge variance if elite set is unstable'})';
end

function T = build_compare_table(summary)
    if ~istable(summary)
        error('summary must be a table.');
    end

    route_rows = summary(startsWith(string(summary.algorithm_name), "ROUTE_"), :);
    algs = unique(string(route_rows.algorithm_name), 'stable');

    T = table();
    T.algorithm_name = algs;
    T.mean_over_funcs = zeros(numel(algs), 1);
    T.std_over_funcs = zeros(numel(algs), 1);
    T.runtime_over_funcs = zeros(numel(algs), 1);
    T.win_count = zeros(numel(algs), 1);

    for i = 1:numel(algs)
        A = route_rows(strcmp(string(route_rows.algorithm_name), algs(i)), :);
        T.mean_over_funcs(i) = mean(A.mean);
        T.std_over_funcs(i) = mean(A.std);
        T.runtime_over_funcs(i) = mean(A.avg_runtime);
    end

    fids = unique(route_rows.function_id);
    for k = 1:numel(fids)
        F = route_rows(route_rows.function_id == fids(k), :);
        [~, idx] = min(F.mean);
        winner = string(F.algorithm_name(idx));
        T.win_count(strcmp(T.algorithm_name, winner)) = T.win_count(strcmp(T.algorithm_name, winner)) + 1;
    end

    T = sortrows(T, {'win_count', 'mean_over_funcs', 'std_over_funcs'}, {'descend', 'ascend', 'ascend'});
end

function R = build_round2_recommendation(compare_table)
    n = height(compare_table);
    if n == 0
        R = compare_table;
        return;
    end

    win_rank = local_rank(-compare_table.win_count);
    mean_rank = local_rank(compare_table.mean_over_funcs);
    std_rank = local_rank(compare_table.std_over_funcs);

    % Lower score is better: prioritize win_count, then mean/std stability.
    compare_table.selection_score = 0.50 * win_rank + 0.30 * mean_rank + 0.20 * std_rank;

    compare_table.mean_rank = mean_rank;
    compare_table.std_rank = std_rank;
    stability_guard = compare_table.mean_rank < n & compare_table.std_rank < n;
    filtered = compare_table(stability_guard, :);
    if isempty(filtered)
        filtered = compare_table;
    end

    filtered = sortrows(filtered, {'selection_score', 'win_count', 'mean_over_funcs', 'std_over_funcs'}, {'ascend', 'descend', 'ascend', 'ascend'});

    top_n = min(2, height(filtered));
    R = filtered(1:top_n, :);
    R.recommend_round2 = repmat("yes", top_n, 1);
    R.reason = strings(top_n, 1);

    for i = 1:top_n
        R.reason(i) = sprintf('score=%.4f, win_count=%d, mean=%.6g, std=%.6g', ...
            R.selection_score(i), R.win_count(i), R.mean_over_funcs(i), R.std_over_funcs(i));
    end
end

function r = local_rank(x)
    [~, order] = sort(x, 'ascend');
    r = zeros(size(x));
    r(order) = 1:numel(x);
end

function write_summary_md(file_path, cfg, notes, compare_table, round2_reco, result_dir)
    fid = fopen(file_path, 'w');

    fprintf(fid, '# Prototype Routes Smoke Summary\n\n');
    fprintf(fid, '## Unified Smoke Config\n');
    fprintf(fid, '- suite: cec2017\n');
    fprintf(fid, '- func_ids: [%s]\n', strjoin(string(cfg.func_ids), ', '));
    fprintf(fid, '- maxFEs: %d\n', cfg.maxFEs);
    fprintf(fid, '- runs: %d\n', cfg.runs);
    fprintf(fid, '- dim: %d\n', cfg.dim);
    fprintf(fid, '- pop_size: %d\n\n', cfg.pop_size);

    fprintf(fid, '## Routes\n');
    for i = 1:height(notes)
        fprintf(fid, '- %s\n', notes.route(i));
        fprintf(fid, '  - idea: %s\n', notes.core_idea(i));
        fprintf(fid, '  - weakness: %s\n', notes.weakness(i));
        fprintf(fid, '  - expected_gain: %s\n', notes.expected_gain(i));
        fprintf(fid, '  - expected_risk: %s\n', notes.expected_risk(i));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Unified Compare\n\n');
    fprintf(fid, '| algorithm_name | mean_over_funcs | std_over_funcs | runtime_over_funcs | win_count |\n');
    fprintf(fid, '| -------------- | --------------- | -------------- | ----------------- | --------- |\n');
    for i = 1:height(compare_table)
        fprintf(fid, '| %s | %.6g | %.6g | %.6g | %d |\n', ...
            compare_table.algorithm_name(i), compare_table.mean_over_funcs(i), ...
            compare_table.std_over_funcs(i), compare_table.runtime_over_funcs(i), ...
            compare_table.win_count(i));
    end

    fprintf(fid, '\n## Round2 Candidates\n');
    for i = 1:height(round2_reco)
        fprintf(fid, '- %s (%s)\n', round2_reco.algorithm_name(i), round2_reco.reason(i));
    end

    fprintf(fid, '\n## Output Files\n');
    fprintf(fid, '- %s\n', fullfile(result_dir, 'route_notes.csv'));
    fprintf(fid, '- %s\n', fullfile(result_dir, 'prototype_routes_compare.csv'));
    fprintf(fid, '- %s\n', fullfile(result_dir, 'prototype_routes_round2_recommendation.csv'));

    fclose(fid);
end
