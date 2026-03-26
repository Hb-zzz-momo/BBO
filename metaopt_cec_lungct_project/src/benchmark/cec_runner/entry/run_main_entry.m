function report = run_main_entry(cfg)
% run_main_entry
% Recommended human-facing main entry for benchmark experiments.
% Why: remove ambiguity among multiple legacy/stage runners.

    if nargin < 1
        cfg = struct();
    end

    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    runner_dir = fileparts(this_dir);
    addpath(fullfile(runner_dir, 'core'));

    report = run_experiment(cfg);
end
