# 下次检错工作流（input_data 告警与 formal 门禁）

## 1. 任务理解
本工作流用于复现与排查以下两类问题，并保证后续批次可复现、可审计：
- 运行期出现 input_data 相关告警（如 Cannot open M_1_D10.txt / shift_data_1.txt）。
- formal 批次在数值层面出现异常（Inf、极端异常值、跨算法异常一致）。

## 2. 所属科研流程位置
文献分析 -> 基线与改进实现 -> CEC 基准测试（本流程位置） -> 消融与敏感性 -> 论文支撑导出。

## 3. 适用范围与边界
- 适用 suite：cec2017、cec2022。
- 适用模式：smoke（定位）、formal（结论批次前校验）。
- 不改 benchmark 协议字段：suite、func_ids、dim、pop_size、maxFEs、runs、stop criteria。

## 4. 标准排查流程（必须按顺序）

### Step A：先做 focused smoke（不改协议）
目的：先判断“告警是否影响当前批次有效性”，避免盲目进入 formal。

操作要点：
- 固定协议参数，仅聚焦函数集合（建议 F6/F7/F8/F10/F11/F12）。
- 先确认结果产物是否齐全，再看告警文本是否实际命中本批次日志。

判定标准：
- run_manifest 中 used_FEs 达预算且 failed=0。
- summary、run_manifest、protocol_snapshot、exact_match_warnings 存在。
- 若日志有告警文本但数值正常，先标记为“非致命待跟踪”，不可直接当作致命故障。

### Step B：做 cec2017 单函数 A/B 专项复核（告警出现 vs 消除）
目的：验证告警是否会造成可观测数值漂移。

操作要点：
- 只改运行目录诊断开关，其他协议参数保持一致。
- 使用同一函数、同一预算、同一 runs 做 warn_on 与 warn_off 成对对照。
- 输出逐函数漂移表（至少包含 best、mean、std 对照）。

判定标准：
- 若 warn_on 出现 Inf 或极端异常值，而 warn_off 恢复有限值，判定“告警对数值有效性有实质影响”。
- 若两者稳定一致，则判定“告警当前为信息性噪声”。

### Step C：formal 前置门禁（必须）
目的：阻断无效 formal 批次，防止污染结论。

门禁要求（formal 强制）：
- runtime_dir 必须解析到 mex 目录。
- input_data 目录必须存在且非空。
- 关键文件必须可读：M_1_D<dim>.txt、shift_data_1.txt。
- 任一失败直接 fail-fast，禁止继续 formal 运行。

### Step D：结果有效性与公平性复核
目的：在可复现前提下确认可比性未被破坏。

检查项：
- used_FEs、budget、stop criteria 未变。
- curves 行数与 used_FEs 一致（抽检至少 3 个算法）。
- exact_match_warnings 文件存在（可为空，不可缺失）。
- run_log 时序完整，无提前 Finished、无交错。

### Step E：台账同步（完成定义的一部分）
必须同步：
- experiments/tracking/decision_log.md
- experiments/tracking/research_progress_master.md
- experiments/tracking/research_progress_master.csv

未完成台账同步，不得标记为完成。

## 5. 最小证据包清单（提交结论前）
- 结果目录：results/<suite>/<experiment_name_or_timestamp>/
- 必备文件：
  - config.mat
  - summary.csv
  - summary.mat
  - run_manifest.csv
  - protocol_snapshot.csv
  - protocol_snapshot.mat
  - exact_match_warnings.csv
  - rescue_evidence.csv
  - rescue_evidence_summary.csv
  - rescue_trigger_events.csv
  - experiment_summary.md
  - improved_algorithm_notes.md

## 6. 常见结论模板（直接复用）
- 工程治理结论：
  - 本次改动属于工程治理与可复现性增强，不是算法创新。
  - benchmark 协议字段未改（suite/func_ids/dim/pop/maxFEs/runs/stop）。
- 风险结论：
  - 若 A/B 对照显示 warn_on 存在 Inf 或极端异常，则该批次不可用于方法优劣结论。

## 7. 下一次执行建议
- 先运行 Step A focused smoke。
- 若发现风险信号，再进入 Step B 的 cec2017 单函数 A/B 复核。
- 进入 formal 前必须通过 Step C 门禁。
- 最后按 Step D、Step E 完成证据与台账闭环。
