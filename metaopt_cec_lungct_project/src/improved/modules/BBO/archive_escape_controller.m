function [archive, accepted_count] = archive_escape_controller(action, archive, payload, cfg)
% archive_escape_controller
% Maintains a tiny elite archive and proposes stagnation-triggered long jumps.

    accepted_count = 0;

    switch lower(string(action))
        case "init"
            archive = struct();
            archive.positions = zeros(0, payload.dim);
            archive.fitness = zeros(0, 1);
            archive.max_size = cfg.max_archive_size;

        case "record"
            if isempty(archive)
                [archive, ~] = archive_escape_controller("init", archive, struct('dim', size(payload.positions, 2)), cfg);
            end
            P = payload.positions;
            F = payload.fitness(:);
            if isempty(P) || isempty(F)
                return;
            end
            archive.positions = [archive.positions; P]; %#ok<AGROW>
            archive.fitness = [archive.fitness; F]; %#ok<AGROW>
            [archive.fitness, idx] = sort(archive.fitness, 'ascend');
            archive.positions = archive.positions(idx, :);
            if numel(archive.fitness) > archive.max_size
                archive.fitness = archive.fitness(1:archive.max_size);
                archive.positions = archive.positions(1:archive.max_size, :);
            end

        case "escape"
            X = payload.X;
            fitness = payload.fitness;
            best_pos = payload.best_pos;
            lb = payload.lb;
            ub = payload.ub;
            rng_span = ub - lb;
            N = size(X, 1);

            if size(archive.positions, 1) < 2
                archive = struct('X', X, 'fitness', fitness, 'accepted_count', 0);
                return;
            end

            [~, order] = sort(fitness, 'descend');
            n_targets = max(1, min(cfg.max_escape_targets, round(cfg.escape_fraction * N)));
            targets = order(1:n_targets);

            for t = 1:numel(targets)
                if rand > cfg.escape_apply_prob
                    continue;
                end
                i = targets(t);
                idx = randperm(size(archive.positions, 1), 2);
                a1 = archive.positions(idx(1), :);
                a2 = archive.positions(idx(2), :);

                jump = X(i, :) ...
                    + cfg.escape_w_best * (best_pos - X(i, :)) ...
                    + cfg.escape_w_diff * (a1 - a2) ...
                    + cfg.escape_noise_scale * randn(1, numel(lb)) .* rng_span;

                jump = min(ub, max(lb, jump));
                f_jump = payload.fobj(jump);
                if f_jump < fitness(i)
                    X(i, :) = jump;
                    fitness(i) = f_jump;
                    accepted_count = accepted_count + 1;
                end
            end

            archive = struct('X', X, 'fitness', fitness, 'accepted_count', accepted_count);

        otherwise
            error('Unsupported archive_escape_controller action: %s', action);
    end
end
