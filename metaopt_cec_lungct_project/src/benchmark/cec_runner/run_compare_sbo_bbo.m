function output = run_compare_sbo_bbo(cfg)
% Unified SBO vs BBO benchmark runner for CEC2017/CEC2022.
% Minimal-intrusion wrapper: keep baseline optimizers unchanged.
%
% Usage:
%   run_compare_sbo_bbo();
%   run_compare_sbo_bbo(struct('suite','cec2017','func_ids',1:5,'runs',3));
%
% Output files are saved to:
%   results/<suite>/<experiment_name_or_timestamp>/
%
% Budget policy:
%   Unified budget is controlled by cfg.max_fes for all algorithms.

    if nargin < 1
        cfg = struct();
    end

    cfg = fill_default_config(cfg);
    validate_config(cfg);

    [repo_root, sbo_dir, suite_dir, compat_dir, suite_api] = resolve_paths_and_suite(cfg.suite);
    result_dir = init_result_dirs(repo_root, cfg);

    cfg.resolved_repo_root = repo_root;
    cfg.resolved_sbo_dir = sbo_dir;
    cfg.resolved_suite_dir = suite_dir;

    if cfg.save_mat
        save(fullfile(result_dir.root, 'config.mat'), 'cfg');
    end

    log_file = fullfile(result_dir.logs, 'run_log.txt');
    log_message(log_file, sprintf('Start experiment: %s', cfg.experiment_name));
    log_message(log_file, sprintf('Suite: %s', cfg.suite));

    path_cleanup = setup_algorithm_paths(compat_dir, sbo_dir, suite_dir);
    cleanup_obj = onCleanup(@() teardown_algorithm_paths(path_cleanup)); %#ok<NASGU>

    % CEC mex functions read input_data by relative path; run inside suite folder.
    old_dir = pwd;
    cd(suite_dir);
    workdir_cleanup = onCleanup(@() cd(old_dir)); %#ok<NASGU>

    algorithms = {'SBO', 'BBO'};
    run_results = struct([]);
    run_idx = 0;

    for f = 1:numel(cfg.func_ids)
        fid = cfg.func_ids(f);
        [lb, ub, resolved_dim, fobj] = suite_api.get_function(fid, cfg.dim);

        if resolved_dim ~= cfg.dim
            log_message(log_file, sprintf('Function F%d overrides dim from %d to %d.', fid, cfg.dim, resolved_dim));
        end

        current_dim = resolved_dim;

        for a = 1:numel(algorithms)
            alg = algorithms{a};
            log_message(log_file, sprintf('Running %s on F%d ...', alg, fid));

            for run_id = 1:cfg.runs
                run_seed = cfg.rng_seed + (f - 1) * 100000 + (a - 1) * 1000 + run_id;
                rng(run_seed, 'twister');

                t0 = tic;
                if strcmp(alg, 'SBO')
                    [best_score, best_pos, curve] = run_sbo_once(cfg.pop_size, cfg.max_fes, lb, ub, current_dim, fobj);
                else
                    [best_score, best_pos, curve] = run_bbo_once(cfg.pop_size, cfg.max_fes, lb, ub, current_dim, fobj);
                end
                runtime = toc(t0);

                run_idx = run_idx + 1;
                run_results(run_idx).algorithm_name = alg; %#ok<*AGROW>
                run_results(run_idx).function_id = fid;
                run_results(run_idx).run_id = run_id;
                run_results(run_idx).best_score = best_score;
                run_results(run_idx).best_position = best_pos;
                run_results(run_idx).convergence_curve = curve;
                run_results(run_idx).runtime = runtime;
                run_results(run_idx).seed = run_seed;
                run_results(run_idx).max_fes = cfg.max_fes;

                save_single_run(result_dir, run_results(run_idx), cfg);
                if cfg.save_curve
                    save_curve_file(result_dir, run_results(run_idx), cfg);
                end

                log_message(log_file, sprintf('Done %s F%d run %d/%d: best=%.12g, t=%.4fs', ...
                    alg, fid, run_id, cfg.runs, best_score, runtime));
            end
        end
    end

    summary_table = build_summary_table(run_results);
    save_summary(result_dir, summary_table, run_results, cfg);

    log_message(log_file, sprintf('Finished experiment: %s', cfg.experiment_name));

    output = struct();
    output.result_dir = result_dir.root;
    output.summary = summary_table;
    output.total_runs = numel(run_results);
end

function cfg = fill_default_config(cfg)
    if ~isfield(cfg, 'suite')
        cfg.suite = 'cec2017';
    end
    if ~isfield(cfg, 'func_ids')
        cfg.func_ids = 1:30;
    end
    if ~isfield(cfg, 'dim')
        cfg.dim = 10;
    end
    if ~isfield(cfg, 'pop_size')
        cfg.pop_size = 30;
    end
    if ~isfield(cfg, 'max_iter')
        cfg.max_iter = 500;
    end
    if ~isfield(cfg, 'max_fes')
        cfg.max_fes = 300000;
    end
    if ~isfield(cfg, 'runs')
        cfg.runs = 30;
    end
    if ~isfield(cfg, 'rng_seed')
        cfg.rng_seed = 20260312;
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
end

function validate_config(cfg)
    supported = {'cec2017', 'cec2022'};
    if ~any(strcmpi(cfg.suite, supported))
        error('Unsupported suite: %s. Use cec2017 or cec2022.', cfg.suite);
    end

    if isempty(cfg.func_ids) || any(cfg.func_ids < 1)
        error('func_ids must be positive integer ids.');
    end

    if any(mod(cfg.func_ids, 1) ~= 0)
        error('func_ids must be integer ids.');
    end

    if strcmpi(cfg.suite, 'cec2017') && any(cfg.func_ids > 30)
        error('cec2017 supports function ids in [1, 30].');
    end

    if strcmpi(cfg.suite, 'cec2022') && any(cfg.func_ids > 12)
        error('cec2022 supports function ids in [1, 12].');
    end

    if cfg.pop_size <= 0 || cfg.max_iter <= 0 || cfg.max_fes <= 0 || cfg.runs <= 0 || cfg.dim <= 0
        error('dim, pop_size, max_iter, max_fes, runs must be > 0.');
    end
end

function [repo_root, sbo_dir, suite_dir, compat_dir, suite_api] = resolve_paths_and_suite(suite_name)
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    repo_root = fullfile(this_dir, '..', '..', '..');

    sbo_dir = fullfile(repo_root, 'src', 'baselines', 'metaheuristics', 'SBO', ...
        'Status_based_Optimization_SBO_MATLAB_codes_extracted', 'Status-based Optimization (SBO)-2025');
    compat_dir = fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'compat');

    bbo_root = fullfile(repo_root, 'src', 'baselines', 'metaheuristics', 'BBO', ...
        'Source_code_BBO_MATLAB_VERSION_extracted', 'Source_code_BBO_MATLAB_VERSION');

    if strcmpi(suite_name, 'cec2017')
        suite_dir = fullfile(bbo_root, 'CEC2017');
        suite_api.get_function = @get_cec2017_function;
    else
        suite_dir = fullfile(bbo_root, 'CEC2022');
        suite_api.get_function = @get_cec2022_function;
    end

    if ~isfolder(sbo_dir)
        error('SBO folder not found: %s', sbo_dir);
    end
    if ~isfolder(compat_dir)
        error('Compatibility folder not found: %s', compat_dir);
    end
    if ~isfolder(suite_dir)
        error('Suite folder not found: %s', suite_dir);
    end
end

function path_state = setup_algorithm_paths(compat_dir, sbo_dir, suite_dir)
    path_state = {};

    addpath(compat_dir);
    path_state{end + 1} = compat_dir;

    addpath(sbo_dir);
    path_state{end + 1} = sbo_dir;

    addpath(suite_dir);
    path_state{end + 1} = suite_dir;
end

function teardown_algorithm_paths(path_state)
    for i = 1:numel(path_state)
        if isfolder(path_state{i})
            rmpath(path_state{i});
        end
    end
end

function [lb, ub, dim, fobj] = get_cec2017_function(fid, dim)
    [lb, ub, dim, fobj] = Get_Functions_cec2017(fid, dim);
end

function [lb, ub, dim, fobj] = get_cec2022_function(fid, dim)
    [lb, ub, dim, fobj] = Get_Functions_cec2022(fid, dim);
end

function [best_score, best_pos, curve] = run_sbo_once(pop_size, max_fes, lb, ub, dim, fobj)
    [best_score, best_pos, curve] = SBO(pop_size, max_fes, lb, ub, dim, fobj);
end

function [best_score, best_pos, curve] = run_bbo_once(pop_size, max_fes, lb, ub, dim, fobj)
    max_iter = bbo_iterations_from_fes(pop_size, max_fes);
    [best_score, best_pos, curve] = BBO(pop_size, max_iter, lb, ub, dim, fobj);
end

function max_iter = bbo_iterations_from_fes(pop_size, max_fes)
    % BBO evaluates N individuals at initialization and N per iteration.
    % Use the largest integer iteration count whose estimated FEs <= max_fes.
    max_iter = floor((max_fes - pop_size) / pop_size);
    if max_iter < 1
        max_iter = 1;
    end
end

function result_dir = init_result_dirs(repo_root, cfg)
    suite = lower(cfg.suite);
    root = fullfile(repo_root, cfg.result_root, suite, cfg.experiment_name);

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

            row = table( ...
                string(algs(i)), ...
                fids(j), ...
                min(scores), ...
                mean(scores), ...
                std(scores), ...
                max(scores), ...
                median(scores), ...
                mean(runtimes), ...
                'VariableNames', {'algorithm_name','function_id','best','mean','std','worst','median','avg_runtime'});

            rows = [rows; row]; %#ok<AGROW>
        end
    end

    summary_table = rows;
end

function save_summary(result_dir, summary_table, run_results, cfg)
    if cfg.save_csv
        writetable(summary_table, fullfile(result_dir.root, 'summary.csv'));
    end

    if cfg.save_mat
        save(fullfile(result_dir.root, 'summary.mat'), 'summary_table', 'run_results');
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
