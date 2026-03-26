function paths = setup_benchmark_paths()
% setup_benchmark_paths
% Central path bootstrap for benchmark runner stack.
% Why: avoid repeated mfilename/fileparts/addpath blocks across entry scripts.

    this_file = mfilename('fullpath');
    core_dir = fileparts(this_file);
    runner_dir = fileparts(core_dir);

    paths = struct();
    paths.core_dir = core_dir;
    paths.runner_dir = runner_dir;
    paths.config_dir = fullfile(runner_dir, 'config');
    paths.export_dir = fullfile(runner_dir, 'export');
    paths.metrics_dir = fullfile(runner_dir, '..', 'metrics');
    paths.compat_dir = fullfile(runner_dir, 'compat');
    paths.compat_transitional_dir = fullfile(paths.compat_dir, 'transitional');
    paths.repo_root = fullfile(runner_dir, '..', '..', '..', '..');
    paths.mex_cec2017_dir = fullfile(paths.repo_root, 'external_assets', 'mex_bin', 'cec2017');
    paths.mex_cec2022_dir = fullfile(paths.repo_root, 'external_assets', 'mex_bin', 'cec2022');

    addpath(paths.runner_dir);
    addpath(paths.core_dir);
    addpath(paths.config_dir);
    addpath(paths.export_dir);
    if isfolder(paths.metrics_dir)
        addpath(paths.metrics_dir);
    end
    addpath(paths.compat_dir);
    if isfolder(paths.compat_transitional_dir)
        addpath(paths.compat_transitional_dir);
    end
    if isfolder(paths.mex_cec2017_dir)
        addpath(paths.mex_cec2017_dir);
    end
    if isfolder(paths.mex_cec2022_dir)
        addpath(paths.mex_cec2022_dir);
    end
end
