([Past chat](https://chatgpt.com/c/69b50591-f088-83a8-b1da-dd0ebf3c73ff))([Past chat](https://chatgpt.com/c/69b65aed-0d74-83a4-9fdd-4de1740c4e94))([Past chat](https://chatgpt.com/c/69b64a97-f2b4-83ab-b5dc-9a02133d13a0))

### 先给可直接用的版本

基于这次 **reduced formal** 的结论，当前最合理的路线不是换主线，而是继续沿着 **v3 directional** 往下走，但优先修复 **简单函数退化**：把 direction 改成 **状态触发**，优先试 **停滞触发 + 只对后 50% 差个体启用 + 步长裁剪**，同时保留 `late_local_refine` 但改成状态触发；下一轮 reduced formal 推荐比较 `V3_BASELINE`、`V3_DIR_STAG_ONLY`、`V3_DIR_STAG_BOTTOM_HALF`、`V3_DIR_STAG_BOTTOM_HALF_LATE_REFINE`，可选再加一个 clipped 版本。仓库侧还要坚持 **最小必要改动**、保持 **baseline / improved / ablation** 边界清楚，且**不能静默改 benchmark 协议**。

```text
你是这个仓库的 Research Code Assistant AGENT。现在不要做花哨重构，不要改 benchmark 协议，不要扩展无关工程，只做与本轮研究主线直接相关的最小必要修改。

## 一、任务目标
基于当前 reduced formal 结果，对 v3 directional 主线做“简单函数保护 + 状态触发”改进，生成一个更稳的下一轮 reduced formal 候选版本，并保持 baseline / improved / ablation 边界清楚，方便后续论文写作与消融实验。

## 二、已知研究结论（必须据此修改，不要偏题）
1. directional small step 对复杂函数是有效的，但不能全局常开。
2. 当前主要问题是 simple 子集（F1/F2/F3）退化严重，说明 direction 在简单函数上注入了错误偏置。
3. late_local_refine 可以保留，但不能常开，应改为状态触发。
4. 现有 gate 版本更像过度保守，不要继续扩展复杂 gate 主线，优先把触发逻辑做对。
5. 下一轮重点不是继续加新大模块，而是：
   - simple 保护
   - direction 条件触发
   - late refine 条件触发
   - direction 步长再缩小、再可控

## 三、你必须遵守的约束
1. 不允许静默修改 benchmark 公平性相关协议，除非只是新增 variant：
   - suite
   - function set
   - dim
   - pop_size
   - maxFEs / budget
   - formal runs
   - stopping criteria
   - 统计口径
2. 不允许删除 baseline 或历史版本。
3. 不允许把简单研究代码过度抽象成复杂框架。
4. 不允许伪造实验结果、伪造已测试结论。
5. 优先最小改动，复用现有入口、现有输出格式、现有 result 组织方式。
6. 所有新版本命名必须清晰可区分，适合后续 ablation 与论文写法。
7. 如果仓库里已有统一 benchmark 入口，优先复用，不要另起炉灶。

## 四、你要做的核心代码修改
请先扫描仓库，识别当前 v3 版本、ablation core、benchmark 入口、summary 导出逻辑，然后实现下面这些改动。

### 任务 A：实现 direction 的“停滞触发”
新增一个方向触发机制，只有在“明显停滞”时才允许启用 direction。
建议最小实现：
- 维护 no_improve_count
- 当 no_improve_count >= tau_dir 时，允许 direction
- 否则保持纯 baseline 更新，不注入 direction

要求：
- tau_dir 设为显式参数，便于后续 sensitivity / ablation
- 参数默认值给出保守选择
- 不要把逻辑写死在代码里不可调

### 任务 B：实现“只对后 50% 差个体启用 direction”
新增一个 bottom-half directional 策略：
- 对种群按 fitness 排序
- elite / top half 保持 baseline 主驱动
- bottom half 才允许在满足停滞触发时启用 direction
目的：
- 减少对 simple 函数开发能力的破坏
- 让 direction 主要承担“破局”而不是“全局重写搜索轨迹”

要求：
- 该逻辑必须能单独开关
- 不要影响 baseline 版本
- 代码中保持版本边界清楚

### 任务 C：把 direction 步长改成“可控步长”
目前的 directional small step 仍然过强，请改成可控步长形式，推荐思想：
- direction vector 先归一化或按局部尺度缩放
- 再进行 clip / cap
- 每维最大步长受局部尺度限制

推荐实现思路（可等价实现，不必死抠公式）：
delta_j = alpha_dir * clipped_direction_j * local_scale_j

其中建议：
- alpha_dir 默认取保守小值
- local_scale_j 可优先使用 pop_std_j、elite_spread_j、或与 best 的差值尺度
- per-dimension cap 不超过：
  - 0.1 * pop_std_j
  - 或 0.05 * (ub(j) - lb(j))
  取其中更保守者
- 靠近 best 时再进一步缩小

要求：
- 新步长逻辑要显式参数化
- 保证 fallback 容易回退
- 不要破坏原 baseline body

### 任务 D：保留 late_local_refine，但改成“状态触发式”
只在以下条件同时满足时允许 local refine：
- no_improve_count >= tau_refine
- elite_spread <= threshold_refine
- progress >= p0
- 可选：最近若干代 median-best gap 变小

要求：
- local refine 必须是附加模块，不要与 baseline 主体硬耦合
- 所有阈值都显式参数化
- 如果仓库已有 late refine，请尽量最小改造，不要重写整套逻辑

## 五、需要新增的候选版本
请基于现有命名体系，优先新增以下 4 个 reduced-formal 候选版本：

1. V3_BASELINE
   - 保持现有 baseline，不改协议，只作为对照

2. V3_DIR_STAG_ONLY
   - direction 仅在停滞时启用

3. V3_DIR_STAG_BOTTOM_HALF
   - 停滞触发 + 仅后 50% 差个体启用 direction

4. V3_DIR_STAG_BOTTOM_HALF_LATE_REFINE
   - 在 3 的基础上，再加状态触发式 late_local_refine

可选第 5 个：
5. V3_DIR_CLIPPED_STAG_BOTTOM_HALF_LATE_REFINE
   - 在 4 的基础上，进一步启用更严格的 clipped directional step

要求：
- 如果仓库已有 ablation core，则优先在 core + mode_config 结构中扩展
- 如果已有 variant 注册表 / case list / compare list，则把新版本挂进去
- 不要破坏已有版本名和历史结果兼容性

## 六、实验入口与输出要求
请为下一轮 reduced formal 做好最小可运行支持，优先复用现有 benchmark 入口。
目标实验协议保持不变：
- suite: CEC2017
- reduced subset: F1 / F2 / F3 / F12 / F13 / F14 / F15 / F18 / F19
- dim: 10
- pop_size: 30
- maxFEs: 3000
- formal runs: 5

请确保：
1. 可以只跑上述小矩阵版本
2. summary 输出仍可直接比较各版本
3. 输出命名能区分不同 variant
4. 保留 raw result + summary + 可复现实验配置
5. 不改变已有 summary 字段定义，除非新增字段且向后兼容

## 七、你最终必须交付的内容
请不要只改代码，要同时输出结构化说明，格式如下：

1. Task understanding
2. What part of the research workflow this belongs to
3. Implementation plan
4. Files to add or modify
5. Key code
6. Why this change is made
7. How to run it
8. Expected outputs
9. Risks, assumptions, and items still needing verification
10. Updated end-to-end flow

## 八、额外分析要求
请额外给出一段“为什么这轮这样改”的科研解释，要求能直接服务后续论文：
- 说明为什么 direction 不能全局常开
- 说明为什么要 simple-function protection
- 说明为什么 late refine 要状态触发
- 说明这些修改不是工程堆料，而是“复杂函数收益 + simple 保护”的方法演化逻辑

## 九、验收标准（非常重要）
你改完后，不要声称性能提升已验证；你只能保证代码与实验设计已就绪。
这轮 reduced formal 的目标验收标准是：

必须满足：
- F1/F2/F3 aggregate mean 不再显著差于 baseline
- 不再出现 F1/F2 百倍级退化
- complex 子集仍保持总体正收益
- net_gain >= 3

更理想：
- simple_mean_delta > 0
- complex_mean_delta 仍明显 > 0
- std_delta_mean 不显著恶化

## 十、行为边界
- 不要发散到 UI、平台化、重构全部目录
- 不要把 MATLAB 改成 Python
- 不要自动改论文内容
- 不要虚构“已经跑过并更好”
- 若信息不足，先扫描仓库并基于现有结构做最小合理实现
- 所有不确定点都要显式说明

现在开始：
1. 先扫描仓库并定位相关文件
2. 说明你准备修改哪些文件、为什么
3. 然后给出实际代码改动
4. 最后给出运行方法与 reduced formal 执行建议
```

### 更强约束版（防止 Codex 跑偏）

```text
你现在只做一件事：在现有 v3 directional 主线上实现“简单函数保护 + 状态触发”小步改进，并为 reduced formal 做好可运行候选版本。

禁止事项：
- 禁止大重构
- 禁止改 benchmark 协议
- 禁止删除 baseline / 历史逻辑
- 禁止扩展无关模块
- 禁止伪造测试结果
- 禁止把任务改写成工程平台建设

你必须优先复用：
- 现有 ablation core
- 现有 mode_config / variant registry
- 现有 benchmark 入口
- 现有 summary 导出逻辑

本轮只实现 4 个主版本：
- V3_BASELINE
- V3_DIR_STAG_ONLY
- V3_DIR_STAG_BOTTOM_HALF
- V3_DIR_STAG_BOTTOM_HALF_LATE_REFINE
可选：
- V3_DIR_CLIPPED_STAG_BOTTOM_HALF_LATE_REFINE

必须实现的 4 个机制：
1. 停滞触发 direction
2. 仅后 50% 差个体允许 direction
3. directional 步长裁剪 / 局部尺度控制
4. late_local_refine 改为状态触发

输出必须包含：
- 修改文件列表
- 关键代码
- 如何运行 reduced formal
- 新版本命名说明
- 风险与待验证项

记住：这轮的目标不是“加新花样”，而是“把 simple 端修住，同时保住 complex 收益”。
```

### 精简版（适合先试一轮）

```text
请基于当前仓库，对 v3 directional 主线做最小必要改动：

目标：
- 修复 simple 函数 F1/F2/F3 的严重退化
- 保留 complex 函数上的 directional 收益
- 不改 benchmark 协议
- 不删 baseline
- 不做大重构

请新增并接入以下版本：
- V3_BASELINE
- V3_DIR_STAG_ONLY
- V3_DIR_STAG_BOTTOM_HALF
- V3_DIR_STAG_BOTTOM_HALF_LATE_REFINE
可选：
- V3_DIR_CLIPPED_STAG_BOTTOM_HALF_LATE_REFINE

必须实现：
1. direction 仅在 no_improve_count >= tau_dir 时触发
2. 仅后 50% 差个体允许 direction
3. direction 步长改成局部尺度控制 + clip
4. late_local_refine 改成状态触发：
   - no_improve_count >= tau_refine
   - elite_spread <= threshold_refine
   - progress >= p0

要求：
- 优先复用现有 ablation core / benchmark 入口
- 保持 baseline / improved / ablation 边界清楚
- 输出修改文件、关键代码、运行方法、预期结果文件
- 不要声称已验证性能，除非你真的跑了
```

### 我对这版提示词的设计说明

这版不是单纯“让 Codex 改代码”，而是把本轮科研目标钉死成四件事：

1. **不换主线**
2. **不加大模块**
3. **优先修 simple 退化**
4. **保持实验公平与可复现**

这样 Codex 比较不容易跑去做“新 gate、大重构、重新搭框架”这种偏题操作，而会老老实实围绕这次结果去修正。这个约束正好也符合你仓库里强调的研究主线、最小改动、可复现和公平比较原则。

### 论文撰写或修改建议

这轮代码修改在论文里最适合写成一条很清楚的“方法演化链”：

- 基线版本在复杂函数上存在后期收敛不足；
- 引入 directional small step 后，复杂函数收益明显；
- 但 simple 函数显著退化，说明全局常开 direction 会破坏基础开发能力；
- 因此进一步引入 **状态感知触发（state-aware trigger）** 与 **简单函数保护机制**；
- 再引入 **状态触发式 late local refine** 用于停滞后精修。

这样写出来更像“问题驱动的研究推进”，而不是“想到什么加什么”。

### 当前总体任务进度

- **当前阶段**：V3 reduced formal 结果已完成解释，正在进入下一轮 Codex 定向改码阶段。
- **已完成**：主线方向判断、保留模块判断、下一轮版本矩阵确定。
- **下一步**：把上面的标准版提示词直接喂给 Codex，拿到改动后再做第二轮“收紧提示词 + 验收输出模板”。

### 这次你能学到什么 / 对未来有什么帮助 🌱

真正有效的科研提示词，不是“让 AI 帮我写代码”，而是把 **研究边界、实验公平、修改粒度、验收标准** 一次性钉住。
这样 AI 就像进实验室前先拿到 SOP（Standard Operating Procedure，标准作业流程）的人，知道哪里能动、哪里不能动，产出才更稳。🧪