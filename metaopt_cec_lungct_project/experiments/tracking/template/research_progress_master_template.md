### 科研总进度表（建议放到 `experiments/tracking/research_progress_master.md`）

## 当前总览

- 项目主线：BBO/HHO 改进算法 + CEC 基准测试 + 肺 CT 应用验证
- 当前阶段：V3 消融实验分析
- 当前主问题：在保持复杂函数表现的前提下，补简单函数收敛能力
- 当前决策状态：V3 暂定继续作为主线，directional 模块保守触发思路待 formal 进一步验证

## 主进度表

| 进度ID | 阶段 | 任务名称 | 当前状态 | 目标 | 当前结论 | 下一步 | 更新时间 |
|---|---|---|---|---|---|---|---|
| P-001 | improved_version | BBO/HHO baseline 对齐与统一测试入口 | done | 保证 baseline 与改进版可公平对比 | 已具备后续消融与 formal 对比基础 | 保持接口稳定 | 2026-03-15 |
| P-002 | ablation | V3 消融实验：双目标消融 + directional 保守方向验证 | analyzing | 提升简单函数收敛，同时不破坏复杂函数表现 | 当前倾向：V3 主线比更激进的 directional 版本更稳；directional 更适合条件触发而非全程注入；下一轮重点应偏向简单函数收敛增强 | 先做小规模 smoke，筛掉弱方向，再进入 formal | 2026-03-15 |
| P-003 | improved_version | V4 directional 主线评估 | archived | 判断是否转向 v4 | 当前不建议作为主线继续扩写 | 保留为对照，不再主推 | 2026-03-15 |
| P-004 | paper_support | 消融实验论文章节素材沉淀 | running | 把实验目的、设计、结果、结论沉淀为论文素材 | 已形成“为什么继续 V3、为什么限制 directional”的叙事框架 | 跟随 formal 结果补表格与图 | 2026-03-15 |

## 当前主线详情：V3 消融实验

### 任务卡

- **任务名**：V3 消融实验：双目标消融 + directional 保守方向验证
- **阶段**：ablation
- **状态**：analyzing
- **研究目标**：
  1. 提升简单函数/单峰函数收敛精度
  2. 避免 directional 机制对复杂函数造成负迁移
  3. 为进入 formal 版改进提供依据

### 当前结论拆分

#### 事实
- 已围绕 V3 / V4 / directional / dual ablation 连续做过多轮分析。
- 当前研究讨论已形成一个较稳定判断：**V3 主线优于继续激进扩写 V4**。
- 当前讨论主轴已从“继续堆 directional 模块”转向“补简单函数收敛能力”。

#### 推断
- directional 引导更适合做成**条件触发模块**，例如停滞检测后触发，而不是默认主驱动。
- 进入下一轮实验时，优先考虑“轻量增强 exploitation（开发/局部精修）”而不是大幅改变全局搜索骨架。

#### 待验证
- V3 在 formal 条件下，对简单函数提升是否稳定显著。
- directional 缩减版在复杂函数上的负面影响是否已下降到可接受范围。
- 是否需要新的局部搜索模块替代当前 directional 方案。

### 下一步最小闭环

1. 做一轮 `simple-function convergence smoke`
2. 对入围模块做 `formal ablation`
3. 固定统一预算后更新 summary、排名、箱线图、收敛图
4. 沉淀成消融实验小节草稿

