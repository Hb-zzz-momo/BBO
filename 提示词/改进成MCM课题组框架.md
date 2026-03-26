([Past chat](https://chatgpt.com/c/69b67315-dd1c-83a9-8493-593e4cf55381))([Past chat](https://chatgpt.com/c/69b25b8c-7c9c-83a5-9bfb-0469fc2c1205))([Past chat](https://chatgpt.com/c/69b01117-03c0-83a9-bcad-4389fc1bd755))

### 先给结论

这次我直接给你一套**可复制到 Codex（OpenAI 本地编码代理）里用的“多版本详细提示词”**，并且把上次分析里**所有真正值得借鉴的框架思想**都塞进去，包括：

- 统一算法接口
- 统一实验主控
- 统一统计导出
- CEC（Congress on Evolutionary Computation，进化计算大会）基准测试
- 应用任务 objective wrapper（目标函数包装器）
- 时间戳结果归档
- 消融实验
- 可复现性
- FE（Function Evaluations，函数评价次数）公平性
- 论文支撑输出
- 你当前项目里最关键的**BBO 指的是 Beaver Behavior Optimizer（河狸行为优化），不是 Biogeography-Based Optimization（生物地理学优化）**

另外，OpenAI 官方文档也明确建议：
Codex 更适合在**给足上下文、指定相关文件、给出清晰输出契约、并通过 `AGENTS.md` 约束项目规则**的情况下工作；而且 `AGENTS.md` 可以分层放置，离当前目录越近的规则优先级越高。官方也建议说明具体文件、图像、目标和交付格式，而不是只说“帮我改代码”。 ([OpenAI开发者](https://developers.openai.com/codex/learn/best-practices/?utm_source=chatgpt.com))

------

### 先说怎么用这几版提示词

这几版不是“谁覆盖谁”，而是不同场景用不同版本：

| 版本 | 适用场景                                     | 风格                  |
| ---- | -------------------------------------------- | --------------------- |
| V1   | 第一次让 Codex 接手仓库                      | 全量理解 + 先规划后改 |
| V2   | 已经有主线代码，想保守迭代                   | 最稳，最适合科研仓库  |
| V3   | 重点做 benchmark（基准测试）与消融           | 实验导向最强          |
| V4   | 重点做 lung CT（肺部计算机断层扫描）应用接入 | 应用验证导向          |
| V5   | 重点做论文支撑与结果沉淀                     | 结果组织最强          |

我建议实际使用顺序是：

**先 V1 → 再 V2 或 V3 → 最后 V4 / V5**

------

### 使用前的固定前置说明

每次发给 Codex 前，建议你都在最前面补这一段，让它别跑偏：

```text
请先完整阅读仓库中的 README、AGENTS.md、实验主控脚本、算法实现文件、结果导出文件与已有改进版本代码，再开始工作。
不要把 BBO 理解成 Biogeography-Based Optimization。
在本仓库中，BBO 一律指 Beaver Behavior Optimizer（河狸行为优化）。
本次任务目标优先级为：
1. 真实科研推进
2. 实验可复现
3. 论文写作支撑
4. 尽量少改动无关代码
如果发现信息不足，先给出“已知事实 / 待确认点 / 暂定方案”，再开始实施。
不要直接大面积重构；优先做最小必要修改。
```

------

### V1：全量理解 + 研究框架重构版提示词

这个版本适合你第一次把整个仓库交给 Codex。

```text
你现在是我的科研代码代理，任务是基于当前仓库，构建一个适用于“基于 BBO（Beaver Behavior Optimizer，河狸行为优化）改进的肺 CT 图像分割与增强研究”的标准化科研实验框架。

先不要急着改代码。先做完整分析，再给最小可执行改造方案，然后再按计划实施。

必须遵守以下硬约束：

一、项目背景与总目标
1. 本项目是科研代码仓库，不是普通工程项目。
2. 研究主线是：改进元启发式优化算法 → 用 CEC 基准函数验证 → 再做肺 CT 图像分割/增强应用验证 → 最终服务论文写作。
3. 这里的 BBO 一律指 Beaver Behavior Optimizer（河狸行为优化），绝不是 Biogeography-Based Optimization（生物地理学优化）。
4. 代码修改必须服务于三个目标：
   - 真实研究推进
   - 实验可复现
   - 论文写作支撑

二、先做仓库理解，不要直接改
请先扫描并理解以下内容：
1. 顶层目录结构
2. 所有算法实现目录
3. 所有 benchmark / CEC 相关目录
4. 所有应用层目录
5. 所有结果导出、统计分析、绘图脚本
6. 所有 README、说明文档、配置文件、AGENTS.md
7. 当前是否已有 baseline、improved、ablation、formal、smoke 等实验痕迹

三、先输出“仓库诊断报告”，格式固定为
1. 仓库当前结构概览
2. 当前已经具备的科研框架能力
3. 当前缺失的关键能力
4. 哪些部分适合直接复用
5. 哪些部分应只借鉴思想，不应直接照搬
6. 对本项目最关键的风险点
7. 最小改造路线图（按优先级排序）

四、你要重点检查并评估这些科研能力
1. 是否有统一算法接口
   - 初始化
   - 适应度评估
   - 单轮迭代
   - solve 主入口
2. 是否有统一 benchmark 主控脚本
3. 是否有统一结果归档格式
4. 是否支持多次独立运行
5. 是否固定随机种子
6. 是否区分 smoke / formal / ablation
7. 是否按 FE（Function Evaluations，函数评价次数）而不是仅 epoch（迭代轮数）做公平预算控制
8. 是否能导出均值、标准差、秩次、显著性检验、收敛曲线、箱线图
9. 是否能把真实应用任务封装为 objective wrapper（目标函数包装器）
10. 是否有利于论文中的“方法、实验、结果、消融、局限性”写作

五、改造目标结构
请尽量把仓库整理为类似以下结构，但不要机械照搬；先判断当前仓库最适合的最小变体：
- src/optimizers/
  - baseline/
  - improved/
  - ablation/
- src/benchmarks/
  - cec/
  - benchmark_runner.*
- src/applications/lung_ct/
  - data_io.*
  - preprocess.*
  - segmentation.*
  - enhancement.*
  - metrics.*
  - objective_wrapper.*
- src/analysis/
  - stats.*
  - plots.*
  - export.*
- experiments/
  - run_cec.*
  - run_ablation.*
  - run_sensitivity.*
  - run_lung_ct.*
- results/
- docs/

六、改造原则
1. 最小必要修改优先
2. 不要一次性重写全仓库
3. 保留现有可运行主线
4. 先把接口统一，再谈功能扩展
5. 先让 benchmark 主线稳定，再接 lung CT
6. 所有新增结果目录必须带时间戳
7. 所有关键实验必须能复现实验条件
8. 所有新增模块都必须有清晰注释，说明科研作用而不是只写工程作用

七、实施顺序
请按下面顺序推进：
阶段 A：只做分析，不改代码
阶段 B：提出最小可执行改造计划
阶段 C：实施第一批高优先级改造
阶段 D：给出验证方法与验收标准
阶段 E：给出后续建议

八、第一批优先改造内容
1. 统一算法调用接口
2. 建立统一 benchmark 主控脚本
3. 建立统一结果输出结构
4. 加入随机种子控制
5. 加入 smoke / formal 模式区分
6. 明确 FE 预算控制逻辑
7. 建立实验日志与时间戳目录
8. 为后续 lung CT objective wrapper 预留接口

九、输出要求
每完成一个阶段，都要输出：
1. 改了哪些文件
2. 为什么改
3. 对科研主线有什么帮助
4. 如何验证改动没有破坏原功能
5. 下一步建议

十、禁止事项
1. 禁止把不确定结论写成确定结论
2. 禁止把 BBO 解释错
3. 禁止只做表面重命名而不解决科研框架问题
4. 禁止为了“代码好看”做大规模无关重构
5. 禁止忽略实验公平性与可复现性
6. 禁止删除已有可用实验结果目录
7. 禁止擅自改动论文主线目标

现在开始：
先输出“仓库诊断报告”，不要直接修改代码。
```

------

### V2：最稳妥的“保守迭代版”提示词

这个版本最适合你现在这种**已经有主线、怕 Codex 乱改**的情况。

```text
你现在要在当前科研仓库中做“保守型迭代改造”。

目标不是重写仓库，而是在尽量少改动现有代码的前提下，把现有项目逐步提升为一个更规范的科研实验框架，用于：
1. BBO（Beaver Behavior Optimizer，河狸行为优化）改进算法研究
2. CEC 基准验证
3. 肺 CT 图像分割与增强应用验证
4. 论文结果组织与沉淀

请严格遵守以下原则：

一、总原则
1. 只做高收益、低破坏的改动
2. 保留现有实验主线
3. 不改变已有核心算法语义，除非明确发现错误
4. 所有修改都要说明“科研收益”
5. 所有新文件命名要清晰，能一眼看出用途
6. 所有输出路径要可追踪、可复现

二、你需要优先吸收和实现的“可借鉴能力”
1. 统一算法接口
2. 统一 benchmark 主控
3. 统一统计导出
4. 时间戳结果目录
5. smoke / formal 分层实验
6. 多次独立运行
7. 固定随机种子
8. FE 公平预算
9. objective wrapper 预留机制
10. 面向论文写作的结果沉淀

三、请先完成下面任务
任务 1：列出当前仓库哪些文件承担了以下职责
- 算法实现
- 实验入口
- benchmark 测试
- 结果保存
- 统计分析
- 作图
- 文档说明

任务 2：判断这些职责是否已经清晰分层
任务 3：给出“最少改动方案”
任务 4：只实施最关键的第一步，不要一次性做完全部

四、第一步只允许改造这些类型
1. 新增统一实验入口
2. 新增结果目录组织逻辑
3. 新增随机种子和实验配置管理
4. 新增 benchmark 结果汇总导出
5. 新增实验模式切换（smoke / formal）

五、输出格式固定
1. 当前问题
2. 为什么这是问题
3. 解决方案
4. 具体将改哪些文件
5. 风险评估
6. 验证方法
7. 实施结果
8. 下一步建议

六、特别提醒
1. BBO 指河狸行为优化，不是生物地理学优化
2. 如果仓库中已有 BBO 命名冲突，必须标出来，但不要贸然全局替换
3. 如果 benchmark 当前按 epoch 预算，请检查是否应改为 FE 预算
4. 如果当前结果只保存最优值，不保存 raw runs、mean/std、rank、p-value、curve，请明确指出并补强
5. 如果当前仓库还没有应用层 objective wrapper，请只预留接口，不要凭空写死业务逻辑

现在开始：
先做“当前职责映射 + 最少改动方案”，不要先大改代码。
```

------

### V3：面向 CEC + 消融实验的强实验导向版提示词

这个版本特别适合你现在这种**改进算法、做消融矩阵、跑 formal（正式实验）**的阶段。

```text
你现在的任务是把当前仓库改造成“适合改进算法研究与消融实验”的标准 benchmark 框架。

研究背景：
- 当前主线是 BBO（Beaver Behavior Optimizer，河狸行为优化）改进研究
- 先做 CEC2017 / CEC2022 等 benchmark 验证
- 再做应用验证
- 当前最关心的是：公平性、可复现性、结果可分析性、消融可比性

本次任务重点不是应用层，而是 benchmark 主线。

一、你要重点建设的能力
1. baseline / improved / ablation 的统一接入方式
2. benchmark 配置集中管理
3. 支持 smoke 与 formal 两级实验
4. 多函数、多轮独立运行
5. 固定随机种子
6. 统一 FE 预算控制
7. 导出 raw runs、mean/std、best/worst、rank、p-value
8. 画 convergence curve（收敛曲线）与 boxplot（箱线图）
9. 自动生成实验摘要
10. 结果目录带时间戳与版本名

二、请先检查当前仓库有没有这些问题
1. 算法版本切换要改很多地方
2. baseline 和 improved 的接口不一致
3. 结果文件命名混乱
4. 不支持批量消融
5. 不支持统一读取结果再分析
6. 没有显著性检验
7. 只比较 improved 次数，不比较提升幅度和退化幅度
8. 没有按函数类别分组分析
9. 只控制 epoch，不控制 FE
10. formal 实验协议不清晰

三、你要实现的目标状态
1. 能通过一个主控脚本指定：
   - benchmark 套件
   - 维度
   - 运行次数
   - 种群规模
   - FE 或迭代预算
   - 算法列表
   - 模式（smoke / formal）
2. 能方便加入：
   - 原始算法
   - 完整改进版
   - 去模块消融版
   - 对照算法
3. 每次实验自动保存：
   - config
   - raw fitness
   - summary csv / xlsx
   - plots
   - log
   - 简要 markdown 报告

四、重要科研规则
1. 默认以 FE 公平性为优先，不要只用 epoch
2. smoke 仅用于健康检查，不作为论文证据
3. formal 才作为正式结论依据
4. 消融实验要能证明“哪个模块在起作用”
5. 不要只给 improved count / degraded count / net gain
6. 还要增加：
   - 提升幅度统计
   - 退化幅度统计
   - 按函数类别统计
   - 稳定性统计
   - 最终精度与收敛速度对比

五、输出要求
先不要立即改很多文件。
请先输出：
1. benchmark 主线现状诊断
2. benchmark 框架缺口
3. 消融实验框架设计方案
4. formal 实验协议草案
5. 第一批应改文件列表

六、然后再实施第一批改造
第一批只做：
1. 统一实验配置结构
2. 统一算法注册入口
3. 统一结果归档
4. 统一 smoke / formal 模式
5. 统一 summary 导出

七、注意
1. 不要把应用层任务和 benchmark 主线耦合死
2. 不要写一堆空架子
3. 只做对当前科研推进真正有帮助的模块
4. 对每个新增模块写明它支撑的是哪一类科研问题

现在开始：
先输出“benchmark 主线现状诊断 + 消融框架设计方案”。
```

------

### V4：面向肺 CT 应用接入的提示词

这个版本适合你后面把优化器和图像任务正式接上。

```text
你现在要在当前科研仓库中，为“肺 CT 图像分割与增强任务”建立一个可复用的 application layer（应用层），但前提是不能破坏 benchmark 主线。

任务目标：
把优化算法与真实图像任务通过 objective wrapper（目标函数包装器）方式解耦连接，使仓库形成：
算法层 → benchmark 层 → 应用层 → 分析层
的清晰结构。

一、总原则
1. benchmark 主线与应用主线分离
2. 应用层通过 wrapper 接入优化器，而不是把图像逻辑写死在算法内部
3. 所有医学图像处理流程模块化
4. 所有实验输出可回溯
5. 支持后续论文写法与结果复用

二、你需要规划的应用层结构
- data_io：图像与标注读取
- preprocess：预处理
- segmentation：分割
- enhancement：增强
- metrics：评价指标
- objective_wrapper：把任务封装为优化目标
- visualization：结果可视化
- runner：应用实验入口

三、你要优先考虑的实际科研需求
1. 优化器可能搜索的是：
   - 阈值参数
   - 增强参数
   - 分割参数
   - 联合参数
2. objective function 可能由多个指标组成
3. 需要保留病例级结果
4. 需要保存可视化结果
5. 需要区分训练 / 验证 / 测试或病例分组
6. 需要导出能进论文的图表与汇总表

四、请先检查仓库当前是否缺以下能力
1. 图像读写分层
2. 预处理与分割分层
3. 指标独立模块
4. objective wrapper 机制
5. 结果可视化统一保存
6. 应用实验主控脚本
7. 应用层配置文件

五、这次不要直接发明复杂业务逻辑
如果当前仓库没有完整肺 CT 数据流程，请先：
1. 搭好接口骨架
2. 预留配置项
3. 预留指标接口
4. 预留输入输出结构
5. 写清楚未来如何接真实数据
而不是编造假的数据处理逻辑

六、输出要求
先输出：
1. 应用层设计草案
2. 最小可落地目录结构
3. 需要从 benchmark 主线复用哪些能力
4. 需要单独新增哪些能力
5. 第一批建议落地文件

七、特别提醒
应用层只是验证算法价值，不要让它反向污染算法核心实现。
算法层不应直接依赖具体肺 CT 文件路径、图像格式或可视化代码。

现在开始：
先做“应用层设计草案”，不要直接写大量代码。
```

------

### V5：面向论文支撑与结果沉淀的提示词

这个版本很适合你要让 Codex 帮你把“实验结果组织能力”补齐。

```text
你现在的任务不是改进算法本身，而是把当前科研仓库增强为“更适合论文写作支撑”的实验结果沉淀系统。

目标：
让仓库在完成 benchmark 和应用实验后，能够自动产出更适合论文撰写、复核与对比的结果文件和分析材料。

一、请重点补强以下能力
1. 每次实验自动保存完整配置
2. 每次实验自动保存原始多次运行结果
3. 自动汇总 mean/std/median/best/worst
4. 自动做 rank 与显著性检验
5. 自动输出按函数类别分组的汇总
6. 自动生成收敛曲线与箱线图
7. 自动生成 markdown 摘要报告
8. 自动保存版本名、时间戳、实验模式
9. 自动记录使用的算法版本与关键参数
10. 为后续论文表格生成保留结构化中间文件

二、你要检查当前仓库是否存在这些问题
1. 结果只能看图，不能直接形成表
2. 表和图来自不同文件，难对齐
3. 版本号不清晰
4. 不记录参数
5. 不记录 seed
6. 不记录数据集 / benchmark 范围
7. 不记录 smoke / formal 区分
8. 没有统一汇总脚本

三、希望形成的结果目录示意
results/
  experiment_name/
    timestamp/
      config.*
      raw/
      summary/
      stats/
      plots/
      report/
      logs/

四、报告输出最少要包含
1. 本次实验设置
2. 算法列表
3. benchmark / 数据集范围
4. 运行次数
5. 核心统计结果
6. 改进与退化概况
7. 主要结论
8. 风险提示
9. 下一步建议

五、限制
1. 不要伪造统计结果
2. 不要凭空写论文结论
3. 只搭建真实可用的结果沉淀管线
4. 所有导出都要能追溯到原始数据

现在开始：
先分析当前结果导出系统缺了什么，再给出最小补强方案。
```

------

### 我最推荐你现在先用哪一版

结合你当前研究节奏，我更推荐：

#### 第一轮

先发 **V2（保守迭代版）**

因为你现在不是从零起仓库，而是已经在持续做版本推进，这版最不容易让 Codex 乱拆。

#### 第二轮

等 V2 跑完后，再发 **V3（benchmark + 消融实验版）**

因为你现在最核心的问题，还是：

- 如何把改进算法版本体系化
- 如何让 smoke / formal / ablation 更严谨
- 如何让结果可直接支撑论文

#### 第三轮

后面再用 **V4（lung CT 应用接入版）**

------

### 可以直接附给 Codex 的“项目级规则补丁”

这个适合追加在每一版提示词最后面。

```text
补充项目规则：

1. 命名规则
- baseline：原始算法
- improved：完整改进版
- ablation：去模块版本
- smoke：冒烟测试
- formal：正式实验
- summary：汇总结果
- raw：原始运行结果

2. 实验规则
- smoke 只用于健康检查
- formal 才用于正式比较
- 所有正式实验必须记录 seed、runs、budget、dim、pop_size
- 优先采用 FE 公平预算
- 所有结果目录必须带时间戳

3. 统计规则
- 不只比较 improved 次数
- 还要比较提升幅度、退化幅度、稳定性、收敛特征
- 尽量支持秩次与显著性检验

4. 结构规则
- 算法层、benchmark 层、应用层、分析层分离
- 应用层通过 objective wrapper 接入
- 不把肺 CT 业务逻辑写死进算法实现

5. 论文支撑规则
- 新增模块请在注释中说明其科研用途
- 输出要能支撑方法、实验、消融、局限性写作
```

------

### 给 Codex 配套的 `AGENTS.md` 建议文本

OpenAI 官方建议用简洁、准确、实用的 `AGENTS.md`，而且可以按全局、仓库、子目录分层放置，越靠近当前目录的规则优先。 ([OpenAI开发者](https://developers.openai.com/codex/learn/best-practices/?utm_source=chatgpt.com))

你这个项目很适合在仓库根目录放一个 `AGENTS.md`，可以写成：

```md
# AGENTS.md

## Project identity
This repository is for academic research, not a generic software product.
Primary goals:
1. real research progress
2. reproducible experiments
3. paper-writing support

## Core research context
- BBO always means Beaver Behavior Optimizer.
- Never reinterpret BBO as Biogeography-Based Optimization.
- Main workflow:
  baseline algorithm -> improved variants -> CEC benchmark -> ablation -> lung CT application validation -> paper-ready analysis

## Working style
- Prefer minimal necessary edits.
- Do not perform large unrelated refactors.
- Preserve existing runnable paths.
- If context is insufficient, report:
  - known facts
  - unknowns
  - provisional plan

## Architecture preference
Prefer separation of:
- optimizers
- benchmarks
- applications
- analysis
- experiments
- results

## Experiment rules
- Distinguish smoke and formal experiments.
- Formal experiments must record config, seeds, runs, budget, dimension, population size.
- Prefer FE-based fairness over epoch-only fairness.
- Save timestamped result folders.
- Keep raw results and summary results both.

## Analysis rules
Do not only count improved/degraded cases.
Also analyze:
- improvement magnitude
- degradation magnitude
- stability
- function-group behavior
- convergence characteristics

## Application rules
Application logic should connect through objective wrappers.
Do not hard-code lung CT business logic into optimizer core.

## Output rules
When modifying code, always explain:
1. what changed
2. why it changed
3. research value
4. validation method
5. next step
```

------

### Skills、聊天指令、Hooks 怎么配

你之前提过，之后给 Codex 提示词时，希望把这三类功能也考虑进去。这里我直接给你落地建议。

#### 1）Skills（技能包）

如果你在 Codex 里支持 Skills，最适合这个项目的 4 类是：

- `research-benchmark-auditor`
  - 检查 benchmark 公平性、FE、seed、runs、统计导出
- `metaheuristic-ablation-designer`
  - 设计 baseline / improved / ablation 的对照矩阵
- `lung-ct-objective-wrapper-designer`
  - 帮你规划应用层 objective wrapper
- `paper-results-packager`
  - 整理表格、图、摘要报告输出

#### 2）聊天指令（chat instructions）

适合固定成长期规则：

```text
Always treat this repository as a research codebase.
Prefer minimal changes with maximum research value.
Always distinguish confirmed facts, inferred conclusions, and suggestions.
Do not confuse Beaver Behavior Optimizer with Biogeography-Based Optimization.
Favor reproducibility, experimental fairness, and paper-ready outputs.
```

#### 3）Hooks

如果你的 Codex 环境支持 Hooks，最值得加的是：

- **pre-run hook**
  - 跑实验前自动检查：
    - seed 是否设置
    - result path 是否带时间戳
    - smoke/formal 是否区分
    - 是否保存 config
- **post-run hook**
  - 跑完后自动检查：
    - raw 是否存在
    - summary 是否导出
    - plots 是否输出
    - log 是否记录
- **pre-commit hook**
  - 检查是否误删结果目录、是否改坏核心实验入口、是否新增未说明文件

------

### 再给你一版“最适合当前阶段”的压缩版终稿提示词

如果你现在只想马上复制一版去用，我推荐这版：

```text
你现在是我的科研代码代理。请在当前仓库中做“保守型科研框架增强”，不要大规模重构。

项目背景：
- 本项目用于 BBO（Beaver Behavior Optimizer，河狸行为优化）改进研究
- 先做 CEC benchmark，再做肺 CT 图像分割与增强应用验证
- 目标优先级：真实研究推进 > 实验可复现 > 论文写作支撑 > 代码整洁
- 注意：这里的 BBO 绝不是 Biogeography-Based Optimization

本次任务：
基于当前仓库，吸收优秀科研代码框架中值得借鉴的部分，但只做最小必要改造。重点吸收：
1. 统一算法接口
2. 统一 benchmark 主控
3. 统一统计导出
4. 时间戳结果目录
5. smoke / formal 区分
6. 多次独立运行
7. 随机种子控制
8. FE 公平预算
9. objective wrapper 预留接口
10. 面向论文写作的结果沉淀

先不要直接改代码。先完成下面输出：
1. 当前仓库职责映射（算法实现 / 实验入口 / benchmark / 结果保存 / 统计分析 / 作图 / 文档）
2. 当前已经具备的科研框架能力
3. 当前缺失的关键能力
4. 最值得直接复用的部分
5. 只应借鉴思想、不应直接照搬的部分
6. 最少改动方案（按优先级排序）
7. 第一批建议改动文件列表
8. 风险与验证方法

实施规则：
- 只做高收益、低破坏改动
- 不破坏现有主线
- 新增结果目录必须带时间戳
- formal 实验必须可复现
- 尽量按 FE 而不是仅 epoch 做公平预算
- 结果不能只看 improved/degraded 次数，还要支持提升幅度、退化幅度、稳定性、函数类别表现分析
- benchmark 层与 lung CT 应用层分离
- 应用层通过 objective wrapper 接入
- 所有新增改动必须说明科研价值

请现在先输出：
“当前仓库职责映射 + 最少改动方案”，不要先大改代码。
```

------

### 这些提示词为什么会更稳

因为它们基本都贴合了 OpenAI 官方对 Codex 的几条核心建议：

- **给足项目上下文和相关文件线索**
- **让输出结构清晰、可验收**
- **通过 `AGENTS.md` 固化长期规则**
- **用更具体的任务说明替代模糊指令**
- **先分析再改动，减少代理失控式大改** ([OpenAI开发者](https://developers.openai.com/codex/prompting/?utm_source=chatgpt.com))

------

### 论文写作或修改建议

如果后面你要把“为什么这样设计 Codex 工作流”写进方法实现或系统实现部分，可以用这种论文式表达：

> 为提高算法研究过程中的实验一致性、结果可追踪性与论文撰写效率，研究过程采用分层式科研代码组织策略，将优化算法层、基准测试层、应用验证层与统计分析层进行模块化拆分，并通过统一实验入口、统一结果归档机制以及显著性统计输出流程，实现了基准测试、消融实验、应用验证和论文证据链构建的协同推进。

这个表述很适合以后放到“系统实现”或“实验平台搭建”部分。

------

### 这次你能学到什么 / 对以后有什么帮助 🌱

这次最关键的，不是“又写了几版提示词”，而是你已经开始把 **Codex 当成科研协作代理** 来用，而不是单纯代码补全工具。

可以把它理解成一个实验室里的“研究助理” 🧪：

- 提示词 = 任务书
- `AGENTS.md` = 实验室规章
- Skills = 专项助手
- Hooks = 质检流程

当这四样东西配齐后，Codex 才不容易“自作聪明乱改仓库”，而会更像一个**按科研流程办事的人**。这对你后面持续做：

- 版本迭代
- 消融实验
- formal 正式实验
- 肺 CT 应用接入
- 论文图表沉淀

都会越来越稳。📈

------

### 当前总体任务进度

**当前阶段：** 从“框架分析”进入“Codex 可执行提示词设计”阶段
**已完成：**

- 提炼了可借鉴的科研框架能力
- 转化为 5 版可直接使用的 Codex 详细提示词
- 补齐了 `AGENTS.md`、Skills、聊天指令、Hooks 的配套思路
- 给出了当前最适合你使用的压缩版终稿

**下一步最适合做的事：**
把你现在仓库的顶层目录、主实验入口文件名、算法实现文件名发我，我直接帮你把上面这几版提示词**再定制成“贴你当前仓库文件名的最终版”**，这样 Codex 会更稳。