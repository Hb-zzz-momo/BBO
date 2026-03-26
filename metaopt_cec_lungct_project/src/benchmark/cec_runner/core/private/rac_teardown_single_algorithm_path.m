function rac_teardown_single_algorithm_path(algorithm_dir)
    if isfolder(algorithm_dir) && rac_is_path_entry_active(algorithm_dir)
        rmpath(algorithm_dir);
    end
    if rac_is_path_entry_active(algorithm_dir)
        warning('CECRunner:PathRemoveFailed', 'Algorithm path still active after teardown: %s', algorithm_dir);
    end
end
