function [best_score, best_pos, curve, fe_control_mode, fe_note] = rac_run_one_algorithm(alg, pop_size, maxFEs, lb, ub, dim, fobj)
    entry_name = char(string(alg.entry_name));
    if exist(entry_name, 'file') ~= 2
        error('CECRunner:AlgorithmEntryNotFound', 'Algorithm entry not found on active path: %s', entry_name);
    end
    entry_fn = str2func(entry_name);

    if strcmp(alg.budget_arg, 'maxFEs')
        budget_value = maxFEs;
        used_est = maxFEs;
    else
        [budget_value, used_est] = estimate_iteration_budget_local(pop_size, maxFEs);
    end

    if strcmp(alg.output_mode, 'score_pos_curve')
        [best_score, best_pos, curve] = entry_fn(pop_size, budget_value, lb, ub, dim, fobj);
    elseif strcmp(alg.output_mode, 'pos_score_curve')
        [best_pos, best_score, curve] = entry_fn(pop_size, budget_value, lb, ub, dim, fobj);
    elseif strcmp(alg.output_mode, 'score_curve')
        [best_score, curve] = entry_fn(pop_size, budget_value, lb, ub, dim, fobj);
        best_pos = [];
    elseif strcmp(alg.output_mode, 'pos_curve')
        [best_pos, curve] = entry_fn(pop_size, budget_value, lb, ub, dim, fobj);
        if isempty(curve)
            best_score = inf;
        else
            best_score = curve(end);
        end
    elseif strcmp(alg.output_mode, 'po')
        [~, best_pos, best_score, curve, ~, ~] = entry_fn(pop_size, budget_value, lb, ub, dim, fobj);
    else
        error('Unsupported output mode %s for algorithm %s.', alg.output_mode, alg.name);
    end

    if strcmp(alg.budget_arg, 'maxFEs')
        fe_control_mode = 'exact_fes_parameter';
        fe_note = sprintf('%s uses MaxFEs directly.', alg.entry_name);
    else
        if used_est == maxFEs
            fe_control_mode = 'exact_derived_iteration_from_maxFEs';
            fe_note = sprintf('%s Max_iteration=%d maps to exact used_FEs=%d.', alg.entry_name, budget_value, used_est);
        else
            fe_control_mode = 'approx_derived_iteration_from_maxFEs';
            fe_note = sprintf('%s Max_iteration=%d maps to used_FEs=%d (< maxFEs=%d).', alg.entry_name, budget_value, used_est, maxFEs);
        end
    end
end

function [max_iter, used_fes_est] = estimate_iteration_budget_local(pop_size, maxFEs)
    if maxFEs < pop_size
        max_iter = 0;
        used_fes_est = pop_size;
        return;
    end

    max_iter = floor((maxFEs - pop_size) / pop_size);
    if max_iter < 1
        max_iter = 1;
    end

    used_fes_est = pop_size + max_iter * pop_size;
end
