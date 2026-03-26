function tpl = rac_make_suite_output_template()
    tpl = struct();
    tpl.suite = '';
    tpl.result_dir = '';
    tpl.summary = table();
    tpl.exact_match_warnings = table();
    tpl.total_runs = 0;
end
