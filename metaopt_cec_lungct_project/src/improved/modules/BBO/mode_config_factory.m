function cfg = mode_config_factory(mode, max_iter)
% mode_config_factory
% Build v3 ablation mode configuration in one place for reuse and ablation control.

    cfg = struct();

    cfg.use_fast_A = false;
    cfg.use_fast_B = false;
    cfg.dir_late = false;
    cfg.dir_stagnation = false;
    cfg.dir_elite_only = false;
    cfg.dir_small_step = false;
    cfg.use_late_local_refine = false;
    cfg.use_directional_gate = false;
    cfg.use_stag_trigger_only = false;
    cfg.direction_bottom_half_only = false;
    cfg.use_clipped_direction_step = false;
    cfg.local_refine_state_trigger = false;
    cfg.local_refine_use_gap_gate = false;

    cfg.stall_window = max(5, round(0.08 * max_iter));
    cfg.late_start = 0.60;
    cfg.tau_dir = max(4, round(0.06 * max_iter));
    cfg.alpha_dir = 0.22;
    cfg.dir_cap_std_ratio = 0.10;
    cfg.dir_cap_range_ratio = 0.05;
    cfg.dir_noise_ratio = 0.20;
    cfg.dir_near_best_ratio = 0.06;
    cfg.dir_near_best_shrink = 0.55;

    cfg.local_refine_start = 0.70;
    cfg.local_refine_no_improve_max = max(2, round(0.03 * max_iter));
    cfg.local_refine_diversity_threshold = 0.12;
    cfg.local_refine_prob = 0.20;
    cfg.tau_refine = max(5, round(0.07 * max_iter));
    cfg.refine_elite_spread_threshold = 0.015;
    cfg.refine_gap_window = max(4, round(0.04 * max_iter));
    cfg.refine_gap_ratio_threshold = 0.08;
    cfg.gate_stall_window = max(4, round(0.06 * max_iter));
    cfg.gate_lag_ratio = 0.18;
    cfg.gate_min_diversity = 0.08;
    cfg.gate_early_stage = 0.35;

    switch char(mode)
        case 'baseline'
        case 'fast_simple_a'
            cfg.use_fast_A = true;
        case 'fast_simple_b'
            cfg.use_fast_B = true;
        case 'dir_late'
            cfg.dir_late = true;
        case 'dir_stagnation'
            cfg.dir_stagnation = true;
        case 'dir_elite_only'
            cfg.dir_elite_only = true;
        case 'dir_small_step'
            cfg.dir_small_step = true;
            cfg.dir_late = true;
        case 'hybrid_a_dir_stag'
            cfg.use_fast_A = true;
            cfg.dir_stagnation = true;
        case 'hybrid_b_dir_small'
            cfg.use_fast_B = true;
            cfg.dir_small_step = true;
            cfg.dir_late = true;
        case 'dir_small_step_late_local_refine'
            cfg.dir_small_step = true;
            cfg.dir_late = true;
            cfg.use_late_local_refine = true;
        case 'dir_small_step_gate_late_local_refine'
            cfg.dir_small_step = true;
            cfg.dir_late = true;
            cfg.use_late_local_refine = true;
            cfg.use_directional_gate = true;
        case 'dir_stag_only'
            cfg.dir_stagnation = true;
            cfg.use_stag_trigger_only = true;
            cfg.tau_dir = max(4, round(0.07 * max_iter));
            cfg.alpha_dir = 0.18;
        case 'dir_stag_bottom_half'
            cfg.dir_stagnation = true;
            cfg.use_stag_trigger_only = true;
            cfg.direction_bottom_half_only = true;
            cfg.use_clipped_direction_step = true;
            cfg.dir_small_step = true;
            cfg.tau_dir = max(5, round(0.08 * max_iter));
            cfg.alpha_dir = 0.15;
        case 'dir_stag_bottom_half_late_refine'
            cfg.dir_stagnation = true;
            cfg.use_stag_trigger_only = true;
            cfg.direction_bottom_half_only = true;
            cfg.use_clipped_direction_step = true;
            cfg.dir_small_step = true;
            cfg.use_late_local_refine = true;
            cfg.local_refine_state_trigger = true;
            cfg.local_refine_use_gap_gate = true;
            cfg.tau_dir = max(5, round(0.08 * max_iter));
            cfg.tau_refine = max(6, round(0.09 * max_iter));
            cfg.alpha_dir = 0.13;
            cfg.local_refine_prob = 0.18;
            cfg.refine_elite_spread_threshold = 0.012;
        case 'dir_clipped_stag_bottom_half_late_refine'
            cfg.dir_stagnation = true;
            cfg.use_stag_trigger_only = true;
            cfg.direction_bottom_half_only = true;
            cfg.use_clipped_direction_step = true;
            cfg.dir_small_step = true;
            cfg.use_late_local_refine = true;
            cfg.local_refine_state_trigger = true;
            cfg.local_refine_use_gap_gate = true;
            cfg.tau_dir = max(6, round(0.10 * max_iter));
            cfg.tau_refine = max(7, round(0.10 * max_iter));
            cfg.alpha_dir = 0.10;
            cfg.dir_cap_std_ratio = 0.08;
            cfg.dir_cap_range_ratio = 0.04;
            cfg.dir_noise_ratio = 0.15;
            cfg.dir_near_best_shrink = 0.45;
            cfg.local_refine_prob = 0.15;
            cfg.refine_elite_spread_threshold = 0.010;
        otherwise
            error('Unsupported v3 ablation mode: %s', mode);
    end
end
