# benchmark/metrics

This directory is the single home for metric computation logic.

Current modules:

- metrics_build_aggregate_table.m
- metrics_build_rank_table.m
- metrics_build_wilcoxon_rank_sum_table.m
- metrics_build_friedman_tables.m
- metrics_average_tie_ranks.m
- metrics_extract_scores.m

Usage:

- Export layer should call metrics functions.
- Do not duplicate metric formulas inside export/reporting scripts.
