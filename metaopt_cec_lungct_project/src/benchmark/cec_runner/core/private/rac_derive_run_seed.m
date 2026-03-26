function seed = rac_derive_run_seed(base_seed, suite_idx, func_idx, ~, run_id, ~)
% Deterministic paired-seed construction.
% For the same suite/function/run_id, all algorithms share exactly the
% same seed so comparisons are run-paired.

    % Signature keeps legacy positions for call-site compatibility.
    seed = base_seed + (suite_idx - 1) * 10000000 + (func_idx - 1) * 100000 + run_id;
end
