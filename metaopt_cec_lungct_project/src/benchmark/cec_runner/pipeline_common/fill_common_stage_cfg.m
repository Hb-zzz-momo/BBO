function cfg = fill_common_stage_cfg(cfg)
% fill_common_stage_cfg
% Shared defaults for stage runners to avoid duplicated protocol fields.

    if nargin < 1 || isempty(cfg)
        cfg = struct();
    end

    % Reuse the global default source to keep stage and core semantics aligned.
    cfg = default_experiment_config(cfg);

    if ~isfield(cfg, 'use_core_entry')
        if isfield(cfg, 'use_unified_entry')
            cfg.use_core_entry = logical(cfg.use_unified_entry);
        else
            cfg.use_core_entry = true;
        end
    end
    if ~isfield(cfg, 'use_unified_entry')
        cfg.use_unified_entry = false;
    end
end
