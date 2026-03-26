function output = run_all_compare(cfg)
% run_all_compare
% Compatibility entry kept for historical scripts.
% Why: converge execution to core pipeline and avoid duplicated kernels.

    if nargin < 1
        cfg = struct();
    end

    runner_dir = fileparts(mfilename('fullpath'));
    addpath(fullfile(runner_dir, 'entry'));
    addpath(fullfile(runner_dir, 'core'));

    warning('CECRunner:DeprecatedRootEntry', ...
        'run_all_compare is a compatibility entry. Prefer entry/run_main_entry or pipelines/*.m.');

    report = run_main_entry(cfg);
    output = report.output;
end
