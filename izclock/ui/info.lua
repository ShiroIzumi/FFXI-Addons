--[[
    IzClock - ui/info.lua

    Everything the clock knows, in two places:
      * the hover window: shown while the mouse is over the clock (or just
        the day); which sections it has is up to you (Hover & info page)
      * the info window: click the clock (without dragging) or /ic info.
        Three columns: Now / Moon / Crafting, This week / Guilds, Travel.

    Both use the same section drawers, so they always agree.
]]

require('common');
local imgui = require('imgui');
local theme = require('core.theme');
local uifont = require('uifont');
local vana = require('core.vana');
local schedule = require('core.schedule');

local info = {
    open = { false },
    placed = false,
};

function info.toggle()
    info.open[1] = not info.open[1];
    info.placed = false;
end

-- ============================================================================
-- Helpers
-- ============================================================================

local GOOD = { 0.45, 0.84, 0.52, 1.00 };     -- open / boarding
local WARN = { 0.95, 0.72, 0.34, 1.00 };     -- holiday / about to change
local CLOSED = { 0.86, 0.46, 0.46, 1.00 };   -- closed
local DEST = { 0.55, 0.78, 1.00, 1.00 };     -- where a ship is going

local function muted() return theme.UI_MUTED; end

local function day_color(c, i)
    local col = c.day_colors and c.day_colors[i + 1];
    if type(col) == 'table' then return col; end
    return vana.DAY_COLORS[i];
end

local function text_w(s)
    local w = imgui.CalcTextSize(tostring(s or ''));
    return tonumber(w) or 0;
end

-- One row of cells at fixed x offsets from where the row starts.
-- cells: { { text, color }, ... }; xs: x offset of each cell.
-- One row of cells at fixed x offsets from where the row starts.
-- cells: { { text, color }, ... } or a cell of several colored runs:
-- { runs = { { text, color }, ... } }. xs: x offset of each cell.
local function row(xs, cells)
    local x0 = imgui.GetCursorPosX();
    for i, cell in ipairs(cells) do
        if i > 1 then
            imgui.SameLine();
            imgui.SetCursorPosX(x0 + (xs[i] or 0));
        end
        if cell.runs then
            for j, r in ipairs(cell.runs) do
                if j > 1 then imgui.SameLine(0, 0); end
                imgui.TextColored(r[2] or theme.UI_TEXT, tostring(r[1] or ''));
            end
        else
            imgui.TextColored(cell[2] or theme.UI_TEXT, tostring(cell[1] or ''));
        end
    end
end

-- A faint band behind every other row (info window), so long lists are
-- easy to follow across. Call before drawing the row.
local function band(on)
    if not on then return; end
    local x, y = imgui.GetCursorScreenPos();
    x, y = tonumber(x) or 0, tonumber(y) or 0;
    local w = info.cur_w or (imgui.GetFontSize() * 20);
    local h = imgui.GetFontSize();
    imgui.GetWindowDrawList():AddRectFilled({ x - 4, y - 1 }, { x + w + 4, y + h + 2 },
        imgui.GetColorU32({ 1, 1, 1, 0.035 }), 3);
end

-- Width of the widest text in a list (+ a gap).
local function col_w(list, gap)
    local w = 0;
    for _, s in ipairs(list) do w = math.max(w, text_w(s)); end
    return w + (gap or imgui.GetFontSize());
end

-- Width of the column being drawn in the info window (measured last frame),
-- so section lines stop at the column's edge instead of crossing the window.
info.col_w = {};
info.cur_w = nil;

local function header(title, in_window)
    if in_window then
        imgui.Spacing();
        imgui.TextColored(theme.UI_ACCENT_TEXT, title);
        local x, y = imgui.GetCursorScreenPos();
        x, y = tonumber(x) or 0, tonumber(y) or 0;
        local w = info.cur_w or (imgui.GetFontSize() * 14);
        imgui.GetWindowDrawList():AddLine({ x, y }, { x + w, y }, imgui.GetColorU32(theme.accent(0.35)), 1);
        imgui.Dummy({ 1, 4 });
    else
        imgui.Spacing();
        imgui.TextColored(theme.UI_ACCENT_TEXT, title);
        imgui.Separator();
    end
end

-- Local time (or Japan time with jp = true) in the clock's 12/24h and seconds format.
local function fmt_time(c, jp)
    local f;
    if c.time24 then f = c.seconds and '%H:%M:%S' or '%H:%M';
    else f = c.seconds and '%I:%M:%S %p' or '%I:%M %p'; end
    local s;
    if jp then s = os.date('!' .. f, os.time() + 9 * 3600); else s = os.date(f); end
    if not c.time24 and s:sub(1, 1) == '0' then s = s:sub(2); end
    return s;
end

-- ============================================================================
-- Sections (c = the clock's settings, for formats and colors)
-- ============================================================================

local S = {};

function S.now(c, v, win)
    header('NOW', win);
    local el = schedule.ELEMENTS[v.day];
    local rows = {
        { 'Vana\'diel', { { ('%02d:%02d'):format(v.hour, v.minute), c.vana_color } } },
        { 'Day', { { vana.DAYS[v.day], day_color(c, v.day) }, { '  ' .. el.name, muted() } } },
        { 'Next day', { { vana.DAYS[v.next_day], day_color(c, v.next_day) },
            { '  in ' .. schedule.span(v.to_next) .. '  (' .. schedule.at_local(v.to_next, c.time24) .. ')', muted() } } },
        { 'Local', { { fmt_time(c, false), c.value_color } } },
        { 'Japan', { { fmt_time(c, true), c.value_color } } },
    };
    local lw = col_w({ 'Vana\'diel', 'Next day', 'Local', 'Japan', 'Day' });
    for _, r in ipairs(rows) do
        local x0 = imgui.GetCursorPosX();
        imgui.TextColored(muted(), r[1]);
        local x = lw;
        for _, cell in ipairs(r[2]) do
            imgui.SameLine();
            imgui.SetCursorPosX(x0 + x);
            imgui.TextColored(cell[2], cell[1]);
            x = x + text_w(cell[1]);
        end
    end
end

function S.week(c, v, win)
    header('THIS WEEK', win);
    local names = {};
    for i = 0, 7 do names[#names + 1] = '> ' .. vana.DAYS[i]; end
    local x1 = col_w(names);
    local x2 = x1 + col_w({ 'in 00h 00m' });
    for off = 0, 7 do
        local i = (v.day + off) % 8;
        if off == 0 then
            row({ 0, x1 }, { { '> ' .. vana.DAYS[i], day_color(c, i) }, { 'now', theme.UI_ACCENT_TEXT } });
        else
            local secs = v.to_next + (off - 1) * vana.DAY_SECS;
            row({ 0, x1, x2 }, {
                { '  ' .. vana.DAYS[i], day_color(c, i) },
                { 'in ' .. schedule.span(secs), theme.UI_TEXT },
                { schedule.at_local(secs, c.time24), muted() },
            });
        end
    end
end

function S.moon(c, v, win)
    header('MOON', win);
    imgui.TextColored(theme.UI_TEXT, v.moon_name);
    imgui.SameLine();
    imgui.TextColored(muted(), ('%d%%, %s'):format(v.moon_pct, v.moon_waxing and 'waxing' or 'waning'));
    local lw = col_w({ 'Full Moon', 'New Moon' });
    for _, p in ipairs({ { 4, 'Full Moon' }, { 0, 'New Moon' } }) do
        local now, secs = schedule.moon_next(v, p[1]);
        if now then
            row({ 0, lw }, { { p[2], muted() }, { 'now, ends in ' .. schedule.span(secs), GOOD } });
        else
            row({ 0, lw }, { { p[2], muted() }, { 'in ' .. schedule.span(secs) .. '  (' .. schedule.at_local(secs, c.time24) .. ')', theme.UI_TEXT } });
        end
    end
end

function S.craft(c, v, win)
    header('CRAFTING', win);
    local el = schedule.ELEMENTS[v.day];
    local lw = col_w({ 'Favored', 'Unfavored', 'Guilds off' });
    row({ 0, lw }, { { 'Favored', muted() }, { el.name .. ' crystals', day_color(c, v.day) } });
    row({ 0, lw }, { { 'Unfavored', muted() }, { el.beats .. ' crystals', theme.UI_TEXT } });
    local off = schedule.holiday_guilds(v.day);
    row({ 0, lw }, { { 'Guilds off', muted() }, { #off > 0 and table.concat(off, ', ') or 'none', #off > 0 and WARN or theme.UI_TEXT } });
end

function S.guilds(c, v, win)
    header('GUILDS', win);
    local names, hours = {}, {};
    for _, g in ipairs(schedule.GUILDS) do
        names[#names + 1] = g.name;
        hours[#hours + 1] = ('%d:00-%d:00'):format(g.open, g.close);
    end
    local x1 = col_w(names);
    local x2 = x1 + col_w(hours);
    for n, g in ipairs(schedule.GUILDS) do
        local open, secs, why = schedule.guild_status(g, v);
        local st;
        if open then
            local col = (secs <= 120) and WARN or GOOD;
            st = { runs = { { 'open', GOOD }, { '  closes in ', muted() }, { schedule.span(secs), col } } };
        elseif why == 'holiday' then
            st = { runs = { { 'holiday', WARN }, { '  opens in ', muted() }, { schedule.span(secs), theme.UI_TEXT } } };
        else
            st = { runs = { { 'closed', CLOSED }, { '  opens in ', muted() }, { schedule.span(secs), theme.UI_TEXT } } };
        end
        band(win and n % 2 == 0);
        row({ 0, x1, x2 }, { { g.name, open and theme.UI_TEXT or muted() }, { ('%d:00-%d:00'):format(g.open, g.close), muted() }, st });
        if win and imgui.IsItemHovered() then
            theme.tooltip(g.name .. ' guild, ' .. g.where .. '. Holiday: ' .. vana.DAYS[g.holiday] .. '.');
        end
    end
end

-- "Jeuno > San d'Oria": where from, a dim arrow, where to.
local function route_name(r)
    local from, to = r.name:match('^(.-) > (.+)$');
    if from == nil then return { runs = { { r.name, theme.UI_TEXT } } }; end
    return { runs = { { from, theme.UI_TEXT }, { '  >  ', muted() }, { to, DEST } } };
end

function S.travel(c, v, win, pick)
    header('TRAVEL', win);
    local raw = vana.raw();
    local names = {};
    for _, r in ipairs(schedule.ROUTES) do
        if pick == nil or pick[r.key] then names[#names + 1] = r.name:gsub(' > ', '  >  '); end
    end
    if #names == 0 then
        imgui.TextColored(muted(), 'No routes picked (settings, Hover & info).');
        return;
    end
    local x1 = col_w(names);
    local x2 = x1 + col_w({ 'boarding, leaves in 00m 00s' });
    local first_group = true;
    for _, grp in ipairs(schedule.GROUPS) do
        local first, n = true, 0;
        for _, r in ipairs(schedule.ROUTES) do
            if r.group == grp and (pick == nil or pick[r.key]) then
                if first then
                    if not first_group then imgui.Dummy({ 1, 2 }); end
                    imgui.TextColored(win and theme.UI_ACCENT_TEXT or muted(), grp:upper());
                    first, first_group = false, false;
                end
                n = n + 1;
                local st = schedule.route_status(r, raw);
                local status;
                if st.boarding then
                    status = { runs = { { 'boarding', GOOD }, { '  leaves in ', muted() }, { schedule.span(st.leaves), GOOD } } };
                else
                    local soon = st.arrives <= 60;
                    status = { runs = { { 'leaves in ', muted() }, { schedule.span(st.leaves), soon and WARN or theme.UI_TEXT } } };
                end
                band(win and n % 2 == 0);
                if win then
                    local docks = st.boarding and { '', muted() }
                        or { 'docks in ' .. schedule.span(st.arrives), (st.arrives <= 60) and WARN or muted() };
                    row({ 0, x1, x2 }, { route_name(r), status, docks });
                else
                    row({ 0, x1 }, { route_name(r), status });
                end
            end
        end
    end
end

info.S = S;

-- ============================================================================
-- Hover window
-- ============================================================================

-- cfg: all settings (cfg.hover says which sections); c: the hovered clock's.
function info.hover(cfg, c, v)
    local h = cfg.hover or {};
    local hs = tonumber(h.scale) or 1;
    theme.push(nil, hs, { border = true });
    uifont.push(hs);
    imgui.BeginTooltip();
    local any = false;
    local function sec(on, fn, ...)
        if on then fn(c, v, false, ...); any = true; end
    end
    sec(h.week ~= false, S.week);
    sec(h.moon ~= false, S.moon);
    sec(h.craft ~= false, S.craft);
    sec(h.guilds ~= false, S.guilds);
    sec(h.travel ~= false, S.travel, h.routes or schedule.DEFAULT_HOVER_ROUTES);
    if not any then imgui.TextColored(muted(), 'Nothing picked for the hover window.'); end
    imgui.Spacing();
    imgui.TextColored(muted(), 'Click the clock for everything.');
    imgui.EndTooltip();
    uifont.pop();
    theme.pop();
end

-- ============================================================================
-- Info window
-- ============================================================================

function info.draw(cfg, ctx)
    if not info.open[1] then return; end
    local s = tonumber(cfg.info_scale) or 1;
    local v = vana.now();
    local c = cfg;   -- formats and colors from the main clock

    -- Opens where it was last left; the first time, under the main clock.
    local pos = cfg.info_pos;
    if not info.placed then
        local px, py = tonumber(pos.x) or -1, tonumber(pos.y) or -1;
        if px < 0 or py < 0 then px, py = (tonumber(cfg.x) or 50), (tonumber(cfg.y) or 50) + 40; end
        imgui.SetNextWindowPos({ px, py });
        info.placed = true;
    end
    -- 3.2.0: its own opacity when it has one.
    local look = cfg.look and cfg.look.info or {};
    theme.push(look.own_alpha and theme.background(tonumber(look.alpha) or 0.97) or nil, s, { border = true });
    uifont.push(s);
    local flags = bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoCollapse or 0, ImGuiWindowFlags_NoSavedSettings or 0, ImGuiWindowFlags_NoNav or 0);
    if imgui.Begin('Vana\'diel##izclock_info', info.open, flags) then
        -- Big header: time, day, moon.
        local base = imgui.GetFontSize();
        imgui.PushFont(nil, base * 1.7);
        imgui.TextColored(c.vana_color, ('%02d:%02d'):format(v.hour, v.minute));
        imgui.SameLine(0, base);
        imgui.TextColored(day_color(c, v.day), vana.DAYS[v.day]);
        imgui.PopFont();
        imgui.SameLine(0, base);
        theme.align_label();
        imgui.TextColored(muted(), ('%s  %d%%'):format(v.moon_name, v.moon_pct));

        local gap = 28 * s;
        local cols = {
            function() S.now(c, v, true); S.moon(c, v, true); S.craft(c, v, true); end,
            function() S.week(c, v, true); S.guilds(c, v, true); end,
            function() S.travel(c, v, true, nil); end,
        };
        for i, fn in ipairs(cols) do
            if i > 1 then imgui.SameLine(0, gap); end
            info.cur_w = info.col_w[i];
            imgui.BeginGroup();
            fn();
            imgui.EndGroup();
            local w = imgui.GetItemRectSize();
            info.col_w[i] = tonumber(w) or info.col_w[i];
        end
        info.cur_w = nil;

        imgui.Spacing();
        imgui.TextColored(muted(), 'Times in brackets are your local time. Click the clock or /ic info to close.');

        -- Remember where it was moved to.
        local wx, wy = imgui.GetWindowPos();
        wx, wy = tonumber(wx), tonumber(wy);
        if wx ~= nil and wy ~= nil and not imgui.IsMouseDown(0)
            and (math.abs(wx - (tonumber(pos.x) or -1)) >= 1 or math.abs(wy - (tonumber(pos.y) or -1)) >= 1) then
            pos.x, pos.y = math.floor(wx), math.floor(wy);
            ctx.dirty(true);
        end
    end
    imgui.End();
    uifont.pop();
    theme.pop();
end

return info;
