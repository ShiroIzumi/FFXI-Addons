--[[
    WhatsMyDamage - ui/meter.lua

    The meter windows (up to 3), drawn like Details!: a header with the
    mode's title and small icon buttons, then one colored bar per player:

        [icon] 1. Name ..................... 12,345 (35.2%)

    Each window shows one mode (Damage Done, Healing Done, Damage Taken).

    Moving and snapping:
      * drag a window by its header to move it
      * drop it next to another window's edge and it snaps there (a glowing
        line shows where); snapped windows move together, whichever one you
        drag
      * Ctrl + drag pulls a window out of its group; the chain icon in the
        header unsnaps it too
      * drag the bottom-right corner to change the width (snapped windows
        above / below each other share the width, if that's on)

    Rows: hover for the breakdown, click for the full details window,
    mouse wheel to scroll (fixed size). Bars slide to their new length and
    rows slide to their new place when the ranking changes.
]]

require('common');
local imgui = require('imgui');
local theme = require('core.theme');
local data = require('core.data');
local fonts = require('core.fonts');
local icons = require('core.icons');
local tracker = require('core.tracker');
local styles = require('ui.styles');
local detail = require('ui.detail');
local report = require('ui.report');

local meter = {
    st = { {}, {}, {} },     -- per window runtime state
    rects = {},              -- [i] = { x, y, w, h } this frame
    drag = nil,              -- { win, root, mx, my, ox, oy, detach }
    resize = nil,            -- { win, mx, w }
    reset_armed = {},        -- [i] = os.clock() when armed
    preview = nil,           -- snap preview { x1, y1, x2, y2 }
};

local function U32(c) return imgui.GetColorU32(c); end

-- ============================================================================
-- Numbers and colors
-- ============================================================================

local function commas(n)
    local s = tostring(math.floor(n + 0.5));
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse();
    if out:sub(1, 1) == ',' then out = out:sub(2); end
    return out;
end

function meter.num(cfg, n)
    n = tonumber(n) or 0;
    if cfg.numbers == 'short' then
        if n >= 1000000 then return ('%.2fM'):format(n / 1000000); end
        if n >= 10000 then return ('%.1fK'):format(n / 1000); end
    end
    return commas(n);
end

function meter.job_color(cfg, job)
    local c = cfg.job_colors and cfg.job_colors[job or ''];
    if type(c) == 'table' then return c; end
    return data.JOB_COLORS[job or ''] or data.UNKNOWN_COLOR;
end

local function bar_color(cfg, row)
    local b = cfg.bars;
    if b.color_by == 'single' then return b.single; end
    if row.pet then
        if b.pet_owner_color then
            local c = meter.job_color(cfg, row.job);
            return { c[1] * 0.70, c[2] * 0.70, c[3] * 0.70, c[4] or 1 };
        end
        return b.pet_color or data.PET_COLOR;
    end
    return meter.job_color(cfg, row.job);
end
meter.bar_color = bar_color;

-- ============================================================================
-- Layout: sizes, then positions (snapping)
-- ============================================================================

local function header_h(cfg) return cfg.header.show and (tonumber(cfg.header.height) or 24) * (cfg.scale or 1) or 0; end
local function row_h(cfg) return (tonumber(cfg.bars.height) or 22) * (cfg.scale or 1); end
local function row_gap(cfg) return (tonumber(cfg.bars.spacing) or 1) * (cfg.scale or 1); end
local function pad(cfg) return (tonumber(cfg.padding) or 2) * (cfg.scale or 1); end

local function visible_rows(cfg, w, n)
    if w.size == 'fixed' then return math.max(1, math.floor(tonumber(w.rows) or 8)); end
    local cap = math.floor(tonumber(w.max_rows) or 0);
    n = math.max(1, n);
    if cap > 0 then n = math.min(n, cap); end
    return n;
end

local function height_of(cfg, w, n)
    local rows = visible_rows(cfg, w, n);
    return header_h(cfg) + pad(cfg) * 2 + rows * row_h(cfg) + math.max(0, rows - 1) * row_gap(cfg);
end

local function enabled(cfg, i)
    local w = cfg.windows[i];
    return w ~= nil and w.enabled == true;
end

-- The window this one is snapped to (only if that one is shown).
local function parent_of(cfg, i)
    local w = cfg.windows[i];
    local p = tonumber(w.snap_to) or 0;
    if p >= 1 and p <= 3 and p ~= i and enabled(cfg, p) then return p; end
    return nil;
end

function meter.root_of(cfg, i)
    local seen = {};
    while true do
        if seen[i] then return i; end
        seen[i] = true;
        local p = parent_of(cfg, i);
        if p == nil then return i; end
        i = p;
    end
end

-- Width: snapped above / below shares the parent's width when "match width" is on.
local function width_of(cfg, i, depth)
    depth = depth or 0;
    local w = cfg.windows[i];
    local p = parent_of(cfg, i);
    if p ~= nil and depth < 4 and cfg.snap_match ~= false and (w.snap_side == 'below' or w.snap_side == 'above') then
        return width_of(cfg, p, depth + 1);
    end
    return math.max(140, tonumber(w.w) or 300) * 1.0;
end

-- Fills meter.rects for every enabled window.
local function layout(cfg, heights)
    local rects, done = {}, {};
    local gap = tonumber(cfg.snap_gap) or 2;
    local function place(i, depth)
        if done[i] then return rects[i]; end
        if depth > 4 then return nil; end
        local w = cfg.windows[i];
        local width, h = width_of(cfg, i), heights[i];
        local p = parent_of(cfg, i);
        local r;
        if p ~= nil then
            local pr = place(p, depth + 1);
            if pr ~= nil then
                local side = w.snap_side;
                if side == 'above' then r = { x = pr.x, y = pr.y - h - gap, w = width, h = h };
                elseif side == 'right' then r = { x = pr.x + pr.w + gap, y = pr.y, w = width, h = h };
                elseif side == 'left' then r = { x = pr.x - width - gap, y = pr.y, w = width, h = h };
                else r = { x = pr.x, y = pr.y + pr.h + gap, w = width, h = h }; end
            end
        end
        if r == nil then
            local x = tonumber(w.x) or 300;
            local y = tonumber(w.y) or 300;
            if w.grow == 'up' then y = y - h; end   -- y is the bottom edge
            r = { x = x, y = y, w = width, h = h };
        end
        rects[i] = r;
        done[i] = true;
        return r;
    end
    for i = 1, 3 do
        if enabled(cfg, i) then place(i, 0); end
    end
    return rects;
end

-- Moves a root window (its saved anchor) by dx, dy.
local function move_root(cfg, i, dx, dy)
    local w = cfg.windows[i];
    w.x = math.floor((tonumber(w.x) or 0) + dx + 0.5);
    w.y = math.floor((tonumber(w.y) or 0) + dy + 0.5);
end

-- Detaches a window: it keeps its place on screen.
function meter.unsnap(cfg, i)
    local w = cfg.windows[i];
    local r = meter.rects[i];
    w.snap_to, w.snap_side = 0, '';
    if r ~= nil then
        w.x = math.floor(r.x);
        w.y = math.floor((w.grow == 'up') and (r.y + r.h) or r.y);
        if cfg.snap_match ~= false then w.w = math.floor(r.w); end
    end
end

-- Is j inside i's group (i, or snapped to i through any chain)?
local function in_group(cfg, i, j)
    local guard = 0;
    while j ~= nil and guard < 5 do
        if j == i then return true; end
        j = parent_of(cfg, j);
        guard = guard + 1;
    end
    return false;
end

-- Best snap for window i (dragged, root of its group) against the others.
local function find_snap(cfg, i)
    local ri = meter.rects[i];
    if ri == nil then return nil; end
    local d = tonumber(cfg.snap_distance) or 14;
    local gap = tonumber(cfg.snap_gap) or 2;
    local best = nil;
    for j = 1, 3 do
        local rj = meter.rects[j];
        if j ~= i and rj ~= nil and enabled(cfg, j) and not in_group(cfg, i, j) then
            local function taken(side)
                for k = 1, 3 do
                    if k ~= i and enabled(cfg, k) and parent_of(cfg, k) == j and cfg.windows[k].snap_side == side then return true; end
                end
                return false;
            end
            local hover_x = ri.x < rj.x + rj.w and ri.x + ri.w > rj.x;
            local hover_y = ri.y < rj.y + rj.h and ri.y + ri.h > rj.y;
            local cands = {
                { side = 'below', dist = math.abs(ri.y - (rj.y + rj.h + gap)), ok = hover_x,
                  line = { rj.x, rj.y + rj.h + gap / 2, rj.x + rj.w, rj.y + rj.h + gap / 2 } },
                { side = 'above', dist = math.abs((ri.y + ri.h) - (rj.y - gap)), ok = hover_x,
                  line = { rj.x, rj.y - gap / 2, rj.x + rj.w, rj.y - gap / 2 } },
                { side = 'right', dist = math.abs(ri.x - (rj.x + rj.w + gap)), ok = hover_y,
                  line = { rj.x + rj.w + gap / 2, rj.y, rj.x + rj.w + gap / 2, rj.y + rj.h } },
                { side = 'left', dist = math.abs((ri.x + ri.w) - (rj.x - gap)), ok = hover_y,
                  line = { rj.x - gap / 2, rj.y, rj.x - gap / 2, rj.y + rj.h } },
            };
            for _, c in ipairs(cands) do
                if c.ok and c.dist <= d and not taken(c.side) and (best == nil or c.dist < best.dist) then
                    best = { to = j, side = c.side, dist = c.dist, line = c.line };
                end
            end
        end
    end
    return best;
end

-- ============================================================================
-- Header icons (drawn with shapes)
-- ============================================================================

local function icon_mode(dl, x, y, s, c)
    local bw = s * 0.22;
    dl:AddRectFilled({ x + s * 0.10, y + s * 0.55 }, { x + s * 0.10 + bw, y + s * 0.90 }, c, 1);
    dl:AddRectFilled({ x + s * 0.39, y + s * 0.30 }, { x + s * 0.39 + bw, y + s * 0.90 }, c, 1);
    dl:AddRectFilled({ x + s * 0.68, y + s * 0.10 }, { x + s * 0.68 + bw, y + s * 0.90 }, c, 1);
end

local function icon_reset(dl, x, y, s, c)
    dl:AddRectFilled({ x + s * 0.18, y + s * 0.18 }, { x + s * 0.82, y + s * 0.28 }, c, 1);
    dl:AddRectFilled({ x + s * 0.40, y + s * 0.08 }, { x + s * 0.60, y + s * 0.18 }, c, 1);
    dl:AddRect({ x + s * 0.26, y + s * 0.32 }, { x + s * 0.74, y + s * 0.92 }, c, 2, 0, 1.6);
    dl:AddLine({ x + s * 0.42, y + s * 0.42 }, { x + s * 0.42, y + s * 0.82 }, c, 1.2);
    dl:AddLine({ x + s * 0.58, y + s * 0.42 }, { x + s * 0.58, y + s * 0.82 }, c, 1.2);
end

local function icon_report(dl, x, y, s, c)
    dl:AddRect({ x + s * 0.10, y + s * 0.12 }, { x + s * 0.90, y + s * 0.70 }, c, 3, 0, 1.6);
    dl:AddTriangleFilled({ x + s * 0.25, y + s * 0.68 }, { x + s * 0.45, y + s * 0.68 }, { x + s * 0.22, y + s * 0.92 }, c);
    dl:AddLine({ x + s * 0.24, y + s * 0.32 }, { x + s * 0.76, y + s * 0.32 }, c, 1.3);
    dl:AddLine({ x + s * 0.24, y + s * 0.50 }, { x + s * 0.62, y + s * 0.50 }, c, 1.3);
end

local function icon_gear(dl, x, y, s, c)
    local cx, cy = x + s / 2, y + s / 2;
    for k = 0, 7 do
        local a = k * math.pi / 4;
        dl:AddLine({ cx + math.cos(a) * s * 0.22, cy + math.sin(a) * s * 0.22 },
            { cx + math.cos(a) * s * 0.44, cy + math.sin(a) * s * 0.44 }, c, s * 0.13);
    end
    dl:AddCircleFilled({ cx, cy }, s * 0.30, c, 16);
    dl:AddCircleFilled({ cx, cy }, s * 0.12, U32({ 0.06, 0.06, 0.07, 1 }), 12);
end

local function icon_link(dl, x, y, s, c)
    dl:AddCircle({ x + s * 0.36, y + s * 0.5 }, s * 0.22, c, 12, 1.6);
    dl:AddCircle({ x + s * 0.64, y + s * 0.5 }, s * 0.22, c, 12, 1.6);
end

-- One header icon button. Returns clicked, hovered.
local function icon_button(id, x, y, s, draw, dl, active_col)
    imgui.SetCursorScreenPos({ x, y });
    local clicked = imgui.InvisibleButton(id, { s, s });
    local hov = imgui.IsItemHovered();
    local col = active_col or (hov and { 1, 1, 1, 1 } or { 0.80, 0.80, 0.84, 0.85 });
    if hov then dl:AddRectFilled({ x - 2, y - 2 }, { x + s + 2, y + s + 2 }, U32({ 1, 1, 1, 0.10 }), 3); end
    draw(dl, x, y, s, U32(col));
    return clicked, hov;
end

-- ============================================================================
-- Drawing one window
-- ============================================================================

local function draw_badge(cfg, dl, x, y, s, job, pet)
    local c = pet and (cfg.bars.pet_color or data.PET_COLOR) or meter.job_color(cfg, job);
    dl:AddRectFilled({ x + 1, y + 1 }, { x + s - 1, y + s - 1 }, U32({ c[1] * 0.55, c[2] * 0.55, c[3] * 0.55, 1 }), 3);
    dl:AddRect({ x + 1, y + 1 }, { x + s - 1, y + s - 1 }, U32({ c[1], c[2], c[3], 1 }), 3, 0, 1);
    local t = pet and 'PET' or (job ~= nil and job ~= '' and job or '?');
    local st = { family = cfg.fonts.value.family, size = math.max(7, s * 0.40), outline = 0 };
    local tw = fonts.width(st, t);
    fonts.text(dl, x + (s - tw) / 2, y + (s - st.size) / 2 - 1, t, st, { 1, 1, 1, 0.95 });
end

local function draw_icon(cfg, dl, x, y, s, row)
    local ic = cfg.icons;
    if ic.set ~= 'badge' and not row.pet then
        local tex = icons.job(row.job, ic.set);
        if tex ~= nil then
            pcall(function() dl:AddImage(tex, { x, y }, { x + s, y + s }, { 0, 0 }, { 1, 1 }, U32({ 1, 1, 1, 1 })); end);
            return;
        end
    end
    draw_badge(cfg, dl, x, y, s, row.job, row.pet);
end

local function lerp(a, b, k) return a + (b - a) * k; end

-- A font style at the meter's size.
local function scaled(st, k)
    if k == 1 then return st; end
    local o = {};
    for key, v in pairs(st) do o[key] = v; end
    o.size = (tonumber(st.size) or 14) * k;
    return o;
end

function meter.draw_window(cfg, ctx, i)
    local w = cfg.windows[i];
    local r = meter.rects[i];
    local st = meter.st[i];
    if r == nil then return; end
    local s = cfg.scale or 1;
    local hh = header_h(cfg);
    local rh, rg, pd = row_h(cfg), row_gap(cfg), pad(cfg);

    imgui.SetNextWindowPos({ r.x, r.y });
    imgui.SetNextWindowSize({ r.w, r.h });
    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0, 0, 0, 0 });
    imgui.PushStyleColor(ImGuiCol_Border, { 0, 0, 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    imgui.PushStyleVar(ImGuiStyleVar_WindowMinSize, { 8, 8 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 0);
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoMove,
        ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse, ImGuiWindowFlags_NoSavedSettings or 0,
        ImGuiWindowFlags_NoFocusOnAppearing or 0, ImGuiWindowFlags_NoNav or 0);
    if imgui.Begin('WhatsMyDamage ' .. i .. '##wmd_win' .. i, true, flags) then
        local ok, err = pcall(function()
            local dl = imgui.GetWindowDrawList();
            local x1, y1, x2, y2 = r.x, r.y, r.x + r.w, r.y + r.h;
            local mx, my = imgui.GetMousePos();
            mx, my = tonumber(mx) or -1, tonumber(my) or -1;
            local win_hover = imgui.IsWindowHovered();
            local rnd = (tonumber(cfg.rounding) or 0) * s;

            -- Background
            local bg = cfg.bg or { 0.03, 0.03, 0.035 };
            dl:AddRectFilled({ x1, y1 }, { x2, y2 }, U32({ bg[1], bg[2], bg[3], tonumber(cfg.bg_alpha) or 0.7 }), rnd);
            if cfg.border then
                dl:AddRect({ x1, y1 }, { x2, y2 }, U32(cfg.border_color or { 0.3, 0.3, 0.33, 0.9 }), rnd, 0, 1);
            end

            -- Header
            local mode = w.mode or 'damage';
            if hh > 0 then
                local hc = cfg.header.bg or { 0.07, 0.07, 0.08 };
                dl:AddRectFilled({ x1, y1 }, { x2, y1 + hh }, U32({ hc[1], hc[2], hc[3], tonumber(cfg.header.bg_alpha) or 0.92 }), rnd);
                if cfg.header.accent_line ~= false then
                    dl:AddRectFilled({ x1, y1 + hh - 2 * s }, { x2, y1 + hh }, U32(theme.accent(0.85)), 0);
                end
                local tf = scaled(cfg.fonts.title, s);
                local tsize = tonumber(tf.size) or 16;
                fonts.text(dl, x1 + 7 * s, y1 + (hh - tsize) / 2 - 1, data.MODE_LABEL[mode] or 'Damage Done', tf);

                -- Icons, right to left: settings, report, reset, mode, (link).
                local isz = math.floor(hh * 0.62);
                local ix = x2 - isz - 6 * s;
                local iy = y1 + (hh - isz) / 2 - 1;
                local tip = nil;
                local c, hov;
                c, hov = icon_button('##wmd_cfg' .. i, ix, iy, isz, icon_gear, dl);
                if c then ctx.config_toggle(); end
                if hov then tip = 'Settings (also /wmd config, or right-click)'; end
                ix = ix - isz - 6 * s;
                c, hov = icon_button('##wmd_rep' .. i, ix, iy, isz, icon_report, dl);
                if c then report.open(mode, mx, my); end
                if hov then tip = 'Report to chat: party, linkshell, say...'; end
                ix = ix - isz - 6 * s;
                local armed = meter.reset_armed[i] and (os.clock() - meter.reset_armed[i] < 3);
                c, hov = icon_button('##wmd_rst' .. i, ix, iy, isz, icon_reset, dl, armed and { 1, 0.35, 0.30, 1 } or nil);
                if c then
                    if armed then
                        tracker.reset();
                        meter.reset_armed[i] = nil;
                        ctx.say('All data cleared.');
                    else
                        meter.reset_armed[i] = os.clock();
                    end
                end
                if hov then tip = armed and 'Click again to clear ALL data (every window)' or 'Reset: clears all data (click twice)'; end
                ix = ix - isz - 6 * s;
                c, hov = icon_button('##wmd_mode' .. i, ix, iy, isz, icon_mode, dl);
                if c then imgui.OpenPopup('##wmd_modes' .. i); end
                if hov then tip = 'Change what this window shows'; end
                if parent_of(cfg, i) ~= nil then
                    ix = ix - isz - 6 * s;
                    c, hov = icon_button('##wmd_link' .. i, ix, iy, isz, icon_link, dl, { 0.55, 0.80, 1.0, 1 });
                    if c then meter.unsnap(cfg, i); ctx.dirty(); end
                    if hov then tip = 'Snapped: click to unsnap (or Ctrl + drag)'; end
                end
                if tip ~= nil then theme.tooltip(tip); end

                -- Header drag area (left of the icons).
                imgui.SetCursorScreenPos({ x1, y1 });
                imgui.InvisibleButton('##wmd_hdr' .. i, { math.max(10, ix - x1 - 4), hh });
                if imgui.IsItemActive() and imgui.IsMouseDragging(0) and not cfg.lock and meter.drag == nil then
                    local detach = imgui.GetIO().KeyCtrl == true;
                    meter.drag = { win = i, mx = mx, my = my, detach = detach };
                    if detach and parent_of(cfg, i) ~= nil then meter.unsnap(cfg, i); end
                end
                if imgui.IsItemHovered() and meter.drag == nil then
                    local secs = tracker.elapsed();
                    local rows, total = st.rows or {}, st.total or 0;
                    theme.tooltip(('%s\nParty total: %s\nTime since the first hit: %dm %02ds\n\nDrag to move, drop next to another window to snap.\nCtrl + drag pulls it out of its group.')
                        :format(data.MODE_LABEL[mode], meter.num(cfg, total), math.floor(secs / 60), secs % 60));
                end

                if imgui.BeginPopup('##wmd_modes' .. i) then
                    for _, m in ipairs(data.MODES) do
                        if imgui.Selectable(m.label .. '##wmdm' .. i .. m.key, m.key == mode) then
                            w.mode = m.key;
                            st.rev = -1;
                            ctx.dirty();
                        end
                    end
                    imgui.EndPopup();
                end
            end

            -- Rows
            local rows = st.rows or {};
            local list_y = y1 + hh + pd;
            local list_h = y2 - pd - list_y;
            local nvis = visible_rows(cfg, w, #rows);
            local max_scroll = math.max(0, #rows - nvis);
            st.scroll = math.max(0, math.min(max_scroll, st.scroll or 0));
            if win_hover and w.size == 'fixed' then
                local wheel = tonumber(imgui.GetIO().MouseWheel) or 0;
                if wheel ~= 0 then st.scroll = math.max(0, math.min(max_scroll, st.scroll - wheel)); end
            end

            -- Which rows show (you can be pinned to the last line).
            local shown = {};
            for k = 1, nvis do
                local row = rows[k + st.scroll];
                if row ~= nil then shown[#shown + 1] = row; end
            end
            if cfg.me_always and #rows > nvis then
                local me_in = false;
                for _, row in ipairs(shown) do if row.me then me_in = true; end end
                if not me_in then
                    for _, row in ipairs(rows) do
                        if row.me then shown[#shown] = row; break; end
                    end
                end
            end

            local top_val = (rows[1] and rows[1].value) or 1;
            local now = os.clock();
            local dt = math.min(0.1, now - (st.last_draw or now));
            st.last_draw = now;
            st.disp = st.disp or {};
            st.ypos = st.ypos or {};
            local b = cfg.bars;
            local nf, vf = scaled(cfg.fonts.name, s), scaled(cfg.fonts.value, s);
            local ic = cfg.icons;
            local xl, xr = x1 + pd, x2 - pd;
            local hovered_row = nil;

            dl:PushClipRect({ x1, list_y }, { x2, y2 - pd + 0.5 }, true);
            if #rows == 0 then
                local msg = tracker.test and 'Test mode' or 'No data yet - go hit something!';
                local tw = fonts.width(nf, msg);
                fonts.text(dl, x1 + (r.w - tw) / 2, list_y + (rh - (tonumber(nf.size) or 14)) / 2, msg, nf, { 0.75, 0.75, 0.78, 0.8 });
            end
            for k, row in ipairs(shown) do
                local key = (row.pet and 'p' or 'm') .. row.sid;
                local target_y = list_y + (k - 1) * (rh + rg);
                local yy = st.ypos[key];
                if yy == nil or b.slide == false or math.abs(yy - target_y) > rh * 6 then yy = target_y;
                else yy = lerp(yy, target_y, math.min(1, dt * 12)); end
                st.ypos[key] = yy;
                local frac = (top_val > 0) and (row.value / top_val) or 0;
                local f0 = st.disp[key];
                if f0 == nil or b.anim == false then f0 = frac; else f0 = lerp(f0, frac, math.min(1, dt * 7)); end
                st.disp[key] = f0;

                local ry1, ry2 = yy, yy + rh;
                local bx = xl;
                if ic.show then
                    draw_icon(cfg, dl, xl, ry1, rh, row);
                    bx = xl + rh + 1 * s;
                end
                styles.draw(dl, b.style, bx, ry1, xr, ry2, f0, bar_color(cfg, row), {
                    alpha = b.alpha, rounding = (tonumber(b.rounding) or 0) * s, track = b.track, anim = b.anim ~= false,
                });
                if row.me and b.me_highlight then
                    dl:AddRect({ bx, ry1 }, { xr, ry2 }, U32(theme.accent(0.9)), (tonumber(b.rounding) or 0) * s, 0, 1.2);
                end

                -- Text: "1. Name" on the left, "12,345 (35.2%)" on the right.
                local right = ('%s (%.1f%%)'):format(meter.num(cfg, row.value), row.pct);
                local rw = fonts.width(vf, right);
                local vsize = tonumber(vf.size) or 14;
                local nsize = tonumber(nf.size) or 14;
                local name = row.name or '?';
                if row.pet then name = name .. ' (' .. tostring(row.owner_name or '?') .. ')'; end
                local left = ('%d. %s'):format(row.rank or k, name);
                local tx = bx + 5 * s;
                left = fonts.fit(nf, left, math.max(20, xr - tx - rw - 12 * s));
                local ncol = nf.color;
                if cfg.name_color == 'job' then ncol = meter.job_color(cfg, row.job); end
                fonts.text(dl, tx, ry1 + (rh - nsize) / 2 - 1, left, nf, ncol);
                fonts.text(dl, xr - rw - 5 * s, ry1 + (rh - vsize) / 2 - 1, right, vf);

                if win_hover and mx >= xl and mx <= xr and my >= ry1 and my < ry2 and my < y2 - pd then
                    hovered_row = row;
                    dl:AddRectFilled({ xl, ry1 }, { xr, ry2 }, U32({ 1, 1, 1, 0.06 }), 0);
                end
            end
            dl:PopClipRect();

            -- Scroll bar (fixed size, more rows than fit).
            if w.size == 'fixed' and max_scroll > 0 then
                local th = list_h * nvis / #rows;
                local ty = list_y + (list_h - th) * (st.scroll / max_scroll);
                dl:AddRectFilled({ x2 - 3 * s, ty }, { x2 - 1 * s, ty + th }, U32({ 1, 1, 1, 0.35 }), 2);
            end

            -- Hover breakdown / click for the details window.
            local on_grip = (not cfg.lock) and mx > x2 - 10 * s and my > y2 - 10 * s;
            if hovered_row ~= nil and meter.drag == nil and meter.resize == nil and not on_grip then
                detail.tooltip(cfg, hovered_row, mode);
                if imgui.IsMouseClicked(0) then detail.open(hovered_row.sid, mode); end
            end
            if win_hover and imgui.IsMouseClicked(1) then ctx.config_toggle(); end

            -- Width grip (bottom-right corner).
            if not cfg.lock then
                local gs = 10 * s;
                imgui.SetCursorScreenPos({ x2 - gs, y2 - gs });
                imgui.InvisibleButton('##wmd_grip' .. i, { gs, gs });
                local gh = imgui.IsItemHovered() or (meter.resize ~= nil and meter.resize.win == i);
                if gh or win_hover then
                    local gc = U32({ 1, 1, 1, gh and 0.6 or 0.18 });
                    dl:AddLine({ x2 - 3 * s, y2 - 9 * s }, { x2 - 9 * s, y2 - 3 * s }, gc, 1);
                    dl:AddLine({ x2 - 3 * s, y2 - 5 * s }, { x2 - 5 * s, y2 - 3 * s }, gc, 1);
                end
                if imgui.IsItemActive() and meter.resize == nil then
                    meter.resize = { win = i, mx = mx, w = r.w };
                end
            end
        end);
        if not ok then ctx.error('window ' .. i, err); end
    end
    imgui.End();
    imgui.PopStyleVar(4);
    imgui.PopStyleColor(2);
end

-- ============================================================================
-- All windows
-- ============================================================================

function meter.draw(cfg, ctx)
    tracker.fake_tick();
    -- Rows (re-sorted at most 4 times a second, or when the mode changed).
    local now = os.clock();
    local heights = {};
    local opts = { combine = cfg.combine_pets ~= false, alliance = cfg.alliance == true };
    for i = 1, 3 do
        if enabled(cfg, i) then
            local st = meter.st[i];
            local w = cfg.windows[i];
            if st.rev ~= tracker.rev and (st.rev == -1 or st.rev == nil or now - (st.sorted or 0) > 0.25 or st.mode ~= w.mode
                or st.combine ~= opts.combine or st.alliance ~= opts.alliance) then
                st.rows, st.total = tracker.rows(w.mode or 'damage', opts);
                st.rev, st.sorted, st.mode = tracker.rev, now, w.mode;
                st.combine, st.alliance = opts.combine, opts.alliance;
            end
            heights[i] = height_of(cfg, w, #(st.rows or {}));
        end
    end
    meter.rects = layout(cfg, heights);

    -- Dragging a window moves its whole group (its root's anchor).
    local mx, my = imgui.GetMousePos();
    mx, my = tonumber(mx) or 0, tonumber(my) or 0;
    meter.preview = nil;
    if meter.drag ~= nil then
        local d = meter.drag;
        if imgui.IsMouseDown(0) then
            local root = meter.root_of(cfg, d.win);
            local dx, dy = mx - d.mx, my - d.my;
            if dx ~= 0 or dy ~= 0 then
                move_root(cfg, root, dx, dy);
                d.mx, d.my = mx, my;
                meter.rects = layout(cfg, heights);
            end
            if root == d.win then
                local sn = find_snap(cfg, d.win);
                if sn ~= nil then meter.preview = sn.line; end
            end
        else
            -- Dropped: snap when close to another window.
            local root = meter.root_of(cfg, d.win);
            if root == d.win then
                local sn = find_snap(cfg, d.win);
                if sn ~= nil then
                    local w = cfg.windows[d.win];
                    w.snap_to, w.snap_side = sn.to, sn.side;
                    ctx.say(('Window %d snapped %s window %d.'):format(d.win, sn.side == 'below' and 'under' or (sn.side == 'above' and 'over' or ('to the ' .. sn.side .. ' of')), sn.to));
                end
            end
            meter.drag = nil;
            ctx.dirty();
        end
    end
    if meter.resize ~= nil then
        local rz = meter.resize;
        if imgui.IsMouseDown(0) then
            -- Snapped above / below with matched width: resize the parent chain's top.
            local i = rz.win;
            local guard = 0;
            while cfg.snap_match ~= false and parent_of(cfg, i) ~= nil and guard < 4
                and (cfg.windows[i].snap_side == 'below' or cfg.windows[i].snap_side == 'above') do
                i = parent_of(cfg, i);
                guard = guard + 1;
            end
            cfg.windows[i].w = math.floor(math.max(140, rz.w + (mx - rz.mx)));
            meter.rects = layout(cfg, heights);
        else
            meter.resize = nil;
            ctx.dirty();
        end
    end

    for i = 1, 3 do
        if enabled(cfg, i) then meter.draw_window(cfg, ctx, i); end
    end

    -- Snap preview: a glowing line where the window will attach.
    if meter.preview ~= nil then
        local l = meter.preview;
        local fg = imgui.GetForegroundDrawList();
        fg:AddLine({ l[1], l[2] }, { l[3], l[4] }, U32(theme.accent(0.35)), 7);
        fg:AddLine({ l[1], l[2] }, { l[3], l[4] }, U32(theme.accent(1.0)), 2.5);
    end
end

return meter;
