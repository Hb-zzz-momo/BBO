function report = run_prototype_route_compare_smoke(cfg)
% run_prototype_route_compare_smoke
% Three-route prototype smoke skeleton for baseline + Route A/B/C.
% This entry reuses cec_runner pipeline and only adds route-level metadata exports.

    if nargin < 1
        cfg = struct();
    end

    cfg = fill_defaults(cfg);

    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    repo_root = fullfile(this_dir, '..', '..', '..');

    addpath(fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'entry'));
    addpath(fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'config'));

    route_reg = prototype_route_registry();
    algorithms = [{'BBO_BASE'}, cellstr(route_reg.algorithm_token')];

    run_cfg = struct();
    run_cfg.mode = 'smoke';
    run_cfg.suites = {'cec2017'};
    run_cfg.algorithms = algorithms;
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

    route_reg.algorithm_connected = false(height(route_reg), 1);
    route_reg.connection_note = repmat("not_in_summary", height(route_reg), 1);

    summary_algs = strings(0, 1);
    if istable(summary) && ~isempty(summary)
        summary_algs = unique(string(summary.algorithm_name), 'stable');
    end

    for i = 1:height(route_reg)
        token = string(route_reg.algorithm_token(i));
        route_reg.algorithm_connected(i) = any(strcmp(summary_algs, token));
        if route_reg.algorithm_connected(i)
            if route_reg.is_implemented(i)
                route_reg.connection_note(i) = "connected_implemented";
            else
                route_reg.connection_note(i) = "connected_placeholder";
            end
        end
    end

    compare_table = build_compare_table(summary, route_reg);
    compare_csv = fullfile(result_dir, 'prototype_route_compare.csv');
    writetable(compare_table, compare_csv);

    route_csv = fullfile(result_dir, 'prototype_route_registry.csv');
    writetable(route_reg, route_csv);

    connectivity = route_reg(:, {'route_id', 'algorithm_token', 'is_implemented', 'status', 'algorithm_connected', 'connection_note'});
    connectivity_csv = fullfile(result_dir, 'prototype_route_connectivity.csv');
    writetable(connectivity, connectivity_csv);

    summary_md = fullfile(result_dir, 'prototype_route_compare_summary.md');
    write_summary_md(summary_md, cfg, route_reg, compare_table, result_dir);

    report.prototype = struct();
    report.prototype.route_registry_csv = route_csv;
    report.prototype.route_connectivity_csv = connectivity_csv;
    report.prototype.route_compare_csv = compare_csv;
    report.prototype.route_summary_md = summary_md;

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
        cfg.rng_seed = 20260318;
    end
    if ~isfield(cfg, 'experiment_name') || strlength(string(cfg.experiment_name)) == 0
        cfg.experiment_name = sprintf('prototype_route_compare_smoke_%s', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
    end
end

function T = build_compare_table(summary, route_reg)
    if ~istable(summary) || isempty(summary)
        T = table();
        return;
    end

    route_tokens = unique(string(route_reg.algorithm_token), 'stable');
    keep_mask = strcmp(string(summary.algorithm_name), "BBO_BASE");
    for i = 1:numel(route_tokens)
        keep_mask = keep_mask | strcmp(string(summary.algorithm_name), route_tokens(i)); %#ok<AGROW>
    end

    rows = summary(keep_mask, :);
    algs = unique(string(rows.algorithm_name), 'stable');

    T = table();
    T.algorithm_name = algs;
    T.mean_over_funcs = zeros(numel(algs), 1);
    T.std_over_funcs = zeros(numel(algs), 1);
    T.runtime_over_funcs = zeros(numel(algs), 1);
    T.win_count = zeros(numel(algs), 1);

    for i = 1:numel(algs)
        A = rows(strcmp(string(rows.algorithm_name), algs(i)), :);
        T.mean_over_funcs(i) = mean(A.mean);
        T.std_over_funcs(i) = mean(A.std);
        T.runtime_over_funcs(i) = mean(A.avg_runtime);
    end

    fids = unique(rows.function_id);
    for k = 1:numel(fids)
        F = rows(rows.function_id == fids(k), :);
        [~, idx] = min(F.mean);
        winner = string(F.algorithm_name(idx));
        T.win_count(strcmp(T.algorithm_name, winner)) = T.win_count(strcmp(T.algorithm_name, winner)) + 1;
    end

    T = sortrows(T, {'win_count', 'mean_over_funcs', 'std_over_funcs'}, {'descend', 'ascend', 'ascend'});
end

function write_summary_md(file_path, cfg, route_reg, compare_table, result_dir)
    fid = fopen(file_path, 'w');
    if fid == -1
        error('Cannot write summary markdown: %s', file_path);
    end
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# Prototype Route Compare Smoke Summary\n\n');
    fprintf(fid, '## Smoke Config\n');
    fprintf(fid, '- suite: cec2017\n');
    fprintf(fid, '- func_ids: [%s]\n', strjoin(string(cfg.func_ids), ', '));
    fprintf(fid, '- maxFEs: %d\n', cfg.maxFEs);
    fprintf(fid, '- runs: %d\n', cfg.runs);
    fprintf(fid, '- dim: %d\n', cfg.dim);
    fprintf(fid, '- pop_size: %d\n\n', cfg.pop_size);

    fprintf(fid, '## Route Registry\n\n');
    fprintf(fid, '| route_id | algorithm_token | implemented | status | connected | note |\n');
    fprintf(fid, '| -------- | --------------- | ----------- | ------ | --------- | ---- |\n');
    for i = 1:height(route_reg)
        impl_txt = string(route_reg.is_implemented(i));
        conn_txt = string(route_reg.algorithm_connected(i));
        fprintf(fid, '| %s | %s | %s | %s | %s | %s |\n', ...
            route_reg.route_id(i), route_reg.algorithm_token(i), impl_txt, ...
            route_reg.status(i), conn_txt, route_reg.connection_note(i));
    end

    fprintf(fid, '\n## Route Notes\n');
    for i = 1:height(route_reg)
        fprintf(fid, '- %s: %s\n', route_reg.route_id(i), route_reg.route_note(i));
    end

    fprintf(fid, '\n## Compare (Baseline + Routes)\n\n');
    if isempty(compare_table)
        fprintf(fid, 'No compare rows available.\n');
    else
        fprintf(fid, '| algorithm_name | mean_over_funcs | std_over_funcs | runtime_over_funcs | win_count |\n');
        fprintf(fid, '| -------------- | --------------- | -------------- | ----------------- | --------- |\n');
        for i = 1:height(compare_table)
            fprintf(fid, '| %s | %.6g | %.6g | %.6g | %d |\n', ...
                compare_table.algorithm_name(i), compare_table.mean_over_funcs(i), ...
                compare_table.std_over_funcs(i), compare_table.runtime_over_funcs(i), ...
                compare_table.win_count(i));
        end
    end

    fprintf(fid, '\n## Output Files\n');
    fprintf(fid, '- %s\n', fullfile(result_dir, 'summary.csv'));
    fprintf(fid, '- %s\n', fullfile(result_dir, 'rank_table.csv'));
    fprintf(fid, '- %s\n', fullfile(result_dir, 'prototype_route_registry.csv'));
    fprintf(fid, '- %s\n', fullfile(result_dir, 'prototype_route_connectivity.csv'));
    fprintf(fid, '- %s\n', fullfile(result_dir, 'prototype_route_compare.csv'));
    fprintf(fid, '- %s\n', fullfile(result_dir, 'improved_algorithm_notes.md'));
end
