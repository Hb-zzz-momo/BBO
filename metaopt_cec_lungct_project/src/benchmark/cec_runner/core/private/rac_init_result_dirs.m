function result_dir = rac_init_result_dirs(repo_root, suite_name, cfg)
    root = rac_compute_result_root(repo_root, suite_name, cfg);

    result_dir = struct();
    result_dir.root = root;
    result_dir.tables = fullfile(root, 'tables');
    result_dir.raw_runs = fullfile(root, 'raw_runs');
    result_dir.curves = fullfile(root, 'curves');
    result_dir.logs = fullfile(root, 'logs');
    result_dir.figures = fullfile(root, cfg.plot.subdir);

    if ~isfolder(root)
        mkdir(root);
    end
    if ~isfolder(result_dir.tables)
        mkdir(result_dir.tables);
    end
    if ~isfolder(result_dir.raw_runs)
        mkdir(result_dir.raw_runs);
    end
    if ~isfolder(result_dir.curves)
        mkdir(result_dir.curves);
    end
    if ~isfolder(result_dir.logs)
        mkdir(result_dir.logs);
    end
    if ~isfolder(result_dir.figures)
        mkdir(result_dir.figures);
    end
end
