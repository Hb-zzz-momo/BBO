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
- `archive/achieve/reference_only/`: 仅供参考的第三方大型代码包（不进入主运行路径）。

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

## 6. 框架树使用规范（与当前实现同步）

以下规范用于保证当前 CEC benchmark 主线可运行、可复现、可扩展。

### 6.1 入口分层规范（谁给人用，谁给机器用）

- 人工触发主入口固定为 `src/benchmark/cec_runner/entry/run_main_entry.m`。
- 核心执行入口为 `src/benchmark/cec_runner/core/run_experiment.m`，供入口层和脚本层调用。
- 兼容入口 `src/benchmark/cec_runner/legacy/run_experiment_unified.m` 仅用于历史脚本兼容，不作为新实验默认入口。
- 阶段流程入口放在 `src/benchmark/cec_runner/pipelines/`，用于 smoke/formal/ablation 编排，不直接承载底层路径拼接与导出细节。

### 6.2 路径解析规范（防止入口级故障）

- 任何位于 `src/benchmark/cec_runner/core/` 的脚本，计算项目根目录时必须按当前层级回溯到项目根，禁止写成会落到 `src/` 的错误层级。
- 优先复用统一路径解析函数（如 `resolve_common_paths`、`setup_benchmark_paths`），避免在多个函数里重复手写路径根逻辑。
- 禁止在核心流程中出现 `.../src/src/...` 这类双重拼接路径。
- CEC 函数目录切换应保持现有调用链不变：
  wrapper/main -> Get_Functions_cec2017 或 Get_Functions_cec2022 -> fobj -> optimizer -> cec17_func 或 cec22_func -> input_data。

### 6.3 算法登记与文件一致性规范

- `run_all_compare` 的算法 catalog 必须与真实 `.m` 文件保持一致。
- 若保留历史算法别名，必须在 catalog 中显式映射到当前真实入口函数，且在 inventory 中保留别名到真实入口的注记，确保可审计。
- pipeline 中的算法名到文件名映射（如 dual ablation 的 name_from_algorithm）必须与 catalog 同步更新，避免“配置可选但运行报缺文件”。

### 6.4 第三方基线路径隔离规范

- `src/baselines/` 中的第三方原始代码包视为外部基线资产，不参与全局 `genpath`。
- 运行算法时按“单算法 addpath -> 运行 -> rmpath”模式管理路径，防止 `initialization.m`、`main.m`、`Get_Functions_details.m` 等同名函数串扰。
- 手动调试时禁止对 `src/baselines/` 做全量递归加路径。

### 6.5 结果与复现规范

- benchmark 结果统一落盘到 `results/<suite>/<experiment_name_or_timestamp>/`。
- 每轮实验至少保存 `config.mat`、`summary.csv`、`summary.mat`、`raw_runs/`、`curves/`、`logs/`。
- 任一 runner 增加新导出项时，应同步更新 `experiments/tracking/` 与对应 README/说明文档。

### 6.6 变更边界规范（最小侵入）

- 不改算法语义，不改 CEC mex 机制，不改 benchmark 公平性协议（函数集、维度、预算、runs、指标）。
- 优先通过 wrapper、映射、配置层和导出层修复问题，避免直接重写算法体。
- 结构重构遵循“先兼容后收敛”：先保证旧入口可运行，再逐步收敛到主入口。

### 6.7 提交前检查清单

- 是否能通过 `entry/run_main_entry` 启动 smoke。
- 是否确认 repo_root 解析到项目根而非 `src/`。
- 是否确认 catalog 中每个默认算法可运行或有明确不可运行说明。
- 是否确认 pipeline 与 catalog 的算法命名一致。
- 是否确认输出目录和关键文件自动生成。
