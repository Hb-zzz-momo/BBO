function phase_report = run_phase_via_unified(phase_cfg, mode_name)
% run_phase_via_unified
% Compatibility shim.
% Default stage execution should use run_phase_via_core.

    warning('CECRunner:CompatShim', ...
        'run_phase_via_unified is compatibility shim. Stage default path is run_phase_via_core.');
    phase_report = run_phase_via_core(phase_cfg, mode_name);
end
