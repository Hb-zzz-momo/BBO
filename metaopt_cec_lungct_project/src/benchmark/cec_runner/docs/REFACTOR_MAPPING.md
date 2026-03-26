# Benchmark Runner 重构映射（大胆但受控）

## 1. 当前问题分析（仅结构，不改算法）

- 入口分散：多个 run_*.m 都直接调用 run_all_compare，导致模式配置与导出策略重复。
- 配置分散：smoke/formal 的字段拼装在多个脚本内重复实现，后续协议变更容易漏改。
- 导出分散：聚合导出由统一入口负责，但部分 pipeline 仍绕开统一入口，产物风格不一致。
- 兼容风险：run_all_compare 体量大且承载 CEC 调用链，任何深改都可能影响公平性与历史可比性。

## 2. 受控重构目标

- 不修改 run_all_compare 核心执行语义。
- 收口入口：上层 pipeline 默认走 core/run_experiment。
- 保留兼容开关：每个 pipeline 增加 use_unified_entry，必要时可回退直调 run_all_compare。
- 保持结果目录语义：统一入口新增 explicit_experiment_name，避免重命名造成结果对比中断。
- 统一结果树协议：支持 result_group + result_layout=experiment_then_suite。

## 3. 旧 -> 新职责映射

| 旧文件 | 旧职责 | 新职责 | 兼容策略 |
| ---- | ---- | ---- | ---- |
| run_all_compare.m | 执行核心（算法调度、统计、保存、绘图） | 保持不变，继续作为唯一执行内核 | 不改内部逻辑 |
| run_experiment_unified.m | 统一入口（配置+模式+导出） | 退为 legacy 兼容入口，不再作为 pipeline 默认链 | additive 改造 |
| config/default_experiment_config.m | 默认配置填充 | 新增 explicit_experiment_name 默认字段 | additive 改造 |
| config/resolve_experiment_mode.m | 模式转 run_cfg | 支持 explicit_experiment_name 优先 | additive 改造 |
| run_bbo_research_pipeline.m | pipeline 协调 + 直调 run_all_compare | 默认改为 core/run_experiment 执行 phase | use_unified_entry 回退开关 |
| run_v3_direction_reduced_ablation.m | reduced ablation 协调 + 直调 run_all_compare | 默认改为 core/run_experiment 执行 smoke/formal | use_unified_entry 回退开关 |
| run_v3_dual_objective_ablation.m | dual-objective 协调 + 直调 run_all_compare | 默认改为 core/run_experiment 执行 smoke/formal | use_unified_entry 回退开关 |

## 3.1 本轮新增核心层（已落地）

| 新文件 | 职责 |
| ---- | ---- |
| core/run_experiment.m | 新统一主入口（标准化配置 -> 模式解析 -> 执行 -> 导出） |
| core/setup_benchmark_paths.m | 统一路径初始化与 addpath |
| core/normalize_config.m | 配置标准化入口（复用 default_experiment_config） |
| core/resolve_mode.m | 模式解析入口（复用 resolve_experiment_mode） |
| core/run_suite_batch.m | 执行层薄包装（复用 run_all_compare） |
| export/save_protocol_snapshot.m | 协议快照导出（MAT + CSV，字段兼容） |

## 3.2 阶段脚本层（已落地）

| 新文件 | 职责 |
| ---- | ---- |
| experiments/scripts/run_benchmark/run_benchmark.m | benchmark 阶段脚本入口 |
| experiments/scripts/run_benchmark/run_smoke_selfcheck.m | smoke 语义自检脚本 |
| experiments/scripts/run_ablation/run_ablation.m | ablation 阶段脚本入口（分发到 v3 两类 runner） |
| archive/achieve/unused_versions/20260315_simplify_cleanup/experiments_scripts/run_ct_app.m | ct_app 占位入口（已归档） |
| archive/achieve/unused_versions/20260315_simplify_cleanup/experiments_scripts/run_sensitivity.m | sensitivity 占位入口（已归档） |

## 3.3 新增路径安全与自检工具（已落地）

| 新文件 | 职责 |
| ---- | ---- |
| tools/check_path_collisions.m | 静态扫描 baselines 中高风险同名函数 |
| tools/selfcheck_runner_integrity.m | 入口、配置、结果协议与冲突扫描的一致性自检 |
| core/private/rac_validate_algorithm_path_resolution.m | 单算法路径激活后的运行时冲突告警 |
| core/private/rac_compute_result_root.m | 统一结果根目录计算策略 |

## 4. 变更边界说明

- 不改 CEC 调用链：wrapper/main -> Get_Functions_cec2017/2022 -> fobj -> optimizer -> cec17/22_func -> input_data。
- 不改协议核心参数口径：suite、func_ids、dim、pop_size、maxFEs、runs、seed。
- 不删除旧入口：所有 run_*.m 仍保留原函数名与主流程（run_experiment_unified 已变为兼容壳）。

## 5. 计划后的建议自检

- smoke/formal 下 output.suite_results 是否完整。
- 结果目录是否仍按旧 experiment_name 生成。
- protocol_snapshot 与 aggregate/wilcoxon/friedman 是否正常输出。
- use_unified_entry=false 时是否能回退到原行为。
- smoke 自检脚本是否可检查 summary/protocol 快照文件存在性。
