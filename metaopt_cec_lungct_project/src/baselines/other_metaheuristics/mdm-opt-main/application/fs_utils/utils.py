#!/usr/bin/env python
# Created by "Jona" at 14:26, 08/06/2025 ----------%
#       Email: jona.wzu@gmail.com            %
#       Github: https://github.com/JonaWon       %
# --------------------------------------------------%

"""
Feature Selection Utilities (fs_utils.py)
=========================================
Contains helper functions for feature selection experiments:
- Result directory setup
- Data loading and preprocessing
- Classification metric calculations
- Evaluating final solutions
- Saving results (CSV format)
- Convergence curve sampling
- Statistical analysis and plotting (adapted for FS)
"""

import os
import numpy as np
import pandas as pd
import datetime
import warnings
from typing import List, Dict, Union

# ML specific imports (keep minimal, only if function needs them directly)
from sklearn.metrics import (accuracy_score, confusion_matrix, precision_score,
                             recall_score, f1_score, matthews_corrcoef)
from sklearn.preprocessing import MinMaxScaler
from scipy.stats import wilcoxon, ttest_rel, rankdata as scipy_rankdata
import matplotlib.pyplot as plt

# Ignore potential division by zero warnings in metrics
warnings.filterwarnings("ignore", category=RuntimeWarning)
warnings.filterwarnings("ignore", category=UserWarning, message="FixedFormatter should only be used together with FixedLocator")


# ========================
# SETUP RESULT DIR for FS
# ========================

def setup_fs_results_dir(base_name: str) -> str:
    """Creates a timestamped results directory for FS experiments."""
    exp_time = datetime.datetime.now()
    day_str = exp_time.strftime('%Y-%m-%d')
    # Specific directory structure for feature selection results
    dir_name = os.path.join('./application/fs_exp_result', day_str, f'{base_name}')
    os.makedirs(dir_name, exist_ok=True)
    return dir_name

# ========================
# DATA LOADING for FS
# ========================

def load_dataset(dataset_name: str, data_dir: str) -> tuple[np.ndarray | None, np.ndarray | None, str]:
    """Loads a .dat dataset, handles label=0, scales features, returns features, labels, and filename."""
    filename = os.path.join(data_dir, f"{dataset_name}.dat")
    try:
        # Try loading with space as delimiter first
        data = np.loadtxt(filename)
    except ValueError:
        try:
            # Fallback to comma delimiter if space fails
            print(f"Space delimiter failed for {filename}. Trying comma.")
            data = np.loadtxt(filename, delimiter=',')
        except Exception as e:
            print(f"Error loading {filename}: {e}")
            return None, None, filename
    except Exception as e:
         print(f"Error loading {filename}: {e}")
         return None, None, filename


    X = data[:, :-1]
    y = data[:, -1].astype(int) # Ensure labels are integers

    # Scale features (important for KNN and many other algorithms)
    scaler = MinMaxScaler()
    X = scaler.fit_transform(X)

    return X, y, filename

# ========================
# METRIC CALCULATIONS
# ========================

def calculate_metrics(y_true: np.ndarray, y_pred: np.ndarray) -> dict:
    """Calculates various classification metrics, with correct binary vs. multiclass handling."""
    # find all labels so cm covers classes even if one is missing in y_pred
    labels = np.union1d(np.unique(y_true), np.unique(y_pred))

    # if no labels at all
    if labels.size == 0:
        raise ValueError("y_true and y_pred contain no labels.")

    cm = confusion_matrix(y_true, y_pred, labels=labels)
    binary = (cm.shape == (2, 2))

    # Accuracy & error
    acc = accuracy_score(y_true, y_pred)
    err = 1.0 - acc

    # Precision, recall, f1 (macro for multiclass; binary for 2-class)
    avg = 'binary' if binary else 'macro'
    precision = precision_score(y_true, y_pred, average=avg, zero_division=0)
    sensitivity = recall_score(y_true, y_pred, average=avg, zero_division=0)
    f1 = f1_score(y_true, y_pred, average=avg, zero_division=0)

    # Specificity
    if binary:
        tn, fp, fn, tp = cm.ravel()
        specificity = tn / (tn + fp) if (tn + fp) > 0 else 0
    else:
        # Calculate specificity for each class in one-vs-rest fashion
        specificities = []
        for i in range(len(labels)):
            # For each class, create a binary confusion matrix
            true_neg = np.sum(cm) - np.sum(cm[i, :]) - np.sum(cm[:, i]) + cm[i, i]
            false_pos = np.sum(cm[:, i]) - cm[i, i]

            # Calculate specificity for this class
            if true_neg + false_pos > 0:
                specificities.append(true_neg / (true_neg + false_pos))
            else:
                specificities.append(0)

        # Macro-average of specificities
        specificity = np.mean(specificities)

    # Matthews Corrcoef (works for multiclass too)
    try:
        mcc = matthews_corrcoef(y_true, y_pred)
    except ValueError:
        mcc = np.nan

    return {
        'Accuracy': acc,
        'Error': err,
        'Sensitivity': sensitivity,
        'Specificity': specificity,
        'Precision': precision,
        'F1': f1,
        'MCC': mcc
    }

# ========================
# EVALUATING FINAL SOLUTION
# ========================

def evaluate_final_solution(solution_binary: np.ndarray, X_train: np.ndarray, y_train: np.ndarray, X_test: np.ndarray, y_test: np.ndarray, classifier):
    """Evaluates a binary solution vector on train/test data and returns metrics."""
    features_selected_indices = np.where(solution_binary == 1)[0]
    num_selected = len(features_selected_indices)

    if num_selected == 0:
        # Handle case with no features selected - return defaults (bad performance)
        # print("Warning: Evaluating solution with no features selected.")
        return {
            'Accuracy': 0.0, 'Error': 1.0, 'Sensitivity': 0.0, 'Specificity': 0.0,
            'Precision': 0.0, 'MCC': -1.0 if len(np.unique(y_test))==2 else 0.0, # Adjust MCC default based on classes
            'F1': 0.0, 'NumFeatures': 0
        }

    X_train_subset = X_train[:, features_selected_indices]
    X_test_subset = X_test[:, features_selected_indices]

    try:
        # Clone the classifier to ensure independence if it's stateful
        from sklearn.base import clone
        cloned_classifier = clone(classifier)
        cloned_classifier.fit(X_train_subset, y_train)
        y_pred = cloned_classifier.predict(X_test_subset)
    except Exception as e:
         print(f"Error during final evaluation fit/predict: {e}")
         # Return default bad values if evaluation fails
         return {
            'Accuracy': np.nan, 'Error': np.nan, 'Sensitivity': np.nan, 'Specificity': np.nan,
            'Precision': np.nan, 'MCC': np.nan, 'F1': np.nan, 'NumFeatures': num_selected
         }

    metrics = calculate_metrics(y_test, y_pred)
    metrics['NumFeatures'] = num_selected
    return metrics

# ========================
# SAMPLING FUNCTIONS
# ========================

def my_sampling(curve: Union[List[float], np.ndarray], num_points: int) -> np.ndarray:
    """
    Resamples a convergence curve to have a fixed number of points using linear interpolation.
    """
    original_len = len(curve)
    if original_len == 0:
        return np.full(num_points, np.nan)
    if original_len == 1:
        return np.full(num_points, curve[0])

    curve_np = np.asarray(curve)
    # Replace inf values if any
    curve_np[np.isinf(curve_np)] = np.nan
    # Find max finite value to replace NaNs if needed
    max_finite = np.nanmax(curve_np[np.isfinite(curve_np)]) if np.any(np.isfinite(curve_np)) else 1.0
    curve_np[np.isnan(curve_np)] = max_finite # Replace NaN with max finite value

    original_indices = np.linspace(0, 1, original_len)
    target_indices = np.linspace(0, 1, num_points)

    try:
        return np.interp(target_indices, original_indices, curve_np)
    except Exception as e:
        print(f"Sampling error: {e}. Using fallback.")
        return np.full(num_points, curve_np[-1] if original_len > 0 else np.nan)


# ========================
# RESULT SAVING FUNCTIONS
# ========================

def save_fold_results_to_csv(results_df: pd.DataFrame, filename: str):
    """Saves detailed fold results (excluding lists/arrays) to CSV."""
    try:
        columns_to_save = [col for col in results_df.columns if col not in ['Convergence', 'BestSolution']]
        results_df[columns_to_save].to_csv(filename, index=False, float_format='%.6f')
        print(f"Fold results saved to: {filename}")
    except Exception as e:
        print(f"Error saving fold results to {filename}: {e}")

def save_best_solutions_to_csv(results_df: pd.DataFrame, filename: str):
    """Saves best solutions (binary vectors) from each fold to CSV."""
    try:
        solutions_df = results_df[['Algorithm', 'Fold', 'BestSolution']].copy()
        # Convert numpy array solution to comma-separated string
        solutions_df['BestSolution'] = solutions_df['BestSolution'].apply(lambda x: ','.join(map(str, x)) if isinstance(x, np.ndarray) else x)
        solutions_df.to_csv(filename, index=False)
        print(f"Best solutions saved to: {filename}")
    except Exception as e:
        print(f"Error saving best solutions to {filename}: {e}")

def save_convergence_to_csv(all_run_results: List[Dict], max_iter: int, filename: str):
    """Saves full convergence curves for all folds/algorithms to CSV."""
    try:
        convergence_data = []
        for record in all_run_results:
            # Sample or pad convergence curve using my_sampling
            sampled_curve = my_sampling(record.get('Convergence', []), max_iter) # Use .get for safety
            row = {'Algorithm': record['Algorithm'], 'Fold': record['Fold'],
                   **{f'Iter_{i+1}': val for i, val in enumerate(sampled_curve)}}
            convergence_data.append(row)
        convergence_df = pd.DataFrame(convergence_data)
        convergence_df.to_csv(filename, index=False, float_format='%.6f')
        print(f"Convergence curves saved to: {filename}")
    except Exception as e:
        print(f"Error saving convergence curves to {filename}: {e}")

def save_summary_stats_to_csv(results_df: pd.DataFrame, filename: str):
    """Calculates and saves summary statistics (mean, std over folds) to CSV."""
    try:
        # Define metrics to aggregate
        metrics_to_agg = {
            'BestFitness': ['mean', 'std'], 'Accuracy': ['mean', 'std'],
            'Error': ['mean', 'std'], 'Sensitivity': ['mean', 'std'],
            'Specificity': ['mean', 'std'], 'Precision': ['mean', 'std'],
            'MCC': ['mean', 'std'], 'F1': ['mean', 'std'],
            'NumFeatures': ['mean', 'std'], 'Time': ['mean', 'std']
        }
        summary_stats = results_df.groupby('Algorithm').agg(metrics_to_agg)
        # Flatten multi-index columns (e.g., ('Accuracy', 'mean') -> 'Accuracy_mean')
        summary_stats.columns = ['_'.join(col).strip() for col in summary_stats.columns.values]
        summary_stats = summary_stats.reset_index()
        summary_stats.to_csv(filename, index=False, float_format='%.6f')
        print(f"Summary statistics saved to: {filename}")
    except Exception as e:
        print(f"Error saving summary stats to {filename}: {e}")


def save_avg_convergence_to_csv(convergence_all_file: str, filename: str):
    """Calculates and saves average convergence curves per algorithm."""
    try:
        convergence_df = pd.read_csv(convergence_all_file)
        # Ensure Fold column exists before dropping
        if 'Fold' in convergence_df.columns:
             avg_convergence_df = convergence_df.drop(columns=['Fold']).groupby('Algorithm').mean().reset_index()
        else:
             avg_convergence_df = convergence_df.groupby('Algorithm').mean().reset_index() # Handle if Fold column was missing

        avg_convergence_df.to_csv(filename, index=False, float_format='%.6f')
        print(f"Average convergence curves saved to: {filename}")
    except FileNotFoundError:
         print(f"Error: Convergence file not found at {convergence_all_file}")
    except Exception as e:
        print(f"Error saving average convergence curves to {filename}: {e}")


def save_feature_importance_to_csv(results_df: pd.DataFrame, num_folds: int, filename: str):
    """Calculates and saves feature importance (selection frequency) to CSV."""
    try:
        feature_importance_data = []
        all_solutions = results_df[['Algorithm', 'BestSolution']].copy()

        # Check if 'BestSolution' column contains valid numpy arrays
        if not all(isinstance(sol, np.ndarray) for sol in all_solutions['BestSolution']):
             print("Warning: 'BestSolution' column contains non-array elements. Skipping feature importance.")
             return

        num_features = len(all_solutions['BestSolution'].iloc[0]) if not all_solutions.empty else 0
        if num_features == 0:
             print("Warning: Cannot determine number of features. Skipping feature importance.")
             return

        for algo_name, group in all_solutions.groupby('Algorithm'):
             if group.empty: continue
             # Stack the binary vectors and sum column-wise
             feature_counts = np.sum(np.vstack(group['BestSolution'].to_numpy()), axis=0)
             # Avoid division by zero if num_folds is 0
             importance = feature_counts / num_folds if num_folds > 0 else np.zeros_like(feature_counts)
             # Create dict for this algorithm's importance values
             importance_dict = {f'Feature_{i+1}': imp for i, imp in enumerate(importance)}
             feature_importance_data.append({'Algorithm': algo_name, **importance_dict})

        if feature_importance_data:
             feature_importance_df = pd.DataFrame(feature_importance_data)
             feature_importance_df.to_csv(filename, index=False, float_format='%.4f')
             print(f"Feature importance saved to: {filename}")
        else:
            print("No feature importance data generated.")

    except Exception as e:
        print(f"Error saving feature importance to {filename}: {e}")

# ========================
# STATISTICAL ANALYSIS & PLOTTING (ADAPTED for FS)
# ========================

# Helper for ranking (from original fs_utils.py)
def rankdata_fs(a, method='dense'):
    """Assign ranks to data, dealing with ties appropriately."""
    arr = np.ravel(a)
    sorter = np.argsort(arr)
    inv = np.empty_like(sorter)
    inv[sorter] = np.arange(len(sorter))
    arr = arr[sorter]
    obs = np.r_[True, arr[1:] != arr[:-1]]
    dense = obs.cumsum()[inv]
    if method == 'dense': return dense
    elif method == 'min':
        count = np.r_[np.nonzero(obs)[0], len(obs)]
        return count[dense - 1] + 1
    else: raise ValueError("Unknown method")


def perform_statistical_analysis_fs(results_df: pd.DataFrame, algorithm_names: List[str], metric: str, excel_writer: pd.ExcelWriter):
    """
    Performs Wilcoxon signed-rank tests and ranking based on a specified metric (e.g., 'Accuracy', 'NumFeatures')
    and saves results to sheets in an existing Excel writer object.
    Assumes results_df contains fold-level results with 'Algorithm', 'Fold', and the specified metric column.
    """
    print(f"Performing statistical analysis for metric: {metric}")
    if metric not in results_df.columns:
        print(f"Warning: Metric '{metric}' not found in results DataFrame. Skipping analysis.")
        return

    # Pivot table to get metric values per algorithm per fold
    try:
        pivot_df = results_df.pivot(index='Fold', columns='Algorithm', values=metric)
    except ValueError as e:
        print(f"Multiple runs detected. Can not creating pivot table for metric '{metric}': {e}")
        print("Check if there are duplicate Algorithm/Fold combinations.")
        # Attempt to handle duplicates by averaging - suboptimal but might allow analysis
        try:
            print("Attempting to average duplicates...")
            pivot_df = results_df.groupby(['Fold', 'Algorithm'])[metric].mean().unstack()
            if pivot_df.isnull().any().any():
                 print("Warning: Pivot table contains NaNs after averaging duplicates. Analysis might be affected.")
        except Exception as inner_e:
             print(f"Could not resolve pivot table issue for metric '{metric}': {inner_e}. Skipping analysis.")
             return

    # Ensure columns are in the desired order
    pivot_df = pivot_df.reindex(columns=algorithm_names)
    all_metric_values = pivot_df.to_numpy().T # Shape: (n_algorithms, n_folds)

    if all_metric_values.shape[0] != len(algorithm_names):
        print(f"Warning: Mismatch between algorithm count and pivot table shape for metric '{metric}'. Skipping analysis.")
        return

    n_algorithms, n_folds = all_metric_values.shape
    avg_metric = np.nanmean(all_metric_values, axis=1)
    std_metric = np.nanstd(all_metric_values, axis=1, ddof=1) # Use ddof=1 for sample std dev

    # Rank calculations (lower fitness/error/features is better, higher accuracy is better)
    # Adjust ranking based on metric (Accuracy needs descending rank)
    minimize = not (metric in ['Accuracy', 'Sensitivity', 'Specificity', 'Precision', 'F1', 'MCC']) # Metrics where higher is better
    rank_data = np.zeros_like(avg_metric)
    temp_avg = avg_metric if minimize else -avg_metric # Negate for maximization metrics
    try:
         # Handle potential NaNs before ranking
         if np.isnan(temp_avg).any():
             print(f"Warning: NaNs found in average {metric}. Ranking might be affected.")
             # Replace NaNs with a value that ranks them last (e.g., infinity)
             nan_mask = np.isnan(temp_avg)
             temp_avg[nan_mask] = np.inf

         rank_data = rankdata_fs(temp_avg)
    except Exception as e:
         print(f"Error during ranking for metric {metric}: {e}")
         # Assign default rank if error occurs
         rank_data = np.full_like(avg_metric, np.nan)

    # Wilcoxon p-values (comparing algorithm 0 to others)
    p_values = np.full(n_algorithms - 1, np.nan)
    base_algo_data = all_metric_values[0, :]
    for i in range(1, n_algorithms):
        comp_algo_data = all_metric_values[i, :]
        # Remove NaN pairs before testing
        valid_mask = ~np.isnan(base_algo_data) & ~np.isnan(comp_algo_data)
        sample1 = base_algo_data[valid_mask]
        sample2 = comp_algo_data[valid_mask]

        if len(sample1) < 5: # Need at least 5 pairs for Wilcoxon/ttest
            p_values[i - 1] = 1.0
            continue

        try:
            # Prefer Wilcoxon if assumptions met (roughly symmetric difference)
            # Simplified check: use Wilcoxon if N >= 10, else T-test
            if len(sample1) >= 10:
                 stat, pval = wilcoxon(sample1, sample2, zero_method='pratt', correction=False) # Pratt handles zeros better
            else:
                 stat, pval = ttest_rel(sample1, sample2)
            p_values[i - 1] = pval
        except ValueError as e: # Wilcoxon fails if all differences are same sign or zero
            # print(f"Wilcoxon failed for {algorithm_names[0]} vs {algorithm_names[i]} ({metric}): {e}. Using t-test.")
            try:
                stat, pval = ttest_rel(sample1, sample2)
                p_values[i - 1] = pval
            except Exception as e_ttest:
                 print(f"T-test also failed for {algorithm_names[0]} vs {algorithm_names[i]} ({metric}): {e_ttest}")
                 p_values[i - 1] = 1.0 # Default to non-significant if both fail
        except Exception as e_other:
            print(f"Error during statistical test for {algorithm_names[0]} vs {algorithm_names[i]} ({metric}): {e_other}")
            p_values[i-1] = 1.0

    # Prepare data for Excel sheet
    stats_data = []
    for algo_idx, algo_name in enumerate(algorithm_names):
        stats_data.append({
            'Algorithm': algo_name,
            f'Avg_{metric}': avg_metric[algo_idx],
            f'Std_{metric}': std_metric[algo_idx],
            f'Rank_{metric}': rank_data[algo_idx]
        })
        # Add p-value comparing to the first algorithm
        if algo_idx > 0:
             stats_data[-1][f'p_vs_{algorithm_names[0]}'] = p_values[algo_idx - 1]

    stats_df = pd.DataFrame(stats_data)
    stats_df.to_excel(excel_writer, sheet_name=f'Stats_{metric}', index=False, float_format='%.6f')
    print(f"Statistical analysis for {metric} saved to sheet: Stats_{metric}")

def plot_fs_boxplots(results_df: pd.DataFrame, metric: str, algorithm_names: List[str], save_dir: str, dataset_name: str):
    """Creates and saves boxplot visualizations for a specific metric."""
    print(f"Generating boxplot for metric: {metric}")
    if metric not in results_df.columns:
        print(f"Warning: Metric '{metric}' not found in results DataFrame. Skipping boxplot.")
        return

    # Pivot table to get data in shape (n_folds, n_algorithms)
    try:
        pivot_df = results_df.pivot(index='Fold', columns='Algorithm', values=metric)
    except ValueError: # Handle potential duplicates by averaging
         pivot_df = results_df.groupby(['Fold', 'Algorithm'])[metric].mean().unstack()

    pivot_df = pivot_df.reindex(columns=algorithm_names) # Ensure correct order
    plot_data = pivot_df.to_numpy() # Shape: (n_folds, n_algorithms)

    # Handle potential NaN columns if an algorithm failed completely
    valid_algo_indices = [i for i, name in enumerate(algorithm_names) if not np.all(np.isnan(plot_data[:, i]))]
    if not valid_algo_indices:
         print(f"Warning: All algorithms have NaN values for metric '{metric}'. Skipping boxplot.")
         return

    # Filter data and names for valid algorithms
    plot_data = plot_data[:, valid_algo_indices]
    valid_algorithm_names = [algorithm_names[i] for i in valid_algo_indices]
    algo_num = len(valid_algorithm_names)

    plt.style.use('default') # Reset style
    plt.rcParams.update({'font.size': 10, 'axes.linewidth': 1.2, 'lines.linewidth': 1.5, 'xtick.major.width': 1.2, 'ytick.major.width': 1.2})
    fig, ax = plt.subplots(figsize=(max(10, algo_num * 0.8), 6)) # Adjust width based on algo count

    # Create boxplot
    box_plot = ax.boxplot(plot_data, patch_artist=True, showfliers=True, # Show outliers
                           medianprops={'color': 'black', 'linewidth': 1.5},
                           whiskerprops={'linestyle': ':'},
                           capprops={'linewidth': 1.5})

    # Style the boxes
    colors = plt.cm.viridis(np.linspace(0, 1, algo_num))
    for patch, color in zip(box_plot['boxes'], colors):
        patch.set_facecolor(color)
        patch.set_edgecolor('black')

    # Add mean points
    means = np.nanmean(plot_data, axis=0)
    ax.plot(np.arange(1, algo_num + 1), means, 'o', markerfacecolor='white', markeredgecolor='black', markersize=8, label='Mean')

    # Finalize plot
    ax.set_xticks(np.arange(1, algo_num + 1))
    ax.set_xticklabels(valid_algorithm_names, rotation=30, ha='right') # Rotate labels if many algos
    ax.set_title(f'{dataset_name} - Boxplot for {metric}')
    ax.set_ylabel(metric)
    ax.grid(True, axis='y', linestyle='--', alpha=0.6)
    plt.tight_layout() # Adjust layout

    # Save plot
    plot_filename = os.path.join(save_dir, f'{dataset_name}_boxplot_{metric}.png')
    try:
        plt.savefig(plot_filename, dpi=300)
        print(f"Boxplot saved to: {plot_filename}")
    except Exception as e:
        print(f"Error saving boxplot {plot_filename}: {e}")
    plt.close(fig) # Close the figure to free memory