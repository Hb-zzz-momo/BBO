# SBO Baseline Adapter Directory

- 当前目录角色：保留 SBO 适配说明与可控入口，不再混放第三方原始 MATLAB 包。
- 第三方原始 SBO MATLAB 包位置：third_party/sbo_raw/Status_based_Optimization_SBO_MATLAB_codes_extracted/
- SBO Python 原始包仍位于本目录用于轻量对照，可后续迁移到 third_party。

维护规则：
- 新增内容优先放适配层。
- 原始包与论文附件统一放 third_party 或 archive。
