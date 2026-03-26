function resolved = resolve_algorithm_alias(name)
% resolve_algorithm_alias
% Resolve input name (legacy alias/internal id/paper label/entry func)
% to the canonical three-layer naming fields.

    items = algorithm_alias_map();
    key = upper(string(strtrim(name)));

    resolved = struct();
    resolved.requested_name = char(key);
    resolved.paper_name = char(key);
    resolved.internal_id = lower(char(key));
    resolved.entry_name = '';
    resolved.entry_func = '';
    resolved.canonical_token = char(key);
    resolved.is_known = false;

    for i = 1:numel(items)
        aliases = upper(string(items(i).aliases));
        if any(key == aliases)
            resolved.paper_name = char(items(i).paper_name);
            resolved.internal_id = char(items(i).internal_id);
            resolved.entry_name = items(i).entry_func;
            resolved.entry_func = items(i).entry_func;
            resolved.canonical_token = upper(char(items(i).internal_id));
            resolved.is_known = true;
            return;
        end
    end
end
