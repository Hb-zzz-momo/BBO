function localize_output_files_zh(result_dir)
% localize_output_files_zh
% Create Chinese-named aliases for key output files.
% Why: keep Chinese-first artifact naming while preserving backward compatibility.

    if nargin < 1 || ~isfolder(result_dir)
        return;
    end

    pairs = {
        'config.mat', '配置.mat';
        'summary.csv', '汇总.csv';
        'summary.mat', '汇总.mat';
        'run_manifest.csv', '运行清单.csv';
        'protocol_snapshot.csv', '协议快照.csv';
        'protocol_snapshot.mat', '协议快照.mat';
        'aggregate_stats.csv', '聚合统计.csv';
        'rank_table.csv', '秩次统计.csv';
        'wilcoxon_rank_sum.csv', 'Wilcoxon检验.csv';
        'friedman_summary.csv', 'Friedman汇总.csv';
        'friedman_ranks.csv', 'Friedman秩次.csv';
        'summary_exports.xlsx', '汇总导出.xlsx';
        'experiment_summary.md', '实验摘要.md';
        'aggregate_exports.mat', '聚合导出.mat'};

    for i = 1:size(pairs, 1)
        src = fullfile(result_dir, pairs{i, 1});
        dst = fullfile(result_dir, pairs{i, 2});
        copy_if_exists(src, dst);
    end

    copy_if_exists(fullfile(result_dir, 'logs', 'run_log.txt'), fullfile(result_dir, 'logs', '运行日志.txt'));
end

function copy_if_exists(src, dst)
    if ~isfile(src)
        return;
    end

    try
        copyfile(src, dst);
    catch
        % Localization copy is best-effort and must not break experiment flow.
    end
end
