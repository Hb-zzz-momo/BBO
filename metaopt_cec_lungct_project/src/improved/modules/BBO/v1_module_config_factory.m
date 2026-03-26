function cfg = v1_module_config_factory(mode, max_iter)
% v1_module_config_factory
% Centralized module switches for BBO_IMPROVED_V1 mainline and ablations.

    if nargin < 1 || strlength(string(mode)) == 0
        mode = "v1_full";
    end
    mode = lower(string(mode));

    cfg = struct();

    cfg.enable_selective_elite_learning = true;
    cfg.enable_gated_directional_push = true;
    cfg.enable_anti_stagnation_escape = true;

    cfg.sel_topk_ratio = 0.22;
    cfg.sel_dim_ratio_early = 0.35;
    cfg.sel_dim_ratio_late = 0.18;
    cfg.sel_apply_prob = 0.45;
    cfg.sel_step_ref = 0.55;
    cfg.sel_step_best = 0.25;

    cfg.gdp_trigger_stagnation = max(5, round(0.06 * max_iter));
    cfg.gdp_trigger_diversity = 0.09;
    cfg.gdp_trigger_success = 0.16;
    cfg.gdp_start_progress = 0.25;
    cfg.gdp_active_span = max(2, round(0.02 * max_iter));
    cfg.gdp_target_ratio = 0.20;
    cfg.gdp_step_alpha = 0.14;
    cfg.gdp_noise_ratio = 0.06;
    cfg.gdp_elite_ratio = 0.20;
    cfg.gdp_reference_mode = 'triad';
    cfg.state_driven_enabled = false;
    cfg.state_phase_1 = 0.33;
    cfg.state_phase_2 = 0.67;
    cfg.state_early_step_scale = 0.70;
    cfg.state_mid_step_scale = 1.00;
    cfg.state_late_step_scale = 1.20;
    cfg.state_early_noise_scale = 1.10;
    cfg.state_mid_noise_scale = 1.00;
    cfg.state_late_noise_scale = 0.70;

    cfg.escape_start_progress = 0.45;
    cfg.escape_trigger_stagnation = max(7, round(0.08 * max_iter));
    cfg.escape_target_ratio = 0.16;
    cfg.escape_stagnant_age = max(6, round(0.05 * max_iter));
    cfg.escape_elite_ratio = 0.20;
    cfg.escape_levy_scale = 0.04;
    cfg.escape_rediffuse_ratio = 0.35;
    cfg.escape_conditional_enabled = false;
    cfg.escape_cond_min_hits = 2;
    cfg.escape_use_stagnation_cond = true;
    cfg.escape_use_stage_cond = true;
    cfg.escape_use_diversity_cond = true;
    cfg.escape_use_success_cond = true;
    cfg.escape_stage_progress = 0.65;
    cfg.escape_diversity_threshold = 0.08;
    cfg.escape_success_threshold = 0.10;
    cfg.escape_target_scope = 'both';

    switch char(mode)
        case 'v1_full'
        case 'v1_no_sel'
            cfg.enable_selective_elite_learning = false;
        case 'v1_no_gdp'
            cfg.enable_gated_directional_push = false;
        case 'v1_no_escape'
            cfg.enable_anti_stagnation_escape = false;
        case 'v1_sel_only'
            cfg.enable_gated_directional_push = false;
            cfg.enable_anti_stagnation_escape = false;
        case 'v1_gdp_only'
            cfg.enable_selective_elite_learning = false;
            cfg.enable_anti_stagnation_escape = false;
        case 'v1_escape_only'
            cfg.enable_selective_elite_learning = false;
            cfg.enable_gated_directional_push = false;
        case 'v1_sel_gdp_esc_cond'
            cfg.enable_selective_elite_learning = true;
            cfg.enable_gated_directional_push = true;
            cfg.enable_anti_stagnation_escape = true;
            cfg.escape_conditional_enabled = true;
            cfg.escape_cond_min_hits = 2;
            cfg.escape_trigger_stagnation = max(6, round(0.06 * max_iter));
            cfg.escape_stage_progress = 0.65;
            cfg.escape_diversity_threshold = 0.07;
            cfg.escape_success_threshold = 0.10;
            cfg.escape_target_scope = 'stagnant_elites';
        otherwise
            error('Unsupported V1 module mode: %s', mode);
    end
end
