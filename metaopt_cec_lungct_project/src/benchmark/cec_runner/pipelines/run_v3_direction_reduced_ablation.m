function report = run_v3_direction_reduced_ablation(cfg)
% run_v3_direction_reduced_ablation
% Canonical stage entry for reduced directional ablation.

    if nargin < 1
        cfg = struct();
    end

    this_dir = fileparts(mfilename('fullpath'));
    runner_dir = fileparts(this_dir);
    addpath(fullfile(runner_dir, 'pipeline_common'));
    report = run_v3_direction_reduced_ablation_impl(cfg);
end
