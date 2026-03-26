function check = selfcheck_runner_integrity(cfg)
% selfcheck_runner_integrity
% Lightweight integrity check for cec_runner structure and protocol consistency.

    if nargin < 1
        cfg = struct();
    end
    if ~isfield(cfg, 'run_smoke')
        cfg.run_smoke = false;
    end

    this_file = mfilename('fullpath');
    tools_dir = fileparts(this_file);
    runner_dir = fileparts(tools_dir);
    repo_root = fullfile(runner_dir, '..', '..', '..', '..');

    addpath(fullfile(runner_dir, 'core'));
    addpath(fullfile(runner_dir, 'config'));
    addpath(fullfile(runner_dir, 'entry'));
    addpath(fullfile(runner_dir, 'pipeline_common'));

    checks = table();
    checks = append_check(checks, 'main_entry_exists', isfile(fullfile(runner_dir, 'entry', 'run_main_entry.m')), 'entry/run_main_entry.m must exist');

    impl1 = fileread(fullfile(runner_dir, 'pipeline_common', 'run_bbo_research_pipeline_impl.m'));
    impl2 = fileread(fullfile(runner_dir, 'pipeline_common', 'run_v3_direction_reduced_ablation_impl.m'));
    impl3 = fileread(fullfile(runner_dir, 'pipeline_common', 'run_v3_dual_objective_ablation_impl.m'));
    default_core_chain = contains(impl1, 'run_phase_via_core') && contains(impl2, 'run_phase_via_core') && contains(impl3, 'run_phase_via_core') ...
        && ~contains(impl1, 'run_all_compare(') && ~contains(impl2, 'run_all_compare(') && ~contains(impl3, 'run_all_compare(');
    checks = append_check(checks, 'pipeline_default_core', default_core_chain, 'Pipeline implementations should default to core entry and avoid direct run_all_compare calls');

    try
        dual = stage_profiles('v3_dual_ablation');
        suite_names = cellstr(string(dual.suites));
        smoke_fields = fieldnames(dual.smoke_func_ids);
        formal_fields = fieldnames(dual.formal_func_ids);
        profile_ok = isempty(setxor(suite_names, smoke_fields')) && isempty(setxor(suite_names, formal_fields'));
    catch
        profile_ok = false;
    end
    checks = append_check(checks, 'stage_profile_suite_consistency', profile_ok, 'stage_profiles suites and func_ids must align');

    cfg_defaults = default_experiment_config(struct());
    has_result_protocol = isfield(cfg_defaults, 'result_group') && isfield(cfg_defaults, 'result_layout');
    checks = append_check(checks, 'result_protocol_fields', has_result_protocol, 'default config should expose result_group/result_layout');

    collisions = check_path_collisions(struct('write_report', false));
    checks = append_check(checks, 'path_collision_scan_available', isfield(collisions, 'duplicate_table'), 'collision scan should return table');

    policy = rac_enforce_source_of_truth_policy(struct('throw_on_violation', false));
    checks = append_check(checks, 'source_of_truth_policy', policy.pass, 'raw package literals must stay inside rac_resolve_common_paths');

    rac_file = fullfile(runner_dir, 'core', 'rac_run_benchmark_kernel.m');
    rac_lines = count_lines(rac_file);
    slim_ok = rac_lines <= 1200;
    checks = append_check(checks, 'benchmark_kernel_slimming_progress', slim_ok, 'TODO(low-risk follow-up): continue split to core/private');

    smoke_ok = true;
    smoke_note = 'smoke skipped';
    if cfg.run_smoke
        try
            smoke_cfg = struct();
            smoke_cfg.mode = 'smoke';
            smoke_cfg.smoke = struct('runs', 1, 'func_ids', struct('cec2017', 1, 'cec2022', 1));
            smoke_cfg.plot = struct('enable', false, 'save', false, 'show', false, 'formats', {{'png'}});
            report = run_main_entry(smoke_cfg); %#ok<NASGU>
            smoke_note = 'smoke run completed';
        catch ME
            smoke_ok = false;
            smoke_note = ME.message;
        end
    end
    checks = append_check(checks, 'smoke_entry_path', smoke_ok, smoke_note);

    check = struct();
    check.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    check.repo_root = repo_root;
    check.checks = checks;
    check.pass = all(checks.pass);

    out_dir = fullfile(repo_root, 'logs', 'system');
    if ~isfolder(out_dir)
        mkdir(out_dir);
    end
    ts = datestr(now, 'yyyymmdd_HHMMSS');
    save(fullfile(out_dir, ['runner_integrity_' ts '.mat']), 'check');
    write_markdown(fullfile(out_dir, ['runner_integrity_' ts '.md']), check);
end

function T = append_check(T, name, pass, note)
    row = table(string(name), logical(pass), string(note), 'VariableNames', {'name', 'pass', 'note'});
    T = [T; row]; %#ok<AGROW>
end

function n = count_lines(file_path)
    txt = fileread(file_path);
    n = numel(regexp(txt, '\n', 'match')) + 1;
end

function write_markdown(file_path, check)
    fid = fopen(file_path, 'w');
    c = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# Runner Integrity Check\n\n');
    fprintf(fid, '- timestamp: %s\n', check.timestamp);
    fprintf(fid, '- pass: %d\n\n', check.pass);
    fprintf(fid, '| check | pass | note |\n');
    fprintf(fid, '| --- | :---: | --- |\n');
    for i = 1:height(check.checks)
        fprintf(fid, '| %s | %d | %s |\n', char(check.checks.name(i)), check.checks.pass(i), char(check.checks.note(i)));
    end
end
