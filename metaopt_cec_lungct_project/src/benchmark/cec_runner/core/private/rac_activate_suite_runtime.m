function runtime_session = rac_activate_suite_runtime(paths, suite_api)
% rac_activate_suite_runtime
% Activate suite-scoped runtime paths and working directory.

    runtime_session = struct();
    path_cleanup = rac_setup_algorithm_paths(paths.compat_dir, suite_api.suite_dir);
    runtime_session.path_cleanup = path_cleanup;

    old_dir = pwd;
    cd(suite_api.runtime_dir);

    runtime_session.cleanup = onCleanup(@() restore_runtime(path_cleanup, old_dir));
end

function restore_runtime(path_cleanup, old_dir)
    rac_teardown_algorithm_paths(path_cleanup);
    cd(old_dir);
end
