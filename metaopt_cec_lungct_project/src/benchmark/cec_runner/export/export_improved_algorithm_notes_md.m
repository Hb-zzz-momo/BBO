function note_path = export_improved_algorithm_notes_md(result_dir, summary_table, run_cfg)
% export_improved_algorithm_notes_md
% Auto-generate improved algorithm explanation document for each experiment.

    note_path = fullfile(result_dir, 'improved_algorithm_notes.md');

    if isempty(summary_table) || ~istable(summary_table)
        write_empty_note(note_path, run_cfg);
        return;
    end

    algs = unique(string(summary_table.algorithm_name), 'stable');
    items = collect_improved_items(algs);

    fid = fopen(note_path, 'w');
    if fid == -1
        error('Cannot write improved algorithm note: %s', note_path);
    end
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# 改进算法说明文档\n\n');
    fprintf(fid, '- 生成时间: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '- 实验名: %s\n', string(run_cfg.experiment_name));
    fprintf(fid, '- 目的: 记录本次实验中改进算法“改进了什么”与“未改什么”，用于复现与论文写作。\n\n');

    fprintf(fid, '## 公平性声明\n\n');
    fprintf(fid, '1. 本文档描述的是算法机制差异，不修改 benchmark 协议参数。\n');
    fprintf(fid, '2. 预算、停止条件、函数集合、维度、种群规模由实验配置统一控制。\n');
    fprintf(fid, '3. smoke 结果仅用于链路与方向筛选，不作为最终论文结论。\n\n');

    if isempty(items)
        fprintf(fid, '## 改进算法条目\n\n');
        fprintf(fid, '未检测到改进算法（仅 baseline 或 comparison）。\n');
        return;
    end

    fprintf(fid, '## 改进算法条目\n\n');
    for i = 1:numel(items)
        it = items(i);
        fprintf(fid, '### %s\n\n', it.algorithm_name);
        fprintf(fid, '- 类型: %s\n', it.tier);
        fprintf(fid, '- 对应入口函数: %s\n', it.entry_func);
        fprintf(fid, '- 核心思想: %s\n', it.core_idea);
        fprintf(fid, '- 具体改进点:\n');
        for k = 1:numel(it.improvements)
            fprintf(fid, '  - %s\n', it.improvements{k});
        end
        fprintf(fid, '- 预期收益: %s\n', it.expected_gain);
        fprintf(fid, '- 预期风险: %s\n', it.expected_risk);
        fprintf(fid, '- 保持不变项: %s\n\n', it.fairness_invariant);
    end
end

function write_empty_note(note_path, run_cfg)
    fid = fopen(note_path, 'w');
    if fid == -1
        return;
    end
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# 改进算法说明文档\n\n');
    fprintf(fid, '- 实验名: %s\n', string(run_cfg.experiment_name));
    fprintf(fid, '- 说明: 当前无 summary 表，无法生成改进算法详细说明。\n');
end

function items = collect_improved_items(algs)
    items = repmat(struct( ...
        'algorithm_name', '', ...
        'tier', '', ...
        'entry_func', '', ...
        'core_idea', '', ...
        'improvements', {{}}, ...
        'expected_gain', '', ...
        'expected_risk', '', ...
        'fairness_invariant', ''), 1, 0);

    for i = 1:numel(algs)
        resolved = resolve_algorithm_alias(char(algs(i)));
        tier = lower(string(resolve_tier_by_internal_id(resolved.internal_id)));
        if ~(tier == "improved" || tier == "ablation" || tier == "ablation_failed_but_informative")
            continue;
        end

        desc = resolve_description(resolved);

        item = struct();
        item.algorithm_name = char(algs(i));
        item.tier = char(tier);
        item.entry_func = desc.entry_func;
        item.core_idea = desc.core_idea;
        item.improvements = desc.improvements;
        item.expected_gain = desc.expected_gain;
        item.expected_risk = desc.expected_risk;
        item.fairness_invariant = desc.fairness_invariant;

        items(end + 1) = item; %#ok<AGROW>
    end
end

function tier = resolve_tier_by_internal_id(internal_id)
    tier = 'unknown';
    items = algorithm_alias_map();
    target = lower(string(internal_id));
    for i = 1:numel(items)
        if lower(string(items(i).internal_id)) == target
            tier = items(i).tier;
            return;
        end
    end
end

function desc = resolve_description(resolved)
    token = lower(string(resolved.internal_id));

    desc = struct();
    desc.entry_func = char(resolved.entry_func);
    desc.core_idea = '在 baseline 框架上加入最小改进机制。';
    desc.improvements = {
        '引入局部机制提升探索-开发平衡。', ...
        '保持统一接口，便于与 baseline 公平对比。'};
    desc.expected_gain = '在部分函数上获得更优均值或稳定性。';
    desc.expected_risk = '参数敏感导致在某些函数上退化。';
    desc.fairness_invariant = '不改变 suite、func_ids、maxFEs、runs、dim、pop_size 与 stop criteria。';

    switch char(token)
        case 'bbo_improved_v1'
            desc.core_idea = '模块化改进（SEL + GDP + ESC），支持开关化消融。';
            desc.improvements = {
                'SEL: 选择性精英学习，降低盲目更新。', ...
                'GDP: 停滞/多样性/成功率门控的方向推动。', ...
                'ESC: 反停滞逃逸机制，用于局部困陷恢复。'};
            desc.expected_gain = '提升复杂函数下的收敛效率并增强恢复能力。';
            desc.expected_risk = '模块组合可能提高参数耦合，需消融验证。';

        case 'bbo_improved_v2'
            desc.core_idea = '在 v1 基础上调整机制耦合与触发策略。';
            desc.improvements = {
                '优化触发条件与更新节奏。', ...
                '保持 benchmark 接口一致，便于横向比较。'};
            desc.expected_gain = '在更多函数上获得更平衡表现。';
            desc.expected_risk = '触发阈值不当会导致收益不稳定。';

        case {'bbo_improved_v3', 'v3_base', 'v3_dir', 'v3_dir_late', 'v3_dir_late_gate', ...
              'v3_dir_stag_only', 'v3_dir_stag_bottom_half', 'v3_dir_stag_bottom_half_late_refine', ...
              'v3_hybrid_a', 'v3_hybrid_b'}
            desc.core_idea = '方向模块与停滞触发策略的分层改进，强调 simple/complex 平衡。';
            desc.improvements = {
                '方向更新由保守触发机制控制，降低全局扰动。', ...
                '可选 late refine，聚焦后期开发阶段。', ...
                '支持 bottom-half 作用对象，保护优秀个体。'};
            desc.expected_gain = '保持复杂函数收益并尽量减少简单函数退化。';
            desc.expected_risk = '若阈值偏激，可能造成 simple 函数恢复不足。';

        case 'bbo_improved_v4'
            desc.core_idea = '在方向性与局部精修之间做更强耦合控制。';
            desc.improvements = {
                '强化门控策略，控制改进模块干预时机。', ...
                '提升后期局部精修与全局探索的切换质量。'};
            desc.expected_gain = '改善中后期收敛质量。';
            desc.expected_risk = '门控设计不合理时会降低早期探索。';

        case 'route_a_differential_generator_bbo'
            desc.core_idea = 'Route A: 双主线候选生成（BBO 主行为 + 差分变异/交叉主生成器）并行竞争。';
            desc.improvements = {
                '每轮为每个个体并行生成 BBO 候选与 DE 候选。', ...
                '先在双候选中选优，再与个体当前解竞争，形成主生成器增强。', ...
                '使用最小参数集（F、CR、beta_best）保持可控复杂度。'};
            desc.expected_gain = '在 difficult/hybrid/composition 函数上提高方向性搜索冲击力。';
            desc.expected_risk = '方向增强可能导致简单函数或平滑函数上的方差上升。';

        case 'route_a_current_bbo'
            desc.core_idea = 'A_current: Route A 当前行为的标准化入口版本。';
            desc.improvements = {
                '不改变当前 Route A 算法行为。', ...
                '仅作为 A family 对照版本以保证公平比较。'};
            desc.expected_gain = '提供稳定可复现实验对照。';
            desc.expected_risk = '继承当前版本已知风险（如特定函数波动）。';

        case 'route_a_pbest_bbo'
            desc.core_idea = 'A_pbest: 将单 best 参考替换为 p-best 精英池随机参考。';
            desc.improvements = {
                '在候选生成中将单 best 替换为 p-best 参考对象。', ...
                '保持差分触发与接受机制不变，不引入 gated/safe。'};
            desc.expected_gain = '缓解平台锁死，提升中后期搜索多样性。';
            desc.expected_risk = 'p-best 比例不当可能降低收敛速度。';

        case 'route_a_gated_bbo'
            desc.core_idea = 'A_gated: 为差分主生成器增加门控激活调度。';
            desc.improvements = {
                '按进度调度差分候选激活概率。', ...
                '仅调整差分触发，不修改参考对象与接受机制。'};
            desc.expected_gain = '降低差分过猛触发带来的负收益风险。';
            desc.expected_risk = '门控过保守时可能错失有效全局跳跃。';

        case 'route_a_safe_bbo'
            desc.core_idea = 'A_safe: 在候选接受阶段加入安全接受与缩步复核。';
            desc.improvements = {
                '对大步候选执行缩步复核，必要时回退到更保守更新。', ...
                '不修改参考对象选择，不引入 gated 触发策略。'};
            desc.expected_gain = '降低偶发失稳与极端爆炸风险。';
            desc.expected_risk = '额外复核评估可能增加运行时间。';

        case 'route_a_pbest_gated_bbo'
            desc.core_idea = 'A_pbest_gated: 联合 p-best 参考与 gated 差分触发。';
            desc.improvements = {
                '使用 p-best 参考替代单 best。', ...
                '使用门控调度控制差分候选激活。', ...
                '不引入 safe acceptance 机制。'};
            desc.expected_gain = '同时缓解平台锁死与过触发负收益风险。';
            desc.expected_risk = '双机制耦合可能带来参数协同敏感性。';

        case 'route_a_late_pbest_bbo'
            desc.core_idea = 'Direction1: CURRENT 主链 + 后期小范围 PBEST 精修（仅精英且触发式激活）。';
            desc.improvements = {
                '前中期保持 CURRENT 行为，不提前承担 p-best 风险。', ...
                '仅在后期且满足停滞/低多样性触发时启用 PBEST。', ...
                '仅对 elite 个体应用 PBEST 候选，并采用贪心接受。'};
            desc.expected_gain = '保留 CURRENT 稳定性，同时获得后期精修收益。';
            desc.expected_risk = '触发阈值不当可能使精修不足或过晚。';

        case 'route_a_safe_conservative_bbo'
            desc.core_idea = 'Direction2: SAFE 保守增强线（小步长、小扰动、强约束、少模块）。';
            desc.improvements = {
                '收紧差分幅度与扰动尺度。', ...
                '加入 donor 步长上限与缩步复核接受。', ...
                '不引入 p-best 与 gated 机制。'};
            desc.expected_gain = '降低低预算条件下的突发爆炸风险。';
            desc.expected_risk = '过于保守可能限制复杂函数后期开发能力。';

        case {'route_a_budget_adaptive_bbo', 'route_a_budget_adaptive_baseline_bbo'}
            desc.core_idea = 'Direction3: 预算感知调度（低预算弱化 PBEST，高预算后期增强 PBEST）。';
            desc.improvements = {
                '按预算模式（短预算/长预算）切换 PBEST 强度策略。', ...
                '按进度阶段分配 PBEST 注入概率与精英覆盖范围。', ...
                '保持 CURRENT 主链为主体，PBEST 作为时机敏感增强。'};
            desc.expected_gain = '解释并利用 30k 与 300k 下机制时机差异。';
            desc.expected_risk = '预算模式阈值对不同函数维度可能敏感。';

        case 'route_a_budget_adaptive_success_history_bbo'
            desc.core_idea = '主线B：Budget_adaptive + success-history 步长自适应。';
            desc.improvements = {
                '不引入 archive/replay/dispersal，聚焦步长尺度自适应。', ...
                '根据近期成功步长更新步长中心，动态调整搜索尺度。', ...
                '同一机制同时影响远跳、精修、扰动与差分更新幅度。'};
            desc.expected_gain = '缓解“有时跳太猛、有时又不够”的尺度失配问题。';
            desc.expected_risk = '若历史窗口过短，步长中心可能抖动。';

        case 'route_a_budget_adaptive_success_history_dispersal_bbo'
            desc.core_idea = '主线C：Budget_adaptive + success-history + state-triggered controlled dispersal。';
            desc.improvements = {
                '仅在停滞状态触发受控扩散，不做全群体无条件扰动。', ...
                '扩散对象限定为尾部子集，避免破坏头部守门个体。', ...
                '与 replay 解耦，避免多机制同时高频触发。'};
            desc.expected_gain = '在锁死时提供必要脱困，同时减少对守门函数的副作用。';
            desc.expected_risk = '触发阈值过严会降低脱困覆盖率。';

        case 'route_a_budget_adaptive_archive_only_bbo'
            desc.core_idea = '分层消融 L1：baseline + archive。';
            desc.improvements = {
                '在主链不变前提下，增加停滞触发的精英 archive 逃逸。', ...
                '维持触发次数与冷却门控，避免高频扰动。'};
            desc.expected_gain = '缓解 F11 类停滞锁死，延长后期搜索寿命。';
            desc.expected_risk = '仅靠 archive 可能不足以修复 F10 坏 run。';

        case 'route_a_budget_adaptive_archive_replay_bbo'
            desc.core_idea = '分层消融 L2：archive + replay。';
            desc.improvements = {
                '在 archive 触发链上加入成功步长回放（replay）。', ...
                '优先在尾部个体执行 replay 候选并贪心接受。'};
            desc.expected_gain = '提高停滞触发后的实战命中率。';
            desc.expected_risk = 'replay 过强可能导致群体同质化。';

        case 'route_a_budget_adaptive_archive_replay_shsa_bbo'
            desc.core_idea = '分层消融 L3：archive + replay + success-history。';
            desc.improvements = {
                '保留 L2，并加入成功历史步长记忆。', ...
                '中后期按成功步长统计调整步长中心。'};
            desc.expected_gain = '提升后期复活后微调效率。';
            desc.expected_risk = '步长记忆与 replay 可能产生耦合敏感性。';

        case 'route_a_budget_adaptive_archive_dispersal_replay_shsa_bbo'
            desc.core_idea = '分层消融 L4：archive + dispersal + replay + success-history。';
            desc.improvements = {
                '在 L3 基础上增加停滞分散重启（dispersal）。', ...
                '当 archive/replay 无收益时，对尾部个体执行受控再扩散。'};
            desc.expected_gain = '增强复杂组合函数下的跨盆地复活能力。';
            desc.expected_risk = '若触发过频，可能损伤 F6/F7/F8 既有优势。';

        case 'route_a_budget_adaptive_f11_patch_bbo'
            desc.core_idea = '主线 Route A 的单点小修版本：仅增加受控局部脱困，专项瞄准 F11 停滞。';
            desc.improvements = {
                '仅在停滞连续达到阈值后触发，不改基础候选生成主链。', ...
                '触发对象默认限定为尾部个体，减少对头部稳定个体扰动。', ...
                '候选替换必须优于当前族内精英，避免低质量跳变。', ...
                '在 composition/hybrid 函数上自动降低触发强度。'};
            desc.expected_gain = '在不扩模块与不改协议前提下，提升 F11 脱困机会。';
            desc.expected_risk = '精英优于门槛较严格，触发成功率可能偏低。';

        case 'route_a_budget_adaptive_shsa_bbo'
            desc.core_idea = '失败但有信息量的消融分支：budget-adaptive + 成功历史步长自适应（SHSA）。';
            desc.improvements = {
                '中后期根据成功步长历史更新步长中心。', ...
                '停滞阶段允许轻度步长提升以增强突破能力。', ...
                '保留预算感知 PBEST 调度，不改变主协议。'};
            desc.expected_gain = '为主线提供了步长历史控制思路的反例证据。';
            desc.expected_risk = '在当前口径下未稳定改善主线目标函数，暂不并入主线。';

        case 'route_a_budget_adaptive_archive_escape_bbo'
            desc.core_idea = '失败但有信息量的消融分支：budget-adaptive + archive_escape。';
            desc.improvements = {
                '维护小型精英 archive 保存近期有效结构。', ...
                '停滞时对尾部个体执行受控远跳候选并贪心接受。', ...
                '仅在中后期触发，降低对前期稳定性的扰动。'};
            desc.expected_gain = '为主线提供了“脱困强度过高会伤害稳定性”的反例证据。';
            desc.expected_risk = '当前版本在目标口径下未达到主线稳健标准，保留为信息型消融分支。';

        case 'route_b_dual_population_bbo'
            desc.core_idea = 'Route B 已归档：当前仅保留占位入口并回退到 V3 baseline kernel。';
            desc.improvements = {
                'Route B 实核代码快照已迁入 archive/achieve/unused_versions。', ...
                '活动位仅用于保持接口兼容与链路可运行。'};
            desc.expected_gain = '归档后可减少活动算法面，便于聚焦当前主线。';
            desc.expected_risk = '当前占位结果不代表 Route B 实核能力。';

        case 'route_c_success_history_pool_bbo'
            desc.core_idea = 'Route C 已归档：当前仅保留占位入口并回退到 V3 baseline kernel。';
            desc.improvements = {
                'Route C 实核代码快照已迁入 archive/achieve/unused_versions。', ...
                '活动位仅用于保持接口兼容与链路可运行。'};
            desc.expected_gain = '归档后可减少活动算法面，便于聚焦当前主线。';
            desc.expected_risk = '当前占位结果不代表 Route C 实核能力。';

        case 'route_d_multi_elite_reference_bbo'
            desc.core_idea = 'top-k 多精英参考的方向更新（GDP-only minimal）。';
            desc.improvements = {
                '用多精英混合参考替代单一方向参考。', ...
                '增强方向信息鲁棒性。'};
            desc.expected_gain = '提升复杂地形下跳出局部最优能力。';
            desc.expected_risk = '若精英集合波动大，可能放大方差。';
    end
end
