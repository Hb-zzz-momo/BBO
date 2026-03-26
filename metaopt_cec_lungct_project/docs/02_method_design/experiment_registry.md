# Experiment Registry (Single Source)

本文件定义实验命名的唯一映射规则。

## Authoritative source

- MATLAB source of truth: src/benchmark/cec_runner/config/algorithm_alias_map.m
- Resolver used by runtime: src/benchmark/cec_runner/config/resolve_algorithm_alias.m

## Three-layer naming

| paper_name | internal_id | entry_func | legacy_aliases |
| --- | --- | --- | --- |
| V3-Base | v3_base | BBO_v3_baseline | V3_BASE, V3_BASELINE |
| V3-Dir | v3_dir | BBO_v3_dir_small_step | V3_DIR, V3_FAST_SIMPLE_A, V3_DIR_SMALL_STEP |
| V3-DirLate | v3_dir_late | BBO_v3_dir_small_step_late_local_refine | V3_DIR_LATE, V3_FAST_SIMPLE_B, V3_DIR_SMALL_STEP_LATE_LOCAL_REFINE |
| V3-DirStagOnly | v3_dir_stag_only | BBO_v3_dir_stag_only | V3_DIR_STAG_ONLY, V3_DIR_STAGNATION |
| V3-DirStagBottomHalf | v3_dir_stag_bottom_half | BBO_v3_dir_stag_bottom_half | V3_DIR_STAG_BOTTOM_HALF, V3_DIR_ELITE_ONLY |
| V3-DirStagBottomHalfLateRefine | v3_dir_stag_bottom_half_late_refine | BBO_v3_dir_stag_bottom_half_late_refine | V3_DIR_STAG_BOTTOM_HALF_LATE_REFINE |
| V3-HybridA | v3_hybrid_a | BBO_v3_dir_stag_bottom_half_late_refine | V3_HYBRID_A, V3_HYBRID_A_DIR_STAG |
| V3-HybridB | v3_hybrid_b | BBO_v3_dir_clipped_stag_bottom_half_late_refine | V3_HYBRID_B, V3_HYBRID_B_DIR_SMALL, V3_DIR_CLIPPED_STAG_BOTTOM_HALF_LATE_REFINE |

## Usage rules

- 论文与图表使用 paper_name。
- 配置和调度使用 internal_id（大小写不敏感）。
- MATLAB 实际调用统一落到 entry_func。
- 新映射只允许在 algorithm_alias_map.m 增加，禁止散落在 pipeline/core 中硬编码。
