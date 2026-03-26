function report = run_benchmark(cfg)
% run_benchmark
% Stage script for benchmark execution. Long-term logic stays in cec_runner/core.

    if nargin < 1
        cfg = struct();
    end

    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    repo_root = fullfile(this_dir, '..', '..', '..');

    addpath(fullfile(repo_root, 'src', 'benchmark', 'cec_runner', 'entry'));

    report = run_main_entry(cfg);
end
