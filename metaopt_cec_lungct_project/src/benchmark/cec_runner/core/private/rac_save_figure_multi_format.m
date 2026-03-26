function rac_save_figure_multi_format(fig, base_name, plot_cfg, log_file)
% rac_save_figure_multi_format
% Save figure with multi-format policy shared by plotting modules.

    if plot_cfg.close_after_save
        cleaner = onCleanup(@() close(fig)); %#ok<NASGU>
    else
        cleaner = onCleanup(@() []); %#ok<NASGU>
    end

    if plot_cfg.tight
        try
            drawnow;
        catch
        end
    end

    for i = 1:numel(plot_cfg.formats)
        fmt = lower(char(string(plot_cfg.formats{i})));
        file_path = sprintf('%s.%s', base_name, fmt);
        if ~plot_cfg.overwrite && isfile(file_path)
            rac_log_message(log_file, sprintf('[Plot] skip existing file: %s', file_path));
            continue;
        end
        try
            save_by_format(fig, file_path, fmt, plot_cfg.dpi);
            rac_log_message(log_file, sprintf('[Plot] saved: %s', file_path));
        catch ME
            rac_log_message(log_file, sprintf('[Plot] save failed: %s (%s)', file_path, ME.message));
        end
    end
    clear cleaner;
end

function save_by_format(fig, file_path, fmt, dpi)
    if exist('exportgraphics', 'file') == 2 && any(strcmp(fmt, {'png', 'pdf'}))
        exportgraphics(fig, file_path, 'Resolution', dpi);
        return;
    end

    switch fmt
        case 'png'
            print(fig, file_path, '-dpng', sprintf('-r%d', dpi));
        case 'pdf'
            print(fig, file_path, '-dpdf', sprintf('-r%d', dpi));
        case 'fig'
            savefig(fig, file_path);
        otherwise
            saveas(fig, file_path);
    end
end
