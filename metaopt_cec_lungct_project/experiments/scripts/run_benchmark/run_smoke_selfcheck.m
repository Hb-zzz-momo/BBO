function check = run_smoke_selfcheck(cfg)
% run_smoke_selfcheck
% Minimal smoke self-check for refactor compatibility.

    if nargin < 1
        cfg = struct();
    end

    if ~isfield(cfg, 'mode') || isempty(cfg.mode)
        cfg.mode = 'smoke';
    end
    if ~isfield(cfg, 'smoke') || ~isstruct(cfg.smoke)
        cfg.smoke = struct();
    end
    if ~isfield(cfg.smoke, 'runs')
        cfg.smoke.runs = 1;
    end
    if ~isfield(cfg.smoke, 'func_ids') || isempty(cfg.smoke.func_ids)
        cfg.smoke.func_ids = struct('cec2017', 1, 'cec2022', 1);
    end

    report = run_benchmark(cfg);

    check = struct();
    check.pass = true;
    check.errors = {};
    check.report = report;

    if ~isfield(report, 'output') || ~isfield(report.output, 'suite_results') || isempty(report.output.suite_results)
        check.pass = false;
        check.errors{end + 1} = 'output.suite_results missing'; %#ok<AGROW>
        return;
    end

    for i = 1:numel(report.output.suite_results)
        suite_result = report.output.suite_results(i);
        required_files = { ...
            'summary.csv', ...
            'summary.mat', ...
            'protocol_snapshot.csv', ...
            'protocol_snapshot.mat'};

        for k = 1:numel(required_files)
            fp = fullfile(suite_result.result_dir, required_files{k});
            if ~isfile(fp)
                check.pass = false;
                check.errors{end + 1} = ['missing_file:' fp]; %#ok<AGROW>
            end
        end
    end
end
