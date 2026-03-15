### 目标

你现在的思路是对的：

> **smoke（冒烟测试）只负责验证“流程能不能跑通、输出链路是否完整、版本是否不报错”，不再承担“筛选最优改进版”的职责。**
> **真正的版本优劣比较，统一放到 formal（正式实验）阶段完成。**

这比当前脚本更严谨，原因是：

- smoke 样本太少，容易误筛掉潜在有效版本
- BBO 改进效果可能只在某些复杂函数上体现
- 用极少函数做版本淘汰，容易把“复杂函数增强机制”误判成退化

------

### 先给你可直接发给 Codex 的提示词

下面这份你可以直接贴给 Codex。

```text
你现在要修改 MATLAB 科研脚本 `run_bbo_research_pipeline.m`。

## 一、任务目标

把当前 research pipeline 的策略从：

- smoke 阶段做版本优劣筛选
- 选出 best_variant
- formal 阶段只跑 baseline + best_variant + strong baselines

改为新的策略：

- smoke 阶段只做“流程连通性验证（can run / no crash / output chain complete）”
- smoke 阶段不再依据少量函数对改进版本做优劣淘汰
- formal 阶段直接对所有改进版本进行正式统一评测
- 最终版本优劣判断统一基于 formal 结果完成，而不是 smoke 结果

## 二、必须遵守的修改原则

1. **最小侵入（minimal intrusion）**
   - 不改原始 BBO 文件
   - 不新增平行 benchmark backend
   - 继续复用 `run_all_compare.m` 作为唯一统一评测入口
   - 保留现有结果目录风格与落盘链路（raw / summary / logs / curves / markdown）

2. **保持现有协议字段不变**
   以下字段继续显式保留并透传：
   - suite / suites
   - func_ids
   - dim
   - pop_size
   - maxFEs
   - runs
   - rng_seed
   - result_root
   - experiment_name
   - save_curve / save_mat / save_csv
   - plot

3. **不要把 smoke 结果写成算法优劣结论**
   - smoke 只判断：
     - 是否成功执行
     - 是否生成 summary / raw / log / curve 等结果
     - 各算法是否存在报错/缺失输出
   - smoke 输出结论应是：
     - pass / fail
     - 哪些算法跑通
     - 哪些算法失败
     - 哪些套件/函数存在异常
   - 不允许再用 smoke 的少量函数结果决定“best_variant”

4. **formal 阶段直接跑全体版本**
   formal 阶段算法列表应为：
   - BBO_BASE
   - 全部改进版本：`cfg.variant_algorithms`
   - `cfg.strong_baselines`
   不再只跑 baseline + best_variant

5. **结果分析分层**
   - smoke 分析：只做运行状态分析
   - formal 分析：才做性能优劣分析

## 三、需要具体修改的功能点

### 1）修改 pipeline 主流程

当前流程大致是：
- scan
- smoke run
- evaluate_variants_from_output(smoke_output, ...)
- select_best_variant(...)
- formal only best_variant
- write_analysis_markdown(...)

请改成：
- scan
- smoke run
- smoke health check / smoke execution summary
- formal run on all variants if `cfg.run_formal == true`
- formal variant evaluation
- unified final report + markdown

### 2）删除/停用“smoke 选最好版本”逻辑

以下逻辑需要重构：
- `evaluate_variants_from_output(smoke_output, ...)`
- `select_best_variant(...)`

要求：
- 不删除函数也可以，但不能再用于 smoke 的版本筛选决策
- 如果保留，请改为 formal 阶段调用
- `report.best_variant` 不应由 smoke 决定
- 可以新增：
  - `report.smoke_status`
  - `report.smoke_health`
  - `report.formal_variant_scores`
  - `report.formal_variant_detail`
  - `report.final_recommendation`

### 3）新增 smoke 健康检查函数

请新增类似函数，例如：
- `evaluate_smoke_execution(output, expected_algorithms)`
或等价命名

它至少要检查：
- `output.suite_results` 是否存在
- 每个 suite 是否有 summary
- summary 中是否覆盖预期算法
- 是否存在空表
- 是否存在缺失算法结果
- 是否存在明显失败标记
- 是否生成了基础输出文件（如果当前 output 结构能拿到）

输出结构建议包括：
- smoke_pass (true/false)
- passed_algorithms
- failed_algorithms
- suite_status
- missing_algorithms
- notes / messages

### 4）修改 formal 配置构造逻辑

当前 `make_formal_cfg(cfg, best_variant)` 需要改成：

- 不再接收 `best_variant`
- formal 算法列表直接使用：
  - `{cfg.base_algorithm}, cfg.variant_algorithms, cfg.strong_baselines`

即 formal 要覆盖所有改进版，而不是只保留一个

### 5）formal 阶段才做版本评分

请将当前：
- `evaluate_variants_from_output(...)`
真正用于 formal 输出分析

要求：
- smoke 不做最终优劣结论
- 如果 `cfg.run_formal == true` 且 formal_output 有效：
  - 对全部 variant 相对 `cfg.base_algorithm` 做统计
  - 输出 formal_variant_scores
- 如果 formal 没跑：
  - 明确说明“暂无正式性能结论”

### 6）改写 markdown 报告内容

请重写 `write_analysis_markdown(...)`，结构改成：

#### 1. Repository scan
#### 2. Pipeline design decision
说明：
- smoke only for pipeline health check
- formal for actual algorithm comparison

#### 3. Smoke stage execution status
写：
- suites
- algorithms in smoke
- smoke pass/fail
- missing algorithms / failed algorithms / notes

#### 4. Formal stage result
- 是否执行
- formal algorithms
- 如果未执行：明确说明暂无正式结论
- 如果执行：输出各 variant 相对 baseline 的统计

#### 5. Recommendation / next action
- 如果 smoke fail：先修流程
- 如果 smoke pass 但 formal 未执行：进入正式实验
- 如果 formal 已执行：给出基于 formal 的建议

#### 6. Risks and assumptions
强调：
- smoke 不是最终性能依据
- final conclusion must come from formal stage

### 7）默认配置调整建议

请修改默认配置，体现新的研究策略：

- `smoke_runs` 可以保持 1
- `smoke_func_ids` 保持很小即可，例如：
  - cec2017: 1
  - cec2022: 1
  或者 1:2，但要明确只是跑通验证
- `run_formal` 默认建议设为 true 或保留可配，但注释要写清楚：
  - smoke only checks execution
  - formal is required for actual comparison

请把注释写清楚，避免后续误解 smoke 的用途。

## 四、输出要求

请直接完成以下工作：

1. 修改 `run_bbo_research_pipeline.m`
2. 保持 MATLAB 代码风格清晰、注释规范
3. 给出完整可运行版本，不要只给伪代码
4. 尽量少改动无关逻辑
5. 给出一段简短说明，列出你改了哪些函数、为什么这样改
6. 如果发现 `run_all_compare` 的返回结构不足以支持 smoke health check，请在不破坏主流程的前提下做最小兼容处理
7. 不要把失败结果静默忽略，要在 report 和 markdown 里显式记录

## 五、设计意图说明（必须理解后再改）

本次修改的核心研究意图是：

- smoke 阶段样本太少，只适合做“能否跑通”的技术性验证
- 改进算法可能在复杂函数上才体现优势，不能因为少量 smoke 函数退化就提前淘汰
- 版本选择应基于 formal 全协议结果，而不是 smoke 小样本
- 研究记录中必须明确区分：
  - pipeline health evidence
  - algorithm performance evidence

## 六、完成后自检

请自检并确认：
- 是否还存在 smoke 选 best_variant 的逻辑
- formal 是否已覆盖所有改进版本
- markdown 是否明确写出 smoke 仅用于跑通验证
- report 结构是否区分 smoke_status 与 formal_variant_scores
- 所有修改是否符合 minimal-intrusion 原则
```

------

### 这份提示词为什么这样写

你这次不是单纯“让 Codex 改几行”，而是要让它**理解研究策略发生了变化**。

原策略是：

- smoke = 小样本筛选器

你现在的新策略是：

- smoke = 流程健康检查器
- formal = 真正的性能判断器

所以提示词里必须把这两个层次强行拆开，不然 Codex 很容易只是局部修补，最后又偷偷保留“smoke 选 best_variant”的旧逻辑。

------

### 我再帮你补一版“更强约束版”

如果你担心 Codex 改得不彻底，用下面这个更硬一点的版本。

```text
严格修改 `run_bbo_research_pipeline.m`，目标是取消“smoke 阶段筛选最优版本”的研究策略。

硬性要求如下：

1. smoke 阶段禁止输出任何“best variant / best candidate / recommended variant”结论
2. smoke 阶段禁止依据少量函数结果淘汰改进版本
3. formal 阶段必须同时包含：
   - BBO_BASE
   - 全部 `cfg.variant_algorithms`
   - 全部 `cfg.strong_baselines`
4. 只有 formal 阶段结果才允许生成 variant_scores / variant_detail / recommendation
5. markdown 报告必须显式区分：
   - smoke execution status
   - formal performance comparison
6. 若 formal 未执行，报告中必须明确写出：
   - no final performance conclusion
   - smoke is not sufficient for algorithm ranking
7. 保持最小侵入，不新增新的 benchmark backend，不修改原始 BBO 算法文件

请直接给出完整修改后的 MATLAB 文件，不要只给 diff，不要只给思路。
```

------

### 再给你一版“分步骤执行版”

如果你想让 Codex 更稳，可以用这种分任务结构。

```text
请按以下顺序修改 `run_bbo_research_pipeline.m`：

第一步：重构主流程
- 去掉 smoke 阶段基于性能选 best_variant 的逻辑
- smoke 只保留执行验证
- formal 跑全部 variants

第二步：新增 smoke health check
- 新增函数，对 smoke_output 做运行完整性检查
- 输出 pass/fail、缺失算法、异常 suite、说明信息

第三步：重构 formal 分析
- formal_output 才调用 variant evaluation
- 输出 formal_variant_scores 与 formal_variant_detail

第四步：重写 markdown
- 明确写 smoke ≠ final conclusion
- formal 才用于算法优劣判断

第五步：自检
- 确认代码里没有任何 smoke 选 best_variant 的残留逻辑
- 确认 formal 覆盖全部 variants
- 确认 report 字段语义清晰

最终请输出：
1. 完整 MATLAB 代码
2. 修改说明
3. 自检清单
```

------

### 你当前这版脚本里，最该一起改的一个点

除了你提到的 **“smoke 不该筛优”** 之外，还有一个很关键：

你现在把：

```matlab
if ~isfield(cfg, 'run_formal')
    cfg.run_formal = true;
end
```

默认开成了 `true`。这本身不一定错，但最好让 Codex 在注释里写清楚：

- `run_formal=true` 是因为当前研究策略要求 formal 才产生性能结论
- 不是因为 smoke 已经足够

否则以后回头看代码，会误以为“formal 只是额外可选”，而不是“真正比较必须做”。

------

### 你还可以顺带要求 Codex 加上的两个增强点

你这次提示词里还可以顺手加两条，我建议加。

#### 增强点 1：formal 结束后再选最终推荐版本

不是 smoke 选，而是：

- formal 才输出 `final_recommendation`
- 例如：
  - `best_by_net_gain`
  - `best_by_mean_improvement`
  - `most_stable_variant`

这样后面论文会更顺。

#### 增强点 2：smoke 失败时禁止 formal

也就是：

- 如果 smoke 没跑通
- formal 直接不进
- 报告写明“先修流程异常”

你可以给 Codex 加一句：

```text
若 smoke health check 未通过，则 formal 阶段默认跳过，并在 report / markdown 中明确记录跳过原因。
```

这会更像正规科研流水线。

------

### 建议你最终发给 Codex 的版本

如果你想要“够详细，但不至于太长”，我建议你发第一版主提示词，再在末尾补这两句：

```text
补充要求：
1. 若 smoke health check 未通过，则 formal 默认跳过，并记录 skip reason。
2. formal 执行完成后，可额外输出 final_recommendation，但该推荐必须仅基于 formal 结果，而不是 smoke 结果。
```

这样基本就够了。

------

### 当前总体任务进度

**当前所处阶段：**
已经从“首轮 pipeline 可运行”进入“重构实验决策逻辑”阶段。现在做的是把 smoke 从“粗糙筛选器”改成“流程健康检查器”，让 formal 成为真正的性能判断层。

**已完成：**

- 识别出当前脚本的研究逻辑问题
- 明确 smoke 不应承担最终筛选职责
- 明确 formal 应覆盖全部改进版本
- 已生成可直接交给 Codex 的结构化修改提示词

**下一步：**
把这份提示词交给 Codex，等它给出修改版后，再让我帮你做一轮“科研合理性审查 + 是否适合写论文”的复核。

### 这次你能学到什么 / 对未来有什么帮助 🔬

这次最关键的收获，是你开始把**实验流程设计**和**算法结果判断**分开了。
很多人做改进算法时，问题不在算法本身，而在实验策略：
明明 smoke 只是“点火看看发动机响不响”，却拿它当“正式比赛成绩”。
你现在这一步，相当于把“试车场”和“正式赛道”分开了。这样后面即使改进失败，结论也更可信；一旦成功，论文也更站得住。📈