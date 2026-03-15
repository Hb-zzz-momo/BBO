#!/usr/bin/env python
# Created by "Jona" at 14:26, 08/06/2025 ----------%
#       Email: jona.wzu@gmail.com            %
#       Github: https://github.com/JonaWon       %
# --------------------------------------------------%

import numpy as np
import pandas as pd
import os
import sys
import time
import datetime
import warnings
from joblib import Parallel, delayed

# Machine Learning and Optimization related imports
from sklearn.model_selection import KFold
from sklearn.metrics import accuracy_score
from sklearn.neighbors import KNeighborsClassifier
from sklearn.svm import SVC
from sklearn.tree import DecisionTreeClassifier  # CART
from sklearn.ensemble import RandomForestClassifier, AdaBoostClassifier
from xgboost import XGBClassifier
from lightgbm import LGBMClassifier
from catboost import CatBoostClassifier
from sklearn.neural_network import MLPClassifier

# Add the project root directory to sys.path
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.append(project_root)

from mealpy import FloatVar, GWO, WOA, PSO, DE, SSA
from fs_utils import *

warnings.filterwarnings("ignore", category=RuntimeWarning)

# --- Configuration ---
DATASET_DIR = 'application/fs_datasets/'  # Directory containing .dat files
DATASETS = [
    'SpectEW',
    # 'Tumors_9',     # 9C 60*5726
    # 'Tumors_11',    # 11C 174*12353
    # 'Tumors_14',    # 26C 308*15009
]

# --- Experiment Parameters ---
EXP_NUM = 10   # Number of independent runs per dataset
FOLDS = 10     # Number of cross-validation folds
POP_SIZE = 20 # Population size
MAX_ITER = 50 # Max iterations

# --- Algorithm Selection ---
ALGORITHM_MAP = {
    'bGWO': GWO.BinaryGWO,
    'bWOA': WOA.BinaryWOA,
    'bPSO': PSO.BinaryPSO,
    'bDE'  : DE.BinaryDE,
    'bSSA': SSA.BinarySSA,
}
# Select which algorithms to run
ACTIVE_ALGORITHMS = [
    'bGWO',
    # 'bWOA',
    'bPSO',
    # 'bDE',
    # 'bSSA',
]
SELECTED_ALGORITHMS = {name: ALGORITHM_MAP[name] for name in ACTIVE_ALGORITHMS if name in ALGORITHM_MAP and ALGORITHM_MAP[name] is not None}
if not SELECTED_ALGORITHMS: raise ValueError("No valid/selected algorithms found.")
ALGORITHM_NAMES = list(SELECTED_ALGORITHMS.keys())

# --- Classifier Selection ---
CLASSIFIERS = {
    'knn': KNeighborsClassifier(n_neighbors=5),
    'svm': SVC(kernel="rbf"),
    'cart': DecisionTreeClassifier(criterion='gini'),  # CART (Classification and Regression Trees)
    'rf': RandomForestClassifier(n_estimators=100),
    'adaboost': AdaBoostClassifier(n_estimators=50),
    'xgboost': XGBClassifier(eval_metric='logloss'),
    'lightgbm': LGBMClassifier(),
    'catboost': CatBoostClassifier(verbose=False),  # verbose=0 to suppress output
    'mlp': MLPClassifier(hidden_layer_sizes=(100,), max_iter=500)
}
# Select which classifiers to run
ACTIVE_CLASSIFIERS = [
    'knn',
    # 'svm',
    # 'rf',
    # 'cart',
    # 'adaboost',
    # 'xgboost',
    # 'lightgbm',
    # 'catboost',
    # 'mlp'
]
SELECTED_CLASSIFIERS = {name: CLASSIFIERS[name] for name in ACTIVE_CLASSIFIERS if name in CLASSIFIERS}
if not SELECTED_CLASSIFIERS: raise ValueError("No valid/selected classifiers found.")
CLASSIFIER_NAMES = list(SELECTED_CLASSIFIERS.keys())

# --- Transfer function configuration ---
TRANSFER_FUNCTIONS = {
    # 'tf_1': s1,
    # 'tf_2': s2,
    # 'tf_3': s3,
    # 'tf_4': s4,
    'tf_5': v1,
    # 'tf_6': v2,
    # 'tf_7': v3,
    # 'tf_8': v4,
    # 'tf_9': gwo
}

# --- Fitness Function Parameters ---
ALPHA = 0.95 # Weight for classification error vs feature reduction

# === Objective Function (Kept in main script for clarity on what's optimized) ===
def objective_function_wrapper(solution: np.ndarray, X_train: np.ndarray, y_train: np.ndarray, X_valid: np.ndarray, y_valid: np.ndarray, classifier, alpha: float):
    """Objective function for mealpy optimizers (minimization)."""
    # Binarize solution (thresholding) - Check if your mealpy binary algo needs this
    features_selected_indices = np.where(solution > 0.5)[0]
    num_selected = len(features_selected_indices)
    num_total_features = X_train.shape[1]

    if num_selected == 0: return 1.0 # Worst fitness if no features selected

    X_train_subset = X_train[:, features_selected_indices]
    X_valid_subset = X_valid[:, features_selected_indices]

    try:
        from sklearn.base import clone # Clone classifier for safety
        cloned_classifier = clone(classifier)
        cloned_classifier.fit(X_train_subset, y_train)
        y_pred = cloned_classifier.predict(X_valid_subset)
        # Use accuracy_score directly here for the error component
        error_rate = 1.0 - accuracy_score(y_valid, y_pred)
    except Exception:
        error_rate = 1.0 # Assign worst error if classifier fails

    feature_ratio = num_selected / num_total_features
    fitness = alpha * error_rate + (1 - alpha) * feature_ratio
    return fitness

# === Function to Run Optimization for One Fold (Kept in main script) ===
def run_fold_optimization(transfer_func, fold_idx, train_indices, test_indices, X, y, algorithm_class, algo_name, classifier, classifier_name, alpha, pop_size, max_iter, dataset_name):
    """Runs the optimization process for a single CV fold."""
    print(f"--- Dataset: {dataset_name}, Algo: {algo_name}, Classifier: {classifier_name}, TF: {transfer_func.__name__}, Fold: {fold_idx+1}/{FOLDS} ---")
    X_train, X_test = X[train_indices], X[test_indices]
    y_train, y_test = y[train_indices], y[test_indices]

    start_time = time.time()

    # Define the objective function for this specific fold using the wrapper
    obj_func = lambda solution: objective_function_wrapper(solution, X_train, y_train, X_test, y_test, classifier, alpha)

    problem = {
        "obj_func": obj_func,
        "bounds": FloatVar(lb=(0.,) * X.shape[1], ub=(1.,) * X.shape[1], name="delta"),
        "minmax": "min",
        "n_dims": X.shape[1]
    }

    model = algorithm_class(epoch=max_iter, pop_size=pop_size, transfer_func=transfer_func)

    best_fitness = np.inf
    best_solution_binary = np.zeros(X.shape[1], dtype=int)
    convergence_curve = [np.inf] * max_iter

    try:
        best_agent = model.solve(problem)
        best_fitness = best_agent.target.fitness
        # Ensure final solution is binary
        best_solution_binary = (best_agent.solution > 0.5).astype(int)
        # Ensure convergence curve has expected length
        raw_curve = model.history.list_global_best_fit
        convergence_curve = my_sampling(raw_curve, max_iter) # Sample/pad the curve

    except Exception as e:
        print(f"ERROR during optimization for {algo_name} on fold {fold_idx+1}: {e}")
        # Keep default bad values

    end_time = time.time()
    execution_time = end_time - start_time

    # Evaluate the final binary solution on the test set of this fold using helper
    fold_metrics = evaluate_final_solution(best_solution_binary, X_train, y_train, X_test, y_test, classifier)

    # Combine results
    results = {
        'Fold': fold_idx + 1, 'Algorithm': algo_name, 'Classifier': classifier_name,
        'Dataset': dataset_name, 'TransferFunction': transfer_func.__name__,
        'BestFitness': best_fitness, 'Time': execution_time,
        **fold_metrics, # Add Accuracy, Error, Sens, Spec, etc.
        'BestSolution': best_solution_binary, 'Convergence': convergence_curve # Store sampled curve
    }
    return results

# --- Main Execution Logic ---
if __name__ == "__main__":
    overall_start_time = time.time()
    timestamp = datetime.datetime.now().strftime("%H_%M_%S")

    for dataset_name in DATASETS:
        print(f"\n===== Processing Dataset: {dataset_name} =====")
        X_full, y_full, dataset_path = load_dataset(dataset_name, DATASET_DIR)

        if X_full is None:
            print(f"Skipping dataset {dataset_name} due to loading error.")
            continue

        dataset_results = []  # Store results for all runs of this dataset

        # Loop through independent experiment runs
        for exp_run in range(EXP_NUM):
            print(f"\n--- Starting Experiment Run {exp_run + 1}/{EXP_NUM} for {dataset_name} ---")
            run_start_time = time.time()

            # Setup main directory for this run with timestamp
            base_dir_name = f"{timestamp}-Specific-{EXP_NUM}Runs-{dataset_name}/Run{exp_run + 1}-{dataset_name}"
            run_main_dir = setup_fs_results_dir(base_dir_name)
            print(f"Main results directory for Run {exp_run + 1}: {run_main_dir}")

            run_results_df_all = []  # Store results from all classifiers and TFs in this run

            # Loop through classifiers
            for classifier_name, classifier in SELECTED_CLASSIFIERS.items():
                print(f"\n=== Running with Classifier: {classifier_name} ===")

                # Create classifier directory
                classifier_dir = os.path.join(run_main_dir, classifier_name)
                os.makedirs(classifier_dir, exist_ok=True)
                print(f"Results for classifier {classifier_name} will be saved in: {classifier_dir}")

                run_results_df_all_tfs = []  # Store results from all TFs for this classifier

                # Loop through transfer functions
                for tf_name, transfer_func in TRANSFER_FUNCTIONS.items():
                    print(f"\n--- Running with Transfer Function: {tf_name} ---")

                    # Create subdirectory for this transfer function within classifier directory
                    tf_dir_name = f"{tf_name}"
                    tf_results_dir = os.path.join(classifier_dir, tf_dir_name)
                    os.makedirs(tf_results_dir, exist_ok=True)
                    print(f"Results for {classifier_name} with {tf_name} will be saved in: {tf_results_dir}")

                    # Define filenames within this TF directory
                    filename_base = os.path.join(tf_results_dir, f"{classifier_name}-ExpRun{exp_run + 1}")
                    file_all_folds = f"{filename_base}-AllFoldResults.csv"
                    file_summary = f"{filename_base}-Summary.csv"
                    file_convergence_all = f"{filename_base}-Convergences.csv"
                    file_convergence_avg = f"{filename_base}-AvgConvergences.csv"
                    file_best_solutions = f"{filename_base}-BestSolutions.csv"
                    file_feature_importance = f"{filename_base}-FeatureImportance.csv"
                    file_excel_stats = f"{filename_base}-StatisticalAnalysis.xlsx"

                    tf_fold_results_list = []  # Store results for all algos/folds for this TF and classifier

                    # Loop through selected algorithms
                    for algo_name, algo_class in SELECTED_ALGORITHMS.items():
                        kf = KFold(n_splits=FOLDS, shuffle=True,
                                   random_state=exp_run * 42 + ALGORITHM_NAMES.index(algo_name))

                        # Parallel execution over folds
                        fold_results = Parallel(n_jobs=-1)(
                            delayed(run_fold_optimization)(
                                transfer_func, fold_idx, train_idx, test_idx, X_full, y_full,
                                algo_class, algo_name, classifier, classifier_name, ALPHA,
                                POP_SIZE, MAX_ITER, dataset_name
                            )
                            for fold_idx, (train_idx, test_idx) in enumerate(kf.split(X_full))
                        )
                        tf_fold_results_list.extend(fold_results)

                    # Process and save results for this TF within this classifier
                    if not tf_fold_results_list:
                        print(f"No results generated for {classifier_name} with {tf_name}. Skipping saving.")
                        continue

                    tf_results_df = pd.DataFrame(tf_fold_results_list)
                    run_results_df_all_tfs.append(tf_results_df)  # Append this TF's results for this classifier
                    run_results_df_all.append(tf_results_df)  # Append to overall run results

                    # Save individual TF results for this classifier
                    save_fold_results_to_csv(tf_results_df, file_all_folds)
                    save_best_solutions_to_csv(tf_results_df, file_best_solutions)
                    save_convergence_to_csv(tf_fold_results_list, MAX_ITER, file_convergence_all)
                    save_summary_stats_to_csv(tf_results_df, file_summary)
                    save_avg_convergence_to_csv(file_convergence_all, file_convergence_avg)
                    save_feature_importance_to_csv(tf_results_df, FOLDS, file_feature_importance)

                    # Statistical analysis for this TF and classifier
                    with pd.ExcelWriter(file_excel_stats, engine='openpyxl') as writer:
                        metrics_to_analyze = ['Accuracy', 'NumFeatures', 'BestFitness', 'F1', 'Time']
                        for metric in metrics_to_analyze:
                            perform_statistical_analysis_fs(tf_results_df, ALGORITHM_NAMES, metric, writer)

                    # Generate boxplots for this TF and classifier
                    for metric in metrics_to_analyze:
                        if metric != 'BestFitness':
                            plot_fs_boxplots(tf_results_df, metric, ALGORITHM_NAMES, tf_results_dir,
                                             f"{dataset_name}_{classifier_name}_{tf_name}")

                # Create an aggregated results directory for all TFs within this classifier
                if run_results_df_all_tfs:
                    classifier_results_df = pd.concat(run_results_df_all_tfs, ignore_index=True)

                    # Save aggregated results for this classifier (across all TFs)
                    classifier_agg_dir = os.path.join(classifier_dir, "all_tfs")
                    os.makedirs(classifier_agg_dir, exist_ok=True)

                    # Define filenames for aggregated classifier results
                    agg_filename_base = os.path.join(classifier_agg_dir,
                                                     f"{classifier_name}-AllTFs-ExpRun{exp_run + 1}")
                    agg_file_summary = f"{agg_filename_base}-Summary.csv"
                    agg_file_excel_stats = f"{agg_filename_base}-StatisticalAnalysis.xlsx"

                    # Calculate summary stats for this classifier (across all TFs)
                    metrics_to_agg = {
                        'BestFitness': ['mean', 'std'], 'Accuracy': ['mean', 'std'], 'Error': ['mean', 'std'],
                        'Sensitivity': ['mean', 'std'], 'Specificity': ['mean', 'std'], 'Precision': ['mean', 'std'],
                        'MCC': ['mean', 'std'], 'F1': ['mean', 'std'], 'NumFeatures': ['mean', 'std'],
                        'Time': ['mean', 'std']
                    }

                    # Group by both Algorithm and TransferFunction
                    classifier_agg_stats = classifier_results_df.groupby(['Algorithm', 'TransferFunction']).agg(
                        metrics_to_agg)
                    classifier_agg_stats.columns = ['_'.join(col).strip() for col in
                                                    classifier_agg_stats.columns.values]
                    classifier_agg_stats = classifier_agg_stats.reset_index()
                    classifier_agg_stats.to_csv(agg_file_summary, index=False, float_format='%.6f')

                    with pd.ExcelWriter(agg_file_excel_stats, engine='openpyxl') as writer:
                        for tf_name in classifier_results_df['TransferFunction'].unique():
                            tf_df = classifier_results_df[classifier_results_df['TransferFunction'] == tf_name]
                            # Create a sheet for each transfer function
                            for metric in metrics_to_analyze:
                                perform_statistical_analysis_fs(tf_df, ALGORITHM_NAMES, metric, writer)

            # --- Combine all results for this run (across all classifiers and TFs) ---
            if run_results_df_all:
                run_results_df = pd.concat(run_results_df_all, ignore_index=True)
                dataset_results.append(run_results_df)

                # Create directory for aggregated results across all classifiers for this run
                all_classifiers_dir = os.path.join(run_main_dir, "all_classifiers")
                os.makedirs(all_classifiers_dir, exist_ok=True)

                # Save aggregated results for all classifiers in this run
                all_clf_filename_base = os.path.join(all_classifiers_dir, f"AllClassifiers-ExpRun{exp_run + 1}")
                all_clf_file_summary = f"{all_clf_filename_base}-Summary.csv"
                all_clf_file_excel_stats = f"{all_clf_filename_base}-StatisticalAnalysis.xlsx"

                # Calculate summary stats across all classifiers and TFs
                all_clf_agg_stats = run_results_df.groupby(['Algorithm', 'Classifier', 'TransferFunction']).agg(
                    metrics_to_agg)
                all_clf_agg_stats.columns = ['_'.join(col).strip() for col in all_clf_agg_stats.columns.values]
                all_clf_agg_stats = all_clf_agg_stats.reset_index()
                all_clf_agg_stats.to_csv(all_clf_file_summary, index=False, float_format='%.6f')

                # Statistical analysis comparing classifiers
                with pd.ExcelWriter(all_clf_file_excel_stats, engine='openpyxl') as writer:
                    for metric in metrics_to_analyze:
                        # Compare classifiers for each algorithm/tf combination
                        classifier_stats_df = run_results_df.pivot_table(
                            values=metric,
                            index=['Algorithm', 'TransferFunction'],
                            columns='Classifier',
                            aggfunc='mean'
                        )
                        classifier_stats_df.to_excel(writer, sheet_name=f"Compare_Clf_{metric}")

            run_end_time = time.time()
            print(
                f"--- Experiment Run {exp_run + 1}/{EXP_NUM} finished in {run_end_time - run_start_time:.2f} seconds ---")

        # --- Aggregate results ACROSS ALL RUNS for the current dataset ---
        if dataset_results:
            print(f"\n--- Aggregating results across {EXP_NUM} runs for {dataset_name} ---")
            # Concatenate results from all runs
            all_runs_df = pd.concat(dataset_results, ignore_index=True)

            # Setup main directory for aggregated results
            agg_dir_name = f"{timestamp}-Aggregated-{EXP_NUM}Runs-{dataset_name}"
            agg_main_dir = setup_fs_results_dir(agg_dir_name)
            print(f"Main aggregated results directory: {agg_main_dir}")

            # First, aggregate by classifier
            for classifier_name in all_runs_df['Classifier'].unique():
                classifier_df = all_runs_df[all_runs_df['Classifier'] == classifier_name]

                # Create classifier directory
                classifier_agg_dir = os.path.join(agg_main_dir, classifier_name)
                os.makedirs(classifier_agg_dir, exist_ok=True)

                # Group by transfer function within this classifier
                for tf_name in classifier_df['TransferFunction'].unique():
                    tf_df = classifier_df[classifier_df['TransferFunction'] == tf_name]

                    # Create subdirectory for this transfer function
                    tf_agg_dir = os.path.join(classifier_agg_dir, tf_name)
                    os.makedirs(tf_agg_dir, exist_ok=True)
                    print(f"Aggregated results for {classifier_name} with {tf_name} will be saved in: {tf_agg_dir}")

                    # Define filenames for this TF and classifier
                    agg_filename_base = os.path.join(tf_agg_dir,
                                                     f"{classifier_name}-{dataset_name}-{tf_name}-Aggregated")
                    agg_file_summary = f"{agg_filename_base}-Summary.csv"
                    agg_file_excel_stats = f"{agg_filename_base}-StatisticalAnalysis.xlsx"

                    # Calculate summary stats for this TF and classifier
                    metrics_to_agg = {
                        'BestFitness': ['mean', 'std'], 'Accuracy': ['mean', 'std'], 'Error': ['mean', 'std'],
                        'Sensitivity': ['mean', 'std'], 'Specificity': ['mean', 'std'], 'Precision': ['mean', 'std'],
                        'MCC': ['mean', 'std'], 'F1': ['mean', 'std'], 'NumFeatures': ['mean', 'std'],
                        'Time': ['mean', 'std']
                    }
                    agg_summary_stats = tf_df.groupby('Algorithm').agg(metrics_to_agg)
                    agg_summary_stats.columns = ['_'.join(col).strip() for col in agg_summary_stats.columns.values]
                    agg_summary_stats = agg_summary_stats.reset_index()
                    agg_summary_stats.to_csv(agg_file_summary, index=False, float_format='%.6f')
                    print(
                        f"Aggregated summary statistics for {classifier_name} with {tf_name} saved to: {agg_file_summary}")

                    # Perform statistical analysis for this TF and classifier
                    with pd.ExcelWriter(agg_file_excel_stats, engine='openpyxl') as writer:
                        metrics_to_analyze = ['Accuracy', 'NumFeatures', 'BestFitness', 'F1', 'Time']
                        for metric in metrics_to_analyze:
                            perform_statistical_analysis_fs(tf_df, ALGORITHM_NAMES, metric, writer)
                    print(
                        f"Aggregated statistical analysis for {classifier_name} with {tf_name} saved to: {agg_file_excel_stats}")

                    # Generate boxplots for this TF and classifier
                    for metric in metrics_to_analyze:
                        if metric != 'BestFitness':
                            plot_fs_boxplots(tf_df, metric, ALGORITHM_NAMES, tf_agg_dir,
                                             f"{dataset_name}_{classifier_name}_{tf_name}_Aggregated")

                # Also save overall aggregation for this classifier (across all TFs)
                classifier_overall_dir = os.path.join(classifier_agg_dir, "overall")
                os.makedirs(classifier_overall_dir, exist_ok=True)
                classifier_overall_base = os.path.join(classifier_overall_dir,
                                                       f"{classifier_name}-{dataset_name}-Overall")
                classifier_overall_summary = f"{classifier_overall_base}-Summary.csv"

                # Group by Algorithm and TransferFunction for this classifier
                classifier_overall_stats = classifier_df.groupby(['Algorithm', 'TransferFunction']).agg(metrics_to_agg)
                classifier_overall_stats.columns = ['_'.join(col).strip() for col in
                                                    classifier_overall_stats.columns.values]
                classifier_overall_stats = classifier_overall_stats.reset_index()
                classifier_overall_stats.to_csv(classifier_overall_summary, index=False, float_format='%.6f')

            # Finally, create overall comparison across all classifiers
            overall_dir = os.path.join(agg_main_dir, "overall_comparison")
            os.makedirs(overall_dir, exist_ok=True)

            # Define filenames for overall comparison
            overall_filename_base = os.path.join(overall_dir, f"{dataset_name}-AllClassifiers-AllTFs-Comparison")
            overall_file_summary = f"{overall_filename_base}-Summary.csv"
            overall_file_excel_stats = f"{overall_filename_base}-StatisticalAnalysis.xlsx"

            # Create a comprehensive summary comparing all classifiers and algorithms
            overall_summary_stats = all_runs_df.groupby(['Algorithm', 'Classifier', 'TransferFunction']).agg(
                metrics_to_agg)
            overall_summary_stats.columns = ['_'.join(col).strip() for col in overall_summary_stats.columns.values]
            overall_summary_stats = overall_summary_stats.reset_index()
            overall_summary_stats.to_csv(overall_file_summary, index=False, float_format='%.6f')

            # Generate comparison tables and statistical analyses
            with pd.ExcelWriter(overall_file_excel_stats, engine='openpyxl') as writer:
                metrics_to_analyze = ['Accuracy', 'NumFeatures', 'BestFitness', 'F1', 'Time']

                # For each metric, compare classifiers and algorithms
                for metric in metrics_to_analyze:
                    # Create a pivot table comparing classifiers across algorithms
                    pivot_df = all_runs_df.pivot_table(
                        values=metric,
                        index=['Algorithm', 'TransferFunction'],
                        columns='Classifier',
                        aggfunc='mean'
                    )
                    pivot_df.to_excel(writer, sheet_name=f"Compare_{metric}")

                    # Add standard deviations
                    pivot_std_df = all_runs_df.pivot_table(
                        values=metric,
                        index=['Algorithm', 'TransferFunction'],
                        columns='Classifier',
                        aggfunc='std'
                    )
                    pivot_std_df.to_excel(writer, sheet_name=f"StdDev_{metric}")

        print(f"===== Finished Dataset: {dataset_name} =====")

        overall_end_time = time.time()
        print(f"\n>>>> All fs_datasets completed in {(overall_end_time - overall_start_time) / 60:.2f} minutes <<<<")