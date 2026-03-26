function ids = rac_validate_func_ids_for_suite(ids, suite_name)
    if isempty(ids)
        error('Resolved function ids are empty.');
    end

    if any(ids < 1) || any(mod(ids, 1) ~= 0)
        error('func_ids must be positive integer ids.');
    end

    if strcmpi(suite_name, 'cec2017') && any(ids > 30)
        error('cec2017 supports function ids in [1, 30].');
    end

    if strcmpi(suite_name, 'cec2022') && any(ids > 12)
        error('cec2022 supports function ids in [1, 12].');
    end

    ids = unique(ids, 'stable');
end
