function report = check_path_collisions(cfg)
% check_path_collisions
% Static scan for high-risk duplicate MATLAB function names in baselines.

    if nargin < 1
        cfg = struct();
    end

    this_file = mfilename('fullpath');
    tools_dir = fileparts(this_file);
    runner_dir = fileparts(tools_dir);
    repo_root = fileparts(fileparts(fileparts(runner_dir)));

    if ~isfield(cfg, 'scan_roots') || isempty(cfg.scan_roots)
        cfg.scan_roots = {
            fullfile(repo_root, 'third_party', 'bbo_raw'), ...
            fullfile(repo_root, 'third_party', 'sbo_raw')};
    end
    if ~isfield(cfg, 'focus_names') || isempty(cfg.focus_names)
        cfg.focus_names = {'initialization.m', 'main.m', 'Get_Functions_details.m', 'func_plot.m'};
    end
    if ~isfield(cfg, 'write_report')
        cfg.write_report = true;
    end
    if ~isfield(cfg, 'report_root') || isempty(cfg.report_root)
        cfg.report_root = fullfile(repo_root, 'logs', 'system');
    end

    files = {};
    for i = 1:numel(cfg.scan_roots)
        root = cfg.scan_roots{i};
        if isfolder(root)
            files = [files; list_m_files(root)]; %#ok<AGROW>
        end
    end

    name_to_paths = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for i = 1:numel(files)
        [~, fname, ext] = fileparts(files{i});
        key = [fname ext];
        if isKey(name_to_paths, key)
            paths = name_to_paths(key);
            paths{end + 1} = files{i}; %#ok<AGROW>
            name_to_paths(key) = paths;
        else
            name_to_paths(key) = {files{i}};
        end
    end

    rows = table();
    keys = name_to_paths.keys;
    for i = 1:numel(keys)
        key = keys{i};
        paths = name_to_paths(key);
        if numel(paths) < 2
            continue;
        end
        is_focus = any(strcmpi(key, cfg.focus_names));
        rows = [rows; table(string(key), numel(paths), logical(is_focus), string(strjoin(paths, ' | ')), ...
            'VariableNames', {'function_name', 'duplicate_count', 'is_focus_name', 'paths'})]; %#ok<AGROW>
    end

    if ~isempty(rows)
        rows = sortrows(rows, {'is_focus_name', 'duplicate_count'}, {'descend', 'descend'});
    end

    report = struct();
    report.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    report.scan_roots = cfg.scan_roots;
    report.focus_names = cfg.focus_names;
    report.total_m_files = numel(files);
    report.duplicate_table = rows;

    if cfg.write_report
        if ~isfolder(cfg.report_root)
            mkdir(cfg.report_root);
        end
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        mat_path = fullfile(cfg.report_root, ['path_collisions_' timestamp '.mat']);
        md_path = fullfile(cfg.report_root, ['path_collisions_' timestamp '.md']);
        save(mat_path, 'report');
        write_markdown(md_path, report);
        report.report_mat = mat_path;
        report.report_md = md_path;
    end
end

function files = list_m_files(root_dir)
    files = {};
    items = dir(root_dir);
    for i = 1:numel(items)
        name = items(i).name;
        if strcmp(name, '.') || strcmp(name, '..')
            continue;
        end
        p = fullfile(root_dir, name);
        if items(i).isdir
            files = [files; list_m_files(p)]; %#ok<AGROW>
        else
            if endsWith(name, '.m', 'IgnoreCase', true)
                files{end + 1, 1} = p; %#ok<AGROW>
            end
        end
    end
end

function write_markdown(file_path, report)
    fid = fopen(file_path, 'w');
    c = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# Path Collision Report\n\n');
    fprintf(fid, '- timestamp: %s\n', report.timestamp);
    fprintf(fid, '- total_m_files: %d\n\n', report.total_m_files);

    if isempty(report.duplicate_table)
        fprintf(fid, 'No duplicate function names detected in scanned roots.\n');
        return;
    end

    fprintf(fid, '| function_name | duplicate_count | is_focus_name |\n');
    fprintf(fid, '| --- | ---: | :---: |\n');
    for i = 1:height(report.duplicate_table)
        fprintf(fid, '| %s | %d | %d |\n', ...
            char(report.duplicate_table.function_name(i)), ...
            report.duplicate_table.duplicate_count(i), ...
            report.duplicate_table.is_focus_name(i));
    end
end
