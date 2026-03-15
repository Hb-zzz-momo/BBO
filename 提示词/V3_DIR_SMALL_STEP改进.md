可以，这次我把两个点一起补上：

1. **结果目录强制带时间节点**
2. **给你迭代 3 版 Codex 提示词**，从“稳妥版 → 强约束版 → 研究执行版”逐步增强

根据你这份 README 的结论，当前主线应继续围绕 `V3_DIR_SMALL_STEP`，不再把 `FAST_SIMPLE_A/B` 当主线；重点保留 `F1/F2/F3` 作为单峰短板检测函数，保留 `F12/F13/F14/F15/F18/F19` 作为当前 directional 优势验证函数；下一轮核心比较版本应收敛到 4 个：`V3_BASELINE`、`V3_DIR_SMALL_STEP`、`V3_DIR_SMALL_STEP + late_local_refine`、`V3_DIR_SMALL_STEP + gate + late_local_refine`。

------

## 先统一：result 时间节点命名规范

先让 Codex 统一按这个规范输出结果：

```text
results/
  benchmark/
    v3_direction_reduced_smoke/
      20260315_142530/
        ...
    v3_direction_reduced_formal/
      20260315_143812/
        ...
```

也就是：

- 每次实验目录都自动生成时间戳
- 格式统一为：`YYYYMMDD_HHMMSS`
- smoke 和 formal 分开
- 不能覆盖旧结果
- 结果报告里要回写本次时间戳

还可以再要求它额外生成一个“latest”软链接（symbolic link，符号链接）或索引文件，但这个不是必须。

------

## 提示词 v1：稳妥执行版

这版适合先让 Codex **低风险落地**。

```text
你现在是这个仓库的科研代码助手 AGENT。

任务目标：
基于当前已有结果分析，进行一轮“缩减函数集的方向消融实验”，流程为：
1）先做 reduced smoke
2）再做 reduced formal
3）输出带时间节点的 result 目录
4）自动生成简短结果分析

### 一、必须先遵守的研究结论

当前主线应继续围绕 `V3_DIR_SMALL_STEP` 展开，不再把 `FAST_SIMPLE_A/B` 作为主线继续扩展。
本轮重点不是继续堆模块，而是验证：
- directional 优势能否保住
- 单峰短板能否通过后期收缩修复补回来

### 二、不要做的事

- 不要删除原始 full benchmark
- 不要删除历史结果目录
- 不要修改原有 full benchmark 默认函数集
- 不要覆盖旧实验结果
- 不要大范围重构仓库
- 不要新增与本轮研究无关的功能

用户所说的“先把之前不理想的函数都删除”，这里解释为：
仅在本轮新增一个 reduced function subset 配置，不物理删除原 benchmark 中的函数定义与 full 配置。

### 三、本轮 reduced function subset

请新增一个 reduced subset 配置，仅保留以下函数：
- F1
- F2
- F3
- F12
- F13
- F14
- F15
- F18
- F19

说明：
- F1/F2/F3：检测单峰修复是否生效
- F12/F13/F14/F15/F18/F19：检测 directional 在复杂/混合函数上的优势是否保住

### 四、本轮仅保留以下 4 个版本进入比较

1. V3_BASELINE
2. V3_DIR_SMALL_STEP
3. V3_DIR_SMALL_STEP_LATE_LOCAL_REFINE
4. V3_DIR_SMALL_STEP_GATE_LATE_LOCAL_REFINE

要求：
- 命名清晰
- 结构可消融
- 尽量复用现有 benchmark / compare / report 体系

### 五、late_local_refine 的设计原则

这是一个“单峰友好型后期收缩修复模块”，必须满足：

- 只在后期启用
- 小步长
- 低频触发
- 以 best 或 elite centroid 为中心做轻量收缩
- 可以使用很轻的精英差分局部搜索
- 不能引入大扰动和大偏移

建议触发条件：
- progress > 0.7
- no_improve_count <= small_threshold
- population_diversity < diversity_threshold

### 六、gate + late_local_refine 版本要求

在 `V3_DIR_SMALL_STEP_GATE_LATE_LOCAL_REFINE` 中，为 directional 增加条件门控。
只有在以下情况下 directional 才允许触发：
- 出现停滞
- 当前个体明显落后于 elite / best
- 群体仍有一定多样性
- 当前阶段不是最早期

禁止：
- directional 全时段常开
- 早期强行引导
- 对所有个体无差别触发

### 七、实验流程

A. reduced smoke
- 使用 reduced subset
- 若仓库已有 smoke 配置体系，优先复用
- 若缺失，则最小新增一个 reduced smoke config
- 推荐默认参数：
  - dim = 10
  - population = 30
  - budget = 3000 FEs
  - runs = 2

B. reduced formal
- smoke 通过后再执行
- 仍然只使用 reduced subset
- 若仓库已有 formal 协议，保持一致
- 若缺失，则最小新增一个 reduced formal config
- 推荐默认参数：
  - dim = 10
  - population = 30
  - budget = 3000 FEs
  - runs = 5

### 八、result 目录必须带时间节点

请统一使用时间戳目录命名，格式：
YYYYMMDD_HHMMSS

结果目录示例：
- results/benchmark/v3_direction_reduced_smoke/20260315_142530/
- results/benchmark/v3_direction_reduced_formal/20260315_143812/

要求：
- 每次运行自动生成新的时间戳目录
- 不覆盖旧结果
- 在 summary/report 中回写本次 timestamp
- 如果仓库已有统一输出函数，优先扩展该函数，不要另起炉灶

### 九、输出内容

每次实验至少输出：
- raw results
- summary.csv
- ranking summary
- per-function mean/std
- improved / degraded / tie 统计
- markdown 简报

### 十、formal 结束后自动分析

请基于结果文件自动回答以下问题：

1. late_local_refine 是否修复了 F1/F2/F3
2. DIR_SMALL_STEP 在 F12/F13/F14/F15/F18/F19 上的优势是否保住
3. gate + late_local_refine 是否比纯 late_local_refine 更稳
4. 当前四个版本中哪个最适合作为下一轮主线
5. 是否值得再进入 full formal

### 十一、最终交付格式

请输出：
1. 任务理解
2. 修改/新增文件清单
3. 核心改动说明
4. 运行入口与命令
5. result 输出位置
6. smoke 是否通过
7. formal 是否完成
8. 当前最佳版本判断
9. 风险与后续建议

注意：
不要虚构结果；只有真的跑完才能说完成。
```

------

## 提示词 v2：强约束科研版

这版更适合你现在这种 **要控制 Codex 不乱改仓库** 的场景。

```text
你是本仓库的“最小侵入式科研代码改造助手”。

### 任务目标
围绕 `V3_DIR_SMALL_STEP` 做一轮 reduced subset 消融：
- 先 smoke
- 再 formal_screen
- 输出带 timestamp 的结果目录
- 自动给出面向论文与下一轮实验决策的结论

### 核心研究约束
1. 不再以 `FAST_SIMPLE_A/B` 为主线扩写
2. 不做多模块继续堆叠
3. 当前改进目标是“方向引导 + 单峰后期修复”
4. 本轮只判断方向是否成立，不做 full final benchmark

### 仓库改造约束
你必须遵守：
- 不删除任何历史 benchmark 入口
- 不删除任何历史结果目录
- 不修改 full benchmark 默认函数集
- 不破坏已有 run_all_compare / research_pipeline / compare / report 体系
- 能复用就复用，不能复用再做最小新增
- 结果目录必须 timestamp 化，不能覆盖旧结果

### reduced subset
只保留：
F1 F2 F3 F12 F13 F14 F15 F18 F19

### 本轮只比较四个版本
- V3_BASELINE
- V3_DIR_SMALL_STEP
- V3_DIR_SMALL_STEP_LATE_LOCAL_REFINE
- V3_DIR_SMALL_STEP_GATE_LATE_LOCAL_REFINE

### 模块设计要求
#### 1）late_local_refine
这是一个“收缩型后期修复模块”，不是偏移型强扰动模块。
目标：
- 修复单峰后期精度
- 不破坏早期探索
- 不改变 V3_DIR_SMALL_STEP 主搜索骨架

建议特征：
- progress > 0.7
- 小步长
- 低频触发
- best / elite centroid 附近轻量局部搜索
- 不允许大幅随机重排个体

#### 2）directional gate
让 directional 从“常驻机制”变成“条件触发机制”。

推荐门控信号：
- stagnation（停滞）
- relative lag to elite（相对精英落后）
- remaining diversity（剩余多样性）
- stage control（阶段控制）

禁止：
- 早期常开
- 全体常开
- 强行牵引搜索轨迹

### 实验阶段
#### Stage A: reduced smoke
建议参数：
- dim=10
- pop=30
- budget=3000 FEs
- runs=2

#### Stage B: reduced formal_screen
建议参数：
- dim=10
- pop=30
- budget=3000 FEs
- runs=5

### 时间戳输出要求
所有结果目录必须自动带时间节点，格式：
YYYYMMDD_HHMMSS

示例：
results/benchmark/v3_direction_reduced_smoke/20260315_150101/
results/benchmark/v3_direction_reduced_formal/20260315_151422/

并且：
- summary.csv 中增加 timestamp 字段，或在配套 meta 文件中记录 timestamp
- markdown 报告标题中写明 timestamp
- 运行日志文件名也要带 timestamp

### 输出文件最低要求
- config snapshot
- run log
- raw results
- summary.csv
- ranking summary
- per-function mean/std table
- improved/degraded/tie summary
- markdown report

### 自动结论模块
跑完 formal_screen 后，自动回答：
- F1/F2/F3 是否得到修复
- complex/hybrid 优势是否保持
- gate 是否提高稳定性
- 哪个版本最适合进入下一轮 full formal
- 哪些风险仍未解决

### 最终输出格式
请按如下顺序输出：
1. 任务理解
2. 拟修改文件
3. 关键实现策略
4. 运行入口
5. timestamp 结果目录
6. smoke 状态
7. formal_screen 状态
8. 当前最佳版本
9. 后续是否建议 full formal

重要：
- 不要编造成果
- 如果失败，准确说明失败点
- 如果仓库已有相关能力，优先在原能力上扩展
```

------

## 提示词 v3：研究推进版（最适合现在直接丢给 Codex）

这版最完整，适合你现在直接执行。

```text
你现在进入“科研推进执行模式”。

任务不是重写仓库，而是以最小修改完成一轮：
`V3_DIR_SMALL_STEP` 主线下的 reduced subset directional ablation。

## 一、背景结论
当前已有分析显示：
- `V3_DIR_SMALL_STEP` 是当前最合理主线
- directional 思路有效，但必须轻量、保守、受控
- `FAST_SIMPLE_A/B` 不能继续当主线
- 当前最主要矛盾是：复杂函数增强了，但 F1/F2/F3 这类单峰函数被伤到了
- 下一轮应验证“directional + late contraction-style repair”是否可行

## 二、任务范围
你只做以下事情：
1. 新增 reduced subset 配置
2. 新增或整理 4 个比较版本
3. 先 smoke
4. 再 formal_screen
5. 所有结果目录加 timestamp
6. 自动导出结果分析

你不要做以下事情：
- 不要删 full benchmark
- 不要删历史代码
- 不要覆盖旧结果
- 不要大重构
- 不要写与本轮无关的新框架

## 三、本轮 reduced subset
仅保留：
- F1
- F2
- F3
- F12
- F13
- F14
- F15
- F18
- F19

## 四、本轮比较版本
仅保留：
- V3_BASELINE
- V3_DIR_SMALL_STEP
- V3_DIR_SMALL_STEP_LATE_LOCAL_REFINE
- V3_DIR_SMALL_STEP_GATE_LATE_LOCAL_REFINE

要求：
- 文件命名、注册命名、结果命名一致
- 每个版本的新增机制必须可单独解释
- 方便后续写论文中的 ablation 表述

## 五、实现要求

### 1. V3_DIR_SMALL_STEP_LATE_LOCAL_REFINE
请在 `V3_DIR_SMALL_STEP` 基础上新增一个单峰友好型后期修复模块。

目标：
- 修复 F1/F2/F3 后期收敛
- 不破坏 F12/F13/F14/F15/F18/F19 的已有优势

模块属性：
- contraction-style（收缩型）
- late-stage only（仅后期）
- light local refine（轻量局部精修）
- low frequency（低频）
- small radius（小半径）

推荐触发：
- progress > 0.7
- no_improve_count <= small threshold
- population_diversity < threshold

推荐动作：
- 在 best 或 elite centroid 附近做轻量差分式局部试探
- 或做小幅收缩性 refinement
- 禁止大扰动、禁止大范围个体重排

### 2. V3_DIR_SMALL_STEP_GATE_LATE_LOCAL_REFINE
在上一个版本基础上，再增加 directional gate。

directional 只有在满足以下条件时才触发：
- stagnation 出现
- 当前个体明显落后于 elite
- 群体仍有一定 diversity
- 当前不是早期阶段

设计目标：
- 让 directional 只在“需要干预时”介入
- 避免简单函数阶段被持续扰动

## 六、实验协议

### smoke_reduced
优先复用现有 smoke 体系。
若没有，则最小新增：
- dim = 10
- pop = 30
- budget = 3000 FEs
- runs = 2

### formal_reduced
优先复用现有 formal 体系。
若没有，则最小新增：
- dim = 10
- pop = 30
- budget = 3000 FEs
- runs = 5

注意：
本轮 formal 是 direction screening，不是最终论文 full formal。

## 七、timestamp 输出强约束
所有 result 路径必须自动带当前时间节点，格式：
`YYYYMMDD_HHMMSS`

目录示例：
- `results/benchmark/v3_direction_reduced_smoke/20260315_153015/`
- `results/benchmark/v3_direction_reduced_formal/20260315_154702/`

同时要求：
- 日志文件名带 timestamp
- markdown 报告带 timestamp
- config snapshot 带 timestamp
- summary 或 meta 中能追溯这次时间节点
- 绝不能覆盖历史实验结果

## 八、输出内容
每次运行至少导出：
- config snapshot
- raw results
- run log
- summary.csv
- ranking summary
- per-function mean/std
- improved/degraded/tie
- markdown report

## 九、formal_screen 后自动分析
请基于真实结果自动写一个简短分析，必须回答：

1. F1/F2/F3 是否得到修复
2. F12/F13/F14/F15/F18/F19 是否仍保留 directional 优势
3. late_local_refine 是否有效
4. gate + late_local_refine 是否比单独 late_local_refine 更稳
5. 哪个版本值得进入 full formal
6. 当前仍存在哪些风险

## 十、交付格式
请最终输出：
1. 任务理解
2. 修改/新增文件
3. 实现说明
4. 运行命令
5. timestamp 结果目录
6. smoke 结果
7. formal_screen 结果
8. 最佳版本判断
9. 是否建议进入 full formal
10. 风险与下一步建议

重要：
- 不要声称完成未实际完成的运行
- 如果失败，明确失败发生在哪个脚本、配置、接口、参数或结果导出步骤
- 优先在现有 pipeline 上做最小侵入扩展，而不是重写
```

------

## 我建议你怎么选

### 直接开干

用 **v3 研究推进版**

### 担心 Codex 改太多

用 **v2 强约束科研版**

### 先试一次，看看它听不听话

用 **v1 稳妥执行版**

------

## 我再补一个更狠的“防跑偏尾巴”

你可以把下面这段加到任意一版提示词最后面：

```text
补充硬约束：
- 不允许把 reduced subset 伪装成 full benchmark
- 不允许擅自扩大函数集
- 不允许擅自新增第五个比较版本
- 不允许把历史版本重命名导致结果不可对齐
- 不允许覆盖旧的 summary.csv
- 若新增时间戳目录失败，优先修复输出路径逻辑，再运行 benchmark
- 若 smoke 失败，不得直接跳过进入 formal
- 若 formal 未完成，不得输出“当前最佳版本”这一结论式表述，只能输出“暂定观察”
```

------

## 最后给你一个我更推荐的结果目录模板

```text
results/
  benchmark/
    v3_direction_reduced/
      smoke/
        20260315_160012/
      formal/
        20260315_161455/
```

这个结构比把 `smoke/formal` 写进长文件名更整洁，后面论文整理也更方便。

------

### 这次你能学到什么 / 对未来有什么帮助 🌱

这次真正学到的不是“怎么写一句提示词”，而是**怎么把科研意图翻译成可执行工程约束**。
好的提示词就像实验方案书 🧪：不是只说“去做实验”，而是要把**变量、对照、流程、输出、命名、失败处理**全部锁住。这样 Codex 才更像研究助理，而不是随机写代码的机器人 🤖

### 当前总体任务进度

当前处于：**V3 主线收敛后的 reduced subset 消融执行准备阶段**
已完成：**主线方向确认、时间戳结果规范、3 版 Codex 提示词迭代**
下一步：**选一版提示词直接喂给 Codex，先看它能不能把 timestamp 输出和 reduced smoke 跑通**