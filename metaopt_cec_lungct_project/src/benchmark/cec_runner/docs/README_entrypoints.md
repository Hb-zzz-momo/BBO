# README_entrypoints

## 单一入口规则

- 给人用：entry/run_main_entry.m
- 给阶段跑批：pipelines/run_bbo_research_pipeline.m、pipelines/run_v3_direction_reduced_ablation.m、pipelines/run_v3_dual_objective_ablation.m、pipelines/run_compare_sbo_bbo.m
- 给系统内部：core/run_experiment.m、core/run_suite_batch.m、core/rac_run_benchmark_kernel.m
- 给历史兼容：legacy/run_experiment_unified.m、legacy/run_compare_sbo_bbo.m

默认规则：pipeline 通过 run_phase_via_core -> core/run_experiment 执行；legacy 入口仅兼容保留。

## 最小运行示例

```matlab
cfg = struct();
cfg.mode = 'smoke';
report = run_main_entry(cfg);
```

## 阶段脚本入口

- experiments/scripts/run_benchmark/run_benchmark.m
- experiments/scripts/run_benchmark/run_smoke_selfcheck.m
- experiments/scripts/run_ablation/run_ablation.m
