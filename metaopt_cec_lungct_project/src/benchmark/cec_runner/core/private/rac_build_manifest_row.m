function manifest_row = rac_build_manifest_row(algorithm_name, suite_name, function_id, run_id, seed, maxFEs, used_FEs, fe_control_mode, status, error_message)
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
