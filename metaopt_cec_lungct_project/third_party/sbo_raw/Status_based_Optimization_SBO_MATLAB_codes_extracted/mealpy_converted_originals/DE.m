function [best_score, best_pos, curve] = DE(pop_size, max_iter, lb, ub, dim, fobj, opts)
% DE MATLAB port of mealpy.evolutionary_based.DE.OriginalDE.

    if nargin < 7 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts, 'wf') || isempty(opts.wf)
        opts.wf = 0.1;
    end
    if ~isfield(opts, 'cr') || isempty(opts.cr)
        opts.cr = 0.9;
    end
    if ~isfield(opts, 'strategy') || isempty(opts.strategy)
        opts.strategy = 0;
    end

    pop_size = floor(pop_size);
    max_iter = floor(max_iter);
    strategy = floor(opts.strategy);
    if pop_size < 5
        error('DE requires pop_size >= 5.');
    end
    if max_iter < 1
        error('DE requires max_iter >= 1.');
    end

    lb = local_expand_bounds(lb, dim);
    ub = local_expand_bounds(ub, dim);
    local_validate_strategy(pop_size, strategy);

    X = local_initialize_population(pop_size, dim, lb, ub);
    fit = local_evaluate_population(X, fobj);
    [best_score, best_idx] = min(fit);
    best_pos = X(best_idx, :);
    curve = zeros(1, max_iter);

    for epoch = 1:max_iter %#ok<NASGU>
        g_best = best_pos;
        for idx = 1:pop_size
            available = setdiff(1:pop_size, idx);
            switch strategy
                case 0
                    idx_list = available(randperm(numel(available), 3));
                    new_pos = X(idx_list(1), :) + opts.wf .* (X(idx_list(2), :) - X(idx_list(3), :));
                case 1
                    idx_list = available(randperm(numel(available), 2));
                    new_pos = g_best + opts.wf .* (X(idx_list(1), :) - X(idx_list(2), :));
                case 2
                    idx_list = available(randperm(numel(available), 4));
                    new_pos = g_best + opts.wf .* (X(idx_list(1), :) - X(idx_list(2), :)) + ...
                        opts.wf .* (X(idx_list(3), :) - X(idx_list(4), :));
                case 3
                    idx_list = available(randperm(numel(available), 5));
                    new_pos = X(idx_list(1), :) + opts.wf .* (X(idx_list(2), :) - X(idx_list(3), :)) + ...
                        opts.wf .* (X(idx_list(4), :) - X(idx_list(5), :));
                case 4
                    idx_list = available(randperm(numel(available), 2));
                    new_pos = X(idx, :) + opts.wf .* (g_best - X(idx, :)) + ...
                        opts.wf .* (X(idx_list(1), :) - X(idx_list(2), :));
                otherwise
                    idx_list = available(randperm(numel(available), 3));
                    new_pos = X(idx, :) + opts.wf .* (X(idx_list(1), :) - X(idx, :)) + ...
                        opts.wf .* (X(idx_list(2), :) - X(idx_list(3), :));
            end

            pos_new = local_binomial_crossover(X(idx, :), new_pos, opts.cr, lb, ub);
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

function local_validate_strategy(pop_size, strategy)
    needed = [3, 2, 4, 5, 2, 3];
    if strategy < 0 || strategy > 5
        error('DE strategy must be an integer in [0, 5].');
    end
    if pop_size - 1 < needed(strategy + 1)
        error('DE strategy %d requires a larger population.', strategy);
    end
end

function X = local_initialize_population(pop_size, dim, lb, ub)
    X = repmat(lb, pop_size, 1) + rand(pop_size, dim) .* repmat(ub - lb, pop_size, 1);
end

function pos_new = local_binomial_crossover(current_pos, new_pos, cr, lb, ub)
    mask = rand(1, numel(current_pos)) < cr;
    pos_new = current_pos;
    pos_new(mask) = new_pos(mask);
    pos_new = min(max(pos_new, lb), ub);
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
