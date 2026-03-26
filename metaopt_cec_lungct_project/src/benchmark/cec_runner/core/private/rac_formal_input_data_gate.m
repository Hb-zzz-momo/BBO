function gate = rac_formal_input_data_gate(run_cfg)
% rac_formal_input_data_gate
% Formal preflight gate for CEC input_data readability.
% Why: prevent invalid formal runs caused by unreadable/missing input_data.

    gate = struct();
    gate.pass = true;
    gate.checked = struct('suite', {}, 'pass', {}, 'error_message', {}, ...
        'runtime_dir', {}, 'expected_mex_dir', {});
    gate.errors = {};

    paths = rac_resolve_common_paths();
    suites = run_cfg.suites;

    for i = 1:numel(suites)
        suite_name = string(suites{i});
        if ~any(strcmpi(suite_name, {'cec2017', 'cec2022'}))
            continue;
        end

        item = check_one_suite(paths, char(suite_name), run_cfg.dim);
        gate.checked(end + 1) = item; %#ok<AGROW>

        if ~item.pass
            gate.pass = false;
            gate.errors{end + 1} = item.error_message; %#ok<AGROW>
        end
    end
end

function item = check_one_suite(paths, suite_name, dim)
    item = struct();
    item.suite = suite_name;
    item.pass = true;
    item.error_message = '';

    if strcmpi(suite_name, 'cec2017')
        suite_dir = fullfile(paths.bbo_root, 'CEC2017');
        mex_dir = paths.mex_cec2017_dir;
    else
        suite_dir = fullfile(paths.bbo_root, 'CEC2022');
        mex_dir = paths.mex_cec2022_dir;
    end

    runtime_dir = resolve_runtime_dir_for_gate(suite_dir, mex_dir);
    item.runtime_dir = runtime_dir;
    item.expected_mex_dir = mex_dir;

    % Formal gate: enforce runtime_dir to be mex directory to avoid
    % fallback into suite_dir with incomplete input_data.
    if ~paths_equal(runtime_dir, mex_dir)
        item.pass = false;
        item.error_message = sprintf('[formal_gate][%s] runtime_dir is not mex dir: runtime=%s, mex=%s', ...
            suite_name, runtime_dir, mex_dir);
        return;
    end

    [ok, msg] = validate_input_data_dir(runtime_dir, dim);
    if ~ok
        item.pass = false;
        item.error_message = sprintf('[formal_gate][%s] %s', suite_name, msg);
    end
end

function runtime_dir = resolve_runtime_dir_for_gate(suite_dir, mex_dir)
    runtime_mode = strtrim(getenv('CEC_RUNTIME_DIR_MODE'));
    if strcmpi(runtime_mode, 'suite')
        runtime_dir = suite_dir;
        return;
    elseif strcmpi(runtime_mode, 'mex')
        runtime_dir = mex_dir;
        return;
    end

    if is_runtime_dir_valid(mex_dir)
        runtime_dir = mex_dir;
        return;
    end

    if is_runtime_dir_valid(suite_dir)
        runtime_dir = suite_dir;
        return;
    end

    runtime_dir = suite_dir;
end

function [ok, msg] = validate_input_data_dir(runtime_dir, dim)
    ok = false;
    msg = '';

    if ~isfolder(runtime_dir)
        msg = sprintf('runtime_dir missing: %s', runtime_dir);
        return;
    end

    input_dir = fullfile(runtime_dir, 'input_data');
    if ~isfolder(input_dir)
        msg = sprintf('input_data folder missing: %s', input_dir);
        return;
    end

    listing = dir(fullfile(input_dir, '*'));
    listing = listing(~[listing.isdir]);
    if isempty(listing)
        msg = sprintf('input_data folder is empty: %s', input_dir);
        return;
    end

    key_files = {sprintf('M_1_D%d.txt', dim), 'shift_data_1.txt'};
    for i = 1:numel(key_files)
        fp = fullfile(input_dir, key_files{i});
        if ~isfile(fp)
            msg = sprintf('required input_data file missing: %s', fp);
            return;
        end

        [fok, ferr] = test_file_readable(fp);
        if ~fok
            msg = sprintf('required input_data file unreadable: %s (%s)', fp, ferr);
            return;
        end
    end

    ok = true;
end

function tf = is_runtime_dir_valid(runtime_dir)
    tf = false;
    if ~isfolder(runtime_dir)
        return;
    end

    input_dir = fullfile(runtime_dir, 'input_data');
    if ~isfolder(input_dir)
        return;
    end

    listing = dir(fullfile(input_dir, '*'));
    listing = listing(~[listing.isdir]);
    tf = ~isempty(listing);
end

function [ok, err] = test_file_readable(fp)
    ok = false;
    err = '';

    [fid, msg] = fopen(fp, 'r');
    if fid < 0
        err = msg;
        return;
    end

    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    first_char = fread(fid, 1, '*char');
    if isempty(first_char)
        err = 'empty file';
        return;
    end

    ok = true;
end

function tf = paths_equal(a, b)
    tf = strcmpi(normalize_path(a), normalize_path(b));
end

function p = normalize_path(p)
    p = strrep(char(p), '/', filesep);
    p = strrep(p, '\\', '\');
end
