function report = run_route_a_family_smoke(cfg)
% run_route_a_family_smoke
% Unified smoke entry for Route A family versions.

    if nargin < 1
        cfg = struct();
    end

    cfg = fill_defaults(cfg);

    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    repo_root = fullfile(this_dir, '..', '..', '..');

    addpath(fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'entry'));
    addpath(fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'config'));

    reg = route_a_family_registry();

    run_cfg = struct();
    run_cfg.mode = 'smoke';
    run_cfg.suites = {'cec2017'};
    run_cfg.algorithms = cellstr(reg.algorithm_token');
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

    compare_table = build_compare_table(summary, reg);
    compare_csv = fullfile(result_dir, 'route_a_family_compare.csv');
    writetable(compare_table, compare_csv);

    registry_csv = fullfile(result_dir, 'route_a_family_registry.csv');
    writetable(reg, registry_csv);

    notes_md = fullfile(result_dir, 'route_a_family_version_notes.md');
    write_version_notes(notes_md, reg, cfg, result_dir);

    report.route_a_family = struct();
    report.route_a_family.registry_csv = registry_csv;
    report.route_a_family.compare_csv = compare_csv;
    report.route_a_family.notes_md = notes_md;

    disp(result_dir);
end

function cfg = fill_defaults(cfg)
    if ~isfield(cfg, 'func_ids') || isempty(cfg.func_ids)
        cfg.func_ids = [2, 10, 11, 30];
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
        cfg.rng_seed = 20260319;
    end
    if ~isfield(cfg, 'experiment_name') || strlength(string(cfg.experiment_name)) == 0
        cfg.experiment_name = sprintf('routeA_family_smoke_%s', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
    end
end

function T = build_compare_table(summary, reg)
    if ~istable(summary) || isempty(summary)
        T = table();
        return;
    end

    tokens = resolve_summary_names(reg);
    keep_mask = false(height(summary), 1);
    for i = 1:numel(tokens)
        keep_mask = keep_mask | strcmp(string(summary.algorithm_name), tokens(i)); %#ok<AGROW>
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

function names = resolve_summary_names(reg)
    names = strings(height(reg), 1);
    for i = 1:height(reg)
        r = resolve_algorithm_alias(char(reg.algorithm_token(i)));
        names(i) = upper(string(r.internal_id));
    end
    names = unique(names, 'stable');
end

function write_version_notes(file_path, reg, cfg, result_dir)
    fid = fopen(file_path, 'w');
    if fid == -1
        error('Cannot write Route A family notes: %s', file_path);
    end
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# Route A Family Version Notes\n\n');
    fprintf(fid, '- suite: cec2017\n');
    fprintf(fid, '- func_ids: [%s]\n', strjoin(string(cfg.func_ids), ', '));
    fprintf(fid, '- maxFEs: %d\n', cfg.maxFEs);
    fprintf(fid, '- runs: %d\n', cfg.runs);
    fprintf(fid, '- dim: %d\n', cfg.dim);
    fprintf(fid, '- pop_size: %d\n\n', cfg.pop_size);

    fprintf(fid, '## Version List\n\n');
    fprintf(fid, '| version_id | token | entry_func | strategy_tag | note |\n');
    fprintf(fid, '| ---------- | ----- | ---------- | ------------ | ---- |\n');

    for i = 1:height(reg)
        fprintf(fid, '| %s | %s | %s | %s | %s |\n', ...
            reg.version_id(i), reg.algorithm_token(i), reg.entry_func(i), ...
            reg.strategy_tag(i), reg.version_note(i));
    end

    fprintf(fid, '\n## Output Files\n');
    fprintf(fid, '- %s\n', fullfile(result_dir, 'summary.csv'));
    fprintf(fid, '- %s\n', fullfile(result_dir, 'rank_table.csv'));
    fprintf(fid, '- %s\n', fullfile(result_dir, 'route_a_family_compare.csv'));
    fprintf(fid, '- %s\n', fullfile(result_dir, 'route_a_family_registry.csv'));
    fprintf(fid, '- %s\n', fullfile(result_dir, 'route_a_family_version_notes.md'));
end
