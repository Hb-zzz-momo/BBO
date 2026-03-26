function trial = apply_simple_modules(trial, old_position, best_solution, progress, lb, ub, cfg)
% apply_simple_modules
% Apply reusable simple-function acceleration modules for v3 ablation.

    if cfg.use_fast_A
        shrink = 1 - 0.50 * progress;
        trial = old_position + shrink .* (trial - old_position);

        if progress > 0.65 && rand < 0.35
            trial = trial + (0.08 + 0.18 * progress) .* (best_solution - trial);
        end

        if progress > 0.80
            fine_scale = 0.008 * (1 - progress + 0.1);
            trial = trial + fine_scale .* (ub - lb) .* randn(size(trial));
        end
    end

    if cfg.use_fast_B
        contraction = 0.06 + 0.24 * progress;
        trial = trial + contraction .* (best_solution - trial);

        if progress > 0.70
            trial = 0.75 * trial + 0.25 * best_solution;
        end

        if progress > 0.85
            fine_scale = 0.005 * (1 - progress + 0.05);
            trial = best_solution + fine_scale .* (ub - lb) .* randn(size(trial));
        end
    end
end
