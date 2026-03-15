#!/usr/bin/env python
# Created by "Jona" at 14:26, 08/06/2025 ----------%
#       Email: jona.wzu@gmail.com            %
#       Github: https://github.com/JonaWon       %
# --------------------------------------------------%

"""
Project Utilities (utils.py)
============================
Contains helper functions for:
- Convergence curve sampling (my_sampling)
- Visualization (plot_curve, plot_multiple_runs)
- Statistics (calculate_stats, moving_average)
"""

from datetime import datetime
import os
import numpy as np
import pandas as pd
from matplotlib.patches import Rectangle
from scipy.stats import wilcoxon, ttest_rel
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from typing import List, Union, Tuple, Optional, Dict

# ========================
# SETUP RESULT DIR
# ========================

def setup_results_dir(algorithm_name: str) -> str:
    """Creates a timestamped results directory for experiments."""
    exp_time = datetime.now()
    day_str = exp_time.strftime('%Y-%m-%d')
    time_str = exp_time.strftime('%H_%M_%S')
    dir_name = os.path.join('exp_result', day_str, f'{algorithm_name}-{time_str}')
    os.makedirs(dir_name, exist_ok=True)
    return dir_name

# ========================
# SAMPLING FUNCTIONS
# ========================

def my_sampling(curve: Union[List[float], np.ndarray], num_points: int) -> np.ndarray:
    """
    Resamples a convergence curve to have a fixed number of points using linear interpolation.

    Parameters:
        curve: Original convergence curve values
        num_points: Desired number of points in output

    Returns:
        Uniformly sampled curve with `num_points` elements
    """
    original_len = len(curve)
    if original_len == 0:
        return np.full(num_points, np.nan)
    if original_len == 1:
        return np.full(num_points, curve[0])

    curve_np = np.asarray(curve)
    original_indices = np.linspace(0, 1, original_len)
    target_indices = np.linspace(0, 1, num_points)

    try:
        return np.interp(target_indices, original_indices, curve_np)
    except Exception as e:
        print(f"Sampling error: {e}. Using fallback.")
        return np.full(num_points, curve_np[-1] if original_len > 0 else np.nan)

# ========================
# VISUALIZATION FUNCTIONS
# ========================

# def plot_convergence_curves(mean_curves: np.ndarray,
#                           algorithm_names: List[str],
#                           max_fes: int,
#                           title: str,
#                           save_path: str) -> None:
#     """
#     Plots and saves mean convergence curves for multiple algorithms.
#
#     Args:
#         mean_curves: Array of mean curves (n_algorithms × n_points)
#         algorithm_names: List of algorithm names
#         max_fes: Maximum function evaluations
#         title: Plot title
#         save_path: Full path to save the figure
#     """
#     plt.figure(figsize=(10, 6))
#     x_values = np.linspace(max_fes/mean_curves.shape[1], max_fes, mean_curves.shape[1])
#
#     for algo_idx, (curve, name) in enumerate(zip(mean_curves, algorithm_names)):
#         plt.semilogy(x_values, curve,
#                     label=name,
#                     linewidth=1.5,
#                     linestyle=['-', '--', ':', '-.'][algo_idx % 4],
#                     color=plt.cm.viridis(algo_idx/len(algorithm_names)))
#
#     plt.xlabel('Function Evaluations')
#     plt.ylabel('Fitness (log scale)')
#     plt.title(title)
#     plt.legend(frameon=False)
#     plt.grid(True, alpha=0.3)
#     plt.tight_layout()
#
#     try:
#         plt.savefig(save_path, dpi=300, bbox_inches='tight')
#         plt.close()
#     except Exception as e:
#         print(f"Failed to save plot: {str(e)}")
#         raise

def plot_convergence_curves(mean_curves: np.ndarray,
                            algorithm_names: List[str],
                            max_fes: int,
                            title: str,
                            save_path: str) -> None:
    """
    Plots and saves mean convergence curves for multiple algorithms.

    Args:
        mean_curves: Array of mean curves (n_algorithms × n_points)
        algorithm_names: List of algorithm names
        max_fes: Maximum function evaluations
        title: Plot title
        save_path: Full path to save the figure
    """
    plt.figure(figsize=(10, 6))
    x_values = np.linspace(max_fes / mean_curves.shape[1], max_fes, mean_curves.shape[1])

    for algo_idx, (curve, name) in enumerate(zip(mean_curves, algorithm_names)):
        # Handle negative fitness values by shifting them
        if np.any(curve < 0):
            curve = curve - np.min(curve) + 1  # Shift to make all values positive

        plt.semilogy(x_values, curve,
                     label=name,
                     linewidth=1.5,
                     linestyle=['-', '--', ':', '-.'][algo_idx % 4],
                     color=plt.cm.plasma(algo_idx / len(algorithm_names)))

    plt.xlabel('Function Evaluations')
    plt.ylabel('Fitness (log scale)')
    plt.title(title)
    plt.legend(frameon=False)
    plt.grid(True, alpha=0.3)
    plt.tight_layout()

    try:
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
        plt.close()
    except Exception as e:
        print(f"Failed to save plot: {str(e)}")
        raise


# ========================
# SAVING RESULT TO EXCEL
# ========================

def save_all_results(bestFitnessAll: np.ndarray,
                     algorithm_names: List[str],
                     function_ids: List[str],
                     dir_name: str) -> None:
    """
    Processes all results and saves to Excel with comprehensive sheets including:
    - cmpResult: Main comparison results (avg, std, ranks)
    - raw_data: Complete raw fitness values
    - pValue: Wilcoxon signed-rank test results
    - rank_pValue: Combined ranks and p-values
    - pValue_sign: Statistical significance indicators
    - Individual function sheets (F1-F30): Boxplot-ready data
    """
    # Save raw fitness data as numpy arrays
    # Save the raw fitness data
    fitness_filename = os.path.join(dir_name, 'best_fitness_all.npy')
    np.save(fitness_filename, bestFitnessAll)
    print(f"Raw best fitness data saved to: {fitness_filename}")

    # Basic calculations
    n_algorithms, n_runs, n_functions = bestFitnessAll.shape
    avg_fitness = np.nanmean(bestFitnessAll, axis=1)
    std_fitness = np.nanstd(bestFitnessAll, axis=1, ddof=0)

    # Rank calculations (MATLAB compatible)
    rank_data = np.zeros_like(avg_fitness)
    for col in range(n_functions):
        rank_data[:, col] = rankdata(avg_fitness[:, col])
    rank_sum = np.sum(rank_data, axis=1)
    final_rank = rankdata(rank_sum / n_functions)

    # Robust Wilcoxon p-values with fallback to t-test when appropriate
    p_values = np.full((n_functions, n_algorithms - 1), np.nan)
    for func in range(n_functions):
        for algo in range(1, n_algorithms):
            # Get the two samples to compare
            sample1 = bestFitnessAll[0, :, func]
            sample2 = bestFitnessAll[algo, :, func]

            # Step 1: Check for completely identical distributions
            if np.array_equal(sample1, sample2):
                p_values[func, algo - 1] = 1.0
                continue

            # Step 2: Check if there are enough differences for Wilcoxon
            diff = sample1 - sample2
            if np.count_nonzero(diff) > 5:  # Wilcoxon needs at least 6 non-zero differences
                try:
                    # Step 3: Apply Wilcoxon test when appropriate
                    _, p_values[func, algo - 1] = wilcoxon(sample1, sample2)
                except ValueError as e:
                    # Handle specific ValueError cases
                    if "zero_method 'wilcox'" in str(e):
                        p_values[func, algo - 1] = 1.0
                    else:
                        # Fall back to t-test if Wilcoxon fails
                        try:
                            _, p_values[func, algo - 1] = ttest_rel(sample1, sample2)
                        except Exception:
                            p_values[func, algo - 1] = 1.0
            else:
                # Step 4: Use t-test for small samples
                try:
                    _, p_values[func, algo - 1] = ttest_rel(sample1, sample2)
                except Exception:
                    # Handle any other possible exceptions
                    p_values[func, algo - 1] = 1.0

    # Create Excel file
    basename = os.path.basename(os.path.normpath(dir_name))
    excel_path = f"{dir_name}/result-{basename}.xlsx"
    with pd.ExcelWriter(excel_path, engine='openpyxl') as writer:

        # ========================
        # Sheet 1: Raw Data (Complete experimental records)
        # ========================
        raw_records = []
        for algo_idx, algo_name in enumerate(algorithm_names):
            for run_idx in range(n_runs):
                for func_idx, func_id in enumerate(function_ids):
                    raw_records.append({
                        'Algorithm': algo_name,
                        'Run': run_idx + 1,
                        'Function': func_id,
                        'Fitness': bestFitnessAll[algo_idx, run_idx, func_idx]
                    })
        pd.DataFrame(raw_records).to_excel(
            writer,
            sheet_name='raw_data',
            index=False
        )

        # ========================
        # Sheet 2: Main Comparison Results
        # ========================
        main_results = []
        for func_idx, func_id in enumerate(function_ids):
            for algo_name, algo_avg, algo_std in zip(algorithm_names,
                                                     avg_fitness[:, func_idx],
                                                     std_fitness[:, func_idx]):
                main_results.extend([
                    {'Function': func_id, 'Metric': 'Avg', 'Algorithm': algo_name, 'Value': algo_avg},
                    {'Function': func_id, 'Metric': 'Std', 'Algorithm': algo_name, 'Value': algo_std}
                ])

        # Add summary statistics
        for algo_name, algo_rank, algo_rank_sum in zip(algorithm_names,
                                                       final_rank,
                                                       rank_sum / n_functions):
            main_results.extend([
                {'Function': 'ARV', 'Metric': '', 'Algorithm': algo_name, 'Value': algo_rank_sum},
                {'Function': 'Rank', 'Metric': '', 'Algorithm': algo_name, 'Value': algo_rank}
            ])

        # Create DataFrame
        df = pd.DataFrame(main_results)

        # Extract numeric part from function IDs and convert to integers for proper sorting
        def extract_numeric_key(func_id):
            if func_id in ['ARV', 'Rank']:
                return float('inf')  # Place these at the end
            return int(''.join(filter(str.isdigit, func_id)))

        # Create custom sort order
        regular_functions = sorted([f for f in df['Function'].unique() if f not in ['ARV', 'Rank']],
                                   key=extract_numeric_key)
        function_order = regular_functions + ['ARV', 'Rank']

        # Convert Function column to ordered categorical data type
        df['Function'] = pd.Categorical(df['Function'],
                                        categories=function_order,
                                        ordered=True)

        # Pivot to match MATLAB's wide format
        (df.pivot_table(index=['Function', 'Metric'],
                        columns='Algorithm',
                        values='Value',
                        observed=False)  # Explicitly set observed parameter
         .reindex(columns=algorithm_names)
         .to_excel(writer, sheet_name='cmp_result'))

        # ========================
        # Sheet 3: Statistical Testing
        # ========================
        pvalue_df = pd.DataFrame(
            p_values,
            index=function_ids,
            columns=[f"{name}_p" for name in algorithm_names[1:]]
        )
        pvalue_df.to_excel(writer, sheet_name='pValue')

        # ========================
        # Sheet 4: Rank & pValue Combo
        # ========================
        rank_pvalue_data = []
        for func_idx, func_id in enumerate(function_ids):
            row = {'Function': func_id, algorithm_names[0]: rank_data[0, func_idx]}
            for algo_idx in range(1, n_algorithms):
                row.update({
                    algorithm_names[algo_idx]: rank_data[algo_idx, func_idx],
                    f"{algorithm_names[algo_idx]}_p": p_values[func_idx, algo_idx - 1]
                })
            rank_pvalue_data.append(row)
        pd.DataFrame(rank_pvalue_data).to_excel(
            writer,
            sheet_name='rank_pValue',
            index=False
        )

        # ========================
        # Sheet 5: pValue & Sign (Base vs ALL Others)
        # ========================
        # First, check if this is an existing variable that might be persisting between runs
        if 'summary_counts' in locals() or 'summary_counts' in globals():
            print("Warning: summary_counts variable already exists - clearing it to prevent accumulation")

        pValueSign_data = []

        # Exception handling: Ensure there's at least a base algorithm and one comparison algorithm
        if len(algorithm_names) <= 1:
            print("Warning: At least two algorithms are needed for comparison")
        else:
            # Create column names list for proper Excel headers
            column_names = ['Func']
            for algo_name in algorithm_names[1:]:  # All non-base algorithms
                column_names.extend([f'{algo_name}_p', f'{algo_name}_sign'])

            # Create a fresh summary counts dictionary
            summary_counts = {}
            # Make sure we have unique entries only
            unique_algos = []
            for algo in algorithm_names[1:]:
                if algo not in unique_algos:
                    unique_algos.append(algo)
                    summary_counts[algo] = {'+': 0, '-': 0, '=': 0}

            print(f"Processing {len(function_ids)} functions with {len(unique_algos)} comparison algorithms")

            # Data rows - Compare base vs each other algorithm
            for func_idx in range(len(function_ids)):
                row_data = {}
                row_data['Func'] = f'F{func_idx + 1}'
                base_rank = rank_data[0, func_idx]  # Rank of base algorithm

                # Compare base against EACH other algorithm
                for algo_idx in range(1, len(algorithm_names)):
                    algo_name = algorithm_names[algo_idx]

                    # Ensure p_values indexing is correct
                    p_idx = algo_idx - 1  # Because we skip the base algorithm
                    # Safety check
                    if func_idx < p_values.shape[0] and p_idx < p_values.shape[1]:
                        pval = p_values[func_idx, p_idx]
                    else:
                        print(f"Warning: p_values index out of bounds func_idx={func_idx}, p_idx={p_idx}")
                        pval = 1.0  # Default to non-significant

                    algo_rank = rank_data[algo_idx, func_idx]

                    # Determine significance (lower rank is better logic is confirmed)
                    if pval < 0.05:
                        sign = '+' if base_rank < algo_rank else '-'
                    else:
                        sign = '='

                    # Update summary - only for this single comparison
                    summary_counts[algo_name][sign] += 1

                    # Add both columns
                    row_data[f'{algo_name}_p'] = f'{pval:.4f}'
                    row_data[f'{algo_name}_sign'] = sign

                pValueSign_data.append(row_data)

            # Verify counts match expected
            for algo_name in unique_algos:
                counts = summary_counts[algo_name]
                total = counts['+'] + counts['-'] + counts['=']
                print(
                    f"Algorithm {algo_name} counts: +={counts['+']}, -={counts['-']}, =={counts['=']} (Total: {total})")
                if total != len(function_ids):
                    print(f"Warning: Count mismatch for {algo_name}. Expected {len(function_ids)}, got {total}")

            # Summary row (+/-/= counts for each comparison)
            summary_row = {'Func': '+/-/='}
            for algo_name in unique_algos:
                counts = summary_counts[algo_name]
                summary_row[f'{algo_name}_p'] = ''
                summary_row[f'{algo_name}_sign'] = f"{counts['+']}/{counts['-']}/{counts['=']}"
            pValueSign_data.append(summary_row)

            # Convert to DataFrame with explicit column names
            pValueSign_df = pd.DataFrame(pValueSign_data, columns=column_names)
            pValueSign_df.to_excel(
                writer,
                sheet_name='pValue_sign',
                index=False,
                header=True
            )

        # ========================
        # Sheets 6+: Individual Function Data
        # ========================
        for func_idx, func_id in enumerate(function_ids):
            func_data = []
            for run_idx in range(n_runs):
                func_data.append({
                    'Run': run_idx + 1,
                    **{algo: bestFitnessAll[algo_idx, run_idx, func_idx]
                       for algo_idx, algo in enumerate(algorithm_names)}
                })
            pd.DataFrame(func_data).to_excel(
                writer,
                sheet_name=func_id,
                index=False
            )

    print(f"All results saved to {excel_path}")


# Helper function (equivalent to MATLAB's unique ranking)
def rankdata(a, method='dense'):
    """
    Assign ranks to data, dealing with ties appropriately.
    Similar to MATLAB's ranking behavior.
    """
    arr = np.ravel(a)
    sorter = np.argsort(arr)
    inv = np.empty_like(sorter)
    inv[sorter] = np.arange(len(sorter))

    arr = arr[sorter]
    obs = np.r_[True, arr[1:] != arr[:-1]]
    dense = obs.cumsum()[inv]

    if method == 'dense':
        return dense
    elif method == 'min':
        count = np.r_[np.nonzero(obs)[0], len(obs)]
        return count[dense - 1] + 1
    else:
        raise ValueError("Unknown method")


# ========================
# STATISTIC ANALYSIS
# ========================

def plot_boxplots(excel_path: str, algorithm_names: List[str], dir_name: str):
    """
    Creates and saves boxplot visualizations for each function's results

    Args:
        excel_path: Path to the results Excel file
        algorithm_names: List of algorithm names
        dir_name: Directory to save the plots
    """
    # Create plots directory if it doesn't exist
    # plots_dir = os.path.join(dir_name, 'boxplots')
    # os.makedirs(plots_dir, exist_ok=True)
    plots_dir = dir_name

    # Style parameters matching MATLAB
    plt.style.use('default')
    plt.rcParams.update({
        'font.size': 10,
        'axes.linewidth': 1.2,
        'lines.linewidth': 1.5,
        'xtick.major.width': 1.2,
        'ytick.major.width': 1.2
    })

    # Read all function sheets
    xls = pd.ExcelFile(excel_path)
    func_sheets = [sheet for sheet in xls.sheet_names if sheet.startswith('F')]

    for func_sheet in func_sheets:
        # Read data for this function
        df = pd.read_excel(xls, sheet_name=func_sheet)
        plot_data = df.drop(columns=['Run']).values

        # Create figure
        fig, ax = plt.subplots(figsize=(10, 6))
        algo_num = len(algorithm_names)

        # Style parameters
        fence_margin = 0.14
        rectangle_margin = 0.28
        colors = plt.cm.viridis(np.linspace(0, 1, algo_num))

        # Set axis limits
        ax.set_xlim(0.5, algo_num + 0.5)

        for algo_idx in range(algo_num):
            # Calculate statistics
            box_data = np.sort(plot_data[:, algo_idx])
            quater2 = np.median(box_data)
            quater1 = np.median(box_data[box_data <= quater2])
            quater3 = np.median(box_data[box_data >= quater2])
            iqr = quater3 - quater1
            fence_low = quater1 - 1.5 * iqr
            fence_up = quater3 + 1.5 * iqr
            mean_dot = np.mean(plot_data[:, algo_idx])

            # Plot fence
            ax.plot([algo_idx + 1, algo_idx + 1], [fence_up, fence_low],
                    color='k', linestyle=':')
            ax.plot([algo_idx + 1 - fence_margin, algo_idx + 1 + fence_margin],
                    [fence_up, fence_up], color='k')
            ax.plot([algo_idx + 1 - fence_margin, algo_idx + 1 + fence_margin],
                    [fence_low, fence_low], color='k')

            # Plot quantile rectangle
            if quater3 > quater1:
                rect = Rectangle((algo_idx + 1 - rectangle_margin, quater1),
                                 2 * rectangle_margin, quater3 - quater1,
                                 edgecolor='k', facecolor=colors[algo_idx])
                ax.add_patch(rect)

            # Plot median line
            ax.plot([algo_idx + 1 - rectangle_margin, algo_idx + 1 + rectangle_margin],
                    [quater2, quater2], color='k', linewidth=1.5)

            # Plot mean dot
            ax.plot(algo_idx + 1, mean_dot, 'o',
                    markerfacecolor=colors[algo_idx],
                    markeredgecolor='k',
                    markersize=8)

            # Plot individual points (like MATLAB's outliers)
            outliers = plot_data[(plot_data[:, algo_idx] < fence_low) |
                                 (plot_data[:, algo_idx] > fence_up), algo_idx]
            if len(outliers) > 0:
                ax.plot([algo_idx + 1] * len(outliers), outliers, '.',
                        color=[0.6, 0.6, 0.6],
                        markersize=12)

        # Finalize plot
        ax.set_xticks(range(1, algo_num + 1))
        ax.set_xticklabels(algorithm_names)
        ax.set_title(f'Function {func_sheet}')
        ax.grid(True, alpha=0.3)

        # Save plot
        plot_path = os.path.join(plots_dir, f'{func_sheet}_boxplot.png')
        plt.savefig(plot_path, dpi=300, bbox_inches='tight')
        plt.close()

    print(f"Boxplots saved to {plots_dir}")


if __name__ == "__main__":
    pass
