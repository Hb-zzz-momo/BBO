function suite_api = rac_build_suite_api(paths, suite_name)
    suite_api = struct();
    suite_api.name = suite_name;

    if strcmpi(suite_name, 'cec2017')
        suite_api.suite_dir = fullfile(paths.bbo_root, 'CEC2017');
        suite_api.runtime_dir = rac_resolve_cec_runtime_dir(fullfile(paths.bbo_root, 'CEC2017'));
        suite_api.get_function = @rac_get_cec2017_function;
        suite_api.default_func_ids = 1:30;
    else
        suite_api.suite_dir = fullfile(paths.bbo_root, 'CEC2022');
        suite_api.runtime_dir = rac_resolve_cec_runtime_dir(fullfile(paths.bbo_root, 'CEC2022'));
        suite_api.get_function = @rac_get_cec2022_function;
        suite_api.default_func_ids = 1:12;
    end

    if ~isfolder(suite_api.suite_dir)
        error('Suite folder not found: %s', suite_api.suite_dir);
    end

    if ~isfolder(suite_api.runtime_dir)
        error('Runtime folder not found: %s', suite_api.runtime_dir);
    end
end

function [lb, ub, dim, fobj] = rac_get_cec2017_function(fid, dim)
    suite_dir = rac_resolve_suite_dir('cec2017');
    rac_ensure_cec_runtime_path(suite_dir);
    if exist('Get_Functions_cec2017', 'file') ~= 2
        rac_ensure_suite_getter_on_path('cec2017');
    end
    [lb, ub, dim, fobj] = rac_call_getter_in_suite_dir(@() Get_Functions_cec2017(fid, dim), suite_dir);
end

function [lb, ub, dim, fobj] = rac_get_cec2022_function(fid, dim)
    suite_dir = rac_resolve_suite_dir('cec2022');
    rac_ensure_cec_runtime_path(suite_dir);
    if exist('Get_Functions_cec2022', 'file') ~= 2
        rac_ensure_suite_getter_on_path('cec2022');
    end
    [lb, ub, dim, fobj] = rac_call_getter_in_suite_dir(@() Get_Functions_cec2022(fid, dim), suite_dir);
end

function suite_dir = rac_resolve_suite_dir(suite_name)
    paths = rac_resolve_common_paths();
    if strcmpi(suite_name, 'cec2017')
        suite_dir = fullfile(paths.bbo_root, 'CEC2017');
    else
        suite_dir = fullfile(paths.bbo_root, 'CEC2022');
    end
    if ~isfolder(suite_dir)
        error('Suite folder not found while resolving suite dir: %s', suite_dir);
    end
end

function [lb, ub, dim, fobj] = rac_call_getter_in_suite_dir(getter_fn, suite_dir)
    old_dir = pwd;
    cd(suite_dir);
    cleanup_obj = onCleanup(@() cd(old_dir)); %#ok<NASGU>
    rac_ensure_cec_runtime_path(suite_dir);
    [lb, ub, dim, fobj] = getter_fn();
end

function rac_ensure_suite_getter_on_path(suite_name)
    suite_dir = rac_resolve_suite_dir(suite_name);
    if isfolder(suite_dir)
        addpath(suite_dir);
    else
        error('Suite folder not found while repairing path: %s', suite_dir);
    end
end

function rac_ensure_cec_runtime_path(suite_dir)
    paths = rac_resolve_common_paths();

    if isfolder(suite_dir) && ~rac_is_path_entry_active(suite_dir)
        addpath(suite_dir, '-begin');
    end

    if contains(upper(suite_dir), 'CEC2017')
        if isfolder(paths.mex_cec2017_dir) && ~rac_is_path_entry_active(paths.mex_cec2017_dir)
            addpath(paths.mex_cec2017_dir, '-begin');
        end
    else
        if isfolder(paths.mex_cec2022_dir) && ~rac_is_path_entry_active(paths.mex_cec2022_dir)
            addpath(paths.mex_cec2022_dir, '-begin');
        end
    end
end

function runtime_dir = rac_resolve_cec_runtime_dir(suite_dir)
    paths = rac_resolve_common_paths();

    if contains(upper(suite_dir), 'CEC2017')
        candidate = paths.mex_cec2017_dir;
    else
        candidate = paths.mex_cec2022_dir;
    end

    % Diagnostic-only override for A/B runtime-dir checks.
    % Default behavior remains unchanged when env var is empty.
    runtime_mode = strtrim(getenv('CEC_RUNTIME_DIR_MODE'));
    if strcmpi(runtime_mode, 'suite')
        runtime_dir = suite_dir;
        return;
    elseif strcmpi(runtime_mode, 'mex')
        runtime_dir = candidate;
        return;
    end

    if is_runtime_dir_valid(candidate)
        runtime_dir = candidate;
        return;
    end

    if is_runtime_dir_valid(suite_dir)
        runtime_dir = suite_dir;
        return;
    end

    runtime_dir = suite_dir;
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
