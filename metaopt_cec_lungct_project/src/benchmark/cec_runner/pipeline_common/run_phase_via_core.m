function phase_report = run_phase_via_core(phase_cfg, mode_name)
% run_phase_via_core
% Default bridge from stage phase config to core/run_experiment.

    this_file = mfilename('fullpath');
    common_dir = fileparts(this_file);
    runner_dir = fileparts(common_dir);
    addpath(fullfile(runner_dir, 'core'));

    core_cfg = struct();
    core_cfg.mode = mode_name;
    core_cfg.suites = phase_cfg.suites;
    core_cfg.algorithms = phase_cfg.algorithms;
    core_cfg.dim = phase_cfg.dim;
    core_cfg.pop_size = phase_cfg.pop_size;
    core_cfg.maxFEs = phase_cfg.maxFEs;
    core_cfg.rng_seed = phase_cfg.rng_seed;
    core_cfg.result_root = phase_cfg.result_root;
    if isfield(phase_cfg, 'result_group')
        core_cfg.result_group = phase_cfg.result_group;
    end
    if isfield(phase_cfg, 'result_layout')
        core_cfg.result_layout = phase_cfg.result_layout;
    end
    core_cfg.save_curve = phase_cfg.save_curve;
    core_cfg.save_mat = phase_cfg.save_mat;
    core_cfg.save_csv = phase_cfg.save_csv;
    core_cfg.plot = phase_cfg.plot;
    core_cfg.explicit_experiment_name = phase_cfg.experiment_name;
    core_cfg.export = struct('summary_markdown', true);

    core_cfg.smoke = struct('runs', phase_cfg.runs, 'func_ids', phase_cfg.func_ids);
    core_cfg.formal = struct('runs', phase_cfg.runs, 'func_ids', phase_cfg.func_ids);

    phase_report = run_experiment(core_cfg);
end
