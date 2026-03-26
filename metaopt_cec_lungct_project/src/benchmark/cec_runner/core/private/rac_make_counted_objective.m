function [counted_fobj, get_fe_state] = rac_make_counted_objective(base_fobj, maxFEs, hard_stop_on_fe_limit, trace_request, pop_size)
    used_FEs = 0;
    best_score = inf;
    best_position = [];
    best_curve = [];
    behavior_trace = rac_make_behavior_trace_template();
    batch_sum = 0;
    batch_count = 0;
    ring_buffer = [];
    ring_count = 0;
    ring_cursor = 0;

    if nargin < 4 || isempty(trace_request)
        trace_request = rac_make_trace_request_template();
    end
    if nargin < 5 || isempty(pop_size)
        pop_size = 1;
    end

    if trace_request.enable
        behavior_trace.captured = true;
        behavior_trace.capture_mode = 'evaluation_batch_proxy';
        behavior_trace.note = 'Behavior curves are lightweight proxies from objective-call batches; benchmark metrics remain unchanged.';
        if trace_request.capture_final_population
            ring_buffer = nan(pop_size, trace_request.position_dims);
        end
    end

    function y = counted_fobj_impl(x)
        if hard_stop_on_fe_limit && used_FEs >= maxFEs
            error('CECRunner:MaxFEsReached', 'Reached maxFEs=%d, objective evaluation is stopped.', maxFEs);
        end

        used_FEs = used_FEs + 1;
        y = base_fobj(x);

        if y < best_score
            best_score = y;
            best_position = x;
        end

        best_curve(end + 1) = best_score; %#ok<AGROW>

        if trace_request.enable
            batch_sum = batch_sum + y;
            batch_count = batch_count + 1;

            if trace_request.capture_final_population
                ring_cursor = ring_cursor + 1;
                if ring_cursor > pop_size
                    ring_cursor = 1;
                end
                ring_count = min(ring_count + 1, pop_size);
                ring_buffer(ring_cursor, :) = x(1:trace_request.position_dims);
            end

            if batch_count >= pop_size
                behavior_trace.mean_fitness_curve(end + 1) = batch_sum / batch_count; %#ok<AGROW>
                if ~isempty(best_position)
                    behavior_trace.trajectory_first_dim(end + 1) = best_position(1); %#ok<AGROW>
                else
                    behavior_trace.trajectory_first_dim(end + 1) = nan; %#ok<AGROW>
                end
                batch_sum = 0;
                batch_count = 0;
            end
        end
    end

    function state = get_state_impl()
        state = struct();
        state.used_FEs = used_FEs;
        state.best_score = best_score;
        state.best_position = best_position;
        state.best_curve = best_curve;
        state.behavior_trace = finalize_behavior_trace_local(behavior_trace, batch_sum, batch_count, best_position, ring_buffer, ring_count, ring_cursor);
    end

    counted_fobj = @counted_fobj_impl;
    get_fe_state = @get_state_impl;
end

function trace = finalize_behavior_trace_local(trace, batch_sum, batch_count, best_position, ring_buffer, ring_count, ring_cursor)
    if ~trace.captured
        return;
    end

    if batch_count > 0
        trace.mean_fitness_curve(end + 1) = batch_sum / batch_count; %#ok<AGROW>
        if ~isempty(best_position)
            trace.trajectory_first_dim(end + 1) = best_position(1); %#ok<AGROW>
        else
            trace.trajectory_first_dim(end + 1) = nan; %#ok<AGROW>
        end
    end

    if ~isempty(ring_buffer) && ring_count > 0
        if ring_count < size(ring_buffer, 1)
            trace.final_population = ring_buffer(1:ring_count, :);
        else
            order = [ring_cursor + 1:size(ring_buffer, 1), 1:ring_cursor];
            trace.final_population = ring_buffer(order, :);
        end
    end
end
