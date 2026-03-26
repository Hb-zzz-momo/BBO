function [best_score, best_pos, curve] = BBO_ORIG(pop_size, max_iter, lb, ub, dim, fobj, opts)
% BBO_ORIG MATLAB port of mealpy.bio_based.BBO.OriginalBBO.

    if nargin < 7 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts, 'p_m') || isempty(opts.p_m)
        opts.p_m = 0.01;
    end
    if ~isfield(opts, 'n_elites') || isempty(opts.n_elites)
        opts.n_elites = 2;
    end

    pop_size = floor(pop_size);
    max_iter = floor(max_iter);
    if pop_size < 5
        error('BBO_ORIG requires pop_size >= 5.');
    end
    if max_iter < 1
        error('BBO_ORIG requires max_iter >= 1.');
    end

    lb = local_expand_bounds(lb, dim);
    ub = local_expand_bounds(ub, dim);
    n_elites = min(max(2, floor(opts.n_elites)), max(2, floor(pop_size / 2)));

    X = local_initialize_population(pop_size, dim, lb, ub);
    fit = local_evaluate_population(X, fobj);
    [best_score, best_idx] = min(fit);
    best_pos = X(best_idx, :);
    curve = zeros(1, max_iter);

    mu = (pop_size + 1 - (1:pop_size)) / (pop_size + 1);
    mr = 1 - mu;
    mu_sum = sum(mu);

    for epoch = 1:max_iter %#ok<NASGU>
        [fit_sorted, order] = sort(fit, 'ascend');
        pop_elites = X(order(1:n_elites), :);
        elite_fit = fit_sorted(1:n_elites);

        for idx = 1:pop_size
            pos_new = X(idx, :);
            for j = 1:dim
                if rand < mr(idx)
                    random_number = rand * mu_sum;
                    select = mu(1);
                    select_index = 1;
                    while random_number > select && select_index < pop_size
                        select_index = select_index + 1;
                        select = select + mu(select_index);
                    end
                    pos_new(j) = X(select_index, j);
                end
            end

            noise = lb + rand(1, dim) .* (ub - lb);
            mask = rand(1, dim) < opts.p_m;
            pos_new(mask) = noise(mask);
            pos_new = local_clip_row(pos_new, lb, ub);
            fit_new = local_eval_solution(pos_new, fobj);

            if fit_new < fit(idx)
                X(idx, :) = pos_new;
                fit(idx) = fit_new;
            end
        end

        X = [X; pop_elites];
        fit = [fit; elite_fit];
        [fit, order] = sort(fit, 'ascend');
        X = X(order(1:pop_size), :);
        fit = fit(1:pop_size);

        if fit(1) < best_score
            best_score = fit(1);
            best_pos = X(1, :);
        end
        curve(epoch) = best_score;
    end
end

function bounds = local_expand_bounds(bounds, dim)
    if isscalar(bounds)
        bounds = repmat(double(bounds), 1, dim);
        return;
    end
    bounds = reshape(double(bounds), 1, []);
    if numel(bounds) ~= dim
        error('Bound vectors must have length equal to dim.');
    end
end

function X = local_initialize_population(pop_size, dim, lb, ub)
    X = repmat(lb, pop_size, 1) + rand(pop_size, dim) .* repmat(ub - lb, pop_size, 1);
end

function X = local_clip_row(X, lb, ub)
    X = min(max(X, lb), ub);
end

function fit = local_evaluate_population(X, fobj)
    fit = zeros(size(X, 1), 1);
    for i = 1:size(X, 1)
        fit(i) = local_eval_solution(X(i, :), fobj);
    end
end

function score = local_eval_solution(x, fobj)
    score = fobj(x);
    if ~isscalar(score)
        score = score(1);
    end
    score = double(score);
end
