# BBO Variant Layers

This folder keeps BBO variants for benchmark, ablation, and reproducibility.

## Layering policy

- stable: current mainline versions used for formal comparison.
- ablation: controllable modules/variants for mechanism attribution.
- deprecated: retained for reproducibility, not default in new runs.

## Canonical grouping source

- See algorithm_groups.m for current classification.
- Do not remove deprecated files without archive evidence and migration note.

## Naming policy

- Paper-facing names are managed by:
  src/benchmark/cec_runner/config/algorithm_alias_map.m
- Runtime alias resolution is managed by:
  src/benchmark/cec_runner/config/resolve_algorithm_alias.m
