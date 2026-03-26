function rac_plot_convergence_curves(run_results, cfg, plot_dirs, log_file)
% rac_plot_convergence_curves
% Generate convergence curves using the shared convergence dataset builder.

    fids = unique([run_results.function_id]);
    for i = 1:numel(fids)
        fid = fids(i);
        try
            [mean_curves, labels, x_axis_mode, target_len, run_count_map] = rac_build_plot_dataset(run_results, fid);
            if isempty(mean_curves)
                log_plot_skip_local(log_file, cfg, 'convergence_curves', fid, 'no convergence history found');
                continue;
            end

            if strcmp(x_axis_mode, 'fe')
                x_label = 'Function Evaluations';
            else
                x_label = 'Iteration';
            end

            fig = create_plot_figure_local(cfg.plot);
            ax = axes('Parent', fig);
            apply_axes_style_local(ax);
            hold(ax, 'on');
            x = 1:target_len;
            for k = 1:numel(mean_curves)
                if isempty(mean_curves{k})
                    continue;
                end
                plot(ax, x, mean_curves{k}, 'LineWidth', 1.5, 'DisplayName', labels{k});
            end
            hold(ax, 'off');
            set(ax, 'YScale', 'log');
            xlabel(ax, x_label);
            ylabel(ax, 'Best-so-far fitness');
            title(ax, sprintf('%s convergence on F%d (D=%d)', upper(cfg.suite), fid, cfg.dim));
            legend(ax, labels, 'Location', 'best', 'Interpreter', 'none');
            grid(ax, 'on');

            note_text = build_convergence_note_local(run_count_map, labels);
            if ~isempty(note_text)
                annotation(fig, 'textbox', [0.14, 0.01, 0.82, 0.05], 'String', note_text, ...
                    'EdgeColor', 'none', 'Interpreter', 'none', 'FontSize', 9);
            end

            base_name = fullfile(plot_dirs.convergence_curves, sprintf('convergence_%s_D%d_F%d', lower(cfg.suite), cfg.dim, fid));
            rac_save_figure_multi_format(fig, base_name, cfg.plot, log_file);
        catch ME
            log_plot_skip_local(log_file, cfg, 'convergence_curves', fid, ME.message);
        end
    end
end

function note_text = build_convergence_note_local(run_count_map, labels)
    parts = {};
    for i = 1:numel(labels)
        n_runs = run_count_map(i);
        if n_runs > 1
            parts{end + 1} = sprintf('%s: mean over %d runs', labels{i}, n_runs); %#ok<AGROW>
        else
            parts{end + 1} = sprintf('%s: single-run trajectory', labels{i}); %#ok<AGROW>
        end
    end
    note_text = strjoin(parts, ' | ');
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
