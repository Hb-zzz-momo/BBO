# V3_DIR_SMALL_STEP Reduced Ablation：改进点对应代码块与语法详解

## 1. 文档目的

本文档面向当前 reduced subset 实验主线，解释三件事：

1. 每个改进版本相对 V3 的具体改动点
2. 每个改动点在代码中的对应代码块
3. 关键 MATLAB 语法如何理解（结合本仓库真实实现）

本轮主线版本：

- V3_BASELINE
- V3_DIR_SMALL_STEP
- V3_DIR_SMALL_STEP_LATE_LOCAL_REFINE
- V3_DIR_SMALL_STEP_GATE_LATE_LOCAL_REFINE

核心实现文件：

- src/improved/algorithms/BBO/BBO_improved_v3_ablation_core.m
- src/improved/algorithms/BBO/BBO_v3_dir_small_step.m
- src/improved/algorithms/BBO/BBO_v3_dir_small_step_late_local_refine.m
- src/improved/algorithms/BBO/BBO_v3_dir_small_step_gate_late_local_refine.m
- src/benchmark/cec_runner/run_v3_direction_reduced_ablation.m

---

## 2. 版本入口与改进映射

### 2.1 V3_DIR_SMALL_STEP 入口

```matlab
function [best_fitness, best_solution, Convergence_curve] = BBO_v3_dir_small_step(N, Max_iteration, lb, ub, dim, fobj)
% V3 directional module: conservative small-step directional updates.
    [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3_ablation_core( ...
    N, Max_iteration, lb, ub, dim, fobj, 'dir_small_step');
end
```

解释：

- 这是薄封装，不改算法主体
- 真正逻辑在 core 函数里，通过 mode='dir_small_step' 开关启用

语法点：

- `...` 是 MATLAB 续行符，表示下一行继续同一条语句
- `[a,b,c] = func(...)` 表示函数有多个返回值

### 2.2 V3_DIR_SMALL_STEP_LATE_LOCAL_REFINE 入口

```matlab
function [best_fitness, best_solution, Convergence_curve] = BBO_v3_dir_small_step_late_local_refine(N, Max_iteration, lb, ub, dim, fobj)
% V3 directional small-step + late contraction-style local refine.
    [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3_ablation_core( ...
        N, Max_iteration, lb, ub, dim, fobj, 'dir_small_step_late_local_refine');
end
```

解释：

- 在 small_step 基础上新增 late_local_refine 模块
- 仍保持统一主循环和统一接口

### 2.3 V3_DIR_SMALL_STEP_GATE_LATE_LOCAL_REFINE 入口

```matlab
function [best_fitness, best_solution, Convergence_curve] = BBO_v3_dir_small_step_gate_late_local_refine(N, Max_iteration, lb, ub, dim, fobj)
% V3 directional small-step + directional gate + late local refine.
    [best_fitness, best_solution, Convergence_curve] = BBO_improved_v3_ablation_core( ...
        N, Max_iteration, lb, ub, dim, fobj, 'dir_small_step_gate_late_local_refine');
end
```

解释：

- 在上一版本基础上再启用 directional gate
- 目标是让 directional 从“概率触发”收敛到“条件触发优先”

---

## 3. 核心 mode 映射（改进点总开关）

对应代码块：

```matlab
switch char(mode)
    case 'dir_small_step'
        cfg.dir_small_step = true;
        cfg.dir_late = true;
    case 'dir_small_step_late_local_refine'
        cfg.dir_small_step = true;
        cfg.dir_late = true;
        cfg.use_late_local_refine = true;
    case 'dir_small_step_gate_late_local_refine'
        cfg.dir_small_step = true;
        cfg.dir_late = true;
        cfg.use_late_local_refine = true;
        cfg.use_directional_gate = true;
end
```

解释：

- `dir_small_step`：小步长 directional + 晚期触发
- `dir_small_step_late_local_refine`：再加后期局部修复
- `dir_small_step_gate_late_local_refine`：再加门控

语法点：

- `switch ... case ... otherwise`：按模式名分支
- `char(mode)`：把 string 统一转成 char，避免字符串类型不一致

---

## 4. 改进点 1：small-step directional（保守步长）

对应代码块：

```matlab
F = 0.52 - 0.30 * progress;
tail = 0.05 + 0.03 * (1 - progress);

if cfg.dir_small_step
    F = 0.5 * F;
    tail = 0.35 * tail;
end
```

改进含义：

- 主方向差分系数 F 进一步减半
- 尾部噪声项 tail 同时减小
- 避免 directional 过冲，尤其在简单函数后期阶段

语法点：

- `*` 是标量乘法
- `progress = t / Max_iteration` 表示归一化进度

---

## 5. 改进点 2：late_local_refine（后期收缩式局部修复）

### 5.1 触发条件

对应代码块：

```matlab
if ~cfg.use_late_local_refine
    return;
end

if progress <= cfg.local_refine_start
    return;
end

if no_improve_count > cfg.local_refine_no_improve_max
    return;
end

if pop_diversity >= cfg.local_refine_diversity_threshold
    return;
end

if rand > cfg.local_refine_prob
    return;
end
```

改进含义：

- 仅在后期 (`progress > 0.70`) 允许
- 要求“当前不是长停滞”
- 要求群体多样性较低（进入收敛区）
- 低频触发（概率门控）

语法点：

- `~` 是逻辑非
- `return` 在子函数中表示提前退出，不执行后续逻辑
- 多个 `if-return` 串联是常见“门控链”写法

### 5.2 动作机制

对应代码块：

```matlab
elite_count = max(3, round(0.15 * size(population, 1)));
[~, elite_sorted] = sort(fitness);
elite = population(elite_sorted(1:elite_count), :);
elite_centroid = mean(elite, 1);

base_radius = 0.008 * (1 - progress + 0.08);
local_noise = base_radius .* (ub - lb) .* randn(size(best_solution));

candidate_a = 0.88 .* best_solution + 0.12 .* elite_centroid + local_noise;
candidate_b = best_solution + 0.16 .* (elite_centroid - best_solution) + 0.5 .* local_noise;
```

改进含义：

- 在 best 与 elite centroid 附近做小半径局部试探
- 采用两个候选 (`candidate_a`, `candidate_b`) 再择优
- 属于收缩式修复，不是大范围重排

语法点：

- `size(population,1)`：种群个体数
- `sort(fitness)`：适应度升序排序（最小化问题）
- `population(idx, :)`：取第 idx 行所有维度
- `mean(elite,1)`：按列求均值，得到精英中心向量
- `.*`：逐元素乘法（element-wise）

### 5.3 提交策略

对应代码块：

```matlab
[worst_fit, worst_idx] = max(fitness);
if candidate_fit < worst_fit
    population(worst_idx, :) = candidate;
    fitness(worst_idx) = candidate_fit;
end

if candidate_fit < best_fitness
    best_fitness = candidate_fit;
    best_solution = candidate;
end
```

改进含义：

- 优先替换最差个体，避免污染精英层
- 若候选更优则更新全局最优

语法点：

- `[value, idx] = max(x)` 同时返回最大值和索引
- 这是“尾部修复 + 全局最优更新”的双层提交

---

## 6. 改进点 3：directional gate（条件门控）

对应代码块：

```matlab
if cfg.use_directional_gate
    if progress <= cfg.gate_early_stage
        return;
    end
    if no_improve_count < cfg.gate_stall_window
        return;
    end
    if pop_diversity < cfg.gate_min_diversity
        return;
    end

    elite_mid_f = median(fitness(elite_sorted(1:elite_pool_size)));
    [worst_fitness, ~] = max(fitness);
    lag_ratio = (worst_fitness - elite_mid_f) / (abs(elite_mid_f) + 1e-12);
    if lag_ratio < cfg.gate_lag_ratio
        return;
    end
end
```

改进含义：

- 必须非早期
- 必须出现停滞
- 必须有一定多样性（避免收缩过头）
- 必须存在明显“落后尾部”（lag_ratio 充足）

这让 directional 更像“按需干预器”，减少对 F1/F2/F3 的持续扰动。

语法点：

- `median(...)`：中位数，抗极端值
- `abs(x)+1e-12`：防除零保护
- `~` 在 `[worst_fitness, ~]` 中表示忽略第二返回值

---

## 7. 主循环稳定性保护（关键）

对应代码块：

```matlab
trial_fitness = fobj(trial);
if trial_fitness < old_fitness
    population(i, :) = trial;
    fitness(i) = trial_fitness;
    if trial_fitness < best_fitness
        best_fitness = trial_fitness;
        best_solution = trial;
        improved_this_iter = true;
    end
else
    population(i, :) = old_position;
    fitness(i) = old_fitness;
end
```

解释：

- 严格贪婪提交/回滚
- 失败 trial 不得污染 population-fitness 对齐关系

语法点：

- `old_position` / `old_fitness` 是显式回滚锚点
- 这是避免“位置-适应度不一致”的核心写法

---

## 8. 多样性定义（本轮新增）

对应代码块：

```matlab
function d = population_diversity(population, lb, ub)
    span = ub - lb;
    span(span <= 1e-12) = 1;
    scaled_std = std(population, 0, 1) ./ span;
    d = mean(scaled_std);
    if ~isfinite(d)
        d = 0;
    end
end
```

解释：

- 用按维标准差除以边界跨度，得到归一化多样性
- 再对维度求均值作为总体多样性指标

语法点：

- `span(span <= 1e-12) = 1` 是逻辑索引赋值
- `std(population,0,1)`：按列标准差
- `./`：逐元素除法

---

## 9. Reduced runner 的对应改进点与语法

### 9.1 reduced subset 与 4 版本固定配置

对应代码块：

```matlab
if ~isfield(cfg, 'reduced_func_ids')
    cfg.reduced_func_ids = [1, 2, 3, 12, 13, 14, 15, 18, 19];
end

if ~isfield(cfg, 'algorithms')
    cfg.algorithms = {
        'V3_BASELINE', ...
        'V3_DIR_SMALL_STEP', ...
        'V3_DIR_SMALL_STEP_LATE_LOCAL_REFINE', ...
        'V3_DIR_SMALL_STEP_GATE_LATE_LOCAL_REFINE'};
end
```

语法点：

- `isfield` 检查配置字段是否存在
- `{ ... }` 是 cell array（字符串列表常用）

### 9.2 timestamp 强约束

对应代码块：

```matlab
if ~isfield(cfg, 'timestamp') || isempty(cfg.timestamp)
    cfg.timestamp = datestr(now, 'yyyymmdd_HHMMSS');
end
```

解释：

- 自动生成 `YYYYMMDD_HHMMSS` 时间节点
- 保证每次结果目录唯一，避免覆盖旧结果

语法点：

- `datestr(now, fmt)`：时间格式化
- `isempty`：空值判断

### 9.3 smoke/formal 目录分离

对应代码块：

```matlab
smoke_root = fullfile(paths.repo_root, 'results', 'benchmark', 'v3_direction_reduced_smoke', cfg.timestamp);
formal_root = fullfile(paths.repo_root, 'results', 'benchmark', 'v3_direction_reduced_formal', cfg.timestamp);
```

解释：

- smoke 与 formal 独立落盘
- 同一 timestamp 下便于回溯同批实验

语法点：

- `fullfile` 跨平台安全拼路径

### 9.4 formal 自动问答输出

对应代码块：

```matlab
fprintf(fid, '1. %s\n', analysis.answers.q1);
fprintf(fid, '2. %s\n', analysis.answers.q2);
fprintf(fid, '3. %s\n', analysis.answers.q3);
fprintf(fid, '4. %s\n', analysis.answers.q4);
fprintf(fid, '5. %s\n', analysis.answers.q5);
fprintf(fid, '6. %s\n\n', analysis.answers.q6);
```

解释：

- formal_screen 后自动回答 6 个研究问题
- 直接服务下一轮决策与论文描述

语法点：

- `fprintf` 格式化写文件
- `%s` 字符串占位符
- `\n` 换行

---

## 10. MATLAB 语法速查（按本实现）

### 10.1 控制流

- `if ... elseif ... else ... end`：条件分支
- `switch ... case ... otherwise ... end`：离散模式分支
- `for i = 1:N`：循环
- `while k == i`：条件循环
- `return`：提前退出当前函数

### 10.2 数组与索引

- `population(i, :)`：第 i 个个体（整行）
- `elite_sorted(1:elite_count)`：前 elite_count 个索引
- `span(span <= 1e-12) = 1`：逻辑索引批量赋值

### 10.3 运算符

- `*`：矩阵/标量乘法
- `.*`：逐元素乘法
- `/`：右除
- `./`：逐元素除法
- `+ -`：加减

### 10.4 常见函数

- `rand`：均匀随机
- `randn`：高斯随机
- `randi([a,b])`：离散随机整数
- `sort`：排序
- `min/max`：极值与索引
- `mean/median/std`：统计量
- `isfinite`：有限数判断
- `isempty/isfield/isstruct`：结构与空值检查

---

## 11. 论文可用的一句话方法描述

本轮在 V3_DIR_SMALL_STEP 主线上，通过新增后期低频小半径的 contraction-style local refine，以及基于停滞/落后/多样性的 directional gate，实现了对 simple functions 后期修复与复杂函数 directional 优势保留的可解释消融验证。

---

## 12. 建议如何配套使用本文件

建议在论文或报告中把本文件当“方法附录解释稿”，正文只保留：

1. 三个版本的机制差异（small_step / +local_refine / +gate）
2. 四条核心触发条件
3. formal_screen 的 6 个问题回答

这样正文简洁，附录可追溯实现细节。