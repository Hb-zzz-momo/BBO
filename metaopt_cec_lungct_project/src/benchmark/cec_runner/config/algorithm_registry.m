function reg = algorithm_registry(profile)
% algorithm_registry
% Canonical algorithm registry with three-layer naming metadata.

    if nargin < 1 || isempty(profile)
        profile = 'research_core';
    end

    reg = struct();
    reg.profile = profile;
    reg.items = build_registry_items();

    switch lower(profile)
        case 'smoke_minimal'
            allow = {'BBO_BASE', 'BBO_IMPROVED_V3', 'SBO'};
        case 'research_core'
            allow = {'BBO_BASE', 'BBO_IMPROVED_V1', 'BBO_IMPROVED_V3', 'BBO_IMPROVED_V4', 'SBO', 'MGO', 'PLO'};
        case 'ablation_v3'
            allow = {'V3_BASE', 'V3_DIR_STAG_ONLY', 'V3_DIR_STAG_BOTTOM_HALF', ...
                'V3_DIR_STAG_BOTTOM_HALF_LATE_REFINE', 'V3_HYBRID_B'};
        case 'prototype_routes_smoke'
            allow = {'ROUTE_A', 'ROUTE_B', 'ROUTE_C', 'ROUTE_D'};
        otherwise
            error('Unsupported algorithm registry profile: %s', profile);
    end

    names = {reg.items.name};
    reg.selected = allow;
    reg.missing = setdiff(allow, names, 'stable');

    if ~isempty(reg.missing)
        error('Registry profile %s references unknown algorithms: %s', profile, strjoin(reg.missing, ', '));
    end
end

function items = build_registry_items()
    alias_items = algorithm_alias_map();
    items = repmat(struct( ...
        'name', '', ...
        'paper_name', '', ...
        'internal_id', '', ...
        'entry_func', '', ...
        'variant_type', '', ...
        'track', '', ...
        'note', ''), 1, numel(alias_items));

    for i = 1:numel(alias_items)
        item = struct();
        item.name = upper(alias_items(i).internal_id);
        item.paper_name = alias_items(i).paper_name;
        item.internal_id = alias_items(i).internal_id;
        item.entry_func = alias_items(i).entry_func;
        item.variant_type = map_variant_type(alias_items(i).tier, item.name);
        item.track = map_track(alias_items(i).tier);
        item.note = sprintf('%s -> %s -> %s', item.paper_name, item.internal_id, item.entry_func);
        items(i) = item;
    end
end

function variant_type = map_variant_type(tier, name)
    switch lower(tier)
        case 'baseline'
            variant_type = 'baseline';
        case 'improved'
            variant_type = 'improved';
        case {'ablation', 'ablation_failed_but_informative'}
            variant_type = 'ablation';
        case 'comparison'
            variant_type = 'control';
        otherwise
            if any(strcmpi(name, {'SBO', 'HHO', 'PSO', 'DE', 'GWO', 'WOA', 'RIME', 'SHADE', 'MGO', 'PLO'}))
                variant_type = 'control';
            else
                variant_type = 'other';
            end
    end
end

function track = map_track(tier)
    switch lower(tier)
        case {'baseline', 'improved', 'ablation', 'ablation_failed_but_informative'}
            track = 'beaver_research';
        otherwise
            track = 'comparison';
    end
end
