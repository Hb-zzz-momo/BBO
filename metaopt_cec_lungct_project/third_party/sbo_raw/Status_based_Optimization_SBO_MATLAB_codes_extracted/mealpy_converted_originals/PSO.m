function [best_score, best_pos, curve] = PSO(pop_size, max_iter, lb, ub, dim, fobj, opts)
% PSO MATLAB port of mealpy.swarm_based.PSO.OriginalPSO.

    if nargin < 7 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts, 'c1') || isempty(opts.c1)
        opts.c1 = 2.05;
    end
    if ~isfield(opts, 'c2') || isempty(opts.c2)
        opts.c2 = 2.05;
    end
    if ~isfield(opts, 'w') || isempty(opts.w)
        opts.w = 0.4;
    end

    pop_size = floor(pop_size);
    max_iter = floor(max_iter);
    if pop_size < 5
        error('PSO requires pop_size >= 5.');
    end
    if max_iter < 1
        error('PSO requires max_iter >= 1.');
    end

    lb = local_expand_bounds(lb, dim);
    ub = local_expand_bounds(ub, dim);
    v_max = 0.5 * (ub - lb);
    v_min = -v_max;

    X = local_initialize_population(pop_size, dim, lb, ub);
    V = repmat(v_min, pop_size, 1) + rand(pop_size, dim) .* repmat(v_max - v_min, pop_size, 1);
    fit = local_evaluate_population(X, fobj);

    local_X = X;
    local_fit = fit;
    [best_score, best_idx] = min(fit);
    best_pos = X(best_idx, :);
    curve = zeros(1, max_iter);

    for epoch = 1:max_iter %#ok<NASGU>
        g_best = best_pos;
        for idx = 1:pop_size
            cognitive = opts.c1 * rand(1, dim) .* (local_X(idx, :) - X(idx, :));
            social = opts.c2 * rand(1, dim) .* (g_best - X(idx, :));
            V(idx, :) = opts.w .* V(idx, :) + cognitive + social;

            pos_new = X(idx, :) + V(idx, :);
            pos_new = local_amend_solution(pos_new, lb, ub);
            fit_new = local_eval_solution(pos_new, fobj);

            if fit_new < fit(idx)
                X(idx, :) = pos_new;
                fit(idx) = fit_new;
            end
            if fit_new < local_fit(idx)
                local_X(idx, :) = pos_new;
                local_fit(idx) = fit_new;
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

function x = local_amend_solution(x, lb, ub)
    mask = (x >= lb) & (x <= ub);
    pos_rand = lb + rand(1, numel(x)) .* (ub - lb);
    x(~mask) = pos_rand(~mask);
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
