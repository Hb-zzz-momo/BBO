# external_assets 说明

- 作用：存放外部资产（如 CEC 输入数据、mex 二进制）。
- 子目录：
  - mex_bin：按 suite 存放 CEC mex 与所需 input_data
  - cec_input_data：输入数据镜像备份
- 约束：主源码目录不再直接混放此类资产。
