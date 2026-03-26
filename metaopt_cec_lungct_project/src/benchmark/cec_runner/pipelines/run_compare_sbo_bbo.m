function output = run_compare_sbo_bbo(cfg)
% run_compare_sbo_bbo
% Canonical pipeline entry for SBO vs BBO comparison.

    if nargin < 1
        cfg = struct();
    end

    this_dir = fileparts(mfilename('fullpath'));
    runner_dir = fileparts(this_dir);
    addpath(fullfile(runner_dir, 'pipeline_common'));
    output = run_compare_sbo_bbo_impl(cfg);
end
