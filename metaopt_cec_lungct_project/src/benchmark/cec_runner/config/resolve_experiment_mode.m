function [run_cfg, mode_info] = resolve_experiment_mode(cfg)
% resolve_experiment_mode
% Convert unified config into benchmark-kernel config for smoke/formal.

    mode = lower(string(cfg.mode));
    if mode ~= "smoke" && mode ~= "formal"
        error('Unsupported mode: %s. Use smoke or formal.', cfg.mode);
    end

    run_cfg = struct();
    run_cfg.suites = cfg.suites;

    if isfield(cfg, 'algorithms') && ~isempty(cfg.algorithms)
        run_cfg.algorithms = cfg.algorithms;
    else
        profile = cfg.algorithm_profile;
        if mode == "smoke"
            profile = 'smoke_minimal';
        end
        reg = algorithm_registry(profile);
        run_cfg.algorithms = reg.selected;
        run_cfg.algorithm_registry_profile = reg.profile;
    end

    run_cfg.dim = cfg.dim;
    run_cfg.pop_size = cfg.pop_size;
    run_cfg.maxFEs = cfg.maxFEs;
    run_cfg.rng_seed = cfg.rng_seed;
    if isfield(cfg, 'seed_list') && ~isempty(cfg.seed_list)
        run_cfg.seed_list = cfg.seed_list;
    end
    run_cfg.result_root = cfg.result_root;
    run_cfg.result_group = cfg.result_group;
    run_cfg.result_layout = cfg.result_layout;
    run_cfg.save_curve = cfg.save_curve;
    run_cfg.save_mat = cfg.save_mat;
    run_cfg.save_csv = cfg.save_csv;
    run_cfg.hard_stop_on_fe_limit = cfg.hard_stop_on_fe_limit;
    run_cfg.plot = cfg.plot;

    if mode == "smoke"
        run_cfg.runs = cfg.smoke.runs;
        validate_seed_list_if_present(run_cfg, cfg.smoke.runs, 'smoke');
        run_cfg.func_ids = cfg.smoke.func_ids;
        if isfield(cfg, 'explicit_experiment_name') && ~isempty(cfg.explicit_experiment_name)
            run_cfg.experiment_name = char(cfg.explicit_experiment_name);
        else
            run_cfg.experiment_name = sprintf('%s_smoke_%s', cfg.experiment_name_base, cfg.timestamp);
        end
    else
        run_cfg.runs = cfg.formal.runs;
        validate_seed_list_if_present(run_cfg, cfg.formal.runs, 'formal');
        run_cfg.func_ids = cfg.formal.func_ids;
        if isfield(cfg, 'explicit_experiment_name') && ~isempty(cfg.explicit_experiment_name)
            run_cfg.experiment_name = char(cfg.explicit_experiment_name);
        else
            run_cfg.experiment_name = sprintf('%s_formal_%s', cfg.experiment_name_base, cfg.timestamp);
        end
    end

    mode_info = struct();
    mode_info.mode = char(mode);
    mode_info.timestamp = cfg.timestamp;
    mode_info.objective_wrapper_note = cfg.objective_wrapper_note;
    mode_info.objective_wrapper_hook_defined = ~isempty(cfg.objective_wrapper_hook);
end

function validate_seed_list_if_present(run_cfg, expected_runs, mode_name)
    if ~isfield(run_cfg, 'seed_list') || isempty(run_cfg.seed_list)
        return;
    end

    seed_list = double(run_cfg.seed_list(:)');
    if any(~isfinite(seed_list))
        error('resolve_experiment_mode:InvalidSeedList', 'seed_list contains non-finite values.');
    end
    if numel(seed_list) ~= expected_runs
        error('resolve_experiment_mode:SeedListLengthMismatch', ...
            'seed_list length (%d) must equal %s runs (%d).', numel(seed_list), mode_name, expected_runs);
    end
end
