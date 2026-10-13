--[[
    Azure Codex - ac/zones.lua

    Spell Locations window, Zone Info window, the learning index, Farm Zones
    and the Learned Log window.
]]

function draw_location_window()
    if not state.location_open[1] or state.location_spell == nil then
        return;
    end

    local spell = state.location_spell;
    local entries = locations.get(spell.name) or {};

    if state.location_apply_default_size then
        imgui.SetNextWindowSize({ 760, 650 });
        state.location_apply_default_size = false;
        state.location_size_initialized = true;
    end

    if imgui.SetNextWindowSizeConstraints ~= nil then
        imgui.SetNextWindowSizeConstraints(
            { LOCATION_MIN_WIDTH, 180 },
            { LOCATION_MAX_WIDTH, 1200 }
        );
    end

    local location_flags = ImGuiWindowFlags_NoNav;
    if state.location_locked[1] then
        location_flags = bit.bor(
            location_flags,
            ImGuiWindowFlags_NoMove,
            ImGuiWindowFlags_NoResize
        );
    end
    if not state.title_bar[1] then
        location_flags = bit.bor(location_flags, ImGuiWindowFlags_NoTitleBar);
    end

    -- push_theme applies the same configured window color / transparency
    -- used by the main BLUSpells window.
    push_theme();
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);

    -- Keep one stable ImGui window identity for every spell so position/size are shared.
    -- The text before ### may change; the ID after ### remains constant.
    local title = 'Azure Codex - Spell Locations - ' .. tostring(spell.name) .. '###bluspells_locations';
    window_drag_apply('locations');
    if imgui.Begin(title, state.location_open, location_flags) then
        local base_font_size = imgui.GetFontSize();
        local requested_size = base_font_size * state.font_scale[1];
        imgui.PushFont(nil, requested_size);

        local location_avail_w = select(1, imgui.GetContentRegionAvail());
        location_avail_w = tonumber(location_avail_w) or 760;

        -- Header: spell name and mob family on the left, close button
        -- (title bar hidden) measured and right-aligned so nothing overlaps.
        do
            local frame_h = imgui.GetFrameHeight();
            local start_x = imgui.GetCursorPosX();
            align_label();
            imgui.TextColored(state.header_color, tostring(spell.name));
            imgui.SameLine(0, 16);
            align_label();
            imgui.TextColored(MUTED, 'Mob Family:');
            imgui.SameLine();
            align_label();
            imgui.Text(tostring(spell.mob_family or '--'));
            if not state.title_bar[1] then
                imgui.SameLine();
                local close_x = start_x + location_avail_w - frame_h;
                if imgui.GetCursorPosX() < close_x then imgui.SetCursorPosX(close_x); end
                if imgui.Button('X##bluspells_locations_close', { frame_h, frame_h }) then
                    state.location_open[1] = false;
                end
            end
        end

        imgui.Separator();

        -- Only the list scrolls (same layout as Farm Zones): the header and
        -- close button stay put, and the window drags like the others.
        imgui.BeginChild('##bluspells_location_list', { 0, 0 });
        if state.location_reset_scroll and imgui.SetScrollY ~= nil then
            imgui.SetScrollY(0);
            state.location_reset_scroll = false;
        end

        if #entries == 0 then
            imgui.TextColored(MUTED, 'No learning locations available.');
        else
            for zone_index, entry in ipairs(entries) do
                if zone_index > 1 then
                    imgui.Spacing();
                end

                imgui.TextColored(state.header_color, locations.get_zone_name(entry.zone));
                imgui.Separator();

                local mobs = entry.mobs or {};
                if #mobs == 0 then
                    imgui.TextColored(MUTED, 'No mobs listed.');
                else
                    local current_w = select(1, imgui.GetContentRegionAvail());
                    current_w = tonumber(current_w) or location_avail_w;

                    -- Narrow layout: one column for readability.
                    if current_w < LOCATION_TWO_COLUMN_WIDTH or imgui.BeginTable == nil then
                        for _, mob_name in ipairs(mobs) do
                            imgui.Text('  - ' .. tostring(mob_name));
                        end
                    else
                        -- Wide layout: split the list evenly into two columns
                        -- (measured, no table, so empty space drags the window).
                        local left_count = math.ceil(#mobs / 2);
                        local col_x = imgui.GetCursorPosX();
                        local half = math.floor(current_w / 2);
                        for row = 1, left_count do
                            local left_mob = mobs[row];
                            imgui.Text('  - ' .. tostring(left_mob or ''));
                            local right_mob = mobs[row + left_count];
                            if right_mob ~= nil then
                                imgui.SameLine();
                                imgui.SetCursorPosX(col_x + half);
                                imgui.Text('  - ' .. tostring(right_mob));
                            end
                        end
                    end
                end
            end
        end

        imgui.EndChild();

        window_drag('locations', state.location_locked[1]);

        imgui.PopFont();
    end

    imgui.End();
    imgui.PopStyleVar();
    pop_theme();
end

function draw_zone_info_window()
    if not state.zone_info_open[1] then
        state.zone_apply_saved_geometry = true;
        return;
    end

    if state.zone_apply_saved_geometry then
        imgui.SetNextWindowPos({ state.zone_last_x, state.zone_last_y }, { 0, 0 });
        imgui.SetNextWindowSize({ state.zone_last_w, state.zone_last_h });
        state.zone_apply_saved_geometry = false;
    end

    local zone_id = safe_current_zone_id();

    if zone_id ~= state.zone_last_id then
        state.zone_last_id = zone_id;
        state.zone_reset_scroll = true;
    end

    local zone_name = zone_id and locations.get_zone_name(zone_id) or 'Unknown Zone';
    local known_count, total_count, rows = get_zone_progress(zone_id);

    local zone_flags = ImGuiWindowFlags_NoNav;
    if state.zone_locked[1] then
        zone_flags = bit.bor(
            zone_flags,
            ImGuiWindowFlags_NoMove,
            ImGuiWindowFlags_NoResize
        );
    end
    if not state.title_bar[1] then
        zone_flags = bit.bor(zone_flags, ImGuiWindowFlags_NoTitleBar);
    end

    -- Keep Zone Info usable on narrow layouts while preventing the window from
    -- collapsing so far that the header/status fields become unreadable.
    if imgui.SetNextWindowSizeConstraints ~= nil then
        imgui.SetNextWindowSizeConstraints(
            { ZONE_MIN_WIDTH, 180 },
            { ZONE_MAX_WIDTH, 1200 }
        );
    end

    -- push_theme applies the same configured window color / transparency
    -- used by the main BLUSpells window.
    push_theme();
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);

    local title = 'Azure Codex - Zone Info - ' .. tostring(zone_name) .. '###bluspells_zone_info';
    window_drag_apply('zone');
    if imgui.Begin(title, state.zone_info_open, zone_flags) then
        local base_font_size = imgui.GetFontSize();
        local requested_size = base_font_size * state.font_scale[1];
        imgui.PushFont(nil, requested_size);

        -- Header: zone name, id and progress on the left; Hide Known and
        -- the close button measured and right-aligned so nothing overlaps
        -- at any font scale.
        do
            local style = imgui.GetStyle();
            local frame_h = imgui.GetFrameHeight();
            local inner_x = (style.ItemInnerSpacing and style.ItemInnerSpacing.x) or 4;
            local spacing_x = (style.ItemSpacing and style.ItemSpacing.x) or 8;
            local start_x, start_y = imgui.GetCursorPos();
            local content_w = tonumber((imgui.GetContentRegionAvail())) or state.zone_last_w;

            local hide_w = frame_h + inner_x + (tonumber((imgui.CalcTextSize('Hide Known'))) or 80);
            local close_w = state.title_bar[1] and 0 or (frame_h + spacing_x);
            local right_w = hide_w + close_w;

            if imgui.AlignTextToFramePadding ~= nil then imgui.AlignTextToFramePadding(); end
            imgui.TextColored(state.header_color, tostring(zone_name));
            imgui.SameLine();
            if zone_id ~= nil then
                imgui.TextColored(MUTED, ('ID %d'):fmt(zone_id));
            else
                imgui.TextColored(MUTED, 'ID --');
            end
            imgui.SameLine();
            imgui.Text(('%d / %d learned'):fmt(known_count, total_count));
            imgui.SameLine();
            local text_end_x = imgui.GetCursorPosX();

            local right_x = start_x + content_w - right_w;
            if text_end_x <= right_x then
                imgui.SetCursorPosX(right_x);
            else
                imgui.NewLine();
                right_x = start_x;
            end
            imgui.Checkbox('Hide Known##bluspells_zone_hide', state.zone_hide_known);
            if not state.title_bar[1] then
                imgui.SameLine();
                if imgui.Button('X##bluspells_zone_info_close', { frame_h, frame_h }) then
                    state.zone_info_open[1] = false;
                end
            end
        end

        imgui.Separator();

        -- Only the list scrolls (same layout as Farm Zones).
        imgui.BeginChild('##bluspells_zone_list', { 0, 0 });
        if state.zone_reset_scroll and imgui.SetScrollY ~= nil then
            imgui.SetScrollY(0);
            state.zone_reset_scroll = false;
        end

        if zone_id == nil then
            imgui.TextColored(MUTED, 'Current zone information is not available yet.');
        elseif total_count == 0 then
            imgui.TextColored(MUTED, 'No tracked Blue Magic spells are available from mobs in this zone.');
        else
            local avail_w = select(1, imgui.GetContentRegionAvail());
            avail_w = tonumber(avail_w) or 680;

            local visible_rows = {};

            for _, row in ipairs(rows) do
                if not (state.zone_hide_known[1] and row.known) then
                    visible_rows[#visible_rows + 1] = row;
                end
            end

            if #visible_rows == 0 then
                imgui.TextColored(MUTED, 'No missing Blue Magic spells are tracked in this zone.');
            else
                for row_index, row in ipairs(visible_rows) do
                    local display_state, spell_color = get_spell_display_state(row.spell);
                    local status_text = display_state == 'known' and 'Known'
                        or (display_state == 'learnable' and 'Learnable' or 'Unlearnable');
                    local learn_skill = blue_magic_learn_skill(row.spell);
                    local spell_label = ('%s (BLU:%d)'):fmt(
                        tostring(row.spell.name), learn_skill
                    );

                    -- Spell (BLU:#) | Lv | Status row in measured columns (no
                    -- table, so empty space still drags the window).
                    do
                        local row_x = imgui.GetCursorPosX();
                        local level_w = (tonumber((imgui.CalcTextSize('Lv 75'))) or 40) + 16;
                        local status_w = (tonumber((imgui.CalcTextSize('Unlearnable'))) or 80) + 8;
                        imgui.TextColored(spell_color, spell_label);
                        imgui.SameLine();
                        imgui.SetCursorPosX(math.max(imgui.GetCursorPosX() + 8, row_x + avail_w - level_w - status_w));
                        imgui.TextColored(state.header_color, 'Lv');
                        imgui.SameLine();
                        imgui.Text(tostring(row.spell.level or '--'));
                        imgui.SameLine();
                        imgui.SetCursorPosX(math.max(imgui.GetCursorPosX() + 8, row_x + avail_w - status_w));
                        imgui.TextColored(spell_color, status_text);
                    end

                    -- Mobs that teach this spell in the current zone.
                    for _, mob_name in ipairs(row.mobs) do
                        imgui.Text(('  - %s'):fmt(tostring(mob_name)));
                    end

                    if row_index < #visible_rows then
                        imgui.Separator();
                    end
                end
            end
        end

        imgui.EndChild();

        window_drag('zone', state.zone_locked[1]);

        if not state.zone_locked[1] then
            capture_zone_geometry();
        end

        imgui.PopFont();
    end

    imgui.End();
    imgui.PopStyleVar();
    pop_theme();
end

-- ----------------------------------------------------------------------------
-- Learning index (missing spells by zone / mob). Rebuilt when known spells or
-- Blue Magic skill change. Era zones only (locations.lua filters them).
-- ----------------------------------------------------------------------------
learning_index = { key = nil, zones = {}, ranked = {}, by_mob = {} };

function get_learning_index()
    refresh_known_cache(false);
    local skill = safe_blue_magic_skill();
    local cache_key = tostring(known_cache.version) .. '|' .. tostring(skill);
    if learning_index.key == cache_key then
        return learning_index;
    end

    local zones = {};
    local by_mob = {};

    for _, spell in ipairs(spells) do
        if not is_known(spell.name) then
            local display_state = get_spell_display_state(spell);
            local learnable = display_state == 'learnable';
            for _, entry in ipairs(locations.get(spell.name) or {}) do
                local zone_id = tonumber(entry.zone);
                if zone_id ~= nil then
                    local zone = zones[zone_id];
                    if zone == nil then
                        zone = { id = zone_id, rows = {}, missing = 0, learnable = 0 };
                        zones[zone_id] = zone;
                    end
                    zone.rows[#zone.rows + 1] = { spell = spell, mobs = entry.mobs or {}, learnable = learnable };
                    zone.missing = zone.missing + 1;
                    if learnable then zone.learnable = zone.learnable + 1; end

                    by_mob[zone_id] = by_mob[zone_id] or {};
                    for _, mob in ipairs(entry.mobs or {}) do
                        local mob_key = tostring(mob):lower();
                        by_mob[zone_id][mob_key] = by_mob[zone_id][mob_key] or {};
                        table.insert(by_mob[zone_id][mob_key], { spell = spell, learnable = learnable });
                    end
                end
            end
        end
    end

    local ranked = {};
    for _, zone in pairs(zones) do
        zone.name = locations.get_zone_name(zone.id);
        table.sort(zone.rows, function(a, b)
            if a.learnable ~= b.learnable then return a.learnable; end
            return tostring(a.spell.name):lower() < tostring(b.spell.name):lower();
        end);
        ranked[#ranked + 1] = zone;
    end
    table.sort(ranked, function(a, b)
        if a.learnable ~= b.learnable then return a.learnable > b.learnable; end
        if a.missing ~= b.missing then return a.missing > b.missing; end
        return tostring(a.name):lower() < tostring(b.name):lower();
    end);

    learning_index.key = cache_key;
    learning_index.zones = zones;
    learning_index.ranked = ranked;
    learning_index.by_mob = by_mob;
    return learning_index;
end

function draw_close_button(id, open_ref)
    if state.title_bar[1] then return; end
    local window_w = tonumber((imgui.GetWindowSize())) or 400;
    local saved_x, saved_y = imgui.GetCursorPos();
    imgui.SetCursorPos({ math.max(8, window_w - 48), 6 });
    if imgui.Button('X##' .. id, { 22, 20 }) then
        open_ref[1] = false;
    end
    imgui.SetCursorPos({ saved_x, saved_y });
end

function draw_farm_window()
    if not state.farm_open[1] then
        state.farm_apply_geometry = true;
        return;
    end

    if state.farm_apply_geometry then
        imgui.SetNextWindowPos({ tonumber(config.farm_window.x) or 1040, tonumber(config.farm_window.y) or 160 });
        imgui.SetNextWindowSize({ tonumber(config.farm_window.width) or 520, tonumber(config.farm_window.height) or 560 });
        state.farm_apply_geometry = false;
    end

    local flags = ImGuiWindowFlags_NoNav;
    if not state.title_bar[1] then flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar); end

    push_theme();
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);
    if imgui.Begin('Azure Codex - Farm Zones###azure_farm_zones', state.farm_open, flags) then
        imgui.PushFont(nil, imgui.GetFontSize() * state.font_scale[1]);
        draw_close_button('azure_farm_close', state.farm_open);

        local index = get_learning_index();
        local current_zone = safe_current_zone_id();

        imgui.TextColored(state.header_color, 'BEST ZONES TO FARM');
        imgui.SameLine();
        imgui.Checkbox('Learnable only##azure_farm_learnable', state.farm_learnable_only);
        imgui.TextColored(MUTED, 'Zones ranked by spells you are missing (learnable first). Click a zone to expand.');
        imgui.Separator();

        -- Only the list scrolls; the header (and the close button) stay put.
        imgui.BeginChild('##azure_farm_list', { 0, 0 });

        local shown = 0;
        for _, zone in ipairs(index.ranked) do
            if not state.farm_learnable_only[1] or zone.learnable > 0 then
                shown = shown + 1;
                local expanded = state.farm_expanded[zone.id] == true;
                local label = ('%s %s'):fmt(expanded and 'v' or '>', tostring(zone.name));
                if zone.id == current_zone then label = label .. '  (here)'; end
                imgui.PushStyleColor(ImGuiCol_Text, zone.learnable > 0 and state.learnable_color or TEXT);
                if imgui.Selectable(label .. '##azure_farm_zone_' .. tostring(zone.id), expanded) then
                    state.farm_expanded[zone.id] = not expanded;
                end
                imgui.PopStyleColor(1);
                imgui.SameLine();
                imgui.TextColored(MUTED, ('%d missing, %d learnable'):fmt(zone.missing, zone.learnable));

                if expanded then
                    for _, row in ipairs(zone.rows) do
                        if not state.farm_learnable_only[1] or row.learnable then
                            local _, color = get_spell_display_state(row.spell);
                            imgui.TextColored(color, ('    %s'):fmt(tostring(row.spell.name)));
                            imgui.SameLine();
                            imgui.TextColored(MUTED, ('Lv %s  -  %s'):fmt(tostring(row.spell.level or '--'),
                                table.concat(row.mobs, ', ')));
                        end
                    end
                end
            end
        end
        if shown == 0 then
            imgui.TextColored(MUTED, 'Nothing left to learn from mobs in era zones.');
        end

        imgui.EndChild();

        local x, y = imgui.GetWindowPos();
        local w, h = imgui.GetWindowSize();
        x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h);
        if x and y and w and h then
            local fw = config.farm_window;
            if math.abs(x - (tonumber(fw.x) or 0)) >= 1 or math.abs(y - (tonumber(fw.y) or 0)) >= 1
                or math.abs(w - (tonumber(fw.width) or 0)) >= 1 or math.abs(h - (tonumber(fw.height) or 0)) >= 1 then
                fw.x, fw.y, fw.width, fw.height = x, y, w, h;
                state.settings_dirty = true;
            end
        end

        imgui.PopFont();
    end
    imgui.End();
    imgui.PopStyleVar(1);
    pop_theme();
end

-- Formatted log lines, built once per entry (not saved to settings).
log_line_cache = setmetatable({}, { __mode = 'k' });

function log_line(entry)
    local line = log_line_cache[entry];
    if line == nil then
        local where = (tonumber(entry.zone) or 0) > 0 and locations.get_zone_name(entry.zone) or '';
        local mob = tostring(entry.mob or '');
        line = {
            date = os.date('%Y-%m-%d %H:%M', tonumber(entry.time) or 0),
            spell = tostring(entry.spell or '?'),
            detail = ('%s%s%s'):fmt(where, (where ~= '' and mob ~= '') and '  -  ' or '', mob),
        };
        log_line_cache[entry] = line;
    end
    return line;
end

function draw_log_window()
    if not state.log_open[1] then
        state.log_apply_geometry = true;
        return;
    end

    if state.log_apply_geometry then
        imgui.SetNextWindowPos({ tonumber(config.log_window.x) or 1060, tonumber(config.log_window.y) or 180 });
        imgui.SetNextWindowSize({ tonumber(config.log_window.width) or 560, tonumber(config.log_window.height) or 460 });
        state.log_apply_geometry = false;
    end

    local flags = ImGuiWindowFlags_NoNav;
    if not state.title_bar[1] then flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar); end

    push_theme();
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);
    if imgui.Begin('Azure Codex - Learned Log###azure_learned_log', state.log_open, flags) then
        imgui.PushFont(nil, imgui.GetFontSize() * state.font_scale[1]);
        draw_close_button('azure_log_close', state.log_open);

        local log = config.learned_log or {};
        imgui.TextColored(state.header_color, 'LEARNED LOG');
        imgui.SameLine();
        imgui.TextColored(MUTED, ('%d entries (this character)'):fmt(#log));

        if #log > 0 then
            imgui.SameLine();
            if not state.log_clear_confirm then
                if imgui.SmallButton('Clear##azure_log_clear') then state.log_clear_confirm = true; end
            else
                imgui.TextColored(state.unknown_color, 'Clear the whole log?');
                imgui.SameLine();
                if imgui.SmallButton('Yes##azure_log_clear_yes') then
                    config.learned_log = T{};
                    state.log_clear_confirm = false;
                    state.settings_dirty = true;
                end
                imgui.SameLine();
                if imgui.SmallButton('No##azure_log_clear_no') then state.log_clear_confirm = false; end
            end
        end
        imgui.Separator();

        imgui.BeginChild('##azure_log_list', { 0, 0 });
        if #log == 0 then
            imgui.TextColored(MUTED, 'Spells you learn from now on are listed here with the time, zone and mob.');
        else
            for i = #log, 1, -1 do
                local line = log_line(log[i]);
                imgui.TextColored(MUTED, line.date);
                imgui.SameLine();
                imgui.TextColored(state.known_color, line.spell);
                if line.detail ~= '' then
                    imgui.SameLine();
                    imgui.TextColored(MUTED, line.detail);
                end
            end
        end
        imgui.EndChild();

        local x, y = imgui.GetWindowPos();
        local w, h = imgui.GetWindowSize();
        x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h);
        if x and y and w and h then
            local lw = config.log_window;
            if math.abs(x - (tonumber(lw.x) or 0)) >= 1 or math.abs(y - (tonumber(lw.y) or 0)) >= 1
                or math.abs(w - (tonumber(lw.width) or 0)) >= 1 or math.abs(h - (tonumber(lw.height) or 0)) >= 1 then
                lw.x, lw.y, lw.width, lw.height = x, y, w, h;
                state.settings_dirty = true;
            end
        end

        imgui.PopFont();
    end
    imgui.End();
    imgui.PopStyleVar(1);
    pop_theme();
end
