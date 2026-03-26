# README_benchmark_flow

## Benchmark 主流程

1. entry/run_main_entry.m
2. core/run_experiment.m
3. core/normalize_config.m + core/resolve_mode.m
4. core/run_suite_batch.m
5. core/rac_run_benchmark_kernel.m
6. export/save_protocol_snapshot.m + export/export_benchmark_aggregate.m

## 公平性边界（不应随意更改）

- CEC 调用链
- FE 预算定义与 hard stop 行为
- runs、func_ids、dim、pop_size、maxFEs 的正式协议

## 可安全迭代层

- 路径初始化
- 保存与导出
- 统计表构造
- 可视化生成

## 结果树协议

- 默认：results/<suite>/<experiment_name>/
- pipeline 统一树：results/<result_group>/<experiment_name>/<suite>/

## 路径冲突防线

- 运行时：rac_run_benchmark_kernel 在单算法路径激活后执行关键同名函数冲突检查并写入日志。
- 静态：tools/check_path_collisions.m 可扫描 baselines 重名风险。
