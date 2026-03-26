function inventory = rac_build_algorithm_inventory(paths, suite_api, selected_algorithms, maxFEs, pop_size)
% Build runnable algorithm inventory and FE-control annotations.

    alg_list = cellstr(string(selected_algorithms));

    template = struct('name', '', 'paper_name', '', 'internal_id', '', 'entry_name', '', 'algorithm_dir', '', ...
        'budget_arg', '', 'output_mode', '', 'is_runnable', false, ...
        'fe_control_mode', '', 'note', '', 'requested_name', '');
    inventory = repmat(template, 1, numel(alg_list));

    for i = 1:numel(alg_list)
        requested_name = upper(strtrim(alg_list{i}));
        resolved = resolve_algorithm_alias(requested_name);
        name = upper(strtrim(resolved.canonical_token));
        record = template;
        record.name = name;
        record.paper_name = char(resolved.paper_name);
        record.internal_id = char(lower(string(resolved.internal_id)));
        record.requested_name = requested_name;

        spec = resolve_algorithm_runtime_spec(paths, suite_api.name, name, alias_entry_name(resolved));
        if ~spec.is_supported
            record.fe_control_mode = 'not_supported';
            record.note = 'No wrapper implemented in benchmark kernel yet.';
            inventory(i) = record;
            continue;
        end

        record.entry_name = spec.entry_name;
        record.algorithm_dir = spec.algorithm_dir;
        record.budget_arg = spec.budget_arg;
        record.output_mode = spec.output_mode;

        entry_file = fullfile(spec.algorithm_dir, [spec.entry_name '.m']);
        record.is_runnable = isfolder(spec.algorithm_dir) && isfile(entry_file);

        if strcmp(spec.budget_arg, 'maxFEs')
            record.fe_control_mode = 'exact_fes_parameter';
            record.note = sprintf('%s uses MaxFEs directly; counted wrapper records used_FEs.', spec.entry_name);
        else
            [max_iter, used_est] = estimate_iteration_budget(pop_size, maxFEs);
            if used_est == maxFEs
                record.fe_control_mode = 'exact_derived_iteration_from_maxFEs';
                record.note = sprintf('%s uses iteration budget; derived Max_iteration=%d gives exact used_FEs=%d.', spec.entry_name, max_iter, used_est);
            else
                record.fe_control_mode = 'approx_derived_iteration_from_maxFEs';
                record.note = sprintf('%s uses iteration budget; derived Max_iteration=%d gives used_FEs=%d (< maxFEs=%d).', spec.entry_name, max_iter, used_est, maxFEs);
            end
        end

        if is_legacy_alias_name(requested_name)
            record.note = sprintf('%s [legacy_alias->%s]', record.note, spec.entry_name);
        end

        inventory(i) = record;
    end
end

function tf = is_legacy_alias_name(name)
    legacy_aliases = {
        'V3_FAST_SIMPLE_A', ...
        'V3_FAST_SIMPLE_B', ...
        'V3_DIR_LATE', ...
        'V3_DIR_STAGNATION', ...
        'V3_DIR_ELITE_ONLY', ...
        'V3_HYBRID_A_DIR_STAG', ...
        'V3_HYBRID_B_DIR_SMALL'};
    tf = any(strcmpi(string(name), string(legacy_aliases)));
end

function [max_iter, used_fes_est] = estimate_iteration_budget(pop_size, maxFEs)
    % Conservative FE-to-iteration estimate for iteration-budget algorithms.
    if maxFEs < pop_size
        max_iter = 0;
        used_fes_est = pop_size;
        return;
    end

    max_iter = floor((maxFEs - pop_size) / pop_size);
    if max_iter < 1
        max_iter = 1;
    end

    used_fes_est = pop_size + max_iter * pop_size;
end

function entry_name = alias_entry_name(resolved)
    entry_name = '';
    if isstruct(resolved) && isfield(resolved, 'entry_name') && ~isempty(resolved.entry_name)
        entry_name = resolved.entry_name;
    elseif isstruct(resolved) && isfield(resolved, 'entry_func') && ~isempty(resolved.entry_func)
        entry_name = resolved.entry_func;
    end
end
