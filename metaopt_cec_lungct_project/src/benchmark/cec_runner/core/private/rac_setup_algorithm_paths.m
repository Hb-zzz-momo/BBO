function path_state = rac_setup_algorithm_paths(compat_dir, suite_dir)
    path_state = {};
    addpath(compat_dir);
    path_state{end + 1} = compat_dir;
    addpath(suite_dir);
    path_state{end + 1} = suite_dir;
end
