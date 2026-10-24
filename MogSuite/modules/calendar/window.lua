--[[
    MogSuite - modules/calendar/window.lua

    The Calendar window (L):
      Today      what's going on now: the day, moon, conquest, your timers
                 and events, guilds and the next ships
      Vana'diel  a month of Vana'diel days (element, moon) with the Earth
                 time each one starts
      Earth      your month: events, timers getting ready, conquest results,
                 full / new moons
      Timers     cooldowns you start yourself (Dynamis, Limbus, ENM key items ...)
      Events     your own events (all characters)
      Travel     ships, airships and guild hours
    Plus the login summary and the small notice popup.
]]

local TABS = {
    { key = 'today',  label = 'Today',     color = COLORS.light },
    { key = 'vana',   label = "Vana'diel", color = COLORS.water },
    { key = 'earth',  label = 'Earth',     color = COLORS.earth },
    { key = 'timers', label = 'Timers',    color = COLORS.wind },
    { key = 'events', label = 'Events',    color = COLORS.fire },
    { key = 'travel', label = 'Travel',    color = COLORS.ice },
};

local MONTHS = { 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December' };
local WEEK = { 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' };

local GOOD = { 0.43, 0.85, 0.50, 1.0 };
local WARN = { 0.95, 0.72, 0.32, 1.0 };
local BAD  = { 0.92, 0.42, 0.40, 1.0 };

local function lh() return imgui.GetTextLineHeight(); end
local function avail_w() return tonumber((imgui.GetContentRegionAvail())) or 400; end

local function pair(label, value, col, w)
    imgui.TextColored(UI_MUTED, label);
    imgui.SameLine(w or (150 * (tonumber(config.font_scale) or 1)));
    imgui.TextColored(col or UI_TEXT, value);
end

local function card_begin(id, title, color, h)
    begin_child('##calcard_' .. id, { 0, h or 0 }, ImGuiWindowFlags_NoScrollbar or 0);
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    dl:AddRectFilled({ x, y }, { x + 3, y + lh() }, imgui.GetColorU32(color or UI_ACCENT), 1.0);
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 8);
    imgui.TextColored(color or UI_ACCENT_TEXT, title);
end

-- ============================================================================
-- Today
-- ============================================================================

local function draw_today()
    local v = vana_at();
    local now = os.time();
    local scale = tonumber(config.font_scale) or 1;
    local dl = imgui.GetWindowDrawList();

    -- Header: big Vana'diel time, the day, the moon.
    local x, y = imgui.GetCursorScreenPos();
    local col = VDAY_COLORS[v.weekday];
    local big = imgui.GetFontSize() * 1.9;
    local t = ('%02d:%02d'):format(v.hour, v.minute);
    dl:AddText(imgui.GetFont(), big, { x, y }, imgui.GetColorU32(UI_TEXT), t);
    local tw = text_w(t) * 1.9;
    dl:AddText(imgui.GetFont(), imgui.GetFontSize() * 1.25, { x + tw + 14, y + 2 }, imgui.GetColorU32(col), VDAYS[v.weekday]);
    dl:AddText({ x + tw + 14, y + big * 0.62 }, imgui.GetColorU32(UI_MUTED),
        ("Vana'diel %d/%d/%d  -  next day in %s"):fmt(v.year, v.month, v.day, span(v.to_next)));
    local mr = big * 0.42;
    local mx = x + avail_w() - mr - 6;
    draw_moon(dl, mx, y + big * 0.5, mr, v.moon_pct, v.moon_waxing);
    local ml = ('%s %d%%'):fmt(v.moon_name, v.moon_pct);
    dl:AddText({ mx - mr - 10 - text_w(ml), y + big * 0.5 - lh() / 2 }, imgui.GetColorU32({ 0.96, 0.94, 0.80, 1 }), ml);
    imgui.Dummy({ 1, big + 6 });
    imgui.TextColored(UI_MUTED, ('%s element, strong against %s.  Earth time %s.'):fmt(VDAY_SHORT[v.weekday], VDAY_BEATS[v.weekday], os.date(config.time24 and '%H:%M' or '%I:%M %p')));
    imgui.Separator();

    local half = (avail_w() - 8) / 2;
    imgui.BeginGroup();
    begin_child('##caltoday_l', { half, 0 }, 0);

    -- Coming up.
    imgui.TextColored(UI_ACCENT_TEXT, 'COMING UP');
    if config.conquest.enabled ~= false then
        local c = next_conquest(now);
        pair('Conquest results', ('in %s'):fmt(span(c - now)), COLORS.earth, half * 0.45);
        if imgui.IsItemHovered() then imgui.SetTooltip(when_at(c)); end
    end
    local items = items_between(now, now + 7 * 86400);
    local shown = 0;
    for _, it in ipairs(items) do
        if it.kind ~= 'conquest' and shown < 8 then
            shown = shown + 1;
            pair(it.title, 'in ' .. span(it.t - now), it.color, half * 0.45);
            if imgui.IsItemHovered() then imgui.SetTooltip(when_at(it.t)); end
        end
    end
    if shown == 0 then imgui.TextDisabled('No events or timers this week.'); end
    imgui.Spacing();

    -- Timers.
    imgui.TextColored(UI_ACCENT_TEXT, 'TIMERS');
    if #(config.timers or {}) == 0 then imgui.TextDisabled('None yet (Timers tab).'); end
    for _, tm in ipairs(config.timers or {}) do
        local st, left = timer_status(tm);
        if st == 'ready' then pair(tm.name, 'Ready', GOOD, half * 0.45);
        elseif st == 'waiting' then pair(tm.name, span(left), WARN, half * 0.45);
        else pair(tm.name, 'not started', UI_MUTED, half * 0.45); end
    end
    imgui.Spacing();

    -- The next Vana'diel days.
    imgui.TextColored(UI_ACCENT_TEXT, 'NEXT DAYS');
    for k = 1, 8 do
        local td = v.total_days + k;
        local wd = td % 8;
        local start = vday_start(td);
        local name, pct = moon_of(td);
        imgui.TextColored(VDAY_COLORS[wd], VDAYS[wd]);
        imgui.SameLine(half * 0.33);
        imgui.TextColored(UI_TEXT, clock_at(start));
        imgui.SameLine(half * 0.56);
        imgui.TextColored(UI_MUTED, ('%s %d%%'):fmt(name, pct));
    end
    imgui.EndChild();
    imgui.EndGroup();

    imgui.SameLine(0, 8);
    begin_child('##caltoday_r', { 0, 0 }, 0);
    imgui.TextColored(UI_ACCENT_TEXT, 'GUILDS');
    for _, g in ipairs(GUILDS) do
        local open, secs, why = guild_status(g, v);
        imgui.TextColored(open and UI_TEXT or UI_MUTED, g.name);
        imgui.SameLine(half * 0.40);
        if open then
            imgui.TextColored(GOOD, 'open');
            imgui.SameLine();
            imgui.TextColored(UI_MUTED, 'closes in ' .. span(secs));
        else
            imgui.TextColored(why == 'holiday' and WARN or BAD, why == 'holiday' and 'holiday' or 'closed');
            imgui.SameLine();
            imgui.TextColored(UI_MUTED, 'opens in ' .. span(secs));
        end
        if imgui.IsItemHovered() then imgui.SetTooltip(('%s  -  %02d:00 to %02d:00, closed on %s'):fmt(g.where, g.open, g.close, VDAYS[g.holiday])); end
    end
    imgui.Spacing();
    imgui.TextColored(UI_ACCENT_TEXT, 'NEXT SHIPS');
    local raw = vraw();
    for _, r in ipairs(ROUTES) do
        if r.group == 'Airships' or r.group == 'Ferry' then
            local st = route_status(r, raw);
            imgui.TextColored(UI_TEXT, r.name);
            imgui.SameLine(half * 0.52);
            if st.boarding then
                imgui.TextColored(GOOD, 'boarding');
                imgui.SameLine();
                imgui.TextColored(UI_MUTED, 'leaves in ' .. span(st.leaves));
            else
                imgui.TextColored(UI_MUTED, 'docks in ' .. span(st.arrives));
            end
        end
    end
    imgui.EndChild();
end

-- ============================================================================
-- Vana'diel month
-- ============================================================================

local function draw_vana()
    local v = vana_at();
    local now_month = v.year * 12 + v.month - 1;
    local m = state.vana_month or now_month;
    if imgui.Button('<##calvprev') then state.vana_month = m - 1; end
    imgui.SameLine();
    if imgui.Button('Today##calvtoday') then state.vana_month = nil; end
    imgui.SameLine();
    if imgui.Button('>##calvnext') then state.vana_month = m + 1; end
    imgui.SameLine(0, 14);
    local year, month = math.floor(m / 12), m % 12 + 1;
    local first = year * 360 + (month - 1) * 30;      -- day number of the 1st
    imgui.TextColored(UI_ACCENT_TEXT, ("Vana'diel  %d / %02d"):fmt(year, month));
    imgui.SameLine();
    imgui.TextColored(UI_MUTED, ('  %s  to  %s'):fmt(when_at(vday_start(first)), when_at(vday_start(first + 30) - 60)));

    -- 8 columns, one per weekday; the 1st sits under its own weekday.
    local w = avail_w();
    local cw = (w - 7 * 4) / 8;
    local ch = math.max(lh() * 3.3, cw * 0.52);
    local dl = imgui.GetWindowDrawList();
    local x0, y0 = imgui.GetCursorScreenPos();
    for wd = 0, 7 do
        dl:AddText({ x0 + wd * (cw + 4) + 4, y0 }, imgui.GetColorU32(VDAY_COLORS[wd]), VDAYS[wd]);
    end
    y0 = y0 + lh() + 4;
    local lead = first % 8;
    local rows = math.ceil((lead + 30) / 8);
    local mx, my = imgui.GetMousePos();
    local hovered = nil;
    for i = 0, 29 do
        local td = first + i;
        local slot = lead + i;
        local cx = x0 + (slot % 8) * (cw + 4);
        local cy = y0 + math.floor(slot / 8) * (ch + 4);
        local wd = td % 8;
        local c = VDAY_COLORS[wd];
        local is_now = (td == v.total_days);
        local past = td < v.total_days;
        dl:AddRectFilled({ cx, cy }, { cx + cw, cy + ch }, imgui.GetColorU32({ c[1], c[2], c[3], past and 0.06 or 0.13 }), 4.0);
        if is_now then dl:AddRect({ cx, cy }, { cx + cw, cy + ch }, imgui.GetColorU32(c), 4.0, 0, 2.0); end
        dl:AddText({ cx + 5, cy + 3 }, imgui.GetColorU32(past and UI_MUTED or UI_TEXT), tostring(i + 1));
        local start = vday_start(td);
        dl:AddText({ cx + 5, cy + 3 + lh() }, imgui.GetColorU32(UI_MUTED), os.date('%a ', start) .. clock_at(start));
        if config.show.moon ~= false then
            local _, pct, phase, waxing = moon_of(td);
            local r = lh() * 0.42;
            draw_moon(dl, cx + cw - r - 6, cy + r + 5, r, pct, waxing);
            if phase == 4 or phase == 0 then
                dl:AddText({ cx + 5, cy + 3 + lh() * 2 }, imgui.GetColorU32({ 0.96, 0.94, 0.80, 1 }), (phase == 4) and 'Full moon' or 'New moon');
            end
        end
        if config.show.holidays ~= false and #holiday_guilds(wd) > 0 then
            dl:AddCircleFilled({ cx + cw - 7, cy + ch - 7 }, 3, imgui.GetColorU32(WARN), 8);
        end
        local mxn, myn = tonumber(mx) or -1, tonumber(my) or -1;
        if mxn >= cx and mxn <= cx + cw and myn >= cy and myn <= cy + ch and imgui.IsWindowHovered() then hovered = td; end
    end
    imgui.Dummy({ w, rows * (ch + 4) });
    if hovered ~= nil then
        local wd = hovered % 8;
        local name, pct = moon_of(hovered);
        local s = vday_start(hovered);
        local hol = holiday_guilds(wd);
        local lines = ('%s  (%s, strong vs %s)\n%s  to  %s\n%s %d%%'):fmt(VDAYS[wd], VDAY_SHORT[wd], VDAY_BEATS[wd],
            when_at(s), clock_at(s + VDAY), name, pct);
        if #hol > 0 then lines = lines .. '\nGuild holiday: ' .. table.concat(hol, ', '); end
        for _, it in ipairs(items_between(s, s + VDAY)) do lines = lines .. '\n' .. clock_at(it.t) .. '  ' .. it.title; end
        imgui.SetTooltip(lines);
    end
    imgui.TextColored(UI_MUTED, 'A Vana\'diel day lasts 57 min 36 s of Earth time. The dot marks a guild holiday. Hover a day for details.');
end

-- ============================================================================
-- Earth month
-- ============================================================================

local function draw_earth()
    local now_t = os.date('*t');
    local em = state.earth_month or { y = now_t.year, m = now_t.month };
    if imgui.Button('<##calep') then
        local t = os.date('*t', os.time({ year = em.y, month = em.m - 1, day = 1, hour = 12 }));
        state.earth_month = { y = t.year, m = t.month };
    end
    imgui.SameLine();
    if imgui.Button('Today##calet') then state.earth_month = nil; state.earth_day = nil; end
    imgui.SameLine();
    if imgui.Button('>##calen') then
        local t = os.date('*t', os.time({ year = em.y, month = em.m + 1, day = 1, hour = 12 }));
        state.earth_month = { y = t.year, m = t.month };
    end
    imgui.SameLine(0, 14);
    imgui.TextColored(UI_ACCENT_TEXT, ('%s %d'):fmt(MONTHS[em.m], em.y));

    local first = os.time({ year = em.y, month = em.m, day = 1, hour = 0 });
    local days = tonumber(os.date('%d', os.time({ year = em.y, month = em.m + 1, day = 0, hour = 12 })));
    local lead = tonumber(os.date('%w', first));
    local items = items_between(first, os.time({ year = em.y, month = em.m + 1, day = 1, hour = 0 }));
    local by_day = {};
    for _, it in ipairs(items) do
        local d = tonumber(os.date('%d', it.t));
        by_day[d] = by_day[d] or {};
        table.insert(by_day[d], it);
    end

    local side_w = 250 * (tonumber(config.font_scale) or 1);
    begin_child('##calgrid', { avail_w() - side_w - 8, 0 }, 0);
    local w = avail_w();
    local cw = (w - 6 * 4) / 7;
    local ch = math.max(lh() * 4.2, cw * 0.62);
    local dl = imgui.GetWindowDrawList();
    local x0, y0 = imgui.GetCursorScreenPos();
    for i = 1, 7 do dl:AddText({ x0 + (i - 1) * (cw + 4) + 4, y0 }, imgui.GetColorU32(UI_MUTED), WEEK[i]); end
    y0 = y0 + lh() + 4;
    local rows = math.ceil((lead + days) / 7);
    local mx, my = imgui.GetMousePos();
    mx, my = tonumber(mx) or -1, tonumber(my) or -1;
    local today = (now_t.year == em.y and now_t.month == em.m) and now_t.day or -1;
    local pick = state.earth_day;
    for d = 1, days do
        local slot = lead + d - 1;
        local cx = x0 + (slot % 7) * (cw + 4);
        local cy = y0 + math.floor(slot / 7) * (ch + 4);
        local sel = pick ~= nil and pick.y == em.y and pick.m == em.m and pick.d == d;
        dl:AddRectFilled({ cx, cy }, { cx + cw, cy + ch }, imgui.GetColorU32(sel and accent(0.22) or { 1, 1, 1, 0.035 }), 4.0);
        if d == today then dl:AddRect({ cx, cy }, { cx + cw, cy + ch }, imgui.GetColorU32(UI_ACCENT), 4.0, 0, 2.0); end
        dl:AddText({ cx + 5, cy + 3 }, imgui.GetColorU32(d == today and UI_ACCENT_TEXT or UI_TEXT), tostring(d));
        -- Full / new moons that start this day.
        if config.show.moon ~= false then
            local ds = os.time({ year = em.y, month = em.m, day = d, hour = 0 });
            local td0 = math.floor(vraw(ds) / VDAY);
            local td1 = math.floor(vraw(ds + 86400) / VDAY);
            local full, new = false, false;
            for td = td0, td1 do
                local _, _, ph = moon_of(td);
                if ph == 4 then full = true; elseif ph == 0 then new = true; end
            end
            local r = lh() * 0.36;
            if full then draw_moon(dl, cx + cw - r - 5, cy + r + 5, r, 100, true); end
            if new then draw_moon(dl, cx + cw - r * 3 - 9, cy + r + 5, r, 0, true); end
        end
        local list = by_day[d] or {};
        for k, it in ipairs(list) do
            if k > 3 then
                dl:AddText({ cx + 5, cy + 3 + lh() * 4 }, imgui.GetColorU32(UI_MUTED), ('+%d more'):fmt(#list - 3));
                break;
            end
            local ty = cy + 3 + lh() * k;
            dl:AddRectFilled({ cx + 4, ty + 2 }, { cx + 7, ty + lh() - 2 }, imgui.GetColorU32(it.color), 1.0);
            local label = it.title;
            while #label > 2 and text_w(label) > cw - 14 do label = label:sub(1, #label - 2); end
            if label ~= it.title then label = label .. '..'; end
            dl:AddText({ cx + 10, ty }, imgui.GetColorU32(UI_TEXT), label);
        end
        if mx >= cx and mx <= cx + cw and my >= cy and my <= cy + ch and imgui.IsWindowHovered() and imgui.IsMouseClicked(0) then
            state.earth_day = { y = em.y, m = em.m, d = d };
        end
    end
    imgui.Dummy({ w, rows * (ch + 4) });
    imgui.EndChild();

    -- The picked day.
    imgui.SameLine(0, 8);
    begin_child('##calearthday', { 0, 0 }, 0);
    local p = state.earth_day or { y = now_t.year, m = now_t.month, d = now_t.day };
    local ds = os.time({ year = p.y, month = p.m, day = p.d, hour = 0 });
    imgui.TextColored(UI_ACCENT_TEXT, os.date('%A, %B ', ds) .. p.d);
    imgui.Separator();
    local list = items_between(ds, ds + 86400);
    if #list == 0 then imgui.TextDisabled('Nothing this day.'); end
    for _, it in ipairs(list) do
        imgui.TextColored(UI_MUTED, clock_at(it.t));
        imgui.SameLine();
        imgui.TextColored(it.color, it.title);
        if it.kind == 'event' and it.ref.note ~= nil and it.ref.note ~= '' and imgui.IsItemHovered() then imgui.SetTooltip(it.ref.note); end
    end
    imgui.Spacing();
    if imgui.Button('Add an event this day##caladdday') then
        state.form = { id = nil, title = { '' }, date = { os.date('%Y-%m-%d', ds) }, time = { '20:00' }, rep = 'none', note = { '' }, color = 'water' };
        config.tab = 'events';
        mark_dirty();
    end
    imgui.EndChild();
end

-- ============================================================================
-- Timers
-- ============================================================================

local function draw_timers()
    imgui.TextColored(UI_MUTED, 'Add one, then click Start when you do the thing (enter Dynamis, get the key item...). It counts down to Ready.');
    imgui.TextColored(UI_MUTED, 'Add:');
    for i, p in ipairs(TIMER_PRESETS) do
        imgui.SameLine(0, 4);
        if imgui.Button(p.name .. '##caltp' .. i) then add_timer(p); end
        if imgui.IsItemHovered() then imgui.SetTooltip(('%s  -  %g hours\n%s'):fmt(p.name, p.hours, p.note or '')); end
    end
    imgui.Separator();
    local list = config.timers or {};
    if #list == 0 then imgui.TextDisabled('No timers yet.'); end
    local w = avail_w();
    local remove = nil;
    for i, tm in ipairs(list) do
        imgui.PushID('caltm' .. tostring(tm.id));
        local st, left = timer_status(tm);
        local name = { tostring(tm.name or '') };
        imgui.PushItemWidth(w * 0.28);
        if imgui.InputText('##name', name, 48) then tm.name = name[1]; mark_dirty(); end
        imgui.PopItemWidth();
        imgui.SameLine();
        local hrs = { tonumber(tm.hours) or 1 };
        imgui.PushItemWidth(90);
        if imgui.InputFloat('##hours', hrs, 1, 24, '%.1f h') then tm.hours = math.max(0.1, hrs[1]); mark_dirty(); end
        imgui.PopItemWidth();
        if imgui.IsItemHovered() then imgui.SetTooltip('Length in Earth hours.'); end
        imgui.SameLine();
        -- Status + bar.
        local bx, by = imgui.GetCursorScreenPos();
        local bw = w * 0.30;
        local dl = imgui.GetWindowDrawList();
        local frac = 0;
        local label, col;
        if st == 'ready' then frac, label, col = 1, 'Ready', GOOD;
        elseif st == 'waiting' then
            local total = math.max(1, (tonumber(tm.hours) or 1) * 3600);
            frac = 1 - left / total;
            label, col = ('%s  (%s)'):fmt(span(left), when_at(timer_ready_at(tm))), WARN;
        else frac, label, col = 0, 'Not started', UI_MUTED; end
        local fh = imgui.GetFrameHeight();
        dl:AddRectFilled({ bx, by }, { bx + bw, by + fh }, imgui.GetColorU32(UI_CONTROL), 3.0);
        dl:AddRectFilled({ bx, by }, { bx + bw * math.max(0, math.min(1, frac)), by + fh }, imgui.GetColorU32({ col[1], col[2], col[3], 0.35 }), 3.0);
        dl:AddText({ bx + 6, by + (fh - lh()) / 2 }, imgui.GetColorU32(col), label);
        imgui.Dummy({ bw, fh });
        imgui.SameLine();
        if imgui.Button((st == 'idle') and 'Start' or 'Restart') then start_timer(tm); end
        if imgui.IsItemHovered() then imgui.SetTooltip('Starts counting now.'); end
        imgui.SameLine();
        if st ~= 'idle' and imgui.Button('Clear') then tm.started = 0; mark_dirty(); end
        imgui.SameLine();
        local armed = (state.confirm['tm' .. tm.id] or 0) > os.clock();
        if imgui.Button(armed and 'Sure?' or 'X') then
            if armed then remove = i; else state.confirm['tm' .. tm.id] = os.clock() + 3; end
        end
        if imgui.IsItemHovered() then imgui.SetTooltip('Delete this timer (click twice).'); end
        if tm.note ~= nil and tm.note ~= '' then
            imgui.SetCursorPosX(imgui.GetCursorPosX() + 6);
            imgui.TextColored(UI_MUTED, tm.note);
        end
        imgui.PopID();
        imgui.Spacing();
    end
    if remove ~= nil then table.remove(list, remove); mark_dirty(); end
end

-- ============================================================================
-- Events
-- ============================================================================

local function parse_when(date_s, time_s)
    local y, m, d = tostring(date_s):match('^%s*(%d%d%d%d)%-(%d%d?)%-(%d%d?)%s*$');
    local hh, mm, ap = tostring(time_s):lower():match('^%s*(%d%d?):(%d%d)%s*([ap]?)m?%s*$');
    if y == nil or hh == nil then return nil; end
    hh = tonumber(hh);
    if ap == 'p' and hh < 12 then hh = hh + 12; elseif ap == 'a' and hh == 12 then hh = 0; end
    return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = hh, min = tonumber(mm), sec = 0 });
end

local function draw_form()
    local f = state.form;
    imgui.TextColored(UI_ACCENT_TEXT, f.id and 'EDIT EVENT' or 'NEW EVENT');
    local lw = 90 * (tonumber(config.font_scale) or 1);
    imgui.TextColored(UI_MUTED, 'Title'); imgui.SameLine(lw);
    imgui.PushItemWidth(320); imgui.InputText('##calftitle', f.title, 80); imgui.PopItemWidth();
    imgui.TextColored(UI_MUTED, 'Date'); imgui.SameLine(lw);
    imgui.PushItemWidth(120); imgui.InputText('##calfdate', f.date, 16); imgui.PopItemWidth();
    imgui.SameLine(); imgui.TextColored(UI_MUTED, 'YYYY-MM-DD');
    imgui.SameLine(0, 16); imgui.TextColored(UI_MUTED, 'Time'); imgui.SameLine();
    imgui.PushItemWidth(90); imgui.InputText('##calftime', f.time, 12); imgui.PopItemWidth();
    imgui.SameLine(); imgui.TextColored(UI_MUTED, '20:00 or 8:00 pm');
    imgui.TextColored(UI_MUTED, 'Repeats'); imgui.SameLine(lw);
    for i, r in ipairs(REPEATS) do
        if i > 1 then imgui.SameLine(0, 4); end
        if toggle_button(r.label, 'calfrep' .. r.key, f.rep == r.key) then f.rep = r.key; end
    end
    imgui.TextColored(UI_MUTED, 'Color'); imgui.SameLine(lw);
    for i, c in ipairs(EVENT_COLORS) do
        if i > 1 then imgui.SameLine(0, 4); end
        local col = COLORS[c];
        imgui.PushStyleColor(ImGuiCol_Button, { col[1], col[2], col[3], (f.color == c) and 0.9 or 0.35 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { col[1], col[2], col[3], 0.7 });
        if imgui.Button('##calfc' .. c, { imgui.GetFrameHeight(), imgui.GetFrameHeight() }) then f.color = c; end
        imgui.PopStyleColor(2);
    end
    imgui.TextColored(UI_MUTED, 'Note'); imgui.SameLine(lw);
    imgui.PushItemWidth(420); imgui.InputText('##calfnote', f.note, 300); imgui.PopItemWidth();
    local at = parse_when(f.date[1], f.time[1]);
    if at == nil then imgui.TextColored(BAD, 'Check the date and time.'); end
    if imgui.Button('Save##calfsave') and at ~= nil and tostring(f.title[1]) ~= '' then
        local list = load_events();
        local e = nil;
        if f.id ~= nil then for _, x in ipairs(list) do if x.id == f.id then e = x; end end end
        if e == nil then e = { id = new_event_id() }; list[#list + 1] = e; end
        e.title, e.at, e.rep, e.note, e.color = f.title[1], at, f.rep, f.note[1], f.color;
        save_events();
        state.form = nil;
    end
    imgui.SameLine();
    if imgui.Button('Cancel##calfcancel') then state.form = nil; end
    imgui.Separator();
end

local function draw_events()
    if state.form ~= nil then
        draw_form();
    elseif imgui.Button('+ New event##calnew') then
        state.form = { id = nil, title = { '' }, date = { os.date('%Y-%m-%d') }, time = { '20:00' }, rep = 'none', note = { '' }, color = 'water' };
    end
    if state.form == nil then
        imgui.SameLine();
        imgui.TextColored(UI_MUTED, 'Events are shared by all your characters.');
    end
    local list = load_events();
    local now = os.time();
    local rows = {};
    for _, e in ipairs(list) do
        local nxt = event_times(e, now - 3600, now + 400 * 86400)[1];
        rows[#rows + 1] = { e = e, next_t = nxt };
    end
    table.sort(rows, function(a, b)
        if (a.next_t ~= nil) ~= (b.next_t ~= nil) then return a.next_t ~= nil; end
        return (a.next_t or a.e.at or 0) < (b.next_t or b.e.at or 0);
    end);
    if #rows == 0 then imgui.TextDisabled('No events yet.'); end
    local remove = nil;
    for i, r in ipairs(rows) do
        local e = r.e;
        imgui.PushID('calev' .. tostring(e.id));
        local col = COLORS[e.color] or COLORS.water;
        imgui.TextColored(col, e.title);
        imgui.SameLine(260);
        if r.next_t ~= nil then
            imgui.TextColored(UI_TEXT, when_at(r.next_t));
            imgui.SameLine();
            imgui.TextColored(UI_MUTED, ('(in %s)'):fmt(span(r.next_t - now)));
        else
            imgui.TextColored(UI_MUTED, 'past  ' .. os.date('%Y-%m-%d', e.at));
        end
        if (e.rep or 'none') ~= 'none' then imgui.SameLine(); imgui.TextColored(UI_MUTED, '- ' .. e.rep); end
        imgui.SameLine();
        if imgui.SmallButton('Edit') then
            state.form = { id = e.id, title = { e.title }, date = { os.date('%Y-%m-%d', e.at) }, time = { os.date('%H:%M', e.at) },
                rep = e.rep or 'none', note = { e.note or '' }, color = e.color or 'water' };
        end
        imgui.SameLine();
        local armed = (state.confirm['ev' .. e.id] or 0) > os.clock();
        if imgui.SmallButton(armed and 'Sure?' or 'X') then
            if armed then remove = e.id; else state.confirm['ev' .. e.id] = os.clock() + 3; end
        end
        if e.note ~= nil and e.note ~= '' then
            imgui.SetCursorPosX(imgui.GetCursorPosX() + 10);
            imgui.TextColored(UI_MUTED, e.note);
        end
        imgui.PopID();
    end
    if remove ~= nil then
        for i = #list, 1, -1 do if list[i].id == remove then table.remove(list, i); end end
        save_events();
    end
end

-- ============================================================================
-- Travel
-- ============================================================================

local function draw_travel()
    local raw = vraw();
    local w = avail_w();
    for _, grp in ipairs(ROUTE_GROUPS) do
        imgui.TextColored(UI_ACCENT_TEXT, grp:upper());
        for _, r in ipairs(ROUTES) do
            if r.group == grp then
                local st = route_status(r, raw);
                imgui.TextColored(UI_TEXT, r.name);
                imgui.SameLine(w * 0.36);
                if st.boarding then
                    imgui.TextColored(GOOD, 'boarding');
                    imgui.SameLine(w * 0.50);
                    imgui.TextColored(UI_MUTED, 'leaves in ' .. span(st.leaves));
                else
                    imgui.TextColored(UI_MUTED, 'at sea');
                    imgui.SameLine(w * 0.50);
                    imgui.TextColored(UI_MUTED, ('docks in %s, leaves in %s'):fmt(span(st.arrives), span(st.leaves)));
                end
            end
        end
        imgui.Spacing();
    end
    local v = vana_at();
    imgui.TextColored(UI_ACCENT_TEXT, 'GUILDS');
    for _, g in ipairs(GUILDS) do
        local open, secs, why = guild_status(g, v);
        imgui.TextColored(open and UI_TEXT or UI_MUTED, g.name);
        imgui.SameLine(w * 0.20);
        imgui.TextColored(UI_MUTED, g.where);
        imgui.SameLine(w * 0.50);
        if open then imgui.TextColored(GOOD, 'open, closes in ' .. span(secs));
        else imgui.TextColored(why == 'holiday' and WARN or BAD, (why == 'holiday' and 'holiday' or 'closed') .. ', opens in ' .. span(secs)); end
        imgui.SameLine(w * 0.78);
        imgui.TextColored(UI_MUTED, ('%02d-%02d, off %s'):fmt(g.open, g.close, VDAYS[g.holiday]));
    end
end

local DRAW = { today = draw_today, vana = draw_vana, earth = draw_earth, timers = draw_timers, events = draw_events, travel = draw_travel };

-- ============================================================================
-- Window
-- ============================================================================

function draw_calendar_window()
    if not state.visible[1] then
        if config.visible then config.visible = false; mark_dirty(); end
        state.apply_geometry = true;
        return;
    end
    local W = config.window;
    if state.apply_geometry then
        local x, y = tonumber(W.x) or -1, tonumber(W.y) or -1;
        if x < 0 or y < 0 then
            local io = imgui.GetIO();
            local dw = io and io.DisplaySize and tonumber(io.DisplaySize.x) or 1920;
            local dh = io and io.DisplaySize and tonumber(io.DisplaySize.y) or 1080;
            x, y = math.max(0, (dw - W.w) / 2), math.max(0, (dh - W.h) / 3);
        end
        imgui.SetNextWindowPos({ x, y });
        imgui.SetNextWindowSize({ W.w, W.h });
        state.apply_geometry = false;
    end
    imgui.SetNextWindowSizeConstraints({ 560, 380 }, { 4000, 4000 });
    push_theme();
    local flags = ImGuiWindowFlags_NoNav;
    if config.locked then flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoResize); end
    if imgui.Begin('MogSuite  -  Calendar##ms_calendar', state.visible, flags) then
        local scale = tonumber(config.font_scale) or 1.0;
        imgui.PushFont(MS_FONT(), MS_FONT_SIZE() * scale);
        for i, t in ipairs(TABS) do
            if i > 1 then imgui.SameLine(0, 4); end
            if color_tab(t.label, 'cal_tab_' .. t.key, config.tab == t.key, t.color) then config.tab = t.key; mark_dirty(); end
        end
        imgui.SameLine();
        local cw = text_w('Config') + 16;
        imgui.SetCursorPosX(math.max(imgui.GetCursorPosX(), imgui.GetWindowWidth() - cw - 12));
        if imgui.Button('Config##cal_cfg') then MS.open_config('calendar'); end
        imgui.Separator();
        begin_child('##cal_body', { 0, 0 }, 0);
        local ok, err = pcall(DRAW[config.tab] or draw_today);
        if not ok then imgui.TextColored(BAD, tostring(err)); end
        imgui.EndChild();
        imgui.PopFont();
        if not imgui.IsMouseDown(0) then
            local px, py = imgui.GetWindowPos();
            local sw, sh = imgui.GetWindowSize();
            px, py, sw, sh = tonumber(px), tonumber(py), tonumber(sw), tonumber(sh);
            if px ~= nil and (math.abs(px - (W.x or 0)) >= 1 or math.abs(py - (W.y or 0)) >= 1
                or math.abs(sw - (W.w or 0)) >= 1 or math.abs(sh - (W.h or 0)) >= 1) then
                W.x, W.y, W.w, W.h = px, py, sw, sh;
                mark_dirty();
            end
        end
    end
    imgui.End();
    pop_theme();
    if config.visible ~= true then config.visible = true; mark_dirty(); end
end

-- ============================================================================
-- Login summary and notices (small windows at the top of the screen)
-- ============================================================================

local function top_box(id, title, lines, until_t)
    local io = imgui.GetIO();
    local dw = io and io.DisplaySize and tonumber(io.DisplaySize.x) or 1920;
    imgui.SetNextWindowPos({ dw / 2, 90 }, ImGuiCond_Always or 1, { 0.5, 0 });
    push_theme();
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoFocusOnAppearing or 0);
    local close = false;
    if imgui.Begin(id, nil, flags) then
        imgui.PushFont(MS_FONT(), MS_FONT_SIZE() * (tonumber(config.font_scale) or 1.0) * 1.05);
        imgui.TextColored(UI_ACCENT_TEXT, title);
        imgui.SameLine();
        imgui.TextColored(UI_MUTED, ('  %ds'):fmt(math.max(0, math.ceil(until_t - os.clock()))));
        imgui.Separator();
        for _, l in ipairs(lines) do
            if type(l) == 'table' then imgui.TextColored(l[2] or UI_TEXT, l[1]); else imgui.TextColored(UI_TEXT, tostring(l)); end
        end
        imgui.Spacing();
        if imgui.SmallButton('OK##' .. id) then close = true; end
        imgui.SameLine();
        if imgui.SmallButton('Open Calendar##' .. id) then state.visible[1] = true; close = true; end
        imgui.PopFont();
    end
    imgui.End();
    pop_theme();
    return close;
end

function draw_popups()
    if state.login_lines ~= nil then
        if os.clock() > (state.login_until or 0) or top_box('##cal_login', 'WELCOME BACK', state.login_lines, state.login_until or 0) then
            state.login_lines = nil;
        end
    elseif state.toast ~= nil then
        if os.clock() > state.toast.until_t or top_box('##cal_toast', 'CALENDAR', state.toast.lines, state.toast.until_t) then
            state.toast = nil;
        end
    end
end
