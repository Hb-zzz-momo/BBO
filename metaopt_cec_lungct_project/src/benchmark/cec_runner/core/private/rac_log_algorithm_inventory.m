function rac_log_algorithm_inventory(log_file, inventory)
    for i = 1:numel(inventory)
        rac_log_message(log_file, sprintf('Algorithm %s | runnable=%d | entry=%s | budget=%s | fe_mode=%s | note=%s', ...
            inventory(i).name, inventory(i).is_runnable, inventory(i).entry_name, inventory(i).budget_arg, inventory(i).fe_control_mode, inventory(i).note));
    end
end
