# README_ablation_flow

## Ablation 流程

- pipelines/run_v3_direction_reduced_ablation.m
- pipelines/run_v3_dual_objective_ablation.m

二者默认通过 pipeline_common/run_phase_via_core.m 进入 core/run_experiment。
run_phase_via_unified.m 仅保留兼容 shim，不再作为默认主路径。

## pipeline_common 作用

- fill_common_stage_cfg.m：公共实验字段默认值
- build_smoke_cfg.m / build_formal_cfg.m：阶段配置壳
- write_stage_scan.m：扫描快照保存
- save_stage_report.m：报告统一保存

## 扩展建议

新增阶段脚本时，只保留：

1. 阶段特有配置
2. 阶段特有分析逻辑
3. 阶段特有推荐逻辑

其余流程壳应优先复用 pipeline_common。
