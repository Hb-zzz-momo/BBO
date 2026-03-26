function rac_save_summary(result_dir, summary_table, run_results, run_manifest, exact_match_warnings, cfg)
    if nargin < 5 || isempty(exact_match_warnings)
        exact_match_warnings = table();
    end

    if cfg.save_csv
        writetable(summary_table, fullfile(result_dir.root, 'summary.csv'));
        writetable(run_manifest, fullfile(result_dir.root, 'run_manifest.csv'));
        writetable(summary_table, fullfile(result_dir.tables, 'summary.csv'));
        writetable(run_manifest, fullfile(result_dir.tables, 'run_manifest.csv'));
        writetable(exact_match_warnings, fullfile(result_dir.root, 'exact_match_warnings.csv'));
        writetable(exact_match_warnings, fullfile(result_dir.tables, 'exact_match_warnings.csv'));
    end

    if cfg.save_mat
        save(fullfile(result_dir.root, 'summary.mat'), 'summary_table', 'run_results', 'run_manifest', 'exact_match_warnings');
        save(fullfile(result_dir.tables, 'summary.mat'), 'summary_table', 'run_results', 'run_manifest', 'exact_match_warnings');
    end
end
