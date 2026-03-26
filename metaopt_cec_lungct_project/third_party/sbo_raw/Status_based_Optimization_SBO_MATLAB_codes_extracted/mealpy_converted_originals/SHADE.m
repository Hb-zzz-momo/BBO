function [best_score, best_pos, curve] = SHADE(pop_size, max_iter, lb, ub, dim, fobj, opts)
% SHADE MATLAB port of mealpy.evolutionary_based.SHADE.OriginalSHADE.

    if nargin < 7 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts, 'miu_f') || isempty(opts.miu_f)
        opts.miu_f = 0.5;
    end
    if ~isfield(opts, 'miu_cr') || isempty(opts.miu_cr)
        opts.miu_cr = 0.5;
    end

    pop_size = floor(pop_size);
    max_iter = floor(max_iter);
    if pop_size < 5
        error('SHADE requires pop_size >= 5.');
    end
    if max_iter < 1
        error('SHADE requires max_iter >= 1.');
    end

    lb = local_expand_bounds(lb, dim);
    ub = local_expand_bounds(ub, dim);

    X = local_initialize_population(pop_size, dim, lb, ub);
    fit = local_evaluate_population(X, fobj);
    [best_score, best_idx] = min(fit);
    best_pos = X(best_idx, :);
    curve = zeros(1, max_iter);

    dyn_miu_f = opts.miu_f .* ones(1, pop_size);
    dyn_miu_cr = opts.miu_cr .* ones(1, pop_size);
    archive_X = zeros(0, dim);
    k_counter = 1;

    for epoch = 1:max_iter %#ok<NASGU>
        success_f = [];
        success_cr = [];
        success_indices = [];
        list_f_new = ones(1, pop_size);
        list_cr_new = ones(1, pop_size);

        X_old = X;
        fit_old = fit;
        [~, order] = sort(fit_old, 'ascend');
        X_sorted = X_old(order, :);

        trial_X = zeros(pop_size, dim);
        trial_fit = zeros(pop_size, 1);

        for idx = 1:pop_size
            mem_idx = randi(pop_size);
            cr = dyn_miu_cr(mem_idx) + 0.1 * randn;
            cr = min(max(cr, 0), 1);

            while true
                f = dyn_miu_f(mem_idx) + 0.1 * tan(pi * (rand - 0.5));
                if f < 0
                    continue;
                end
                if f > 1
                    f = 1;
                end
                break;
            end

            list_cr_new(idx) = cr;
            list_f_new(idx) = f;

            p = 2 / pop_size + rand * (0.2 - 2 / pop_size);
            top = max(1, floor(pop_size * p));
            x_best = X_sorted(randi(top), :);

            candidates = setdiff(1:pop_size, idx);
            x_r1 = X_old(candidates(randperm(numel(candidates), 1)), :);
            union_pop = [X_old; archive_X];
            x_r2 = local_select_r2(union_pop, x_r1, X_old(idx, :));

            x_new = X_old(idx, :) + f .* (x_best - X_old(idx, :)) + f .* (x_r1 - x_r2);
            pos_new = X_old(idx, :);
            mask = rand(1, dim) < cr;
            pos_new(mask) = x_new(mask);
            j_rand = randi(dim);
            pos_new(j_rand) = x_new(j_rand);
            pos_new = min(max(pos_new, lb), ub);

            trial_X(idx, :) = pos_new;
            trial_fit(idx) = local_eval_solution(pos_new, fobj);
        end

        for idx = 1:pop_size
            if trial_fit(idx) < fit(idx)
                success_cr(end + 1) = list_cr_new(idx); %#ok<AGROW>
                success_f(end + 1) = list_f_new(idx); %#ok<AGROW>
                success_indices(end + 1) = idx; %#ok<AGROW>

                X(idx, :) = trial_X(idx, :);
                fit(idx) = trial_fit(idx);
                archive_X = [archive_X; trial_X(idx, :)]; %#ok<AGROW>
            end
        end

        extra = size(archive_X, 1) - pop_size;
        if extra > 0
            remove_idx = randperm(size(archive_X, 1), extra);
            keep_mask = true(size(archive_X, 1), 1);
            keep_mask(remove_idx) = false;
            archive_X = archive_X(keep_mask, :);
        end

        if ~isempty(success_f) && ~isempty(success_cr)
            fit_old_success = fit_old(success_indices(:));
            fit_new_success = fit(success_indices(:));
            deltas = abs(fit_new_success - fit_old_success);
            delta_sum = sum(deltas);
            if delta_sum == 0
                weights = ones(numel(deltas), 1) ./ numel(deltas);
            else
                weights = deltas ./ delta_sum;
            end

            dyn_miu_cr(k_counter) = sum(weights .* success_cr(:));
            dyn_miu_f(k_counter) = local_weighted_lehmer_mean(success_f(:), weights);
            k_counter = k_counter + 1;
            if k_counter > pop_size
                k_counter = 1;
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

function x_r2 = local_select_r2(union_pop, x_r1, current_x)
    if isempty(union_pop)
        x_r2 = current_x;
        return;
    end

    max_trials = 100;
    for trial = 1:max_trials %#ok<NASGU>
        candidate = union_pop(randi(size(union_pop, 1)), :);
        if any(candidate ~= x_r1) && any(candidate ~= current_x)
            x_r2 = candidate;
            return;
        end
    end

    diff_mask = any(union_pop ~= x_r1, 2) & any(union_pop ~= current_x, 2);
    idx = find(diff_mask, 1, 'first');
    if isempty(idx)
        x_r2 = union_pop(randi(size(union_pop, 1)), :);
    else
        x_r2 = union_pop(idx, :);
    end
end

function value = local_weighted_lehmer_mean(objects, weights)
    numerator = sum(weights .* (objects .^ 2));
    denominator = sum(weights .* objects);
    if denominator == 0
        value = 0;
    else
        value = numerator / denominator;
    end
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
