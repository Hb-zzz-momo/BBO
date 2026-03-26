function spec = resolve_algorithm_runtime_spec(paths, suite_name, canonical_token, entry_name)
% resolve_algorithm_runtime_spec
% Public runtime-spec resolver for benchmark algorithms.
% Why: keep final comparison workflow and core inventory on the same source of truth.

    if nargin < 4
        entry_name = '';
    end

    token = upper(string(strtrim(canonical_token)));
    entry_name = char(string(entry_name));

    spec = struct();
    spec.name = char(token);
    spec.entry_name = entry_name;
    spec.algorithm_dir = '';
    spec.budget_arg = '';
    spec.output_mode = '';
    spec.is_supported = false;
    spec.source_group = '';

    if isempty(spec.entry_name)
        spec.entry_name = local_default_entry_name(token);
    end

    if strcmpi(token, 'BBO_BASE')
        spec.is_supported = true;
        spec.algorithm_dir = local_suite_dir(paths, suite_name);
        spec.budget_arg = 'max_iter';
        spec.output_mode = 'score_pos_curve';
        spec.source_group = 'third_party_bbo_raw';
        return;
    end

    if startsWith(token, "BBO_IMPROVED_", 'IgnoreCase', true) || ...
            startsWith(token, "V3_", 'IgnoreCase', true) || ...
            startsWith(token, "ROUTE_", 'IgnoreCase', true)
        spec.is_supported = true;
        spec.algorithm_dir = paths.improved_bbo_root;
        spec.budget_arg = 'max_iter';
        spec.output_mode = 'score_pos_curve';
        spec.source_group = 'src_improved_bbo';
        return;
    end

    switch upper(token)
        case 'SBO'
            spec = local_make_spec(spec, 'SBO', fullfile(paths.sbo_pack_root, 'Status-based Optimization (SBO)-2025'), 'maxFEs', 'score_pos_curve', 'third_party_sbo_raw');
        case 'HGS'
            spec = local_make_spec(spec, 'HGS', fullfile(paths.sbo_pack_root, 'Hunger Games Search (HGS)-2021'), 'max_iter', 'score_pos_curve', 'third_party_sbo_raw');
        case 'SMA'
            spec = local_make_spec(spec, 'SMA', fullfile(paths.sbo_pack_root, 'Slime mould algorithm (SMA)-2020'), 'max_iter', 'score_pos_curve', 'third_party_sbo_raw');
        case 'HHO'
            spec = local_make_spec(spec, 'HHO', fullfile(paths.sbo_pack_root, 'Harris Hawk Optimization (HHO)-2019'), 'max_iter', 'score_pos_curve', 'third_party_sbo_raw');
        case 'RUN'
            spec = local_make_spec(spec, 'RUN', fullfile(paths.sbo_pack_root, 'Runge Kutta Optimization (RUN)-2021'), 'max_iter', 'score_pos_curve', 'third_party_sbo_raw');
        case 'INFO'
            spec = local_make_spec(spec, 'INFO', fullfile(paths.sbo_pack_root, 'Weighted Mean of Vectors (INFO)-2022'), 'max_iter', 'score_pos_curve', 'third_party_sbo_raw');
        case 'MGO'
            spec = local_make_spec(spec, 'MGO', fullfile(paths.sbo_pack_root, 'Moss Growth Optimization (MGO)-2024'), 'maxFEs', 'pos_curve', 'third_party_sbo_raw');
        case 'PLO'
            spec = local_make_spec(spec, 'PLO', fullfile(paths.sbo_pack_root, 'Polar Lights Optimizer (PLO)-2024'), 'maxFEs', 'pos_score_curve', 'third_party_sbo_raw');
        case 'PO'
            spec = local_make_spec(spec, 'PO', fullfile(paths.sbo_pack_root, 'Parrot Optimizer (PO)-2024'), 'max_iter', 'po', 'third_party_sbo_raw');
        case 'PSO'
            spec = local_make_spec(spec, 'PSO', paths.mealpy_converted_root, 'max_iter', 'score_pos_curve', 'mealpy_converted_originals');
        case 'DE'
            spec = local_make_spec(spec, 'DE', paths.mealpy_converted_root, 'max_iter', 'score_pos_curve', 'mealpy_converted_originals');
        case 'GWO'
            spec = local_make_spec(spec, 'GWO', paths.mealpy_converted_root, 'max_iter', 'score_pos_curve', 'mealpy_converted_originals');
        case 'WOA'
            spec = local_make_spec(spec, 'WOA', paths.mealpy_converted_root, 'max_iter', 'score_pos_curve', 'mealpy_converted_originals');
        case 'SHADE'
            spec = local_make_spec(spec, 'SHADE', paths.mealpy_converted_root, 'max_iter', 'score_pos_curve', 'mealpy_converted_originals');
        case 'BBO_ORIG'
            spec = local_make_spec(spec, 'BBO_ORIG', paths.mealpy_converted_root, 'max_iter', 'score_pos_curve', 'mealpy_converted_originals');
        case 'RIME'
            spec = local_make_spec(spec, 'RIME', fullfile(paths.sbo_pack_root, 'Rime Optimization Algorithm (RIME)-2023'), 'max_iter', 'score_pos_curve', 'third_party_sbo_raw');
        otherwise
            % Leave unsupported.
    end
end

function spec = local_make_spec(spec, entry_name, algorithm_dir, budget_arg, output_mode, source_group)
    spec.is_supported = true;
    spec.entry_name = entry_name;
    spec.algorithm_dir = algorithm_dir;
    spec.budget_arg = budget_arg;
    spec.output_mode = output_mode;
    spec.source_group = source_group;
end

function entry_name = local_default_entry_name(token)
    switch upper(token)
        case 'BBO_BASE'
            entry_name = 'BBO';
        otherwise
            entry_name = char(token);
    end
end

function suite_dir = local_suite_dir(paths, suite_name)
    if strcmpi(string(suite_name), "cec2022")
        suite_dir = fullfile(paths.bbo_root, 'CEC2022');
    else
        suite_dir = fullfile(paths.bbo_root, 'CEC2017');
    end
end
