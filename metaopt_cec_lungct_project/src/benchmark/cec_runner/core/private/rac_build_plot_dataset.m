function [mean_curves, labels, x_axis_mode, target_len, run_count_map] = rac_build_plot_dataset(run_results, fid)
% rac_build_plot_dataset
% Build normalized convergence dataset for plotting.

    subset_f = run_results([run_results.function_id] == fid);
    if isempty(subset_f)
        mean_curves = {};
        labels = {};
        x_axis_mode = 'iter';
        target_len = 0;
        run_count_map = zeros(1, 0);
        return;
    end

    alg_names = unique(string({subset_f.algorithm_name}), 'stable');
    labels = cellstr(alg_names(:));
    mean_curves = cell(1, numel(alg_names));
    run_count_map = zeros(1, numel(alg_names));

    lengths = zeros(1, numel(subset_f));
    for i = 1:numel(subset_f)
        c = read_curve_local(subset_f(i));
        if isempty(c)
            lengths(i) = 0;
        else
            lengths(i) = numel(c);
        end
    end
    target_len = max(lengths);

    if target_len <= 0
        mean_curves = {};
        labels = {};
        run_count_map = zeros(1, 0);
        x_axis_mode = 'iter';
        return;
    end

    x_axis_mode = infer_x_axis_mode(subset_f, target_len);

    for i = 1:numel(alg_names)
        name = alg_names(i);
        subset = subset_f(strcmp(string({subset_f.algorithm_name}), name));
        curves = [];
        valid_count = 0;
        for k = 1:numel(subset)
            curve = read_curve_local(subset(k));
            if isempty(curve)
                continue;
            end
            curve = curve(:)';
            curve = pad_best_curve(curve, target_len);
            if all(isfinite(curve))
                curves = [curves; curve]; %#ok<AGROW>
                valid_count = valid_count + 1;
            end
        end

        run_count_map(i) = valid_count;
        if isempty(curves)
            mean_curves{i} = [];
        else
            mean_curves{i} = mean(curves, 1, 'omitnan');
        end
    end
end

function padded = pad_best_curve(curve, target_len)
    if numel(curve) >= target_len
        padded = curve(1:target_len);
        return;
    end
    if isempty(curve)
        padded = nan(1, target_len);
        return;
    end
    padded = [curve, repmat(curve(end), 1, target_len - numel(curve))];
end

function mode_name = infer_x_axis_mode(subset_f, target_len)
    mode_name = 'iter';
    if isempty(subset_f)
        return;
    end

    has_fe_hint = false;
    for i = 1:numel(subset_f)
        r = subset_f(i);
        if isfield(r, 'used_FEs') && ~isempty(r.used_FEs)
            if isnumeric(r.used_FEs) && isfinite(r.used_FEs) && r.used_FEs >= target_len
                has_fe_hint = true;
                break;
            end
        end
        if isfield(r, 'x_axis_mode') && ~isempty(r.x_axis_mode)
            if strcmpi(string(r.x_axis_mode), 'fe')
                has_fe_hint = true;
                break;
            end
        end
    end

    if has_fe_hint
        mode_name = 'fe';
    end
end

function curve = read_curve_local(run_item)
% Compatibility shim for mixed result schemas.
    curve = [];
    if isfield(run_item, 'convergence') && ~isempty(run_item.convergence)
        curve = run_item.convergence;
        return;
    end
    if isfield(run_item, 'convergence_curve') && ~isempty(run_item.convergence_curve)
        curve = run_item.convergence_curve;
    end
end
