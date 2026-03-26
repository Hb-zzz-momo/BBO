function rank_table = metrics_build_rank_table(summary_table)
% metrics_build_rank_table
% Build per-function rank table from summary mean scores.

    funcs = unique(summary_table.function_id, 'stable');
    rows = table();

    for i = 1:numel(funcs)
        fid = funcs(i);
        subset = summary_table(summary_table.function_id == fid, :);
        if isempty(subset)
            continue;
        end

        scores = subset.mean(:)';
        ranks = metrics_average_tie_ranks(scores);

        for k = 1:height(subset)
            row = table( ...
                string(subset.algorithm_name(k)), ...
                fid, ...
                subset.mean(k), ...
                ranks(k), ...
                'VariableNames', {'algorithm_name','function_id','mean_score','rank'});
            rows = [rows; row]; %#ok<AGROW>
        end
    end

    rank_table = rows;
end
