function report = run_bbo_research_pipeline(cfg)
% run_bbo_research_pipeline
% Deprecated root-level compatibility wrapper.

    if nargin < 1
        cfg = struct();
    end

    runner_dir = fileparts(mfilename('fullpath'));
    addpath(fullfile(runner_dir, 'pipeline_common'));
    warning('CECRunner:DeprecatedRootEntry', ...
        'Root run_bbo_research_pipeline is deprecated. Prefer pipelines/run_bbo_research_pipeline.');
    report = run_bbo_research_pipeline_impl(cfg);
end
