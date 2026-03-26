function report = run_v3_dual_objective_ablation(cfg)
% run_v3_dual_objective_ablation
% Canonical stage entry for dual-objective ablation.

    if nargin < 1
        cfg = struct();
    end

    this_dir = fileparts(mfilename('fullpath'));
    runner_dir = fileparts(this_dir);
    addpath(fullfile(runner_dir, 'pipeline_common'));
    report = run_v3_dual_objective_ablation_impl(cfg);
end
