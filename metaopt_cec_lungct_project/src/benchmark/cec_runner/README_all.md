下面我按 **“怎么设置用” + “会画哪些图” + “图的英文名” + “怎么读这些图”** 给你拆开讲。

------

### 一、这个脚本是干什么的

这个 `run_all_compare.m` 是一个 **统一多算法基准测试脚本**，主要作用是：

- 在 **CEC2017** 和 **CEC2022** 基准函数集（benchmark suite，基准测试集）上跑多个优化算法
- 统一控制：
  - 算法列表
  - 函数编号
  - 维度（dimension，维数）
  - 种群大小（population size，群体规模）
  - 最大函数评估次数（maxFEs, maximum function evaluations）
  - 重复运行次数（runs）
- 自动输出：
  - 单次运行结果
  - 收敛曲线数据
  - 汇总表
  - 图像文件

它本质上就是一个 **批量实验总控脚本**。

------

### 二、最基本怎么用

#### 1. 直接默认运行

如果仓库路径都对，MATLAB 里直接运行：

```matlab
run_all_compare();
```

这会使用脚本里的默认配置。

------

#### 2. 传入配置结构体运行

更常见的是这样：

```matlab
cfg = struct();
cfg.suites = {'cec2017','cec2022'};
cfg.algorithms = {'BBO','SBO'};
cfg.func_ids = 1:5;
cfg.dim = 10;
cfg.pop_size = 30;
cfg.maxFEs = 3000;
cfg.runs = 5;
cfg.experiment_name = 'bbo_sbo_test';

output = run_all_compare(cfg);
```

------

### 三、默认配置是什么

这个脚本里默认值大致是：

```matlab
cfg.suites = {'cec2017', 'cec2022'};
cfg.algorithms = {'BBO', 'SBO', 'HGS', 'SMA', 'HHO', 'RUN', 'INFO', 'MGO', 'PLO', 'PO'};
cfg.func_ids = [];          % 空表示跑该套件全部函数
cfg.dim = 10;
cfg.pop_size = 30;
cfg.maxFEs = 3000;
cfg.runs = 5;
cfg.rng_seed = 20260313;
cfg.result_root = 'results';
cfg.save_curve = true;
cfg.save_mat = true;
cfg.save_csv = true;
cfg.hard_stop_on_fe_limit = true;
```

------

### 四、重点：你最关心的图像开关怎么设置

这个脚本已经有比较完整的绘图配置 `cfg.plot`。

------

#### 1. 总开关

```matlab
cfg.plot.enable = true;   % 是否启用绘图模块
```

- `true`：生成图
- `false`：完全不生成图

------

#### 2. 是否显示图窗

```matlab
cfg.plot.show = false;
```

这个很重要。

脚本默认其实是：

```matlab
cfg.plot.show = true;
```

也就是说，**如果你不改，它默认会弹图窗显示**。
如果你想像之前说的那样 **“只保存，不显示”**，一定要手动改成：

```matlab
cfg.plot.show = false;
```

------

#### 3. 是否保存图

```matlab
cfg.plot.save = true;
```

通常保持 `true`。

------

#### 4. 保存格式

```matlab
cfg.plot.formats = {'png'};
```

也可以改成：

```matlab
cfg.plot.formats = {'png','pdf','fig'};
```

含义：

- `png`：普通图片
- `pdf`：论文排版更方便
- `fig`：MATLAB 原生图文件，后续还能再编辑

------

#### 5. 分辨率

```matlab
cfg.plot.dpi = 200;
```

论文一般建议：

```matlab
cfg.plot.dpi = 300;
```

------

### 五、单独控制“画哪些图”

这个脚本支持按图类型开关。

```matlab
cfg.plot.types.convergence_curves = true;
cfg.plot.types.boxplots = true;
cfg.plot.types.friedman_radar = true;
cfg.plot.types.search_process_overview = true;
cfg.plot.types.mean_fitness = true;
cfg.plot.types.trajectory_first_dim = true;
cfg.plot.types.final_population = true;
```

你可以按需求关掉一部分。

------

### 六、推荐你这样设置：只保存，不显示，分类型输出

#### 1. 适合正式批量实验的配置

```matlab
cfg = struct();

cfg.suites = {'cec2017','cec2022'};
cfg.algorithms = {'BBO','SBO'};
cfg.func_ids = 1:5;
cfg.dim = 10;
cfg.pop_size = 30;
cfg.maxFEs = 3000;
cfg.runs = 5;
cfg.experiment_name = 'bbo_sbo_compare';

cfg.plot.enable = true;
cfg.plot.show = false;          % 不显示
cfg.plot.save = true;           % 只保存
cfg.plot.formats = {'png'};
cfg.plot.dpi = 300;
cfg.plot.close_after_save = true;
cfg.plot.overwrite = true;

cfg.plot.types.convergence_curves = true;
cfg.plot.types.boxplots = true;
cfg.plot.types.friedman_radar = true;

cfg.plot.types.search_process_overview = false;
cfg.plot.types.mean_fitness = false;
cfg.plot.types.trajectory_first_dim = false;
cfg.plot.types.final_population = false;

output = run_all_compare(cfg);
```

这套比较适合 **论文主实验**。

------

#### 2. 适合单独分析 BBO 行为的配置

```matlab
cfg = struct();

cfg.suites = {'cec2017'};
cfg.algorithms = {'BBO'};
cfg.func_ids = [1 3 5];
cfg.dim = 2;                    % 注意：行为图里有些要求二维
cfg.pop_size = 30;
cfg.maxFEs = 3000;
cfg.runs = 3;
cfg.experiment_name = 'bbo_behavior_demo';

cfg.plot.enable = true;
cfg.plot.show = false;
cfg.plot.save = true;
cfg.plot.formats = {'png'};
cfg.plot.dpi = 300;

cfg.plot.types.convergence_curves = true;
cfg.plot.types.boxplots = false;
cfg.plot.types.friedman_radar = false;
cfg.plot.types.search_process_overview = true;
cfg.plot.types.mean_fitness = true;
cfg.plot.types.trajectory_first_dim = true;
cfg.plot.types.final_population = true;

cfg.plot.behavior.only_for_algorithms = {'BBO'};
cfg.plot.behavior.require_dim2 = true;
cfg.plot.behavior.max_funcs = 3;

output = run_all_compare(cfg);
```

这套适合 **过程分析 / 周报 / 方法解释**。

------

### 七、脚本到底会画哪些图

下面我给你逐个解释。

------

### 八、图 1：收敛曲线图

#### 中文名

收敛曲线图

#### 英文名

**Convergence Curves**

#### 开关

```matlab
cfg.plot.types.convergence_curves = true;
```

#### 文件夹

```text
figures/convergence_curves/D10/
```

#### 文件名格式

```text
convergence_cec2017_D10_F1.png
```

#### 它画的是什么

- 横轴：迭代次数（Iteration）或函数评估次数（Function Evaluations）
- 纵轴：当前最优值（Best-so-far fitness）

#### 用途

看不同算法谁下降得更快、谁最后更低。

#### 适合放哪里

- 论文正文
- 周报
- 对比实验分析

------

### 九、图 2：箱线图

#### 中文名

箱线图 / 箱型图

#### 英文名

**Boxplots**

#### 开关

```matlab
cfg.plot.types.boxplots = true;
```

#### 文件夹

```text
figures/boxplots/D10/
```

#### 文件名格式

```text
boxplot_cec2017_D10_F1.png
```

#### 它画的是什么

它用每个算法多次独立运行后的最终结果画分布图。

#### 主要看什么

- 中位数（median，中位值）
- 四分位区间（interquartile range，四分位距）
- 离群点（outliers，异常值）

#### 用途

看算法稳不稳定，而不只是看一次跑得好不好。

#### 适合放哪里

- 论文正文
- 稳定性分析章节

------

### 十、图 3：Friedman 排名雷达图

#### 中文名

Friedman 平均排名雷达图

#### 英文名

**Friedman Radar Chart**
或者更完整一点叫
**Friedman Average Rank Radar Chart**

#### 开关

```matlab
cfg.plot.types.friedman_radar = true;
```

#### 文件夹

```text
figures/friedman_radar/D10/
```

#### 文件名格式

```text
friedman_cec2017_D10.png
```

#### 它画的是什么

它会根据 `summary_table` 中各算法在多个函数上的平均表现，先算排名，再画雷达图。

#### 用途

看算法整体排名，而不是只看某一个函数。

#### 适合放哪里

- 论文整体性能总结
- 多函数综合结论图

------

### 十一、图 4：搜索过程综合图

#### 中文名

搜索过程综合图

#### 英文名

**Search Process Overview**

#### 开关

```matlab
cfg.plot.types.search_process_overview = true;
```

#### 文件夹

```text
figures/search_process_overview/<algorithm>/D2/
```

例如：

```text
figures/search_process_overview/bbo/D2/
```

#### 文件名格式

```text
overview_bbo_cec2017_D2_F1.png
```

#### 这个图里包含什么

它是一个 2×2 的综合图，包含：

1. **2D contour and final population proxy**
   二维等高线 + 最终种群分布代理图
2. **Mean fitness**
   平均适应度曲线
3. **Representative first-dimension trajectory**
   代表性个体第一维轨迹图
4. **Convergence**
   收敛图

#### 注意

这个图对二维要求比较强：

```matlab
cfg.plot.behavior.require_dim2 = true;
```

如果不是二维，轮廓图和最终种群图通常会跳过。

#### 适合放哪里

- 周报
- 算法机理解释
- 论文方法分析补充图

------

### 十二、图 5：平均适应度曲线

#### 中文名

平均适应度曲线

#### 英文名

**Mean Fitness Curve**

#### 开关

```matlab
cfg.plot.types.mean_fitness = true;
```

#### 文件夹

```text
figures/mean_fitness/<algorithm>/D10/
```

#### 文件名格式

```text
meanfit_bbo_cec2017_D10_F1.png
```

#### 它画的是什么

- 横轴：迭代代理（evaluation batch，评估批次）
- 纵轴：种群平均适应度（mean fitness）

#### 用途

看整个种群整体是在变好，还是只有个别点偶然变好。

#### 适合放哪里

- 行为分析
- 算法收敛机理说明

------

### 十三、图 6：第一维轨迹图

#### 中文名

第一维轨迹图

#### 英文名

**First-Dimension Trajectory**
脚本里标题更接近：
**Representative First-Dimension Trajectory**

#### 开关

```matlab
cfg.plot.types.trajectory_first_dim = true;
```

#### 文件夹

```text
figures/trajectory_first_dim/<algorithm>/D10/
```

#### 文件名格式

```text
traj1d_bbo_cec2017_D10_F1.png
```

#### 它画的是什么

记录一个代表性个体（其实更接近当前最优个体代理）的第一维坐标 `x(1)` 随过程变化。

#### 用途

看搜索是否剧烈跳动、后期是否稳定。

#### 适合放哪里

- 方法解释
- 搜索行为分析

------

### 十四、图 7：最终种群分布图

#### 中文名

最终种群分布图

#### 英文名

**Final Population Plot**
或者
**Final Population Distribution**

#### 开关

```matlab
cfg.plot.types.final_population = true;
```

#### 文件夹

```text
figures/final_population/<algorithm>/D2/
```

#### 文件名格式

```text
finalpop_bbo_cec2017_D2_F1.png
```

#### 它画的是什么

显示最终一批种群个体在二维空间中的分布。

#### 注意

这个图基本要求二维，否则画不出来。

#### 用途

看最后是不是都聚集到了某个区域。

#### 适合放哪里

- 行为分析
- 论文补充图
- 周报展示

------

### 十五、这些图和论文用途怎么对应

| 中文图名                | 英文名                            | 更适合什么用途           |
| ----------------------- | --------------------------------- | ------------------------ |
| 收敛曲线图              | Convergence Curves                | 论文正文、主实验对比     |
| 箱线图                  | Boxplots                          | 论文正文、稳定性分析     |
| Friedman 平均排名雷达图 | Friedman Average Rank Radar Chart | 论文整体结论             |
| 搜索过程综合图          | Search Process Overview           | 周报、行为解释、论文补充 |
| 平均适应度曲线          | Mean Fitness Curve                | 行为分析                 |
| 第一维轨迹图            | First-Dimension Trajectory        | 搜索机理说明             |
| 最终种群分布图          | Final Population Distribution     | 二维搜索过程展示         |

------

### 十六、图像输出到哪里

脚本会在结果目录下生成：

```text
results/<suite>/<experiment_name>/
```

里面有这些子目录：

```text
tables/
raw_runs/
curves/
logs/
figures/
```

而 `figures/` 下会继续分：

```text
figures/convergence_curves/D10/
figures/boxplots/D10/
figures/friedman_radar/D10/
figures/search_process_overview/bbo/D2/
figures/mean_fitness/bbo/D2/
figures/trajectory_first_dim/bbo/D2/
figures/final_population/bbo/D2/
```

------

### 十七、你现在使用时最容易踩坑的地方

#### 1. 默认会显示图，不是默认隐藏

虽然你之前想要“不显示只保存”，但这个脚本当前默认是：

```matlab
cfg.plot.show = true;
```

所以你一定要改：

```matlab
cfg.plot.show = false;
```

------

#### 2. 行为图很多只适合二维

像：

- Search Process Overview
- Final Population
- 2D contour

这些都更适合：

```matlab
cfg.dim = 2;
```

如果正式实验是 `D=10`，这些图可能会跳过或只画部分。

------

#### 3. 箱线图需要多次运行

如果：

```matlab
cfg.runs = 1;
```

那箱线图基本没意义，甚至可能跳过。

建议至少：

```matlab
cfg.runs = 5
```

更规范一点是：

```matlab
cfg.runs = 20 或 30
```

------

#### 4. Friedman 图需要多个算法、多个函数

如果你只跑一个算法，或者只跑一个函数，Friedman 图会跳过。

------

### 十八、我建议你怎么分两套使用

#### 方案 A：正式论文主实验

用来出主结果表和主图：

```matlab
cfg.dim = 10;
cfg.runs = 20;
cfg.plot.types.convergence_curves = true;
cfg.plot.types.boxplots = true;
cfg.plot.types.friedman_radar = true;
cfg.plot.types.search_process_overview = false;
cfg.plot.types.mean_fitness = false;
cfg.plot.types.trajectory_first_dim = false;
cfg.plot.types.final_population = false;
cfg.plot.show = false;
```

------

#### 方案 B：单独行为分析图

用来解释 BBO 为什么这样搜索：

```matlab
cfg.dim = 2;
cfg.algorithms = {'BBO'};
cfg.plot.types.search_process_overview = true;
cfg.plot.types.mean_fitness = true;
cfg.plot.types.trajectory_first_dim = true;
cfg.plot.types.final_population = true;
cfg.plot.show = false;
```

------

### 十九、给你一份最实用的可直接复制配置

```matlab
cfg = struct();

cfg.suites = {'cec2017'};
cfg.algorithms = {'BBO','SBO'};
cfg.func_ids = 1:5;
cfg.dim = 10;
cfg.pop_size = 30;
cfg.maxFEs = 3000;
cfg.runs = 5;
cfg.experiment_name = 'demo_compare';

cfg.plot.enable = true;
cfg.plot.show = false;              % 只保存，不显示
cfg.plot.save = true;
cfg.plot.formats = {'png'};
cfg.plot.dpi = 300;
cfg.plot.close_after_save = true;
cfg.plot.overwrite = true;

cfg.plot.types.convergence_curves = true;
cfg.plot.types.boxplots = true;
cfg.plot.types.friedman_radar = true;
cfg.plot.types.search_process_overview = false;
cfg.plot.types.mean_fitness = false;
cfg.plot.types.trajectory_first_dim = false;
cfg.plot.types.final_population = false;

output = run_all_compare(cfg);
```

------

### 二十、总结一下这个脚本“怎么设置使用”

最核心就记住 4 句：

```matlab
cfg = struct();
cfg.plot.enable = true;     % 开启绘图
cfg.plot.show = false;      % 不显示
cfg.plot.save = true;       % 保存
cfg.plot.types.xxx = true;  % 选你想画的图
```

然后再配：

```matlab
cfg.algorithms
cfg.func_ids
cfg.dim
cfg.maxFEs
cfg.runs
cfg.experiment_name
```

就可以了。

------

### 这次你能学到什么 / 对未来有什么帮助 🌟

这次真正学到的是：**一个科研脚本不是“能跑就行”，而是要分清“主实验图”和“行为解释图”**。
收敛曲线、箱线图、Friedman 图更像论文里的“成绩单”；搜索过程图、轨迹图、种群分布图更像“监控录像”。前者告诉我结果好不好，后者告诉我它为什么会这样。以后你看优化算法论文或写自己的实验脚本时，就会更清楚该开什么图、为什么开这个图。📈🧠

### 当前总体任务进度

当前处于 **BBO/SBO 实验脚本使用与图表理解阶段**。
已完成：把 `run_all_compare.m` 的配置方式、绘图开关、图类型和英文名梳理清楚。
下一步最合适的是：我继续帮你做一份 **“论文用图选择清单 + 周报用图选择清单”**，直接告诉你哪些图该放正文、哪些图该放附录、哪些图适合汇报。