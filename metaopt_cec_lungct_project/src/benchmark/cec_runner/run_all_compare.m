function output = run_all_compare(cfg)
% Unified multi-algorithm benchmark runner for CEC2017 and CEC2022.
% Minimal-intrusion wrapper: keep baseline optimizers unchanged.
%
% Usage:
%   run_all_compare();
%   run_all_compare(struct('suites',{{'cec2017','cec2022'}}, 'func_ids',1:5, 'runs',3));
%
% Budget policy:
%   maxFEs is the primary fairness budget for all algorithms.

    if nargin < 1
        cfg = struct();
    end

    cfg = fill_default_config(cfg);
    validate_config(cfg);

    paths = resolve_common_paths();
    suite_list = normalize_suite_list(cfg.suites);

    output = struct();
    output.suite_results = repmat(make_suite_output_template(), 1, 0);

    for s = 1:numel(suite_list)
        suite_name = suite_list{s};
        suite_api = build_suite_api(paths, suite_name);
        suite_cfg = derive_suite_cfg(cfg, suite_name);
        result_dir = init_result_dirs(paths.repo_root, suite_name, suite_cfg);

        suite_cfg.resolved_repo_root = paths.repo_root;
        suite_cfg.resolved_sbo_pack_root = paths.sbo_pack_root;
        suite_cfg.resolved_compat_dir = paths.compat_dir;
        suite_cfg.resolved_suite_dir = suite_api.suite_dir;
        suite_cfg.fe_counting_mode = 'counted_objective_wrapper';

        if suite_cfg.save_mat
            save(fullfile(result_dir.root, 'config.mat'), 'suite_cfg');
        end

        log_file = fullfile(result_dir.logs, 'run_log.txt');
        log_message(log_file, sprintf('Start experiment: %s', suite_cfg.experiment_name));
        log_message(log_file, sprintf('Suite: %s', suite_name));
        log_message(log_file, sprintf('Primary budget maxFEs: %d', suite_cfg.maxFEs));

        path_cleanup = setup_algorithm_paths(paths.compat_dir, suite_api.suite_dir);
        cleanup_obj = onCleanup(@() teardown_algorithm_paths(path_cleanup)); %#ok<NASGU>

        % CEC mex functions read input_data by relative path; run inside suite folder.
        old_dir = pwd;
        cd(suite_api.suite_dir);
        workdir_cleanup = onCleanup(@() cd(old_dir)); %#ok<NASGU>

        algorithm_inventory = build_algorithm_inventory(paths, suite_api, suite_cfg.algorithms, suite_cfg.maxFEs, suite_cfg.pop_size);
        save_algorithm_inventory(result_dir.root, algorithm_inventory, suite_cfg);
        log_algorithm_inventory(log_file, algorithm_inventory);

        selected_func_ids = resolve_function_ids_for_suite(suite_cfg.func_ids, suite_name);
        selected_func_ids = validate_func_ids_for_suite(selected_func_ids, suite_name);
        suite_cfg.plot = finalize_plot_config_for_suite(suite_cfg.plot, selected_func_ids, suite_cfg.algorithms);

        run_results = repmat(make_run_result_template(), 1, 0);
        run_manifest_rows = repmat(make_manifest_row_template(), 1, 0);
        run_idx = 0;
        manifest_idx = 0;

        for f = 1:numel(selected_func_ids)
            fid = selected_func_ids(f);
            [lb, ub, resolved_dim, fobj] = suite_api.get_function(fid, suite_cfg.dim);

            if resolved_dim ~= suite_cfg.dim
                log_message(log_file, sprintf('Function F%d overrides dim from %d to %d.', fid, suite_cfg.dim, resolved_dim));
            end

            current_dim = resolved_dim;

            for a = 1:numel(algorithm_inventory)
                alg = algorithm_inventory(a);
                if ~alg.is_runnable
                    log_message(log_file, sprintf('Skip %s on F%d: not runnable (%s).', alg.name, fid, alg.note));
                    continue;
                end

                alg_path_cleanup = setup_single_algorithm_path(alg.algorithm_dir);
                alg_cleanup_obj = onCleanup(@() teardown_single_algorithm_path(alg_path_cleanup)); %#ok<NASGU>

                log_message(log_file, sprintf('Running %s on F%d ...', alg.name, fid));

                for run_id = 1:suite_cfg.runs
                    run_seed = derive_run_seed(suite_cfg.rng_seed, s, f, a, run_id);
                    rng(run_seed, 'twister');

                    trace_request = make_plot_trace_request(suite_cfg.plot, alg.name, fid, current_dim);
                    [counted_fobj, get_fe_state] = make_counted_objective( ...
                        fobj, suite_cfg.maxFEs, suite_cfg.hard_stop_on_fe_limit, trace_request, suite_cfg.pop_size);

                    t0 = tic;
                    status = 'completed';
                    error_message = '';
                    try
                        [best_score, best_pos, curve, fe_control_mode, fe_note] = run_one_algorithm( ...
                            alg, suite_cfg.pop_size, suite_cfg.maxFEs, lb, ub, current_dim, counted_fobj);
                    catch ME
                        status = 'failed';
                        if strcmp(ME.identifier, 'CECRunner:MaxFEsReached')
                            status = 'stopped_at_budget';
                            fe_state = get_fe_state();
                            best_score = fe_state.best_score;
                            best_pos = fe_state.best_position;
                            curve = fe_state.best_curve;
                            [fe_control_mode, fe_note] = fe_mode_on_budget_stop(alg);
                            error_message = ME.message;
                        else
                            fe_state = get_fe_state();
                            best_score = fe_state.best_score;
                            best_pos = fe_state.best_position;
                            curve = fe_state.best_curve;
                            [fe_control_mode, fe_note] = fe_mode_on_runtime_error(alg);
                            error_message = ME.message;
                            log_message(log_file, sprintf('ERROR %s F%d run %d/%d: %s', alg.name, fid, run_id, suite_cfg.runs, ME.message));
                        end
                    end
                    runtime = toc(t0);

                    fe_state = get_fe_state();
                    used_fes = fe_state.used_FEs;

                    run_idx = run_idx + 1;
                    run_results(run_idx) = build_run_result( ...
                        alg.name, suite_name, fid, run_id, best_score, best_pos, curve, runtime, run_seed, ...
                        current_dim, suite_cfg.pop_size, suite_cfg.maxFEs, used_fes, fe_control_mode, fe_note, fe_state.behavior_trace);

                    save_single_run(result_dir, run_results(run_idx), suite_cfg);
                    if suite_cfg.save_curve
                        save_curve_file(result_dir, run_results(run_idx), suite_cfg);
                    end

                    manifest_idx = manifest_idx + 1;
                    run_manifest_rows(manifest_idx) = build_manifest_row( ...
                        alg.name, suite_name, fid, run_id, run_seed, suite_cfg.maxFEs, used_fes, ...
                        fe_control_mode, status, error_message); %#ok<AGROW>

                    log_message(log_file, sprintf('Done %s F%d run %d/%d: best=%.12g, used_FEs=%d/%d, t=%.4fs, mode=%s, status=%s', ...
                        alg.name, fid, run_id, suite_cfg.runs, best_score, used_fes, suite_cfg.maxFEs, runtime, fe_control_mode, status));
                end
            end
        end

        summary_table = build_summary_table(run_results);
        run_manifest = build_run_manifest_table(run_manifest_rows);

        save_summary(result_dir, summary_table, run_results, run_manifest, suite_cfg);

        % Plot generation is isolated after numeric outputs to avoid changing benchmark flow.
        generate_result_figures(run_results, summary_table, suite_cfg, result_dir, log_file);

        log_message(log_file, sprintf('Finished experiment: %s', suite_cfg.experiment_name));

        suite_output = struct();
        suite_output.suite = suite_name;
        suite_output.result_dir = result_dir.root;
        suite_output.summary = summary_table;
        suite_output.total_runs = numel(run_results);
        output.suite_results(end + 1) = suite_output; %#ok<AGROW>
    end
end

function cfg = fill_default_config(cfg)
    if ~isfield(cfg, 'suites')
        cfg.suites = {'cec2017', 'cec2022'};
    end
    if ~isfield(cfg, 'algorithms')
        cfg.algorithms = {'BBO', 'SBO', 'HGS', 'SMA', 'HHO', 'RUN', 'INFO', 'MGO', 'PLO', 'PO'};
    end
    if ~isfield(cfg, 'func_ids')
        cfg.func_ids = [];
    end
    if ~isfield(cfg, 'dim')
        cfg.dim = 10;
    end
    if ~isfield(cfg, 'pop_size')
        cfg.pop_size = 30;
    end
    if ~isfield(cfg, 'maxFEs')
        if isfield(cfg, 'max_fes')
            cfg.maxFEs = cfg.max_fes;
        else
            cfg.maxFEs = 3000;
        end
    end
    if ~isfield(cfg, 'runs')
        cfg.runs = 5;
    end
    if ~isfield(cfg, 'rng_seed')
        cfg.rng_seed = 20260313;
    end
    if ~isfield(cfg, 'experiment_name') || isempty(cfg.experiment_name)
        cfg.experiment_name = datestr(now, 'yyyymmdd_HHMMSS');
    end
    if ~isfield(cfg, 'result_root') || isempty(cfg.result_root)
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
    if ~isfield(cfg, 'hard_stop_on_fe_limit')
        cfg.hard_stop_on_fe_limit = true;
    end
    if ~isfield(cfg, 'plot') || ~isstruct(cfg.plot)
        cfg.plot = struct();
    end
    if ~isfield(cfg.plot, 'enable')
        if isfield(cfg, 'enable_plots')
            cfg.plot.enable = logical(cfg.enable_plots);
        else
            cfg.plot.enable = true;
        end
    end
    if ~isfield(cfg.plot, 'show')
        if isfield(cfg, 'show_plots')
            cfg.plot.show = logical(cfg.show_plots);
        else
            cfg.plot.show = false;
        end
    end
    if ~isfield(cfg.plot, 'save')
        if isfield(cfg, 'save_plots')
            cfg.plot.save = logical(cfg.save_plots);
        else
            cfg.plot.save = true;
        end
    end
    if ~isfield(cfg.plot, 'formats') || isempty(cfg.plot.formats)
        if isfield(cfg, 'plot_formats') && ~isempty(cfg.plot_formats)
            cfg.plot.formats = cfg.plot_formats;
        else
            cfg.plot.formats = {'png'};
        end
    end
    if ~isfield(cfg.plot, 'dpi')
        if isfield(cfg, 'plot_dpi')
            cfg.plot.dpi = cfg.plot_dpi;
        else
            cfg.plot.dpi = 200;
        end
    end
    if ~isfield(cfg.plot, 'tight')
        cfg.plot.tight = true;
    end
    if ~isfield(cfg.plot, 'close_after_save')
        cfg.plot.close_after_save = true;
    end
    if ~isfield(cfg.plot, 'overwrite')
        cfg.plot.overwrite = true;
    end
    if ~isfield(cfg.plot, 'selected_funcs')
        cfg.plot.selected_funcs = [];
    end
    if ~isfield(cfg.plot, 'selected_algorithms')
        cfg.plot.selected_algorithms = {};
    end
    if ~isfield(cfg.plot, 'subdir') || isempty(cfg.plot.subdir)
        if isfield(cfg, 'plot_subdir') && ~isempty(cfg.plot_subdir)
            cfg.plot.subdir = cfg.plot_subdir;
        else
            cfg.plot.subdir = 'figures';
        end
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
        cfg.plot.types.search_process_overview = true;
    end
    if ~isfield(cfg.plot.types, 'mean_fitness')
        cfg.plot.types.mean_fitness = true;
    end
    if ~isfield(cfg.plot.types, 'trajectory_first_dim')
        cfg.plot.types.trajectory_first_dim = true;
    end
    if ~isfield(cfg.plot.types, 'final_population')
        cfg.plot.types.final_population = true;
    end
    if ~isfield(cfg.plot, 'behavior') || ~isstruct(cfg.plot.behavior)
        cfg.plot.behavior = struct();
    end
    if ~isfield(cfg.plot.behavior, 'only_for_algorithms') || isempty(cfg.plot.behavior.only_for_algorithms)
        cfg.plot.behavior.only_for_algorithms = {'BBO'};
    end
    if ~isfield(cfg.plot.behavior, 'require_dim2')
        cfg.plot.behavior.require_dim2 = true;
    end
    if ~isfield(cfg.plot.behavior, 'max_funcs')
        cfg.plot.behavior.max_funcs = 3;
    end
    if ~isfield(cfg.plot, 'log_skipped')
        cfg.plot.log_skipped = true;
    end

    % Keep legacy flat fields populated for backward compatibility.
    cfg.enable_plots = cfg.plot.enable;
    cfg.show_plots = cfg.plot.show;
    cfg.save_plots = cfg.plot.save;
    cfg.plot_formats = cfg.plot.formats;
    cfg.plot_dpi = cfg.plot.dpi;
    cfg.plot_subdir = cfg.plot.subdir;
end

function validate_config(cfg)
    if cfg.pop_size <= 0 || cfg.maxFEs <= 0 || cfg.runs <= 0 || cfg.dim <= 0
        error('dim, pop_size, maxFEs, runs must be > 0.');
    end

    if any(mod(cfg.dim, 1) ~= 0) || any(mod(cfg.pop_size, 1) ~= 0) || any(mod(cfg.runs, 1) ~= 0)
        error('dim, pop_size, runs must be integers.');
    end

    suites = normalize_suite_list(cfg.suites);
    supported = {'cec2017', 'cec2022'};
    for i = 1:numel(suites)
        if ~any(strcmpi(suites{i}, supported))
            error('Unsupported suite: %s. Use cec2017 or cec2022.', suites{i});
        end
    end

    if ~isempty(cfg.func_ids) && isnumeric(cfg.func_ids)
        if any(cfg.func_ids < 1) || any(mod(cfg.func_ids, 1) ~= 0)
            error('func_ids must be positive integer ids.');
        end
    end

    if ~isstruct(cfg.plot)
        error('cfg.plot must be a struct.');
    end
    if cfg.plot.dpi <= 0
        error('cfg.plot.dpi must be > 0.');
    end
    if cfg.plot.behavior.max_funcs <= 0 || mod(cfg.plot.behavior.max_funcs, 1) ~= 0
        error('cfg.plot.behavior.max_funcs must be a positive integer.');
    end
end

function suites = normalize_suite_list(suites_in)
    if ischar(suites_in)
        suites = {lower(suites_in)};
        return;
    end
    if isstring(suites_in)
        suites = cellstr(lower(suites_in(:)'));
        return;
    end
    if iscell(suites_in)
        suites = cell(size(suites_in));
        for i = 1:numel(suites_in)
            suites{i} = lower(string(suites_in{i}));
            suites{i} = char(suites{i});
        end
        return;
    end
    error('suites must be char/string/cellstr.');
end

function paths = resolve_common_paths()
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);

    paths = struct();
    paths.repo_root = fullfile(this_dir, '..', '..', '..');

    paths.sbo_pack_root = fullfile(paths.repo_root, 'src', 'baselines', 'metaheuristics', 'SBO', ...
        'Status_based_Optimization_SBO_MATLAB_codes_extracted');
    paths.compat_dir = fullfile(paths.repo_root, 'src', 'benchmark', 'cec_runner', 'compat');
    paths.bbo_root = fullfile(paths.repo_root, 'src', 'baselines', 'metaheuristics', 'BBO', ...
        'Source_code_BBO_MATLAB_VERSION_extracted', 'Source_code_BBO_MATLAB_VERSION');
    paths.improved_bbo_root = fullfile(paths.repo_root, 'src', 'improved', 'algorithms', 'BBO');

    if ~isfolder(paths.sbo_pack_root)
        error('SBO package root folder not found: %s', paths.sbo_pack_root);
    end
    if ~isfolder(paths.compat_dir)
        error('Compatibility folder not found: %s', paths.compat_dir);
    end
    if ~isfolder(paths.bbo_root)
        error('BBO root folder not found: %s', paths.bbo_root);
    end
end

function suite_api = build_suite_api(paths, suite_name)
    suite_api = struct();
    suite_api.name = suite_name;

    if strcmpi(suite_name, 'cec2017')
        suite_api.suite_dir = fullfile(paths.bbo_root, 'CEC2017');
        suite_api.get_function = @get_cec2017_function;
        suite_api.default_func_ids = 1:30;
    else
        suite_api.suite_dir = fullfile(paths.bbo_root, 'CEC2022');
        suite_api.get_function = @get_cec2022_function;
        suite_api.default_func_ids = 1:12;
    end

    if ~isfolder(suite_api.suite_dir)
        error('Suite folder not found: %s', suite_api.suite_dir);
    end
end

function suite_cfg = derive_suite_cfg(cfg, suite_name)
    suite_cfg = cfg;
    suite_cfg.suite = suite_name;
end

function ids = resolve_function_ids_for_suite(func_ids_cfg, suite_name)
    if isstruct(func_ids_cfg)
        if isfield(func_ids_cfg, suite_name)
            ids = func_ids_cfg.(suite_name);
            return;
        end
        if isfield(func_ids_cfg, 'all')
            ids = func_ids_cfg.all;
            return;
        end
        error('func_ids struct must contain field "%s" or "all".', suite_name);
    end

    if isempty(func_ids_cfg)
        if strcmpi(suite_name, 'cec2017')
            ids = 1:30;
        else
            ids = 1:12;
        end
        return;
    end

    ids = func_ids_cfg;
end

function ids = validate_func_ids_for_suite(ids, suite_name)
    if isempty(ids)
        error('Resolved function ids are empty.');
    end

    if any(ids < 1) || any(mod(ids, 1) ~= 0)
        error('func_ids must be positive integer ids.');
    end

    if strcmpi(suite_name, 'cec2017') && any(ids > 30)
        error('cec2017 supports function ids in [1, 30].');
    end

    if strcmpi(suite_name, 'cec2022') && any(ids > 12)
        error('cec2022 supports function ids in [1, 12].');
    end

    ids = unique(ids, 'stable');
end

function path_state = setup_algorithm_paths(compat_dir, suite_dir)
    path_state = {};

    addpath(compat_dir);
    path_state{end + 1} = compat_dir;

    addpath(suite_dir);
    path_state{end + 1} = suite_dir;
end

function p = setup_single_algorithm_path(algorithm_dir)
    if ~is_path_entry_active(algorithm_dir)
        addpath(algorithm_dir);
    end
    p = algorithm_dir;
end

function teardown_single_algorithm_path(algorithm_dir)
    if isfolder(algorithm_dir) && is_path_entry_active(algorithm_dir)
        rmpath(algorithm_dir);
    end
end

function teardown_algorithm_paths(path_state)
    for i = 1:numel(path_state)
        if isfolder(path_state{i}) && is_path_entry_active(path_state{i})
            rmpath(path_state{i});
        end
    end
end

function tf = is_path_entry_active(target_dir)
    current_parts = strsplit(path, pathsep);
    tf = any(strcmpi(current_parts, target_dir));
end

function [lb, ub, dim, fobj] = get_cec2017_function(fid, dim)
    % Keep the original calling chain, but self-heal MATLAB path when session state is dirty.
    if exist('Get_Functions_cec2017', 'file') ~= 2
        ensure_suite_getter_on_path('cec2017');
    end
    suite_dir = resolve_suite_dir('cec2017');
    [lb, ub, dim, raw_fobj] = call_getter_in_suite_dir(@() Get_Functions_cec2017(fid, dim), suite_dir);
    fobj = @(x) eval_objective_in_suite_dir(raw_fobj, suite_dir, x);
end

function [lb, ub, dim, fobj] = get_cec2022_function(fid, dim)
    % Keep the original calling chain, but self-heal MATLAB path when session state is dirty.
    if exist('Get_Functions_cec2022', 'file') ~= 2
        ensure_suite_getter_on_path('cec2022');
    end
    suite_dir = resolve_suite_dir('cec2022');
    [lb, ub, dim, raw_fobj] = call_getter_in_suite_dir(@() Get_Functions_cec2022(fid, dim), suite_dir);
    fobj = @(x) eval_objective_in_suite_dir(raw_fobj, suite_dir, x);
end

function suite_dir = resolve_suite_dir(suite_name)
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    repo_root = fullfile(this_dir, '..', '..', '..');
    bbo_root = fullfile(repo_root, 'src', 'baselines', 'metaheuristics', 'BBO', ...
        'Source_code_BBO_MATLAB_VERSION_extracted', 'Source_code_BBO_MATLAB_VERSION');

    if strcmpi(suite_name, 'cec2017')
        suite_dir = fullfile(bbo_root, 'CEC2017');
    else
        suite_dir = fullfile(bbo_root, 'CEC2022');
    end

    if ~isfolder(suite_dir)
        error('Suite folder not found while resolving suite dir: %s', suite_dir);
    end
end

function [lb, ub, dim, fobj] = call_getter_in_suite_dir(getter_fn, suite_dir)
    old_dir = pwd;
    cd(suite_dir);
    cleanup_obj = onCleanup(@() cd(old_dir)); %#ok<NASGU>
    [lb, ub, dim, fobj] = getter_fn();
end

function value = eval_objective_in_suite_dir(raw_fobj, suite_dir, x)
    old_dir = pwd;
    cd(suite_dir);
    cleanup_obj = onCleanup(@() cd(old_dir)); %#ok<NASGU>
    value = raw_fobj(x);
end

function ensure_suite_getter_on_path(suite_name)
    suite_dir = resolve_suite_dir(suite_name);

    if isfolder(suite_dir)
        addpath(suite_dir);
    else
        error('Suite folder not found while repairing path: %s', suite_dir);
    end
end

function inventory = build_algorithm_inventory(paths, suite_api, selected_algorithms, maxFEs, pop_size)
    catalog = get_algorithm_catalog(paths, suite_api);
    alg_list = cellstr(string(selected_algorithms));

    template = struct('name', '', 'entry_name', '', 'algorithm_dir', '', ...
        'budget_arg', '', 'output_mode', '', 'is_runnable', false, ...
        'fe_control_mode', '', 'note', '');
    inventory = repmat(template, 1, numel(alg_list));

    for i = 1:numel(alg_list)
        name = upper(strtrim(alg_list{i}));
        record = template;
        record.name = name;

        idx = find(strcmp({catalog.name}, name), 1, 'first');
        if isempty(idx)
            record.fe_control_mode = 'not_supported';
            record.note = 'No wrapper implemented in run_all_compare yet.';
            inventory(i) = record;
            continue;
        end

        spec = catalog(idx);
        record.entry_name = spec.entry_name;
        record.algorithm_dir = spec.algorithm_dir;
        record.budget_arg = spec.budget_arg;
        record.output_mode = spec.output_mode;

        entry_file = fullfile(spec.algorithm_dir, [spec.entry_name '.m']);
        record.is_runnable = isfolder(spec.algorithm_dir) && isfile(entry_file);

        if strcmp(spec.budget_arg, 'maxFEs')
            record.fe_control_mode = 'exact_fes_parameter';
            record.note = sprintf('%s uses MaxFEs directly; counted wrapper records used_FEs.', spec.entry_name);
        else
            [max_iter, used_est] = estimate_iteration_budget(pop_size, maxFEs);
            if used_est == maxFEs
                record.fe_control_mode = 'exact_derived_iteration_from_maxFEs';
                record.note = sprintf('%s uses iteration budget; derived Max_iteration=%d gives exact used_FEs=%d.', spec.entry_name, max_iter, used_est);
            else
                record.fe_control_mode = 'approx_derived_iteration_from_maxFEs';
                record.note = sprintf('%s uses iteration budget; derived Max_iteration=%d gives used_FEs=%d (< maxFEs=%d).', spec.entry_name, max_iter, used_est, maxFEs);
            end
        end

        inventory(i) = record;
    end
end

function catalog = get_algorithm_catalog(paths, suite_api)
    sbo_root = paths.sbo_pack_root;
    improved_bbo_root = paths.improved_bbo_root;
    c = struct('name', '', 'entry_name', '', 'algorithm_dir', '', 'budget_arg', '', 'output_mode', '');
    catalog = repmat(c, 1, 0);

    % Baseline BBO is kept untouched. BBO_BASE is an explicit alias used by pipeline scripts.
    catalog(end + 1) = make_algorithm_spec('BBO_BASE', 'BBO', suite_api.suite_dir, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('BBO', 'BBO', suite_api.suite_dir, 'max_iter', 'score_pos_curve'); %#ok<AGROW>

    % Versioned improved BBO variants for ablation and iterative research.
    catalog(end + 1) = make_algorithm_spec('BBO_IMPROVED_V1', 'BBO_improved_v1', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('BBO_IMPROVED_V2', 'BBO_improved_v2', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('BBO_IMPROVED_V3', 'BBO_improved_v3', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('BBO_IMPROVED_V4', 'BBO_improved_v4', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>

    % Dual-objective v3 ablation family: simple-function acceleration + conditional directional modules.
    catalog(end + 1) = make_algorithm_spec('V3_BASELINE', 'BBO_v3_baseline', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('V3_FAST_SIMPLE_A', 'BBO_v3_fast_simple_A', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('V3_FAST_SIMPLE_B', 'BBO_v3_fast_simple_B', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('V3_DIR_LATE', 'BBO_v3_dir_late', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('V3_DIR_STAGNATION', 'BBO_v3_dir_stagnation', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('V3_DIR_ELITE_ONLY', 'BBO_v3_dir_elite_only', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('V3_DIR_SMALL_STEP', 'BBO_v3_dir_small_step', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('V3_DIR_SMALL_STEP_LATE_LOCAL_REFINE', 'BBO_v3_dir_small_step_late_local_refine', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('V3_DIR_SMALL_STEP_GATE_LATE_LOCAL_REFINE', 'BBO_v3_dir_small_step_gate_late_local_refine', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('V3_DIR_STAG_ONLY', 'BBO_v3_dir_stag_only', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('V3_DIR_STAG_BOTTOM_HALF', 'BBO_v3_dir_stag_bottom_half', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('V3_DIR_STAG_BOTTOM_HALF_LATE_REFINE', 'BBO_v3_dir_stag_bottom_half_late_refine', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('V3_DIR_CLIPPED_STAG_BOTTOM_HALF_LATE_REFINE', 'BBO_v3_dir_clipped_stag_bottom_half_late_refine', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('V3_HYBRID_A_DIR_STAG', 'BBO_v3_hybrid_A_dir_stag', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('V3_HYBRID_B_DIR_SMALL', 'BBO_v3_hybrid_B_dir_small', improved_bbo_root, 'max_iter', 'score_pos_curve'); %#ok<AGROW>

    catalog(end + 1) = make_algorithm_spec('SBO', 'SBO', fullfile(sbo_root, 'Status-based Optimization (SBO)-2025'), 'maxFEs', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('HGS', 'HGS', fullfile(sbo_root, 'Hunger Games Search (HGS)-2021'), 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('SMA', 'SMA', fullfile(sbo_root, 'Slime mould algorithm (SMA)-2020'), 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('HHO', 'HHO', fullfile(sbo_root, 'Harris Hawk Optimization (HHO)-2019'), 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('RUN', 'RUN', fullfile(sbo_root, 'Runge Kutta Optimization (RUN)-2021'), 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('INFO', 'INFO', fullfile(sbo_root, 'Weighted Mean of Vectors (INFO)-2022'), 'max_iter', 'score_pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('MGO', 'MGO', fullfile(sbo_root, 'Moss Growth Optimization (MGO)-2024'), 'maxFEs', 'pos_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('PLO', 'PLO', fullfile(sbo_root, 'Polar Lights Optimizer (PLO)-2024'), 'maxFEs', 'pos_score_curve'); %#ok<AGROW>
    catalog(end + 1) = make_algorithm_spec('PO', 'PO', fullfile(sbo_root, 'Parrot Optimizer (PO)-2024'), 'max_iter', 'po'); %#ok<AGROW>
end

function s = make_algorithm_spec(name, entry_name, algorithm_dir, budget_arg, output_mode)
    s = struct();
    s.name = name;
    s.entry_name = entry_name;
    s.algorithm_dir = algorithm_dir;
    s.budget_arg = budget_arg;
    s.output_mode = output_mode;
end

function save_algorithm_inventory(result_root, inventory, cfg)
    table_rows = table();
    for i = 1:numel(inventory)
        row = table(string(inventory(i).name), logical(inventory(i).is_runnable), ...
            string(inventory(i).entry_name), string(inventory(i).algorithm_dir), ...
            string(inventory(i).budget_arg), string(inventory(i).fe_control_mode), string(inventory(i).note), ...
            'VariableNames', {'algorithm_name','is_runnable','entry_name','algorithm_dir','budget_arg','fe_control_mode','note'});
        table_rows = [table_rows; row]; %#ok<AGROW>
    end

    if cfg.save_csv
        writetable(table_rows, fullfile(result_root, 'algorithm_inventory.csv'));
    end

    if cfg.save_mat
        save(fullfile(result_root, 'algorithm_inventory.mat'), 'table_rows', 'inventory');
    end
end

function log_algorithm_inventory(log_file, inventory)
    for i = 1:numel(inventory)
        log_message(log_file, sprintf('Algorithm %s | runnable=%d | entry=%s | budget=%s | fe_mode=%s | note=%s', ...
            inventory(i).name, inventory(i).is_runnable, inventory(i).entry_name, inventory(i).budget_arg, inventory(i).fe_control_mode, inventory(i).note));
    end
end

function [counted_fobj, get_fe_state] = make_counted_objective(base_fobj, maxFEs, hard_stop_on_fe_limit, trace_request, pop_size)
    used_FEs = 0;
    best_score = inf;
    best_position = [];
    best_curve = [];
    behavior_trace = make_behavior_trace_template();
    batch_sum = 0;
    batch_count = 0;
    ring_buffer = [];
    ring_count = 0;
    ring_cursor = 0;

    if nargin < 4 || isempty(trace_request)
        trace_request = make_trace_request_template();
    end
    if nargin < 5 || isempty(pop_size)
        pop_size = 1;
    end

    if trace_request.enable
        behavior_trace.captured = true;
        behavior_trace.capture_mode = 'evaluation_batch_proxy';
        behavior_trace.note = 'Behavior curves are lightweight proxies from objective-call batches; benchmark metrics remain unchanged.';
        if trace_request.capture_final_population
            ring_buffer = nan(pop_size, trace_request.position_dims);
        end
    end

    function y = counted_fobj_impl(x)
        if hard_stop_on_fe_limit && used_FEs >= maxFEs
            error('CECRunner:MaxFEsReached', 'Reached maxFEs=%d, objective evaluation is stopped.', maxFEs);
        end

        used_FEs = used_FEs + 1;
        y = base_fobj(x);

        if y < best_score
            best_score = y;
            best_position = x;
        end

        best_curve(end + 1) = best_score; %#ok<AGROW>

        if trace_request.enable
            batch_sum = batch_sum + y;
            batch_count = batch_count + 1;

            if trace_request.capture_final_population
                ring_cursor = ring_cursor + 1;
                if ring_cursor > pop_size
                    ring_cursor = 1;
                end
                ring_count = min(ring_count + 1, pop_size);
                ring_buffer(ring_cursor, :) = x(1:trace_request.position_dims);
            end

            if batch_count >= pop_size
                behavior_trace.mean_fitness_curve(end + 1) = batch_sum / batch_count; %#ok<AGROW>
                if ~isempty(best_position)
                    behavior_trace.trajectory_first_dim(end + 1) = best_position(1); %#ok<AGROW>
                else
                    behavior_trace.trajectory_first_dim(end + 1) = nan; %#ok<AGROW>
                end
                batch_sum = 0;
                batch_count = 0;
            end
        end
    end

    function state = get_state_impl()
        state = struct();
        state.used_FEs = used_FEs;
        state.best_score = best_score;
        state.best_position = best_position;
        state.best_curve = best_curve;
        state.behavior_trace = finalize_behavior_trace(behavior_trace, batch_sum, batch_count, best_position, ring_buffer, ring_count, ring_cursor);
    end

    counted_fobj = @counted_fobj_impl;
    get_fe_state = @get_state_impl;
end

function [best_score, best_pos, curve, fe_control_mode, fe_note] = run_one_algorithm(alg, pop_size, maxFEs, lb, ub, dim, fobj)
    if strcmp(alg.budget_arg, 'maxFEs')
        budget_value = maxFEs;
    else
        [budget_value, used_est] = estimate_iteration_budget(pop_size, maxFEs);
    end

    if strcmp(alg.output_mode, 'score_pos_curve')
        [best_score, best_pos, curve] = feval(alg.entry_name, pop_size, budget_value, lb, ub, dim, fobj);
    elseif strcmp(alg.output_mode, 'pos_score_curve')
        [best_pos, best_score, curve] = feval(alg.entry_name, pop_size, budget_value, lb, ub, dim, fobj);
    elseif strcmp(alg.output_mode, 'score_curve')
        [best_score, curve] = feval(alg.entry_name, pop_size, budget_value, lb, ub, dim, fobj);
        best_pos = [];
    elseif strcmp(alg.output_mode, 'pos_curve')
        [best_pos, curve] = feval(alg.entry_name, pop_size, budget_value, lb, ub, dim, fobj);
        if isempty(curve)
            best_score = inf;
        else
            best_score = curve(end);
        end
    elseif strcmp(alg.output_mode, 'po')
        [~, best_pos, best_score, curve, ~, ~] = feval(alg.entry_name, pop_size, budget_value, lb, ub, dim, fobj);
    else
        error('Unsupported output mode %s for algorithm %s.', alg.output_mode, alg.name);
    end

    if strcmp(alg.budget_arg, 'maxFEs')
        fe_control_mode = 'exact_fes_parameter';
        fe_note = sprintf('%s uses MaxFEs directly.', alg.entry_name);
    else
        if used_est == maxFEs
            fe_control_mode = 'exact_derived_iteration_from_maxFEs';
            fe_note = sprintf('%s Max_iteration=%d maps to exact used_FEs=%d.', alg.entry_name, budget_value, used_est);
        else
            fe_control_mode = 'approx_derived_iteration_from_maxFEs';
            fe_note = sprintf('%s Max_iteration=%d maps to used_FEs=%d (< maxFEs=%d).', alg.entry_name, budget_value, used_est, maxFEs);
        end
    end
end

function [max_iter, used_fes_est] = estimate_iteration_budget(pop_size, maxFEs)
    % Conservative FE-to-iteration estimate for iteration-budget algorithms.
    if maxFEs < pop_size
        max_iter = 0;
        used_fes_est = pop_size;
        return;
    end

    max_iter = floor((maxFEs - pop_size) / pop_size);
    if max_iter < 1
        max_iter = 1;
    end

    used_fes_est = pop_size + max_iter * pop_size;
end

function [fe_mode, fe_note] = fe_mode_on_budget_stop(alg)
    fe_mode = sprintf('%s_with_hard_stop', alg.fe_control_mode);
    fe_note = 'Counted objective wrapper stopped the run exactly at maxFEs.';
end

function [fe_mode, fe_note] = fe_mode_on_runtime_error(alg)
    fe_mode = sprintf('%s_with_runtime_error', alg.fe_control_mode);
    fe_note = 'Run ended with runtime error; output uses tracked FE state before failure.';
end

function run_result = build_run_result(algorithm_name, suite_name, function_id, run_id, ...
    best_score, best_position, convergence_curve, runtime, seed, dimension, population_size, maxFEs, used_FEs, fe_control_mode, fe_note, behavior_trace)

    run_result = struct();
    run_result.algorithm_name = algorithm_name;
    run_result.suite = suite_name;
    run_result.function_id = function_id;
    run_result.run_id = run_id;
    run_result.best_score = best_score;
    run_result.best_position = best_position;
    run_result.convergence_curve = convergence_curve;
    run_result.runtime = runtime;
    run_result.seed = seed;
    run_result.dimension = dimension;
    run_result.population_size = population_size;
    run_result.maxFEs = maxFEs;
    run_result.used_FEs = used_FEs;
    run_result.fe_control_mode = fe_control_mode;
    run_result.fe_control_note = fe_note;
    run_result.behavior_trace = behavior_trace;
end

function manifest_row = build_manifest_row(algorithm_name, suite_name, function_id, run_id, seed, maxFEs, used_FEs, fe_control_mode, status, error_message)
    manifest_row = struct();
    manifest_row.algorithm_name = algorithm_name;
    manifest_row.suite = suite_name;
    manifest_row.function_id = function_id;
    manifest_row.run_id = run_id;
    manifest_row.seed = seed;
    manifest_row.maxFEs = maxFEs;
    manifest_row.used_FEs = used_FEs;
    manifest_row.fe_control_mode = fe_control_mode;
    manifest_row.status = status;
    manifest_row.error_message = error_message;
end

function result_dir = init_result_dirs(repo_root, suite_name, cfg)
    root = fullfile(repo_root, cfg.result_root, lower(suite_name), cfg.experiment_name);

    result_dir = struct();
    result_dir.root = root;
    result_dir.tables = fullfile(root, 'tables');
    result_dir.raw_runs = fullfile(root, 'raw_runs');
    result_dir.curves = fullfile(root, 'curves');
    result_dir.logs = fullfile(root, 'logs');
    result_dir.figures = fullfile(root, cfg.plot.subdir);

    if ~isfolder(root)
        mkdir(root);
    end
    if ~isfolder(result_dir.tables)
        mkdir(result_dir.tables);
    end
    if ~isfolder(result_dir.raw_runs)
        mkdir(result_dir.raw_runs);
    end
    if ~isfolder(result_dir.curves)
        mkdir(result_dir.curves);
    end
    if ~isfolder(result_dir.logs)
        mkdir(result_dir.logs);
    end
    if ~isfolder(result_dir.figures)
        mkdir(result_dir.figures);
    end
end

function save_single_run(result_dir, run_result, cfg)
    if ~cfg.save_mat
        return;
    end

    file_name = sprintf('%s_F%d_run%03d.mat', ...
        lower(run_result.algorithm_name), run_result.function_id, run_result.run_id);
    save(fullfile(result_dir.raw_runs, file_name), 'run_result');
end

function save_curve_file(result_dir, run_result, cfg)
    curve = run_result.convergence_curve;

    if cfg.save_mat
        mat_name = sprintf('%s_F%d_run%03d_curve.mat', ...
            lower(run_result.algorithm_name), run_result.function_id, run_result.run_id);
        save(fullfile(result_dir.curves, mat_name), 'curve');
    end

    if cfg.save_csv
        csv_name = sprintf('%s_F%d_run%03d_curve.csv', ...
            lower(run_result.algorithm_name), run_result.function_id, run_result.run_id);
        writematrix(curve(:), fullfile(result_dir.curves, csv_name));
    end
end

function summary_table = build_summary_table(run_results)
    if isempty(run_results)
        summary_table = table();
        return;
    end

    algs = unique(string({run_results.algorithm_name}));
    fids = unique([run_results.function_id]);

    rows = table();
    for i = 1:numel(algs)
        for j = 1:numel(fids)
            idx = strcmp({run_results.algorithm_name}, char(algs(i))) & [run_results.function_id] == fids(j);
            subset = run_results(idx);
            if isempty(subset)
                continue;
            end

            scores = [subset.best_score];
            runtimes = [subset.runtime];
            used_fes = [subset.used_FEs];

            row = table( ...
                string(algs(i)), ...
                fids(j), ...
                min(scores), ...
                mean(scores), ...
                std(scores), ...
                max(scores), ...
                median(scores), ...
                mean(runtimes), ...
                mean(used_fes), ...
                'VariableNames', {'algorithm_name','function_id','best','mean','std','worst','median','avg_runtime','avg_used_FEs'});

            rows = [rows; row]; %#ok<AGROW>
        end
    end

    summary_table = rows;
end

function run_manifest = build_run_manifest_table(manifest_rows)
    if isempty(manifest_rows)
        run_manifest = table();
        return;
    end

    run_manifest = table( ...
        string({manifest_rows.algorithm_name})', ...
        string({manifest_rows.suite})', ...
        [manifest_rows.function_id]', ...
        [manifest_rows.run_id]', ...
        [manifest_rows.seed]', ...
        [manifest_rows.maxFEs]', ...
        [manifest_rows.used_FEs]', ...
        string({manifest_rows.fe_control_mode})', ...
        string({manifest_rows.status})', ...
        string({manifest_rows.error_message})', ...
        'VariableNames', {'algorithm_name','suite','function_id','run_id','seed','maxFEs','used_FEs','fe_control_mode','status','error_message'});
end

function save_summary(result_dir, summary_table, run_results, run_manifest, cfg)
    if cfg.save_csv
        writetable(summary_table, fullfile(result_dir.root, 'summary.csv'));
        writetable(run_manifest, fullfile(result_dir.root, 'run_manifest.csv'));
        writetable(summary_table, fullfile(result_dir.tables, 'summary.csv'));
        writetable(run_manifest, fullfile(result_dir.tables, 'run_manifest.csv'));
    end

    if cfg.save_mat
        save(fullfile(result_dir.root, 'summary.mat'), 'summary_table', 'run_results', 'run_manifest');
        save(fullfile(result_dir.tables, 'summary.mat'), 'summary_table', 'run_results', 'run_manifest');
    end
end

function seed = derive_run_seed(base_seed, suite_idx, func_idx, alg_idx, run_id)
    seed = base_seed + (suite_idx - 1) * 10000000 + (func_idx - 1) * 100000 + (alg_idx - 1) * 1000 + run_id;
end

function tpl = make_run_result_template()
    tpl = struct();
    tpl.algorithm_name = '';
    tpl.suite = '';
    tpl.function_id = 0;
    tpl.run_id = 0;
    tpl.best_score = inf;
    tpl.best_position = [];
    tpl.convergence_curve = [];
    tpl.runtime = 0;
    tpl.seed = 0;
    tpl.dimension = 0;
    tpl.population_size = 0;
    tpl.maxFEs = 0;
    tpl.used_FEs = 0;
    tpl.fe_control_mode = '';
    tpl.fe_control_note = '';
    tpl.behavior_trace = make_behavior_trace_template();
end

function tpl = make_manifest_row_template()
    tpl = struct();
    tpl.algorithm_name = '';
    tpl.suite = '';
    tpl.function_id = 0;
    tpl.run_id = 0;
    tpl.seed = 0;
    tpl.maxFEs = 0;
    tpl.used_FEs = 0;
    tpl.fe_control_mode = '';
    tpl.status = '';
    tpl.error_message = '';
end

function tpl = make_suite_output_template()
    tpl = struct();
    tpl.suite = '';
    tpl.result_dir = '';
    tpl.summary = table();
    tpl.total_runs = 0;
end

function trace_tpl = make_behavior_trace_template()
    trace_tpl = struct();
    trace_tpl.captured = false;
    trace_tpl.capture_mode = '';
    trace_tpl.note = '';
    trace_tpl.mean_fitness_curve = [];
    trace_tpl.trajectory_first_dim = [];
    trace_tpl.final_population = [];
end

function trace_request = make_trace_request_template()
    trace_request = struct();
    trace_request.enable = false;
    trace_request.capture_mean_fitness = false;
    trace_request.capture_first_dim = false;
    trace_request.capture_final_population = false;
    trace_request.position_dims = 0;
end

function trace = finalize_behavior_trace(trace, batch_sum, batch_count, best_position, ring_buffer, ring_count, ring_cursor)
    if ~trace.captured
        return;
    end

    if batch_count > 0
        trace.mean_fitness_curve(end + 1) = batch_sum / batch_count; %#ok<AGROW>
        if ~isempty(best_position)
            trace.trajectory_first_dim(end + 1) = best_position(1); %#ok<AGROW>
        else
            trace.trajectory_first_dim(end + 1) = nan; %#ok<AGROW>
        end
    end

    if ~isempty(ring_buffer) && ring_count > 0
        if ring_count < size(ring_buffer, 1)
            trace.final_population = ring_buffer(1:ring_count, :);
        else
            order = [ring_cursor + 1:size(ring_buffer, 1), 1:ring_cursor];
            trace.final_population = ring_buffer(order, :);
        end
    end
end

function plot_cfg = finalize_plot_config_for_suite(plot_cfg, selected_func_ids, selected_algorithms)
    if isempty(plot_cfg.selected_funcs)
        plot_cfg.selected_funcs_resolved = selected_func_ids;
    else
        plot_cfg.selected_funcs_resolved = intersect(selected_func_ids, plot_cfg.selected_funcs, 'stable');
    end

    selected_algorithms = upper(cellstr(string(selected_algorithms)));
    if isempty(plot_cfg.selected_algorithms)
        plot_cfg.selected_algorithms_resolved = selected_algorithms;
    else
        requested_algs = upper(cellstr(string(plot_cfg.selected_algorithms)));
        plot_cfg.selected_algorithms_resolved = intersect(selected_algorithms, requested_algs, 'stable');
    end

    behavior_funcs = plot_cfg.selected_funcs_resolved;
    if numel(behavior_funcs) > plot_cfg.behavior.max_funcs
        behavior_funcs = behavior_funcs(1:plot_cfg.behavior.max_funcs);
    end
    plot_cfg.behavior.capture_func_ids = behavior_funcs;
    plot_cfg.behavior.capture_algorithms = upper(cellstr(string(plot_cfg.behavior.only_for_algorithms)));
end

function trace_request = make_plot_trace_request(plot_cfg, algorithm_name, fid, dim)
    trace_request = make_trace_request_template();
    if ~plot_cfg.enable || ~has_behavior_plot_enabled(plot_cfg)
        return;
    end

    alg_name = upper(string(algorithm_name));
    if ~ismember(fid, plot_cfg.behavior.capture_func_ids)
        return;
    end
    if ~ismember(char(alg_name), plot_cfg.behavior.capture_algorithms)
        return;
    end
    if ~ismember(char(alg_name), plot_cfg.selected_algorithms_resolved)
        return;
    end
    trace_request.enable = true;
    trace_request.capture_mean_fitness = plot_cfg.types.mean_fitness || plot_cfg.types.search_process_overview;
    trace_request.capture_first_dim = plot_cfg.types.trajectory_first_dim || plot_cfg.types.search_process_overview;
    trace_request.capture_final_population = (plot_cfg.types.final_population || plot_cfg.types.search_process_overview) && ...
        (~plot_cfg.behavior.require_dim2 || dim == 2);
    trace_request.position_dims = min(dim, 2);
end

function tf = has_behavior_plot_enabled(plot_cfg)
    tf = plot_cfg.types.search_process_overview || plot_cfg.types.mean_fitness || ...
        plot_cfg.types.trajectory_first_dim || plot_cfg.types.final_population;
end

function generate_result_figures(run_results, summary_table, cfg, result_dir, run_log_file)
    if ~cfg.plot.enable
        log_message(run_log_file, '[Plot] Plot module disabled.');
        return;
    end

    plot_log_file = fullfile(result_dir.logs, 'plot_generation.log');
    log_message(plot_log_file, sprintf('[Plot] enabled=1 show=%d save=%d', cfg.plot.show, cfg.plot.save));

    if isempty(run_results)
        log_message(plot_log_file, '[Plot] Skip plot generation because run_results is empty.');
        return;
    end

    plot_dirs = init_plot_dirs(result_dir, cfg);
    filtered_runs = filter_run_results_for_plot(run_results, cfg.plot);
    filtered_summary = filter_summary_for_plot(summary_table, cfg.plot);

    if isempty(filtered_runs)
        log_message(plot_log_file, '[Plot] Skip plot generation because filtered run_results is empty.');
        return;
    end

    if cfg.plot.types.convergence_curves
        log_message(plot_log_file, '[Plot] Generating convergence_curves.');
        plot_convergence_curves(filtered_runs, cfg, plot_dirs, plot_log_file);
    end

    if cfg.plot.types.boxplots
        log_message(plot_log_file, '[Plot] Generating boxplots.');
        plot_boxplots(filtered_runs, cfg, plot_dirs, plot_log_file);
    end

    if cfg.plot.types.friedman_radar
        log_message(plot_log_file, '[Plot] Generating friedman_radar.');
        plot_friedman_radar(filtered_summary, cfg, plot_dirs, plot_log_file);
    end

    if has_behavior_plot_enabled(cfg.plot)
        log_message(plot_log_file, '[Plot] Generating behavior plots.');
        plot_algorithm_behavior(filtered_runs, cfg, plot_dirs, plot_log_file);
    end
end

function plot_dirs = init_plot_dirs(result_dir, cfg)
    dim_name = sprintf('D%d', cfg.dim);
    plot_dirs = struct();
    plot_dirs.root = result_dir.figures;
    plot_dirs.convergence_curves = fullfile(result_dir.figures, 'convergence_curves', dim_name);
    plot_dirs.boxplots = fullfile(result_dir.figures, 'boxplots', dim_name);
    plot_dirs.friedman_radar = fullfile(result_dir.figures, 'friedman_radar', dim_name);
    plot_dirs.search_process_overview = fullfile(result_dir.figures, 'search_process_overview');
    plot_dirs.mean_fitness = fullfile(result_dir.figures, 'mean_fitness');
    plot_dirs.trajectory_first_dim = fullfile(result_dir.figures, 'trajectory_first_dim');
    plot_dirs.final_population = fullfile(result_dir.figures, 'final_population');

    dir_list = {plot_dirs.root, plot_dirs.convergence_curves, plot_dirs.boxplots, plot_dirs.friedman_radar, ...
        plot_dirs.search_process_overview, plot_dirs.mean_fitness, plot_dirs.trajectory_first_dim, plot_dirs.final_population};
    for i = 1:numel(dir_list)
        if ~isfolder(dir_list{i})
            mkdir(dir_list{i});
        end
    end
end

function filtered_runs = filter_run_results_for_plot(run_results, plot_cfg)
    if isempty(run_results)
        filtered_runs = run_results;
        return;
    end

    alg_mask = ismember(upper(string({run_results.algorithm_name})), upper(string(plot_cfg.selected_algorithms_resolved)));
    fid_mask = ismember([run_results.function_id], plot_cfg.selected_funcs_resolved);
    filtered_runs = run_results(alg_mask & fid_mask);
end

function filtered_summary = filter_summary_for_plot(summary_table, plot_cfg)
    if isempty(summary_table)
        filtered_summary = summary_table;
        return;
    end
    alg_mask = ismember(upper(string(summary_table.algorithm_name)), upper(string(plot_cfg.selected_algorithms_resolved)));
    fid_mask = ismember(summary_table.function_id, plot_cfg.selected_funcs_resolved);
    filtered_summary = summary_table(alg_mask & fid_mask, :);
end

function plot_convergence_curves(run_results, cfg, plot_dirs, log_file)
    % Paper-friendly benchmark figure: algorithm-level convergence comparison per function.
    fids = unique([run_results.function_id]);
    for i = 1:numel(fids)
        fid = fids(i);
        try
            [mean_curves, labels, x_axis_mode, target_len, run_count_map] = normalize_convergence_history(run_results, fid);
            if isempty(mean_curves)
                log_plot_skip(log_file, cfg, 'convergence_curves', fid, 'no convergence history found');
                continue;
            end

            if strcmp(x_axis_mode, 'fe')
                x_label = 'Function Evaluations';
            else
                x_label = 'Iteration';
            end

            fig = create_plot_figure(cfg.plot);
            ax = axes('Parent', fig);
            apply_axes_style(ax);
            hold(ax, 'on');
            x = 1:target_len;
            for k = 1:numel(mean_curves)
                plot(ax, x, mean_curves{k}, 'LineWidth', 1.5, 'DisplayName', labels{k});
            end
            hold(ax, 'off');
            set(ax, 'YScale', 'log');
            xlabel(ax, x_label);
            ylabel(ax, 'Best-so-far fitness');
            title(ax, sprintf('%s convergence on F%d (D=%d)', upper(cfg.suite), fid, cfg.dim));
            legend(ax, labels, 'Location', 'best', 'Interpreter', 'none');
            grid(ax, 'on');

            note_text = build_convergence_note(run_count_map, labels);
            if ~isempty(note_text)
                annotation(fig, 'textbox', [0.14, 0.01, 0.82, 0.05], 'String', note_text, ...
                    'EdgeColor', 'none', 'Interpreter', 'none', 'FontSize', 9);
            end

            base_name = fullfile(plot_dirs.convergence_curves, sprintf('convergence_%s_D%d_F%d', lower(cfg.suite), cfg.dim, fid));
            save_figure_safely(fig, base_name, cfg.plot, log_file);
        catch ME
            log_plot_skip(log_file, cfg, 'convergence_curves', fid, ME.message);
        end
    end
end

function note_text = build_convergence_note(run_count_map, labels)
    parts = {};
    for i = 1:numel(labels)
        n_runs = run_count_map.(labels{i});
        if n_runs > 1
            parts{end + 1} = sprintf('%s: mean over %d runs', labels{i}, n_runs); %#ok<AGROW>
        else
            parts{end + 1} = sprintf('%s: single-run trajectory', labels{i}); %#ok<AGROW>
        end
    end
    note_text = strjoin(parts, ' | ');
end

function plot_boxplots(run_results, cfg, plot_dirs, log_file)
    % Paper-friendly benchmark figure: final-best distribution across independent runs.
    fids = unique([run_results.function_id]);
    for i = 1:numel(fids)
        fid = fids(i);
        subset = run_results([run_results.function_id] == fid);
        labels = unique(string({subset.algorithm_name}), 'stable');
        if numel(labels) < 2
            log_plot_skip(log_file, cfg, 'boxplots', fid, 'need at least two algorithms');
            continue;
        end

        score_cells = cell(1, numel(labels));
        has_data = false;
        for k = 1:numel(labels)
            idx = strcmp({subset.algorithm_name}, char(labels(k)));
            score_cells{k} = [subset(idx).best_score];
            has_data = has_data || numel(score_cells{k}) > 1;
        end

        if ~has_data
            log_plot_skip(log_file, cfg, 'boxplots', fid, 'insufficient multi-run final-best data');
            continue;
        end

        try
            fig = create_plot_figure(cfg.plot);
            ax = axes('Parent', fig);
            apply_axes_style(ax);
            hold(ax, 'on');
            draw_minimal_boxplot(ax, score_cells, cellstr(labels));
            hold(ax, 'off');
            ylabel(ax, 'Final best fitness');
            title(ax, sprintf('%s boxplot on F%d (D=%d)', upper(cfg.suite), fid, cfg.dim));
            grid(ax, 'on');
            base_name = fullfile(plot_dirs.boxplots, sprintf('boxplot_%s_D%d_F%d', lower(cfg.suite), cfg.dim, fid));
            save_figure_safely(fig, base_name, cfg.plot, log_file);
        catch ME
            log_plot_skip(log_file, cfg, 'boxplots', fid, ME.message);
        end
    end
end

function draw_minimal_boxplot(ax, score_cells, labels)
    colors = lines(max(3, numel(score_cells)));
    for i = 1:numel(score_cells)
        values = score_cells{i}(:);
        values = values(~isnan(values));
        if isempty(values)
            continue;
        end
        stats = compute_box_stats(values);
        x_left = i - 0.28;
        width = 0.56;
        patch(ax, [x_left, x_left + width, x_left + width, x_left], [stats.q1, stats.q1, stats.q3, stats.q3], ...
            colors(i, :), 'FaceAlpha', 0.22, 'EdgeColor', colors(i, :), 'LineWidth', 1.2);
        line(ax, [i, i], [stats.whisker_low, stats.q1], 'Color', colors(i, :), 'LineWidth', 1.2);
        line(ax, [i, i], [stats.q3, stats.whisker_high], 'Color', colors(i, :), 'LineWidth', 1.2);
        line(ax, [x_left, x_left + width], [stats.median, stats.median], 'Color', colors(i, :), 'LineWidth', 1.6);
        line(ax, [i - 0.14, i + 0.14], [stats.whisker_low, stats.whisker_low], 'Color', colors(i, :), 'LineWidth', 1.2);
        line(ax, [i - 0.14, i + 0.14], [stats.whisker_high, stats.whisker_high], 'Color', colors(i, :), 'LineWidth', 1.2);
        scatter(ax, repmat(i, size(stats.outliers)), stats.outliers, 18, 'MarkerEdgeColor', colors(i, :), 'MarkerFaceColor', colors(i, :));
    end
    xlim(ax, [0.5, numel(score_cells) + 0.5]);
    set(ax, 'XTick', 1:numel(labels), 'XTickLabel', labels, 'XTickLabelRotation', 25);
end

function stats = compute_box_stats(values)
    sorted_vals = sort(values(:));
    stats.q1 = percentile_linear(sorted_vals, 25);
    stats.median = percentile_linear(sorted_vals, 50);
    stats.q3 = percentile_linear(sorted_vals, 75);
    iqr_val = stats.q3 - stats.q1;
    lower_fence = stats.q1 - 1.5 * iqr_val;
    upper_fence = stats.q3 + 1.5 * iqr_val;
    inside = sorted_vals(sorted_vals >= lower_fence & sorted_vals <= upper_fence);
    if isempty(inside)
        stats.whisker_low = sorted_vals(1);
        stats.whisker_high = sorted_vals(end);
    else
        stats.whisker_low = inside(1);
        stats.whisker_high = inside(end);
    end
    stats.outliers = sorted_vals(sorted_vals < lower_fence | sorted_vals > upper_fence);
end

function value = percentile_linear(sorted_vals, pct)
    if isempty(sorted_vals)
        value = nan;
        return;
    end
    n = numel(sorted_vals);
    if n == 1
        value = sorted_vals(1);
        return;
    end
    pos = 1 + (n - 1) * pct / 100;
    lo = floor(pos);
    hi = ceil(pos);
    if lo == hi
        value = sorted_vals(lo);
    else
        value = sorted_vals(lo) + (pos - lo) * (sorted_vals(hi) - sorted_vals(lo));
    end
end

function plot_friedman_radar(summary_table, cfg, plot_dirs, log_file)
    % Paper-friendly summary figure: average rank per algorithm within the current experiment only.
    if isempty(summary_table) || height(summary_table) == 0
        log_plot_skip(log_file, cfg, 'friedman_radar', [], 'summary table is empty');
        return;
    end

    [alg_labels, avg_ranks, comparable_funcs] = compute_average_ranks(summary_table);
    if numel(alg_labels) < 2 || comparable_funcs < 2
        log_plot_skip(log_file, cfg, 'friedman_radar', [], 'need at least two algorithms and two comparable functions');
        return;
    end

    try
        fig = create_plot_figure(cfg.plot);
        ax = axes('Parent', fig);
        apply_axes_style(ax);
        draw_radar_chart(ax, alg_labels, avg_ranks);
        title(ax, sprintf('%s Friedman average ranks (D=%d)', upper(cfg.suite), cfg.dim));
        base_name = fullfile(plot_dirs.friedman_radar, sprintf('friedman_%s_D%d', lower(cfg.suite), cfg.dim));
        save_figure_safely(fig, base_name, cfg.plot, log_file);
    catch ME
        log_plot_skip(log_file, cfg, 'friedman_radar', [], ME.message);
    end
end

function [alg_labels, avg_ranks, comparable_funcs] = compute_average_ranks(summary_table)
    alg_labels = {};
    avg_ranks = [];
    comparable_funcs = 0;

    fids = unique(summary_table.function_id)';
    rank_map = struct();
    for i = 1:numel(fids)
        rows = summary_table(summary_table.function_id == fids(i), :);
        if height(rows) < 2
            continue;
        end
        comparable_funcs = comparable_funcs + 1;
        scores = rows.mean;
        labels = cellstr(string(rows.algorithm_name));
        ranks = average_tie_ranks(scores);
        for k = 1:numel(labels)
            key = matlab.lang.makeValidName(labels{k});
            if ~isfield(rank_map, key)
                rank_map.(key) = [];
            end
            rank_map.(key)(end + 1) = ranks(k); %#ok<AGROW>
        end
    end

    keys = fieldnames(rank_map);
    if isempty(keys)
        return;
    end

    alg_labels = cell(1, numel(keys));
    avg_ranks = zeros(1, numel(keys));
    for i = 1:numel(keys)
        alg_labels{i} = regexprep(keys{i}, '^x', '');
        avg_ranks(i) = mean(rank_map.(keys{i}));
    end
end

function ranks = average_tie_ranks(scores)
    [sorted_scores, order] = sort(scores(:), 'ascend');
    ranks = zeros(size(scores(:)));
    i = 1;
    while i <= numel(sorted_scores)
        j = i;
        while j < numel(sorted_scores) && sorted_scores(j + 1) == sorted_scores(i)
            j = j + 1;
        end
        avg_rank = mean(i:j);
        ranks(order(i:j)) = avg_rank;
        i = j + 1;
    end
    ranks = ranks(:)';
end

function plot_algorithm_behavior(run_results, cfg, plot_dirs, log_file)
    % Process-analysis figures are kept separate and default off to avoid slowing large benchmark batches.
    behavior_algs = upper(string(cfg.plot.behavior.capture_algorithms));
    for a = 1:numel(behavior_algs)
        alg_name = char(behavior_algs(a));
        if ~ismember(alg_name, upper(string(cfg.plot.selected_algorithms_resolved)))
            continue;
        end

        for i = 1:numel(cfg.plot.behavior.capture_func_ids)
            fid = cfg.plot.behavior.capture_func_ids(i);
            subset = run_results(strcmp({run_results.algorithm_name}, alg_name) & [run_results.function_id] == fid);
            if isempty(subset)
                log_plot_skip(log_file, cfg, 'behavior', fid, sprintf('%s has no runs', alg_name));
                continue;
            end
            trace = select_behavior_trace(subset);
            if ~trace.captured
                log_plot_skip(log_file, cfg, 'behavior', fid, sprintf('%s has no captured behavior trace', alg_name));
                continue;
            end

            if cfg.plot.types.mean_fitness
                plot_mean_fitness(trace, alg_name, fid, cfg, plot_dirs, log_file);
            end
            if cfg.plot.types.trajectory_first_dim
                plot_trajectory_first_dim(trace, alg_name, fid, cfg, plot_dirs, log_file);
            end
            if cfg.plot.types.final_population
                plot_final_population(trace, subset(1), alg_name, fid, cfg, plot_dirs, log_file);
            end
            if cfg.plot.types.search_process_overview
                plot_search_process_overview(trace, subset(1), alg_name, fid, cfg, plot_dirs, log_file);
            end
        end
    end
end

function trace = select_behavior_trace(subset)
    trace = make_behavior_trace_template();
    if isempty(subset)
        return;
    end

    best_idx = 1;
    best_score = subset(1).best_score;
    for i = 2:numel(subset)
        if subset(i).best_score < best_score
            best_score = subset(i).best_score;
            best_idx = i;
        end
    end
    trace = subset(best_idx).behavior_trace;
end

function plot_mean_fitness(trace, alg_name, fid, cfg, plot_dirs, log_file)
    if isempty(trace.mean_fitness_curve)
        log_plot_skip(log_file, cfg, 'mean_fitness', fid, sprintf('%s missing mean_fitness_curve', alg_name));
        return;
    end
    fig = create_plot_figure(cfg.plot);
    ax = axes('Parent', fig);
    apply_axes_style(ax);
    plot(ax, 1:numel(trace.mean_fitness_curve), trace.mean_fitness_curve, 'LineWidth', 1.5, 'Color', [0.16, 0.45, 0.71]);
    xlabel(ax, 'Iteration proxy (evaluation batch)');
    ylabel(ax, 'Mean fitness');
    title(ax, sprintf('%s mean fitness on F%d (D=%d)', alg_name, fid, cfg.dim));
    grid(ax, 'on');
    target_dir = ensure_behavior_dir(plot_dirs.mean_fitness, alg_name, cfg.dim);
    base_name = fullfile(target_dir, sprintf('meanfit_%s_%s_D%d_F%d', lower(alg_name), lower(cfg.suite), cfg.dim, fid));
    save_figure_safely(fig, base_name, cfg.plot, log_file);
end

function plot_trajectory_first_dim(trace, alg_name, fid, cfg, plot_dirs, log_file)
    if isempty(trace.trajectory_first_dim)
        log_plot_skip(log_file, cfg, 'trajectory_first_dim', fid, sprintf('%s missing trajectory_first_dim', alg_name));
        return;
    end
    fig = create_plot_figure(cfg.plot);
    ax = axes('Parent', fig);
    apply_axes_style(ax);
    plot(ax, 1:numel(trace.trajectory_first_dim), trace.trajectory_first_dim, 'LineWidth', 1.5, 'Color', [0.8, 0.3, 0.2]);
    xlabel(ax, 'Iteration proxy (evaluation batch)');
    ylabel(ax, 'Representative x(1)');
    title(ax, sprintf('%s first-dimension trajectory on F%d (D=%d)', alg_name, fid, cfg.dim));
    grid(ax, 'on');
    target_dir = ensure_behavior_dir(plot_dirs.trajectory_first_dim, alg_name, cfg.dim);
    base_name = fullfile(target_dir, sprintf('traj1d_%s_%s_D%d_F%d', lower(alg_name), lower(cfg.suite), cfg.dim, fid));
    save_figure_safely(fig, base_name, cfg.plot, log_file);
end

function plot_final_population(trace, run_result, alg_name, fid, cfg, plot_dirs, log_file)
    if cfg.plot.behavior.require_dim2 && run_result.dimension ~= 2
        log_plot_skip(log_file, cfg, 'final_population', fid, sprintf('%s skipped because dim=%d', alg_name, run_result.dimension));
        return;
    end
    if isempty(trace.final_population) || size(trace.final_population, 2) < 2
        log_plot_skip(log_file, cfg, 'final_population', fid, sprintf('%s missing 2D final population proxy', alg_name));
        return;
    end
    fig = create_plot_figure(cfg.plot);
    ax = axes('Parent', fig);
    apply_axes_style(ax);
    scatter(ax, trace.final_population(:, 1), trace.final_population(:, 2), 28, 'filled');
    xlabel(ax, 'x_1');
    ylabel(ax, 'x_2');
    title(ax, sprintf('%s final population proxy on F%d (D=%d)', alg_name, fid, cfg.dim));
    grid(ax, 'on');
    target_dir = ensure_behavior_dir(plot_dirs.final_population, alg_name, cfg.dim);
    base_name = fullfile(target_dir, sprintf('finalpop_%s_%s_D%d_F%d', lower(alg_name), lower(cfg.suite), cfg.dim, fid));
    save_figure_safely(fig, base_name, cfg.plot, log_file);
end

function plot_search_process_overview(trace, run_result, alg_name, fid, cfg, plot_dirs, log_file)
    if cfg.plot.behavior.require_dim2 && run_result.dimension ~= 2
        log_plot_skip(log_file, cfg, 'search_process_overview', fid, sprintf('%s skipped because dim=%d', alg_name, run_result.dimension));
        return;
    end

    fig = create_plot_figure(cfg.plot);

    ax1 = subplot(2, 2, 1, 'Parent', fig);
    apply_axes_style(ax1);
    contour_ok = plot_function_contour(ax1, run_result, cfg, fid, trace, log_file);

    ax2 = subplot(2, 2, 2, 'Parent', fig);
    apply_axes_style(ax2);
    if ~isempty(trace.mean_fitness_curve)
        plot(ax2, 1:numel(trace.mean_fitness_curve), trace.mean_fitness_curve, 'LineWidth', 1.4, 'Color', [0.15, 0.45, 0.75]);
        xlabel(ax2, 'Iteration proxy (evaluation batch)');
        ylabel(ax2, 'Mean fitness');
        title(ax2, 'Mean fitness');
        grid(ax2, 'on');
    else
        axis(ax2, 'off');
        text(ax2, 0.1, 0.5, 'Mean fitness unavailable', 'Units', 'normalized');
    end

    ax3 = subplot(2, 2, 3, 'Parent', fig);
    apply_axes_style(ax3);
    if ~isempty(trace.trajectory_first_dim)
        plot(ax3, 1:numel(trace.trajectory_first_dim), trace.trajectory_first_dim, 'LineWidth', 1.4, 'Color', [0.82, 0.33, 0.22]);
        xlabel(ax3, 'Iteration proxy (evaluation batch)');
        ylabel(ax3, 'x_1');
        title(ax3, 'Representative first-dimension trajectory');
        grid(ax3, 'on');
    else
        axis(ax3, 'off');
        text(ax3, 0.1, 0.5, 'Trajectory unavailable', 'Units', 'normalized');
    end

    ax4 = subplot(2, 2, 4, 'Parent', fig);
    apply_axes_style(ax4);
    curve = run_result.convergence_curve(:)';
    if ~isempty(curve)
        plot(ax4, 1:numel(curve), curve, 'LineWidth', 1.4, 'Color', [0.2, 0.2, 0.2]);
        xlabel(ax4, infer_x_label_from_run(run_result));
        ylabel(ax4, 'Best-so-far fitness');
        title(ax4, 'Convergence');
        grid(ax4, 'on');
    else
        axis(ax4, 'off');
        text(ax4, 0.1, 0.5, 'Convergence unavailable', 'Units', 'normalized');
    end

    if ~contour_ok
        log_plot_skip(log_file, cfg, 'search_process_overview', fid, sprintf('%s contour/final positions unavailable', alg_name));
    end

    target_dir = ensure_behavior_dir(plot_dirs.search_process_overview, alg_name, cfg.dim);
    base_name = fullfile(target_dir, sprintf('overview_%s_%s_D%d_F%d', lower(alg_name), lower(cfg.suite), cfg.dim, fid));
    save_figure_safely(fig, base_name, cfg.plot, log_file);
end

function ok = plot_function_contour(ax, run_result, cfg, fid, trace, log_file)
    ok = false;
    if run_result.dimension ~= 2 || isempty(trace.final_population) || size(trace.final_population, 2) < 2
        axis(ax, 'off');
        text(ax, 0.1, 0.5, '2D contour/final population unavailable', 'Units', 'normalized');
        return;
    end

    try
        paths = resolve_common_paths();
        suite_api = build_suite_api(paths, cfg.suite);
        [lb, ub, ~, fobj] = suite_api.get_function(fid, 2);
        [X, Y, Z] = sample_function_surface(lb, ub, fobj);
        contourf(ax, X, Y, Z, 20, 'LineColor', 'none');
        hold(ax, 'on');
        scatter(ax, trace.final_population(:, 1), trace.final_population(:, 2), 22, 'k', 'filled');
        hold(ax, 'off');
        colorbar(ax);
        xlabel(ax, 'x_1');
        ylabel(ax, 'x_2');
        title(ax, '2D contour and final population proxy');
        ok = true;
    catch ME
        log_message(log_file, sprintf('[Plot] contour generation failed for F%d: %s', fid, ME.message));
        axis(ax, 'off');
        text(ax, 0.1, 0.5, 'Contour generation failed', 'Units', 'normalized');
    end
end

function [X, Y, Z] = sample_function_surface(lb, ub, fobj)
    grid_n = 60;
    x1 = linspace(lb(1), ub(1), grid_n);
    x2 = linspace(lb(2), ub(2), grid_n);
    [X, Y] = meshgrid(x1, x2);
    Z = zeros(size(X));
    for i = 1:grid_n
        for j = 1:grid_n
            Z(i, j) = fobj([X(i, j), Y(i, j)]);
        end
    end
end

function [mean_curves, labels, x_axis_mode, target_len, run_count_map] = normalize_convergence_history(run_results, fid)
    idx_f = [run_results.function_id] == fid;
    subset_f = run_results(idx_f);
    if isempty(subset_f)
        mean_curves = {};
        labels = {};
        x_axis_mode = 'iter';
        target_len = 0;
        run_count_map = struct();
        return;
    end

    algs = unique(string({subset_f.algorithm_name}), 'stable');
    labels = {};
    per_alg_curve_lists = {};
    run_count_map = struct();
    max_len_global = 0;

    for a = 1:numel(algs)
        idx_a = strcmp({subset_f.algorithm_name}, char(algs(a)));
        subset_a = subset_f(idx_a);
        curve_list = {};
        for k = 1:numel(subset_a)
            c = subset_a(k).convergence_curve;
            if isempty(c)
                continue;
            end
            c = c(:)';
            if numel(c) < 2
                continue;
            end
            curve_list{end + 1} = c; %#ok<AGROW>
            max_len_global = max(max_len_global, numel(c));
        end
        if ~isempty(curve_list)
            label = char(algs(a));
            labels{end + 1} = label; %#ok<AGROW>
            per_alg_curve_lists{end + 1} = curve_list; %#ok<AGROW>
            run_count_map.(label) = numel(curve_list);
        end
    end

    if isempty(per_alg_curve_lists) || max_len_global < 2
        mean_curves = {};
        labels = {};
        x_axis_mode = 'iter';
        target_len = 0;
        run_count_map = struct();
        return;
    end

    target_len = max_len_global;
    mean_curves = cell(1, numel(per_alg_curve_lists));
    for a = 1:numel(per_alg_curve_lists)
        curve_list = per_alg_curve_lists{a};
        mat = zeros(numel(curve_list), target_len);
        for r = 1:numel(curve_list)
            mat(r, :) = pad_best_curve(curve_list{r}, target_len);
        end
        mean_curves{a} = mean(mat, 1);
    end
    x_axis_mode = infer_x_axis_mode(subset_f, target_len);
end

function padded = pad_best_curve(curve, target_len)
    c = curve(:)';
    n = numel(c);
    if n >= target_len
        padded = c(1:target_len);
        return;
    end
    if n == 0
        padded = nan(1, target_len);
        return;
    end
    padded = [c, repmat(c(end), 1, target_len - n)];
end

function mode_name = infer_x_axis_mode(subset_f, target_len)
    matched_fe = 0;
    total_checked = 0;
    for i = 1:numel(subset_f)
        c = subset_f(i).convergence_curve;
        if isempty(c)
            continue;
        end
        total_checked = total_checked + 1;
        used_fes = subset_f(i).used_FEs;
        if abs(numel(c) - used_fes) <= 1 || abs(target_len - used_fes) <= 1
            matched_fe = matched_fe + 1;
        end
    end
    if total_checked > 0 && matched_fe / total_checked >= 0.8
        mode_name = 'fe';
    else
        mode_name = 'iter';
    end
end

function label = infer_x_label_from_run(run_result)
    if abs(numel(run_result.convergence_curve) - run_result.used_FEs) <= 1
        label = 'Function Evaluations';
    else
        label = 'Iteration';
    end
end

function fig = create_plot_figure(plot_cfg)
    if plot_cfg.show
        visibility = 'on';
    else
        visibility = 'off';
    end
    fig = figure('Visible', visibility, 'Color', 'w', 'Position', [120, 120, 900, 560]);
end

function apply_axes_style(ax)
    set(ax, 'FontName', 'Times New Roman', 'FontSize', 11, 'LineWidth', 1.0, 'Box', 'on');
end

function apply_polar_style(ax)
    ax.FontName = 'Times New Roman';
    ax.FontSize = 11;
    ax.LineWidth = 1.0;
end

function draw_radar_chart(ax, labels, values)
    n = numel(values);
    theta = linspace(0, 2 * pi, n + 1);
    rho = [values(:); values(1)];
    max_r = max(values);
    if max_r <= 0
        max_r = 1;
    end

    hold(ax, 'on');
    axis(ax, 'equal');
    axis(ax, 'off');

    for level = 0.25:0.25:1.0
        ring_x = max_r * level * cos(theta);
        ring_y = max_r * level * sin(theta);
        plot(ax, ring_x, ring_y, ':', 'Color', [0.75, 0.75, 0.75], 'LineWidth', 0.8);
    end

    for i = 1:n
        plot(ax, [0, max_r * cos(theta(i))], [0, max_r * sin(theta(i))], ':', 'Color', [0.75, 0.75, 0.75], 'LineWidth', 0.8);
        text(ax, 1.1 * max_r * cos(theta(i)), 1.1 * max_r * sin(theta(i)), labels{i}, ...
            'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', 'FontSize', 10);
    end

    data_x = rho .* cos(theta(:));
    data_y = rho .* sin(theta(:));
    plot(ax, data_x, data_y, '-o', 'LineWidth', 1.8, 'MarkerSize', 5, 'Color', [0.1, 0.35, 0.7]);
    hold(ax, 'off');
end

function target_dir = ensure_behavior_dir(root_dir, alg_name, dim)
    target_dir = fullfile(root_dir, lower(alg_name), sprintf('D%d', dim));
    if ~isfolder(target_dir)
        mkdir(target_dir);
    end
end

function save_figure_safely(fig, base_name, plot_cfg, log_file)
    if plot_cfg.close_after_save
        cleaner = onCleanup(@() close(fig)); %#ok<NASGU>
    else
        cleaner = onCleanup(@() []); %#ok<NASGU>
    end

    if plot_cfg.tight
        try
            drawnow;
        catch
        end
    end

    for i = 1:numel(plot_cfg.formats)
        fmt = lower(char(string(plot_cfg.formats{i})));
        file_path = sprintf('%s.%s', base_name, fmt);
        if ~plot_cfg.overwrite && isfile(file_path)
            log_message(log_file, sprintf('[Plot] skip existing file: %s', file_path));
            continue;
        end
        try
            save_figure_by_formats(fig, file_path, fmt, plot_cfg.dpi);
            log_message(log_file, sprintf('[Plot] saved: %s', file_path));
        catch ME
            log_message(log_file, sprintf('[Plot] save failed: %s (%s)', file_path, ME.message));
        end
    end
    clear cleaner;
end

function save_figure_by_formats(fig, file_path, fmt, dpi)
    if exist('exportgraphics', 'file') == 2 && any(strcmp(fmt, {'png', 'pdf'}))
        exportgraphics(fig, file_path, 'Resolution', dpi);
        return;
    end

    switch fmt
        case 'png'
            print(fig, file_path, '-dpng', sprintf('-r%d', dpi));
        case 'pdf'
            print(fig, file_path, '-dpdf', sprintf('-r%d', dpi));
        case 'fig'
            savefig(fig, file_path);
        otherwise
            saveas(fig, file_path);
    end
end

function log_plot_skip(log_file, cfg, plot_type, fid, reason)
    if nargin < 4 || isempty(fid)
        scope = plot_type;
    else
        scope = sprintf('%s F%d', plot_type, fid);
    end
    if cfg.plot.log_skipped
        log_message(log_file, sprintf('[Plot] skipped %s: %s', scope, reason));
    end
end

function log_message(log_file, msg)
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
    line = sprintf('[%s] %s\n', timestamp, msg);

    fid = fopen(log_file, 'a');
    if fid < 0
        error('Cannot open log file: %s', log_file);
    end
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, '%s', line);
    clear cleaner;
end