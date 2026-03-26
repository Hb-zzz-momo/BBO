function state = success_history_step_controller(action, state, value, cfg)
% success_history_step_controller
% Lightweight success-history step-size memory for Route A budget-adaptive variants.
% Why this module exists: keep step adaptation logic outside algorithm loop body.

    switch lower(string(action))
        case "init"
            state = struct();
            state.mu_step = cfg.init_mu_step;
            state.success_scales = zeros(1, 0);
            state.max_hist = cfg.max_hist;

        case "record"
            if isempty(state)
                state = success_history_step_controller("init", state, [], cfg);
            end
            s = max(cfg.step_scale_min, min(cfg.step_scale_max, value));
            state.success_scales(end + 1) = s; %#ok<AGROW>
            if numel(state.success_scales) > state.max_hist
                state.success_scales = state.success_scales(end - state.max_hist + 1:end);
            end

        case "update"
            if isempty(state) || isempty(state.success_scales)
                return;
            end
            target = mean(state.success_scales);
            state.mu_step = (1 - cfg.mu_lr) * state.mu_step + cfg.mu_lr * target;
            state.mu_step = max(cfg.step_scale_min, min(cfg.step_scale_max, state.mu_step));
            state.success_scales = zeros(1, 0);

        otherwise
            error('Unsupported success_history_step_controller action: %s', action);
    end
end
