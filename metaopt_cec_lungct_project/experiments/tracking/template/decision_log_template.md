### 决策日志（建议放到 `experiments/tracking/decision_log.md`）

| 日期 | 决策主题 | 结论 | 依据 | 影响范围 | 后续动作 |
|---|---|---|---|---|---|
| 2026-03-15 | v3_vs_v4_mainline_choice | 暂时继续 V3 主线，不以 V4 为主线推进 | 多轮结果讨论中，V3 主线整体更稳，V4 directional 路线未形成足够主线优势 | 改进算法主线、消融实验设计、formal 投入优先级 | 围绕 V3 继续做保守增量改进 |
| 2026-03-15 | directional_module_keep_or_drop | 不完全删除 directional 思路，但改为保守触发候选模块 | 当前讨论倾向：directional 不是全程主驱动，适合停滞或特定阶段触发 | V3 改进代码结构、消融矩阵设计 | 做缩减版 smoke + formal 判定 |
| 2026-03-15 | simple_function_convergence_fix | 下一轮改进重点转向简单函数收敛增强 | 当前主要短板已从“复杂引导不足”转为“简单函数后期精修不足” | v3 下一轮模块选择 | 优先选择轻量 exploitation 增强模块 |

