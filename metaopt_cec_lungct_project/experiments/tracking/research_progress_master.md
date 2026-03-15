# Research Progress Master

说明：本文件为持续增量台账。仅追加/更新任务状态，不删除历史记录。

| 进度ID | 阶段 | 任务名称 | 当前状态 | 目标 | 当前结论 | 下一步 | 更新时间 |
| ------ | ---- | -------- | -------- | ---- | -------- | ------ | -------- |
| P-20260315-001 | ablation | V3 消融实验：双目标消融 + directional 保守方向验证 | analyzing | 在不破坏复杂函数表现前提下，提升简单函数收敛；验证 directional 是否应保守触发；判断 v3 是否继续主线 | 已完成并实跑 smoke+formal（20260315_175032）。结论：SMOKE_PASS=1；best_version=V3_DIR_STAG_BOTTOM_HALF；simple_mean_delta 仍为负，complex_mean_delta 为正；recommend_full_formal=0。 | 下一轮优先调 simple 保护相关参数（tau_dir/alpha_dir/cap/tau_refine），保持协议不变再跑 reduced formal。 | 2026-03-15 17:50:32 |

## 任务详情（当前主线）

- 任务归属：ablation / benchmark / paper_support
- 主线版本：V3_BASELINE, V3_DIR_STAG_ONLY, V3_DIR_STAG_BOTTOM_HALF, V3_DIR_STAG_BOTTOM_HALF_LATE_REFINE, V3_DIR_CLIPPED_STAG_BOTTOM_HALF_LATE_REFINE
- reduced subset：F1,F2,F3,F12,F13,F14,F15,F18,F19
- 事实证据源：results/benchmark/v3_direction_reduced_formal/20260315_142313/
- 当前是否可用于论文写作：部分可用（方法与阶段性结论可写；最终优劣结论待 full formal）

## 追加规则

- 新任务新增一行，不覆盖旧行。
- 同任务新进展以同一进度ID更新“当前状态/当前结论/下一步/更新时间”，并在下方追加变更记录。

## 变更记录

- 2026-03-15：完成“simple 保护 + 状态触发”代码就绪版，未改 benchmark 协议；已接入统一入口 run_all_compare 与 reduced formal runner 默认算法集。
- 2026-03-15：完成一轮 smoke + formal 实跑（timestamp=20260315_175032），并写入 ranking/report/analysis 证据链。
