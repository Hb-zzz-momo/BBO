function phase_report = run_phase_via_unified_common(phase_cfg, mode_name)
% run_phase_via_unified_common
% Transitional compat shim. Prefer run_phase_via_unified in pipeline_common.

    warning('CECRunner:TransitionalCompat', ...
        'run_phase_via_unified_common is transitional compat shim. Prefer run_phase_via_unified.');
    phase_report = run_phase_via_unified(phase_cfg, mode_name);
end
