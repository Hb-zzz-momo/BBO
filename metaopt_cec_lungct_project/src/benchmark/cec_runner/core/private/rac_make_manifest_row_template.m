function tpl = rac_make_manifest_row_template()
    tpl = struct();
    tpl.algorithm_name = '';
    tpl.suite = '';
    tpl.function_id = 0;
    tpl.run_id = 0;
    tpl.seed = 0;
    tpl.maxFEs = 0;
    tpl.used_FEs = 0;
    tpl.fe_control_mode = '';
    tpl.status = '';
    tpl.error_message = '';
end
