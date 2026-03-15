You are acting as a MATLAB research benchmark maintenance assistant.

This repository is for metaheuristic optimization research, not product engineering.

## Mainline reminder
The repository mainline is:
- BBO as the primary algorithm research object
- SBO as a comparison baseline
- CEC2017 and CEC2022 as the main benchmark validation suites
- lung CT as a later application case only

For this task, do not work on lung CT code.
Do not work on UI, platforms, or unrelated engineering.
Focus only on benchmark experiment support.

## Task
Create a new MATLAB comparison script that runs SBO and BBO on CEC2017 and CEC2022 using the existing repository code and saves all results into the results folder.

The implementation must be minimal-intrusion:
- do not rewrite the repository
- do not rename major folders
- do not replace the tech stack
- do not rewrite existing optimizer bodies unless there is no safe wrapper-based alternative

## Existing repository expectations
The repository already contains source folders similar to:
- src/baselines/metaheuristics/BBO/...
- src/baselines/metaheuristics/SBO/...

and existing baseline calling logic for:
- CEC2017
- CEC2022

Use these existing baselines.
Do not invent nonexistent files or dependencies.

## Required outcome
Add a unified experiment entry, for example:
- run_compare_sbo_bbo.m

and lightweight helper functions if needed.

This entry should:
1. select benchmark suite: cec2017 or cec2022
2. select function IDs
3. set dimension
4. set population size
5. set max iterations
6. set number of runs
7. set RNG seed
8. run SBO and BBO under identical settings
9. save raw run outputs
10. save convergence curves
11. save summary statistics

## Hard constraints
Do not modify:
- cec17_func.mexw64
- cec22_func.mexw64
- input_data structure

Do not silently change benchmark fairness settings.

If SBO and BBO use different interfaces, add wrappers such as:
- run_sbo_once(...)
- run_bbo_once(...)

Do not merge baseline code into one rewritten optimizer file.

## Saved output structure
Save results to:

results/<suite>/<experiment_name_or_timestamp>/

At minimum create:
- config.mat
- summary.csv
- summary.mat
- raw_runs/
- curves/
- logs/

## Per-run saved fields
Each run result should save:
- algorithm_name
- function_id
- run_id
- best_score
- best_position
- convergence_curve
- runtime

## Per-function summary fields
For each algorithm on each function, save:
- algorithm_name
- function_id
- best
- mean
- std
- worst
- median
- avg_runtime

## Recommended implementation direction
Prefer adding:
- one main comparison script
- one benchmark suite resolver
- one result directory initializer
- one result saving function
- one summary statistics function
- two lightweight algorithm wrappers if needed

Prefer not to edit the internal logic of SBO.m or BBO.m unless a small compatibility fix is required.

## Path requirements
- use relative paths only
- code should be runnable from repository root
- save locations must be explicit and stable

## Output requirements
Reply in the following order:
1. current repository problem analysis
2. minimal-intrusion implementation design
3. exact files to add or modify
4. full MATLAB code
5. example run commands
6. expected result files
7. self-check and risks

## Self-check
Before finalizing, explicitly verify:
- CEC2017 can still run
- CEC2022 can still run
- SBO and BBO use identical benchmark settings
- results are saved under results/
- multiple runs are supported
- summary.csv is produced
- raw_runs are saved
- convergence curve files are saved
- original baseline code identity remains clear
- the structure is still suitable for later improved SBO variants and ablation experiments

If any repository detail is uncertain, state the missing detail clearly and make the smallest safe assumption instead of inventing facts.