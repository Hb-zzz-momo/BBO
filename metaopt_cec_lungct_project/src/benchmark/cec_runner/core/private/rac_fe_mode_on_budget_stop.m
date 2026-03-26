function [fe_mode, fe_note] = rac_fe_mode_on_budget_stop(alg)
    fe_mode = sprintf('%s_with_hard_stop', alg.fe_control_mode);
    fe_note = 'Counted objective wrapper stopped the run exactly at maxFEs.';
end
