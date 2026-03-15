#!/usr/bin/env python
# Created by "Jona" at 14:26, 08/06/2025 ----------%
#       Email: jona.wzu@gmail.com            %
#       Github: https://github.com/JonaWon       %
# --------------------------------------------------%

import numpy as np
import os
import time
import inspect
import importlib
from joblib import Parallel, delayed, parallel_backend
from mealpy import FloatVar, PLO, RIME, SBO
from utils import *

# --- Configuration ---
benchmark_name = 'CEC2017'  # --- Change this to 'CEC2005', 'CEC2019', 'CEC2022', etc. ---

# Experiment parameters
SEARCH_AGENTS_NO = 30
DIM = 10 # --- Change dimension here for testing ---
MAX_EPOCHS = 1000  # Max function evaluations
RUNS = 4
NUM_OF_RECORD = 40

# Algorithm setup
algorithm_classes = [PLO.OriginalPLO, RIME.OriginalRIME, SBO.OriginalSBO] # --- Add optimizer here for testing ---
algo_num = len(algorithm_classes)
algorithm_names = []
for algo_class in algorithm_classes:
    # Get the class name (e.g., 'OriginalSMA')
    class_name = algo_class.__name__

    # Find the algorithm name in class
    if class_name.startswith('Original'):
        # Extract the algorithm part after 'Original'
        algo_name = class_name[8:]
    else:
        # Just use the class name as is
        algo_name = class_name

    algorithm_names.append(algo_name)
print(f"Algorithm names: {algorithm_names}")

# Dynamically import the appropriate CEC module
try:
    cec_module = importlib.import_module(f"opfunu.cec_based.{benchmark_name.lower()}")
except ImportError:
    raise ImportError(f"Could not import {benchmark_name}. Make sure opfunu is installed with the required benchmark.")

# Dynamically discover available functions
available_functions = []
for name, obj in inspect.getmembers(cec_module):
    # Check if it's a class and ends with the benchmark year (e.g., 'F12017')
    year_suffix = benchmark_name[3:]  # Extract '2017' from 'CEC2017'
    if inspect.isclass(obj) and name.endswith(year_suffix):
        # Extract function ID (e.g., 'F1' from 'F12017')
        func_id = name[:-len(year_suffix)]
        available_functions.append(func_id)

# Sort functions by their numeric value
available_functions.sort(key=lambda x: int(x[1:]) if x[1:].isdigit() else float('inf'))
print(f"Available {benchmark_name} functions:\n {available_functions}")

# Update configuration
function_cec_ids = available_functions
func_num = len(function_cec_ids)

# Results storage
best_fitness_all = np.full((algo_num, RUNS, func_num), np.nan)

# --- Setup results directory ---
dir_name = setup_results_dir(algorithm_names[0])
print(f"Results will be saved in: {dir_name}")


# --- Modified experiment function using Opfunu ---
def run_single_experiment(run_index, func_index, cec_func_id, dimension):
    """Execute a single algorithm run using Opfunu's CEC functions."""
    try:
        # Initialize CEC function dynamically based on benchmark_name
        year_suffix = benchmark_name[3:]  # Extract '2017' from 'CEC2017'
        func_class_name = f"{cec_func_id}{year_suffix}"
        func_class = getattr(cec_module, func_class_name)
        func_obj = func_class(dimension)
    except AttributeError:
        print(f"Function {cec_func_id} not found in {benchmark_name} set.")
        num_algorithms = len(algorithm_classes)
        return (run_index, func_index,
                np.full(num_algorithms, np.nan),
                np.full((num_algorithms, NUM_OF_RECORD), np.nan))

    # Get function properties from Opfunu
    lb, ub = func_obj.lb, func_obj.ub
    fhd = func_obj.evaluate  # Objective function

    print(f"Running: {cec_func_id}, Dim={dimension}, Run={run_index + 1}/{RUNS}")

    # Define Mealpy problem
    problem = {
        "obj_func": fhd,  # Directly use Opfunu's evaluate method
        "bounds": FloatVar(lb=lb, ub=ub),
        "minmax": "min",
        "name": cec_func_id,
    }

    # Run all algorithms
    num_algorithms = len(algorithm_classes)
    results = np.full(num_algorithms, np.nan)
    curves = np.full((num_algorithms, NUM_OF_RECORD), np.nan)

    for algo_idx, algo_class in enumerate(algorithm_classes):
        try:
            # Initialize and run the algorithm
            model = algo_class(epoch=MAX_EPOCHS, pop_size=SEARCH_AGENTS_NO)

            start_time = time.time()
            best_solution = model.solve(problem)
            end_time = time.time()

            # Extract convergence curve
            cg_curve = model.history.list_global_best_fit
            sampled_curve = my_sampling(cg_curve, NUM_OF_RECORD)
            results[algo_idx] = best_solution.target.fitness

            curves[algo_idx] = sampled_curve
            print(f"Algo {algorithm_names[algo_idx]}: Best Fitness = {results[algo_idx]:.6e}, Time = {end_time - start_time:.2f}s")


        except Exception as e:
            print(f"Error in {algorithm_names[algo_idx]}: {str(e)}")

    return run_index, func_index, results, curves


# --- Main execution ---
if __name__ == "__main__":
    start_total_time = time.time()

    for func_index, cec_func_id in enumerate(function_cec_ids):
        print(f"\n----- Benchmarking {cec_func_id} -----")

        # Parallel execution
        with parallel_backend('loky'):
            results = Parallel(n_jobs=-1)(
                delayed(run_single_experiment)(run_idx, func_index, cec_func_id, DIM)
                for run_idx in range(RUNS)
            )

        # Process results
        cg_curves = np.full((algo_num, RUNS, NUM_OF_RECORD), np.nan)
        for r_idx, f_idx, fitness, sampled in results:
            if f_idx == func_index:
                best_fitness_all[:, r_idx, f_idx] = fitness
                cg_curves[:, r_idx, :] = sampled

        # Plotting
        plot_convergence_curves(
            mean_curves=np.nanmean(cg_curves, axis=1),
            algorithm_names=algorithm_names,
            max_fes=MAX_EPOCHS,
            title=f'Convergence: {cec_func_id} ({benchmark_name})',
            save_path=os.path.join(dir_name, f'{cec_func_id}_convergence.png')
        )

    # Final output
    total_time = time.time() - start_total_time
    print(f"\n----- Benchmark Complete -----")
    print(f"Total time: {total_time / 60:.1f} minutes")
    print(f"Results saved to: {dir_name}")

    # Save raw data
    save_all_results(
        bestFitnessAll=best_fitness_all,
        algorithm_names=algorithm_names,
        function_ids=function_cec_ids,
        dir_name=dir_name
    )

    # Plot boxplots
    basename = os.path.basename(os.path.normpath(dir_name))
    excel_path = os.path.join(dir_name, f'result-{basename}.xlsx')
    plot_boxplots(
        excel_path=excel_path,
        algorithm_names=algorithm_names,
        dir_name=dir_name
    )