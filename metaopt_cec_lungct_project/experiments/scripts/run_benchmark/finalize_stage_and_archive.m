function report = finalize_stage_and_archive(cfg)
% finalize_stage_and_archive
% Phase-end consolidation for research artifacts:
% 1) Copy stable artifacts into archive/achieve/stage_freeze/<stage_name>_<timestamp>
% 2) Move process-only old versions into archive/achieve/unused_versions/<stage_name>_<timestamp>
% 3) Save a machine-readable manifest for audit/repro tracking
%
% Example:
% cfg = struct();
% cfg.stage_name = 'v1_taskc_round3';
% cfg.stable_paths = {
%   'results/benchmark/summaries/v1_taskc_round3_fes30000_20260317'
%   'experiments/tracking/decision_log.md'
%   'experiments/tracking/research_progress_master.md'
%   'experiments/tracking/research_progress_master.csv'
% };
% cfg.process_paths = {
%   'temp/scratch/run_v1_taskc_round1_fes30000_20260317.m'
%   'temp/scratch/run_v1_taskc_round2_small_ablation_20260317.m'
% };
% report = finalize_stage_and_archive(cfg);

    if nargin < 1
        cfg = struct();
    end

    cfg = fill_defaults(cfg);

    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    repo_root = fullfile(this_dir, '..', '..', '..');

    freeze_root = fullfile(repo_root, cfg.achieve_root, 'stage_freeze');
    process_root = fullfile(repo_root, cfg.achieve_root, 'unused_versions');

    freeze_dir = fullfile(freeze_root, sprintf('%s_%s', cfg.stage_name, cfg.timestamp));
    process_dir = fullfile(process_root, sprintf('%s_%s', cfg.stage_name, cfg.timestamp));

    if ~isfolder(freeze_dir)
        mkdir(freeze_dir);
    end
    if ~isfolder(process_dir)
        mkdir(process_dir);
    end

    rows = table();

    for i = 1:numel(cfg.stable_paths)
        source_rel = normalize_rel_path(cfg.stable_paths{i});
        source_abs = fullfile(repo_root, source_rel);
        target_abs = fullfile(freeze_dir, source_rel);
        [status, message] = copy_into_stage(source_abs, target_abs);
        rows = append_row(rows, 'copy', 'stable', source_rel, relpath(repo_root, target_abs), status, message); %#ok<AGROW>
    end

    for i = 1:numel(cfg.process_paths)
        source_rel = normalize_rel_path(cfg.process_paths{i});
        source_abs = fullfile(repo_root, source_rel);
        target_abs = fullfile(process_dir, source_rel);
        [status, message] = move_into_stage(source_abs, target_abs);
        rows = append_row(rows, 'move', 'process', source_rel, relpath(repo_root, target_abs), status, message); %#ok<AGROW>
    end

    report = struct();
    report.stage_name = cfg.stage_name;
    report.timestamp = cfg.timestamp;
    report.freeze_dir = relpath(repo_root, freeze_dir);
    report.process_dir = relpath(repo_root, process_dir);
    report.manifest_rows = height(rows);

    manifest_csv = fullfile(freeze_dir, 'stage_manifest.csv');
    manifest_mat = fullfile(freeze_dir, 'stage_manifest.mat');
    report_md = fullfile(freeze_dir, 'stage_report.md');

    writetable(rows, manifest_csv);
    save(manifest_mat, 'rows', 'cfg', 'report');
    write_markdown_report(report_md, report, rows);

    report.manifest_csv = relpath(repo_root, manifest_csv);
    report.manifest_mat = relpath(repo_root, manifest_mat);
    report.report_md = relpath(repo_root, report_md);

    disp(report);
end

function cfg = fill_defaults(cfg)
    if ~isfield(cfg, 'stage_name') || strlength(string(cfg.stage_name)) == 0
        cfg.stage_name = 'stage';
    end
    if ~isfield(cfg, 'timestamp') || strlength(string(cfg.timestamp)) == 0
        cfg.timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    else
        cfg.timestamp = string(cfg.timestamp);
    end
    if ~isfield(cfg, 'achieve_root') || strlength(string(cfg.achieve_root)) == 0
        cfg.achieve_root = fullfile('archive', 'achieve');
    end
    if ~isfield(cfg, 'stable_paths') || isempty(cfg.stable_paths)
        cfg.stable_paths = {};
    end
    if ~isfield(cfg, 'process_paths') || isempty(cfg.process_paths)
        cfg.process_paths = {};
    end
end

function p = normalize_rel_path(p)
    p = char(string(p));
    p = strrep(p, '\\', '/');
    p = strrep(p, '\', '/');
    while startsWith(p, './')
        p = extractAfter(p, 2);
        p = char(p);
    end
end

function [status, message] = copy_into_stage(source_abs, target_abs)
    status = 'ok';
    message = '';
    if ~(isfile(source_abs) || isfolder(source_abs))
        status = 'missing';
        message = 'source_not_found';
        return;
    end

    parent_dir = fileparts(target_abs);
    if ~isfolder(parent_dir)
        mkdir(parent_dir);
    end

    [ok, msg] = copyfile(source_abs, target_abs);
    if ~ok
        status = 'failed';
        message = char(msg);
    end
end

function [status, message] = move_into_stage(source_abs, target_abs)
    status = 'ok';
    message = '';
    if ~(isfile(source_abs) || isfolder(source_abs))
        status = 'missing';
        message = 'source_not_found';
        return;
    end

    parent_dir = fileparts(target_abs);
    if ~isfolder(parent_dir)
        mkdir(parent_dir);
    end

    [ok, msg] = movefile(source_abs, target_abs);
    if ~ok
        status = 'failed';
        message = char(msg);
    end
end

function rows = append_row(rows, action, category, source_rel, target_rel, status, message)
    t = table( ...
        string(action), ...
        string(category), ...
        string(source_rel), ...
        string(target_rel), ...
        string(status), ...
        string(message), ...
        string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
        'VariableNames', {'action', 'category', 'source_rel', 'target_rel', 'status', 'message', 'recorded_at'});

    if isempty(rows)
        rows = t;
    else
        rows = [rows; t]; %#ok<AGROW>
    end
end

function write_markdown_report(file_path, report, rows)
    fid = fopen(file_path, 'w');
    fprintf(fid, '# Stage Freeze Report\n\n');
    fprintf(fid, '- stage_name: %s\n', report.stage_name);
    fprintf(fid, '- timestamp: %s\n', report.timestamp);
    fprintf(fid, '- freeze_dir: %s\n', report.freeze_dir);
    fprintf(fid, '- process_dir: %s\n', report.process_dir);
    fprintf(fid, '- manifest_rows: %d\n\n', report.manifest_rows);

    fprintf(fid, '## Manifest\n\n');
    fprintf(fid, '| action | category | source_rel | target_rel | status | message | recorded_at |\n');
    fprintf(fid, '| ------ | -------- | ---------- | ---------- | ------ | ------- | ----------- |\n');
    for i = 1:height(rows)
        fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s |\n', ...
            rows.action(i), rows.category(i), rows.source_rel(i), rows.target_rel(i), ...
            rows.status(i), rows.message(i), rows.recorded_at(i));
    end
    fclose(fid);
end

function out_rel = relpath(repo_root, abs_path)
    repo_root = char(string(repo_root));
    abs_path = char(string(abs_path));
    repo_root = strrep(repo_root, '\\', '/');
    abs_path = strrep(abs_path, '\\', '/');

    if startsWith(lower(abs_path), lower(repo_root))
        out_rel = abs_path(length(repo_root) + 2:end);
    else
        out_rel = abs_path;
    end
end
