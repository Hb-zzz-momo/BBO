# 科研项目目录结构（最终版）

## 1. 项目文件树

```text
metaopt_cec_lungct_project/
├─ docs/
│  ├─ 00_project_scope/
│  ├─ 01_literature_notes/
│  ├─ 02_method_design/
│  ├─ 03_experiment_protocols/
│  ├─ 04_meeting_notes/
│  ├─ 05_paper_drafts/
│  └─ 06_submission_materials/
├─ data/
│  ├─ raw/
│  │  ├─ cec/
│  │  └─ lung_ct/
│  ├─ interim/
│  │  ├─ preprocessed/
│  │  └─ splits/
│  ├─ external/
│  └─ metadata/
├─ src/
│  ├─ baselines/
│  │  ├─ metaheuristics/
│  │  └─ segmentation_models/
│  ├─ improved/
│  │  ├─ modules/
│  │  └─ algorithms/
│  ├─ benchmark/
│  │  ├─ cec_runner/
│  │  └─ metrics/
│  ├─ medimg/
│  │  ├─ preprocessing/
│  │  ├─ enhancement/
│  │  ├─ segmentation/
│  │  └─ evaluation/
│  └─ utils/
├─ experiments/
│  ├─ configs/
│  │  ├─ benchmark/
│  │  ├─ ct_app/
│  │  ├─ ablation/
│  │  └─ sensitivity/
│  ├─ scripts/
│  │  ├─ run_benchmark/
│  │  ├─ run_ct_app/
│  │  ├─ run_ablation/
│  │  └─ run_sensitivity/
│  └─ tracking/
├─ results/
│  ├─ benchmark/
│  │  ├─ runs/
│  │  ├─ summaries/
│  │  ├─ figures/
│  │  └─ stats/
│  ├─ ct_app/
│  │  ├─ runs/
│  │  ├─ metrics/
│  │  └─ visualizations/
│  ├─ ablation/
│  └─ sensitivity/
├─ logs/
│  ├─ train/
│  ├─ inference/
│  ├─ benchmark/
│  └─ system/
├─ notebooks/
│  ├─ exploration/
│  ├─ analysis/
│  └─ plotting/
├─ reports/
│  ├─ tables/
│  ├─ figures/
│  └─ appendix/
├─ repro/
│  ├─ requirements/
│  ├─ env/
│  └─ runbook/
├─ temp/
│  ├─ drafts/
│  └─ scratch/
└─ archive/
   ├─ snapshots/
   └─ deprecated/
```

## 2. 每个目录的作用说明

- `docs/`: 项目文档主目录，聚焦研究过程可追溯。
- `docs/00_project_scope/`: 研究问题定义、目标、边界、术语表。
- `docs/01_literature_notes/`: 文献精读笔记、对比表、复现要点。
- `docs/02_method_design/`: 方法设计稿、模块说明、公式推导。
- `docs/03_experiment_protocols/`: 统一实验协议，保证可比性与公平性。
- `docs/04_meeting_notes/`: 讨论记录、阶段决策、待办项。
- `docs/05_paper_drafts/`: 论文草稿、段落备选、审稿回复草稿。
- `docs/06_submission_materials/`: 投稿清单、cover letter、补充材料。

- `data/`: 数据全生命周期管理。
- `data/raw/`: 原始数据（只读，不直接改写）。
- `data/raw/cec/`: CEC 基准定义、函数说明及原始资源。
- `data/raw/lung_ct/`: 肺 CT 原始数据。
- `data/interim/`: 中间产物。
- `data/interim/preprocessed/`: 预处理后数据。
- `data/interim/splits/`: 训练/验证/测试划分文件。
- `data/external/`: 外部公开数据或第三方资源。
- `data/metadata/`: 数据版本、来源、授权、统计信息。

- `src/`: 研究核心代码。
- `src/baselines/`: 基线方法代码，保持原始可比版本。
- `src/improved/`: 改进算法及其模块，和基线清晰分离。
- `src/benchmark/`: CEC 统一测试入口、指标计算。
- `src/medimg/`: 医学图像流程代码（预处理、增强、分割、评估）。
- `src/utils/`: 通用工具函数（I/O、seed、日志、绘图辅助）。

- `experiments/`: 实验编排层。
- `experiments/configs/`: 参数配置（基准、应用、消融、敏感性）。
- `experiments/scripts/`: 一键运行脚本，按实验类型分目录。
- `experiments/tracking/`: 运行清单、实验索引、对照关系。

- `results/`: 结果主目录，按任务类型严格分层。
- `results/benchmark/`: CEC 实验结果（原始 run、汇总、图、统计检验）。
- `results/ct_app/`: CT 应用结果（预测、指标、可视化）。
- `results/ablation/`: 消融实验结果。
- `results/sensitivity/`: 参数敏感性实验结果。

- `logs/`: 各类日志，便于故障回溯和实验追踪。
- `notebooks/`: 仅用于探索分析与作图，不作为主流程执行入口。
- `reports/`: 论文图表素材和附录输出区。
- `repro/`: 复现支持（依赖、环境描述、复现实验手册）。
- `temp/`: 临时文件与草稿，定期清理。
- `archive/`: 阶段归档与废弃版本，避免污染主目录。

## 3. 命名规范建议

- 文件夹命名规则:
  - 全部使用小写字母 + 下划线，例如 `run_benchmark`。
  - 按“任务域/用途”命名，不用模糊名（如 `misc`、`new`）。
- 文件命名规则:
  - 代码文件使用“动作+对象”，例如 `evaluate_ct_metrics.py`。
  - 配置文件使用“实验类型+关键参数”，例如 `cec_bbo_d30_fes1e5.yaml`。
  - 文档使用“主题+版本”，例如 `method_overview_v1.md`。
- 日期是否加入文件名:
  - 需要审计或阶段性文档时加入日期，格式 `YYYYMMDD`。
  - 稳定主文件不要带日期，避免频繁重命名。
- 实验结果如何编号:
  - 建议统一 `exp-{task}-{algo}-{id}`，例如 `exp-cec-ibbo-003`。
  - 每次运行附带 seed 与时间戳，例如 `seed2026_t20260312_1430`。
- 论文图片、表格、代码、日志统一命名:
  - 图片: `fig_{chapter}_{topic}_{ver}.png`，如 `fig_exp_convergence_v2.png`。
  - 表格: `tab_{chapter}_{topic}_{ver}.csv`。
  - 代码: `module_{purpose}.py`。
  - 日志: `log_{exp_id}_{seed}.txt`。

## 4. 针对科研项目的特别建议

- 文献阅读:
  - 在 `docs/01_literature_notes/` 维护“方法-优缺点-可复现性”三列对比表。
- 论文写作:
  - 在 `docs/05_paper_drafts/` 按章节拆分，避免单大文件冲突。
- 数据集:
  - 原始数据固定到 `data/raw/`，中间数据统一进入 `data/interim/`。
- 预处理:
  - 预处理参数必须写入 `experiments/configs/` 并保存到 `results/*/runs/`。
- 算法源码:
  - 基线和改进分离到 `src/baselines/` 与 `src/improved/`。
- 实验脚本:
  - 按任务类型拆分到 `experiments/scripts/`，脚本与配置解耦。
- 对比实验:
  - 对比关系记录到 `experiments/tracking/`，避免后期混淆。
- 消融实验:
  - 每个消融项单独配置文件，输出到 `results/ablation/`。
- 日志:
  - 运行日志与系统日志分开，统一 `logs/` 管理。
- 可视化结果:
  - 草图放 `results/*/visualizations/`，论文终稿图复制到 `reports/figures/`。
- 投稿材料:
  - 所有投稿相关文件只放 `docs/06_submission_materials/`。
- 临时草稿和归档:
  - 临时内容进入 `temp/`，阶段完成后迁移到 `archive/`。

## 5. 适用阶段、必须/可选目录、扩展策略

- 这套目录适合什么阶段使用:
  - 适合从“选题与基线复现”到“论文投稿”全过程。
  - 对单人长期项目尤其友好，能兼顾执行效率与可追溯。

- 哪些目录是必须的:
  - 必须: `docs/`, `data/`, `src/`, `experiments/`, `results/`, `logs/`, `repro/`。
  - 可选: `notebooks/`, `reports/`, `temp/`, `archive/`（建议保留，但可按阶段启用）。

- 如果后面研究方向变化，目录应该怎么扩展:
  - 新增算法方向: 在 `src/improved/algorithms/` 下增加独立子目录，不改历史路径。
  - 新增数据集: 在 `data/raw/` 与 `data/interim/` 各加同名子目录。
  - 新增任务类型: 在 `experiments/configs/`、`experiments/scripts/`、`results/` 中平行新增同名目录。
  - 新论文主题: 在 `docs/05_paper_drafts/` 新建子目录（按论文或会议名区分）。
