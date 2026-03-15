### 实验资产索引表（建议放到 `experiments/tracking/artifact_index.md`）

| 资产类型 | 名称 | 路径 | 对应任务 | 是否已验证 | 备注 |
|---|---|---|---|---|---|
| code | V3 主算法代码 | `待 Codex 扫描仓库自动补全` | V3 消融实验：双目标消融 + directional 保守方向验证 | pending | 优先查找 `v3` 主算法文件 |
| code | V3 消融核心代码 | `待 Codex 扫描仓库自动补全` | V3 消融实验：双目标消融 + directional 保守方向验证 | pending | 重点查找 `ablation_core` |
| result | V3 formal 消融结果压缩包 | `对话提及：v3_dual_ablation_20260314_formal1_formal.zip（需仓库核验）` | V3 消融实验：双目标消融 + directional 保守方向验证 | pending | 名称来自对话，不应直接视为仓库事实 |
| result | V4 directional 结果压缩包 | `对话提及：v4_directional_20260314.zip（需仓库核验）` | V4 directional 主线评估 | pending | 用于支撑“为何不继续主推 v4” |
| result | V3 directional 缩减版结果 | `对话提及：v3_direction_reduced_formal.zip（需仓库核验）` | V3 消融实验：双目标消融 + directional 保守方向验证 | pending | 用于判断 directional 是否保守保留 |
| doc | 分析 README | `待 Codex 扫描仓库自动补全` | 消融实验论文章节素材沉淀 | pending | 用于挂接阶段性文字结论 |
| table | summary.csv | `待 Codex 扫描仓库自动补全` | V3 消融实验：双目标消融 + directional 保守方向验证 | pending | 核心统计证据 |
| figure | convergence / boxplot / ranking 图 | `待 Codex 扫描仓库自动补全` | 消融实验论文章节素材沉淀 | pending | 直接服务论文写作 |

