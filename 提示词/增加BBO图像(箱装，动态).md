你现在是本科研仓库中的 Research Code Assistant AGENT。

任务目标：
在现有的 BBO / CEC benchmark 运行脚本基础上，加入“图像输出模块”，用于在实验结束后自动保存论文风格的结果图。
要求只保存，不弹窗显示，不实时绘图打断运行；不同类型图保存到不同文件夹；并且必须提供统一开关，默认关闭，避免影响原有实验流程。

请严格遵守以下要求执行。

一、总体原则
1. 只做最小必要修改，不重构整个仓库。
2. 不改变现有 benchmark 协议，不改变：
   - suite
   - function set
   - dimension
   - population size
   - maxFEs / iterations
   - runs
   - stopping criteria
   - metrics definition
3. 图像输出是“附加功能”，不是改算法逻辑。
4. 默认不显示图窗，不调用会弹出窗口的实时绘图逻辑。
5. 必须保证旧脚本在关闭绘图开关时，行为与原来尽量一致。
6. 输出要便于论文复用、周报复用、后续批量整理。

二、这次要加入的图像类型
请按下面类型设计，并尽量兼容当前已有结果数据结构。

A. benchmark-level 对比图
1. convergence_curves
   - 多算法对比收敛曲线
   - 横轴：function evaluations 或 iteration（优先沿用当前主脚本已有口径，不要私改）
   - 纵轴：best-so-far fitness / objective
   - 每个函数单独存图
   - 如已有多 runs 数据，优先画 mean convergence；若只有单次轨迹，则如实保存，并在代码注释说明

2. boxplots
   - 同一函数下多算法最终结果箱线图
   - 基于多次独立运行的 final best 值
   - 每个函数单独存图

3. friedman_radar
   - 基于 summary 统计结果或 rank 结果生成 Friedman 平均排名雷达图
   - 至少支持按 suite + dim 生成一张
   - 若当前仓库尚无 Friedman 计算实现，则新增一个最小辅助函数
   - 若缺失足够数据，则跳过并写日志，不报错中断主流程

B. algorithm-behavior 图（重点服务 BBO）
4. search_process_overview
   对选定函数生成“搜索过程综合图”，尽量拆成子图后再合成为一张 overview：
   - benchmark function contour / surface（仅限 2D 可视化场景）
   - final population positions
   - mean fitness over iterations
   - first-dimension trajectory of one representative agent 或 best agent
   - convergence trajectory
   注意：
   - 这类图只在 dim == 2 或显式允许降维展示时生成
   - 若当前实验维度不是 2，默认跳过 contour / final_positions，不报错
   - 允许只输出其中能稳定得到的部分，但要写清楚缺失原因

5. mean_fitness
   - 平均适应度随迭代变化曲线
   - 每个函数单独保存

6. trajectory_first_dim
   - 代表性个体第一维轨迹图
   - 若当前算法代码能方便记录 best agent 或 first agent，就沿用现有最小侵入方案
   - 不要为了画图大改算法主体

7. final_population
   - 最终种群分布图
   - 仅在 2D 情况下生成
   - 如果不是 2D，则跳过

三、统一开关设计
请在主配置结构 cfg 中加入统一绘图配置，不要零散硬编码。

建议新增如下配置字段（如命名与仓库风格冲突，可等价调整，但要统一）：

cfg.plot.enable = false;                 % 总开关，默认 false
cfg.plot.show = false;                   % 是否显示图窗，默认 false，必须默认 false
cfg.plot.save = true;                    % 开启绘图时默认保存
cfg.plot.formats = {'png'};              % 可扩展支持 png/pdf/fig
cfg.plot.dpi = 200;                      % 导出分辨率
cfg.plot.tight = true;                   % 是否紧凑布局
cfg.plot.close_after_save = true;        % 保存后自动关闭 figure
cfg.plot.overwrite = true;               % 是否覆盖同名图
cfg.plot.selected_funcs = [];            % 空表示全部；非空则只对指定函数画图
cfg.plot.selected_algorithms = {};       % 空表示全部；非空则只对指定算法画图

cfg.plot.types.convergence_curves = true;
cfg.plot.types.boxplots = true;
cfg.plot.types.friedman_radar = true;
cfg.plot.types.search_process_overview = false;
cfg.plot.types.mean_fitness = false;
cfg.plot.types.trajectory_first_dim = false;
cfg.plot.types.final_population = false;

cfg.plot.behavior.only_for_algorithms = {'BBO'};   % 行为图默认仅对 BBO 生效
cfg.plot.behavior.require_dim2 = true;             % 需要二维才画某些图
cfg.plot.behavior.max_funcs = 3;                   % 最多为若干函数生成复杂行为图，防止批量爆炸
cfg.plot.log_skipped = true;                       % 跳过时写日志

要求：
1. 总开关 false 时，不做任何绘图相关重计算。
2. 子开关只在总开关 true 时生效。
3. show 必须默认 false。
4. 所有图保存后应自动 close，避免 figure 堆积。

四、输出目录设计
请在现有 result_dir 基础上新增标准化图像目录，不要破坏现有结果表格输出。

建议目录结构如下：

results/<suite>/<experiment_name_or_timestamp>/
├─ tables/
├─ raw/
├─ logs/
└─ figures/
   ├─ convergence_curves/
   │  └─ <dim>/
   ├─ boxplots/
   │  └─ <dim>/
   ├─ friedman_radar/
   │  └─ <dim>/
   ├─ search_process_overview/
   │  └─ <algorithm>/<dim>/
   ├─ mean_fitness/
   │  └─ <algorithm>/<dim>/
   ├─ trajectory_first_dim/
   │  └─ <algorithm>/<dim>/
   └─ final_population/
      └─ <algorithm>/<dim>/

命名规范要求：
1. 文件名必须稳定、可批量检索。
2. 推荐格式：
   - convergence_<suite>_D<dim>_F<fid>.png
   - boxplot_<suite>_D<dim>_F<fid>.png
   - friedman_<suite>_D<dim>.png
   - overview_<alg>_<suite>_D<dim>_F<fid>.png
   - meanfit_<alg>_<suite>_D<dim>_F<fid>.png
   - traj1d_<alg>_<suite>_D<dim>_F<fid>.png
   - finalpop_<alg>_<suite>_D<dim>_F<fid>.png
3. 若 experiment_name 已含时间戳，则文件名不必重复加入时间戳。
4. 所有目录不存在时自动创建。

五、实现要求
请按“最小侵入”原则实现，不要把主脚本改得很乱。

建议实现方式：
1. 在配置默认函数 fill_default_config(cfg) 中补齐 plot 配置默认值
2. 在 result_dir 初始化逻辑中补齐 figures 子目录初始化函数
3. 将绘图逻辑尽量下沉到独立辅助函数，例如：
   - init_plot_dirs.m
   - maybe_generate_plots.m
   - plot_convergence_curves.m
   - plot_boxplots.m
   - plot_friedman_radar.m
   - plot_search_process_overview.m
   - plot_mean_fitness.m
   - plot_trajectory_first_dim.m
   - plot_final_population.m
   - save_figure_safely.m
4. 若已有统计结果 summary.csv / raw run results / convergence history，请优先复用，不要重复计算
5. 若当前代码没有保存 convergence history，请只在最小必要位置增加记录
6. 不要为了画图重写所有算法接口；优先用 wrapper / collector 方式补充
7. 如果某类图因数据缺失无法生成：
   - 不报错中断主流程
   - 在 logs/plot_generation.log 中记录跳过原因
   - 控制台简要提示一次即可

六、关键兼容性要求
1. 兼容批量跑多个算法、多个函数、多个 suite。
2. 兼容只跑 BBO 单算法，也兼容 BBO vs SBO 对比。
3. 行为图类（search_process_overview / mean_fitness / trajectory_first_dim / final_population）优先服务 BBO。
4. 对于需要 2D 的图：
   - 若 dim ~= 2，则跳过
   - 不允许偷偷把当前正式 benchmark dim 改成 2
   - 如需额外 2D 演示，必须通过显式单独配置，不影响正式对比实验
5. Friedman 图只基于当前 experiment 目录下实际已有可比数据生成。
6. 不允许在绘图阶段混入未来实验或其他目录的数据。

七、日志与鲁棒性要求
请加入清晰日志：
- plot enabled / disabled
- generating which plot type
- skipped reason
- saved path

请确保：
- saveas / exportgraphics 失败时不会导致整个 benchmark 崩溃
- 文件夹不存在时自动 mkdir
- figure 保存后关闭
- 无图窗环境也能正常运行
- 没有 GUI 时不报错

八、你输出给我的内容格式
请不要只给解释，直接给“可执行修改方案”。

输出时按以下结构给出：
1. Task understanding
2. Minimal change plan
3. Files to add
4. Files to modify
5. Key code patches
6. How the plot switches work
7. Output directory structure
8. How to run
9. Risks / assumptions / pending verification

九、补充要求
1. 如果你发现仓库里已有类似 plotting 逻辑，请优先复用并统一入口，不要重复造轮子。
2. 如果当前主脚本名称不是 run_compare，也请你自动识别并把改动接到真实入口上。
3. 如果有多个 benchmark runner，请抽取一层通用 plot dispatcher。
4. 若某些图依赖统计检验但当前缺少函数，请实现一个最小可用版本，不引入重型外部依赖。
5. 注释中请明确：
   - 哪些图适合论文正文
   - 哪些图适合周报/过程分析
   - 哪些图默认关闭是为了避免正式批量实验变慢
6. 所有新增代码都要尽量 MATLAB 风格统一、可直接运行、易读、可复现。

请开始基于当前仓库实际文件结构检查并修改代码。
如果发现信息不足，请不要编造不存在的文件；请先基于现有仓库做最小可行实现，并在输出末尾明确列出待确认项。