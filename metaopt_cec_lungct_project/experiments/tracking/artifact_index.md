# Artifact Index

说明：本文件登记“任务-资产”绑定关系。若资产缺失，必须登记“未发现，需用户确认”。

| 资产类型 | 名称 | 路径 | 对应任务 | 是否已验证 | 备注 |
| -------- | ---- | ---- | -------- | ---------- | ---- |
| code | V3 ablation core | src/improved/algorithms/BBO/BBO_improved_v3_ablation_core.m | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 本轮关键算法实现 |
| code | Reduced runner | src/benchmark/cec_runner/pipelines/run_v3_direction_reduced_ablation.m | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | smoke/formal_screen统一入口 |
| code | Benchmark backend | src/benchmark/cec_runner/core/run_all_compare.m | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 统一评测后端 |
| result | Formal summary | results/benchmark/v3_direction_reduced_formal/20260315_142313/summary.csv | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 函数级统计原始依据 |
| table | Ranking summary | results/benchmark/v3_direction_reduced_formal/20260315_142313/ranking_summary.csv | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | reduced formal_screen 排名依据 |
| table | Per-function mean/std | results/benchmark/v3_direction_reduced_formal/20260315_142313/per_function_mean_std.csv | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 各函数均值与方差 |
| doc | Formal auto analysis | results/benchmark/v3_direction_reduced_formal/20260315_142313/analysis_20260315_142313.md | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 6个问题自动结论 |
| doc | Formal report | results/benchmark/v3_direction_reduced_formal/20260315_142313/report_20260315_142313.md | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 批次概览 |
| log | Formal run log | results/benchmark/v3_direction_reduced_formal/20260315_142313/run_log_20260315_142313.txt | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 运行日志 |
| config | Formal config snapshot | results/benchmark/v3_direction_reduced_formal/20260315_142313/config_snapshot_20260315_142313.mat | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 配置快照 |
| result | Smoke summary | results/benchmark/v3_direction_reduced_smoke/20260315_142313/summary.csv | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 连通性验证结果 |
| figure | Formal figure directory | results/benchmark/v3_direction_reduced_formal/20260315_142313/figures/ | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 含 convergence/boxplot/ranking等 |
| doc | 改进点语法详解文档 | docs/02_method_design/improved/V3_DIR_SMALL_STEP_reduced_改进点与语法详解.md | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 可直接服务论文附录 |
| archive | V3 formal结果压缩包 | 未发现，需用户确认 | V3 消融实验：双目标消融 + directional 保守方向验证 | no | 若需归档请补充zip路径 |
| archive | directional相关历史压缩包 | 未发现，需用户确认 | V3 消融实验：双目标消融 + directional 保守方向验证 | no | 待用户确认历史包命名 |
| archive | 未用V3版本归档目录 | archive/achieve/unused_versions/ | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 2026-03-15 已将7个非主线V3 wrapper迁入 |
| archive | cec2017无README结果归档目录 | archive/achieve/results_cec2017_no_readme/ | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 2026-03-15 已将29个无README批次迁入 |
| code | 阶段收口脚本 | experiments/scripts/run_benchmark/finalize_stage_and_archive.m | 阶段收口机制：定型冻结 + 过程归档 achieve | yes | 统一执行 stable 冻结与 process 迁移并自动落盘清单 |
| archive | 阶段收口烟测冻结目录 | archive/achieve/stage_freeze/stage_freeze_smoke_20260317_20260317_223739/ | 阶段收口机制：定型冻结 + 过程归档 achieve | yes | 包含 stage_manifest.csv、stage_manifest.mat、stage_report.md |
| code | Route A 原型 | src/improved/algorithms/BBO/BBO_route_a_sel_gdp_reference.m | 多路线最小原型统一 smoke 框架 | yes | SEL+GDP 参考线，ESC 关闭 |
| code | Route B 原型 | src/improved/algorithms/BBO/BBO_route_b_state_driven_bbo.m | 多路线最小原型统一 smoke 框架 | yes | 三态状态驱动 GDP |
| code | Route C 原型 | src/improved/algorithms/BBO/BBO_route_c_dimension_selective_bbo.m | 多路线最小原型统一 smoke 框架 | yes | 固定比例维度选择 SEL |
| code | Route D 原型 | src/improved/algorithms/BBO/BBO_route_d_multi_elite_reference_bbo.m | 多路线最小原型统一 smoke 框架 | yes | top-k 多精英参考 GDP |
| code | 统一 smoke 入口 | experiments/scripts/run_benchmark/run_bbo_prototype_routes_smoke.m | 多路线最小原型统一 smoke 框架 | yes | 统一配置、统一汇总、统一候选推荐 |
| result | Prototype smoke 结果目录 | results/benchmark/research_pipeline/cec2017/prototype_routes_smoke_20260317/ | 多路线最小原型统一 smoke 框架 | yes | 包含 logs/raw_runs/summary/curves 与 compare/recommendation |
| table | Prototype compare 表 | results/benchmark/research_pipeline/cec2017/prototype_routes_smoke_20260317/prototype_routes_compare.csv | 多路线最小原型统一 smoke 框架 | yes | 统一比较 mean/std/runtime/win_count |
| table | Prototype round2 推荐 | results/benchmark/research_pipeline/cec2017/prototype_routes_smoke_20260317/prototype_routes_round2_recommendation.csv | 多路线最小原型统一 smoke 框架 | yes | 当前候选 ROUTE_A 与 ROUTE_D |
| code | 改进算法说明导出器 | src/benchmark/cec_runner/export/export_improved_algorithm_notes_md.m | 每次结果自动导出改进算法说明文档 | yes | 每个 suite 结果目录自动生成 improved_algorithm_notes.md |
| doc | 改进算法说明示例产物 | results/benchmark/research_pipeline/cec2017/prototype_routes_smoke_20260318_notes/improved_algorithm_notes.md | 每次结果自动导出改进算法说明文档 | yes | 含 route_a/route_b/route_c/route_d 的详细改进点解释 |
| code | V3 dir stagnation only wrapper | src/improved/algorithms/BBO/BBO_v3_dir_stag_only.m | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 新增候选版本 V3_DIR_STAG_ONLY |
| code | V3 dir stagnation bottom-half wrapper | src/improved/algorithms/BBO/BBO_v3_dir_stag_bottom_half.m | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 新增候选版本 V3_DIR_STAG_BOTTOM_HALF |
| code | V3 dir stagnation bottom-half + refine wrapper | src/improved/algorithms/BBO/BBO_v3_dir_stag_bottom_half_late_refine.m | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 新增候选版本 V3_DIR_STAG_BOTTOM_HALF_LATE_REFINE |
| code | V3 clipped dir stagnation bottom-half + refine wrapper | src/improved/algorithms/BBO/BBO_v3_dir_clipped_stag_bottom_half_late_refine.m | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 可选候选版本 V3_DIR_CLIPPED_STAG_BOTTOM_HALF_LATE_REFINE |
| code | V3 ablation core (stag/bottom-half/clipped update) | src/improved/algorithms/BBO/BBO_improved_v3_ablation_core.m | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 完成任务A/B/C/D参数化实现 |
| code | Reduced runner defaults (new candidate set) | src/benchmark/cec_runner/pipelines/run_v3_direction_reduced_ablation.m | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 默认算法切换为 stag 系列并支持 include_clipped_variant |
| code | Algorithm catalog registration for new variants | src/benchmark/cec_runner/core/run_all_compare.m | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 新增4个算法别名注册 |
| result | Formal summary (20260315_175032) | results/benchmark/v3_direction_reduced_formal/20260315_175032/summary.csv | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 本轮formal原始统计 |
| table | Ranking summary (20260315_175032) | results/benchmark/v3_direction_reduced_formal/20260315_175032/ranking_summary.csv | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | best=V3_DIR_STAG_BOTTOM_HALF |
| doc | Formal analysis (20260315_175032) | results/benchmark/v3_direction_reduced_formal/20260315_175032/analysis_20260315_175032.md | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | simple未修复、complex保留、recommend_full_formal=0 |
| doc | Formal report (20260315_175032) | results/benchmark/v3_direction_reduced_formal/20260315_175032/report_20260315_175032.md | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | smoke pass=1 |
| result | Smoke summary (20260315_175032) | results/benchmark/v3_direction_reduced_smoke/20260315_175032/summary.csv | V3 消融实验：双目标消融 + directional 保守方向验证 | yes | 连通性通过 |
