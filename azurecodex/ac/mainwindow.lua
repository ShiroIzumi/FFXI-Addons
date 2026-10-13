--[[
    Azure Codex - ac/mainwindow.lua

    Main window: sidebar helpers, the sidebar, the legend and draw_window.
]]

-- ----------------------------------------------------------------------------
-- Sidebar layout helpers (main window).
-- ----------------------------------------------------------------------------
function text_w(value)
    return tonumber((imgui.CalcTextSize(tostring(value)))) or 0;
end

-- Shortens text with ".." so it fits max_w.
function fit_text(value, max_w)
    value = tostring(value or '');
    if text_w(value) <= max_w then return value; end
    while #value > 1 and text_w(value .. '..') > max_w do
        value = value:sub(1, -2);
    end
    return value .. '..';
end

-- Label (muted, left), value (right) and a thin progress bar under them.
function sidebar_stat(label, value, frac, sub)
    local cw = tonumber((imgui.GetContentRegionAvail())) or 160;
    local x0 = imgui.GetCursorPosX();
    local vw = text_w(value);
    imgui.TextColored(MUTED, fit_text(label, math.max(20, cw - vw - 10)));
    imgui.SameLine();
    imgui.SetCursorPosX(x0 + cw - vw);
    imgui.Text(value);

    local dl = imgui.GetWindowDrawList();
    local sx, sy = imgui.GetCursorScreenPos();
    sy = sy + 1;
    dl:AddRectFilled({ sx, sy }, { sx + cw, sy + 4 }, imgui.GetColorU32({ 1.0, 1.0, 1.0, 0.08 }), 2.0);
    frac = math.max(0, math.min(1, tonumber(frac) or 0));
    if frac > 0 then
        dl:AddRectFilled({ sx, sy }, { sx + math.max(3, cw * frac), sy + 4 }, imgui.GetColorU32(accent()), 2.0);
    end
    imgui.Dummy({ cw, 6 });
    if sub ~= nil then
        imgui.TextColored(MUTED, sub);
    end
    imgui.Spacing();
end

-- Full-width navigation row; accent bar on the left when selected.
function sidebar_nav(label, id, selected, small)
    local cw = tonumber((imgui.GetContentRegionAvail())) or 160;
    local h = small and imgui.GetTextLineHeightWithSpacing() or imgui.GetFrameHeight();

    imgui.PushStyleColor(ImGuiCol_Header, accent(0.16));
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, accent(0.22));
    imgui.PushStyleColor(ImGuiCol_HeaderActive, accent(0.30));
    imgui.PushStyleColor(ImGuiCol_Text, selected and accent() or (small and MUTED or TEXT));
    local pushed_align = false;
    if ImGuiStyleVar_SelectableTextAlign ~= nil then
        imgui.PushStyleVar(ImGuiStyleVar_SelectableTextAlign, { 0.0, 0.5 });
        pushed_align = true;
    end

    local clicked = imgui.Selectable('  ' .. label .. '##' .. id, selected, 0, { cw, h });

    if selected and imgui.GetItemRectMin ~= nil then
        local mnx, mny = imgui.GetItemRectMin();
        local _, mxy = imgui.GetItemRectMax();
        imgui.GetWindowDrawList():AddRectFilled({ mnx, mny }, { mnx + 2, mxy }, imgui.GetColorU32(accent()), 0.0);
    end

    if pushed_align then imgui.PopStyleVar(1); end
    imgui.PopStyleColor(4);
    return clicked;
end

function sidebar_separator()
    imgui.Spacing();
    imgui.PushStyleColor(ImGuiCol_Separator, { 1.0, 1.0, 1.0, 0.07 });
    imgui.Separator();
    imgui.PopStyleColor(1);
    imgui.Spacing();
end

-- BeginChild across Ashita builds. Newer ImGui takes (id, size, child_flags,
-- window_flags); older builds take (id, size, border, window_flags). Padding
-- comes from AlwaysUseWindowPadding, which moved from window flags to
-- child flags.
function begin_child_compat(id, size, window_flags, use_padding)
    window_flags = window_flags or 0;
    local child_flags = 0;
    if use_padding and ImGuiChildFlags_AlwaysUseWindowPadding ~= nil then
        child_flags = ImGuiChildFlags_AlwaysUseWindowPadding;
    end
    local ok, result = pcall(imgui.BeginChild, id, size, child_flags, window_flags);
    if ok then return result; end

    if use_padding and ImGuiWindowFlags_AlwaysUseWindowPadding ~= nil then
        window_flags = bit.bor(window_flags, ImGuiWindowFlags_AlwaysUseWindowPadding);
    end
    return imgui.BeginChild(id, size, false, window_flags);
end

function draw_sidebar(blu_level, list_page)
    imgui.TextColored(accent(), blu_level and ('BLUE MAGE  Lv %d'):fmt(blu_level) or 'BLUE MAGE');
    imgui.Spacing();

    -- Blue Magic skill.
    local blu_skill = safe_blue_magic_skill();
    local skill_cap = blu_level and blue_magic_cap_for_level(blu_level) or nil;
    if blu_skill ~= nil and skill_cap ~= nil then
        sidebar_stat('BLU Skill', ('%d / %d'):fmt(math.floor(blu_skill), math.floor(skill_cap)),
            skill_cap > 0 and (blu_skill / skill_cap) or 0);
    elseif blu_skill ~= nil then
        sidebar_stat('BLU Skill', ('%d / --'):fmt(math.floor(blu_skill)), 0);
    else
        sidebar_stat('BLU Skill', '-- / --', 0);
    end

    -- Set points (live when the client reports them, else equipped vs the
    -- HorizonXI level limit) and spell slots.
    local blu_spent, blu_max = get_blu_points();
    if blu_level ~= nil then
        local cap_points, cap_slots = horizon_blu_caps(blu_level);
        local equipped_list, equipped_points = get_equipped_spells();
        local spent, max_points = equipped_points, cap_points;
        if blu_spent ~= nil and blu_max ~= nil then
            spent, max_points = blu_spent, blu_max;
        end
        sidebar_stat('Points', ('%d / %d'):fmt(spent, max_points),
            max_points > 0 and (spent / max_points) or 0,
            ('Spells set %d / %d'):fmt(#equipped_list, cap_slots));
        if set_cooldown_active() then
            imgui.TextColored(state.learnable_color, ('Spells ready in %ds'):fmt(math.ceil(setcd.remaining)));
            imgui.Spacing();
        end
    elseif blu_spent ~= nil and blu_max ~= nil then
        sidebar_stat('Points', ('%d / %d'):fmt(blu_spent, blu_max), blu_max > 0 and (blu_spent / blu_max) or 0);
    else
        sidebar_stat('Points', '-- / --', 0);
    end

    -- Overall progress.
    local learned_count = get_learned_count();
    local missing_count = math.max(0, #spells - learned_count);
    sidebar_stat('Learned', ('%d / %d'):fmt(learned_count, #spells),
        #spells > 0 and (learned_count / #spells) or 0,
        ('%.1f%%  |  %d missing'):fmt(#spells > 0 and (learned_count / #spells * 100.0) or 0, missing_count));

    -- Current zone.
    local zone_id = safe_current_zone_id();
    local zone_known, zone_total = get_zone_progress(zone_id);
    local zone_name = zone_id and locations.get_zone_name(zone_id) or 'This zone';
    sidebar_stat(tostring(zone_name), ('%d / %d'):fmt(zone_known, zone_total),
        zone_total > 0 and (zone_known / zone_total) or 0);

    sidebar_separator();

    if sidebar_nav('Spells', 'ac_nav_spells', list_page) then
        state.build_page[1] = false;
        state.spellsets_page[1] = false;
        state.bluprint_view_page[1] = false;
    end
    if state.visible_tabs.bluprints[1] and sidebar_nav('BLUPrints', 'ac_nav_build', state.build_page[1] == true) then
        state.build_page[1] = true;
        state.spellsets_page[1] = false;
        state.bluprint_view_page[1] = false;
    end
    if state.visible_tabs.view[1] and sidebar_nav('BLUPrint-View', 'ac_nav_view', state.bluprint_view_page[1] == true) then
        state.bluprint_view_page[1] = true;
        state.build_page[1] = false;
        state.spellsets_page[1] = false;
    end

    sidebar_separator();

    if sidebar_nav('Zone Info', 'ac_nav_zone', state.zone_info_open[1] == true, true) then
        state.zone_info_open[1] = not state.zone_info_open[1];
        state.zone_apply_saved_geometry = true;
        if state.zone_info_open[1] then state.zone_reset_scroll = true; end
    end
    if sidebar_nav('Farm Zones', 'ac_nav_farm', state.farm_open[1] == true, true) then
        state.farm_open[1] = not state.farm_open[1];
        state.farm_apply_geometry = true;
    end
    if sidebar_nav('Learned Log', 'ac_nav_log', state.log_open[1] == true, true) then
        state.log_open[1] = not state.log_open[1];
        state.log_apply_geometry = true;
    end

    -- Config pinned to the bottom of the sidebar.
    local _, rem_h = imgui.GetContentRegionAvail();
    rem_h = tonumber(rem_h) or 0;
    local row_h = imgui.GetTextLineHeightWithSpacing();
    if rem_h > row_h + 4 then
        imgui.SetCursorPosY(imgui.GetCursorPosY() + rem_h - row_h - 2);
    end
    if sidebar_nav('Config', 'ac_nav_config', state.config_open[1] == true, true) then
        state.config_open[1] = not state.config_open[1];
    end
end

-- Small colored dot + label (legend).
function legend_item(color, label)
    local h = imgui.GetTextLineHeight();
    local sx, sy = imgui.GetCursorScreenPos();
    imgui.GetWindowDrawList():AddCircleFilled({ sx + 4, sy + h * 0.5 }, 3.5, imgui.GetColorU32(color), 12);
    imgui.Dummy({ 10, h });
    imgui.SameLine(0, 4);
    imgui.TextColored(MUTED, label);
end

function draw_window()
    if not state.open[1] then
        state.apply_saved_geometry = true;

        -- Secondary windows must still render independently of the main window.
        -- This is what allows /bsz and /bluspellszone to open Zone Info by itself.
        draw_config_window();
        draw_saved_build_loader();
        draw_location_window();
        draw_zone_info_window();

        if (state.config_geometry_dirty or state.zone_geometry_dirty or state.settings_dirty)
            and (os.clock() - state.last_save) >= 0.50 then
            save_config();
            state.config_geometry_dirty = false;
            state.zone_geometry_dirty = false;
            state.settings_dirty = false;
            state.last_save = os.clock();
        end

        return;
    end

    if state.apply_saved_geometry then
        imgui.SetNextWindowPos({ state.last_x, state.last_y }, { 0, 0 });
        imgui.SetNextWindowSize({ state.last_w, state.last_h });
        state.apply_saved_geometry = false;
    end

    -- NoNav: keyboard navigation / Tab never moves focus inside Azure Codex.
    local flags = ImGuiWindowFlags_NoNav;

    if state.locked[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoResize);
    end
    if not state.title_bar[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar);
    end

    push_theme();

    -- Border visibility is independent from the window background.
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);

    -- Sidebar width from measured text at the current font scale; the window
    -- can't be resized narrower than the sidebar plus a usable table.
    local fscale = tonumber(state.font_scale[1]) or 1.0;
    local side_w = math.floor(math.max(
        text_w('BLU Points  000 / 000'),
        text_w('Rolanberry Fields  00 / 00'),
        text_w('BLUPrint-View') + 44) * fscale + 26);
    if imgui.SetNextWindowSizeConstraints ~= nil then
        imgui.SetNextWindowSizeConstraints({ side_w + 460, 320 }, { 10000, 10000 });
    end

    if imgui.Begin('Azure Codex##bluspells', state.open, flags) then
        build_resource_cache();
        update_known_snapshot();

        local base_font_size = imgui.GetFontSize();
        imgui.PushFont(nil, base_font_size * state.font_scale[1]);

        local blu_level = safe_blu_level();
        local list_page = not state.build_page[1] and not state.bluprint_view_page[1]
            and not state.spellsets_page[1];
        local child_flags = ImGuiWindowFlags_NoNav or 0;

        -- ===== Sidebar: progress + navigation =====
        imgui.PushStyleColor(ImGuiCol_ChildBg, { 1.0, 1.0, 1.0, 0.018 });
        begin_child_compat('##ac_sidebar', { side_w, 0 },
            bit.bor(child_flags, ImGuiWindowFlags_NoScrollbar or 0), true);
        draw_sidebar(blu_level, list_page);
        imgui.EndChild();
        imgui.PopStyleColor(1);

        if imgui.GetItemRectMin ~= nil then
            local _, side_top = imgui.GetItemRectMin();
            local side_right, side_bottom = imgui.GetItemRectMax();
            imgui.GetWindowDrawList():AddLine({ side_right, side_top }, { side_right, side_bottom },
                imgui.GetColorU32({ 1.0, 1.0, 1.0, 0.07 }), 1.0);
        end

        imgui.SameLine(0, 8);

        -- ===== Main area: search, filters, page =====
        begin_child_compat('##ac_main', { 0, 0 }, child_flags, false);

        local frame_h = imgui.GetFrameHeight();
        local clear_w = text_w('Clear') + 18;
        local close_w = state.title_bar[1] and 0 or (frame_h + 8);
        local row_w = tonumber((imgui.GetContentRegionAvail())) or 500;

        imgui.PushItemWidth(math.max(120, row_w - clear_w - close_w - 10));
        input_text_no_tab('##bluspells_search', state.search, 128);
        imgui.PopItemWidth();
        if imgui.IsItemHovered() and not imgui.IsItemActive() then
            imgui.SetTooltip('Search every column. Use | for OR, e.g. refresh|regen|goblin');
        end

        local current_search = tostring(state.search[1] or '');
        if current_search ~= state.last_search then
            state.last_search = current_search;
            mark_ui_state_changed(true);
        end

        imgui.SameLine();
        if imgui.Button('Clear##bluspells_search_clear') then
            state.search[1] = '';
            state.last_search = '';
            mark_ui_state_changed(true);
        end

        if not state.title_bar[1] then
            imgui.SameLine();
            if imgui.Button('X##bluspells_custom_close', { frame_h, frame_h }) then
                state.open[1] = false;
                state.config_open[1] = false;
            end
        end

        -- Individual filter visibility, with no leading/trailing SameLine.
        local vt = state.visible_tabs;
        local first_filter = true;
        local function visible_filter(key, label, mode, enabled)
            if not vt[key][1] then return; end
            if not first_filter then imgui.SameLine(0, 4); end
            first_filter = false;
            draw_filter_button(label, mode, enabled);
        end
        visible_filter('all', 'All', 'all', true);
        visible_filter('known', 'Known', 'known', true);
        visible_filter('missing', 'Missing', 'missing', true);
        visible_filter('ready', blu_level and ('Up to Lv ' .. tostring(blu_level)) or 'Up to My Level',
            'ready', blu_level ~= nil);

        imgui.Spacing();

        if state.build_page[1] then
            draw_spell_build_tab();
        elseif state.bluprint_view_page[1] then
            draw_bluprint_view_page();
        else
            calculate_per_page();

            local filtered = get_filtered_spells();
            maybe_jump_to_selected(filtered);

            local pages = clamp_page(#filtered);
            local first = ((state.page - 1) * state.per_page) + 1;
            local last = math.min(first + state.per_page - 1, #filtered);

            if #filtered == 0 then
                imgui.TextColored(MUTED, 'No spells match the current search/filter.');
            else
                draw_main_table(filtered, first, last);
            end

            imgui.Spacing();

            local page_color = state.paging_color;
            local hover = {
                clamp(page_color[1] + 0.14, 0, 1),
                clamp(page_color[2] + 0.08, 0, 1),
                clamp(page_color[3] + 0.08, 0, 1),
                page_color[4],
            };
            local active = {
                clamp(page_color[1] + 0.22, 0, 1),
                clamp(page_color[2] + 0.12, 0, 1),
                clamp(page_color[3] + 0.12, 0, 1),
                page_color[4],
            };

            imgui.PushStyleColor(ImGuiCol_Button, page_color);
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, hover);
            imgui.PushStyleColor(ImGuiCol_ButtonActive, active);

            if state.page > 1 then
                if imgui.Button('< Prev') then state.page = state.page - 1; end
            else
                imgui.BeginDisabled();
                imgui.Button('< Prev');
                imgui.EndDisabled();
            end

            imgui.SameLine();
            align_label();
            imgui.Text(('%d / %d'):fmt(state.page, pages));
            imgui.SameLine();

            if state.page < pages then
                if imgui.Button('Next >') then state.page = state.page + 1; end
            else
                imgui.BeginDisabled();
                imgui.Button('Next >');
                imgui.EndDisabled();
            end

            imgui.PopStyleColor(3);

            imgui.SameLine(0, 16);
            align_label();
            imgui.TextColored(MUTED, ('%d of %d spells'):fmt(#filtered, #spells));
            imgui.SameLine(0, 16);
            legend_item(state.known_color, 'Known');
            imgui.SameLine(0, 10);
            legend_item(state.learnable_color, 'Learnable');
            imgui.SameLine(0, 10);
            legend_item(state.unknown_color, 'Unlearnable');
        end

        imgui.EndChild();

        imgui.PopFont();

        -- Capture live geometry every frame so the BLUPrint details window
        -- stays directly beside Azure Codex even while the main window moves.
        local frame_x, frame_y = imgui.GetWindowPos();
        local frame_w, frame_h = imgui.GetWindowSize();
        state.main_frame_x = tonumber(frame_x);
        state.main_frame_y = tonumber(frame_y);
        state.main_frame_w = tonumber(frame_w);
        state.main_frame_h = tonumber(frame_h);

        if not state.locked[1] then
            capture_main_geometry();
        end
    end

    imgui.End();
    imgui.PopStyleVar(1);
    pop_theme();

    draw_config_window();
    draw_saved_build_loader();
    draw_bluprints_companion_window();
    draw_location_window();
    draw_zone_info_window();

    if (state.geometry_dirty or state.config_geometry_dirty or state.zone_geometry_dirty or state.settings_dirty)
        and (os.clock() - state.last_save) >= 0.50 then
        save_config();
        state.geometry_dirty = false;
        state.config_geometry_dirty = false;
        state.zone_geometry_dirty = false;
        state.settings_dirty = false;
        state.last_save = os.clock();
    end
end
