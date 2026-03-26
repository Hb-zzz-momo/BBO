function cfg = normalize_config(cfg)
% normalize_config
% Normalize and validate unified benchmark config via existing defaults.

    if nargin < 1 || isempty(cfg)
        cfg = struct();
    end

    cfg = default_experiment_config(cfg);
end
