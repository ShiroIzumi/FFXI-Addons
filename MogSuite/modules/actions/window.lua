--[[
    MogSuite - modules/actions/window.lua

    The Actions window: header, tabs, search, filters, pinned strip, lists and details.
]]

-- ============================================================================
-- Header: job, bars, pinned strip
-- ============================================================================

function draw_header(width)
    local me = state.me;
    local dl = imgui.GetWindowDrawList();
    local frame_h = imgui.GetFrameHeight();

    -- Job line + buttons.
    local main_t = ('%s %d'):fmt(JOB_SHORT[me.job] or '?', me.lvl);
    local sub_t = (me.sub > 0) and (' / %s %d'):fmt(JOB_SHORT[me.sub] or '?', me.sublvl) or '';
    local base_x = tonumber(imgui.GetCursorPosX()) or 0;
    imgui.AlignTextToFramePadding();
    imgui.TextColored(UI_ACCENT_TEXT, main_t);
    if sub_t ~= '' then
        imgui.SameLine(0, 0);
        imgui.TextColored(UI_MUTED, sub_t);
    end
    imgui.SameLine(0, 10);
    imgui.TextDisabled(JOB_NAMES[me.job] or '');

    local cfg_w = text_w('Config') + 16;
    local close_w = config.title_bar and 0 or (frame_h + 4);
    imgui.SameLine(math.max(0, base_x + width - cfg_w - close_w));
    if imgui.Button('Config##ab_cfg') then MS.open_config('actions'); end
    tip('Actions settings');
    if not config.title_bar then
        imgui.SameLine(0, 4);
        if imgui.Button('X##ab_close', { frame_h, frame_h }) then state.visible[1] = false; mark_dirty(); end
        tip('Close the Actions window');
    end

    -- HP / MP / TP bars.
    if config.show_bars ~= false then
        local sx, sy = imgui.GetCursorScreenPos();
        local h = math.floor(imgui.GetTextLineHeight() * 0.95);
        local gap = 6;
        local bw = (width - gap * 2) / 3;
        draw_bar(dl, sx, sy, bw, h, me.hpmax > 0 and me.hp / me.hpmax or 0, COL_HP, ('HP %d'):fmt(me.hp));
        draw_bar(dl, sx + bw + gap, sy, bw, h, me.mpmax > 0 and me.mp / me.mpmax or 0, COL_MP, ('MP %d'):fmt(me.mp));
        draw_bar(dl, sx + (bw + gap) * 2, sy, bw, h, me.tp / 3000, COL_TP, ('TP %d'):fmt(me.tp), 1 / 3);
        imgui.Dummy({ width, h + 2 });
    end
end

function draw_pinned(width)
    local pins = config.pinned or {};
    if config.show_pinned == false or #pins == 0 then return; end
    local dl = imgui.GetWindowDrawList();
    local line_h = imgui.GetTextLineHeight();
    local h = line_h + 8;
    local used = 0;
    local remove = nil;
    for i, p in ipairs(pins) do
        local row = find_row(p.k, p.n);
        local label = p.n;
        local w = text_w(label) + 22;
        if i > 1 then
            if used + 4 + w <= width then imgui.SameLine(0, 4); used = used + 4; else used = 0; end
        end
        local sx, sy = imgui.GetCursorScreenPos();
        local clicked = imgui.InvisibleButton(('##ab_pin_%d'):fmt(i), { w, h });
        local hovered = imgui.IsItemHovered();
        if clicked and row ~= nil then use_row(row); end
        if hovered and imgui.IsMouseClicked(1) then remove = i; end
        local ready = row ~= nil and row_ready_now(row);
        local have = row ~= nil and row.status == 'ready';
        dl:AddRectFilled({ sx, sy }, { sx + w, sy + h }, imgui.GetColorU32(accent(hovered and 0.34 or 0.18)), h * 0.5);
        dl:AddRect({ sx, sy }, { sx + w, sy + h }, imgui.GetColorU32(accent(ready and 0.95 or 0.45)), h * 0.5, 0, 1.0);
        if row ~= nil and (row.cd or 0) > 0 and row.cd_key ~= nil then
            local frac = cd_fraction(row.cd_key, row.cd);
            dl:AddRectFilled({ sx, sy }, { sx + w * frac, sy + h }, imgui.GetColorU32({ 0, 0, 0, 0.45 }), h * 0.5);
        end
        local col = have and (ready and UI_WHITE or UI_ACCENT_TEXT) or with_alpha(UI_MUTED, 0.6);
        draw_fx_text(dl, sx + 11, sy + 4, col, label);
        if hovered then
            local tip = (row == nil) and 'Not available on this job.  Right-click to unpin.'
                or (((row.cd or 0) > 0) and ('Ready in %s.  Click to use, right-click to unpin.'):fmt(fmt_time(row.cd))
                or 'Click to use, right-click to unpin.');
            imgui.SetTooltip(tip);
        end
        used = used + w;
    end
    if remove ~= nil then table.remove(config.pinned, remove); mark_dirty(); end
    imgui.Dummy({ 1, 2 });
end

-- ============================================================================
-- Main window
-- ============================================================================

TABS = {
    { key = 'abilities', label = 'Abilities', color = 'fire', tip = 'Your job and support job abilities' },
    { key = 'ws', label = 'Weapon Skills', color = 'earth', tip = 'Weapon skills for the weapons you have equipped' },
    { key = 'magic', label = 'Magic', color = 'thunder', tip = 'Every spell your jobs can use, by school' },
    { key = 'summons', label = 'Summons', pet_job = SMN_JOB, color = 'light', tip = 'Summons, and your avatar\'s blood pacts while it is out' },
    { key = 'wyvern', label = 'Wyvern', pet_job = DRG_JOB, color = 'wind', tip = 'Your wyvern and Dragoon pet abilities' },
    { key = 'automaton', label = 'Automaton', pet_job = PUP_JOB, color = 'ice', tip = 'Your automaton, maneuvers and pet commands' },
    { key = 'beast', label = 'Beast', pet_job = BST_JOB, color = 'dark', tip = 'Your pet, pet commands and Beastmaster abilities' },
};

FILTERS = {
    abilities = { { 'all', 'All' }, { 'ready', 'Ready now' }, { 'have', 'Learned' }, { 'locked', 'Not yet' } },
    ws = { { 'all', 'All' }, { 'have', 'Learned' }, { 'locked', 'Not yet' } },
    magic = { { 'all', 'All' }, { 'ready', 'Castable now' }, { 'have', 'Learned' }, { 'locked', 'Not yet' }, { 'missing', 'Missing scrolls' } },
    summons = { { 'all', 'All' }, { 'ready', 'Ready now' }, { 'have', 'Learned' }, { 'locked', 'Not yet' } },
    wyvern = { { 'all', 'All' }, { 'ready', 'Ready now' }, { 'have', 'Learned' }, { 'locked', 'Not yet' } },
    automaton = { { 'all', 'All' }, { 'ready', 'Ready now' }, { 'have', 'Learned' }, { 'locked', 'Not yet' } },
    beast = { { 'all', 'All' }, { 'ready', 'Ready now' }, { 'have', 'Learned' }, { 'locked', 'Not yet' } },
};

-- Grey placeholder text inside an empty search box (last item).
function draw_search_hint(text)
    if imgui.GetItemRectMin == nil or imgui.IsItemActive() then return; end
    local x1, y1 = imgui.GetItemRectMin();
    x1, y1 = tonumber(x1), tonumber(y1);
    if x1 == nil then return; end
    imgui.GetWindowDrawList():AddText({ x1 + 7, y1 + 3 }, imgui.GetColorU32({ UI_MUTED[1], UI_MUTED[2], UI_MUTED[3], 0.55 }), text);
end

function count_ready(tab)
    local n, total = 0, 0;
    for _, sec in ipairs(state.lists[tab] or {}) do
        for _, row in ipairs(sec.rows) do
            total = total + 1;
            if row.status == 'ready' then n = n + 1; end
        end
    end
    return n, total;
end

function draw_main_window()
    if not state.visible[1] then
        state.apply_geometry = true;
        return;
    end
    if state.apply_geometry then
        imgui.SetNextWindowPos({ config.window.x, config.window.y }, { 0, 0 });
        imgui.SetNextWindowSize({ config.window.w, config.window.h });
        state.apply_geometry = false;
    end
    if imgui.SetNextWindowSizeConstraints ~= nil then
        imgui.SetNextWindowSizeConstraints({ 300, 260 }, { 4000, 4000 });
    end

    push_theme();
    local flags = ImGuiWindowFlags_NoNav;
    if config.locked then flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoResize); end
    if not config.title_bar then flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar); end

    if imgui.Begin('MogSuite  -  Actions##ab_main', state.visible, flags) then
        imgui.PushFont(nil, imgui.GetFontSize() * (tonumber(config.font_scale) or 1.0));
        local width = tonumber((imgui.GetContentRegionAvail())) or 400;
        local me = state.me;

        if me == nil or me.job <= 0 then
            imgui.TextDisabled('Waiting for your character...');
            if not config.title_bar then
                imgui.SameLine();
                if imgui.Button('X##ab_close0') then state.visible[1] = false; end
            end
        else
            draw_header(width);

            -- Tabs.
            -- Pet tabs only show while you're that job (or support job, when it can use a pet).
            for _, t in ipairs(TABS) do
                if t.key == config.tab and t.pet_job ~= nil and not pet_job_active(me, t.pet_job) then
                    config.tab = 'abilities';
                end
            end
            imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 11, 5 });
            local first = true;
            for _, t in ipairs(TABS) do
                if t.pet_job == nil or pet_job_active(me, t.pet_job) then
                    if not first then imgui.SameLine(0, 4); end
                    first = false;
                    local n = count_ready(t.key);
                    if color_tab(('%s  %d'):fmt(t.label, n), 'ab_tab_' .. t.key, config.tab == t.key, COLORS[t.color], t.tip .. ('  (%d learned)'):fmt(n)) then
                        config.tab = t.key;
                        mark_dirty();
                    end
                end
            end
            imgui.PopStyleVar(1);

            -- Search + filter chips.
            imgui.PushItemWidth(math.max(120, width * 0.42));
            imgui.InputText('##ab_search', state.search, 48);
            imgui.PopItemWidth();
            if imgui.IsItemHovered() and not imgui.IsItemActive() then imgui.SetTooltip('Search by name'); end
            if (state.search[1] or '') == '' then draw_search_hint('Search'); end
            local filters = FILTERS[config.tab] or FILTERS.abilities;
            config.filter = config.filter or T{};
            local cur = config.filter[config.tab] or 'all';
            local used = math.max(120, width * 0.42) + 6;
            for _, f in ipairs(filters) do
                local w = text_w(f[2]) + 18;
                if used + 4 + w <= width then imgui.SameLine(0, 4); used = used + 4; else used = 0; end
                if chip(f[2], 'ab_f_' .. config.tab .. f[1], cur == f[1]) then
                    config.filter[config.tab] = f[1];
                    mark_dirty();
                end
                used = used + w;
            end

            draw_pinned(width);

            -- List, with the details pane below.
            local sel = state.selected and find_row(state.selected.k, state.selected.n) or nil;
            -- The details pane grows to fit what it shows (measured last
            -- frame), up to about half the window; only then does it scroll.
            local details_h, details_max = 0, 0;
            local _, avail_h = imgui.GetContentRegionAvail();
            avail_h = tonumber(avail_h) or 300;
            if config.show_details ~= false then
                local line = imgui.GetTextLineHeightWithSpacing();
                details_max = math.max(line * 3, avail_h * 0.55);
                local want = state.details_needed or (line * 3 + 8);
                details_h = math.max(line * 2 + 8, math.min(details_max, want));
            end
            local list_h = math.max(80, avail_h - details_h - ((details_h > 0) and 6 or 0));
            begin_child('##ab_list', { 0, list_h }, 0);
            draw_tab_lists(config.tab);
            imgui.EndChild();

            if config.show_details ~= false then
                imgui.Separator();
                local fits = (state.details_needed or 0) <= details_max;
                begin_child('##ab_details', { 0, details_h }, fits and (ImGuiWindowFlags_NoScrollbar or 0) or 0);
                local start_y = tonumber(imgui.GetCursorPosY()) or 0;
                if sel ~= nil then
                    draw_details(sel, false);
                else
                    imgui.TextDisabled('Click a row for details.  Double-click to use it,');
                    imgui.TextDisabled('right-click for more (use on me / party, pin, copy macro).');
                end
                local end_y = tonumber(imgui.GetCursorPosY()) or start_y;
                state.details_needed = (end_y - start_y) + start_y * 2 + 2;
                imgui.EndChild();
            end
        end

        imgui.PopFont();
        if not config.locked then capture_geometry(config.window); end
    end
    imgui.End();
    pop_theme();
end
