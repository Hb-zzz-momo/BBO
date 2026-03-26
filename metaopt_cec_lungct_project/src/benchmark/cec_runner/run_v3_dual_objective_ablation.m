function report = run_v3_dual_objective_ablation(cfg)
% run_v3_dual_objective_ablation
% Deprecated root-level compatibility wrapper.

    if nargin < 1
        cfg = struct();
    end

    runner_dir = fileparts(mfilename('fullpath'));
    addpath(fullfile(runner_dir, 'pipeline_common'));
    warning('CECRunner:DeprecatedRootEntry', ...
        'Root run_v3_dual_objective_ablation is deprecated. Prefer pipelines/run_v3_dual_objective_ablation.');
    report = run_v3_dual_objective_ablation_impl(cfg);
end
