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

                    [counted_fobj, get_fe_state] = make_counted_objective(fobj, suite_cfg.maxFEs, suite_cfg.hard_stop_on_fe_limit);

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
                        current_dim, suite_cfg.pop_size, suite_cfg.maxFEs, used_fes, fe_control_mode, fe_note);

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
        generate_result_figures(run_results, suite_cfg, result_dir, log_file);

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
            cfg.maxFEs = 30000;
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
    if ~isfield(cfg, 'enable_plots')
        cfg.enable_plots = true;
    end
    if ~isfield(cfg, 'show_plots')
        cfg.show_plots = false;
    end
    if ~isfield(cfg, 'save_plots')
        cfg.save_plots = true;
    end
    if ~isfield(cfg, 'plot_formats') || isempty(cfg.plot_formats)
        cfg.plot_formats = {'png'};
    end
    if ~isfield(cfg, 'plot_dpi')
        cfg.plot_dpi = 200;
    end
    if ~isfield(cfg, 'plot_subdir') || isempty(cfg.plot_subdir)
        cfg.plot_subdir = 'figures';
    end
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
    addpath(algorithm_dir);
    p = algorithm_dir;
end

function teardown_single_algorithm_path(algorithm_dir)
    if isfolder(algorithm_dir)
        rmpath(algorithm_dir);
    end
end

function teardown_algorithm_paths(path_state)
    for i = 1:numel(path_state)
        if isfolder(path_state{i})
            rmpath(path_state{i});
        end
    end
end

function [lb, ub, dim, fobj] = get_cec2017_function(fid, dim)
    % Keep the original calling chain, but self-heal MATLAB path when session state is dirty.
    if exist('Get_Functions_cec2017', 'file') ~= 2
        ensure_suite_getter_on_path('cec2017');
    end
    [lb, ub, dim, fobj] = Get_Functions_cec2017(fid, dim);
end

function [lb, ub, dim, fobj] = get_cec2022_function(fid, dim)
    % Keep the original calling chain, but self-heal MATLAB path when session state is dirty.
    if exist('Get_Functions_cec2022', 'file') ~= 2
        ensure_suite_getter_on_path('cec2022');
    end
    [lb, ub, dim, fobj] = Get_Functions_cec2022(fid, dim);
end

function ensure_suite_getter_on_path(suite_name)
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
    c = struct('name', '', 'entry_name', '', 'algorithm_dir', '', 'budget_arg', '', 'output_mode', '');
    catalog = repmat(c, 1, 10);

    catalog(1) = make_algorithm_spec('BBO', 'BBO', suite_api.suite_dir, 'max_iter', 'score_pos_curve');
    catalog(2) = make_algorithm_spec('SBO', 'SBO', fullfile(sbo_root, 'Status-based Optimization (SBO)-2025'), 'maxFEs', 'score_pos_curve');
    catalog(3) = make_algorithm_spec('HGS', 'HGS', fullfile(sbo_root, 'Hunger Games Search (HGS)-2021'), 'max_iter', 'score_pos_curve');
    catalog(4) = make_algorithm_spec('SMA', 'SMA', fullfile(sbo_root, 'Slime mould algorithm (SMA)-2020'), 'max_iter', 'score_pos_curve');
    catalog(5) = make_algorithm_spec('HHO', 'HHO', fullfile(sbo_root, 'Harris Hawk Optimization (HHO)-2019'), 'max_iter', 'score_pos_curve');
    catalog(6) = make_algorithm_spec('RUN', 'RUN', fullfile(sbo_root, 'Runge Kutta Optimization (RUN)-2021'), 'max_iter', 'score_pos_curve');
    catalog(7) = make_algorithm_spec('INFO', 'INFO', fullfile(sbo_root, 'Weighted Mean of Vectors (INFO)-2022'), 'max_iter', 'score_pos_curve');
    catalog(8) = make_algorithm_spec('MGO', 'MGO', fullfile(sbo_root, 'Moss Growth Optimization (MGO)-2024'), 'maxFEs', 'pos_curve');
    catalog(9) = make_algorithm_spec('PLO', 'PLO', fullfile(sbo_root, 'Polar Lights Optimizer (PLO)-2024'), 'maxFEs', 'pos_score_curve');
    catalog(10) = make_algorithm_spec('PO', 'PO', fullfile(sbo_root, 'Parrot Optimizer (PO)-2024'), 'max_iter', 'po');
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

function [counted_fobj, get_fe_state] = make_counted_objective(base_fobj, maxFEs, hard_stop_on_fe_limit)
    used_FEs = 0;
    best_score = inf;
    best_position = [];
    best_curve = [];

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
    end

    function state = get_state_impl()
        state = struct();
        state.used_FEs = used_FEs;
        state.best_score = best_score;
        state.best_position = best_position;
        state.best_curve = best_curve;
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
    best_score, best_position, convergence_curve, runtime, seed, dimension, population_size, maxFEs, used_FEs, fe_control_mode, fe_note)

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
    result_dir.raw_runs = fullfile(root, 'raw_runs');
    result_dir.curves = fullfile(root, 'curves');
    result_dir.logs = fullfile(root, 'logs');

    if ~isfolder(root)
        mkdir(root);
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
    end

    if cfg.save_mat
        save(fullfile(result_dir.root, 'summary.mat'), 'summary_table', 'run_results', 'run_manifest');
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

function generate_result_figures(run_results, cfg, result_dir, log_file)
    if ~isfield(cfg, 'enable_plots') || ~cfg.enable_plots
        return;
    end

    if isempty(run_results)
        log_message(log_file, '[Plot] Skip plot generation because run_results is empty.');
        return;
    end

    plot_dir = get_plot_dir(result_dir, cfg);
    log_message(log_file, sprintf('[Plot] Saving convergence plots to %s', plot_dir));

    fids = unique([run_results.function_id]);
    for i = 1:numel(fids)
        fid = fids(i);
        try
            save_convergence_plot_by_function(run_results, cfg, plot_dir, fid, log_file);
        catch ME
            % Plot errors must not break benchmark outputs.
            log_message(log_file, sprintf('[Plot] Skip function F%d due to plot error: %s', fid, ME.message));
        end
    end
end

function plot_dir = get_plot_dir(result_dir, cfg)
    plot_dir = fullfile(result_dir.root, cfg.plot_subdir);
    if ~isfolder(plot_dir)
        mkdir(plot_dir);
    end
end

function save_convergence_plot_by_function(run_results, cfg, plot_dir, fid, log_file)
    [mean_curves, labels, x_axis_mode, target_len] = normalize_convergence_history(run_results, fid, log_file);
    if isempty(mean_curves)
        log_message(log_file, sprintf('[Plot] Skip function F%d because no convergence history found.', fid));
        return;
    end

    if strcmp(x_axis_mode, 'fe')
        x_label = 'Function Evaluations (FEs)';
    else
        x_label = 'Iteration';
    end

    x = 1:target_len;
    title_text = sprintf('%s F%d dim=%d', upper(cfg.suite), fid, cfg.dim);

    % Always save a raw linear-scale figure for traceability.
    save_convergence_figure(x, mean_curves, labels, x_label, 'Best-so-far fitness', title_text, ...
        fullfile(plot_dir, sprintf('conv_f%02d_raw', fid)), cfg);

    [plot_curves, y_label, mode_name, reason_text] = transform_curve_for_plot(mean_curves, cfg, fid);
    if ~isempty(reason_text)
        log_message(log_file, sprintf('[Plot] F%d transform mode=%s (%s)', fid, mode_name, reason_text));
    else
        log_message(log_file, sprintf('[Plot] F%d transform mode=%s', fid, mode_name));
    end

    % Primary figure uses transformed curves for paper-ready readability.
    save_convergence_figure(x, plot_curves, labels, x_label, y_label, title_text, ...
        fullfile(plot_dir, sprintf('conv_f%02d', fid)), cfg);

    % Save explicit transformed variant for manual screening.
    save_convergence_figure(x, plot_curves, labels, x_label, y_label, title_text, ...
        fullfile(plot_dir, sprintf('conv_f%02d_log', fid)), cfg);
end

function [mean_curves, labels, x_axis_mode, target_len] = normalize_convergence_history(run_results, fid, log_file)
    idx_f = [run_results.function_id] == fid;
    subset_f = run_results(idx_f);
    if isempty(subset_f)
        mean_curves = {};
        labels = {};
        x_axis_mode = 'iter';
        target_len = 0;
        return;
    end

    algs = unique(string({subset_f.algorithm_name}));
    labels = {};
    per_alg_curve_lists = {};
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
            labels{end + 1} = char(algs(a)); %#ok<AGROW>
            per_alg_curve_lists{end + 1} = curve_list; %#ok<AGROW>
        end
    end

    if isempty(per_alg_curve_lists) || max_len_global < 2
        mean_curves = {};
        labels = {};
        x_axis_mode = 'iter';
        target_len = 0;
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
    if strcmp(x_axis_mode, 'fe')
        log_message(log_file, sprintf('[Plot] F%d x-axis mode resolved as FE-level history.', fid));
    else
        log_message(log_file, sprintf('[Plot] F%d x-axis mode resolved as iteration-level history.', fid));
    end
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
    % Best-so-far remains constant after algorithm termination.
    padded = [c, repmat(c(end), 1, target_len - n)];
end

function mode_name = infer_x_axis_mode(subset_f, target_len)
    % Decide whether history is FE-level or iteration-level from saved run metadata.
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

function [out_curves, y_label, mode_name, reason_text] = transform_curve_for_plot(mean_curves, cfg, fid)
    out_curves = mean_curves;

    f_star = get_theoretical_optimum(cfg, fid);
    if ~isnan(f_star)
        % Preferred paper view: log10(best-so-far - f* + eps).
        for i = 1:numel(mean_curves)
            gap = mean_curves{i} - f_star + eps;
            gap = max(gap, eps);
            out_curves{i} = log10(gap);
        end
        y_label = 'log10(best-so-far - f* + eps)';
        mode_name = 'log_gap_to_fstar';
        reason_text = 'f* available';
        return;
    end

    all_positive = true;
    for i = 1:numel(mean_curves)
        if any(mean_curves{i} <= 0)
            all_positive = false;
            break;
        end
    end

    if all_positive
        for i = 1:numel(mean_curves)
            out_curves{i} = log10(mean_curves{i});
        end
        y_label = 'log10(best-so-far fitness)';
        mode_name = 'log_best';
        reason_text = 'f* missing, all best-so-far values are positive';
        return;
    end

    % Explicit fallback when log transform is unsafe due to non-positive values.
    y_label = 'Best-so-far fitness';
    mode_name = 'linear_best';
    reason_text = 'fallback to linear because non-positive values make log unsafe';
end

function f_star = get_theoretical_optimum(cfg, fid)
    f_star = nan;
    if ~isfield(cfg, 'theoretical_optima') || isempty(cfg.theoretical_optima)
        return;
    end

    opt_cfg = cfg.theoretical_optima;
    suite_name = lower(string(cfg.suite));

    if isstruct(opt_cfg)
        if isfield(opt_cfg, char(suite_name))
            suite_map = opt_cfg.(char(suite_name));
        elseif isfield(opt_cfg, 'all')
            suite_map = opt_cfg.all;
        else
            return;
        end

        if isnumeric(suite_map)
            if fid >= 1 && fid <= numel(suite_map)
                f_star = suite_map(fid);
            end
        elseif isstruct(suite_map)
            key = sprintf('F%d', fid);
            if isfield(suite_map, key)
                f_star = suite_map.(key);
            end
        end
    end
end

function save_convergence_figure(x, curves, labels, x_label, y_label, title_text, base_name, cfg)
    % Keep plotting non-interactive to avoid blocking experiment execution.
    fig = figure('Visible', 'off');
    cleaner = onCleanup(@() close(fig));

    hold on;
    for i = 1:numel(curves)
        plot(x, curves{i}, 'LineWidth', 1.2);
    end
    hold off;

    xlabel(x_label);
    ylabel(y_label);
    title(title_text);
    legend(labels, 'Location', 'best', 'Interpreter', 'none');
    grid on;

    if cfg.save_plots
        save_figure_by_formats(fig, base_name, cfg.plot_formats, cfg.plot_dpi);
    end

    clear cleaner;
end

function save_figure_by_formats(fig, base_name, formats, dpi)
    for i = 1:numel(formats)
        fmt = lower(string(formats{i}));
        file_path = sprintf('%s.%s', base_name, char(fmt));

        if exist('exportgraphics', 'file') == 2
            try
                exportgraphics(fig, file_path, 'Resolution', dpi);
                continue;
            catch
            end
        end

        if strcmp(fmt, 'png')
            print(fig, file_path, '-dpng', sprintf('-r%d', dpi));
        else
            saveas(fig, file_path);
        end
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