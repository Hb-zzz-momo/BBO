function report = run_bbo_research_pipeline(cfg)
% run_bbo_research_pipeline
% Canonical stage entry for the BBO research workflow.

    if nargin < 1
        cfg = struct();
    end

    this_dir = fileparts(mfilename('fullpath'));
    runner_dir = fileparts(this_dir);
    addpath(fullfile(runner_dir, 'pipeline_common'));
    report = run_bbo_research_pipeline_impl(cfg);
end
