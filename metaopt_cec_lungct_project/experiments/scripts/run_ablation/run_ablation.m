function report = run_ablation(cfg)
% run_ablation
% Stage script wrapper. Keeps experiment orchestration outside long-term core files.

    if nargin < 1
        cfg = struct();
    end

    if ~isfield(cfg, 'ablation_runner') || isempty(cfg.ablation_runner)
        cfg.ablation_runner = 'v3_direction_reduced';
    end

    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    repo_root = fullfile(this_dir, '..', '..', '..');
    pipelines_dir = fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'pipelines');
    addpath(pipelines_dir);

    switch lower(string(cfg.ablation_runner))
        case "v3_direction_reduced"
            report = run_v3_direction_reduced_ablation(cfg);
        case "v3_dual_objective"
            report = run_v3_dual_objective_ablation(cfg);
        otherwise
            error('Unsupported ablation_runner: %s', cfg.ablation_runner);
    end
end
