function trace_request = rac_make_trace_request_template()
    trace_request = struct();
    trace_request.enable = false;
    trace_request.capture_mean_fitness = false;
    trace_request.capture_first_dim = false;
    trace_request.capture_final_population = false;
    trace_request.position_dims = 0;
end
