function output = run_suite_batch(run_cfg)
% run_suite_batch
% Thin execution wrapper around the unique benchmark kernel.

    output = rac_run_benchmark_kernel(run_cfg);
end
