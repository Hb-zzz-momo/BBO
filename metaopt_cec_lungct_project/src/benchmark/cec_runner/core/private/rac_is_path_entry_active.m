function tf = rac_is_path_entry_active(target_dir)
    current_parts = strsplit(path, pathsep);
    current_parts = current_parts(~cellfun(@isempty, current_parts));
    target_norm = normalize_path_local(target_dir);
    active_norm = cellfun(@normalize_path_local, current_parts, 'UniformOutput', false);
    active_norm = active_norm(~cellfun(@isempty, active_norm));

    if isempty(target_norm)
        tf = false;
        return;
    end
    tf = any(strcmpi(active_norm, target_norm));
end

function p = normalize_path_local(p0)
    p = char(string(p0));
    if isempty(p)
        return;
    end

    % Normalize separators and collapse duplicate trailing separators.
    p = strrep(p, '/', filesep);
    p = strrep(p, '\\', filesep);
    while numel(p) > 1 && (p(end) == filesep || p(end) == '/')
        p(end) = [];
    end

    % Try to canonicalize existing paths so comparisons are robust to '..'.
    [ok, info] = fileattrib(p);
    if ok && isfield(info, 'Name')
        p = info.Name;
        p = strrep(p, '/', filesep);
        while numel(p) > 1 && (p(end) == filesep || p(end) == '/')
            p(end) = [];
        end
    end
end
