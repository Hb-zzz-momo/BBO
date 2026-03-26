function report = run_experiment(cfg)
% run_experiment
% Unified benchmark entry (core).
% Why: keep execution chain short: normalize -> resolve -> run -> export.

    if nargin < 1
        cfg = struct();
    end

    setup_benchmark_paths();
    rac_enforce_source_of_truth_policy();

    cfg = normalize_config(cfg);
    [run_cfg, mode_info] = resolve_mode(cfg);

    if strcmpi(mode_info.mode, 'formal')
        gate = rac_formal_input_data_gate(run_cfg);
        mode_info.formal_input_data_gate = gate;
        if ~gate.pass
            error('Formal preflight gate failed:\n%s', strjoin(gate.errors, newline));
        end
    end

    output = run_suite_batch(run_cfg);

    suite_count = numel(output.suite_results);
    exports = struct([]);
    for i = 1:suite_count
        suite_result = output.suite_results(i);

        snapshot = build_protocol_snapshot(run_cfg, mode_info);
        save_protocol_snapshot(suite_result.result_dir, snapshot);

        current_export = export_benchmark_aggregate( ...
            suite_result.result_dir, ...
            suite_result.summary, ...
            run_cfg, ...
            mode_info, ...
            cfg.export);

        if i == 1
            exports = repmat(current_export, 1, suite_count);
        end
        exports(i) = current_export;

        if isfield(cfg.export, 'summary_markdown') && cfg.export.summary_markdown
            export_experiment_summary_md( ...
                fullfile(suite_result.result_dir, 'experiment_summary.md'), ...
                suite_result, ...
                run_cfg, ...
                mode_info, ...
                current_export);
        end

        export_improved_algorithm_notes_md( ...
            suite_result.result_dir, ...
            suite_result.summary, ...
            run_cfg);

        if isfield(cfg, 'localize_output_files_zh') && cfg.localize_output_files_zh
            if isfield(cfg, 'output_language') && strcmpi(string(cfg.output_language), "zh")
                localize_output_files_zh(suite_result.result_dir);
            end
        end
    end

    report = struct();
    report.input_cfg = cfg;
    report.run_cfg = run_cfg;
    report.mode_info = mode_info;
    report.output = output;
    report.exports = exports;
end

function snapshot = build_protocol_snapshot(run_cfg, mode_info)
    snapshot = struct();
    snapshot.mode = mode_info.mode;
    snapshot.timestamp = mode_info.timestamp;
    snapshot.run_cfg = run_cfg;
    snapshot.objective_wrapper_note = mode_info.objective_wrapper_note;
    snapshot.objective_wrapper_hook_defined = mode_info.objective_wrapper_hook_defined;
end
