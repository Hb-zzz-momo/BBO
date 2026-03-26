function formal_cfg = build_formal_cfg(cfg, algorithms, func_ids, runs, experiment_name, result_root)
% build_formal_cfg
% Shared formal phase config builder.

    formal_cfg = struct();
    formal_cfg.suites = cfg.suites;
    formal_cfg.algorithms = algorithms;
    formal_cfg.func_ids = func_ids;
    formal_cfg.dim = cfg.dim;
    formal_cfg.pop_size = cfg.pop_size;
    formal_cfg.maxFEs = cfg.maxFEs;
    formal_cfg.runs = runs;
    formal_cfg.rng_seed = cfg.rng_seed;
    formal_cfg.experiment_name = experiment_name;
    formal_cfg.result_root = result_root;
    if isfield(cfg, 'result_group')
        formal_cfg.result_group = cfg.result_group;
    end
    if isfield(cfg, 'result_layout')
        formal_cfg.result_layout = cfg.result_layout;
    end
    formal_cfg.save_curve = cfg.save_curve;
    formal_cfg.save_mat = cfg.save_mat;
    formal_cfg.save_csv = cfg.save_csv;
    formal_cfg.plot = cfg.plot;
end
