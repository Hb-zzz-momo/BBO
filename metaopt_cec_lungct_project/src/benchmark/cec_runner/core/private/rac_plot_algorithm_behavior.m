function rac_plot_algorithm_behavior(run_results, cfg, plot_dirs, log_file)
% rac_plot_algorithm_behavior
% Generate behavior-oriented plots for configured algorithm-function pairs.

    behavior_algs = upper(string(cfg.plot.behavior.capture_algorithms));
    for a = 1:numel(behavior_algs)
        alg_name = char(behavior_algs(a));
        if ~ismember(alg_name, upper(string(cfg.plot.selected_algorithms_resolved)))
            continue;
        end

        for i = 1:numel(cfg.plot.behavior.capture_func_ids)
            fid = cfg.plot.behavior.capture_func_ids(i);
            subset = run_results(strcmp({run_results.algorithm_name}, alg_name) & [run_results.function_id] == fid);
            if isempty(subset)
                log_plot_skip_local(log_file, cfg, 'behavior', fid, sprintf('%s has no runs', alg_name));
                continue;
            end
            trace = select_behavior_trace_local(subset);
            if ~trace.captured
                log_plot_skip_local(log_file, cfg, 'behavior', fid, sprintf('%s has no captured behavior trace', alg_name));
                continue;
            end

            if cfg.plot.types.mean_fitness
                plot_mean_fitness_local(trace, alg_name, fid, cfg, plot_dirs, log_file);
            end
            if cfg.plot.types.trajectory_first_dim
                plot_trajectory_first_dim_local(trace, alg_name, fid, cfg, plot_dirs, log_file);
            end
            if cfg.plot.types.final_population
                plot_final_population_local(trace, subset(1), alg_name, fid, cfg, plot_dirs, log_file);
            end
            if cfg.plot.types.search_process_overview
                plot_search_process_overview_local(trace, subset(1), alg_name, fid, cfg, plot_dirs, log_file);
            end
        end
    end
end

function trace = select_behavior_trace_local(subset)
    trace = rac_make_behavior_trace_template();
    if isempty(subset)
        return;
    end

    best_idx = 1;
    best_score = subset(1).best_score;
    for i = 2:numel(subset)
        if subset(i).best_score < best_score
            best_score = subset(i).best_score;
            best_idx = i;
        end
    end
    trace = subset(best_idx).behavior_trace;
end

function plot_mean_fitness_local(trace, alg_name, fid, cfg, plot_dirs, log_file)
    if isempty(trace.mean_fitness_curve)
        log_plot_skip_local(log_file, cfg, 'mean_fitness', fid, sprintf('%s missing mean_fitness_curve', alg_name));
        return;
    end
    fig = create_plot_figure_local(cfg.plot);
    ax = axes('Parent', fig);
    apply_axes_style_local(ax);
    plot(ax, 1:numel(trace.mean_fitness_curve), trace.mean_fitness_curve, 'LineWidth', 1.5, 'Color', [0.16, 0.45, 0.71]);
    xlabel(ax, 'Iteration proxy (evaluation batch)');
    ylabel(ax, 'Mean fitness');
    title(ax, sprintf('%s mean fitness on F%d (D=%d)', alg_name, fid, cfg.dim));
    grid(ax, 'on');
    target_dir = ensure_behavior_dir_local(plot_dirs.mean_fitness, alg_name, cfg.dim);
    base_name = fullfile(target_dir, sprintf('meanfit_%s_%s_D%d_F%d', lower(alg_name), lower(cfg.suite), cfg.dim, fid));
    rac_save_figure_multi_format(fig, base_name, cfg.plot, log_file);
end

function plot_trajectory_first_dim_local(trace, alg_name, fid, cfg, plot_dirs, log_file)
    if isempty(trace.trajectory_first_dim)
        log_plot_skip_local(log_file, cfg, 'trajectory_first_dim', fid, sprintf('%s missing trajectory_first_dim', alg_name));
        return;
    end
    fig = create_plot_figure_local(cfg.plot);
    ax = axes('Parent', fig);
    apply_axes_style_local(ax);
    plot(ax, 1:numel(trace.trajectory_first_dim), trace.trajectory_first_dim, 'LineWidth', 1.5, 'Color', [0.8, 0.3, 0.2]);
    xlabel(ax, 'Iteration proxy (evaluation batch)');
    ylabel(ax, 'Representative x(1)');
    title(ax, sprintf('%s first-dimension trajectory on F%d (D=%d)', alg_name, fid, cfg.dim));
    grid(ax, 'on');
    target_dir = ensure_behavior_dir_local(plot_dirs.trajectory_first_dim, alg_name, cfg.dim);
    base_name = fullfile(target_dir, sprintf('traj1d_%s_%s_D%d_F%d', lower(alg_name), lower(cfg.suite), cfg.dim, fid));
    rac_save_figure_multi_format(fig, base_name, cfg.plot, log_file);
end

function plot_final_population_local(trace, run_result, alg_name, fid, cfg, plot_dirs, log_file)
    if cfg.plot.behavior.require_dim2 && run_result.dimension ~= 2
        log_plot_skip_local(log_file, cfg, 'final_population', fid, sprintf('%s skipped because dim=%d', alg_name, run_result.dimension));
        return;
    end
    if isempty(trace.final_population) || size(trace.final_population, 2) < 2
        log_plot_skip_local(log_file, cfg, 'final_population', fid, sprintf('%s missing 2D final population proxy', alg_name));
        return;
    end
    fig = create_plot_figure_local(cfg.plot);
    ax = axes('Parent', fig);
    apply_axes_style_local(ax);
    scatter(ax, trace.final_population(:, 1), trace.final_population(:, 2), 28, 'filled');
    xlabel(ax, 'x_1');
    ylabel(ax, 'x_2');
    title(ax, sprintf('%s final population proxy on F%d (D=%d)', alg_name, fid, cfg.dim));
    grid(ax, 'on');
    target_dir = ensure_behavior_dir_local(plot_dirs.final_population, alg_name, cfg.dim);
    base_name = fullfile(target_dir, sprintf('finalpop_%s_%s_D%d_F%d', lower(alg_name), lower(cfg.suite), cfg.dim, fid));
    rac_save_figure_multi_format(fig, base_name, cfg.plot, log_file);
end

function plot_search_process_overview_local(trace, run_result, alg_name, fid, cfg, plot_dirs, log_file)
    if cfg.plot.behavior.require_dim2 && run_result.dimension ~= 2
        log_plot_skip_local(log_file, cfg, 'search_process_overview', fid, sprintf('%s skipped because dim=%d', alg_name, run_result.dimension));
        return;
    end

    fig = create_plot_figure_local(cfg.plot);

    ax1 = subplot(2, 2, 1, 'Parent', fig);
    apply_axes_style_local(ax1);
    contour_ok = plot_function_contour_local(ax1, run_result, cfg, fid, trace, log_file);

    ax2 = subplot(2, 2, 2, 'Parent', fig);
    apply_axes_style_local(ax2);
    if ~isempty(trace.mean_fitness_curve)
        plot(ax2, 1:numel(trace.mean_fitness_curve), trace.mean_fitness_curve, 'LineWidth', 1.4, 'Color', [0.15, 0.45, 0.75]);
        xlabel(ax2, 'Iteration proxy (evaluation batch)');
        ylabel(ax2, 'Mean fitness');
        title(ax2, 'Mean fitness');
        grid(ax2, 'on');
    else
        axis(ax2, 'off');
        text(ax2, 0.1, 0.5, 'Mean fitness unavailable', 'Units', 'normalized');
    end

    ax3 = subplot(2, 2, 3, 'Parent', fig);
    apply_axes_style_local(ax3);
    if ~isempty(trace.trajectory_first_dim)
        plot(ax3, 1:numel(trace.trajectory_first_dim), trace.trajectory_first_dim, 'LineWidth', 1.4, 'Color', [0.82, 0.33, 0.22]);
        xlabel(ax3, 'Iteration proxy (evaluation batch)');
        ylabel(ax3, 'x_1');
        title(ax3, 'Representative first-dimension trajectory');
        grid(ax3, 'on');
    else
        axis(ax3, 'off');
        text(ax3, 0.1, 0.5, 'Trajectory unavailable', 'Units', 'normalized');
    end

    ax4 = subplot(2, 2, 4, 'Parent', fig);
    apply_axes_style_local(ax4);
    curve = run_result.convergence_curve(:)';
    if ~isempty(curve)
        plot(ax4, 1:numel(curve), curve, 'LineWidth', 1.4, 'Color', [0.2, 0.2, 0.2]);
        xlabel(ax4, infer_x_label_from_run_local(run_result));
        ylabel(ax4, 'Best-so-far fitness');
        title(ax4, 'Convergence');
        grid(ax4, 'on');
    else
        axis(ax4, 'off');
        text(ax4, 0.1, 0.5, 'Convergence unavailable', 'Units', 'normalized');
    end

    if ~contour_ok
        log_plot_skip_local(log_file, cfg, 'search_process_overview', fid, sprintf('%s contour/final positions unavailable', alg_name));
    end

    target_dir = ensure_behavior_dir_local(plot_dirs.search_process_overview, alg_name, cfg.dim);
    base_name = fullfile(target_dir, sprintf('overview_%s_%s_D%d_F%d', lower(alg_name), lower(cfg.suite), cfg.dim, fid));
    rac_save_figure_multi_format(fig, base_name, cfg.plot, log_file);
end

function ok = plot_function_contour_local(ax, run_result, cfg, fid, trace, log_file)
    ok = false;
    if run_result.dimension ~= 2 || isempty(trace.final_population) || size(trace.final_population, 2) < 2
        axis(ax, 'off');
        text(ax, 0.1, 0.5, '2D contour/final population unavailable', 'Units', 'normalized');
        return;
    end

    try
        paths = rac_resolve_common_paths();
        suite_api = rac_build_suite_api(paths, cfg.suite);
        [lb, ub, ~, fobj] = suite_api.get_function(fid, 2);
        [X, Y, Z] = call_in_dir_local(suite_api.runtime_dir, @() sample_function_surface_local(lb, ub, fobj));
        contourf(ax, X, Y, Z, 20, 'LineColor', 'none');
        hold(ax, 'on');
        scatter(ax, trace.final_population(:, 1), trace.final_population(:, 2), 22, 'k', 'filled');
        hold(ax, 'off');
        colorbar(ax);
        xlabel(ax, 'x_1');
        ylabel(ax, 'x_2');
        title(ax, '2D contour and final population proxy');
        ok = true;
    catch ME
        rac_log_message(log_file, sprintf('[Plot] contour generation failed for F%d: %s', fid, ME.message));
        axis(ax, 'off');
        text(ax, 0.1, 0.5, 'Contour generation failed', 'Units', 'normalized');
    end
end

function [X, Y, Z] = sample_function_surface_local(lb, ub, fobj)
    grid_n = 60;
    x1 = linspace(lb(1), ub(1), grid_n);
    x2 = linspace(lb(2), ub(2), grid_n);
    [X, Y] = meshgrid(x1, x2);
    Z = zeros(size(X));
    for i = 1:grid_n
        for j = 1:grid_n
            Z(i, j) = fobj([X(i, j), Y(i, j)]);
        end
    end
end

function varargout = call_in_dir_local(target_dir, fn)
    old_dir = pwd;
    cd(target_dir);
    cleanup_obj = onCleanup(@() cd(old_dir)); %#ok<NASGU>
    [varargout{1:nargout}] = fn();
end

function label = infer_x_label_from_run_local(run_result)
    if abs(numel(run_result.convergence_curve) - run_result.used_FEs) <= 1
        label = 'Function Evaluations';
    else
        label = 'Iteration';
    end
end

function target_dir = ensure_behavior_dir_local(root_dir, alg_name, dim)
    target_dir = fullfile(root_dir, lower(alg_name), sprintf('D%d', dim));
    if ~isfolder(target_dir)
        mkdir(target_dir);
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
