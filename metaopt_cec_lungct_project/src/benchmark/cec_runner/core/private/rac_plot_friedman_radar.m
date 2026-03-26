function rac_plot_friedman_radar(summary_table, cfg, plot_dirs, log_file)
% rac_plot_friedman_radar
% Generate Friedman average-rank radar chart.

    if isempty(summary_table) || height(summary_table) == 0
        log_plot_skip_local(log_file, cfg, 'friedman_radar', [], 'summary table is empty');
        return;
    end

    [alg_labels, avg_ranks, comparable_funcs] = compute_average_ranks_local(summary_table);
    if numel(alg_labels) < 2 || comparable_funcs < 2
        log_plot_skip_local(log_file, cfg, 'friedman_radar', [], 'need at least two algorithms and two comparable functions');
        return;
    end

    try
        fig = create_plot_figure_local(cfg.plot);
        ax = axes('Parent', fig);
        apply_axes_style_local(ax);
        draw_radar_chart_local(ax, alg_labels, avg_ranks);
        title(ax, sprintf('%s Friedman average ranks (D=%d)', upper(cfg.suite), cfg.dim));
        base_name = fullfile(plot_dirs.friedman_radar, sprintf('friedman_%s_D%d', lower(cfg.suite), cfg.dim));
        rac_save_figure_multi_format(fig, base_name, cfg.plot, log_file);
    catch ME
        log_plot_skip_local(log_file, cfg, 'friedman_radar', [], ME.message);
    end
end

function [alg_labels, avg_ranks, comparable_funcs] = compute_average_ranks_local(summary_table)
    alg_labels = {};
    avg_ranks = [];
    comparable_funcs = 0;

    fids = unique(summary_table.function_id)';
    rank_map = struct();
    for i = 1:numel(fids)
        rows = summary_table(summary_table.function_id == fids(i), :);
        if height(rows) < 2
            continue;
        end
        comparable_funcs = comparable_funcs + 1;
        scores = rows.mean;
        labels = cellstr(string(rows.algorithm_name));
        ranks = average_tie_ranks_local(scores);
        for k = 1:numel(labels)
            key = matlab.lang.makeValidName(labels{k});
            if ~isfield(rank_map, key)
                rank_map.(key) = [];
            end
            rank_map.(key)(end + 1) = ranks(k); %#ok<AGROW>
        end
    end

    keys = fieldnames(rank_map);
    if isempty(keys)
        return;
    end

    alg_labels = cell(1, numel(keys));
    avg_ranks = zeros(1, numel(keys));
    for i = 1:numel(keys)
        alg_labels{i} = regexprep(keys{i}, '^x', '');
        avg_ranks(i) = mean(rank_map.(keys{i}));
    end
end

function ranks = average_tie_ranks_local(scores)
    [sorted_scores, order] = sort(scores(:), 'ascend');
    ranks = zeros(size(scores(:)));
    i = 1;
    while i <= numel(sorted_scores)
        j = i;
        while j < numel(sorted_scores) && sorted_scores(j + 1) == sorted_scores(i)
            j = j + 1;
        end
        avg_rank = mean(i:j);
        ranks(order(i:j)) = avg_rank;
        i = j + 1;
    end
    ranks = ranks(:)';
end

function draw_radar_chart_local(ax, labels, values)
    n = numel(values);
    theta = linspace(0, 2 * pi, n + 1);
    rho = [values(:); values(1)];
    max_r = max(values);
    if max_r <= 0
        max_r = 1;
    end

    hold(ax, 'on');
    axis(ax, 'equal');
    axis(ax, 'off');

    for level = 0.25:0.25:1.0
        ring_x = max_r * level * cos(theta);
        ring_y = max_r * level * sin(theta);
        plot(ax, ring_x, ring_y, ':', 'Color', [0.75, 0.75, 0.75], 'LineWidth', 0.8);
    end

    for i = 1:n
        plot(ax, [0, max_r * cos(theta(i))], [0, max_r * sin(theta(i))], ':', 'Color', [0.75, 0.75, 0.75], 'LineWidth', 0.8);
        text(ax, 1.1 * max_r * cos(theta(i)), 1.1 * max_r * sin(theta(i)), labels{i}, ...
            'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', 'FontSize', 10);
    end

    data_x = rho .* cos(theta(:));
    data_y = rho .* sin(theta(:));
    plot(ax, data_x, data_y, '-o', 'LineWidth', 1.8, 'MarkerSize', 5, 'Color', [0.1, 0.35, 0.7]);
    hold(ax, 'off');
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
