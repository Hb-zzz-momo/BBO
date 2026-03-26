function run_routea_three_schemes_compare_dual_budget()
% run_routea_three_schemes_compare_dual_budget
% Run three Route-A schemes on two FE budgets via unified entry.
% Why unified entry: always generate complete exports (rank/statistics/summary markdown/notes).

    repo_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    runner_root = fullfile(repo_root, 'src', 'benchmark', 'cec_runner');
    addpath(genpath(runner_root));
    addpath(fullfile(runner_root, 'core'), '-begin');
    addpath(fullfile(runner_root, 'entry'), '-begin');

    budgets = [30000, 300000];
    runs = 10;
    suite_name = 'cec2022';
    func_ids = [6, 7, 8, 10, 11, 12];
    dim = 10;
    pop_size = 30;
    seed = 20260322;

    algs = { ...
        'A_ARCHIVE_ONLY', ...
        'A_ARCHIVE_REPLAY', ...
        'A_ARCHIVE_DISPERSAL_REPLAY_SHSA'};

    result_dirs = cell(numel(budgets), 1);

    for i = 1:numel(budgets)
        max_fes = budgets(i);
        exp_name = sprintf('routeA_three_schemes_compare_fes%d_runs%d_20260322_final', max_fes, runs);

        cfg = struct();
        cfg.mode = 'formal';
        cfg.suites = {suite_name};
        cfg.algorithms = algs;
        cfg.dim = dim;
        cfg.pop_size = pop_size;
        cfg.maxFEs = max_fes;
        cfg.rng_seed = seed;
        cfg.explicit_experiment_name = exp_name;
        cfg.result_root = 'results';
        cfg.result_group = 'benchmark/research_pipeline';
        cfg.save_curve = true;
        cfg.save_mat = true;
        cfg.save_csv = true;
        cfg.plot = struct('enable', false, 'show', false, 'save', false);
        cfg.formal = struct('runs', runs, 'func_ids', func_ids);

        report = run_main_entry(cfg);
        result_dirs{i} = report.output.suite_results(1).result_dir;
    end

    merged_rows = table();
    for i = 1:numel(result_dirs)
        summary_path = fullfile(result_dirs{i}, 'summary.csv');
        if ~isfile(summary_path)
            error('Missing summary.csv: %s', summary_path);
        end
        t = readtable(summary_path);
        [~, exp_name] = fileparts(result_dirs{i});
        t.experiment_name = repmat(string(exp_name), height(t), 1);
        merged_rows = [merged_rows; t]; %#ok<AGROW>
    end

    merged_root = fullfile(repo_root, 'results', 'benchmark', 'research_pipeline', suite_name, ...
        sprintf('routeA_three_schemes_compare_dual_budget_merge_20260322'));
    if ~isfolder(merged_root)
        mkdir(merged_root);
    end

    out_csv = fullfile(merged_root, 'summary_dual_budget_three_schemes.csv');
    writetable(merged_rows, out_csv);

    fprintf('Dual-budget merged summary saved: %s\n', out_csv);
end
