## Budget policy (critical)
The unified benchmark budget must be based on:

- `maxFEs` = maximum number of objective function evaluations

Do not use `max_iterations` as the primary fairness budget.

Reason:
Different metaheuristic algorithms may consume different numbers of objective evaluations per iteration.
Therefore, using only iteration count can create an unfair comparison.

## Required budget rule
All included algorithms must be compared under the same:
- suite
- function IDs
- dimension
- population size where applicable
- `maxFEs`
- number of runs
- random seed policy

`max_iterations` may still exist only as:
- a derived helper control for legacy algorithms
- an approximate outer-loop cap
- a compatibility parameter

But the real fairness budget must be `maxFEs`.

## Implementation requirement for FE control
You must implement or reuse a counted objective wrapper so that the benchmark framework can track the exact number of function evaluations.

Preferred approach:
- wrap the objective function
- increment FE counter on every evaluation
- stop the algorithm when `maxFEs` is reached
- truncate or safely finalize the run if the algorithm attempts to exceed the FE budget

If an algorithm can only be controlled by iteration count and cannot safely support exact FE counting without intrusive rewriting:
1. keep changes minimal
2. apply the safest compatibility treatment
3. clearly log that it is an approximate FE-controlled execution
4. do not hide this limitation

## Output config requirements
The experiment config must include:
- `maxFEs`
- FE counting mode
- whether each algorithm is exact-FE-controlled or approximate-FE-controlled

## Per-run saved fields
Each run result should save:
- `algorithm_name`
- `function_id`
- `run_id`
- `best_score`
- `best_position`
- `convergence_curve`
- `runtime`
- `seed`
- `suite`
- `dimension`
- `population_size`
- `maxFEs`
- `used_FEs`
- `fe_control_mode`

## Per-function summary fields
For each algorithm on each function, save:
- `algorithm_name`
- `function_id`
- `best`
- `mean`
- `std`
- `worst`
- `median`
- `avg_runtime`
- `avg_used_FEs`

## Fairness policy (revised)
All included algorithms must use identical `maxFEs` as the primary budget.

Do not silently compare:
- one algorithm under iteration budget
- another under FE budget

If exact FE fairness is not possible for a specific algorithm, record it explicitly in:
- `algorithm_inventory.csv`
- logs
- run manifest

## Self-check (revised)
Before finalizing, explicitly verify:
- all actually runnable existing algorithms are compared under unified `maxFEs`
- FE counting is implemented
- `used_FEs` is saved
- exact vs approximate FE control is logged
- no algorithm is silently given extra objective evaluations