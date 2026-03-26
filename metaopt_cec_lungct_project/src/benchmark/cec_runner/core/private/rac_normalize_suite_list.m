function suites = rac_normalize_suite_list(suites_in)
    if ischar(suites_in)
        suites = {lower(suites_in)};
        return;
    end
    if isstring(suites_in)
        suites = cellstr(lower(suites_in(:)'));
        return;
    end
    if iscell(suites_in)
        suites = cell(size(suites_in));
        for i = 1:numel(suites_in)
            suites{i} = lower(string(suites_in{i}));
            suites{i} = char(suites{i});
        end
        return;
    end
    error('suites must be char/string/cellstr.');
end
