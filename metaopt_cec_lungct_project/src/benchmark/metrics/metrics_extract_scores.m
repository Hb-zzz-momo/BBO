function scores = metrics_extract_scores(run_results_subset, alg_name)
% metrics_extract_scores
% Extract finite best_score samples for one algorithm from run_results subset.

    if isempty(run_results_subset)
        scores = [];
        return;
    end

    idx = strcmp(string({run_results_subset.algorithm_name}), string(alg_name));
    subset = run_results_subset(idx);
    if isempty(subset)
        scores = [];
        return;
    end

    scores = [subset.best_score];
    scores = scores(isfinite(scores));
end
