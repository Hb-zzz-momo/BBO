function output = rac_run_benchmark_kernel(cfg)
% rac_run_benchmark_kernel
% Unified multi-algorithm benchmark runner for CEC2017 and CEC2022.
% Minimal-intrusion wrapper: keep baseline optimizers unchanged.
%
% Usage:
%   rac_run_benchmark_kernel();
%   rac_run_benchmark_kernel(struct('suites',{{'cec2017','cec2022'}}, 'func_ids',1:5, 'runs',3));
%
% Budget policy:
%   maxFEs is the primary fairness budget for all algorithms.

    if nargin < 1
        cfg = struct();
    end

    cfg = rac_fill_default_config(cfg);
    rac_validate_config(cfg);

    paths = rac_resolve_common_paths();
    suite_list = rac_normalize_suite_list(cfg.suites);

    output = struct();
    output.suite_results = repmat(rac_make_suite_output_template(), 1, 0);

    for s = 1:numel(suite_list)
        suite_name = suite_list{s};
        suite_api = rac_build_suite_api(paths, suite_name);
        suite_cfg = rac_derive_suite_cfg(cfg, suite_name);
        result_dir = rac_init_result_dirs(paths.repo_root, suite_name, suite_cfg);

        suite_cfg.resolved_repo_root = paths.repo_root;
        suite_cfg.resolved_sbo_pack_root = paths.sbo_pack_root;
        suite_cfg.resolved_compat_dir = paths.compat_dir;
        suite_cfg.resolved_suite_dir = suite_api.suite_dir;
        suite_cfg.fe_counting_mode = 'counted_objective_wrapper';

        if suite_cfg.save_mat
            save(fullfile(result_dir.root, 'config.mat'), 'suite_cfg');
        end

        suite_log = rac_begin_suite_logging(result_dir, suite_cfg, suite_name);
        log_file = suite_log.file;
        suite_log_cleanup = suite_log.cleanup; %#ok<NASGU>

        runtime_session = rac_activate_suite_runtime(paths, suite_api);
        runtime_session_cleanup = runtime_session.cleanup; %#ok<NASGU>

        algorithm_inventory = rac_build_algorithm_inventory(paths, suite_api, suite_cfg.algorithms, suite_cfg.maxFEs, suite_cfg.pop_size);
        rac_save_algorithm_inventory(result_dir.root, algorithm_inventory, suite_cfg);
        rac_log_algorithm_inventory(log_file, algorithm_inventory);

        selected_func_ids = rac_resolve_function_ids_for_suite(suite_cfg.func_ids, suite_name);
        selected_func_ids = rac_validate_func_ids_for_suite(selected_func_ids, suite_name);
        suite_cfg.plot = rac_finalize_plot_config_for_suite(suite_cfg.plot, selected_func_ids, suite_cfg.algorithms);

        run_results = repmat(rac_make_run_result_template(), 1, 0);
        run_manifest_rows = repmat(rac_make_manifest_row_template(), 1, 0);
        rescue_diag_rows = repmat(rac_make_rescue_diag_row_template(), 1, 0);
        rescue_trigger_event_rows = repmat(rac_make_rescue_trigger_event_row_template(), 1, 0);
        run_idx = 0;
        manifest_idx = 0;
        rescue_diag_idx = 0;
        rescue_trigger_event_idx = 0;

        for f = 1:numel(selected_func_ids)
            fid = selected_func_ids(f);
            [lb, ub, resolved_dim, fobj] = suite_api.get_function(fid, suite_cfg.dim);

            if resolved_dim ~= suite_cfg.dim
                rac_log_message(log_file, sprintf('Function F%d overrides dim from %d to %d.', fid, suite_cfg.dim, resolved_dim));
            end

            current_dim = resolved_dim;

            for a = 1:numel(algorithm_inventory)
                alg = algorithm_inventory(a);
                if ~alg.is_runnable
                    rac_log_message(log_file, sprintf('Skip %s on F%d: not runnable (%s).', alg.name, fid, alg.note));
                    continue;
                end

                if exist('alg_cleanup_obj', 'var') && isa(alg_cleanup_obj, 'onCleanup')
                    delete(alg_cleanup_obj);
                    clear('alg_cleanup_obj');
                end

                alg_path_cleanup = rac_setup_single_algorithm_path(alg.algorithm_dir, true);
                alg_cleanup_obj = onCleanup(@() rac_teardown_single_algorithm_path(alg_path_cleanup)); %#ok<NASGU>

                [path_ok, path_msg] = rac_validate_algorithm_path_resolution(alg.algorithm_dir, alg.entry_name);
                if path_ok
                    rac_log_message(log_file, sprintf('Path check %s: %s', alg.name, path_msg));
                else
                    rac_log_message(log_file, sprintf('WARNING path check %s: %s', alg.name, path_msg));
                    if suite_cfg.strict_path_guard
                        rac_log_message(log_file, sprintf('Skip %s on F%d: strict_path_guard=true.', alg.name, fid));
                        continue;
                    end
                end

                rac_log_message(log_file, sprintf('Running %s on F%d ...', alg.name, fid));

                if ~rac_is_path_entry_active(alg.algorithm_dir)
                    rac_log_message(log_file, sprintf('WARNING %s path became inactive before run; attempting re-activation.', alg.name));
                    rac_setup_single_algorithm_path(alg.algorithm_dir, true);
                end

                if exist('unifrnd', 'file') ~= 2
                    addpath(paths.compat_dir, '-begin');
                    rac_log_message(log_file, sprintf('Re-activated compat fallback path for %s (unifrnd missing before run).', alg.name));
                end

                for run_id = 1:suite_cfg.runs
                    run_state = rac_execute_single_run( ...
                        alg, suite_name, fid, current_dim, run_id, s, f, a, suite_cfg, lb, ub, fobj, log_file, paths.compat_dir);

                    run_idx = run_idx + 1;
                    run_results(run_idx) = run_state.run_result;
                    rac_persist_run_artifacts(result_dir, run_state.run_result, suite_cfg);

                    manifest_idx = manifest_idx + 1;
                    run_manifest_rows(manifest_idx) = run_state.manifest_row; %#ok<AGROW>

                    if run_state.has_rescue_diag
                        rescue_diag_idx = rescue_diag_idx + 1;
                        rescue_diag_rows(rescue_diag_idx) = run_state.rescue_diag_row; %#ok<AGROW>
                    end

                    if run_state.rescue_event_count > 0
                        rescue_trigger_event_rows((rescue_trigger_event_idx + 1):(rescue_trigger_event_idx + run_state.rescue_event_count)) = run_state.rescue_event_rows; %#ok<AGROW>
                        rescue_trigger_event_idx = rescue_trigger_event_idx + run_state.rescue_event_count;
                    end
                end

                if exist('alg_cleanup_obj', 'var') && isa(alg_cleanup_obj, 'onCleanup')
                    delete(alg_cleanup_obj);
                    clear('alg_cleanup_obj');
                end
            end
        end

        summary_table = rac_build_summary_table(run_results);
        run_manifest = rac_build_run_manifest_table(run_manifest_rows);
        exact_match_warnings = rac_detect_exact_match_warnings(run_results, suite_cfg.runs);

        if ~isempty(exact_match_warnings)
            for wi = 1:height(exact_match_warnings)
                rac_log_message(log_file, sprintf('[RED][ExactMatchAlert] F%d: %s vs %s (%d/%d runs exactly equal; by run_id)', ...
                    exact_match_warnings.function_id(wi), ...
                    string(exact_match_warnings.algorithm_a(wi)), ...
                    string(exact_match_warnings.algorithm_b(wi)), ...
                    exact_match_warnings.equal_run_count(wi), ...
                    exact_match_warnings.expected_runs(wi)));
            end
            summary_table = rac_apply_exact_match_flags(summary_table, exact_match_warnings);
        else
            if ~ismember('exact_match_warning', summary_table.Properties.VariableNames)
                summary_table.exact_match_warning = repmat("", height(summary_table), 1);
            end
        end

        rac_save_summary(result_dir, summary_table, run_results, run_manifest, exact_match_warnings, suite_cfg);
        rac_save_rescue_diagnostics(result_dir, rescue_diag_rows, rescue_trigger_event_rows, suite_cfg);

        % Plot generation is isolated after numeric outputs to avoid changing benchmark flow.
        rac_generate_result_figures(run_results, summary_table, suite_cfg, result_dir, log_file);

        rac_log_message(log_file, sprintf('Finished experiment: %s', suite_cfg.experiment_name));

        suite_output = struct();
        suite_output.suite = suite_name;
        suite_output.result_dir = result_dir.root;
        suite_output.summary = summary_table;
        suite_output.exact_match_warnings = exact_match_warnings;
        suite_output.total_runs = numel(run_results);
        output.suite_results(end + 1) = suite_output; %#ok<AGROW>
    end
end

function warning_table = rac_detect_exact_match_warnings(run_results, expected_runs)
    warning_table = table();
    if isempty(run_results)
        return;
    end

    fids = unique([run_results.function_id]);
    rows = repmat(struct( ...
        'function_id', 0, ...
        'algorithm_a', "", ...
        'algorithm_b', "", ...
        'equal_run_count', 0, ...
        'expected_runs', 0, ...
        'is_full_exact_match', false), 0, 1);

    for fi = 1:numel(fids)
        fid = fids(fi);
        subset = run_results([run_results.function_id] == fid);
        algs = unique(string({subset.algorithm_name}), 'stable');

        for i = 1:numel(algs)
            for j = (i + 1):numel(algs)
                a_runs = subset(strcmp(string({subset.algorithm_name}), algs(i)));
                b_runs = subset(strcmp(string({subset.algorithm_name}), algs(j)));

                if numel(a_runs) ~= expected_runs || numel(b_runs) ~= expected_runs
                    continue;
                end

                a_ids = [a_runs.run_id];
                b_ids = [b_runs.run_id];
                if ~isequal(sort(a_ids), sort(b_ids))
                    continue;
                end

                [~, ord_a] = sort(a_ids);
                [~, ord_b] = sort(b_ids);
                a_vals = [a_runs(ord_a).best_score];
                b_vals = [b_runs(ord_b).best_score];

                eq_mask = arrayfun(@(x, y) isequaln(x, y), a_vals, b_vals);
                eq_count = sum(eq_mask);

                if eq_count == expected_runs
                    r = struct();
                    r.function_id = fid;
                    r.algorithm_a = algs(i);
                    r.algorithm_b = algs(j);
                    r.equal_run_count = eq_count;
                    r.expected_runs = expected_runs;
                    r.is_full_exact_match = true;
                    rows(end + 1, 1) = r; %#ok<AGROW>
                end
            end
        end
    end

    if ~isempty(rows)
        warning_table = struct2table(rows);
    end
end

function summary_table = rac_apply_exact_match_flags(summary_table, warning_table)
    if ~ismember('exact_match_warning', summary_table.Properties.VariableNames)
        summary_table.exact_match_warning = repmat("", height(summary_table), 1);
    else
        summary_table.exact_match_warning = string(summary_table.exact_match_warning);
    end

    for i = 1:height(warning_table)
        fid = warning_table.function_id(i);
        a = string(warning_table.algorithm_a(i));
        b = string(warning_table.algorithm_b(i));
        msg = sprintf('RED_ALERT: full exact run-level match with %s (F%d, %d/%d).', b, fid, warning_table.equal_run_count(i), warning_table.expected_runs(i));
        idx_a = summary_table.function_id == fid & string(summary_table.algorithm_name) == a;
        summary_table.exact_match_warning(idx_a) = msg;

        msg_b = sprintf('RED_ALERT: full exact run-level match with %s (F%d, %d/%d).', a, fid, warning_table.equal_run_count(i), warning_table.expected_runs(i));
        idx_b = summary_table.function_id == fid & string(summary_table.algorithm_name) == b;
        summary_table.exact_match_warning(idx_b) = msg_b;
    end
end

function curve_out = normalize_export_curve(curve_in, fe_state, used_fes)
    curve_out = curve_in;

    if isstruct(fe_state) && isfield(fe_state, 'best_curve') && ~isempty(fe_state.best_curve)
        fe_curve = fe_state.best_curve(:)';
        if used_fes > 0 && numel(fe_curve) >= used_fes
            curve_out = fe_curve(1:used_fes);
            return;
        end
        curve_out = fe_curve;
        return;
    end

    if ~isempty(curve_out)
        curve_out = curve_out(:)';
    end
end

function release_log_lock(lock_dir)
    if isfolder(lock_dir)
        rmdir(lock_dir, 's');
    end
end

function row = rac_make_rescue_diag_row_template()
    row = struct( ...
        'algorithm_name', '', ...
        'suite', '', ...
        'function_id', 0, ...
        'run_id', 0, ...
        'seed', 0, ...
        'trigger_count', 0, ...
        'success_count', 0, ...
        'success_rate', 0);
end

function row = rac_make_rescue_trigger_event_row_template()
    row = struct( ...
        'algorithm_name', '', ...
        'suite', '', ...
        'function_id', 0, ...
        'run_id', 0, ...
        'seed', 0, ...
        'used_FEs', 0, ...
        'event_id', 0, ...
        'trigger_id', 0, ...
        'iter', 0, ...
        'trigger_fe', 0, ...
        'best_before', 0, ...
        'best_after', 0, ...
        'improve_abs', 0, ...
        'improve_rel', 0, ...
        'success', false);
end

function row = rac_build_rescue_diag_row(algorithm_name, suite_name, fid, run_id, run_seed, diag)
    row = rac_make_rescue_diag_row_template();
    row.algorithm_name = algorithm_name;
    row.suite = suite_name;
    row.function_id = fid;
    row.run_id = run_id;
    row.seed = run_seed;
    row.trigger_count = rac_diag_field(diag, 'trigger_count', 0);
    row.success_count = rac_diag_field(diag, 'success_count', 0);
    row.success_rate = rac_diag_field(diag, 'success_rate', 0);
end

function [rows, row_count] = rac_build_rescue_trigger_event_rows(algorithm_name, suite_name, fid, run_id, run_seed, used_fes, diag)
    rows = repmat(rac_make_rescue_trigger_event_row_template(), 1, 0);
    row_count = 0;
    if ~isstruct(diag) || ~isfield(diag, 'trigger_events')
        return;
    end
    events = diag.trigger_events;
    if isempty(events)
        return;
    end
    if ~isstruct(events)
        return;
    end

    row_count = numel(events);
    rows = repmat(rac_make_rescue_trigger_event_row_template(), 1, row_count);
    for i = 1:row_count
        ev = events(i);
        rows(i).algorithm_name = algorithm_name;
        rows(i).suite = suite_name;
        rows(i).function_id = fid;
        rows(i).run_id = run_id;
        rows(i).seed = run_seed;
        rows(i).used_FEs = used_fes;
        rows(i).event_id = rac_diag_field(ev, 'event_id', i);
        rows(i).trigger_id = rac_diag_field(ev, 'trigger_id', 0);
        rows(i).iter = rac_diag_field(ev, 'iter', 0);
        rows(i).trigger_fe = rac_diag_field(ev, 'trigger_fe', 0);
        rows(i).best_before = rac_diag_field(ev, 'best_before', nan);
        rows(i).best_after = rac_diag_field(ev, 'best_after', nan);
        rows(i).improve_abs = rac_diag_field(ev, 'improve_abs', 0);
        rows(i).improve_rel = rac_diag_field(ev, 'improve_rel', 0);
        rows(i).success = logical(rac_diag_field(ev, 'success', false));
    end
end

function value = rac_diag_field(diag, field_name, default_value)
    value = default_value;
    if isstruct(diag) && isfield(diag, field_name)
        value = diag.(field_name);
    end
    if isempty(value) || ~isfinite(double(value))
        value = default_value;
    end
end

function rac_clear_last_rescue_diag()
    if isappdata(0, 'bbo_rescue_diag_last')
        rmappdata(0, 'bbo_rescue_diag_last');
    end
end

function diag = rac_pull_last_rescue_diag()
    diag = [];
    if ~isappdata(0, 'bbo_rescue_diag_last')
        return;
    end
    tmp = getappdata(0, 'bbo_rescue_diag_last');
    rmappdata(0, 'bbo_rescue_diag_last');
    if ~isstruct(tmp) || ~isfield(tmp, 'algorithm_entry')
        return;
    end
    allowed_entries = [ ...
        "BBO_route_a_budget_adaptive_controlled_rescue_bbo", ...
        "BBO_route_a_budget_adaptive_bbo", ...
        "BBO_route_a_budget_adaptive_success_history_bbo", ...
        "BBO_route_a_budget_adaptive_success_history_dispersal_bbo", ...
        "BBO_route_a_budget_adaptive_archive_only_bbo", ...
        "BBO_route_a_budget_adaptive_archive_replay_bbo", ...
        "BBO_route_a_budget_adaptive_archive_replay_shsa_bbo", ...
        "BBO_route_a_budget_adaptive_archive_dispersal_replay_shsa_bbo"];
    if ~any(strcmpi(string(tmp.algorithm_entry), allowed_entries))
        return;
    end
    diag = tmp;
end

function rac_save_rescue_diagnostics(result_dir, rescue_diag_rows, rescue_trigger_event_rows, suite_cfg)
    if isempty(rescue_diag_rows)
        rescue_diag_table = table( ...
            strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
            zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
            'VariableNames', {'algorithm_name', 'suite', 'function_id', 'run_id', 'seed', 'trigger_count', 'success_count', 'success_rate'});
    else
        rescue_diag_table = struct2table(rescue_diag_rows);
        rescue_diag_table.algorithm_name = string(rescue_diag_table.algorithm_name);
        rescue_diag_table.suite = string(rescue_diag_table.suite);
    end

    csv_path = fullfile(result_dir.root, 'rescue_evidence.csv');
    if suite_cfg.save_csv
        writetable(rescue_diag_table, csv_path);
    end

    summary_path = fullfile(result_dir.root, 'rescue_evidence_summary.csv');
    if isempty(rescue_diag_table)
        rescue_summary = table( ...
            strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
            'VariableNames', {'algorithm_name', 'function_id', 'runs', 'trigger_count', 'success_count', 'success_rate'});
    else
        alg_name = string(rescue_diag_table.algorithm_name);
        groups = findgroups(alg_name, rescue_diag_table.function_id);
        trigger_sum = splitapply(@sum, rescue_diag_table.trigger_count, groups);
        success_sum = splitapply(@sum, rescue_diag_table.success_count, groups);
        run_count = splitapply(@numel, rescue_diag_table.run_id, groups);
        alg = splitapply(@(x) x(1), alg_name, groups);
        fid = splitapply(@(x) x(1), rescue_diag_table.function_id, groups);
        rescue_summary = table(alg, fid, run_count, trigger_sum, success_sum, success_sum ./ max(1, trigger_sum), ...
            'VariableNames', {'algorithm_name', 'function_id', 'runs', 'trigger_count', 'success_count', 'success_rate'});
    end
    if suite_cfg.save_csv
        writetable(rescue_summary, summary_path);
    end

    trigger_csv_path = fullfile(result_dir.root, 'rescue_trigger_events.csv');
    if isempty(rescue_trigger_event_rows)
        trigger_table = table( ...
            strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
            zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), false(0, 1), ...
            'VariableNames', {'algorithm_name', 'suite', 'function_id', 'run_id', 'seed', 'used_FEs', 'event_id', 'trigger_id', 'iter', 'trigger_fe', ...
            'best_before', 'best_after', 'improve_abs', 'improve_rel', 'success'});
    else
        trigger_table = struct2table(rescue_trigger_event_rows);
        trigger_table.algorithm_name = string(trigger_table.algorithm_name);
        trigger_table.suite = string(trigger_table.suite);
    end

    if suite_cfg.save_csv
        writetable(trigger_table, trigger_csv_path);
    end
end
