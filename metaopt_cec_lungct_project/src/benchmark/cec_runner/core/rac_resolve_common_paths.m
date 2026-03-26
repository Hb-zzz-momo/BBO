function paths = rac_resolve_common_paths()
% Resolve repository-level paths required by cec_runner core.

    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);

    paths = struct();
    % this_dir = src/benchmark/cec_runner/core, repo root needs 4 levels up.
    repo_root = this_dir;
    for i = 1:4
        repo_root = fileparts(repo_root);
    end
    paths.repo_root = repo_root;

    paths.sbo_pack_root = fullfile(paths.repo_root, 'third_party', 'sbo_raw', ...
        'Status_based_Optimization_SBO_MATLAB_codes_extracted');
    paths.mealpy_converted_root = fullfile(paths.sbo_pack_root, 'mealpy_converted_originals');
    paths.compat_dir = fullfile(paths.repo_root, 'src', 'benchmark', 'cec_runner', 'compat');
    paths.bbo_root = fullfile(paths.repo_root, 'third_party', 'bbo_raw', ...
        'Source_code_BBO_MATLAB_VERSION_extracted', 'Source_code_BBO_MATLAB_VERSION');
    paths.improved_bbo_root = fullfile(paths.repo_root, 'src', 'improved', 'algorithms', 'BBO');
    paths.mex_cec2017_dir = fullfile(paths.repo_root, 'external_assets', 'mex_bin', 'cec2017');
    paths.mex_cec2022_dir = fullfile(paths.repo_root, 'external_assets', 'mex_bin', 'cec2022');

    if ~isfolder(paths.sbo_pack_root)
        error('SBO package root folder not found: %s', paths.sbo_pack_root);
    end
    if ~isfolder(paths.compat_dir)
        error('Compatibility folder not found: %s', paths.compat_dir);
    end
    if ~isfolder(paths.bbo_root)
        error('BBO root folder not found: %s', paths.bbo_root);
    end

    if ~isfolder(paths.mex_cec2017_dir)
        error('CEC2017 mex folder not found: %s', paths.mex_cec2017_dir);
    end

    if ~isfolder(paths.mex_cec2022_dir)
        warning('CEC2022 mex folder not found: %s', paths.mex_cec2022_dir);
    end
end
