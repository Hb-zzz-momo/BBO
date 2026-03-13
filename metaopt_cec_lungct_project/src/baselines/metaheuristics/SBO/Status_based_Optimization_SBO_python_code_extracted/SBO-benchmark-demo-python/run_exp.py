"""
CEC17 Benchmark Testing with Status-Based Optimization (SBO)
"""

import numpy as np
import cec2017.functions as functions
import time

from sbo import SBO

# Parameters:
POP_SIZE = 30
MAX_FES = POP_SIZE * 10000
DIM = 30
LB = -100
UB = 100

# List of CEC17 function names (for printing, mapping to functions.all_functions)
# The order in functions.all_functions corresponds to F1-F30
cec17_function_names = [
    'Shifted and Rotated Bent Cigar Function', # F1
    'Shifted and Rotated Sum of Different Power Function', # F2
    'Shifted and Rotated Zakharov Function', # F3
    'Shifted and Rotated Rosenbrock''s Function', # F4
    'Shifted and Rotated Rastrigin''s Function', # F5
    'Shifted and Rotated Expanded Scaffer''s F6 Function', # F6
    'Shifted and Rotated Lunacek Bi-Rastrigin Function', # F7
    'Shifted and Rotated Non-Continuous Rastrigin''s Function', # F8
    'Shifted and Rotated Levy Function', # F9
    'Shifted and Rotated Schwefel''s Function', # F10
    'Hybrid Function 1 (N=3)', # F11
    'Hybrid Function 2 (N=3)', # F12
    'Hybrid Function 3 (N=3)', # F13
    'Hybrid Function 4 (N=4)', # F14
    'Hybrid Function 5 (N=4)', # F15
    'Hybrid Function 6 (N=4)', # F16
    'Hybrid Function 7 (N=5)', # F17
    'Hybrid Function 8 (N=5)', # F18
    'Hybrid Function 9 (N=5)', # F19
    'Hybrid Function 10 (N=6)', # F20
    'Composition Function 1 (N=3)', # F21
    'Composition Function 2 (N=3)', # F22
    'Composition Function 3 (N=3)', # F23
    'Composition Function 4 (N=4)', # F24
    'Composition Function 5 (N=4)', # F25
    'Composition Function 6 (N=4)', # F26
    'Composition Function 7 (N=5)', # F27
    'Composition Function 8 (N=5)', # F28
    'Composition Function 9 (N=5)', # F29
    'Composition Function 10 (N=6)'  # F30
]

def run_experiment():
    """
    Run the experiment with all CEC2017 functions using the SBO algorithm.
    """

    print('\n=== CEC17 Benchmark Suite Evaluation ===')
    print('Algorithm: Status-Based Optimization (SBO)')
    print(f'Configuration: PopSize={POP_SIZE}, Dim={DIM}, MaxFEs={MAX_FES}\n')

    # Initialize results storage
    # Using a list of dictionaries to store results for each function
    results = []

    start_time = time.time()

    # Iterate through CEC17 functions (F1 to F30)
    for func_num_idx in range(30): 
        func_num = func_num_idx + 1 # 1-based function number for printing
        fobj_cec = functions.all_functions[func_num_idx]
        func_name = cec17_function_names[func_num_idx]

        # Function-specific header
        print('┌──────────────────────────────────────────────────────────────────────┐')
        print(f'│  FUNCTION #{func_num:02d} - {func_name:<38s} ')
        print('└──────────────────────────────────────────────────────────────────────┘')

        # Initialize function wrapper for SBO
        # SBO expects fobj to take a (1, dim) array and return a scalar
        fobj = lambda x: fobj_cec(x)[0]

        func_start = time.time()

        # Run optimization
        # The SBO function from sbo.py returns best_pos and Convergence_curve
        best_pos, convergence_curve = SBO(POP_SIZE, MAX_FES, LB, UB, DIM, fobj)

        # Store results
        runtime = time.time() - func_start
        results.append({
            'fnum': func_num,
            'best_pos': best_pos,
            'best_val': convergence_curve[-1] if convergence_curve else float('inf'), # Get the last value
            'runtime': runtime
        })

        # Display function results
        print(f'├─ Best Fitness: {results[-1]["best_val"]:.3e}')
        best_pos_str = ', '.join([f'{x:.3f}' for x in best_pos])
        print(f'├─ Best Solution: [{best_pos_str}]')
        if convergence_curve:
             print(f'├─ Convergence: {convergence_curve[0]:.2e} → {convergence_curve[-1]:.2e}')
        else:
             print('├─ Convergence: N/A')
        print(f'└─ Runtime: {runtime:.2f} seconds\n')

        # Progress update every 5 functions
        if func_num % 5 == 0:
            elapsed_time = time.time() - start_time
            avg_runtime = elapsed_time / func_num if func_num > 0 else 0
            print(f'✓ Completed {func_num}/30 functions ({100*func_num/30:.1f}%%)')
            print(f'  Current average runtime: {avg_runtime:.2f} sec/function\n')

    # Final Report
    total_computation_time = time.time() - start_time
    all_runtimes = [r['runtime'] for r in results]
    average_runtime_per_function = np.mean(all_runtimes) if all_runtimes else 0

    print('\n════════════════ TEST SUMMARY ════════════════')
    print(f'Total computation time: {total_computation_time/60:.2f} minutes')
    print(f'Average runtime per function: {average_runtime_per_function:.2f} seconds')


if __name__ == "__main__":
    run_experiment()