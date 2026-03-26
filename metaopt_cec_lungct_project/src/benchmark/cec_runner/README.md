# cec_runner

本目录只做 CEC benchmark 运行编排。

## 你只需要记住

1. 人类唯一主入口：entry/run_main_entry.m
2. 阶段脚本目录：pipelines/
3. 历史兼容目录：legacy/
4. 核心执行链：core/run_experiment.m -> core/rac_run_benchmark_kernel.m

## 目录职责

- entry/: 给人直接调用
- pipelines/: 给阶段任务调用
- pipeline_common/: 阶段公共壳
- core/: 系统内部执行层
- legacy/: 历史兼容与专项脚本
- config/: 协议配置与阶段模板
- export/: 导出与统计
- docs/: 使用文档

## 结果输出

默认输出到 results/<suite>/<experiment_name>/。

当使用 pipeline 统一实验树协议（result_layout=experiment_then_suite）时，输出为：

- results/<result_group>/<experiment_name>/<suite>/

数值结果仍包含 summary、raw_runs、curves、logs 与统计导出文件。
