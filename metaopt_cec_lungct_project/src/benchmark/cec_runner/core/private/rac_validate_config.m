function rac_validate_config(cfg)
    if cfg.pop_size <= 0 || cfg.maxFEs <= 0 || cfg.runs <= 0 || cfg.dim <= 0
        error('dim, pop_size, maxFEs, runs must be > 0.');
    end
    if any(mod(cfg.dim, 1) ~= 0) || any(mod(cfg.pop_size, 1) ~= 0) || any(mod(cfg.runs, 1) ~= 0)
        error('dim, pop_size, runs must be integers.');
    end
    suites = rac_normalize_suite_list(cfg.suites);
    supported = {'cec2017', 'cec2022'};
    for i = 1:numel(suites)
        if ~any(strcmpi(suites{i}, supported))
            error('Unsupported suite: %s. Use cec2017 or cec2022.', suites{i});
        end
    end
    if ~isempty(cfg.func_ids) && isnumeric(cfg.func_ids)
        if any(cfg.func_ids < 1) || any(mod(cfg.func_ids, 1) ~= 0)
            error('func_ids must be positive integer ids.');
        end
    end
    if ~isstruct(cfg.plot)
        error('cfg.plot must be a struct.');
    end
    if cfg.plot.dpi <= 0
        error('cfg.plot.dpi must be > 0.');
    end
    if cfg.plot.behavior.max_funcs <= 0 || mod(cfg.plot.behavior.max_funcs, 1) ~= 0
        error('cfg.plot.behavior.max_funcs must be a positive integer.');
    end
end
