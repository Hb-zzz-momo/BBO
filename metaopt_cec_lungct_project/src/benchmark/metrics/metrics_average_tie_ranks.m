function ranks = metrics_average_tie_ranks(scores)
% metrics_average_tie_ranks
% Compute average ranks with tie handling (smaller score gets better rank).

    [sorted_scores, order] = sort(scores, 'ascend');
    ranks = zeros(size(scores));

    i = 1;
    while i <= numel(sorted_scores)
        j = i;
        while j < numel(sorted_scores) && sorted_scores(j + 1) == sorted_scores(i)
            j = j + 1;
        end
        avg_rank = mean(i:j);
        ranks(order(i:j)) = avg_rank;
        i = j + 1;
    end
end
