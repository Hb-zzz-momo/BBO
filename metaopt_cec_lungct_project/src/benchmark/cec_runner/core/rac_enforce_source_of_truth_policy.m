function report = rac_enforce_source_of_truth_policy(cfg)
% rac_enforce_source_of_truth_policy
% Fail fast when runner code references raw-package literals outside the resolver allowlist.

    if nargin < 1
        cfg = struct();
    end
    if ~isfield(cfg, 'throw_on_violation')
        cfg.throw_on_violation = true;
    end

    common_paths = rac_resolve_common_paths();
    runner_dir = fullfile(common_paths.repo_root, 'src', 'benchmark', 'cec_runner');
    files = dir(fullfile(runner_dir, '**', '*.m'));

    allowlist = string({ ...
        fullfile(runner_dir, 'core', 'rac_resolve_common_paths.m'), ...
        fullfile(runner_dir, 'core', 'rac_enforce_source_of_truth_policy.m')});

    raw_patterns = { ...
        'Source_code_BBO_MATLAB_VERSION_extracted', ...
        'Status_based_Optimization_SBO_MATLAB_codes_extracted'};
    archive_patterns = { ...
        'archive/achieve/reference_only', ...
        'archive\achieve\reference_only'};

    violations = strings(0, 1);
    for i = 1:numel(files)
        file_path = string(fullfile(files(i).folder, files(i).name));
        if any(strcmpi(file_path, allowlist))
            continue;
        end

        txt = fileread(file_path);
        if contains_any(txt, raw_patterns) || contains_any(txt, archive_patterns)
            violations(end + 1, 1) = file_path; %#ok<AGROW>
        end
    end

    report = struct();
    report.pass = isempty(violations);
    report.violations = violations;

    if ~report.pass && cfg.throw_on_violation
        error('CECRunner:SourceOfTruthViolation', ...
            'Runner source-of-truth policy violated by:%s%s', newline, strjoin(cellstr(violations), newline));
    end
end

function tf = contains_any(txt, patterns)
    tf = false;
    for i = 1:numel(patterns)
        if contains(txt, patterns{i})
            tf = true;
            return;
        end
    end
end
