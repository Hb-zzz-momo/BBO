function export_info = export_benchmark_aggregate(result_dir, summary_table, run_cfg, mode_info, export_cfg)
% export_benchmark_aggregate
% Save paper-facing aggregate tables from per-function benchmark summary.

    export_info = struct();
    export_info.result_dir = result_dir;

    if isempty(summary_table) || ~istable(summary_table)
        export_info.aggregate_table = table();
        export_info.rank_table = table();
        export_info.wilcoxon_table = table();
        export_info.friedman_summary = table();
        export_info.friedman_ranks = table();
        return;
    end

    aggregate_table = metrics_build_aggregate_table(summary_table);
    rank_table = metrics_build_rank_table(summary_table);
    run_results = load_run_results_if_available(result_dir);
    [wilcoxon_table, friedman_summary, friedman_ranks] = build_significance_tables(summary_table, run_results, mode_info, export_cfg);

    if isfield(export_cfg, 'aggregate_csv') && export_cfg.aggregate_csv
        writetable(aggregate_table, fullfile(result_dir, 'aggregate_stats.csv'));
        writetable(rank_table, fullfile(result_dir, 'rank_table.csv'));
        if ~isempty(wilcoxon_table)
            writetable(wilcoxon_table, fullfile(result_dir, 'wilcoxon_rank_sum.csv'));
        end
        if ~isempty(friedman_summary)
            writetable(friedman_summary, fullfile(result_dir, 'friedman_summary.csv'));
        end
        if ~isempty(friedman_ranks)
            writetable(friedman_ranks, fullfile(result_dir, 'friedman_ranks.csv'));
        end
    end

    if isfield(export_cfg, 'aggregate_xlsx') && export_cfg.aggregate_xlsx
        xlsx_path = fullfile(result_dir, 'summary_exports.xlsx');
        write_table_sheet(xlsx_path, aggregate_table, 'aggregate_stats');
        write_table_sheet(xlsx_path, rank_table, 'rank_table');
        write_table_sheet(xlsx_path, wilcoxon_table, 'wilcoxon');
        write_table_sheet(xlsx_path, friedman_summary, 'friedman_summary');
        write_table_sheet(xlsx_path, friedman_ranks, 'friedman_ranks');
    end

    if isfield(export_cfg, 'aggregate_mat') && export_cfg.aggregate_mat
        save(fullfile(result_dir, 'aggregate_exports.mat'), ...
            'aggregate_table', 'rank_table', 'wilcoxon_table', 'friedman_summary', 'friedman_ranks', 'run_cfg', 'mode_info');
    end

    export_info.aggregate_table = aggregate_table;
    export_info.rank_table = rank_table;
    export_info.wilcoxon_table = wilcoxon_table;
    export_info.friedman_summary = friedman_summary;
    export_info.friedman_ranks = friedman_ranks;
end

function run_results = load_run_results_if_available(result_dir)
    run_results = [];
    summary_mat = fullfile(result_dir, 'summary.mat');
    if ~isfile(summary_mat)
        return;
    end

    S = load(summary_mat, 'run_results');
    if isfield(S, 'run_results')
        run_results = S.run_results;
    end
end

function [wilcoxon_table, friedman_summary, friedman_ranks] = build_significance_tables(summary_table, run_results, mode_info, export_cfg)
    wilcoxon_table = table();
    friedman_summary = table();
    friedman_ranks = table();

    if isfield(export_cfg, 'wilcoxon') && export_cfg.wilcoxon
        wilcoxon_table = metrics_build_wilcoxon_rank_sum_table(summary_table, run_results, mode_info);
    end

    if isfield(export_cfg, 'friedman') && export_cfg.friedman
        [friedman_summary, friedman_ranks] = metrics_build_friedman_tables(summary_table, run_results, mode_info);
    end
end

function write_table_sheet(xlsx_path, T, sheet_name)
    if isempty(T)
        return;
    end

    try
        writetable(T, xlsx_path, 'Sheet', sheet_name);
    catch
        % Keep csv/mat pipeline as primary; xlsx failure should not break experiment flow.
    end
end
