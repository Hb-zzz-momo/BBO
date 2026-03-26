function root = rac_compute_result_root(repo_root, suite_name, cfg)
% rac_compute_result_root
% Central result root policy to keep suite/layout behavior consistent.

    if isfield(cfg, 'result_layout') && strcmpi(string(cfg.result_layout), "experiment_then_suite")
        if isfield(cfg, 'result_group') && ~isempty(cfg.result_group)
            root = fullfile(repo_root, cfg.result_root, cfg.result_group, cfg.experiment_name, lower(suite_name));
        else
            root = fullfile(repo_root, cfg.result_root, cfg.experiment_name, lower(suite_name));
        end
    else
        if isfield(cfg, 'result_group') && ~isempty(cfg.result_group)
            root = fullfile(repo_root, cfg.result_root, cfg.result_group, lower(suite_name), cfg.experiment_name);
        else
            root = fullfile(repo_root, cfg.result_root, lower(suite_name), cfg.experiment_name);
        end
    end
end
