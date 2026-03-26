function report = run_experiment_unified(cfg)
% run_experiment_unified
% Compatibility entry.
% Why: keep legacy API stable while delegating to core/run_experiment.

    if nargin < 1
        cfg = struct();
    end

    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    runner_dir = fileparts(this_dir);
    addpath(fullfile(runner_dir, 'core'));

    warning('CECRunner:LegacyEntry', ...
        'run_experiment_unified is legacy compatibility entry. Prefer entry/run_main_entry for human-triggered experiments.');

    report = run_experiment(cfg);
end
