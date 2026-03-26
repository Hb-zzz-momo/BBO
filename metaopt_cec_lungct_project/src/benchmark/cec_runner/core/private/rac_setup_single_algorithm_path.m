function p = rac_setup_single_algorithm_path(algorithm_dir, prepend_to_path)
    if nargin < 2
        prepend_to_path = true;
    end

    target_dir = canonicalize_path_local(algorithm_dir);

    if ~rac_is_path_entry_active(target_dir)
        if prepend_to_path
            addpath(target_dir, '-begin');
        else
            addpath(target_dir);
        end
    end
    if ~rac_is_path_entry_active(target_dir)
        warning('CECRunner:PathAddFailed', 'Failed to activate algorithm path: %s', target_dir);
    end
    p = target_dir;
end

function p = canonicalize_path_local(p0)
    p = char(string(p0));
    p = strrep(p, '/', filesep);

    [ok, info] = fileattrib(p);
    if ok && isfield(info, 'Name')
        p = info.Name;
    end

    p = strrep(p, '/', filesep);
    while numel(p) > 1 && (p(end) == filesep || p(end) == '/')
        p(end) = [];
    end
end
