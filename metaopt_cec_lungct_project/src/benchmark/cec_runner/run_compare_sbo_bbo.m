function output = run_compare_sbo_bbo(cfg)
% run_compare_sbo_bbo
% Deprecated root-level compatibility wrapper.

    if nargin < 1
        cfg = struct();
    end

    runner_dir = fileparts(mfilename('fullpath'));
    addpath(fullfile(runner_dir, 'pipeline_common'));
    warning('CECRunner:DeprecatedRootEntry', ...
        'Root run_compare_sbo_bbo is deprecated. Prefer pipelines/run_compare_sbo_bbo.');
    output = run_compare_sbo_bbo_impl(cfg);
end
