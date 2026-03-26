function wilcoxon_table = metrics_build_wilcoxon_rank_sum_table(summary_table, run_results, mode_info)
% metrics_build_wilcoxon_rank_sum_table
% Pairwise Wilcoxon rank-sum test table per function.

    algs = unique(string(summary_table.algorithm_name), 'stable');
    rows = table();
    funcs = unique(summary_table.function_id, 'stable');

    if isempty(run_results)
        for i = 1:numel(algs)
            for j = i+1:numel(algs)
                row = table( ...
                    NaN, ...
                    algs(i), ...
                    algs(j), ...
                    NaN, ...
                    NaN, ...
                    NaN, ...
                    NaN, ...
                    string(sprintf('run_results_missing_mode_%s', mode_info.mode)), ...
                    'VariableNames', {'function_id','algorithm_a','algorithm_b','p_value','h','z_value','sample_size','note'});
                rows = [rows; row]; %#ok<AGROW>
            end
        end
        wilcoxon_table = rows;
        return;
    end

    has_ranksum = exist('ranksum', 'file') == 2;
    for f = 1:numel(funcs)
        fid = funcs(f);
        subset_f = run_results([run_results.function_id] == fid);

        for i = 1:numel(algs)
            for j = i+1:numel(algs)
                xa = metrics_extract_scores(subset_f, algs(i));
                xb = metrics_extract_scores(subset_f, algs(j));

                if numel(xa) < 2 || numel(xb) < 2
                    row = table( ...
                        fid, ...
                        algs(i), ...
                        algs(j), ...
                        NaN, ...
                        NaN, ...
                        NaN, ...
                        min(numel(xa), numel(xb)), ...
                        "insufficient_samples", ...
                        'VariableNames', {'function_id','algorithm_a','algorithm_b','p_value','h','z_value','sample_size','note'});
                    rows = [rows; row]; %#ok<AGROW>
                    continue;
                end

                if has_ranksum
                    p = NaN;
                    h = NaN;
                    z = NaN;
                    try
                        [p, h, stats] = ranksum(xa, xb);
                        if isstruct(stats) && isfield(stats, 'zval')
                            z = stats.zval;
                        end
                        note = "wilcoxon_rank_sum";
                    catch ME
                        note = string(['ranksum_error_' ME.identifier]);
                    end
                else
                    p = NaN;
                    h = NaN;
                    z = NaN;
                    note = "ranksum_unavailable";
                end

                row = table( ...
                    fid, ...
                    algs(i), ...
                    algs(j), ...
                    p, ...
                    h, ...
                    z, ...
                    min(numel(xa), numel(xb)), ...
                    note, ...
                    'VariableNames', {'function_id','algorithm_a','algorithm_b','p_value','h','z_value','sample_size','note'});
                rows = [rows; row]; %#ok<AGROW>
            end
        end
    end

    wilcoxon_table = rows;
end
