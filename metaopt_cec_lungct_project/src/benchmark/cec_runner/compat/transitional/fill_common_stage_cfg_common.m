function cfg = fill_common_stage_cfg_common(cfg)
% fill_common_stage_cfg_common
% Transitional compat shim. Prefer fill_common_stage_cfg in pipeline_common.

    warning('CECRunner:TransitionalCompat', ...
        'fill_common_stage_cfg_common is transitional compat shim. Prefer fill_common_stage_cfg.');
    cfg = fill_common_stage_cfg(cfg);
end
