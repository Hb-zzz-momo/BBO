function save_stage_report(out_root, report, mat_file_name, md_file_name, markdown_writer, cfg)
% save_stage_report
% Shared stage report persistence helper.

    if nargin < 3 || isempty(mat_file_name)
        mat_file_name = 'pipeline_report.mat';
    end
    save(fullfile(out_root, mat_file_name), 'report');

    if nargin >= 5 && ~isempty(markdown_writer)
        if nargin < 4 || isempty(md_file_name)
            md_file_name = 'analysis_summary.md';
        end
        markdown_writer(fullfile(out_root, md_file_name), report, cfg);
    end
end
