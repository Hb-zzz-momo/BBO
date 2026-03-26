function export_experiment_summary_md(file_path, suite_result, run_cfg, mode_info, aggregate_export)
% export_experiment_summary_md
% Build a Chinese paper-facing concise markdown summary per suite.

    fid = fopen(file_path, 'w');
    if fid == -1
        error('Cannot open summary markdown: %s', file_path);
    end
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    suite_name = suite_result.suite;
    T = suite_result.summary;

    fprintf(fid, '# 基准实验摘要（%s）\n\n', upper(suite_name));
    fprintf(fid, '- 实验模式：`%s`\n', mode_info.mode);
    fprintf(fid, '- 实验名：`%s`\n', run_cfg.experiment_name);
    fprintf(fid, '- 时间戳：`%s`\n', mode_info.timestamp);
    fprintf(fid, '- 维度：`%d`，种群：`%d`，maxFEs：`%d`，运行次数：`%d`\n\n', ...
        run_cfg.dim, run_cfg.pop_size, run_cfg.maxFEs, run_cfg.runs);

    if isempty(T)
        fprintf(fid, '未找到可导出的汇总行。\n');
        return;
    end

    baseline = resolve_baseline_algorithm(run_cfg, T);
    fprintf(fid, '## 基线设置\n\n');
    fprintf(fid, '- 基线算法：`%s`\n\n', baseline);

    if isfield(suite_result, 'exact_match_warnings') && ~isempty(suite_result.exact_match_warnings)
        W = suite_result.exact_match_warnings;
        fprintf(fid, '## 一致性红色告警\n\n');
        fprintf(fid, '<span style="color:red"><strong>检测到同函数同 runs 的全量逐项相等结果，请先排查算法区分度与配置有效性，再用于结论。</strong></span>\n\n');
        fprintf(fid, '| function_id | algorithm_a | algorithm_b | equal_runs | expected_runs |\n');
        fprintf(fid, '| ---: | --- | --- | ---: | ---: |\n');
        for i = 1:height(W)
            fprintf(fid, '| %d | <span style="color:red">%s</span> | <span style="color:red">%s</span> | %d | %d |\n', ...
                W.function_id(i), string(W.algorithm_a(i)), string(W.algorithm_b(i)), ...
                W.equal_run_count(i), W.expected_runs(i));
        end
        fprintf(fid, '\n');
    end

    if ~isempty(aggregate_export.aggregate_table)
        fprintf(fid, '## 聚合统计\n\n');
        fprintf(fid, '| 算法 | 函数数 | 均值的均值 | 标准差的均值 | 平均耗时 | 平均已用FEs |\n');
        fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: |\n');
        A = aggregate_export.aggregate_table;
        for i = 1:height(A)
            fprintf(fid, '| %s | %d | %.6g | %.6g | %.6g | %.2f |\n', ...
                string(A.algorithm_name(i)), A.func_count(i), A.mean_of_mean(i), ...
                A.mean_of_std(i), A.mean_runtime(i), A.mean_used_FEs(i));
        end
        fprintf(fid, '\n');
    end

    fprintf(fid, '## 相对基线对比\n\n');
    [cmp, has_cmp] = compare_to_baseline(T, baseline);
    if has_cmp
        fprintf(fid, '| 算法 | 改善数 | 退化数 | 净增益 | 改善幅度 | 退化幅度 | 稳定性增量 | 耗时比 |\n');
        fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n');
        for i = 1:height(cmp)
            fprintf(fid, '| %s | %d | %d | %d | %.6g | %.6g | %.6g | %.4f |\n', ...
                string(cmp.algorithm(i)), cmp.improved(i), cmp.degraded(i), cmp.net_gain(i), ...
                cmp.improve_magnitude(i), cmp.degrade_magnitude(i), cmp.std_delta(i), cmp.runtime_ratio(i));
        end
        fprintf(fid, '\n');
    else
        fprintf(fid, '- 未找到可与基线比较的算法结果。\n\n');
    end

    fprintf(fid, '## 显著性检验\n\n');
    if ~isempty(aggregate_export.friedman_summary)
        F = aggregate_export.friedman_summary;
        fprintf(fid, '- Friedman p值：`%s`\n', num2str(F.p_value(1)));
        fprintf(fid, '- Friedman说明：`%s`\n', string(F.note(1)));
    else
        fprintf(fid, '- Friedman结果不可用。\n');
    end

    if ~isempty(aggregate_export.wilcoxon_table)
        W = aggregate_export.wilcoxon_table;
        finite_p = W.p_value(isfinite(W.p_value));
        if isempty(finite_p)
            fprintf(fid, '- Wilcoxon：无有效p值，请检查 csv 中 note 字段。\n');
        else
            fprintf(fid, '- Wilcoxon：有效p值个数 = `%d`\n', numel(finite_p));
        end
    else
        fprintf(fid, '- Wilcoxon结果不可用。\n');
    end
    fprintf(fid, '\n');

    fprintf(fid, '## 说明\n\n');
    fprintf(fid, '- Smoke 仅用于链路健康检查，不用于论文结论。\n');
    fprintf(fid, '- Formal 为固定 FE 协议下的正式结论模式。\n');
end

function baseline = resolve_baseline_algorithm(run_cfg, summary_table)
    candidates = strings(0, 1);
    if isfield(run_cfg, 'baseline_algorithm') && ~isempty(run_cfg.baseline_algorithm)
        candidates(end + 1, 1) = string(run_cfg.baseline_algorithm); %#ok<AGROW>
    end
    if isfield(run_cfg, 'algorithms') && ~isempty(run_cfg.algorithms)
        candidates(end + 1, 1) = string(run_cfg.algorithms{1}); %#ok<AGROW>
    end

    summary_names = string(summary_table.algorithm_name);
    summary_keys = normalize_name_list(summary_names);

    for i = 1:numel(candidates)
        key = normalize_one_name(candidates(i));
        hit_idx = find(summary_keys == key, 1, 'first');
        if ~isempty(hit_idx)
            baseline = char(summary_names(hit_idx));
            return;
        end
    end

    baseline = char(summary_names(1));
end

function out = normalize_name_list(names)
    out = strings(size(names));
    for i = 1:numel(names)
        out(i) = normalize_one_name(names(i));
    end
end

function key = normalize_one_name(name)
    raw = string(strtrim(name));
    key = upper(raw);

    try
        resolved = resolve_algorithm_alias(raw);
        if isstruct(resolved) && isfield(resolved, 'is_known') && resolved.is_known
            key = upper(string(resolved.internal_id));
        end
    catch
        % Keep fallback uppercase raw key when alias map is not available.
    end
end

function [cmp_table, has_cmp] = compare_to_baseline(summary_table, baseline)
    algs = unique(string(summary_table.algorithm_name), 'stable');
    algs = algs(algs ~= string(baseline));

    rows = table();
    for i = 1:numel(algs)
        alg = algs(i);
        fids = unique(summary_table.function_id, 'stable');

        improved = 0;
        degraded = 0;
        imp_mag = [];
        deg_mag = [];
        std_delta = [];
        rt_ratio = [];

        for j = 1:numel(fids)
            fid = fids(j);
            rb = summary_table(summary_table.function_id == fid & string(summary_table.algorithm_name) == string(baseline), :);
            ra = summary_table(summary_table.function_id == fid & string(summary_table.algorithm_name) == alg, :);
            if isempty(rb) || isempty(ra)
                continue;
            end

            delta = rb.mean(1) - ra.mean(1);
            if delta > 0
                improved = improved + 1;
                imp_mag(end + 1) = delta; %#ok<AGROW>
            elseif delta < 0
                degraded = degraded + 1;
                deg_mag(end + 1) = -delta; %#ok<AGROW>
            end

            std_delta(end + 1) = ra.std(1) - rb.std(1); %#ok<AGROW>
            if rb.avg_runtime(1) > 0
                rt_ratio(end + 1) = ra.avg_runtime(1) / rb.avg_runtime(1); %#ok<AGROW>
            end
        end

        row = table( ...
            alg, ...
            improved, ...
            degraded, ...
            improved - degraded, ...
            safe_mean(imp_mag), ...
            safe_mean(deg_mag), ...
            safe_mean(std_delta), ...
            safe_mean(rt_ratio), ...
            'VariableNames', {'algorithm','improved','degraded','net_gain','improve_magnitude','degrade_magnitude','std_delta','runtime_ratio'});
        rows = [rows; row]; %#ok<AGROW>
    end

    cmp_table = rows;
    has_cmp = ~isempty(cmp_table);
end

function v = safe_mean(x)
    if isempty(x)
        v = NaN;
    else
        v = mean(x);
    end
end
