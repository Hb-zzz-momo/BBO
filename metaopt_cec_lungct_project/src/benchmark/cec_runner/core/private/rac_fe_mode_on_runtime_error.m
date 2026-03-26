function [fe_mode, fe_note] = rac_fe_mode_on_runtime_error(alg)
    fe_mode = sprintf('%s_with_runtime_error', alg.fe_control_mode);
    fe_note = 'Run ended with runtime error; output uses tracked FE state before failure.';
end
