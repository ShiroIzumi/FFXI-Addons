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

local function tint(c, a) return { c[1], c[2], c[3], a }; end
local function u32(c) return imgui.GetColorU32(c); end

-- Craft colors (same as the Crafting module).
local GUILD_COLORS = {
    Woodworking = COLORS.wind, Smithing = COLORS.fire, Goldsmithing = COLORS.light, Clothcraft = COLORS.ice,
    Leathercraft = COLORS.earth, Bonecraft = COLORS.dark, Alchemy = COLORS.thunder, Cooking = COLORS.water,
    Fishing = { 0.40, 0.86, 0.82, 1.0 },
};
local GROUP_COLORS = { Airships = COLORS.water, Ferry = COLORS.ice, Manaclipper = COLORS.wind, Barge = COLORS.earth };
local GROUP_NOTES = {
    Airships = 'Needs an airship pass.', Ferry = 'Selbina and Mhaura, about 10 min a crossing.',
    Manaclipper = 'Bibiki Bay (Purgonorgo Isle and the tour).', Barge = 'Phanauet Channel.',
};

-- Section header: a colored bar, the title and a faint line to the right.
local function header(title, col, note)
    col = col or UI_ACCENT_TEXT;
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    local w = avail_w();
    local h = lh();
    dl:AddRectFilled({ x, y + 1 }, { x + 3, y + h - 1 }, u32(col), 1.0);
    dl:AddText({ x + 9, y }, u32(col), title);
    local tx = x + 9 + text_w(title) + 10;
    if note ~= nil then
        dl:AddText({ tx, y }, u32(UI_MUTED), note);
        tx = tx + text_w(note) + 10;
    end
    if tx < x + w then dl:AddRectFilled({ tx, y + h / 2 }, { x + w, y + h / 2 + 1 }, u32(tint(col, 0.22)), 0); end
    imgui.Dummy({ w, h + 3 });
end

-- A soft stripe behind the row that starts at the cursor (every other row).
local function row_bg(i, extra)
    if i % 2 == 0 then return; end
    local x, y = imgui.GetCursorScreenPos();
    imgui.GetWindowDrawList():AddRectFilled({ x - 4, y - 1 }, { x + avail_w(), y + lh() + 1 + (extra or 0) }, u32({ 1, 1, 1, 0.03 }), 3.0);
end

-- Small rounded label with a tinted back.
local function pill(text, col)
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    local tw = text_w(text);
    dl:AddRectFilled({ x, y }, { x + tw + 12, y + lh() }, u32(tint(col, 0.18)), lh() / 2);
    dl:AddText({ x + 6, y }, u32(col), text);
    imgui.Dummy({ tw + 12, lh() });
end

-- Thin progress bar at the cursor (w wide), sits in the middle of a text line.
local function mini_bar(w, frac, col)
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    local h = math.max(4, math.floor(lh() * 0.30));
    local yy = y + (lh() - h) / 2;
    frac = math.max(0, math.min(1, frac or 0));
    dl:AddRectFilled({ x, yy }, { x + w, yy + h }, u32({ 1, 1, 1, 0.07 }), h / 2);
    if frac > 0 then dl:AddRectFilled({ x, yy }, { x + math.max(h, w * frac), yy + h }, u32(tint(col, 0.85)), h / 2); end
    imgui.Dummy({ w, lh() });
end

-- Tinted button in one color (thin outline in that color).
local function color_button(label, id, col, size)
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 4.0);
    imgui.PushStyleColor(ImGuiCol_Button, tint(col, 0.14));
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, tint(col, 0.28));
    imgui.PushStyleColor(ImGuiCol_ButtonActive, tint(col, 0.40));
    imgui.PushStyleColor(ImGuiCol_Text, { math.min(1, col[1] * 0.35 + 0.65), math.min(1, col[2] * 0.35 + 0.65), math.min(1, col[3] * 0.35 + 0.65), 1 });
    local clicked;
    if size ~= nil then clicked = imgui.Button(label .. '##' .. id, size); else clicked = imgui.Button(label .. '##' .. id); end
    local hovered = imgui.IsItemHovered();
    imgui.PopStyleColor(4);
    imgui.PopStyleVar(1);
    if imgui.GetItemRectMin ~= nil then
        local x1, y1 = imgui.GetItemRectMin();
        local x2, y2 = imgui.GetItemRectMax();
        x1, y1, x2, y2 = tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2);
        if x1 and y1 and x2 and y2 then
            imgui.GetWindowDrawList():AddRect({ x1, y1 }, { x2, y2 }, u32(tint(col, hovered and 0.75 or 0.40)), 4.0, 0, 1.0);
        end
    end
    return clicked;
end

-- Where a ship is in its run: 0..1 toward docking (at sea) or leaving (boarding).
local function route_frac(r, st)
    local run = r.runs[1];
    local dock = (run[2] - run[1]) % r.every;
    if st.boarding then return 1 - st.leaves / math.max(1, dock); end
    local sea = math.max(1, r.every / #r.runs - dock);
    return 1 - st.arrives / math.max(sea, st.arrives);
end

-- ============================================================================
-- Today
-- ============================================================================

local function draw_today()
    local v = vana_at();
    local now = os.time();
    local scale = tonumber(config.font_scale) or 1;
    local dl = imgui.GetWindowDrawList();
    local col = VDAY_COLORS[v.weekday];

    -- Header: a panel tinted with the day's element.
    local big = imgui.GetFontSize() * 1.9;
    local hh = big + lh() * 1.4 + 18;
    local x, y = imgui.GetCursorScreenPos();
    local W = avail_w();
    local ok = pcall(function()
        dl:AddRectFilledMultiColor({ x, y }, { x + W, y + hh }, u32(tint(col, 0.20)), u32(tint(col, 0.03)), u32(tint(col, 0.03)), u32(tint(col, 0.14)));
    end);
    if not ok then dl:AddRectFilled({ x, y }, { x + W, y + hh }, u32(tint(col, 0.10)), 6.0); end
    dl:AddRectFilled({ x, y }, { x + 4, y + hh }, u32(col), 2.0);
    dl:AddRect({ x, y }, { x + W, y + hh }, u32(tint(col, 0.30)), 6.0, 0, 1.0);
    local px, py = x + 16, y + 8;
    local t = ('%02d:%02d'):format(v.hour, v.minute);
    dl:AddText(imgui.GetFont(), big, { px, py }, u32(UI_TEXT), t);
    local tw = text_w(t) * 1.9;
    dl:AddText(imgui.GetFont(), imgui.GetFontSize() * 1.25, { px + tw + 16, py + 1 }, u32(col), VDAYS[v.weekday]);
    dl:AddText({ px + tw + 16, py + big * 0.62 }, u32(UI_MUTED),
        ("Vana'diel %d/%d/%d  -  next day in %s"):fmt(v.year, v.month, v.day, span(v.to_next)));
    -- How far into the day (thin bar under the clock).
    local frac = 1 - (v.to_next / VDAY);
    local by = py + big + 6;
    dl:AddRectFilled({ px, by }, { px + tw, by + 3 }, u32({ 1, 1, 1, 0.08 }), 1.5);
    dl:AddRectFilled({ px, by }, { px + tw * math.max(0, math.min(1, frac)), by + 3 }, u32(col), 1.5);
    -- Element line.
    local ey = by + 8;
    local ex = px;
    dl:AddText({ ex, ey }, u32(col), VDAY_SHORT[v.weekday]);
    ex = ex + text_w(VDAY_SHORT[v.weekday]);
    dl:AddText({ ex, ey }, u32(UI_MUTED), ' element, strong against ');
    ex = ex + text_w(' element, strong against ');
    local beats_col = COLORS[({ Ice = 'ice', Lightning = 'thunder', Fire = 'fire', Earth = 'earth', Wind = 'wind', Water = 'water', Dark = 'dark', Light = 'light' })[VDAY_BEATS[v.weekday]]] or UI_TEXT;
    dl:AddText({ ex, ey }, u32(beats_col), VDAY_BEATS[v.weekday]);
    ex = ex + text_w(VDAY_BEATS[v.weekday]);
    dl:AddText({ ex, ey }, u32(UI_MUTED), ('.   Earth time %s'):fmt(os.date(config.time24 and '%H:%M' or '%I:%M %p')));
    -- Moon.
    local mr = big * 0.46;
    local mx = x + W - mr - 16;
    local my = y + hh / 2;
    dl:AddCircleFilled({ mx, my }, mr + 5, u32({ 0.96, 0.94, 0.80, 0.06 }), 28);
    draw_moon(dl, mx, my, mr, v.moon_pct, v.moon_waxing);
    local ml = v.moon_name;
    local mp = ('%d%%'):fmt(v.moon_pct);
    dl:AddText({ mx - mr - 14 - text_w(ml), my - lh() }, u32({ 0.96, 0.94, 0.80, 1 }), ml);
    dl:AddText({ mx - mr - 14 - text_w(mp), my }, u32(UI_MUTED), mp);
    imgui.Dummy({ W, hh + 6 });

    local half = (avail_w() - 10) / 2;
    imgui.BeginGroup();
    begin_child('##caltoday_l', { half, 0 }, 0);

    -- Coming up.
    header('COMING UP', COLORS.light);
    local row = 0;
    if config.conquest.enabled ~= false then
        local c = next_conquest(now);
        row_bg(row);
        pair('Conquest results', ('in %s'):fmt(span(c - now)), COLORS.earth, half * 0.50);
        if imgui.IsItemHovered() then imgui.SetTooltip(when_at(c)); end
        row = row + 1;
    end
    local items = items_between(now, now + 7 * 86400);
    local shown = 0;
    for _, it in ipairs(items) do
        if it.kind ~= 'conquest' and shown < 8 then
            shown = shown + 1;
            row_bg(row);
            row = row + 1;
            local cx, cy = imgui.GetCursorScreenPos();
            imgui.GetWindowDrawList():AddCircleFilled({ cx + 4, cy + lh() / 2 }, 3, u32(it.color), 10);
            imgui.SetCursorPosX(imgui.GetCursorPosX() + 12);
            imgui.TextColored(UI_TEXT, it.title);
            imgui.SameLine(half * 0.50);
            imgui.TextColored(it.color, 'in ' .. span(it.t - now));
            if imgui.IsItemHovered() then imgui.SetTooltip(when_at(it.t)); end
        end
    end
    if shown == 0 then imgui.TextDisabled('No events or timers this week.'); end
    imgui.Spacing();

    -- Timers.
    header('TIMERS', COLORS.wind);
    if #(config.timers or {}) == 0 then imgui.TextDisabled('None yet (Timers tab).'); end
    for i, tm in ipairs(config.timers or {}) do
        local st, left = timer_status(tm);
        row_bg(i);
        imgui.TextColored(UI_TEXT, tm.name);
        imgui.SameLine(half * 0.50);
        if st == 'ready' then
            pill('Ready', GOOD);
        elseif st == 'waiting' then
            local total = math.max(1, (tonumber(tm.hours) or 1) * 3600);
            mini_bar(half * 0.18, 1 - left / total, WARN);
            imgui.SameLine(0, 8);
            imgui.TextColored(WARN, span(left));
        else
            imgui.TextColored(UI_MUTED, 'not started');
        end
    end
    imgui.Spacing();

    -- The next Vana'diel days.
    header('NEXT DAYS', COLORS.water);
    for k = 1, 8 do
        local td = v.total_days + k;
        local wd = td % 8;
        local start = vday_start(td);
        local name, pct, _, waxing = moon_of(td);
        row_bg(k);
        local cx, cy = imgui.GetCursorScreenPos();
        local d2 = imgui.GetWindowDrawList();
        d2:AddRectFilled({ cx, cy + 3 }, { cx + 6, cy + lh() - 3 }, u32(VDAY_COLORS[wd]), 2.0);
        imgui.SetCursorPosX(imgui.GetCursorPosX() + 12);
        imgui.TextColored(VDAY_COLORS[wd], VDAYS[wd]);
        imgui.SameLine(half * 0.36);
        imgui.TextColored(UI_TEXT, clock_at(start));
        imgui.SameLine(half * 0.58);
        local mx2, my2 = imgui.GetCursorScreenPos();
        local r = lh() * 0.36;
        draw_moon(d2, mx2 + r, my2 + lh() / 2, r, pct, waxing);
        imgui.SetCursorPosX(imgui.GetCursorPosX() + r * 2 + 6);
        imgui.TextColored(UI_MUTED, ('%s %d%%'):fmt(name, pct));
    end
    imgui.EndChild();
    imgui.EndGroup();

    imgui.SameLine(0, 10);
    begin_child('##caltoday_r', { 0, 0 }, 0);
    local rw = avail_w();
    header('GUILDS', COLORS.earth);
    for i, g in ipairs(GUILDS) do
        local open, secs, why = guild_status(g, v);
        local gc = GUILD_COLORS[g.name] or UI_TEXT;
        row_bg(i);
        local cx, cy = imgui.GetCursorScreenPos();
        imgui.GetWindowDrawList():AddCircleFilled({ cx + 4, cy + lh() / 2 }, 3.5, u32(open and gc or tint(gc, 0.45)), 10);
        imgui.SetCursorPosX(imgui.GetCursorPosX() + 12);
        imgui.TextColored(open and gc or UI_MUTED, g.name);
        imgui.SameLine(rw * 0.40);
        if open then
            pill('open', GOOD);
            imgui.SameLine(0, 8);
            imgui.TextColored(UI_MUTED, 'closes in ' .. span(secs));
        else
            pill(why == 'holiday' and 'holiday' or 'closed', why == 'holiday' and WARN or BAD);
            imgui.SameLine(0, 8);
            imgui.TextColored(UI_MUTED, 'opens in ' .. span(secs));
        end
        if imgui.IsItemHovered() then imgui.SetTooltip(('%s  -  %02d:00 to %02d:00, closed on %s'):fmt(g.where, g.open, g.close, VDAYS[g.holiday])); end
    end
    imgui.Spacing();
    header('NEXT SHIPS', COLORS.ice);
    local raw = vraw();
    local n = 0;
    for _, r in ipairs(ROUTES) do
        if r.group == 'Airships' or r.group == 'Ferry' then
            n = n + 1;
            local st = route_status(r, raw);
            local gc = GROUP_COLORS[r.group] or UI_ACCENT;
            row_bg(n);
            imgui.TextColored(UI_TEXT, r.name);
            imgui.SameLine(rw * 0.44);
            mini_bar(rw * 0.12, route_frac(r, st), st.boarding and GOOD or gc);
            imgui.SameLine(0, 8);
            if st.boarding then
                pill('boarding', GOOD);
                imgui.SameLine(0, 6);
                imgui.TextColored(UI_MUTED, 'leaves in ' .. span(st.leaves));
            else
                imgui.TextColored(UI_MUTED, 'docks in ');
                imgui.SameLine(0, 0);
                imgui.TextColored(st.arrives < 120 and WARN or UI_TEXT, span(st.arrives));
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
    align_label();
    imgui.TextColored(UI_ACCENT_TEXT, ("Vana'diel  %d / %02d"):fmt(year, month));
    imgui.SameLine();
    imgui.TextColored(UI_MUTED, ('  %s  to  %s'):fmt(when_at(vday_start(first)), when_at(vday_start(first + 30) - 60)));
    imgui.Spacing();

    -- 8 columns, one per weekday; the 1st sits under its own weekday.
    local GAP = 6;
    local PAD = 8;
    local w = avail_w();
    local cw = (w - 7 * GAP) / 8;
    local ch = math.max(lh() * 3 + PAD * 2 + 2, cw * 0.55);
    local dl = imgui.GetWindowDrawList();
    local x0, y0 = imgui.GetCursorScreenPos();
    local top = y0;
    for wd = 0, 7 do
        local hx = x0 + wd * (cw + GAP);
        dl:AddRectFilled({ hx, y0 + lh() + 3 }, { hx + cw, y0 + lh() + 5 }, u32(tint(VDAY_COLORS[wd], 0.55)), 1.0);
        dl:AddText({ hx + PAD, y0 }, u32(VDAY_COLORS[wd]), VDAYS[wd]);
    end
    y0 = y0 + lh() + 10;
    local lead = first % 8;
    local rows = math.ceil((lead + 30) / 8);
    local mx, my = imgui.GetMousePos();
    local hovered = nil;
    for i = 0, 29 do
        local td = first + i;
        local slot = lead + i;
        local cx = x0 + (slot % 8) * (cw + GAP);
        local cy = y0 + math.floor(slot / 8) * (ch + GAP);
        local wd = td % 8;
        local c = VDAY_COLORS[wd];
        local is_now = (td == v.total_days);
        local past = td < v.total_days;
        local mxn, myn = tonumber(mx) or -1, tonumber(my) or -1;
        local hov = mxn >= cx and mxn <= cx + cw and myn >= cy and myn <= cy + ch and imgui.IsWindowHovered();
        dl:AddRectFilled({ cx, cy }, { cx + cw, cy + ch }, u32(tint(c, past and 0.05 or (hov and 0.22 or 0.13))), 5.0);
        dl:AddRectFilled({ cx, cy }, { cx + 3, cy + ch }, u32(tint(c, past and 0.25 or 0.70)), 2.0);
        if is_now then
            dl:AddRect({ cx - 1, cy - 1 }, { cx + cw + 1, cy + ch + 1 }, u32(tint(c, 0.35)), 6.0, 0, 4.0);
            dl:AddRect({ cx, cy }, { cx + cw, cy + ch }, u32(c), 5.0, 0, 2.0);
        end
        dl:AddText({ cx + PAD, cy + PAD - 2 }, u32(past and UI_MUTED or (is_now and c or UI_TEXT)), tostring(i + 1));
        local start = vday_start(td);
        dl:AddText({ cx + PAD, cy + PAD - 2 + lh() }, u32(UI_MUTED), os.date('%a ', start) .. clock_at(start));
        if config.show.moon ~= false then
            local _, pct, phase, waxing = moon_of(td);
            local r = lh() * 0.42;
            draw_moon(dl, cx + cw - r - PAD, cy + r + PAD - 1, r, pct, waxing);
            if phase == 4 or phase == 0 then
                dl:AddText({ cx + PAD, cy + PAD - 2 + lh() * 2 }, u32({ 0.96, 0.94, 0.80, past and 0.5 or 1 }), (phase == 4) and 'Full moon' or 'New moon');
            end
        end
        if config.show.holidays ~= false and #holiday_guilds(wd) > 0 then
            dl:AddCircleFilled({ cx + cw - PAD, cy + ch - PAD }, 3, u32(WARN), 8);
        end
        if hov then hovered = td; end
    end
    imgui.Dummy({ w, (y0 - top) + rows * (ch + GAP) });
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
    imgui.Spacing();
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

local PRESET_COLORS = { COLORS.dark, COLORS.thunder, COLORS.earth, COLORS.fire, COLORS.water, COLORS.wind, COLORS.light };

local function draw_timers()
    imgui.TextColored(UI_MUTED, 'Add one, then click Start when you do the thing (enter Dynamis, get the key item...). It counts down to Ready.');
    imgui.Spacing();
    -- Add buttons (wrap when the window is narrow).
    local line_x = imgui.GetCursorPosX();
    local line_w = avail_w();
    align_label();
    imgui.TextColored(UI_ACCENT_TEXT, 'ADD');
    for i, p in ipairs(TIMER_PRESETS) do
        local label = '+  ' .. p.name;
        local bw = text_w(label) + 20;
        imgui.SameLine(0, 6);
        if imgui.GetCursorPosX() + bw > line_x + line_w then imgui.NewLine(); end
        if color_button(label, 'caltp' .. i, PRESET_COLORS[i] or UI_ACCENT, { bw, 0 }) then add_timer(p); end
        if imgui.IsItemHovered() then imgui.SetTooltip(('%s  -  %g hours\n%s'):fmt(p.name, p.hours, p.note or '')); end
    end
    imgui.Spacing();
    imgui.Separator();
    imgui.Spacing();

    local list = config.timers or {};
    if #list == 0 then imgui.TextDisabled('No timers yet.'); end
    local dl = imgui.GetWindowDrawList();
    local fh = imgui.GetFrameHeight();
    local PAD = 8;
    local remove = nil;
    for i, tm in ipairs(list) do
        imgui.PushID('caltm' .. tostring(tm.id));
        local st, left = timer_status(tm);
        local col = (st == 'ready') and GOOD or ((st == 'waiting') and WARN or UI_MUTED);
        local has_note = tm.note ~= nil and tm.note ~= '';
        local row_h = PAD * 2 + fh + (has_note and (lh() + 4) or 0);
        local x, y = imgui.GetCursorScreenPos();
        local w = avail_w();

        -- Card.
        dl:AddRectFilled({ x, y }, { x + w, y + row_h }, u32({ 1, 1, 1, 0.035 }), 6.0);
        dl:AddRect({ x, y }, { x + w, y + row_h }, u32(tint(col, 0.25)), 6.0, 0, 1.0);
        dl:AddRectFilled({ x, y }, { x + 4, y + row_h }, u32(col), 2.0);
        imgui.SetCursorScreenPos({ x + PAD + 6, y + PAD });

        -- Name.
        local name = { tostring(tm.name or '') };
        imgui.PushItemWidth(math.max(120, w * 0.24));
        if imgui.InputText('##name', name, 48) then tm.name = name[1]; mark_dirty(); end
        imgui.PopItemWidth();

        -- Hours: [-] [ 168.0 h ] [+]
        imgui.SameLine(0, 12);
        if color_button('-', 'hdn', UI_ACCENT, { fh, fh }) then tm.hours = math.max(1, math.floor((tonumber(tm.hours) or 1) - 1 + 0.5)); mark_dirty(); end
        if imgui.IsItemHovered() then imgui.SetTooltip('1 hour less'); end
        imgui.SameLine(0, 3);
        local hrs = { tonumber(tm.hours) or 1 };
        imgui.PushItemWidth(text_w('9999.9 h') + 14);
        if imgui.InputFloat('##hours', hrs, 0, 0, '%.1f h') then tm.hours = math.max(0.1, hrs[1]); mark_dirty(); end
        imgui.PopItemWidth();
        if imgui.IsItemHovered() then imgui.SetTooltip('Length in Earth hours (type a number).'); end
        imgui.SameLine(0, 3);
        if color_button('+', 'hup', UI_ACCENT, { fh, fh }) then tm.hours = math.floor((tonumber(tm.hours) or 0) + 1 + 0.5); mark_dirty(); end
        if imgui.IsItemHovered() then imgui.SetTooltip('1 hour more'); end

        -- Buttons on the right; the bar takes the room between.
        local b1 = (st == 'idle') and 'Start' or 'Restart';
        local armed = (state.confirm['tm' .. tm.id] or 0) > os.clock();
        local b3 = armed and 'Sure?' or 'X';
        local w1 = text_w('Restart') + 20;
        local w2 = text_w('Clear') + 20;
        local w3 = text_w('Sure?') + 16;
        imgui.SameLine(0, 12);
        local bx, by = imgui.GetCursorScreenPos();
        local bw = (x + w - PAD) - bx - (w1 + w2 + w3 + 3 * 6);
        bw = math.max(80, bw);
        local frac, label = 0, 'Not started';
        if st == 'ready' then frac, label = 1, 'Ready';
        elseif st == 'waiting' then
            local total = math.max(1, (tonumber(tm.hours) or 1) * 3600);
            frac = 1 - left / total;
            label = ('%s left  -  %s'):fmt(span(left), when_at(timer_ready_at(tm)));
        end
        frac = math.max(0, math.min(1, frac));
        dl:AddRectFilled({ bx, by }, { bx + bw, by + fh }, u32({ 0, 0, 0, 0.35 }), 4.0);
        if frac > 0 then dl:AddRectFilled({ bx, by }, { bx + math.max(8, bw * frac), by + fh }, u32(tint(col, 0.30)), 4.0); end
        dl:AddRect({ bx, by }, { bx + bw, by + fh }, u32(tint(col, 0.35)), 4.0, 0, 1.0);
        local lab = label;
        while #lab > 3 and text_w(lab) > bw - 16 do lab = lab:sub(1, #lab - 2); end
        if lab ~= label then lab = lab .. '..'; end
        dl:AddText({ bx + 8, by + (fh - lh()) / 2 }, u32(st == 'idle' and UI_MUTED or col), lab);
        imgui.Dummy({ bw, fh });
        if lab ~= label and imgui.IsItemHovered() then imgui.SetTooltip(label); end

        imgui.SameLine(0, 6);
        if color_button(b1, 'start', GOOD, { w1, fh }) then start_timer(tm); end
        if imgui.IsItemHovered() then imgui.SetTooltip('Starts counting now.'); end
        imgui.SameLine(0, 6);
        if st ~= 'idle' then
            if imgui.Button('Clear', { w2, fh }) then tm.started = 0; mark_dirty(); end
        else
            imgui.Dummy({ w2, fh });
        end
        imgui.SameLine(0, 6);
        if color_button(b3, 'del', BAD, { w3, fh }) then
            if armed then remove = i; else state.confirm['tm' .. tm.id] = os.clock() + 3; end
        end
        if imgui.IsItemHovered() then imgui.SetTooltip('Delete this timer (click twice).'); end

        if has_note then
            imgui.SetCursorScreenPos({ x + PAD + 6, y + PAD + fh + 4 });
            imgui.TextColored(UI_MUTED, tm.note);
        end
        imgui.SetCursorScreenPos({ x, y + row_h });
        imgui.Dummy({ w, 6 });
        imgui.PopID();
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
        local gc = GROUP_COLORS[grp] or UI_ACCENT;
        header(grp:upper(), gc, GROUP_NOTES[grp]);
        local n = 0;
        for _, r in ipairs(ROUTES) do
            if r.group == grp then
                n = n + 1;
                local st = route_status(r, raw);
                row_bg(n);
                local cx, cy = imgui.GetCursorScreenPos();
                imgui.GetWindowDrawList():AddRectFilled({ cx, cy + 3 }, { cx + 3, cy + lh() - 3 }, u32(st.boarding and GOOD or tint(gc, 0.6)), 1.0);
                imgui.SetCursorPosX(imgui.GetCursorPosX() + 10);
                imgui.TextColored(st.boarding and UI_TEXT or { 0.86, 0.86, 0.88, 1 }, r.name);
                imgui.SameLine(w * 0.34);
                if st.boarding then pill('boarding', GOOD); else pill('at sea', gc); end
                imgui.SameLine(w * 0.46);
                mini_bar(w * 0.14, route_frac(r, st), st.boarding and GOOD or gc);
                imgui.SameLine(w * 0.64);
                if st.boarding then
                    imgui.TextColored(UI_MUTED, 'leaves in ');
                    imgui.SameLine(0, 0);
                    imgui.TextColored(st.leaves < 60 and BAD or GOOD, span(st.leaves));
                else
                    imgui.TextColored(UI_MUTED, 'docks in ');
                    imgui.SameLine(0, 0);
                    imgui.TextColored(st.arrives < 120 and WARN or UI_TEXT, span(st.arrives));
                    imgui.SameLine(0, 0);
                    imgui.TextColored(UI_MUTED, ',  leaves in ' .. span(st.leaves));
                end
            end
        end
        imgui.Spacing();
    end
    local v = vana_at();
    header('GUILDS', COLORS.earth, 'Vana\'diel hours, closed one day a week.');
    for i, g in ipairs(GUILDS) do
        local open, secs, why = guild_status(g, v);
        local gc = GUILD_COLORS[g.name] or UI_TEXT;
        row_bg(i);
        local cx, cy = imgui.GetCursorScreenPos();
        imgui.GetWindowDrawList():AddCircleFilled({ cx + 4, cy + lh() / 2 }, 3.5, u32(open and gc or tint(gc, 0.45)), 10);
        imgui.SetCursorPosX(imgui.GetCursorPosX() + 12);
        imgui.TextColored(open and gc or tint(gc, 0.70), g.name);
        imgui.SameLine(w * 0.18);
        imgui.TextColored(UI_MUTED, g.where);
        imgui.SameLine(w * 0.40);
        if open then
            pill('open', GOOD);
            imgui.SameLine(0, 8);
            imgui.TextColored(UI_MUTED, 'closes in ' .. span(secs));
        else
            pill(why == 'holiday' and 'holiday' or 'closed', why == 'holiday' and WARN or BAD);
            imgui.SameLine(0, 8);
            imgui.TextColored(UI_MUTED, 'opens in ' .. span(secs));
        end
        imgui.SameLine(w * 0.70);
        imgui.TextColored(UI_TEXT, ('%02d:00 - %02d:00'):fmt(g.open, g.close));
        imgui.SameLine(0, 12);
        imgui.TextColored(UI_MUTED, 'off');
        imgui.SameLine(0, 4);
        imgui.TextColored(VDAY_COLORS[g.holiday], VDAYS[g.holiday]);
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
