function run_state = rac_execute_single_run(alg, suite_name, fid, current_dim, run_id, suite_idx, func_idx, alg_idx, suite_cfg, lb, ub, fobj, log_file, compat_dir)
% rac_execute_single_run
% Execute one algorithm run with FE counting, rescue diagnostics, and manifest metadata.

    if isfield(suite_cfg, 'seed_list') && ~isempty(suite_cfg.seed_list)
        run_seed = double(suite_cfg.seed_list(run_id));
    else
        run_seed = rac_derive_run_seed(suite_cfg.rng_seed, suite_idx, func_idx, alg_idx, run_id, alg.name);
    end
    rng(run_seed, 'twister');
    local_clear_last_rescue_diag();

    if exist('unifrnd', 'file') ~= 2
        addpath(compat_dir, '-begin');
        rac_log_message(log_file, sprintf('Re-activated compat fallback path for %s (unifrnd missing before run).', alg.name));
    end

    trace_request = rac_make_plot_trace_request(suite_cfg.plot, alg.name, fid, current_dim);
    [counted_fobj, get_fe_state] = rac_make_counted_objective( ...
        fobj, suite_cfg.maxFEs, suite_cfg.hard_stop_on_fe_limit, trace_request, suite_cfg.pop_size);

    t0 = tic;
    status = 'completed';
    error_message = '';
    try
        [best_score, best_pos, curve, fe_control_mode, fe_note] = rac_run_one_algorithm( ...
            alg, suite_cfg.pop_size, suite_cfg.maxFEs, lb, ub, current_dim, counted_fobj);
    catch ME
        status = 'failed';
        if strcmp(ME.identifier, 'CECRunner:MaxFEsReached')
            status = 'stopped_at_budget';
            fe_state = get_fe_state();
            best_score = fe_state.best_score;
            best_pos = fe_state.best_position;
            curve = fe_state.best_curve;
            [fe_control_mode, fe_note] = rac_fe_mode_on_budget_stop(alg);
            error_message = ME.message;
        else
            fe_state = get_fe_state();
            best_score = fe_state.best_score;
            best_pos = fe_state.best_position;
            curve = fe_state.best_curve;
            [fe_control_mode, fe_note] = rac_fe_mode_on_runtime_error(alg);
            error_message = ME.message;
            if ~isempty(ME.stack)
                top_stack = ME.stack(1);
                rac_log_message(log_file, sprintf('ERROR %s F%d run %d/%d: [%s] %s | at %s:%d', ...
                    alg.name, fid, run_id, suite_cfg.runs, ME.identifier, ME.message, top_stack.name, top_stack.line));
            else
                rac_log_message(log_file, sprintf('ERROR %s F%d run %d/%d: [%s] %s', ...
                    alg.name, fid, run_id, suite_cfg.runs, ME.identifier, ME.message));
            end
        end
    end
    runtime = toc(t0);
    rescue_diag = local_pull_last_rescue_diag();

    fe_state = get_fe_state();
    used_fes = fe_state.used_FEs;
    curve = local_normalize_export_curve(curve, fe_state, used_fes);

    run_state = struct();
    run_state.run_result = rac_build_run_result( ...
        alg.name, suite_name, fid, run_id, best_score, best_pos, curve, runtime, run_seed, ...
        current_dim, suite_cfg.pop_size, suite_cfg.maxFEs, used_fes, fe_control_mode, fe_note, fe_state.behavior_trace);
    run_state.manifest_row = rac_build_manifest_row( ...
        alg.name, suite_name, fid, run_id, run_seed, suite_cfg.maxFEs, used_fes, ...
        fe_control_mode, status, error_message);
    run_state.has_rescue_diag = ~isempty(rescue_diag);
    run_state.rescue_diag_row = local_make_rescue_diag_row_template();
    run_state.rescue_event_rows = repmat(local_make_rescue_trigger_event_row_template(), 1, 0);
    run_state.rescue_event_count = 0;

    if run_state.has_rescue_diag
        run_state.rescue_diag_row = local_build_rescue_diag_row(alg.name, suite_name, fid, run_id, run_seed, rescue_diag);
        [run_state.rescue_event_rows, run_state.rescue_event_count] = local_build_rescue_trigger_event_rows( ...
            alg.name, suite_name, fid, run_id, run_seed, used_fes, rescue_diag);
    end

    rac_log_message(log_file, sprintf('Done %s F%d run %d/%d: best=%.12g, used_FEs=%d/%d, t=%.4fs, mode=%s, status=%s', ...
        alg.name, fid, run_id, suite_cfg.runs, best_score, used_fes, suite_cfg.maxFEs, runtime, fe_control_mode, status));
end

function curve_out = local_normalize_export_curve(curve_in, fe_state, used_fes)
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

function row = local_make_rescue_diag_row_template()
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

function row = local_make_rescue_trigger_event_row_template()
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

function row = local_build_rescue_diag_row(algorithm_name, suite_name, fid, run_id, run_seed, diag)
    row = local_make_rescue_diag_row_template();
    row.algorithm_name = algorithm_name;
    row.suite = suite_name;
    row.function_id = fid;
    row.run_id = run_id;
    row.seed = run_seed;
    row.trigger_count = local_diag_field(diag, 'trigger_count', 0);
    row.success_count = local_diag_field(diag, 'success_count', 0);
    row.success_rate = local_diag_field(diag, 'success_rate', 0);
end

function [rows, row_count] = local_build_rescue_trigger_event_rows(algorithm_name, suite_name, fid, run_id, run_seed, used_fes, diag)
    rows = repmat(local_make_rescue_trigger_event_row_template(), 1, 0);
    row_count = 0;
    if ~isstruct(diag) || ~isfield(diag, 'trigger_events')
        return;
    end
    events = diag.trigger_events;
    if isempty(events) || ~isstruct(events)
        return;
    end

    row_count = numel(events);
    rows = repmat(local_make_rescue_trigger_event_row_template(), 1, row_count);
    for i = 1:row_count
        ev = events(i);
        rows(i).algorithm_name = algorithm_name;
        rows(i).suite = suite_name;
        rows(i).function_id = fid;
        rows(i).run_id = run_id;
        rows(i).seed = run_seed;
        rows(i).used_FEs = used_fes;
        rows(i).event_id = local_diag_field(ev, 'event_id', i);
        rows(i).trigger_id = local_diag_field(ev, 'trigger_id', 0);
        rows(i).iter = local_diag_field(ev, 'iter', 0);
        rows(i).trigger_fe = local_diag_field(ev, 'trigger_fe', 0);
        rows(i).best_before = local_diag_field(ev, 'best_before', nan);
        rows(i).best_after = local_diag_field(ev, 'best_after', nan);
        rows(i).improve_abs = local_diag_field(ev, 'improve_abs', 0);
        rows(i).improve_rel = local_diag_field(ev, 'improve_rel', 0);
        rows(i).success = logical(local_diag_field(ev, 'success', false));
    end
end

function value = local_diag_field(diag, field_name, default_value)
    value = default_value;
    if isstruct(diag) && isfield(diag, field_name)
        value = diag.(field_name);
    end
    if isempty(value) || ~isfinite(double(value))
        value = default_value;
    end
end

function local_clear_last_rescue_diag()
    if isappdata(0, 'bbo_rescue_diag_last')
        rmappdata(0, 'bbo_rescue_diag_last');
    end
end

function diag = local_pull_last_rescue_diag()
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
    if isfield(tmp, 'diag') && isstruct(tmp.diag)
        diag = tmp.diag;
    end
end
