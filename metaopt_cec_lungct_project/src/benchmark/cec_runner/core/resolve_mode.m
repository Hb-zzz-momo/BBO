function [run_cfg, mode_info] = resolve_mode(cfg)
% resolve_mode
% Mode resolver wrapper to keep core entry stable while reusing old logic.

    [run_cfg, mode_info] = resolve_experiment_mode(cfg);
end
