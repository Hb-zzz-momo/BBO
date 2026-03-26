function output = run_compare_sbo_bbo(cfg)
% run_compare_sbo_bbo
% Legacy compatibility wrapper.

    if nargin < 1
        cfg = struct();
    end

    this_dir = fileparts(mfilename('fullpath'));
    runner_dir = fileparts(this_dir);
    addpath(fullfile(runner_dir, 'pipeline_common'));
    warning('CECRunner:LegacyEntry', ...
        'legacy/run_compare_sbo_bbo is deprecated. Prefer pipelines/run_compare_sbo_bbo.');
    output = run_compare_sbo_bbo_impl(cfg);
end
