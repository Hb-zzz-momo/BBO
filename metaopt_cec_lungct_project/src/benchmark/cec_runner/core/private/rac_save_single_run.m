function rac_save_single_run(result_dir, run_result, cfg)
    if ~cfg.save_mat
        return;
    end

    file_name = sprintf('%s_F%d_run%03d.mat', ...
        lower(run_result.algorithm_name), run_result.function_id, run_result.run_id);
    save(fullfile(result_dir.raw_runs, file_name), 'run_result');
end
