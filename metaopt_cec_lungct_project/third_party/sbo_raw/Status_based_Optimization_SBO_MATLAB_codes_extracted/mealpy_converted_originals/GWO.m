function [best_score, best_pos, curve] = GWO(pop_size, max_iter, lb, ub, dim, fobj, opts) %#ok<INUSD>
% GWO MATLAB port of mealpy.swarm_based.GWO.OriginalGWO.

    if nargin < 7
        opts = struct(); %#ok<NASGU>
    end

    pop_size = floor(pop_size);
    max_iter = floor(max_iter);
    if pop_size < 5
        error('GWO requires pop_size >= 5.');
    end
    if max_iter < 1
        error('GWO requires max_iter >= 1.');
    end

    lb = local_expand_bounds(lb, dim);
    ub = local_expand_bounds(ub, dim);

    X = local_initialize_population(pop_size, dim, lb, ub);
    fit = local_evaluate_population(X, fobj);
    [best_score, best_idx] = min(fit);
    best_pos = X(best_idx, :);
    curve = zeros(1, max_iter);

    for epoch = 1:max_iter
        [~, order] = sort(fit, 'ascend');
        leaders = X(order(1:3), :);
        a = 2 - 2 * epoch / max_iter;

        for idx = 1:pop_size
            A1 = a .* (2 .* rand(1, dim) - 1);
            A2 = a .* (2 .* rand(1, dim) - 1);
            A3 = a .* (2 .* rand(1, dim) - 1);
            C1 = 2 .* rand(1, dim);
            C2 = 2 .* rand(1, dim);
            C3 = 2 .* rand(1, dim);

            X1 = leaders(1, :) - A1 .* abs(C1 .* leaders(1, :) - X(idx, :));
            X2 = leaders(2, :) - A2 .* abs(C2 .* leaders(2, :) - X(idx, :));
            X3 = leaders(3, :) - A3 .* abs(C3 .* leaders(3, :) - X(idx, :));
            pos_new = (X1 + X2 + X3) ./ 3;
            pos_new = min(max(pos_new, lb), ub);
            fit_new = local_eval_solution(pos_new, fobj);

            if fit_new < fit(idx)
                X(idx, :) = pos_new;
                fit(idx) = fit_new;
            end
        end

        [current_best, current_idx] = min(fit);
        if current_best < best_score
            best_score = current_best;
            best_pos = X(current_idx, :);
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
