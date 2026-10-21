--[[
    IzClock - ui/clock.lua

    A clock window. There are two: the main clock and an optional second one
    (off by default), each with its own settings table. The text is laid out
    once per second (or right after a setting changes) and drawn on the draw
    list, so it costs almost nothing per frame and can have a shadow /
    outline like the other addons.

    Layouts:
      line   one line:   LOCAL 12:10:57 | VANA 05:33 | Watersday > Windsday | NEXT 44m 15s
      stack  one piece per line, labels in a column
      full   stack + the coming week's day rotation

    Mouse:
      drag         move it (unless locked)
      click        open / close the info window
      right-click  settings
      hover        the hover window (week, moon, crafting, guilds, travel)
]]

require('common');
local imgui = require('imgui');
local theme = require('core.theme');
local vana = require('core.vana');
local gamestate = require('core.gamestate');

local clock = {
    rev = 0,                 -- bumped on every setting change
    flash_until = 0,         -- day alert: flash until this os.clock()
    flash_day = 0,           -- ... in this day's color
};

function clock.invalidate() clock.rev = clock.rev + 1; end

function clock.flash(day, secs)
    clock.flash_day = day;
    clock.flash_until = os.clock() + (tonumber(secs) or 10);
end

local Clock = {};
Clock.__index = Clock;

-- id: 'main' or 'second' (window ids and saved positions).
function clock.new(id)
    return setmetatable({
        id = id,
        place_next = true,   -- apply the saved position on the next frame
        key = nil,           -- what the cached layout was built for
        lines = nil,         -- { { runs = { {text, color, x, w, hover} }, w, y } }
        w = 0, h = 0, lh = 0,
        press = nil,         -- where a left-click started (click vs drag)
    }, Clock);
end

function Clock:place() self.place_next = true; end

-- ============================================================================
-- Text for each piece
-- ============================================================================

local function time_fmt(c)
    if c.time24 then return c.seconds and '%H:%M:%S' or '%H:%M'; end
    return c.seconds and '%I:%M:%S %p' or '%I:%M %p';
end

local function trim_zero(c, s)
    if s ~= nil and not c.time24 and s:sub(1, 1) == '0' then return s:sub(2); end
    return s;
end

local function local_time(c)
    return trim_zero(c, os.date(time_fmt(c)));
end

-- Japan Standard Time: UTC+9, no daylight saving.
local function jp_time(c)
    return trim_zero(c, os.date('!' .. time_fmt(c), os.time() + 9 * 3600));
end

local function countdown(c, secs)
    secs = math.max(0, math.floor(secs or 0));
    local m, s = math.floor(secs / 60), secs % 60;
    if c.countdown == 'clock' then return ('%d:%02d'):format(m, s); end
    return ('%dm %02ds'):format(m, s);
end

local function day_color(c, i)
    local col = c.day_colors and c.day_colors[i + 1];
    if type(col) == 'table' then return col; end
    return vana.DAY_COLORS[i];
end

local function day_text(c, i)
    local name = vana.DAYS[i] or '?';
    if c.element_tags then return '[' .. vana.TAGS[i] .. '] ' .. name; end
    return name;
end

-- The runs (text + color) of one piece's value. hover = 'day' marks the
-- runs that open the hover window when it is set to "the day only".
local function value_runs(c, id, v)
    if id == 'local' then return { { local_time(c), c.value_color } }; end
    if id == 'jp' then return { { jp_time(c), c.value_color } }; end
    if id == 'vana' then return { { ('%02d:%02d'):format(v.hour, v.minute), c.vana_color } }; end
    if id == 'next' then return { { countdown(c, v.to_next), c.value_color } }; end
    if id == 'moon' then
        local t = v.moon_name;
        if c.moon_percent then t = t .. (' (%d%%)'):format(v.moon_pct); end
        return { { t, c.value_color } };
    end
    if id == 'day' then
        local runs = { { day_text(c, v.day), day_color(c, v.day), hover = 'day' } };
        if c.day_next then
            runs[#runs + 1] = { ' > ', c.sep_color, hover = 'day' };
            runs[#runs + 1] = { day_text(c, v.next_day), day_color(c, v.next_day), hover = 'day' };
        end
        return runs;
    end
    return {};
end

-- ============================================================================
-- Layout (once per second / per change)
-- ============================================================================

local function measure(text)
    local w = imgui.CalcTextSize(text);
    return tonumber(w) or 0;
end

function Clock:build(c, v)
    local lines = {};
    local gap = (tonumber(c.gap) or 8) * 0.5;
    local labels = c.show_labels ~= false;
    local shown = {};
    for _, s in ipairs(c.segments) do
        if s.show then shown[#shown + 1] = s; end
    end

    if c.layout == 'line' then
        local runs = {};
        for i, s in ipairs(shown) do
            if i > 1 then
                local sep = tostring(c.separator or '|');
                runs[#runs + 1] = { sep ~= '' and sep or ' ', c.sep_color, pad = gap };
            end
            if labels and (s.label or '') ~= '' then
                runs[#runs + 1] = { s.label .. ' ', c.label_color };
            end
            for _, r in ipairs(value_runs(c, s.id, v)) do runs[#runs + 1] = r; end
        end
        lines[1] = { runs = runs };
    else
        -- Labels in a column so the values line up.
        local col = 0;
        if labels then
            for _, s in ipairs(shown) do
                if (s.label or '') ~= '' then col = math.max(col, measure(s.label)); end
            end
        end
        for _, s in ipairs(shown) do
            local runs = {};
            if col > 0 then
                runs[#runs + 1] = { s.label or '', c.label_color, width = col + gap * 2 };
            end
            for _, r in ipairs(value_runs(c, s.id, v)) do runs[#runs + 1] = r; end
            lines[#lines + 1] = { runs = runs };
        end
        if c.layout == 'full' then
            lines[#lines + 1] = { runs = { { 'THIS WEEK', c.label_color } }, rule = true };
            local runs = {};
            for off = 1, 7 do
                local i = (v.day + off) % 8;
                if off > 1 then runs[#runs + 1] = { ' > ', c.sep_color, hover = 'day' }; end
                runs[#runs + 1] = { day_text(c, i), day_color(c, i), hover = 'day' };
            end
            lines[#lines + 1] = { runs = runs };
        end
    end

    -- Positions and sizes.
    local lh = imgui.GetFontSize();
    local line_gap = tonumber(c.line_gap) or 3;
    local w, h = 0, 0;
    for li, ln in ipairs(lines) do
        local x = 0;
        for _, r in ipairs(ln.runs) do
            local tw = measure(r[1]);
            local pad = r.pad or 0;
            r.x = x + pad;
            r.w = tw;
            x = x + pad + (r.width or tw) + pad;
        end
        ln.w = x;
        ln.y = h;
        w = math.max(w, x);
        h = h + lh + ((li < #lines) and line_gap or 0);
        if ln.rule then h = h + 2; end
    end
    self.lines, self.w, self.h, self.lh = lines, w, h, lh;
end

-- ============================================================================
-- Window
-- ============================================================================

-- c: this clock's settings. cfg: all settings (hover, hide_events).
-- ui: { config = ui.config, info = ui.info }
function Clock:draw(c, cfg, ctx, ui)
    if not gamestate.logged_in() then return; end
    if cfg.hide_events ~= false and (gamestate.in_event() or gamestate.interface_hidden()) then return; end

    local v = vana.now();
    local pad_x, pad_y = tonumber(c.pad_x) or 8, tonumber(c.pad_y) or 4;

    if self.place_next then
        imgui.SetNextWindowPos({ tonumber(c.x) or 50, tonumber(c.y) or 50 });
        self.place_next = false;
    end

    local bg = c.bg or { 0.055, 0.070, 0.095 };
    imgui.PushStyleColor(ImGuiCol_WindowBg, { bg[1], bg[2], bg[3], tonumber(c.bg_alpha) or 0.92 });
    imgui.PushStyleColor(ImGuiCol_Border, c.border and (c.border_color or { 0.2, 0.38, 0.52, 0.9 }) or { 0, 0, 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, tonumber(c.rounding) or 4);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { pad_x, pad_y });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, c.border and 1 or 0);
    imgui.PushStyleVar(ImGuiStyleVar_WindowMinSize, { 8, 8 });

    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoSavedSettings or 0, ImGuiWindowFlags_NoFocusOnAppearing or 0,
        ImGuiWindowFlags_NoNav or 0);
    if c.lock then flags = bit.bor(flags, ImGuiWindowFlags_NoMove); end

    if imgui.Begin('IzClock##izclock_' .. self.id, true, flags) then
        local base = imgui.GetFontSize();
        imgui.PushFont(nil, base * (tonumber(c.font_scale) or 1));

        -- Rebuild the layout when the second, the settings or the font size change.
        local key = tostring(os.time()) .. '|' .. clock.rev .. '|' .. tostring(imgui.GetFontSize());
        if self.key ~= key then
            self:build(c, v);
            self.key = key;
        end

        local fixed = c.width_mode == 'fixed';
        local inner_w = fixed and math.max(self.w, (tonumber(c.width) or 520) - pad_x * 2) or self.w;
        local ox, oy = imgui.GetCursorScreenPos();
        ox, oy = tonumber(ox) or 0, tonumber(oy) or 0;
        local dl = imgui.GetWindowDrawList();
        local size = imgui.GetFontSize();
        local mx, my = imgui.GetMousePos();
        mx, my = tonumber(mx) or -1, tonumber(my) or -1;
        local hovered = imgui.IsWindowHovered();
        local over_day = false;

        -- Day alert: pulse in the new day's color.
        local flashing = os.clock() < clock.flash_until;
        local wx, wy = imgui.GetWindowPos();
        local ww, wh = imgui.GetWindowSize();
        wx, wy, ww, wh = tonumber(wx) or 0, tonumber(wy) or 0, tonumber(ww) or 0, tonumber(wh) or 0;
        local pulse = 0;
        if flashing then
            pulse = 0.5 + 0.5 * math.sin(os.clock() * 7);
            local fc = day_color(c, clock.flash_day);
            dl:AddRectFilled({ wx, wy }, { wx + ww, wy + wh }, imgui.GetColorU32({ fc[1], fc[2], fc[3], 0.10 + 0.22 * pulse }), tonumber(c.rounding) or 4);
        end

        theme.effect = c.text_effect;
        for _, ln in ipairs(self.lines) do
            local lx = ox;
            if fixed and c.align == 'center' then lx = ox + (inner_w - ln.w) / 2;
            elseif fixed and c.align == 'right' then lx = ox + inner_w - ln.w; end
            local ly = oy + ln.y;
            if ln.rule then
                dl:AddLine({ ox, ly - 1 }, { ox + inner_w, ly - 1 }, imgui.GetColorU32(c.sep_color), 1);
            end
            for _, r in ipairs(ln.runs) do
                local x = lx + r.x;
                theme.text(dl, x, ly, r[2], r[1], size);
                if r.hover == 'day' and hovered and mx >= x and mx < x + r.w and my >= ly and my < ly + self.lh then
                    over_day = true;
                end
            end
        end
        theme.effect = nil;

        if flashing then
            local fc = day_color(c, clock.flash_day);
            dl:AddRect({ wx + 1, wy + 1 }, { wx + ww - 1, wy + wh - 1 }, imgui.GetColorU32({ fc[1], fc[2], fc[3], 0.55 + 0.45 * pulse }), tonumber(c.rounding) or 4, 0, 2);
        end

        imgui.Dummy({ math.max(1, inner_w), math.max(1, self.h) });
        imgui.PopFont();

        -- Hover window (not while a mouse button is held).
        local area = (cfg.hover and cfg.hover.area) or 'clock';
        local show_tip = (area == 'clock' and hovered) or (area == 'day' and over_day);
        if show_tip and not imgui.IsMouseDown(0) and not imgui.IsMouseDown(1) then
            ui.info.hover(cfg, c, v);
        end

        -- Click (no drag): info window. Right-click: settings.
        if hovered and imgui.IsMouseClicked(0) then self.press = { mx, my }; end
        if self.press ~= nil and imgui.IsMouseReleased(0) then
            local dx, dy = mx - self.press[1], my - self.press[2];
            if hovered and dx * dx + dy * dy <= 16 then ui.info.toggle(); end
            self.press = nil;
        end
        if hovered and imgui.IsMouseClicked(1) then ui.config.toggle(); end

        -- Remember where it was dragged.
        if not imgui.IsMouseDown(0) and (math.abs(wx - (c.x or 0)) >= 1 or math.abs(wy - (c.y or 0)) >= 1) then
            c.x, c.y = math.floor(wx), math.floor(wy);
            ctx.dirty(true);
        end
    end
    imgui.End();
    imgui.PopStyleVar(4);
    imgui.PopStyleColor(2);
end

return clock;
