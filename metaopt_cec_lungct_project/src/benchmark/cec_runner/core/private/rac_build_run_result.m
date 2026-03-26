function run_result = rac_build_run_result(algorithm_name, suite_name, function_id, run_id, ...
    best_score, best_position, convergence_curve, runtime, seed, dimension, population_size, maxFEs, used_FEs, fe_control_mode, fe_note, behavior_trace)

    run_result = struct();
    run_result.algorithm_name = algorithm_name;
    run_result.suite = suite_name;
    run_result.function_id = function_id;
    run_result.run_id = run_id;
    run_result.best_score = best_score;
    run_result.best_position = best_position;
    run_result.convergence_curve = convergence_curve;
    run_result.runtime = runtime;
    run_result.seed = seed;
    run_result.dimension = dimension;
    run_result.population_size = population_size;
    run_result.maxFEs = maxFEs;
    run_result.used_FEs = used_FEs;
    run_result.fe_control_mode = fe_control_mode;
    run_result.fe_control_note = fe_note;
    run_result.behavior_trace = behavior_trace;
end
