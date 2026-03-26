function write_stage_scan(out_root, scan_info, cfg, markdown_writer)
% write_stage_scan
% Shared stage scan persistence helper.

    save(fullfile(out_root, 'scan_snapshot.mat'), 'scan_info', 'cfg');
    if nargin >= 4 && ~isempty(markdown_writer)
        markdown_writer(fullfile(out_root, 'scan_snapshot.md'), scan_info, cfg);
    end
end
