function formal_cfg = build_formal_cfg_common(cfg, algorithms, func_ids, runs, experiment_name, result_root)
% build_formal_cfg_common
% Transitional compat shim. Prefer build_formal_cfg in pipeline_common.

    warning('CECRunner:TransitionalCompat', ...
        'build_formal_cfg_common is transitional compat shim. Prefer build_formal_cfg.');
    formal_cfg = build_formal_cfg(cfg, algorithms, func_ids, runs, experiment_name, result_root);
end
