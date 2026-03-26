function ids = rac_resolve_function_ids_for_suite(func_ids_cfg, suite_name)
    if isstruct(func_ids_cfg)
        if isfield(func_ids_cfg, suite_name)
            ids = func_ids_cfg.(suite_name);
            return;
        end
        if isfield(func_ids_cfg, 'all')
            ids = func_ids_cfg.all;
            return;
        end
        error('func_ids struct must contain field "%s" or "all".', suite_name);
    end

    if isempty(func_ids_cfg)
        if strcmpi(suite_name, 'cec2017')
            ids = 1:30;
        else
            ids = 1:12;
        end
        return;
    end

    ids = func_ids_cfg;
end
