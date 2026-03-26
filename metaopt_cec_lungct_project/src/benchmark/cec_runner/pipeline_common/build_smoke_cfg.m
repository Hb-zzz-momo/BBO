function smoke_cfg = build_smoke_cfg(cfg, algorithms, func_ids, runs, experiment_name, result_root)
% build_smoke_cfg
% Shared smoke phase config builder.

    smoke_cfg = struct();
    smoke_cfg.suites = cfg.suites;
    smoke_cfg.algorithms = algorithms;
    smoke_cfg.func_ids = func_ids;
    smoke_cfg.dim = cfg.dim;
    smoke_cfg.pop_size = cfg.pop_size;
    smoke_cfg.maxFEs = cfg.maxFEs;
    smoke_cfg.runs = runs;
    smoke_cfg.rng_seed = cfg.rng_seed;
    smoke_cfg.experiment_name = experiment_name;
    smoke_cfg.result_root = result_root;
    if isfield(cfg, 'result_group')
        smoke_cfg.result_group = cfg.result_group;
    end
    if isfield(cfg, 'result_layout')
        smoke_cfg.result_layout = cfg.result_layout;
    end
    smoke_cfg.save_curve = cfg.save_curve;
    smoke_cfg.save_mat = cfg.save_mat;
    smoke_cfg.save_csv = cfg.save_csv;
    smoke_cfg.plot = cfg.plot;
end
