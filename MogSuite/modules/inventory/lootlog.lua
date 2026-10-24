--[[
    MogSuite - modules/inventory/lootlog.lua

    The session loot log window and the inventory-full banner.
]]

-- ============================================================================
-- Loot log window
-- ============================================================================

function fmt_duration(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0));
    local h, m = math.floor(sec / 3600), math.floor((sec % 3600) / 60);
    if h > 0 then return ('%dh %02dm'):fmt(h, m); end
    return ('%dm'):fmt(m);
end

function signed_gil(n)
    n = tonumber(n) or 0;
    return (n >= 0 and '+' or '-') .. fmt_gil(math.abs(n));
end

function gil_color(n)
    if n > 0 then return { 0.45, 0.85, 0.45, 1.0 }; end
    if n < 0 then return { 0.90, 0.45, 0.40, 1.0 }; end
    return UI_MUTED;
end

function draw_log_window()
    if not state.log_visible[1] then
        state.apply_log_geometry = true;
        return;
    end
    config.log_window = config.log_window or T{ x = 680, y = 180, w = 420, h = 420 };
    if state.apply_log_geometry then
        imgui.SetNextWindowPos({ config.log_window.x, config.log_window.y }, { 0, 0 });
        imgui.SetNextWindowSize({ config.log_window.w, config.log_window.h });
        state.apply_log_geometry = false;
    end

    push_theme();
    if imgui.Begin('MogSuite  -  Loot Log##nai_log', state.log_visible, ImGuiWindowFlags_NoNav) then
        imgui.PushFont(MS_FONT(), MS_FONT_SIZE() * (tonumber(config.font_scale) or 1.0));

        local elapsed = os.time() - state.session_start;
        local gained = (state.session_gil ~= nil) and (state.gil - state.session_gil) or 0;
        local per_hr = gained / math.max(elapsed, 300) * 3600;

        section_header('Session');
        imgui.TextColored(UI_MUTED, 'Time');
        imgui.SameLine(110);
        imgui.Text(fmt_duration(elapsed));

        imgui.TextColored(UI_MUTED, 'Gil');
        imgui.SameLine(110);
        imgui.TextColored(gil_color(gained), signed_gil(gained));
        imgui.SameLine(0, 10);
        imgui.TextColored(UI_MUTED, ('(%s / hr)'):fmt(signed_gil(math.floor(per_hr))));

        local day_start = tonumber(config.gil_day_start) or -1;
        if day_start >= 0 then
            local today = state.gil - day_start;
            imgui.TextColored(UI_MUTED, 'Today');
            imgui.SameLine(110);
            imgui.TextColored(gil_color(today), signed_gil(today));
        end

        local loot_value, loot_count = 0, 0;
        for _, e in ipairs(state.log) do
            loot_count = loot_count + e.qty;
            local each = price_of(e.id);
            if each ~= nil then loot_value = loot_value + each * e.qty; end
        end
        imgui.TextColored(UI_MUTED, 'Loot');
        imgui.SameLine(110);
        imgui.Text(('%d item%s'):fmt(loot_count, loot_count == 1 and '' or 's'));
        if config.show_value ~= false and loot_value > 0 then
            imgui.SameLine(0, 10);
            imgui.TextColored(config.qty_color, ('~%s gil'):fmt(fmt_gil(loot_value)));
        end

        imgui.Spacing();
        if imgui.Button('Clear log##nai_log_clear') then state.log = {}; end
        imgui.SameLine();
        if imgui.Button('New session##nai_log_reset') then
            state.log = {};
            state.session_start = os.time();
            state.session_gil = state.gil;
        end
        if imgui.IsItemHovered() then imgui.SetTooltip('Clears the log and restarts the session time and gil'); end

        imgui.Spacing();
        section_header('Items gained');
        local _, ah = imgui.GetContentRegionAvail();
        begin_child('##nai_log_list', { 0, math.max(60, tonumber(ah) or 200) }, 0);
        if #state.log == 0 then
            imgui.TextDisabled('Nothing yet. Items you gain this session show up here.');
        else
            local dl = imgui.GetWindowDrawList();
            local line_h = imgui.GetTextLineHeight();
            local icon = math.floor(line_h + 2);
            local row_h = icon + 4;
            local width = tonumber((imgui.GetContentRegionAvail())) or 300;
            for i, e in ipairs(state.log) do
                local info = get_item_info(e.id);
                local sx, sy = imgui.GetCursorScreenPos();
                imgui.InvisibleButton(('##nai_log_%d'):fmt(i), { math.max(1, width), row_h });
                if info ~= nil and (imgui.IsItemVisible == nil or imgui.IsItemVisible()) then
                    if i % 2 == 0 then
                        dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32({ 1, 1, 1, 0.025 }), 3.0);
                    end
                    local ty = sy + (row_h - line_h) * 0.5;
                    local tt = os.date('%H:%M', e.time);
                    draw_fx_text(dl, sx + 4, ty, UI_MUTED, tt);
                    local x = sx + 10 + text_w('00:00');
                    local tex = get_icon(info);
                    if tex ~= nil then
                        dl:AddImage(tex.id, { x, sy + 2 }, { x + icon, sy + 2 + icon }, { 0, 0 }, { 1, 1 }, imgui.GetColorU32(UI_WHITE));
                    end
                    x = x + icon + 6;
                    draw_fx_text(dl, x, ty, config.name_color, info.name);
                    x = x + text_w(info.name);
                    if e.qty > 1 then draw_fx_text(dl, x, ty, config.qty_color, (' x%d'):fmt(e.qty)); end
                    if config.show_value ~= false then
                        local each = price_of(e.id);
                        if each ~= nil and each > 0 then
                            local vt = fmt_gil(each * e.qty);
                            draw_fx_text(dl, sx + width - text_w(vt) - 6, ty, UI_MUTED, vt);
                        end
                    end
                end
            end
        end
        imgui.EndChild();

        imgui.PopFont();
        capture_geometry(config.log_window);
    end
    imgui.End();
    pop_theme();
end

-- ============================================================================
-- Inventory-full banner (top of the screen, a few seconds)
-- ============================================================================

function draw_full_warning()
    if os.clock() >= state.warn_until then return; end
    local b = state.bags[0];
    if b == nil then return; end
    local free = b.max - b.used;
    local text = (free <= 0) and 'INVENTORY FULL'
        or ('INVENTORY: %d SLOT%s LEFT'):fmt(free, free == 1 and '' or 'S');

    local big = 1.5;
    local dsize = imgui.GetIO().DisplaySize;
    local w = text_w(text) * big + 40;
    imgui.SetNextWindowPos({ (tonumber(dsize.x) or 1920) * 0.5 - w * 0.5, 80 }, { 0, 0 });
    local pulse = 0.75 + 0.25 * math.abs(math.sin(os.clock() * 5));
    push_theme({ 0.30 * pulse, 0.05, 0.05, 0.92 });
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoInputs or 0, ImGuiWindowFlags_NoFocusOnAppearing or 0);
    if imgui.Begin('##nai_full_warning', nil, flags) then
        imgui.PushFont(nil, imgui.GetFontSize() * big);
        imgui.TextColored({ 1.0, 0.85, 0.80, 1.0 }, text);
        imgui.PopFont();
    end
    imgui.End();
    pop_theme();
end
