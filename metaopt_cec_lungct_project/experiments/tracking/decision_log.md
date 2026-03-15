# Decision Log

说明：记录“保留/放弃方向”的决策证据链，仅追加，不删除历史。

| 日期 | 决策主题 | 结论 | 依据 | 影响范围 | 后续动作 |
| ---- | -------- | ---- | ---- | -------- | -------- |
| 2026-03-15 | v3_vs_v4_mainline_choice | 继续以 v3 作为当前研究主线，v4 不作为当前主推主线 | 事实：results/benchmark/v3_direction_reduced_formal/20260315_142313/analysis_20260315_142313.md 中 best_version 为 V3_DIR_SMALL_STEP_LATE_LOCAL_REFINE，且 recommend_full_formal=0，表明仍在筛选阶段而非主线切换阶段 | 主线算法管理、后续 formal 投入优先级 | 维持 v3 主线，进行阈值级保守修复后再评估是否 full formal |
| 2026-03-15 | directional_module_keep_or_drop | directional 不删除，但应保守触发，不作为全程强注入 | 事实：analysis_20260315_142313.md 显示 complex 子集优势保留，但 gate+late_local_refine 未体现更稳；simple 子集仍未修复 | ablation 设计、模块触发策略 | 下一轮优先调 gate 与 local_refine 触发阈值，不扩机制数量 |
| 2026-03-15 | simple_function_convergence_fix | 下一轮优先修复 simple-function 收敛问题 | 事实：ranking_summary.csv 中 simple_mean_delta 均为负；analysis_20260315_142313.md 明确 F1/F2/F3 未修复 | 参数敏感性与后期收敛模块 | 先做最小闭环（smoke + reduced formal_screen）验证 simple 子集是否由负转正 |
| 2026-03-15 | formal_entry_decision | 暂不建议进入 full formal | 事实：report_20260315_142313.md 中 Recommend Full Formal = 0；analysis 给出 risk remains high | 资源投入与实验排期 | 完成一轮阈值修复后再做 formal_entry 决策复核 |
| 2026-03-15 | archive_cleanup_unused_versions | 活动区仅保留V3主线4个wrapper，其余V3封装与无README结果批次统一迁入achieve归档 | 事实：已迁移至 archive/achieve/unused_versions/（7文件）与 archive/achieve/results_cec2017_no_readme/（29目录）；当前活动区保留 baseline/dir_small_step/late_local_refine/gate_late_local_refine | 代码目录整洁度、结果可追溯性、后续批次管理 | 后续新增批次需强制补README；若无README先入归档区再决定是否回迁 |
| 2026-03-15 | directional_stagnation_trigger_policy | directional 改为“停滞触发优先”，不再默认全局概率触发用于新主线候选 | 事实：在 BBO_improved_v3_ablation_core 中新增 tau_dir 与 use_stag_trigger_only，并在新模式启用 | simple 保护、complex 收益保持、可解释性 | 以 reduced formal 评估 simple 子集退化是否显著收敛 |
| 2026-03-15 | simple_protection_bottom_half_policy | directional 注入限定到后50%个体，top half 保持 baseline 主驱动 | 事实：新模式启用 direction_bottom_half_only，仅从 bottom-half 选择替换目标 | simple function 开发能力保护、扰动范围可控 | 对比 V3_DIR_STAG_ONLY 与 V3_DIR_STAG_BOTTOM_HALF 的 simple/complex delta |
| 2026-03-15 | clipped_direction_step_policy | directional 步长改为参数化 clipped 形式，受 pop_std 与搜索区间双上限约束 | 事实：新增 alpha_dir、dir_cap_std_ratio、dir_cap_range_ratio、near_best_shrink 参数与实现 | 稳定性、可回退性、后续 sensitivity 可做 | 先跑默认候选，必要时只调 alpha_dir 与 cap 比例 |
| 2026-03-15 | late_refine_state_trigger_policy | late_local_refine 改为状态触发，不再常开 | 事实：新增 tau_refine、refine_elite_spread_threshold、可选 gap gate，并在新模式启用 | 避免过早局部收缩、提高 simple 保护 | 在 reduced formal 中核验 std_delta_mean 与 simple_mean_delta 是否改善 |
| 2026-03-15 | run_20260315_175032_outcome | 本轮 smoke+formal 已完成，但仍不建议进入 full formal | 事实：SMOKE_PASS=1；ranking_summary 显示 best_version=V3_DIR_STAG_BOTTOM_HALF；analysis 显示 simple_mean_delta 仍为负、complex_mean_delta 为正、recommend_full_formal=0 | 主线推进节奏、参数敏感性优先级 | 下一轮优先调 simple 保护参数（tau_dir/alpha_dir/cap/tau_refine），维持协议不变继续 reduced formal |
