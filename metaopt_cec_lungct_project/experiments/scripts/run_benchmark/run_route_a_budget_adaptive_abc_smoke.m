function report = run_route_a_budget_adaptive_abc_smoke(cfg)
% run_route_a_budget_adaptive_abc_smoke
% Focused A/B/C smoke for Route A budget-adaptive branch on CEC2022.

    if nargin < 1
        cfg = struct();
    end
    cfg = fill_defaults(cfg);

    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    repo_root = fullfile(this_dir, '..', '..', '..');

    addpath(fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'entry'));
    addpath(fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'config'));

    reg = route_a_budget_adaptive_abc_registry();

    run_cfg = struct();
    run_cfg.mode = 'smoke';
    run_cfg.suites = {cfg.suite};
    run_cfg.algorithms = cellstr(reg.algorithm_token');
    run_cfg.dim = cfg.dim;
    run_cfg.pop_size = cfg.pop_size;
    run_cfg.maxFEs = cfg.maxFEs;
    run_cfg.rng_seed = cfg.rng_seed;
    run_cfg.result_root = cfg.result_root;
    run_cfg.result_group = fullfile('benchmark', 'route_a_budget_adaptive_abc');
    run_cfg.result_layout = 'suite_then_experiment';
    run_cfg.explicit_experiment_name = cfg.experiment_name;
    run_cfg.save_curve = cfg.save_curve;
    run_cfg.save_mat = cfg.save_mat;
    run_cfg.save_csv = cfg.save_csv;
    run_cfg.plot = struct('enable', false, 'show', false, 'save', false, 'formats', {{'png'}});

    if strcmpi(cfg.suite, 'cec2022')
        run_cfg.smoke = struct('runs', cfg.runs, 'func_ids', struct('cec2022', cfg.func_ids));
    else
        run_cfg.smoke = struct('runs', cfg.runs, 'func_ids', struct('cec2017', cfg.func_ids));
    end

    run_cfg.export = struct('summary_markdown', true);

    report = run_main_entry(run_cfg);

    suite_result = report.output.suite_results(1);
    result_dir = suite_result.result_dir;
    summary = suite_result.summary;

    fn_table = build_function_level_table(summary, reg);
    group_table = build_group_summary(fn_table);
    delta_table = build_delta_vs_a(fn_table, group_table);
    decision = build_decision(group_table, delta_table, cfg.decision);
    decision_table = build_decision_table(decision);

    registry_csv = fullfile(result_dir, 'route_a_budget_adaptive_abc_registry.csv');
    function_csv = fullfile(result_dir, 'route_a_budget_adaptive_abc_function_summary.csv');
    group_csv = fullfile(result_dir, 'route_a_budget_adaptive_abc_group_summary.csv');
    delta_csv = fullfile(result_dir, 'route_a_budget_adaptive_abc_delta_vs_A.csv');
    decision_csv = fullfile(result_dir, 'route_a_budget_adaptive_abc_decision_table.csv');
    note_md = fullfile(result_dir, 'route_a_budget_adaptive_abc_decision_note.md');

    writetable(reg, registry_csv);
    writetable(fn_table, function_csv);
    writetable(group_table, group_csv);
    writetable(delta_table, delta_csv);
    writetable(decision_table, decision_csv);
    write_decision_note(note_md, decision, cfg, suite_result, reg);

    report.route_a_budget_adaptive_abc = struct();
    report.route_a_budget_adaptive_abc.registry_csv = registry_csv;
    report.route_a_budget_adaptive_abc.function_csv = function_csv;
    report.route_a_budget_adaptive_abc.group_csv = group_csv;
    report.route_a_budget_adaptive_abc.delta_csv = delta_csv;
    report.route_a_budget_adaptive_abc.decision_csv = decision_csv;
    report.route_a_budget_adaptive_abc.decision_md = note_md;
    report.route_a_budget_adaptive_abc.decision = decision;

    disp(result_dir);
end

function cfg = fill_defaults(cfg)
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    repo_root = fullfile(this_dir, '..', '..', '..');
    addpath(fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'config'));

    profile = stage_profiles('route_a_budget_adaptive_abc_smoke');

    if ~isfield(cfg, 'suite') || strlength(string(cfg.suite)) == 0
        cfg.suite = profile.suite;
    end
    if ~isfield(cfg, 'func_ids') || isempty(cfg.func_ids)
        cfg.func_ids = profile.func_ids;
    end
    if ~isfield(cfg, 'maxFEs') || isempty(cfg.maxFEs)
        cfg.maxFEs = profile.maxFEs;
    end
    if isfield(cfg, 'use_long_budget') && logical(cfg.use_long_budget)
        cfg.maxFEs = profile.long_maxFEs;
    end
    if ~isfield(cfg, 'runs') || isempty(cfg.runs)
        cfg.runs = profile.smoke_runs;
    end
    if ~isfield(cfg, 'dim') || isempty(cfg.dim)
        cfg.dim = profile.dim;
    end
    if ~isfield(cfg, 'pop_size') || isempty(cfg.pop_size)
        cfg.pop_size = profile.pop_size;
    end
    if ~isfield(cfg, 'rng_seed') || isempty(cfg.rng_seed)
        cfg.rng_seed = profile.rng_seed;
    end
    if ~isfield(cfg, 'result_root') || strlength(string(cfg.result_root)) == 0
        cfg.result_root = 'results';
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
    if ~isfield(cfg, 'experiment_name') || strlength(string(cfg.experiment_name)) == 0
        cfg.experiment_name = sprintf('routeA_budget_adaptive_ABC_smoke_%s', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
    end

    if ~isfield(cfg, 'decision') || ~isstruct(cfg.decision)
        cfg.decision = struct();
    end
    if ~isfield(cfg.decision, 'require_f11_better')
        cfg.decision.require_f11_better = true;
    end
    if ~isfield(cfg.decision, 'composition_improve_min_count')
        cfg.decision.composition_improve_min_count = 2;
    end
    if ~isfield(cfg.decision, 'guard_worse_max_count')
        cfg.decision.guard_worse_max_count = 1;
    end
    if ~isfield(cfg.decision, 'std_explosion_ratio_limit')
        cfg.decision.std_explosion_ratio_limit = 0.20;
    end
end

function T = build_function_level_table(summary, reg)
    if ~istable(summary) || isempty(summary)
        T = table();
        return;
    end

    token_to_name = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for i = 1:height(reg)
        r = resolve_algorithm_alias(char(reg.algorithm_token(i)));
        token_to_name(char(reg.version_id(i))) = char(upper(string(r.internal_id)));
    end

    versions = string(keys(token_to_name));
    keep = false(height(summary), 1);
    vid = strings(height(summary), 1);
    for i = 1:numel(versions)
        v = versions(i);
        n = string(token_to_name(char(v)));
        m = strcmp(string(summary.algorithm_name), n);
        keep = keep | m;
        vid(m) = v;
    end

    rows = summary(keep, :);
    rows.version_id = vid(keep);
    rows.group_tag = map_group(rows.function_id);

    T = rows(:, {'version_id', 'algorithm_name', 'function_id', 'group_tag', 'best', 'mean', 'std', 'worst', 'median', 'avg_runtime'});
    T.func_rank = rank_by_function(T);
    T = sortrows(T, {'function_id', 'func_rank', 'mean'}, {'ascend', 'ascend', 'ascend'});
end

function group = map_group(fid)
    comp = ismember(fid, [10, 11, 12]);
    group = repmat("guard", numel(fid), 1);
    group(comp) = "composition";
end

function ranks = rank_by_function(T)
    ranks = zeros(height(T), 1);
    fids = unique(T.function_id, 'stable');
    for k = 1:numel(fids)
        m = T.function_id == fids(k);
        M = T.mean(m);
        [~, ord] = sort(M, 'ascend');
        r = zeros(sum(m), 1);
        r(ord) = 1:sum(m);
        ranks(m) = r;
    end
end

function G = build_group_summary(T)
    if isempty(T)
        G = table();
        return;
    end

    keys = unique(T(:, {'version_id', 'algorithm_name', 'group_tag'}), 'rows', 'stable');
    n = height(keys);
    G = keys;
    G.mean_of_mean = zeros(n, 1);
    G.mean_of_std = zeros(n, 1);
    G.mean_rank = zeros(n, 1);
    G.mean_runtime = zeros(n, 1);

    for i = 1:n
        m = strcmp(T.version_id, G.version_id(i)) & strcmp(T.group_tag, G.group_tag(i));
        S = T(m, :);
        G.mean_of_mean(i) = mean(S.mean);
        G.mean_of_std(i) = mean(S.std);
        G.mean_rank(i) = mean(S.func_rank);
        G.mean_runtime(i) = mean(S.avg_runtime);
    end

    G = sortrows(G, {'group_tag', 'mean_of_mean', 'mean_rank'}, {'ascend', 'ascend', 'ascend'});
end

function D = build_delta_vs_a(T, G)
    if isempty(T)
        D = table();
        return;
    end

    base_id = "A_BASELINE";

    fids = unique(T.function_id, 'stable');
    vids = unique(T.version_id, 'stable');

    rows = [];
    for i = 1:numel(vids)
        if vids(i) == base_id
            continue;
        end
        for k = 1:numel(fids)
            A = T(T.version_id == base_id & T.function_id == fids(k), :);
            B = T(T.version_id == vids(i) & T.function_id == fids(k), :);
            if isempty(A) || isempty(B)
                continue;
            end
            rows = [rows; {"function", vids(i), B.algorithm_name(1), string(fids(k)), string(B.group_tag(1)), ...
                B.mean(1) - A.mean(1), B.std(1) - A.std(1), B.func_rank(1) - A.func_rank(1)}]; %#ok<AGROW>
        end
    end

    groups = unique(string(G.group_tag), 'stable');
    for i = 1:numel(vids)
        if vids(i) == base_id
            continue;
        end
        for k = 1:numel(groups)
            A = G(G.version_id == base_id & G.group_tag == groups(k), :);
            B = G(G.version_id == vids(i) & G.group_tag == groups(k), :);
            if isempty(A) || isempty(B)
                continue;
            end
            rows = [rows; {"group", vids(i), B.algorithm_name(1), groups(k), groups(k), ...
                B.mean_of_mean(1) - A.mean_of_mean(1), B.mean_of_std(1) - A.mean_of_std(1), B.mean_rank(1) - A.mean_rank(1)}]; %#ok<AGROW>
        end
    end

    D = cell2table(rows, 'VariableNames', { ...
        'level', 'version_id', 'algorithm_name', 'target_id', 'group_tag', ...
        'delta_mean_vs_A', 'delta_std_vs_A', 'delta_rank_vs_A'});
end

function decision = build_decision(group_table, delta_table, cfg)
    decision = struct();
    decision.criteria = cfg;

    f11 = delta_table(delta_table.level == "function" & delta_table.target_id == "11", :);
    comp = delta_table(delta_table.level == "function" & delta_table.group_tag == "composition", :);
    guard = delta_table(delta_table.level == "function" & delta_table.group_tag == "guard", :);

    decision.by_version = struct();
    candidates = unique(string(delta_table.version_id), 'stable');
    best_score = -inf;
    best_version = "A_BASELINE";

    for i = 1:numel(candidates)
        v = candidates(i);
        fv11 = f11(f11.version_id == v, :);
        fcomp = comp(comp.version_id == v, :);
        fguard = guard(guard.version_id == v, :);

        gcomp = group_table(group_table.version_id == v & group_table.group_tag == "composition", :);
        aguard = group_table(group_table.version_id == "A_BASELINE" & group_table.group_tag == "guard", :);
        vguard = group_table(group_table.version_id == v & group_table.group_tag == "guard", :);
        acomp = group_table(group_table.version_id == "A_BASELINE" & group_table.group_tag == "composition", :);

        f11_ok = true;
        if cfg.require_f11_better
            f11_ok = ~isempty(fv11) && fv11.delta_mean_vs_A < 0;
        end

        comp_improve_count = sum(fcomp.delta_mean_vs_A < 0);
        comp_ok = comp_improve_count >= cfg.composition_improve_min_count;

        guard_worse_count = sum(fguard.delta_mean_vs_A > 0);
        guard_ok = guard_worse_count <= cfg.guard_worse_max_count;

        std_ok = true;
        if ~isempty(acomp) && ~isempty(gcomp)
            allow = cfg.std_explosion_ratio_limit * max(1.0, abs(acomp.mean_of_std(1)));
            std_ok = (gcomp.mean_of_std(1) - acomp.mean_of_std(1)) <= allow;
        end

        pass = f11_ok && comp_ok && guard_ok && std_ok;

        score = 0;
        if ~isempty(fcomp)
            score = score - mean(fcomp.delta_mean_vs_A);
        end
        if ~isempty(fguard)
            score = score - 0.5 * max(0, mean(fguard.delta_mean_vs_A));
        end
        if ~isempty(fv11)
            score = score - 1.2 * fv11.delta_mean_vs_A(1);
        end
        if ~isempty(aguard) && ~isempty(vguard)
            score = score - 0.2 * max(0, vguard.mean_of_mean(1) - aguard.mean_of_mean(1));
        end
        if ~pass
            score = score - 1000;
        end

        entry = struct();
        entry.version_id = char(v);
        entry.f11_ok = logical(f11_ok);
        entry.comp_improve_count = double(comp_improve_count);
        entry.comp_ok = logical(comp_ok);
        entry.guard_worse_count = double(guard_worse_count);
        entry.guard_ok = logical(guard_ok);
        entry.std_ok = logical(std_ok);
        entry.pass = logical(pass);
        entry.score = double(score);
        decision.by_version.(char(v)) = entry;

        if score > best_score
            best_score = score;
            best_version = v;
        end
    end

    decision.recommended_version = char(best_version);
    decision.recommended_score = double(best_score);
end

function T = build_decision_table(decision)
    fields = fieldnames(decision.by_version);
    n = numel(fields);
    T = table('Size', [n, 8], ...
        'VariableTypes', {'string', 'logical', 'logical', 'double', 'logical', 'double', 'logical', 'double'}, ...
        'VariableNames', {'version_id', 'pass', 'f11_ok', 'comp_improve_count', 'comp_ok', 'guard_worse_count', 'std_ok', 'score'});

    for i = 1:n
        x = decision.by_version.(fields{i});
        T.version_id(i) = string(x.version_id);
        T.pass(i) = logical(x.pass);
        T.f11_ok(i) = logical(x.f11_ok);
        T.comp_improve_count(i) = double(x.comp_improve_count);
        T.comp_ok(i) = logical(x.comp_ok);
        T.guard_worse_count(i) = double(x.guard_worse_count);
        T.std_ok(i) = logical(x.std_ok);
        T.score(i) = double(x.score);
    end

    T = sortrows(T, {'pass', 'score'}, {'descend', 'descend'});
end

function write_decision_note(file_path, decision, cfg, suite_result, reg)
    fid = fopen(file_path, 'w');
    if fid < 0
        warning('Failed to open decision note for write: %s', file_path);
        return;
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# Route A Budget-Adaptive A/B/C Decision Note\n\n');
    fprintf(fid, '- Type: behavior-focused smoke (A/B/C)\n');
    fprintf(fid, '- Suite: %s\n', cfg.suite);
    fprintf(fid, '- Functions: %s\n', mat2str(cfg.func_ids));
    fprintf(fid, '- runs: %d\n', cfg.runs);
    fprintf(fid, '- maxFEs: %d\n', cfg.maxFEs);
    if cfg.maxFEs >= 300000
        fprintf(fid, '- budget_mode: long\n');
    else
        fprintf(fid, '- budget_mode: smoke_default\n');
    end
    fprintf(fid, '- dim: %d\n', cfg.dim);
    fprintf(fid, '- pop_size: %d\n', cfg.pop_size);
    fprintf(fid, '- rng_seed: %d\n\n', cfg.rng_seed);

    fprintf(fid, '## Fairness & Protocol\n\n');
    fprintf(fid, '- Benchmark protocol remains unchanged; only algorithm variants differ.\n');
    fprintf(fid, '- This run is for mechanism diagnosis, not final performance claim.\n\n');

    fprintf(fid, '## Decision Criteria\n\n');
    fprintf(fid, '- F11 must improve vs A: %d\n', cfg.decision.require_f11_better);
    fprintf(fid, '- Composition improved count >= %d\n', cfg.decision.composition_improve_min_count);
    fprintf(fid, '- Guard worse count <= %d\n', cfg.decision.guard_worse_max_count);
    fprintf(fid, '- Std explosion ratio limit: %.3f\n\n', cfg.decision.std_explosion_ratio_limit);

    fprintf(fid, '## Variant Mapping\n\n');
    for i = 1:height(reg)
        fprintf(fid, '- %s => %s\n', reg.version_id(i), reg.algorithm_token(i));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Per-Variant Gate Result\n\n');
    fields = fieldnames(decision.by_version);
    for i = 1:numel(fields)
        x = decision.by_version.(fields{i});
        fprintf(fid, '- %s: pass=%d, f11_ok=%d, comp_improve_count=%d, guard_worse_count=%d, std_ok=%d, score=%.6g\n', ...
            x.version_id, x.pass, x.f11_ok, x.comp_improve_count, x.guard_worse_count, x.std_ok, x.score);
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Recommendation\n\n');
    fprintf(fid, '- Recommended: %s (score=%.6g)\n', decision.recommended_version, decision.recommended_score);
    fprintf(fid, '- Result dir: %s\n\n', suite_result.result_dir);

    fprintf(fid, '## Exported Decision Artifacts\n\n');
    fprintf(fid, '- route_a_budget_adaptive_abc_function_summary.csv\n');
    fprintf(fid, '- route_a_budget_adaptive_abc_group_summary.csv\n');
    fprintf(fid, '- route_a_budget_adaptive_abc_delta_vs_A.csv\n');
    fprintf(fid, '- route_a_budget_adaptive_abc_decision_table.csv\n\n');

    fprintf(fid, '## Notes\n\n');
    fprintf(fid, '- Algorithm behavior changes are isolated in improved/BBO variants.\n');
    fprintf(fid, '- Engineering governance changes in this smoke script are for reporting and decision traceability only.\n');
end
