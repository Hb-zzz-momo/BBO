function rac_save_curve_file(result_dir, run_result, cfg)
    curve = run_result.convergence_curve;

    if cfg.save_mat
        mat_name = sprintf('%s_F%d_run%03d_curve.mat', ...
            lower(run_result.algorithm_name), run_result.function_id, run_result.run_id);
        save(fullfile(result_dir.curves, mat_name), 'curve');
    end

    if cfg.save_csv
        csv_name = sprintf('%s_F%d_run%03d_curve.csv', ...
            lower(run_result.algorithm_name), run_result.function_id, run_result.run_id);
        writematrix(curve(:), fullfile(result_dir.curves, csv_name));
    end
end
