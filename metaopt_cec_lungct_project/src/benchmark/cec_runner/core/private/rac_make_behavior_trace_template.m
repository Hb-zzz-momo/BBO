function trace_tpl = rac_make_behavior_trace_template()
    trace_tpl = struct();
    trace_tpl.captured = false;
    trace_tpl.capture_mode = '';
    trace_tpl.note = '';
    trace_tpl.mean_fitness_curve = [];
    trace_tpl.trajectory_first_dim = [];
    trace_tpl.final_population = [];
end
