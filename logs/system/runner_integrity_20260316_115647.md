# Runner Integrity Check

- timestamp: 2026-03-16 11:56:47
- pass: 1

| check | pass | note |
| --- | :---: | --- |
| main_entry_exists | 1 | entry/run_main_entry.m must exist |
| pipeline_default_core | 1 | Pipelines should support core default chain |
| stage_profile_suite_consistency | 1 | stage_profiles suites and func_ids must align |
| result_protocol_fields | 1 | default config should expose result_group/result_layout |
| path_collision_scan_available | 1 | collision scan should return table |
| run_all_compare_slimming_progress | 1 | TODO(low-risk follow-up): continue split to core/private |
| smoke_entry_path | 1 | smoke run completed |
