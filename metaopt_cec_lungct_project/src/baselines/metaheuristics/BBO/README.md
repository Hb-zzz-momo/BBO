# BBO Baseline Source README

## 1. 目录定位

本目录用于存放 BBO (Beaver Behavior Optimizer) 的原始基线代码与压缩包。
当前以 MATLAB 版本为主，已按 CEC 年份拆分测试入口。

## 2. 当前目录内容

- `Source_code_BBO_MATLAB_VERSION.zip`
  - 原始压缩包，建议保留不改，作为可追溯来源。
- `Source_code_BBO_MATLAB_VERSION_extracted/`
  - 解压后的可运行代码。

解压后的核心结构：

- `Source_code_BBO_MATLAB_VERSION_extracted/Source_code_BBO_MATLAB_VERSION/CEC2017/`
  - `main.m`: CEC2017 批量运行入口（F1-F30）。
  - `BBO.m`: BBO 算法主体。
  - `Get_Functions_cec2017.m`: CEC2017 函数封装入口。
  - `cec17_func.mexw64`: CEC2017 相关 mex 二进制（Windows）。
  - `input_data/`: CEC2017 数据文件。

- `Source_code_BBO_MATLAB_VERSION_extracted/Source_code_BBO_MATLAB_VERSION/CEC2022/`
  - `main.m`: CEC2022 批量运行入口（F1-F12）。
  - `BBO.m`: BBO 算法主体。
  - `Get_Functions_cec2022.m`: CEC2022 函数封装入口。
  - `cec22_func.mexw64`: CEC2022 相关 mex 二进制（Windows）。
  - `input_data22/`: CEC2022 数据文件。

## 3. 已包含代码能力

- BBO 单算法优化流程（初始化、迭代更新、边界处理、最优值跟踪）。
- CEC2017 与 CEC2022 的独立测试入口。
- 收敛曲线绘图（`semilogy`）。
- 每个函数的最优值与最优解输出。

不包含的能力：

- 多次独立运行统计（均值/标准差/显著性检验）自动化。
- 统一日志和结果文件持久化（CSV/JSON）。
- 跨算法统一接口层（当前是单算法脚本风格）。

## 4. 快速使用方式（MATLAB）

### 4.1 CEC2017

1. 打开 MATLAB，工作目录切换到：
   - `.../BBO/Source_code_BBO_MATLAB_VERSION_extracted/Source_code_BBO_MATLAB_VERSION/CEC2017`
2. 运行：
   - `main`

默认配置（来自 `main.m`）：
- `nPop = 30`
- `Max_iter = 500`
- `dim = 30`
- `Function_name = 1:30`

### 4.2 CEC2022

1. 切换到：
   - `.../BBO/Source_code_BBO_MATLAB_VERSION_extracted/Source_code_BBO_MATLAB_VERSION/CEC2022`
2. 运行：
   - `main`

默认配置（来自 `main.m`）：
- `nPop = 30`
- `Max_iter = 500`
- `dim = 10`（注释提示可用 10/20）
- `Function_name = 1:12`

## 5. 使用规则（建议作为基线规范）

- 规则 1：原始基线代码不直接覆盖修改。
  - 如需改动，请复制到新目录并标注版本（如 `BBO_v1_research`）。

- 规则 2：比较实验中禁止隐式修改预算。
  - 保持与对照算法一致的 `nPop`、`Max_iter` 或统一 FEs 预算。

- 规则 3：CEC2017 与 CEC2022 不混跑、不混表。
  - 两套函数集合和维度设置不同，汇总时必须分开统计。

- 规则 4：每次运行记录完整配置。
  - 至少记录：函数编号范围、维度、种群大小、迭代数、运行时间、平台信息。

- 规则 5：图像仅作为可视化参考。
  - 科研报告以可复现的数值汇总为主，图像应由原始结果再生成。

## 6. 通用性评估

### 6.1 可移植性

- MATLAB 脚本本体通用性较好。
- 但 `cec17_func.mexw64` 与 `cec22_func.mexw64` 为 Windows 平台二进制。
- 在 Linux/macOS 上可能需要重新编译 mex 或替换 CEC 函数实现。

### 6.2 可扩展性

- 容易替换目标函数：`BBO.m` 接口为 `fobj` 回调。
- 不易直接扩展实验管理：当前缺少统一配置和批处理输出。

### 6.3 与本项目工作流适配

- 适合作为“单算法基线复现”起点。
- 需要二次封装后，才能无缝接入统一实验框架（配置化、多次运行、统计检验）。

## 7. 复现实验最低清单

每次实验建议至少保存：

- 算法版本（原始 / 修改版标识）
- CEC 年份（2017/2022）
- 维度、种群、迭代/FEs
- 每个函数的最优值
- 重复次数与随机种子策略
- 代码执行时间

## 8. 已知风险与注意事项

- `main.m` 当前偏演示风格（每个函数单独绘图并 `pause`），批量实验效率不高。
- 默认未进行多次重复统计，单次结果不宜直接用于论文主结论。
- mex 依赖会影响跨平台复现。

## 9. 建议下一步（不修改原始代码前提）

- 在项目统一实验层新增包装脚本，外部调用该目录 `main.m` 或 `BBO.m`。
- 统一将结果导出到 `results/benchmark/runs/` 与 `results/benchmark/summaries/`。
- 增加重复运行与统计检验，形成论文可用表格与显著性结论。
