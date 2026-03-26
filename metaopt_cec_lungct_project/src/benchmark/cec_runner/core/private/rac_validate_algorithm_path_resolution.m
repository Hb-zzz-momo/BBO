function [ok, message] = rac_validate_algorithm_path_resolution(algorithm_dir, entry_name)
% rac_validate_algorithm_path_resolution
% Runtime guard: detect high-risk path resolution conflicts.
% Entry function resolution is mandatory; duplicated generic helpers are tolerated
% when the first active resolution still points to the target algorithm directory.

    if nargin < 2
        entry_name = '';
    end

    names = repmat({''}, 1, 0);
    if ~isempty(strtrim(char(entry_name)))
        names{end + 1} = strtrim(char(entry_name)); %#ok<AGROW>
    end

    if isempty(names)
        % Fallback for legacy callers without entry_name.
        names = {'initialization'};
    end

    names = unique(names, 'stable');
    conflicts = {};
    notices = {};

    for i = 1:numel(names)
        hits = which(names{i}, '-all');
        if ischar(hits)
            if isempty(strtrim(hits))
                hit_list = {};
            else
                hit_list = {strtrim(hits)};
            end
        else
            hit_list = hits;
        end

        if isempty(hit_list)
            continue;
        end

        expected_file = fullfile(algorithm_dir, [names{i} '.m']);

        in_alg = false(size(hit_list));
        for j = 1:numel(hit_list)
            in_alg(j) = startsWith(strrep(hit_list{j}, '/', filesep), strrep(algorithm_dir, '/', filesep), 'IgnoreCase', true);
        end

        if isfile(expected_file) && ~any(in_alg)
            conflicts{end + 1} = sprintf('%s expected in algorithm_dir but not resolved from active path', names{i}); %#ok<AGROW>
            continue;
        end

        if any(in_alg)
            first_hit = hit_list{1};
            first_in_alg = startsWith(strrep(first_hit, '/', filesep), strrep(algorithm_dir, '/', filesep), 'IgnoreCase', true);
            if ~first_in_alg
                conflicts{end + 1} = sprintf('%s first resolution points to another directory', names{i}); %#ok<AGROW>
                continue;
            end
        end

        if any(in_alg) && numel(hit_list) > 1
            notices{end + 1} = sprintf('%s has %d active definitions (first hit is target algorithm dir)', names{i}, numel(hit_list)); %#ok<AGROW>
        end
    end

    if isempty(conflicts)
        ok = true;
        if isempty(notices)
            message = 'no high-risk duplicate definitions detected for key names';
        else
            message = strjoin(notices, '; ');
        end
    else
        ok = false;
        message = strjoin(conflicts, '; ');
    end
end
