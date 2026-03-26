function rac_plot_boxplots(run_results, cfg, plot_dirs, log_file)
% rac_plot_boxplots
% Generate robust boxplots for per-function final best scores.

    fids = unique([run_results.function_id]);
    for i = 1:numel(fids)
        fid = fids(i);
        subset = run_results([run_results.function_id] == fid);
        labels = unique(string({subset.algorithm_name}), 'stable');
        if numel(labels) < 2
            log_plot_skip_local(log_file, cfg, 'boxplots', fid, 'need at least two algorithms');
            continue;
        end

        score_cells = cell(1, numel(labels));
        has_data = false;
        for k = 1:numel(labels)
            idx = strcmp({subset.algorithm_name}, char(labels(k)));
            score_cells{k} = [subset(idx).best_score];
            has_data = has_data || numel(score_cells{k}) > 1;
        end

        if ~has_data
            log_plot_skip_local(log_file, cfg, 'boxplots', fid, 'insufficient multi-run final-best data');
            continue;
        end

        try
            fig = create_plot_figure_local(cfg.plot);
            ax = axes('Parent', fig);
            apply_axes_style_local(ax);
            hold(ax, 'on');
            draw_minimal_boxplot_local(ax, score_cells, cellstr(labels));
            hold(ax, 'off');
            ylabel(ax, 'Final best fitness');
            title(ax, sprintf('%s boxplot on F%d (D=%d)', upper(cfg.suite), fid, cfg.dim));
            grid(ax, 'on');
            base_name = fullfile(plot_dirs.boxplots, sprintf('boxplot_%s_D%d_F%d', lower(cfg.suite), cfg.dim, fid));
            rac_save_figure_multi_format(fig, base_name, cfg.plot, log_file);
        catch ME
            log_plot_skip_local(log_file, cfg, 'boxplots', fid, ME.message);
        end
    end
end

function draw_minimal_boxplot_local(ax, score_cells, labels)
    colors = lines(max(3, numel(score_cells)));
    for i = 1:numel(score_cells)
        values = score_cells{i}(:);
        values = values(~isnan(values));
        if isempty(values)
            continue;
        end
        stats = compute_box_stats_local(values);
        x_left = i - 0.28;
        width = 0.56;
        patch(ax, [x_left, x_left + width, x_left + width, x_left], [stats.q1, stats.q1, stats.q3, stats.q3], ...
            colors(i, :), 'FaceAlpha', 0.22, 'EdgeColor', colors(i, :), 'LineWidth', 1.2);
        line(ax, [i, i], [stats.whisker_low, stats.q1], 'Color', colors(i, :), 'LineWidth', 1.2);
        line(ax, [i, i], [stats.q3, stats.whisker_high], 'Color', colors(i, :), 'LineWidth', 1.2);
        line(ax, [x_left, x_left + width], [stats.median, stats.median], 'Color', colors(i, :), 'LineWidth', 1.6);
        line(ax, [i - 0.14, i + 0.14], [stats.whisker_low, stats.whisker_low], 'Color', colors(i, :), 'LineWidth', 1.2);
        line(ax, [i - 0.14, i + 0.14], [stats.whisker_high, stats.whisker_high], 'Color', colors(i, :), 'LineWidth', 1.2);
        scatter(ax, repmat(i, size(stats.outliers)), stats.outliers, 18, 'MarkerEdgeColor', colors(i, :), 'MarkerFaceColor', colors(i, :));
    end
    xlim(ax, [0.5, numel(score_cells) + 0.5]);
    set(ax, 'XTick', 1:numel(labels), 'XTickLabel', labels, 'XTickLabelRotation', 25);
end

function stats = compute_box_stats_local(values)
    sorted_vals = sort(values(:));
    stats.q1 = percentile_linear_local(sorted_vals, 25);
    stats.median = percentile_linear_local(sorted_vals, 50);
    stats.q3 = percentile_linear_local(sorted_vals, 75);
    iqr_val = stats.q3 - stats.q1;
    lower_fence = stats.q1 - 1.5 * iqr_val;
    upper_fence = stats.q3 + 1.5 * iqr_val;
    inside = sorted_vals(sorted_vals >= lower_fence & sorted_vals <= upper_fence);
    if isempty(inside)
        stats.whisker_low = sorted_vals(1);
        stats.whisker_high = sorted_vals(end);
    else
        stats.whisker_low = inside(1);
        stats.whisker_high = inside(end);
    end
    stats.outliers = sorted_vals(sorted_vals < lower_fence | sorted_vals > upper_fence);
end

function value = percentile_linear_local(sorted_vals, pct)
    if isempty(sorted_vals)
        value = nan;
        return;
    end
    n = numel(sorted_vals);
    if n == 1
        value = sorted_vals(1);
        return;
    end
    pos = 1 + (n - 1) * pct / 100;
    lo = floor(pos);
    hi = ceil(pos);
    if lo == hi
        value = sorted_vals(lo);
    else
        value = sorted_vals(lo) + (pos - lo) * (sorted_vals(hi) - sorted_vals(lo));
    end
end

function fig = create_plot_figure_local(plot_cfg)
    if plot_cfg.show
        visibility = 'on';
    else
        visibility = 'off';
    end
    fig = figure('Visible', visibility, 'Color', 'w', 'Position', [120, 120, 900, 560]);
end

function apply_axes_style_local(ax)
    set(ax, 'FontName', 'Times New Roman', 'FontSize', 11, 'LineWidth', 1.0, 'Box', 'on');
end

function log_plot_skip_local(log_file, cfg, plot_type, fid, reason)
    if nargin < 4 || isempty(fid)
        scope = plot_type;
    else
        scope = sprintf('%s F%d', plot_type, fid);
    end
    if cfg.plot.log_skipped
        rac_log_message(log_file, sprintf('[Plot] skipped %s: %s', scope, reason));
    end
end
