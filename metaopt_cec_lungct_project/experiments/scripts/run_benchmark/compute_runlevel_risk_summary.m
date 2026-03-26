function out = compute_runlevel_risk_summary(result_dir, baseline_algorithm_name)
% compute_runlevel_risk_summary
% Export run-level final-value distribution and bad-run statistics from curve files.
% bad-run threshold per function: baseline median + 1.5 * baseline IQR.

    if nargin < 2 || strlength(string(baseline_algorithm_name)) == 0
        baseline_algorithm_name = 'ROUTE_A_BUDGET_ADAPTIVE_BBO';
    end

    curves_dir = fullfile(result_dir, 'curves');
    if ~exist(curves_dir, 'dir')
        error('Curves dir not found: %s', curves_dir);
    end

    files = dir(fullfile(curves_dir, '*_curve.csv'));
    if isempty(files)
        error('No curve files found in %s', curves_dir);
    end

    rows = repmat(struct('algorithm_name', '', 'function_id', 0, 'run_id', 0, 'final_value', 0), 0, 1);

    for i = 1:numel(files)
        fn = files(i).name;
        tk = regexp(fn, '^(.*)_F(\d+)_run(\d+)_curve\.csv$', 'tokens', 'once');
        if isempty(tk)
            continue;
        end

        curve = readmatrix(fullfile(files(i).folder, fn));
        curve = curve(:);
        if isempty(curve)
            continue;
        end

        r = struct();
        r.algorithm_name = char(upper(string(tk{1})));
        r.function_id = str2double(tk{2});
        r.run_id = str2double(tk{3});
        r.final_value = curve(end);
        rows(end + 1, 1) = r; %#ok<AGROW>
    end

    T = struct2table(rows);
    if isempty(T)
        error('No valid run-level rows parsed from curves.');
    end

    fids = unique(T.function_id, 'stable');
    bad_tbl = repmat(struct('algorithm_name', '', 'function_id', 0, 'bad_run_count', 0, 'bad_run_ratio', 0, 'bad_threshold', 0), 0, 1);
    mark_bad = false(height(T), 1);

    for k = 1:numel(fids)
        fid = fids(k);
        b = T(strcmpi(T.algorithm_name, baseline_algorithm_name) & T.function_id == fid, :);
        if isempty(b)
            continue;
        end

        q = quantile(b.final_value, [0.25, 0.50, 0.75]);
        iqr_val = q(3) - q(1);
        thr = q(2) + 1.5 * iqr_val;

        idx_f = T.function_id == fid;
        mark_bad(idx_f) = T.final_value(idx_f) > thr;

        algs = unique(T.algorithm_name(idx_f), 'stable');
        for i = 1:numel(algs)
            m = idx_f & strcmpi(T.algorithm_name, algs{i});
            rr = struct();
            rr.algorithm_name = char(algs{i});
            rr.function_id = fid;
            rr.bad_run_count = sum(mark_bad(m));
            rr.bad_run_ratio = sum(mark_bad(m)) / max(1, sum(m));
            rr.bad_threshold = thr;
            bad_tbl(end + 1, 1) = rr; %#ok<AGROW>
        end
    end

    T.bad_run = mark_bad;

    dist_tbl = groupsummary(T, {'algorithm_name', 'function_id'}, {'mean', 'std', 'min', 'max', 'median'}, 'final_value');

    uq = unique(T(:, {'algorithm_name', 'function_id'}), 'rows', 'stable');
    uq.p10 = zeros(height(uq), 1);
    uq.p25 = zeros(height(uq), 1);
    uq.p50 = zeros(height(uq), 1);
    uq.p75 = zeros(height(uq), 1);
    uq.p90 = zeros(height(uq), 1);
    for i = 1:height(uq)
        m = strcmpi(T.algorithm_name, uq.algorithm_name(i)) & T.function_id == uq.function_id(i);
        q = quantile(T.final_value(m), [0.10, 0.25, 0.50, 0.75, 0.90]);
        uq.p10(i) = q(1);
        uq.p25(i) = q(2);
        uq.p50(i) = q(3);
        uq.p75(i) = q(4);
        uq.p90(i) = q(5);
    end

    dist_tbl = outerjoin(dist_tbl, uq, 'Keys', {'algorithm_name', 'function_id'}, 'MergeKeys', true);

    out = struct();
    out.run_level_csv = fullfile(result_dir, 'run_level_final_values.csv');
    out.bad_run_csv = fullfile(result_dir, 'bad_run_summary.csv');
    out.dist_csv = fullfile(result_dir, 'final_value_distribution_summary.csv');

    writetable(T, out.run_level_csv);
    writetable(struct2table(bad_tbl), out.bad_run_csv);
    writetable(dist_tbl, out.dist_csv);
end
