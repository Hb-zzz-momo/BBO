function rac_persist_run_artifacts(result_dir, run_result, suite_cfg)
% rac_persist_run_artifacts
% Persist per-run numeric artifacts without changing orchestration flow.

    rac_save_single_run(result_dir, run_result, suite_cfg);
    if suite_cfg.save_curve
        rac_save_curve_file(result_dir, run_result, suite_cfg);
    end
end
