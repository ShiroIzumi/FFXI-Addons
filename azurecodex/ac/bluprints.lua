--[[
    Azure Codex - ac/bluprints.lua

    BLUPrints: build caps, equipping a set, the equipped set, saved builds,
    the trait list / calculator / planner, and the BLUPrints page + companion.
]]

function get_build_points_used()
    local total = 0;
    local count = 0;
    for _, spell in ipairs(spells) do
        if state.build_selected[normalize_name(spell.name)] == true then
            total = total + (tonumber(spell.points) or 0);
            count = count + 1;
        end
    end
    return total, count;
end

function enforce_build_cap(point_cap, slot_cap)
    point_cap = tonumber(point_cap) or 45;
    if point_cap < 0 then point_cap = 0; end
    slot_cap = tonumber(slot_cap) or 20;

    local total = 0;
    local slots = 0;

    -- Totals only. Selections are never removed here (1.12.0): new picks are
    -- blocked at the checkbox when they would go over, and Equip refuses a
    -- build that is over your limits, so a plan made for a higher level
    -- (or imported from BLUPrint-View) is kept intact.
    for _, spell in ipairs(spells) do
        local key = spell._key;
        if state.build_selected[key] == true then
            total = total + (tonumber(spell.points) or 0);
            slots = slots + 1;
        end
    end

    return total, slots;
end

-- Equipped-set cache (see get_current_equipped_spell_names); declared here so
-- the equip task can clear it when it finishes.
equipped_cache = { names = {}, at = -1 };

function equip_spell_list(selected, used, selected_count, source_label)
    if blu == nil or blu.reset_all_spells == nil or blu.set_spell_by_name == nil then
        log_message('BLU equip functions could not be initialized on this Ashita client.');
        return false;
    end

    selected = selected or {};
    selected_count = tonumber(selected_count) or #selected;
    used = tonumber(used) or 0;

    local point_cap, slot_cap = get_build_caps();

    if selected_count == 0 then
        log_message('No spells selected for the build.');
        return false;
    end

    if selected_count > slot_cap then
        log_message(('Cannot equip %d spells. Your BLU level allows %d set slots.'):fmt(selected_count, slot_cap));
        return false;
    end

    if used > point_cap then
        log_message(('Build exceeds your current BLU point cap by %d points.'):fmt(used - point_cap));
        return false;
    end

    -- Resolve the final spell ids before the equip task starts so the task
    -- only has to send the exact numeric ids used by Ashita's BLU packet.
    local rm = AshitaCore:GetResourceManager();
    local equip_list = {};
    if rm == nil then
        log_message('Unable to access Ashita spell resources.');
        return false;
    end

    for _, spell in ipairs(selected) do
        local resource = rm:GetSpellByName(tostring(spell.name), 0);
        if resource == nil or resource.Index < 512 or resource.Index > 1024 then
            log_message('Unable to resolve BLU spell for equip: ' .. tostring(spell.name));
            return false;
        end
        equip_list[#equip_list + 1] = { name = spell.name, id = resource.Index - 512 };
    end

    local delay = tonumber(blu.delay) or 1.0;
    if delay <= 0 then delay = 1.0; end
    if blu.mode == 'safe' and delay < 1.0 then delay = 1.0; end

    state.build_equipping[1] = true;
    log_message(('Equipping BLU build%s: %d spells, %d points. Please wait..'):fmt(
        source_label and (' from ' .. tostring(source_label)) or '', selected_count, used));

    ashita.tasks.once(1, (function(d, build)
        local ok, err = pcall(function()
            blu.reset_all_spells();
            coroutine.sleep(d);

            for index, spell in ipairs(build) do
                local result = blu.set_spell(index, spell.id);
                if result == false then
                    error(('Failed to queue BLU spell: %s'):format(tostring(spell.name)));
                end
                coroutine.sleep(d);
            end
        end);

        state.build_equipping[1] = false;
        equipped_cache.at = -1;

        if ok then
            log_message('Finished equipping BLU spell build.');
        else
            log_message('BLU equip failed: ' .. tostring(err));
        end
    end):bindn(delay, equip_list));

    return true;
end

function equip_selected_build()
    local used, selected_count = get_build_points_used();
    local selected = {};

    for _, spell in ipairs(spells) do
        if state.build_selected[normalize_name(spell.name)] == true then
            selected[#selected + 1] = spell;
        end
    end

    return equip_spell_list(selected, used, selected_count, nil);
end


-- The spell-set offset pattern is scanned once (scanning on every click
-- caused a hitch); the equipped list itself is cached for one second.
equipped_offset_ptr = nil;

function get_current_equipped_spell_names()
    local now = os.clock();
    if equipped_cache.at >= 0 and (now - equipped_cache.at) < 1.0 then
        return equipped_cache.names;
    end
    equipped_cache.at = now;

    local ok, result = pcall(function()
        -- Read the same BLU spell-set memory used by Ashita's official blu helper.
        if equipped_offset_ptr == nil then
            local found = ashita.memory.find(0, 0, 'C1E1032BC8B0018D????????????B9????????F3A55F5E5B', 10, 0);
            if found == nil or found == 0 then
                return {};
            end
            equipped_offset_ptr = found;
        end

        local offset = ffi.cast('uint32_t*', equipped_offset_ptr);
        local blu_buffer = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('inventory'));
        if blu_buffer == 0 then return {}; end
        blu_buffer = ashita.memory.read_uint32(blu_buffer);
        if blu_buffer == 0 then return {}; end

        local is_blu_main = safe_blu_level() ~= nil;
        local base = blu_buffer + offset[0] + (is_blu_main and 0x04 or 0xA0);
        local ids = ashita.memory.read_array(base, 0x14);
        local names = {};
        local rm = AshitaCore:GetResourceManager();
        if rm == nil then return names; end

        for _, value in ipairs(ids) do
            value = tonumber(value) or 0;
            if value ~= 0 then
                local spell = rm:GetSpellById(value + 512);
                if spell ~= nil and spell.Name ~= nil and spell.Name[1] ~= nil then
                    names[#names + 1] = spell.Name[1];
                end
            end
        end
        return names;
    end);

    if not ok or result == nil then
        result = {};
    end
    equipped_cache.names = result;
    return result;
end

-- Spells currently set in game, as spell rows, plus their point total.
function get_equipped_spells()
    local lookup = {};
    for _, name in ipairs(get_current_equipped_spell_names()) do
        lookup[normalize_name(name)] = true;
    end
    local list = {};
    local points = 0;
    for _, spell in ipairs(spells) do
        local alias = resource_aliases[spell._key];
        if lookup[spell._key] or (alias ~= nil and lookup[alias]) then
            list[#list + 1] = spell;
            points = points + (tonumber(spell.points) or 0);
        end
    end
    return list, points;
end

-- What equipping `target` would change: spells added, removed, unchanged.
function equipped_diff(target)
    local equipped = get_equipped_spells();
    local in_target = {};
    for _, spell in ipairs(target or {}) do in_target[spell._key] = true; end
    local in_equipped = {};
    for _, spell in ipairs(equipped) do in_equipped[spell._key] = true; end

    local adds, removes, same = {}, {}, 0;
    for _, spell in ipairs(target or {}) do
        if in_equipped[spell._key] then same = same + 1; else adds[#adds + 1] = spell; end
    end
    for _, spell in ipairs(equipped) do
        if not in_target[spell._key] then removes[#removes + 1] = spell; end
    end
    return adds, removes, same, #equipped;
end

function ensure_build_folder()
    local folder = ('%s\\addons\\%s\\BLUPrints\\'):fmt(AshitaCore:GetInstallPath(), addon.name);
    if ashita.fs ~= nil and ashita.fs.exists ~= nil and not ashita.fs.exists(folder) then
        if ashita.fs.create_dir ~= nil then
            ashita.fs.create_dir(folder);
        end
    end
    return folder;
end

function save_build_to_file()
    local used, selected_count = get_build_points_used()
    local point_cap, slot_cap = get_build_caps()

    if selected_count == 0 then
        log_message('No spells selected. Nothing to save.')
        return
    end

    local folder = ensure_build_folder()
    local build_name = tostring(state.build_name[1] or '')
    build_name = build_name:gsub('^%s+', ''):gsub('%s+$', '')
    build_name = build_name:gsub('[<>:\"/\\|%?%*]', '_')
    build_name = build_name:gsub('[%. ]+$', '')

    if build_name == '' then
        build_name = 'AzureCodex_Set_' .. os.date('%Y%m%d_%H%M%S')
    end

    if not build_name:lower():match('%.txt$') then
        build_name = build_name .. '.txt'
    end

    local path = folder .. '\\' .. build_name
    local file = io.open(path, 'w')
    if file == nil then
        log_message('Unable to save build file: ' .. path)
        return
    end

    file:write('BLU Spell Build\n')
    file:write('==============================\n')
    file:write('Generated: ' .. os.date('%Y-%m-%d %H:%M:%S') .. '\n')
    file:write('Point Total: ' .. tostring(used) .. '/' .. tostring(point_cap) .. '\n')
    file:write('Spells: ' .. tostring(selected_count) .. '/' .. tostring(slot_cap) .. '\n')
    file:write('\nSelected Spells\n')
    file:write('------------------------------\n')

    local index = 0
    for _, spell in ipairs(spells) do
        if state.build_selected[normalize_name(spell.name)] == true then
            index = index + 1
            file:write(string.format('%d. %s - Lv %s - %s pt\n',
                index, tostring(spell.name), tostring(spell.level), tostring(spell.points)))
        end
    end

    file:close()
    state.build_files_at = -1
    state.view_cache = nil
    log_message('Saved BLU spell build to ' .. path)
end

get_saved_build_files_uncached = nil;

-- The folder listing is cached for 3 seconds (it was read from disk every
-- frame on the BLUPrints / BLUPrint-View pages). Save / delete / Refresh
-- clear it immediately.
function get_saved_build_files()
    local now = os.clock();
    if state.build_files ~= nil and (state.build_files_at or -1) >= 0 and (now - state.build_files_at) < 3.0 then
        return state.build_files;
    end
    state.build_files = get_saved_build_files_uncached();
    state.build_files_at = now;
    return state.build_files;
end

get_saved_build_files_uncached = function()
    local files = {};
    local folder = ensure_build_folder();

    if ashita.fs ~= nil and ashita.fs.get_dir ~= nil then
        local ok, result = pcall(function()
            return ashita.fs.get_dir(folder, '.*.txt', true);
        end);
        if ok and result ~= nil then
            for _, value in ipairs(result) do
                if value ~= nil and tostring(value) ~= '' then
                    local fullpath = tostring(value);
                    local filename = fullpath:match('([^\\/]+)$') or fullpath;
                    if filename:lower():sub(-4) == '.txt' then
                        files[#files + 1] = filename;
                    end
                end
            end
        end
    end

    table.sort(files, function(a, b) return a:lower() > b:lower() end);
    return files;
end

function load_saved_build_file(filename, equip_in_game)
    local folder = ensure_build_folder()
    local path = folder .. '\\' .. tostring(filename or '')
    local file = io.open(path, 'r')
    if file == nil then
        log_message('Unable to open saved build: ' .. path)
        return false
    end

    local loaded = {}
    for line in file:lines() do
        local name = line:match('^%s*%d+%.%s*(.-)%s+%- %s*Lv%s+%d+%s+%-%s+%d+%s+pt%s*$')
        if name ~= nil then
            loaded[normalize_name(name)] = true
        end
    end
    file:close()

    local point_cap, slot_cap = get_build_caps()
    local selected = {}
    local used = 0
    local count = 0

    for _, spell in ipairs(spells) do
        local key = normalize_name(spell.name)
        local cost = tonumber(spell.points) or 0
        if loaded[key] and count < slot_cap and (used + cost) <= point_cap then
            selected[#selected + 1] = spell
            used = used + cost
            count = count + 1
        end
    end

    if count == 0 then
        log_message('No valid spells were found in saved build: ' .. tostring(filename));
        return false
    end

    if equip_in_game then
        state.build_load_open[1] = false
        return equip_spell_list(selected, used, count, filename);
    end

    -- Calculator loading mode remains available for the loader window.
    state.build_selected = {}
    for _, spell in ipairs(selected) do
        state.build_selected[normalize_name(spell.name)] = true
    end

    state.build_load_open[1] = false
    log_message(('Loaded BLU spell build: %d spells, %d points.'):fmt(count, used))
    return true
end

function draw_saved_build_loader()
    if not state.build_load_open[1] then
        return
    end

    state.build_load_files = get_saved_build_files()
    push_theme()
    if imgui.Begin('Load BLU Spell Build##bluspells_load_build', state.build_load_open, ImGuiWindowFlags_NoNav) then
        imgui.TextColored(state.header_color, 'Saved Builds')
        imgui.Separator()

        if #state.build_load_files == 0 then
            imgui.TextColored(MUTED, 'No saved builds found in BLUPrints.')
        else
            for _, filename in ipairs(state.build_load_files) do
                if imgui.Button(filename .. '##saved_build_' .. normalize_name(filename)) then
                    load_saved_build_file(filename)
                    break
                end
            end
        end
    end

    imgui.End()
    pop_theme()
end

-- Trait list with tier, points toward the next tier and a progress bar.
function draw_trait_list(traits, id_prefix, bar_width)
    if #traits == 0 then
        imgui.TextColored(MUTED, 'No traits selected.');
        return;
    end

    for index, entry in ipairs(traits) do
        local color = entry.tier > 0 and state.known_color or partial_color();
        imgui.TextColored(color, trait_label(entry));
        imgui.SameLine();
        if entry.maxed then
            imgui.TextColored(MUTED, ('%d pts  MAX'):fmt(entry.points));
        else
            imgui.TextColored(MUTED, ('%d / %d pts'):fmt(entry.points, entry.next_points or 0));
            if entry.tier > 0 then
                imgui.SameLine();
                imgui.TextColored(MUTED, ('(next: %s)'):fmt(ROMAN[entry.tier + 1] or tostring(entry.tier + 1)));
            end
        end
        if imgui.ProgressBar ~= nil then
            local ratio = 1.0;
            if not entry.maxed and entry.next_points ~= nil then
                local span = math.max(1, entry.next_points - entry.prev_points);
                ratio = math.max(0, math.min(1.0, (entry.points - entry.prev_points) / span));
            end
            imgui.ProgressBar(ratio, { bar_width or 0, 6 }, '');
        end
    end
end

-- "vs Equipped" summary for a planned / saved build.
function draw_equipped_diff(target)
    local adds, removes, same, equipped_count = equipped_diff(target);
    imgui.TextColored(state.header_color, 'VS EQUIPPED');
    imgui.SameLine();
    if equipped_count == 0 then
        imgui.TextColored(MUTED, '(equipped set not readable - BLU main only)');
        return;
    end
    if #adds == 0 and #removes == 0 then
        imgui.TextColored(state.known_color, 'Same as your equipped set.');
        return;
    end
    imgui.TextColored(MUTED, ('%d unchanged'):fmt(same));

    local function names(list)
        local parts = {};
        for _, spell in ipairs(list) do parts[#parts + 1] = tostring(spell.name); end
        return table.concat(parts, ', ');
    end
    if #adds > 0 then
        imgui.TextColored(state.known_color, '+ ');
        imgui.SameLine(0, 0);
        imgui.TextWrapped(names(adds));
    end
    if #removes > 0 then
        imgui.TextColored(state.unknown_color, '- ');
        imgui.SameLine(0, 0);
        imgui.TextWrapped(names(removes));
    end
end

-- Cheapest known, unselected spells that reach the trait's next tier.
function plan_next_tier(trait_key, current_weight, next_need)
    local candidates = {};
    for _, spell in ipairs(spells) do
        if state.build_selected[spell._key] ~= true and is_known(spell.name) then
            local trait_name = get_spell_trait_name(spell);
            if trait_name ~= nil and normalize_name(trait_name) == trait_key then
                candidates[#candidates + 1] = spell;
            end
        end
    end
    table.sort(candidates, function(a, b)
        local ar = (tonumber(a.points) or 0) / get_trait_weight(a);
        local br = (tonumber(b.points) or 0) / get_trait_weight(b);
        if ar ~= br then return ar < br; end
        return (tonumber(a.points) or 0) < (tonumber(b.points) or 0);
    end);

    local needed = (tonumber(next_need) or 0) - (tonumber(current_weight) or 0);
    local picks, cost, got = {}, 0, 0;
    for _, spell in ipairs(candidates) do
        if got >= needed then break; end
        picks[#picks + 1] = spell;
        cost = cost + (tonumber(spell.points) or 0);
        got = got + get_trait_weight(spell);
    end
    return picks, cost, got >= needed;
end

planner_cache = { key = nil, rows = {} };

function draw_trait_planner(traits, used, selected_count, point_cap, slot_cap)
    imgui.TextColored(state.header_color, 'TRAIT PLANNER');
    imgui.SameLine();
    imgui.Checkbox('All traits##azure_planner_all', state.planner_all);
    imgui.Separator();
    imgui.TextColored(MUTED, 'Cheapest known spells to reach each next tier.');

    -- The plan only changes with the selection, known spells or options.
    local selected_keys = {};
    for _, spell in ipairs(spells) do
        if state.build_selected[spell._key] == true then selected_keys[#selected_keys + 1] = spell._key; end
    end
    local cache_key = table.concat({
        table.concat(selected_keys, ','), tostring(known_cache.version), tostring(state.planner_all[1]),
    }, '|');
    if planner_cache.key ~= cache_key then
        planner_cache.key = cache_key;
        planner_cache.rows = nil;
    end

    -- Traits in the build, or every trait any known spell can give.
    local list = {};
    local seen = {};
    for _, entry in ipairs(traits) do
        list[#list + 1] = entry;
        seen[entry.key] = true;
    end
    if state.planner_all[1] then
        local extra = {};
        for _, spell in ipairs(spells) do
            local trait_name = get_spell_trait_name(spell);
            if trait_name ~= nil then
                local key = normalize_name(trait_name);
                if not seen[key] and is_known(spell.name) then
                    seen[key] = true;
                    local tiers = trait_tiers_for(trait_name);
                    extra[#extra + 1] = {
                        name = trait_name, key = key, weight = 0, tier = 0,
                        max_tier = #tiers, maxed = false, points = 0,
                        next_need = tiers[1], next_points = tiers[1] * TRAIT_POINT_SCALE, prev_points = 0,
                    };
                end
            end
        end
        table.sort(extra, function(a, b) return a.name:lower() < b.name:lower(); end);
        for _, entry in ipairs(extra) do list[#list + 1] = entry; end
    end

    if planner_cache.rows == nil then
        planner_cache.rows = {};
        for _, entry in ipairs(list) do
            if not entry.maxed and entry.next_need ~= nil then
                local picks, cost, complete = plan_next_tier(entry.key, entry.weight, entry.next_need);
                planner_cache.rows[#planner_cache.rows + 1] = {
                    entry = entry, picks = picks, cost = cost, complete = complete,
                };
            end
        end
    end

    local shown = 0;
    for _, plan in ipairs(planner_cache.rows) do
        local entry = plan.entry;
        do
            shown = shown + 1;
            local picks, cost, complete = plan.picks, plan.cost, plan.complete;
            local target_label = ('%s %s'):fmt(entry.name, ROMAN[entry.tier + 1] or tostring(entry.tier + 1));
            imgui.TextColored(info_color(), target_label);
            imgui.SameLine();
            if #picks == 0 then
                imgui.TextColored(MUTED, 'no known spells left');
            elseif not complete then
                local parts = {};
                for _, spell in ipairs(picks) do parts[#parts + 1] = tostring(spell.name); end
                imgui.TextColored(MUTED, ('not reachable yet (%s)'):fmt(table.concat(parts, ', ')));
            else
                local fits = (used + cost) <= point_cap and (selected_count + #picks) <= slot_cap;
                local parts = {};
                for _, spell in ipairs(picks) do parts[#parts + 1] = tostring(spell.name); end
                imgui.TextColored(fits and TEXT or partial_color(),
                    ('+%s  (%d pt, %d slot%s)'):fmt(table.concat(parts, ', '), cost, #picks, #picks == 1 and '' or 's'));
                if fits then
                    imgui.SameLine();
                    if imgui.SmallButton('Add##azure_plan_' .. entry.key) then
                        for _, spell in ipairs(picks) do
                            state.build_selected[spell._key] = true;
                        end
                    end
                else
                    imgui.SameLine();
                    imgui.TextColored(MUTED, '[over cap]');
                end
            end
        end
    end
    if shown == 0 then
        imgui.TextColored(MUTED, #list == 0 and 'Select spells (or tick All traits) to plan.' or 'Every listed trait is maxed.');
    end
end

-- ----------------------------------------------------------------------------
-- BLUPrints page (1.14.0): toolbar, budget bars, then two columns:
-- Known spells (trait chips + search, click to add) | Your build (slots,
-- click to remove) with Equip / Load equipped / Clear underneath.
-- ----------------------------------------------------------------------------
function bp_text_w(value)
    return tonumber((imgui.CalcTextSize(tostring(value)))) or 0;
end

-- Label / value / thin bar block (fixed width).
function bp_budget(label, value, frac, width)
    local x0 = imgui.GetCursorPosX();
    local y0 = imgui.GetCursorPosY();
    imgui.TextColored(MUTED, label);
    imgui.SameLine();
    imgui.SetCursorPosX(x0 + width - bp_text_w(value));
    imgui.Text(value);
    local sx, sy = imgui.GetCursorScreenPos();
    sx = sx + (x0 - imgui.GetCursorPosX());
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ sx, sy + 1 }, { sx + width, sy + 5 }, imgui.GetColorU32({ 1.0, 1.0, 1.0, 0.08 }), 2.0);
    frac = math.max(0, math.min(1, tonumber(frac) or 0));
    if frac > 0 then
        dl:AddRectFilled({ sx, sy + 1 }, { sx + math.max(3, width * frac), sy + 5 }, imgui.GetColorU32(accent()), 2.0);
    end
    imgui.SetCursorPosY(y0);
end

-- Rounded filter chip; returns true when clicked.
function bp_chip(label, id, selected)
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 10.0);
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 9, 2 });
    imgui.PushStyleColor(ImGuiCol_Button, selected and accent(0.28) or CONTROL);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, selected and accent(0.36) or CONTROL_HOVER);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, accent(0.44));
    imgui.PushStyleColor(ImGuiCol_Text, selected and accent() or MUTED);
    local clicked = imgui.Button(label .. '##' .. id);
    imgui.PopStyleColor(4);
    imgui.PopStyleVar(2);
    return clicked;
end

-- Primary (accent-filled) button.
function bp_primary_button(label, id, enabled)
    imgui.PushStyleColor(ImGuiCol_Button, enabled and accent(0.85) or CONTROL);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, accent(1.0));
    imgui.PushStyleColor(ImGuiCol_ButtonActive, accent(0.70));
    imgui.PushStyleColor(ImGuiCol_Text, enabled and { 0.02, 0.02, 0.06, 1.0 } or MUTED);
    local clicked = imgui.Button(label .. '##' .. id) and enabled;
    imgui.PopStyleColor(4);
    return clicked;
end

function draw_spell_build_tab()
    local point_cap, slot_cap = get_build_caps();
    local used, selected_count = enforce_build_cap(point_cap, slot_cap);

    -- ===== Toolbar: loadout + save =====
    state.spellsets_files = get_saved_build_files();
    align_label();
    imgui.TextColored(MUTED, 'Loadout');
    imgui.SameLine();
    if #state.spellsets_files == 0 then
        align_label();
        imgui.TextColored(MUTED, '(no saved sets)');
    else
        local selected_name = tostring(state.spellset_selected[1] or '');
        local current_index = 0;
        local combo_items = { 'Select a BLUPrint...' };
        for index, filename in ipairs(state.spellsets_files) do
            combo_items[#combo_items + 1] = filename;
            if filename == selected_name then current_index = index; end
        end
        local combo_value = { current_index };
        imgui.PushItemWidth(math.max(180, bp_text_w('Select a BLUPrint...') + 40));
        if imgui.Combo('##azure_bluprints_loadout_combo', combo_value, table.concat(combo_items, '\0') .. '\0\0', math.min(12, #combo_items)) then
            local chosen_index = tonumber(combo_value[1]) or 0;
            local filename = chosen_index > 0 and state.spellsets_files[chosen_index] or nil;
            if filename ~= nil then
                state.spellset_selected[1] = filename;
                -- Ask first; equipping replaces your whole set.
                state.loadout_pending = filename;
            end
        end
        imgui.PopItemWidth();
    end
    imgui.SameLine();
    if imgui.Button('Refresh##azure_bluprints_refresh') then
        state.build_files_at = -1;
        state.spellsets_files = get_saved_build_files();
        local current = tostring(state.spellset_selected[1] or '');
        local found = false;
        for _, filename in ipairs(state.spellsets_files) do
            if filename == current then found = true; break; end
        end
        if not found then state.spellset_selected[1] = ''; end
        state.view_cache = nil;
    end

    -- Name + Save on the right.
    imgui.SameLine();
    local save_w = bp_text_w('Save') + 20;
    local name_w = 190;
    local row_w = tonumber((imgui.GetContentRegionAvail())) or 400;
    if row_w > name_w + save_w + 12 then
        imgui.SetCursorPosX(imgui.GetCursorPosX() + row_w - name_w - save_w - 8);
    end
    imgui.PushItemWidth(name_w);
    input_text_no_tab('##blu_build_name', state.build_name, 128);
    imgui.PopItemWidth();
    if imgui.IsItemHovered() and not imgui.IsItemActive() then
        imgui.SetTooltip('Name for this build (saved to the BLUPrints folder)');
    end
    imgui.SameLine();
    if imgui.Button('Save##blu_build_save') then
        save_build_to_file();
    end

    if state.loadout_pending ~= nil then
        imgui.TextColored(state.learnable_color, ('Equip %s?'):fmt(tostring(state.loadout_pending)));
        imgui.SameLine();
        if bp_primary_button('Equip', 'azure_loadout_confirm', true) then
            load_saved_build_file(state.loadout_pending, true);
            state.loadout_pending = nil;
        end
        imgui.SameLine();
        if imgui.Button('Cancel##azure_loadout_cancel') then
            state.loadout_pending = nil;
        end
    end

    -- ===== Budget bars =====
    imgui.Spacing();
    local bud_w = math.max(150, bp_text_w('Points  00 / 00') + 20);
    local bx = imgui.GetCursorPosX();
    bp_budget('Spells', ('%d / %d'):fmt(selected_count, slot_cap), slot_cap > 0 and selected_count / slot_cap or 0, bud_w);
    imgui.SameLine();
    imgui.SetCursorPosX(bx + bud_w + 24);
    bp_budget('Points', ('%d / %d'):fmt(used, point_cap), point_cap > 0 and used / point_cap or 0, bud_w);
    imgui.SameLine();
    imgui.SetCursorPosX(bx + (bud_w + 24) * 2);
    local trait_totals, selected_spells = get_trait_totals();
    if #selected_spells > 0 then
        local adds, removes = equipped_diff(selected_spells);
        if #adds == 0 and #removes == 0 then
            imgui.TextColored(state.known_color, 'Same as equipped');
        else
            imgui.TextColored(state.learnable_color, ('+%d / -%d vs equipped'):fmt(#adds, #removes));
        end
    else
        imgui.TextColored(MUTED, 'Empty build');
    end
    imgui.NewLine();
    imgui.Spacing();

    -- ===== Two columns =====
    local avail_w, avail_h = imgui.GetContentRegionAvail();
    avail_w = tonumber(avail_w) or 700;
    avail_h = math.max(160, tonumber(avail_h) or 300);
    local left_w = math.floor(avail_w * 0.56);

    -- Trait chips (traits of your known spells), drawn under Your Build.
    -- Click one to filter Known Spells to that trait.
    local trait_set, trait_list = {}, {};
    for _, spell in ipairs(spells) do
        if is_known(spell.name) then
            local t = get_spell_trait_name(spell);
            if t ~= nil and not trait_set[t] then
                trait_set[t] = true;
                trait_list[#trait_list + 1] = t;
            end
        end
    end
    table.sort(trait_list);
    local chips = { { label = 'All', value = nil } };
    for _, t in ipairs(trait_list) do chips[#chips + 1] = { label = t, value = t }; end
    chips[#chips + 1] = { label = 'No trait', value = '__none' };
    if state.build_trait_filter ~= nil and state.build_trait_filter ~= '__none' and not trait_set[state.build_trait_filter] then
        state.build_trait_filter = nil;
    end


    imgui.PushStyleColor(ImGuiCol_ChildBg, { 0, 0, 0, 0 });

    -- ---- Left: known spells ----
    imgui.BeginChild('##azure_bp_left', { left_w, avail_h });
    section_title('KNOWN SPELLS');

    local col_w = tonumber((imgui.GetContentRegionAvail())) or left_w;
    imgui.Spacing();
    imgui.PushItemWidth(math.max(120, col_w - bp_text_w('Show unlearned') - 40));
    input_text_no_tab('##blu_build_search', state.build_search, 128);
    imgui.PopItemWidth();
    if imgui.IsItemHovered() and not imgui.IsItemActive() then
        imgui.SetTooltip('Search spells, traits or mob families');
    end
    imgui.SameLine();
    if state.build_show_unlearned == nil then state.build_show_unlearned = { false }; end
    imgui.Checkbox('Show unlearned##bp_unlearned', state.build_show_unlearned);

    -- Column header + list.
    local name_x = 22;
    local pts_w = bp_text_w('Pts') + 10;
    local lv_w = bp_text_w('Lv 75') + 8;
    local list_w = tonumber((imgui.GetContentRegionAvail())) or col_w;
    local pts_x = math.floor(list_w * 0.46);
    local lv_x = pts_x + pts_w + 6;
    local trait_x = lv_x + lv_w + 6;

    imgui.TextColored(MUTED, 'Spell');
    imgui.SameLine(); imgui.SetCursorPosX(pts_x); imgui.TextColored(MUTED, 'Pts');
    imgui.SameLine(); imgui.SetCursorPosX(lv_x); imgui.TextColored(MUTED, 'Lv');
    imgui.SameLine(); imgui.SetCursorPosX(trait_x); imgui.TextColored(MUTED, 'Trait');

    imgui.BeginChild('##azure_codex_bluprints_spell_list', { 0, 0 });
    local query = tostring(state.build_search[1] or ''):lower();
    local filter = state.build_trait_filter;
    local shown = 0;
    for _, spell in ipairs(spells) do
        local known = is_known(spell.name);
        local trait_name = get_spell_trait_name(spell);
        local trait_ok = filter == nil
            or (filter == '__none' and trait_name == nil)
            or (trait_name ~= nil and trait_name == filter);
        if (known or state.build_show_unlearned[1]) and trait_ok
            and (query == '' or spell_haystack(spell):find(query, 1, true) ~= nil) then
            shown = shown + 1;
            local key = normalize_name(spell.name);
            local checked = state.build_selected[key] == true;
            local cost = tonumber(spell.points) or 0;
            local blocked = (not checked) and (((used + cost) > point_cap) or (selected_count >= slot_cap));
            local _, spell_color = get_spell_display_state(spell);

            local row_x = imgui.GetCursorPosX();
            imgui.PushStyleColor(ImGuiCol_Header, accent(0.16));
            imgui.PushStyleColor(ImGuiCol_HeaderHovered, accent(0.22));
            imgui.PushStyleColor(ImGuiCol_HeaderActive, accent(0.30));
            imgui.PushStyleColor(ImGuiCol_Text, (blocked or not known) and MUTED or spell_color);
            local label = (checked and '+ ' or '  ') .. tostring(spell.name);
            if imgui.Selectable(label .. '##bp_add_' .. key, checked, 0, { list_w - 4, 0 }) then
                if checked then
                    state.build_selected[key] = false;
                    used, selected_count = get_build_points_used();
                elseif known and not blocked then
                    state.build_selected[key] = true;
                    used = used + cost;
                    selected_count = selected_count + 1;
                end
            end
            imgui.PopStyleColor(4);
            if imgui.IsItemHovered() then
                if not known then
                    imgui.SetTooltip('Not learned yet');
                elseif blocked then
                    imgui.SetTooltip('Over your limits (points or spell slots)');
                end
            end

            imgui.SameLine(); imgui.SetCursorPosX(row_x + pts_x + pts_w - bp_text_w(cost) - 6);
            imgui.TextColored(blocked and MUTED or state.header_color, tostring(cost));
            imgui.SameLine(); imgui.SetCursorPosX(row_x + lv_x);
            imgui.TextColored(MUTED, tostring(spell.level or '--'));
            imgui.SameLine(); imgui.SetCursorPosX(row_x + trait_x);
            local badge = get_spell_trait_badge(spell);
            if badge == nil or tostring(badge):lower() == 'none' then
                imgui.TextColored(MUTED, '--');
            else
                imgui.TextColored(blocked and MUTED or TEXT, tostring(badge));
            end
        end
    end
    if shown == 0 then
        imgui.TextColored(MUTED, 'No spells match.');
    end
    imgui.EndChild();
    imgui.EndChild();

    imgui.SameLine(0, 14);

    -- ---- Right: your build ----
    imgui.BeginChild('##azure_bp_right', { 0, avail_h });
    section_title('YOUR BUILD');
    imgui.TextColored(MUTED, 'Click a spell to remove it.');
    imgui.Spacing();

    local slot_list_w = tonumber((imgui.GetContentRegionAvail())) or 260;
    local num_w = bp_text_w('00') + 8;
    local spt_w = bp_text_w('0') + 10;
    for slot = 1, slot_cap do
        local spell = selected_spells[slot];
        local row_x = imgui.GetCursorPosX();
        imgui.TextColored(spell and state.header_color or BORDER, ('%02d'):fmt(slot));
        imgui.SameLine();
        imgui.SetCursorPosX(row_x + num_w);
        if spell ~= nil then
            local key = normalize_name(spell.name);
            imgui.PushStyleColor(ImGuiCol_Header, accent(0.16));
            imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 0.55, 0.15, 0.15, 0.55 });
            imgui.PushStyleColor(ImGuiCol_HeaderActive, { 0.65, 0.18, 0.18, 0.70 });
            if imgui.Selectable(tostring(spell.name) .. '##bp_slot_' .. key, false, 0, { math.max(60, slot_list_w - num_w - 4), 0 }) then
                state.build_selected[key] = false;
                used, selected_count = get_build_points_used();
            end
            imgui.PopStyleColor(3);
            local name_end = row_x + num_w + bp_text_w(spell.name) + 12;
            local pts_xr = row_x + math.floor(slot_list_w * 0.55);
            imgui.SameLine();
            imgui.SetCursorPosX(math.max(name_end, pts_xr));
            imgui.TextColored(state.header_color, tostring(tonumber(spell.points) or 0));
            local badge = get_spell_trait_badge(spell);
            if badge ~= nil and tostring(badge):lower() ~= 'none' then
                imgui.SameLine();
                imgui.SetCursorPosX(math.max(name_end, pts_xr) + spt_w + 6);
                imgui.TextColored(info_color(), tostring(badge));
            end
        else
            imgui.TextColored(BORDER, 'empty');
        end
    end

    imgui.Spacing();
    imgui.Spacing();
    local equip_label = state.build_equipping[1] and 'Equipping...' or 'Equip build';
    local equip_available = selected_count > 0 and not state.build_equipping[1];
    if bp_primary_button(equip_label, 'blu_build_equip', equip_available) then
        equip_selected_build();
    end
    imgui.SameLine();
    if imgui.Button('Load equipped##blu_build_equipped') then
        state.build_selected = {};
        used, selected_count = 0, 0;
        local equipped = get_current_equipped_spell_names();
        local equipped_lookup = {};
        for _, name in ipairs(equipped) do
            equipped_lookup[normalize_name(name)] = true;
        end
        for _, spell in ipairs(spells) do
            local key = normalize_name(spell.name);
            local cost = tonumber(spell.points) or 0;
            if equipped_lookup[key] and selected_count < slot_cap and (used + cost) <= point_cap then
                state.build_selected[key] = true;
                used = used + cost;
                selected_count = selected_count + 1;
            end
        end
        if #equipped == 0 then
            log_message('Unable to read currently equipped BLU spells.');
        end
    end
    if imgui.IsItemHovered() then imgui.SetTooltip('Load the spells you have set right now'); end
    imgui.SameLine();
    if imgui.Button('Clear##blu_build_clear') then
        state.build_selected = {};
        used, selected_count = 0, 0;
    end

    -- Trait chips: filter Known Spells to one trait.
    imgui.Spacing();
    imgui.Spacing();
    section_title('FILTER BY TRAIT');
    local chip_w = tonumber((imgui.GetContentRegionAvail())) or 260;
    local line_x = 0;
    local spacing = 4;
    for index, chip in ipairs(chips) do
        local w = bp_text_w(chip.label) + 18;
        if index > 1 then
            if line_x + spacing + w <= chip_w then
                imgui.SameLine(0, spacing);
                line_x = line_x + spacing;
            else
                line_x = 0;
            end
        end
        if bp_chip(chip.label, 'bp_chip_' .. tostring(index), state.build_trait_filter == chip.value) then
            state.build_trait_filter = chip.value;
        end
        line_x = line_x + w;
    end

    imgui.EndChild();

    imgui.PopStyleColor(1);
end

function draw_bluprints_companion_window()
    if not state.open[1] or not state.build_page[1] then
        return;
    end

    local main_x = tonumber(state.main_frame_x);
    local main_y = tonumber(state.main_frame_y);
    local main_w = tonumber(state.main_frame_w);
    local main_h = tonumber(state.main_frame_h);
    if not main_x or not main_y or not main_w or not main_h then
        return;
    end

    -- This window intentionally follows the main Azure Codex window and has
    -- no close button. It exists only while the BLUPrints tab is active.
    imgui.SetNextWindowPos({ main_x + main_w + 8, main_y });
    -- Width follows the content (Trait Planner lines); height matches the
    -- main window.
    if imgui.SetNextWindowSizeConstraints ~= nil then
        imgui.SetNextWindowSizeConstraints({ 260, main_h }, { 1100, main_h });
    end

    push_theme();
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);

    local flags = bit.bor(ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_AlwaysAutoResize);
    if not state.title_bar[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar);
    end

    if imgui.Begin('Azure Codex - BLUPrint Details##azure_codex_bluprint_details', nil, flags) then
        local base_font_size = imgui.GetFontSize();
        local requested_size = base_font_size * state.font_scale[1];
        imgui.PushFont(nil, requested_size);

        local point_cap, slot_cap, cap_estimated = get_build_caps();
        local used, selected_count = enforce_build_cap(point_cap, slot_cap);
        local trait_totals, selected_spells = get_trait_totals();

        -- The build's slots are in the main window; this panel shows the
        -- totals, VS Equipped, the Trait Calculator and the Trait Planner.
        imgui.TextColored(state.header_color, 'BUILD');
        imgui.Separator();
        imgui.TextColored(state.known_color, ('%d / %d SPELLS'):fmt(selected_count, slot_cap));
        imgui.SameLine();
        imgui.Text(('%d / %d POINTS'):fmt(used, point_cap));
        if cap_estimated then
            imgui.SameLine();
            imgui.TextColored(MUTED, '(level limits)');
        end
        if #selected_spells == 0 then
            imgui.TextColored(MUTED, 'Click spells on the left to build a set.');
        end

        if #selected_spells > 0 then
            imgui.Spacing();
            draw_equipped_diff(selected_spells);
        end

        imgui.Spacing();
        imgui.Separator();
        imgui.TextColored(state.header_color, 'TRAIT CALCULATOR');
        imgui.SameLine();
        imgui.TextDisabled('(?)');
        if imgui.IsItemHovered() then
            imgui.BeginTooltip();
            imgui.PushTextWrapPos(420);
            imgui.TextUnformatted('HorizonXI 75-era rules: each spell gives 4 points to its trait (some give fewer: '
                .. 'Stinking Gas, Cold Wave 1; Frightful Roar, Self-Destruct, Winds of Promyvion 2; Light of Penance, '
                .. 'Voracious Trunk 3). Most traits gain a tier every 8 points; Auto Refresh and Conserve MP unlock at 8 points and have only Tier I; Resist Gravity '
                .. 'tiers are 8 / 12 / 16. Each trait has its own maximum tier.');
            imgui.PopTextWrapPos();
            imgui.EndTooltip();
        end
        imgui.Separator();
        -- Fixed bar width: this window sizes itself to its content.
        draw_trait_list(trait_totals, 'card', math.floor(260 * (tonumber(state.font_scale[1]) or 1.0)));

        imgui.Spacing();
        draw_trait_planner(trait_totals, used, selected_count, point_cap, slot_cap);

        imgui.PopFont();
    end

    imgui.End();
    imgui.PopStyleVar(1);
    pop_theme();
end
