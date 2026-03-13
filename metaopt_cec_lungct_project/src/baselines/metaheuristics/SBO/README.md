# SBO Baseline Source README

## 1. 目录定位

本目录用于存放 SBO (Status-based Optimization) 相关原始代码。
当前同时包含：

- Python 版 SBO + CEC2017 演示代码
- MATLAB 版 SBO 及多个对比算法代码集合

适合做：
- SBO 基线复现
- 多算法横向对照（HHO/SMA/HGS/RUN/INFO 等）
- 方法论文中的实验补充对比

## 2. 当前目录内容

- `Status_based_Optimization_SBO_python_code.zip`
- `Status_based_Optimization_SBO_python_code_extracted/`
  - `SBO-benchmark-demo-python/`
    - `run_exp.py`: CEC2017 批量运行入口（F1-F30）。
    - `sbo.py`: SBO 核心实现。
    - `requirements.txt`: Python 依赖（仅 `numpy==1.26.4`）。
    - `cec2017/`: CEC2017 函数实现与数据。

- `Status_based_Optimization_SBO_MATLAB_codes.zip`
- `Status_based_Optimization_SBO_MATLAB_codes_extracted/`
  - `Status-based Optimization (SBO)-2025/`
  - `Harris Hawk Optimization (HHO)-2019/`
  - `Slime mould algorithm (SMA)-2020/`
  - `Hunger Games Search (HGS)-2021/`
  - `Runge Kutta Optimization (RUN)-2021/`
  - `Weighted Mean of Vectors (INFO)-2022/`
  - `Rime Optimization Algorithm (RIME)-2023/`
  - `Escape optimization algorithm (ESC)-2024/`
  - `Moss Growth Optimization (MGO)-2024/`
  - `Polar Lights Optimizer (PLO)-2024/`
  - `Parrot Optimizer (PO)-2024/`
  - `Fata Morgana Algorithm (FATA)-2024/`
  - `Educational Competition Optimizer (ECO)-2024/`
  - `Artemisinin Optimizer (AO)-2024/`

## 3. 已包含代码能力

### 3.1 Python 分支（SBO）

- 支持 CEC2017 的 30 个测试函数循环评估。
- SBO 算法完整迭代逻辑（初始化、边界控制、轮盘赌选择、社会交互更新）。
- 命令行输出每个函数结果与运行耗时。

当前缺项：
- 默认没有结果文件落盘（CSV/JSON）。
- 默认没有多次重复运行统计。
- 默认没有统一随机种子管理接口。

### 3.2 MATLAB 分支（SBO + 多算法）

- 提供 SBO 主算法和多篇相关算法实现。
- 大多数目录有独立 `main.m`，便于单算法快速运行。
- 适合作为横向基线库。

当前缺项：
- 跨算法统一参数入口不一致。
- 结果存储格式未统一。

## 4. 快速使用方式

### 4.1 Python 版 SBO

1. 进入目录：
   - `.../SBO/Status_based_Optimization_SBO_python_code_extracted/SBO-benchmark-demo-python`
2. 安装依赖：
   - `pip install -r requirements.txt`
3. 运行：
   - `python run_exp.py`

默认配置（来自 `run_exp.py`）：
- `POP_SIZE = 30`
- `MAX_FES = POP_SIZE * 10000`
- `DIM = 30`
- `LB = -100`
- `UB = 100`

### 4.2 MATLAB 版 SBO

1. 进入目录：
   - `.../SBO/Status_based_Optimization_SBO_MATLAB_codes_extracted/Status-based Optimization (SBO)-2025`
2. 运行：
   - `main`

默认配置（来自 `main.m`）：
- `N = 30`
- `F = 'F1'`（注释说明可选 F1-F23）
- `T = 500`

## 5. 使用规则（建议）

- 规则 1：压缩包与解压原始代码保持只读备份属性。
  - 二次开发请复制到新目录并加版本后缀。

- 规则 2：Python 与 MATLAB 分支不要混合统计。
  - 语言实现差异会影响效率与边界处理细节。

- 规则 3：对比实验保持统一预算。
  - 至少统一维度、函数集合、种群规模、迭代次数或 FEs。

- 规则 4：记录随机性控制策略。
  - 原代码未统一 seed，论文实验必须补充 seed 管理。

- 规则 5：基线与改进严格分目录。
  - 避免在原始 `sbo.py` 或 MATLAB 原目录直接改动。

## 6. 通用性评估

### 6.1 跨问题通用性

- SBO 核心接口采用目标函数回调，理论上可迁移到一般连续优化问题。
- 但当前自带实验脚本主要面向 CEC 基准，问题定义和边界形式偏标准化。

### 6.2 跨平台通用性

- Python 分支通用性较好（依赖轻）。
- MATLAB 分支通用性取决于各子算法实现和外部函数依赖。

### 6.3 工程通用性

- 当前代码偏“论文复现脚本”风格，不是统一工程化框架。
- 要接入统一实验系统，建议新增外层包装：
  - 统一配置读取
  - 多次运行
  - 结果落盘
  - 汇总统计

## 7. 与 BBO 的协同使用建议

- 建议将 SBO Python 和 BBO MATLAB 分别作为独立 baseline 组。
- 若做公平对比，优先统一到同一语言或同一评价脚本层。
- 推荐在项目实验层统一输出：
  - 每函数每次运行最优值
  - 均值/标准差
  - Wilcoxon/Friedman 统计结果

## 8. 复现实验最低清单

每次运行建议记录：

- 算法名、实现语言、代码版本
- 测试集（CEC 年份/函数范围）
- 维度、种群、迭代/FEs
- 随机种子与重复次数
- 机器与软件环境（Python/MATLAB 版本）
- 原始结果与汇总统计文件路径

## 9. 已知风险与注意事项

- Python `run_exp.py` 以屏幕打印为主，默认不保存结构化结果。
- MATLAB 多算法子目录规范不完全一致，批量统一调度成本较高。
- 若直接引用单次运行结果写论文，统计可靠性不足。
