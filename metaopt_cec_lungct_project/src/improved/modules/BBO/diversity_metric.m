function d = diversity_metric(population, lb, ub)
% diversity_metric
% Return normalized population diversity for state-trigger conditions.

    span = ub - lb;
    span(span <= 1e-12) = 1;
    scaled_std = std(population, 0, 1) ./ span;
    d = mean(scaled_std);
    if ~isfinite(d)
        d = 0;
    end
end
