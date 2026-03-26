function out_csv = compute_plateau_fe_summary(result_dir)
% compute_plateau_fe_summary
% Build plateau FE summary from per-run convergence curves.

    curves_dir = fullfile(result_dir, 'curves');
    if ~exist(curves_dir, 'dir')
        error('Curves dir not found: %s', curves_dir);
    end

    files = dir(fullfile(curves_dir, '*_curve.csv'));
    if isempty(files)
        error('No curve csv files found in: %s', curves_dir);
    end

    rows = repmat(struct('algorithm', '', 'function_id', 0, 'run_id', 0, 'plateau_fe', 0), 0, 1);

    for i = 1:numel(files)
        fn = files(i).name;
        tk = regexp(fn, '^(.*)_F(\d+)_run(\d+)_curve\.csv$', 'tokens', 'once');
        if isempty(tk)
            continue;
        end

        alg = string(tk{1});
        fid = str2double(tk{2});
        rid = str2double(tk{3});

        curve = readmatrix(fullfile(files(i).folder, fn));
        curve = curve(:);
        if isempty(curve)
            continue;
        end

        pfe = detect_plateau_fe(curve);

        r = struct();
        r.algorithm = char(alg);
        r.function_id = fid;
        r.run_id = rid;
        r.plateau_fe = pfe;
        rows(end + 1, 1) = r; %#ok<AGROW>
    end

    T = struct2table(rows);
    if isempty(T)
        error('No valid curve records parsed from %s', curves_dir);
    end

    G = groupsummary(T, {'algorithm', 'function_id'}, {'mean', 'std', 'min', 'max'}, 'plateau_fe');
    G = renamevars(G, {'mean_plateau_fe', 'std_plateau_fe', 'min_plateau_fe', 'max_plateau_fe'}, ...
        {'plateau_fe_mean', 'plateau_fe_std', 'plateau_fe_best', 'plateau_fe_worst'});

    out_csv = fullfile(result_dir, 'plateau_fe_summary.csv');
    writetable(G, out_csv);
end

function pfe = detect_plateau_fe(curve)
    n = numel(curve);
    if n < 20
        pfe = n;
        return;
    end

    window = max(20, round(0.01 * n));
    tol_rel = 1e-6;
    pfe = n;

    for i = (window + 1):n
        prev = curve(i - window);
        curr = curve(i);
        improve = prev - curr;
        ref = max(1.0, abs(prev));
        if improve <= tol_rel * ref
            pfe = i;
            return;
        end
    end
end
