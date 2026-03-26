function rac_teardown_algorithm_paths(path_state)
    for i = 1:numel(path_state)
        if isfolder(path_state{i}) && rac_is_path_entry_active(path_state{i})
            rmpath(path_state{i});
        end
    end
end
