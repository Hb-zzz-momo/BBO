function rac_save_algorithm_inventory(result_root, inventory, cfg)
    table_rows = table();
    for i = 1:numel(inventory)
        row = table(string(inventory(i).name), logical(inventory(i).is_runnable), ...
            string(inventory(i).entry_name), string(inventory(i).algorithm_dir), ...
            string(inventory(i).budget_arg), string(inventory(i).fe_control_mode), string(inventory(i).note), ...
            'VariableNames', {'algorithm_name','is_runnable','entry_name','algorithm_dir','budget_arg','fe_control_mode','note'});
        table_rows = [table_rows; row]; %#ok<AGROW>
    end

    if cfg.save_csv
        writetable(table_rows, fullfile(result_root, 'algorithm_inventory.csv'));
    end

    if cfg.save_mat
        save(fullfile(result_root, 'algorithm_inventory.mat'), 'table_rows', 'inventory');
    end
end
