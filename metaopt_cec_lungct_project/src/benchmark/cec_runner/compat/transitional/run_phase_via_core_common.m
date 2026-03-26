function phase_report = run_phase_via_core_common(phase_cfg, mode_name)
% run_phase_via_core_common
% Transitional compat shim. Prefer run_phase_via_core in pipeline_common.

    warning('CECRunner:TransitionalCompat', ...
        'run_phase_via_core_common is transitional compat shim. Prefer run_phase_via_core.');
    phase_report = run_phase_via_core(phase_cfg, mode_name);
end
