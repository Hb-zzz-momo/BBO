function [friedman_summary, friedman_ranks] = metrics_build_friedman_tables(summary_table, run_results, mode_info)
% metrics_build_friedman_tables
% Build Friedman global test summary and average rank table.

    algs = unique(string(summary_table.algorithm_name), 'stable');
    funcs = unique(summary_table.function_id, 'stable');

    friedman_ranks = table();

    if numel(algs) < 2 || numel(funcs) < 2
        friedman_summary = table(string(mode_info.mode), NaN, NaN, NaN, numel(algs), numel(funcs), "insufficient_algorithms_or_functions", ...
            'VariableNames', {'mode','p_value','chi_square','df','algorithm_count','function_count','note'});
        return;
    end

    score_mat = NaN(numel(funcs), numel(algs));
    if ~isempty(run_results)
        for fi = 1:numel(funcs)
            subset_f = run_results([run_results.function_id] == funcs(fi));
            for ai = 1:numel(algs)
                xa = metrics_extract_scores(subset_f, algs(ai));
                if ~isempty(xa)
                    score_mat(fi, ai) = mean(xa);
                end
            end
        end
    else
        for fi = 1:numel(funcs)
            subset_s = summary_table(summary_table.function_id == funcs(fi), :);
            for ai = 1:numel(algs)
                hit = subset_s(string(subset_s.algorithm_name) == algs(ai), :);
                if ~isempty(hit)
                    score_mat(fi, ai) = hit.mean(1);
                end
            end
        end
    end

    valid_rows = all(isfinite(score_mat), 2);
    score_mat = score_mat(valid_rows, :);

    if size(score_mat, 1) < 2
        friedman_summary = table(string(mode_info.mode), NaN, NaN, NaN, numel(algs), size(score_mat, 1), "insufficient_complete_function_rows", ...
            'VariableNames', {'mode','p_value','chi_square','df','algorithm_count','function_count','note'});
        return;
    end

    avg_rank = zeros(1, size(score_mat, 2));
    for i = 1:size(score_mat, 1)
        avg_rank = avg_rank + metrics_average_tie_ranks(score_mat(i, :));
    end
    avg_rank = avg_rank / size(score_mat, 1);

    has_friedman = exist('friedman', 'file') == 2;
    p = NaN;
    chi2 = NaN;
    df = size(score_mat, 2) - 1;
    note = "friedman_unavailable";

    if has_friedman
        try
            [p, tbl] = friedman(score_mat, 1, 'off');
            if iscell(tbl) && size(tbl,1) >= 2 && size(tbl,2) >= 5
                chi2 = tbl{2, 5};
                if ~isfinite(chi2)
                    chi2 = NaN;
                end
            end
            note = "friedman_test";
        catch ME
            note = string(['friedman_error_' ME.identifier]);
        end
    end

    friedman_summary = table( ...
        string(mode_info.mode), ...
        p, ...
        chi2, ...
        df, ...
        numel(algs), ...
        size(score_mat, 1), ...
        note, ...
        'VariableNames', {'mode','p_value','chi_square','df','algorithm_count','function_count','note'});

    friedman_ranks = table( ...
        algs(:), ...
        avg_rank(:), ...
        repmat(size(score_mat, 1), numel(algs), 1), ...
        'VariableNames', {'algorithm_name','avg_rank','comparable_function_count'});
end
