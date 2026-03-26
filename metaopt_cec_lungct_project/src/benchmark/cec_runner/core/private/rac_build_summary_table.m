function summary_table = rac_build_summary_table(run_results)
    if isempty(run_results)
        summary_table = table();
        return;
    end

    algs = unique(string({run_results.algorithm_name}));
    fids = unique([run_results.function_id]);

    rows = table();
    for i = 1:numel(algs)
        for j = 1:numel(fids)
            idx = strcmp({run_results.algorithm_name}, char(algs(i))) & [run_results.function_id] == fids(j);
            subset = run_results(idx);
            if isempty(subset)
                continue;
            end

            scores = [subset.best_score];
            runtimes = [subset.runtime];
            used_fes = [subset.used_FEs];

            row = table( ...
                string(algs(i)), ...
                fids(j), ...
                min(scores), ...
                mean(scores), ...
                std(scores), ...
                max(scores), ...
                median(scores), ...
                mean(runtimes), ...
                mean(used_fes), ...
                'VariableNames', {'algorithm_name','function_id','best','mean','std','worst','median','avg_runtime','avg_used_FEs'});

            rows = [rows; row]; %#ok<AGROW>
        end
    end

    summary_table = rows;
end
