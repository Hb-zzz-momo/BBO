### 已完成的第一步

我已经先把压缩包解开并看了目录。
这份压缩包里**只有 `src/` 源码层**，**没有**一起打包进来：

- `third_party/`（第三方原始算法包）
- `external_assets/`（CEC 的 mex 二进制和 `input_data`）
- `results/`（实验结果）
- 文档里提到的部分 `experiments/scripts/` 入口

所以这次能做的是：**把源码结构、作用、主流程、修改入口讲清楚**；
不能做的是：**把整套 MATLAB 基准测试链路当场确认运行成功**。

------

### 1. 项目总览

#### 先给结论

**确定：** 这不是一个普通软件项目，而是一个**科研实验代码骨架**，主线明显是：

- **BBO 改进算法研究**
- **CEC benchmark（基准测试）实验编排**
- **v3/v4 版本对比**
- **ablation（消融实验）**
- **metrics（评价指标）与导出**
- **medimg（医学图像）应用验证目录预留**

#### 这个项目大概率在做什么

**确定：** 当前代码主战场是 `src/benchmark/cec_runner` 和 `src/improved/algorithms/BBO`。
说明这个项目当前主要在做：

1. 组织多算法在 **CEC2017 / CEC2022** 上跑实验
2. 对 BBO 的多个改进版本做对比
3. 做 v3 主线的机制拆分与消融
4. 输出统计表、显著性检验、收敛曲线等结果
5. 为后续论文写作提供结果导出

#### 使用了什么语言 / 工具

**确定：**

- **主语言：MATLAB**（`.m` 文件占主导）
- **辅助语言：Python**（只有一个 SBO Python demo 子包）
- **工具特征：**
  - MATLAB 路径管理（`addpath`）
  - CEC benchmark 接口
  - 统计导出（CSV / XLSX / MAT / Markdown）
  - 绘图模块（收敛曲线、箱线图、Friedman 雷达图）

#### 属于哪类项目

**确定：**

- **算法实验 / 科研代码项目**
- 不是后端服务
- 不是前端项目
- 不是完整深度学习训练工程
- 也不是完整肺 CT 分割系统落地代码

#### 项目的核心目标是什么

**确定：** 从代码结构和 README 来看，当前核心目标是：

> 构建一个可复现的 BBO 改进算法实验框架，在 CEC 基准上完成 baseline（基线）、improved method（改进方法）、ablation（消融实验）、metrics（统计评价）和 export（结果导出）。

**确定：** `medimg/segmentation/README.md` 明确写了该目录“暂未启用”，仅作为未来肺 CT 应用验证路径。
所以**目前主线不是 CT 分割实现本身，而是优化算法实验框架**。

------

### 2. 项目文件树

下面是我按二级到三级整理后的目录树，重点文件已经保留：

```text
src/
    adapters/
        README.md

    baselines/
        metaheuristics/
            BBO/
                README.md
            SBO/
                README.md
                Status_based_Optimization_SBO_python_code_extracted/
                    SBO-benchmark-demo-python/
                        requirements.txt
                        run_exp.py
                        sbo.py
                        cec2017/
        other_metaheuristics/
            README.md
        segmentation_models/
            README.md

    benchmark/
        cec_runner/
            README.md
            compat/
                README.md
                unifrnd.m
            config/
                algorithm_alias_map.m
                algorithm_registry.m
                default_experiment_config.m
                resolve_algorithm_alias.m
                resolve_experiment_mode.m
                stage_profiles.m
            core/
                README.md
                normalize_config.m
                resolve_mode.m
                run_all_compare.m
                run_experiment.m
                run_suite_batch.m
                setup_benchmark_paths.m
                private/
                    rac_*.m（大量内部执行/保存/绘图/统计辅助函数）
            docs/
                README_ablation_flow.md
                README_benchmark_flow.md
                README_entrypoints.md
                REFACTOR_MAPPING.md
            entry/
                README.md
                run_main_entry.m
            export/
                export_benchmark_aggregate.m
                export_experiment_summary_md.m
                localize_output_files_zh.m
                save_protocol_snapshot.m
            legacy/
                README.md
                run_compare_sbo_bbo.m
                run_experiment_unified.m
            pipeline_common/
                build_formal_cfg.m
                build_smoke_cfg.m
                fill_common_stage_cfg.m
                run_phase_via_core.m
                run_phase_via_unified.m
                save_stage_report.m
                write_stage_scan.m
            pipelines/
                run_bbo_research_pipeline.m
                run_v3_direction_reduced_ablation.m
                run_v3_dual_objective_ablation.m
            tools/
                check_path_collisions.m
                selfcheck_runner_integrity.m

        metrics/
            metrics_average_tie_ranks.m
            metrics_build_aggregate_table.m
            metrics_build_friedman_tables.m
            metrics_build_rank_table.m
            metrics_build_wilcoxon_rank_sum_table.m
            metrics_extract_scores.m

    improved/
        algorithms/
            BBO/
                BBO_improved_v1.m
                BBO_improved_v2.m
                BBO_improved_v3.m
                BBO_improved_v3_ablation_core.m
                BBO_improved_v4.m
                BBO_v3_baseline.m
                BBO_v3_dir_small_step.m
                BBO_v3_dir_small_step_late_local_refine.m
                BBO_v3_dir_small_step_gate_late_local_refine.m
                BBO_v3_dir_stag_only.m
                BBO_v3_dir_stag_bottom_half.m
                BBO_v3_dir_stag_bottom_half_late_refine.m
                BBO_v3_dir_clipped_stag_bottom_half_late_refine.m
                README.md
                algorithm_groups.m
        modules/
            README.md
            BBO/
                apply_simple_modules.m
                directional_update.m
                diversity_metric.m
                local_refine.m
                mode_config_factory.m
                stagnation_detector.m

    medimg/
        enhancement/
            README.md
        evaluation/
            README.md
        preprocessing/
            README.md
        segmentation/
            README.md

    utils/
        README.md
```

------

### 3. 关键目录与文件作用说明

#### `benchmark/cec_runner/`

这是**当前项目的实验调度中心**。

- `entry/run_main_entry.m`
  - **确定：** 人类推荐主入口
  - 只负责把调用引到 `core/run_experiment.m`
- `core/run_experiment.m`
  - **确定：** 当前统一主入口
  - 做的事情是：配置标准化 → 模式解析 → 执行 → 导出
- `core/run_all_compare.m`
  - **确定：** 真正的核心执行引擎
  - 它会按“suite → function → algorithm → run”四层循环跑实验
- `config/*.m`
  - 配置默认值、模式解析、算法注册、别名映射、阶段模板
- `pipelines/*.m`
  - 阶段脚本
  - 更像“科研工作流入口”，不是最底层执行器
- `pipeline_common/*.m`
  - 给多个 pipeline 复用的公共壳
- `export/*.m`
  - 负责把结果整理成 CSV / XLSX / MAT / Markdown
- `tools/*.m`
  - 自检和路径冲突检查

#### `benchmark/metrics/`

这是**统计指标层**。

- `metrics_build_aggregate_table.m`
  - 按算法聚合 mean / std / runtime / used_FEs
- `metrics_build_wilcoxon_rank_sum_table.m`
  - Wilcoxon 秩和检验
- `metrics_build_friedman_tables.m`
  - Friedman 检验
- `metrics_build_rank_table.m`
  - 算法排名表

#### `improved/algorithms/BBO/`

这是**BBO 改进算法实现层**。

- `BBO_improved_v1.m ~ v4.m`
  - 各版本改进算法
- `BBO_improved_v3_ablation_core.m`
  - **非常关键**
  - v3 消融实验的共享核心
- `BBO_v3_*.m`
  - 很多是**薄包装（wrapper，封装壳）**
  - 本质上只是把不同 `mode` 传给 `BBO_improved_v3_ablation_core`

#### `improved/modules/BBO/`

这是**v3 模块化拆分层**。

- `mode_config_factory.m`
  - 不同 ablation 模式的参数工厂
- `apply_simple_modules.m`
  - 简单函数加速模块
- `directional_update.m`
  - 条件触发的方向引导模块
- `local_refine.m`
  - 后期局部精修模块
- `stagnation_detector.m`
  - 停滞检测
- `diversity_metric.m`
  - 种群多样性度量

#### `baselines/`

这是**基线 / 对照目录**，但当前更像“适配说明层”。

- `baselines/metaheuristics/BBO/README.md`
  - **确定：** 这里只保留说明，不放真实 BBO 原始源码
  - 真正第三方 BBO 在 `third_party/bbo_raw/...`
- `baselines/metaheuristics/SBO/.../SBO-benchmark-demo-python/`
  - **确定：** 这里有一个可独立跑的 Python SBO demo
  - 但它**不是当前 MATLAB 主 benchmark runner 的直接入口**

#### `medimg/`

这是**医学图像应用验证预留层**。

- 目前四个子目录都只有 README
- **确定：暂未启用**

#### `utils/`

- 预留公共工具层
- **确定：暂未启用**

------

### 4. 项目运行主流程

#### 主 benchmark 执行链

最主的执行链是：

```text
entry/run_main_entry.m
    -> core/run_experiment.m
        -> core/setup_benchmark_paths.m
        -> core/normalize_config.m
        -> core/resolve_mode.m
        -> core/run_suite_batch.m
            -> core/run_all_compare.m
                -> private/rac_resolve_common_paths.m
                -> private/rac_build_suite_api.m
                -> private/rac_build_algorithm_inventory.m
                -> 对每个 suite / function / algorithm / run 循环执行
                -> private/rac_save_single_run.m
                -> private/rac_save_curve_file.m
                -> private/rac_build_summary_table.m
                -> private/rac_generate_result_figures.m
        -> export/save_protocol_snapshot.m
        -> export/export_benchmark_aggregate.m
        -> export/export_experiment_summary_md.m
```

#### 算法执行层的真实逻辑

在 `run_all_compare.m` 里，核心是这几层循环：

```text
对每个 suite（cec2017 / cec2022）
    对每个 function_id
        通过 suite_api 拿到 lb / ub / dim / fobj
        对每个 algorithm
            构造算法路径与元信息
            对每个 run_id
                设置随机种子
                包装 counted objective（函数评估次数计数器）
                调用具体算法
                保存单次结果
        汇总 summary
        画图
        导出统计
```

#### v3 消融链

如果走消融变体，则链路大概是：

```text
pipelines/run_v3_*.m
    -> pipeline_common/run_phase_via_core.m
        -> core/run_experiment.m
            -> run_all_compare.m
                -> 调用某个 BBO_v3_xxx 包装器
                    -> BBO_improved_v3_ablation_core.m
                        -> mode_config_factory.m
                        -> apply_simple_modules.m
                        -> stagnation_detector.m
                        -> diversity_metric.m
                        -> directional_update.m
                        -> local_refine.m
```

------

### 5. 如何运行这个项目

### 先说最重要的判断

#### MATLAB 主链能不能直接用这个 `src.zip` 跑？

**不能确认。**

而且从代码看，**大概率不能直接独立跑通**，原因是：

- `rac_resolve_common_paths.m` 明确要求存在：
  - `third_party/sbo_raw/...`
  - `third_party/bbo_raw/...`
  - `external_assets/mex_bin/cec2017`
  - `external_assets/mex_bin/cec2022`
- 但这次压缩包里**没有这些目录**

所以：

- **确定：** 当前 `src.zip` 不是完整可执行仓库
- **推断：** 它是从完整研究仓库里抽出来的源码层

#### MATLAB 主链的暂定运行方式（推断）

如果补齐完整仓库结构，主入口应该是：

```matlab
addpath('src/benchmark/cec_runner/entry');
cfg = struct();
cfg.mode = 'smoke';
report = run_main_entry(cfg);
```

或者直接跑 pipeline：

```matlab
addpath('src/benchmark/cec_runner/pipelines');
report = run_bbo_research_pipeline();
```

以及：

```matlab
report = run_v3_direction_reduced_ablation();
report = run_v3_dual_objective_ablation();
```

#### 运行环境要求（推断 + 部分确定）

**确定：**

- 需要 MATLAB
- 需要第三方 BBO 原始包
- 需要 CEC 函数相关 mex / runtime 数据

**推断：**

- 需要 MATLAB 路径能访问完整 repo root
- 需要 `input_data` 在 CEC 运行目录可读
- 需要 Excel 写出功能（若使用 `writetable(..., xlsx)`）

#### Python SBO demo 的运行方式（确定）

这个子目录相对独立：

```bash
cd src/baselines/metaheuristics/SBO/Status_based_Optimization_SBO_python_code_extracted/SBO-benchmark-demo-python
pip install -r requirements.txt
python run_exp.py
```

**确定：**

- `requirements.txt` 只有 `numpy==1.26.4`
- `run_exp.py` 会调用 `sbo.py`
- 自带 `cec2017/` Python 包

------

### 6. 代码结果与输出说明

#### MATLAB 主链理论输出什么

**确定：** 从保存函数名和导出函数名看，运行后会生成：

- 单次运行结果
- 收敛曲线
- 汇总表
- 聚合统计表
- 排名表
- 显著性检验表
- 图像
- 协议快照
- Markdown 摘要

#### 结果目录结构

**确定：** 默认结果树有两种：

1. 默认：

```text
results/<suite>/<experiment_name>/
```

1. pipeline 统一树：

```text
results/<result_group>/<experiment_name>/<suite>/
```

#### 子目录与文件

**确定：** `rac_init_result_dirs.m` 会建立：

- `tables/`
- `raw_runs/`
- `curves/`
- `logs/`
- `figures/`

#### 核心输出文件

**确定：**

- `summary.csv` / `summary.mat`
  - 每个算法在每个函数上的 best / mean / std / worst / median / avg_runtime / avg_used_FEs
- `run_manifest.csv`
  - 每次运行的清单
- `raw_runs/*.mat`
  - 单次运行结果结构体
- `curves/*_curve.mat` / `*_curve.csv`
  - 每次运行的收敛曲线
- `aggregate_stats.csv`
  - 算法级聚合统计
- `rank_table.csv`
  - 排名表
- `wilcoxon_rank_sum.csv`
  - Wilcoxon 检验结果
- `friedman_summary.csv`
  - Friedman 检验摘要
- `friedman_ranks.csv`
  - Friedman 平均秩
- `summary_exports.xlsx`
  - 汇总导出 Excel
- `aggregate_exports.mat`
  - 统计结果 MAT 文件
- `protocol_snapshot.mat` / `protocol_snapshot.csv`
  - 这次实验协议快照，适合复现
- `experiment_summary.md`
  - 中文摘要

#### 哪些结果最重要

最重要的是：

1. `summary.csv`
2. `aggregate_stats.csv`
3. `rank_table.csv`
4. `wilcoxon_rank_sum.csv`
5. `friedman_summary.csv`
6. `protocol_snapshot.csv`

中间产物主要是：

- `raw_runs/*.mat`
- `curves/*.csv`
- `logs/*.txt`

------

### 7. 核心代码详细讲解

### `benchmark/cec_runner/entry/run_main_entry.m`

#### 文件作用

给人直接调用的主入口。

#### 为什么它重要

因为它定义了“从哪里开始看”最省力。

#### 主要内容

它只做三件事：

1. 如果没传 `cfg`，就建一个空结构体
2. 计算当前文件路径
3. `addpath(core)` 后调用 `run_experiment(cfg)`

#### 输入

- `cfg` 配置结构体

#### 输出

- `report` 实验报告结构体

#### 和其他文件的关系

它不实现实验逻辑，只负责把人带到核心入口。

------

### `benchmark/cec_runner/core/run_experiment.m`

#### 文件作用

统一 benchmark 主入口。

#### 为什么它重要

这是整个系统的“总调度器”。

#### 它做了什么

1. `setup_benchmark_paths()`：初始化路径
2. `normalize_config(cfg)`：补默认配置
3. `resolve_mode(cfg)`：把 smoke/formal 配成真正 run_cfg
4. `run_suite_batch(run_cfg)`：执行
5. 保存 protocol snapshot
6. 调 `export_benchmark_aggregate` 做统计导出

#### 输入

- `cfg`

#### 输出

- `report.input_cfg`
- `report.run_cfg`
- `report.mode_info`
- `report.output`
- `report.exports`

#### 关系

它上接 `entry/`，下接 `run_all_compare.m` 和 `export/`

------

### `benchmark/cec_runner/core/run_all_compare.m`

#### 文件作用

真正执行多算法、多函数、多次重复实验。

#### 为什么它重要

这是**实验公平性主心脏**。

#### 主要逻辑

- 生成 suite API
- 生成算法清单
- 对每个测试函数获取 `lb, ub, dim, fobj`
- 对每个算法设置路径
- 对每次运行设置种子
- 包 objective 计数器
- 调算法
- 记录 best score、best position、curve、runtime、used_FEs
- 汇总并画图

#### 输入

- `cfg`，里面包括：
  - suites
  - algorithms
  - dim
  - pop_size
  - maxFEs
  - runs
  - func_ids

#### 输出

- `output.suite_results`

#### 和其他文件关系

它依赖大量 `core/private/rac_*` 辅助函数。

------

### `improved/algorithms/BBO/BBO_improved_v3.m`

#### 文件作用

v3 主线改进算法。

#### 为什么它重要

这是当前改进 BBO 的一个关键正式版本。

#### 核心思路

- 前半部分保留基础 BBO 更新风格
- 每轮末尾加一个 **elite differential local search（精英差分局部搜索）**

#### 输入

- `N`
- `Max_iteration`
- `lb, ub`
- `dim`
- `fobj`

#### 输出

- `best_fitness`
- `best_solution`
- `Convergence_curve`

#### 关系

- 是 v3 baseline / improved line 的核心实现
- `BBO_v3_baseline.m` 直接调它

------

### `improved/algorithms/BBO/BBO_improved_v3_ablation_core.m`

#### 文件作用

v3 消融共享核心。

#### 为什么它重要

这几乎就是“论文机制归因实验中心”。

#### 主要机制

- 基础更新
- `apply_simple_modules`
- `stagnation_detector`
- `diversity_metric`
- `directional_update`
- `local_refine`

#### 输入

和 v3 类似，但多一个：

- `mode`

#### 输出

- `best_fitness`
- `best_solution`
- `Convergence_curve`

#### 关系

所有 `BBO_v3_dir_xxx.m` 包装器都在调它。

------

### `improved/modules/BBO/mode_config_factory.m`

#### 文件作用

把不同 ablation 模式翻译成参数开关。

#### 为什么它重要

这是“改哪个模块、开什么开关”的总控位。

#### 主要内容

比如：

- `dir_small_step`
- `dir_stag_only`
- `dir_stag_bottom_half`
- `dir_stag_bottom_half_late_refine`
- `dir_clipped_stag_bottom_half_late_refine`

每个模式都会设置：

- 是否启用方向引导
- 是否仅停滞触发
- 是否只替换 bottom half（后半种群）
- 是否启用 clipped step（截断步长）
- 是否启用 late local refine（后期局部精修）

#### 关系

它直接喂给 `BBO_improved_v3_ablation_core.m`

------

### 8. 关键语法讲解

### 语法 1：`if nargin < 1`

#### 原写法

```matlab
if nargin < 1
    cfg = struct();
end
```

#### 中文含义

如果调用函数时没有传第一个参数，就给它一个默认空配置。

#### 在这里的作用

让入口函数既能“无参数直接跑”，也能“传配置精细跑”。

#### 为什么这样写

科研代码常需要快速试跑，所以不能每次都手动构造完整配置。

#### 新手理解

`nargin` 就是“传进来了几个参数”。

#### 小例子

```matlab
function hello(name)
    if nargin < 1
        name = 'world';
    end
    disp(name);
end
```

------

### 语法 2：`addpath(fullfile(...))`

#### 原写法

```matlab
addpath(fullfile(runner_dir, 'core'));
```

#### 中文含义

把某个目录加到 MATLAB 的函数搜索路径里。

#### 在这里的作用

让 MATLAB 能找到 `run_experiment.m` 等文件。

#### 为什么这样写

科研项目目录层级深，不加路径就找不到函数。

#### 新手理解

相当于告诉 MATLAB：“去这个文件夹里找函数”。

------

### 语法 3：函数句柄 `@(x)`

#### 原写法

```matlab
fobj = @(x) rac_eval_objective_in_suite_dir(raw_fobj, runtime_dir, x);
```

#### 中文含义

定义一个匿名函数（临时函数）。

#### 在这里的作用

把原始目标函数再包一层，统一运行目录和调用方式。

#### 为什么这样写

CEC 函数依赖运行目录和 `input_data`，所以不能直接裸调。

#### 小例子

```matlab
square = @(x) x^2;
y = square(3);   % 9
```

------

### 语法 4：`onCleanup(@() ...)`

#### 原写法

```matlab
cleanup_obj = onCleanup(@() cd(old_dir));
```

#### 中文含义

函数退出时自动执行清理动作。

#### 在这里的作用

即使中间报错，也能自动切回原目录。

#### 为什么这样写

实验代码经常切路径、加路径，不清理会把环境弄乱。

#### 新手理解

像“离开房间前自动关灯”。

------

### 语法 5：`if any(size(lb) == 1)`

#### 原写法

```matlab
if any(size(lb) == 1)
    lb = lb .* ones(1, dim);
    ub = ub .* ones(1, dim);
end
```

#### 中文含义

如果上下界是单个数，就把它扩展成每一维都有的向量。

#### 在这里的作用

让算法同时兼容：

- 标量边界
- 向量边界

#### 为什么这样写

有的 benchmark 用统一上下界，有的每维边界不同。

#### 小例子

如果 `lb = -100`，`dim = 5`，那就变成：

```matlab
[-100 -100 -100 -100 -100]
```

------

### 语法 6：`repmat(template, 1, n)`

#### 原写法

```matlab
inventory = repmat(template, 1, numel(alg_list));
```

#### 中文含义

按模板预先创建一组结构体。

#### 在这里的作用

避免边循环边动态扩容，结构更稳。

#### 为什么这样写

科研代码会频繁保存很多 run result，预分配更清晰。

------

### 9. 我应该优先阅读哪些文件

#### 第一步：先看框架入口

1. `src/benchmark/cec_runner/README.md`
2. `src/benchmark/cec_runner/docs/README_benchmark_flow.md`
3. `src/benchmark/cec_runner/docs/README_entrypoints.md`

**为什么：** 先建立大地图，不然直接看算法文件会迷路。

#### 第二步：再看真正执行链

1. `src/benchmark/cec_runner/entry/run_main_entry.m`
2. `src/benchmark/cec_runner/core/run_experiment.m`
3. `src/benchmark/cec_runner/core/run_all_compare.m`

**为什么：** 这三份文件决定“实验到底怎么跑”。

#### 第三步：看配置层

1. `default_experiment_config.m`
2. `resolve_experiment_mode.m`
3. `algorithm_registry.m`
4. `algorithm_alias_map.m`

**为什么：** 你会明白哪些算法会被选中、名字怎么映射、smoke/formal 怎么切。

#### 第四步：看改进算法主线

1. `BBO_improved_v3.m`
2. `BBO_improved_v3_ablation_core.m`

**为什么：** v3 是当前主线核心。

#### 第五步：看模块拆分

1. `mode_config_factory.m`
2. `directional_update.m`
3. `local_refine.m`
4. `apply_simple_modules.m`

**为什么：** 这部分最适合写论文机制描述，也最适合继续改。

#### 第六步：看 pipeline

1. `run_bbo_research_pipeline.m`
2. `run_v3_direction_reduced_ablation.m`
3. `run_v3_dual_objective_ablation.m`

**为什么：** 这决定你的实验批量工作流。

------

### 10. 如果我要修改代码，应该从哪里入手

#### 如果要改算法机制

优先看：

- `src/improved/algorithms/BBO/BBO_improved_v3.m`
- `src/improved/algorithms/BBO/BBO_improved_v3_ablation_core.m`
- `src/improved/modules/BBO/*.m`

#### 如果要改参数

优先看：

- `src/improved/modules/BBO/mode_config_factory.m`
- `src/benchmark/cec_runner/config/default_experiment_config.m`
- `src/benchmark/cec_runner/config/stage_profiles.m`

#### 如果要改实验选哪些算法

优先看：

- `algorithm_registry.m`
- `algorithm_alias_map.m`
- `pipelines/*.m` 里的 `candidate_algorithms` / `comparison_algorithms`

#### 如果要改结果输出

优先看：

- `export/export_benchmark_aggregate.m`
- `export/export_experiment_summary_md.m`
- `benchmark/metrics/*.m`

#### 如果要改结果目录结构

优先看：

- `rac_compute_result_root.m`
- `rac_init_result_dirs.m`

#### 如果要调试报错

优先看：

- `setup_benchmark_paths.m`
- `rac_resolve_common_paths.m`
- `rac_build_suite_api.m`
- `rac_build_algorithm_inventory.m`

#### 如果要新增一个算法

通常要接这几层：

1. 真正算法文件放到合适目录
2. 在 `algorithm_alias_map.m` 注册名字
3. 在 `algorithm_registry.m` 的 profile 里加入
4. 在 `rac_build_algorithm_inventory.m` 的 catalog 里补路径和 entry

------

### 11. 当前项目存在的潜在问题或阅读风险

### 1）这是源码层，不是完整运行仓库

**确定：** 当前压缩包没有 `third_party/` 和 `external_assets/`。
所以主 benchmark runner 依赖不全。

### 2）基线代码和主 runner 有“仓库分层断裂”

**确定：**

- `baselines/metaheuristics/BBO/README.md` 说真实 BBO 在 `third_party/bbo_raw`
- `rac_build_algorithm_inventory.m` 也明确去 `third_party` 找 BBO/SBO/MGO/PLO

这说明：

- `src/baselines/` 更像说明层
- 真正跑实验的原始算法不在这个包里

### 3）Python SBO demo 不是主 MATLAB runner 的直接组成部分

**确定：** Python demo 在 `src/baselines/.../SBO-benchmark-demo-python/`
**确定：** 但 `rac_build_algorithm_inventory.m` 期望的是 `third_party/sbo_raw/...` 的 MATLAB 版本 SBO。

所以：

- 这个 Python demo 更像参考实现 / 轻量对照
- 不是当前主流水线直接调的版本

### 4）`medimg/` 还没有真正落地

**确定：** 全是 README，没有实现代码。
所以当前还谈不上“肺 CT 分割模块已经写好”。

### 5）文档提到的部分入口在压缩包里缺失

**确定：** `README_entrypoints.md` 里写了：

- `experiments/scripts/run_benchmark/run_benchmark.m`
- `experiments/scripts/run_benchmark/run_smoke_selfcheck.m`
- `experiments/scripts/run_ablation/run_ablation.m`

但这次压缩包里没有这些文件。

这说明：

- 要么源码抽包不完整
- 要么文档比当前包更新 / 更旧

### 6）`run_v3_dual_objective_ablation.m` 存在高风险命名问题

**确定：** 这个文件内部定义了局部函数：

- `build_smoke_cfg(cfg)`
- `build_formal_cfg(cfg)`

但函数体里又写：

```matlab
smoke_cfg = build_smoke_cfg(...)
formal_cfg = build_formal_cfg(...)
```

**推断：** 在 MATLAB 里这很可能会优先解析成**对自身局部函数的再次调用**，从而触发：

- 参数数目错误
- 或递归 / 调用冲突问题

这一点我建议你后续**优先核查**。
这是目前我看到的最值得先查的结构性风险点之一。

### 7）路径与同名函数冲突风险较高

**确定：** 项目专门写了：

- `tools/check_path_collisions.m`
- `rac_validate_algorithm_path_resolution.m`

说明作者自己也意识到：
不同算法目录下可能有同名入口或依赖冲突。

------

### 12. 最后给你一份“新手友好总结”

#### 这个项目一句话在做什么

这是一套**以 MATLAB 为主的 BBO 改进算法科研实验框架**，当前重点是 **CEC 基准测试、v3/v4 改进与消融分析、统计导出**，医学图像部分还处于预留阶段。

#### 最关键的 5 个文件

1. `src/benchmark/cec_runner/entry/run_main_entry.m`
2. `src/benchmark/cec_runner/core/run_experiment.m`
3. `src/benchmark/cec_runner/core/run_all_compare.m`
4. `src/improved/algorithms/BBO/BBO_improved_v3.m`
5. `src/improved/algorithms/BBO/BBO_improved_v3_ablation_core.m`

#### 最关键的 5 个运行 / 阅读要点

1. 这次压缩包只有 `src/`，**不是完整可运行仓库**
2. MATLAB 主链需要 `third_party/` 和 `external_assets/`
3. 当前真正主线是 **benchmark + improved BBO + ablation**
4. `medimg/` 还没真正启用
5. `run_v3_dual_objective_ablation.m` 有一个值得优先检查的潜在命名问题

#### 你下一步最应该做什么

最合适的顺序是：

1. 先读 `cec_runner/README + docs`
2. 再读 `run_main_entry -> run_experiment -> run_all_compare`
3. 然后读 `BBO_improved_v3 -> BBO_improved_v3_ablation_core -> modules`
4. 最后检查 `run_v3_dual_objective_ablation.m` 的局部函数命名问题
5. 如果要真正跑起来，下一步不是改 `src`，而是先把**完整仓库缺失部分补齐**

------

### 这次你能学到什么 / 对以后有什么帮助

这次最重要的不是“记住了几个文件名”，而是学会了**看科研代码仓的顺序**：
先看入口，再看执行链，再看配置层，再看算法层，再看导出层。
这就像看地铁图🚇，不是先盯着某一站，而是先看**主干线怎么走、换乘站在哪里、终点通向哪**。以后再接手别人的科研代码，你就不会一上来被几十个 `.m` 文件绕晕了。

------

### 当前总体任务进度

**当前阶段：** 已完成“第一轮全局总览 + 核心文件定位 + 运行链梳理”。
**已完成内容：** 解压、目录树、主流程、关键文件、运行方式、输出结果、语法点、风险点。
**下一步最值得做：** 我直接继续帮你做**第二轮深挖版**，把以下 3 块彻底讲懂：

- `run_all_compare.m` 的完整执行细节
- `BBO_improved_v3_ablation_core.m` 的逐段逻辑
- `run_v3_dual_objective_ablation.m` 的潜在 bug 怎么改才稳

如果你愿意，我下一条就直接进入这三块的“带练式拆解”。