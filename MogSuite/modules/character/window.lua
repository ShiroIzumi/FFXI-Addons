--[[
    MogSuite - modules/character/window.lua

    The Character window: header, HP / MP / TP, tabs and the open key.
]]

function capture_geometry()
    if state.locked[1] then return; end
    local x, y = imgui.GetWindowPos();
    local w, h = imgui.GetWindowSize();

    x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h);
    if x and y and w and h then
        if math.abs(x - state.last_x) > 0.5 or math.abs(y - state.last_y) > 0.5
            or math.abs(w - state.last_w) > 0.5 or math.abs(h - state.last_h) > 0.5 then
            state.last_x, state.last_y, state.last_w, state.last_h = x, y, w, h;
            state.geometry_dirty = true;
        end
    end
end

function toggle_sheet()
    state.open[1] = not state.open[1];
    state.apply_saved_geometry = true;
    state.settings_dirty = true;
end

SHEET_TABS = { 'Overview', 'Skills', 'Currencies', 'Gear Stats' };
SHEET_TAB_COLORS = { 'water', 'wind', 'light', 'fire' };
SHEET_TAB_TIPS = {
    'Equipment, attributes, resistances, haste and jobs',
    'Combat, magic and crafting skills with their caps',
    'Conquest points, seals, guild points and more',
    'Stats your equipped gear gives you',
};

function player_name()
    local party = get_party();
    local name = safe_call(party, 'GetMemberName', 0);
    name = tostring(name or '');
    if name == '' then return 'Character'; end
    return name;
end

function draw_main()
    if not state.open[1] then return; end

    local player = get_player();
    if player == nil then return; end

    local scale = state.overall_scale[1];

    if state.apply_saved_geometry then
        imgui.SetNextWindowPos({ state.last_x, state.last_y });
        imgui.SetNextWindowSize({ state.last_w, state.last_h });
        state.apply_saved_geometry = false;
    end

    -- Minimum width = what the content needed last frame (measured from the
    -- real text at the current UI Scale) + window padding + scrollbar.
    local min_w = math.max(320, (tonumber(state.req_w) or 0) + (18 * scale) + 16);
    imgui.SetNextWindowSizeConstraints({ min_w, 260 * scale }, { 4000, 3000 });

    local flags = ImGuiWindowFlags_NoNav;
    if state.locked[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoResize);
    end
    if not state.title_bar[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar);
    end

    push_sheet_theme(scale);
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);

    if imgui.Begin('MogSuite  -  Character##charsheet', state.open, flags) then
        -- Ashita v4-compatible font scaling. This is the same method used
        -- by our working MobHunt / BLUSpells-style windows.
        imgui.PushFont(nil, imgui.GetFontSize() * state.font_scale[1]);
        state.frame_req_w = 0;

        local main_job = tonumber(safe_call(player, 'GetMainJob')) or 0;
        local main_level = tonumber(safe_call(player, 'GetMainJobLevel')) or 0;
        local sub_job = tonumber(safe_call(player, 'GetSubJob')) or 0;
        local sub_level = tonumber(safe_call(player, 'GetSubJobLevel')) or 0;
        local base_level = tonumber(safe_call(player, 'GetJobLevel', main_job)) or main_level;

        local main_name = skilldata.jobs[main_job] or '--';
        local sub_name = skilldata.jobs[sub_job] or '--';

        -- Vitals are refreshed every frame.
        local hp, hpmax, mp, mpmax, tp = get_current_vitals(player);

        -- Header: name on the left, jobs (and base level when synced /
        -- capped) on the right, close button when the title bar is hidden.
        local head_x = imgui.GetCursorPosX();
        local head_w = avail_width();
        local close_w = 0;
        if not state.title_bar[1] then
            close_w = 26 * scale;
        end

        imgui.PushFont(nil, imgui.GetFontSize() * 1.15);
        imgui.TextColored(UI_ACCENT_TEXT, player_name());
        imgui.PopFont();

        local job_text = ('%s %d / %s %d'):fmt(main_name, main_level, sub_name, sub_level);
        local base_text = (base_level ~= main_level) and (('  (base %d)'):fmt(base_level)) or '';
        require_width(text_width(player_name()) * 1.15 + text_width(job_text) + text_width(base_text) + close_w + 20 * scale);
        local right_x = head_x + head_w - close_w;
        imgui.SameLine();
        imgui.SetCursorPosX(math.max(imgui.GetCursorPosX() + 8, right_x - text_width(job_text) - text_width(base_text)));
        imgui.TextColored(UI_BRIGHT, job_text);
        if base_text ~= '' then
            imgui.SameLine(0, 0);
            imgui.TextColored(state.muted_color, base_text);
        end

        if not state.title_bar[1] then
            imgui.SameLine();
            imgui.SetCursorPosX(head_x + head_w - 22 * scale);
            if imgui.Button('X##charsheet_close', { 22 * scale, 0 }) then
                state.open[1] = false;
                state.settings_dirty = true;
            end
            tip('Close the Character window');
        end

        imgui.Spacing();
        draw_vitals(hp, hpmax, mp, mpmax, tp);
        imgui.Spacing();

        -- Tabs + Config.
        local tabs_x = imgui.GetCursorPosX();
        local tabs_w = avail_width();
        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 10 * scale, 4 * scale });
        for index, label in ipairs(SHEET_TABS) do
            if index > 1 then imgui.SameLine(0, 4); end
            if color_tab(label, 'cs_tab_' .. tostring(index), state.tab[1] == index, COLORS[SHEET_TAB_COLORS[index]], SHEET_TAB_TIPS[index]) then
                state.tab[1] = index;
                state.settings_dirty = true;
            end
        end
        local cfg_label = 'Config';
        local tabs_need = text_width(cfg_label) + 20 * scale + 8;
        for _, label in ipairs(SHEET_TABS) do
            tabs_need = tabs_need + text_width(label) + 20 * scale + 4;
        end
        require_width(tabs_need + 12 * scale);
        imgui.SameLine();
        imgui.SetCursorPosX(math.max(imgui.GetCursorPosX() + 8, tabs_x + tabs_w - text_width(cfg_label) - 20 * scale));
        if draw_toggle_button(cfg_label, 'charsheet_cfg_btn', false) then
            MS.open_config('character');
        end
        tip('Character settings');
        imgui.PopStyleVar(1);

        imgui.PushStyleColor(ImGuiCol_Separator, ui_accent(0.30));
        imgui.Separator();
        imgui.PopStyleColor(1);

        local tab = tonumber(state.tab[1]) or 1;
        if tab == 2 then
            imgui.Spacing();
            draw_skills_tab(player, main_job, main_level, sub_job, sub_level);
        elseif tab == 3 then
            imgui.Spacing();
            draw_currencies_tab();
        elseif tab == 4 then
            imgui.Spacing();
            draw_gear_tab(cached_gear_stats());
        else
            sheet_section('EQUIPMENT', 'hover an item for details');
            imgui.Spacing();
            draw_equipment_strip();

            sheet_section('ATTRIBUTES');
            imgui.Spacing();
            draw_attributes(player);

            sheet_section('RESISTANCES');
            imgui.Spacing();
            draw_resistances(player);

            sheet_section('HASTE');
            imgui.Spacing();
            draw_haste_row(cached_gear_stats(), active_haste_effects(player));

            sheet_section('JOBS', jobs_note(player));
            imgui.Spacing();
            draw_jobs(player, main_job, sub_job);
        end

        imgui.PopFont();
        state.req_w = state.frame_req_w;
        capture_geometry();
    end

    imgui.End();
    imgui.PopStyleVar(1);
    pop_sheet_theme();
end
