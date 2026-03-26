function smoke_cfg = build_smoke_cfg_common(cfg, algorithms, func_ids, runs, experiment_name, result_root)
% build_smoke_cfg_common
% Transitional compat shim. Prefer build_smoke_cfg in pipeline_common.

    warning('CECRunner:TransitionalCompat', ...
        'build_smoke_cfg_common is transitional compat shim. Prefer build_smoke_cfg.');
    smoke_cfg = build_smoke_cfg(cfg, algorithms, func_ids, runs, experiment_name, result_root);
end
