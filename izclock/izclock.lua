--[[
    IzClock - Ashita v4 / HorizonXI
    Version 3.1.4

    A small Vana'diel clock: Vana'diel time, the elemental day (and the next
    one), the countdown to the next day, moon phase, and optionally your
    local time and Japan time. Every piece can be turned on / off, renamed,
    reordered and recolored. Hover it for the week, moon, crafting, guild
    hours and ships; click it for the info window with all of it. An
    optional second clock and an optional day-change alert.

    Commands:
      /ic, /izclock          show / hide the clock(s)
      /ic config             settings (also /icconfig, or right-click the clock)
      /ic info               the info window (or click the clock)
      /ic second             show / hide the second clock
      /ic lock               lock / unlock the clocks' positions
      /ic reset              move the clocks back to the top-left corner
      /ic help               list the commands

    Vana'diel time is calculated from the computer clock (no packet needed),
    so it shows right away.

    Files:
      izclock.lua         settings, commands, events
      core/vana.lua       Vana'diel time, days, moon
      core/theme.lua      settings window look (same as Triage)
      core/cursor.lua     mouse pointer over IzClock windows
      core/gamestate.lua  hide before login / during cutscenes
      core/schedule.lua   guild hours, ships, moon forecast, crafting element
      ui/clock.lua        a clock window (main and second)
      ui/info.lua         the hover window and the info window
      ui/config.lua       the settings window
]]

addon.name      = 'izclock';
addon.author    = 'Izumi (ShiroIzumi)';
addon.version   = '3.1.4';
addon.desc      = 'Vana\'diel clock: time, elemental day, next-day countdown, moon phase, local and Japan time.';
addon.link      = '';

require('common');
local imgui = require('imgui');
local settings = require('settings');
local theme = require('core.theme');
local cursor = require('core.cursor');
local vana = require('core.vana');
local schedule = require('core.schedule');
local clock = require('ui.clock');
local info = require('ui.info');
local config = require('ui.config');

cursor.install();

local function day_colors()
    local t = {};
    for i = 0, 7 do
        local c = vana.DAY_COLORS[i];
        t[i + 1] = { c[1], c[2], c[3], c[4] };
    end
    return t;
end

-- Pieces of the clock, in display order. id = which piece; label = the text
-- in front of it (empty = none).
local function default_segments()
    return {
        { id = 'local', show = false, label = 'LOCAL' },
        { id = 'vana',  show = true,  label = 'VANA' },
        { id = 'jp',    show = false, label = 'JP' },
        { id = 'day',   show = true,  label = '' },
        { id = 'next',  show = true,  label = 'NEXT' },
        { id = 'moon',  show = false, label = 'MOON' },
    };
end

-- Everything one clock window needs. The main clock keeps these at the top
-- level of the settings; the second clock has its own copy under `second`.
local function view_defaults()
    return {
        -- What shows
        layout = 'line',            -- line (one line), stack (one per line), full (stack + the week's rotation)
        segments = default_segments(),
        show_labels = true,
        day_next = true,            -- "Watersday > Windsday"
        element_tags = false,       -- [Wa] before day names
        time24 = false,             -- local / JP time
        seconds = false,
        countdown = 'ms',           -- ms ("44m 15s") | clock ("44:15")
        moon_percent = true,
        separator = '|',

        -- Look
        font_scale = 1.00,
        text_effect = 'shadow',     -- none | shadow | outline | both
        label_color = { 0.58, 0.64, 0.72, 1.00 },
        value_color = { 0.91, 0.94, 0.98, 1.00 },
        vana_color = { 0.34, 0.76, 1.00, 1.00 },
        sep_color = { 0.42, 0.47, 0.55, 1.00 },
        day_colors = day_colors(),
        bg = { 0.055, 0.070, 0.095 },
        bg_alpha = 0.92,
        border = true,
        border_color = { 0.20, 0.38, 0.52, 0.90 },
        rounding = 4,
        pad_x = 8,
        pad_y = 4,
        gap = 8,                    -- space around separators / between pieces
        line_gap = 3,               -- space between lines (stack / full)
        width_mode = 'auto',        -- auto | fixed
        width = 520,
        align = 'left',             -- left | center | right (fixed width only)

        -- Position
        x = 50, y = 50,
        lock = false,
    };
end

-- The second clock starts as a stacked panel under the first.
local function second_defaults()
    local d = view_defaults();
    d.enabled = false;
    d.layout = 'stack';
    d.x, d.y = 50, 110;
    for _, s in ipairs(d.segments) do
        s.show = (s.id == 'vana' or s.id == 'day' or s.id == 'next' or s.id == 'moon');
    end
    return d;
end

local function all_days(v)
    local t = {};
    for i = 1, 8 do t[i] = v; end
    return t;
end

local defaults = T(view_defaults());
defaults.version = 3;
defaults.visible = true;
defaults.hide_events = true;        -- hide during cutscenes (always hidden before login)

-- Second clock (off by default)
defaults.second = second_defaults();

-- Hover window: where it opens and what it shows
defaults.hover = {
    area = 'clock',                 -- clock (anywhere on it) | day (the day only) | off
    scale = 1.00,                   -- text size
    week = true, moon = true, craft = true, guilds = true, travel = true,
    routes = (function() local t = {}; for k, v in pairs(schedule.DEFAULT_HOVER_ROUTES) do t[k] = v; end return t; end)(),
};

-- Day-change alert (off by default)
defaults.alert = {
    enabled = false,
    minutes = 0,                    -- 0 = when the day changes, else this many minutes before
    chat = true,
    flash = true,
    flash_secs = 10,
    days = all_days(true),          -- which days to announce (1 = Firesday)
};

-- Info window position (-1 = not moved yet: opens under the main clock)
defaults.info_pos = { x = -1, y = -1 };
defaults.info_scale = 1.00;

-- Settings window
defaults.config_theme = 'midnight';
defaults.ui_scale = 1.00;
defaults.config_win = { x = -1, y = -1, w = -1, h = -1 };   -- -1 = not moved / resized yet
defaults.pointer = { enabled = true, size = 1.4, color = { 1.00, 0.10, 0.75, 1.00 }, outline = { 0.05, 0.00, 0.05, 1.00 }, shadow = true };

local cfg = settings.load(defaults);

-- Adds missing keys (older saves); keeps the user's lists as they are.
local function copy(v)
    if type(v) ~= 'table' then return v; end
    local o = {};
    for k, x in pairs(v) do o[k] = copy(x); end
    return o;
end

local function fill(dst, def)
    for k, v in pairs(def) do
        if dst[k] == nil or type(dst[k]) ~= type(v) then
            dst[k] = copy(v);
        elseif type(v) == 'table' and #v == 0 then
            fill(dst[k], v);
        end
    end
end

-- 2.x settings → 3.0 (same look: one line / mini / full, the same pieces).
local function migrate(c)
    if (tonumber(c.version) or 0) >= 3 then return; end
    if c.compact_mode == true then c.layout = 'line';
    elseif c.mini_mode == true then c.layout = 'stack';
    elseif c.compact_mode == false then c.layout = 'full'; end
    local segs = default_segments();
    for _, s in ipairs(segs) do
        if s.id == 'local' and c.show_local_time ~= nil then s.show = c.show_local_time == true; end
        if s.id == 'jp' and c.show_jp_time ~= nil then s.show = c.show_jp_time == true; end
        if s.id == 'moon' and c.show_moon_phase ~= nil then s.show = c.show_moon_phase == true; end
    end
    c.segments = segs;
    if c.show_element_icons ~= nil then c.element_tags = c.show_element_icons == true; end
    if c.local_time_24h ~= nil then c.time24 = c.local_time_24h == true; end
    if c.show_local_seconds ~= nil then c.seconds = c.show_local_seconds == true; end
    if tonumber(c.window_alpha) ~= nil then c.bg_alpha = tonumber(c.window_alpha); end
    if type(c.background_color) == 'table' then
        c.bg = { tonumber(c.background_color[1]) or 0.055, tonumber(c.background_color[2]) or 0.070, tonumber(c.background_color[3]) or 0.095 };
    end
    if c.hide_border ~= nil then c.border = c.hide_border ~= true; end
    if c.lock_window ~= nil then c.lock = c.lock_window == true; end
    if type(c.window) == 'table' then
        c.x = tonumber(c.window.x) or c.x;
        c.y = tonumber(c.window.y) or c.y;
        if c.alignment == 'center' or c.alignment == 'right' then
            c.align = c.alignment;
            c.width_mode = 'fixed';
            c.width = math.floor(tonumber(c.window.width) or 520);
        end
    end
    for _, k in ipairs({ 'config_visible', 'window_alpha', 'mini_mode', 'hide_title_bar', 'hide_border', 'show_local_time',
        'show_jp_time', 'local_time_24h', 'show_local_seconds', 'show_moon_phase', 'show_element_icons', 'compact_mode',
        'lock_window', 'background_color', 'alignment', 'window' }) do
        c[k] = nil;
    end
    c.version = 3;
end

-- Every piece once, unknown ones dropped (keeps the user's order).
local function clean_segments(list)
    local seen, out = {}, {};
    for _, s in ipairs(list or {}) do
        if type(s) == 'table' and s.id ~= nil and not seen[s.id] then
            seen[s.id] = true;
            out[#out + 1] = s;
        end
    end
    for _, s in ipairs(default_segments()) do
        if not seen[s.id] then
            s.show = false;
            out[#out + 1] = s;
        end
    end
    return out;
end

local function prepare(c)
    migrate(c);
    -- 3.0: the week tooltip setting became the hover window's.
    if c.rotation_tip == false and type(c.hover) ~= 'table' then c.hover = { area = 'off' }; end
    c.rotation_tip = nil;
    fill(c, defaults);
    c.segments = clean_segments(c.segments);
    c.second.segments = clean_segments(c.second.segments);
    c.visible = true;   -- the clock always shows after a load / login
end

prepare(cfg);
theme.set_profile({ theme = cfg.config_theme, opacity = 0.97, use_theme_bg = true, text_effect = cfg.text_effect });

-- Settings are saved shortly after a change, never while a slider is held.
local save_at = nil;
-- pos_only: just a clock being dragged (no need to lay the text out again).
local function dirty(pos_only)
    save_at = os.clock();
    if pos_only == true then return; end
    clock.invalidate();
    theme.set_profile({ theme = cfg.config_theme, opacity = 0.97, use_theme_bg = true, text_effect = cfg.text_effect });
end

local function save_now()
    save_at = nil;
    pcall(settings.save);
end

local clocks = { main = clock.new('main'), second = clock.new('second') };

-- ============================================================================
-- Day-change alert
-- ============================================================================

local alert = { armed_day = nil, last_day = nil };

local function announce(day, msg)
    local a = cfg.alert;
    if a.chat then print('[IzClock] ' .. msg); end
    if a.flash then clock.flash(day, a.flash_secs); end
end

local function check_alert()
    local a = cfg.alert;
    local v = vana.now();
    local lead = math.max(0, math.floor(tonumber(a.minutes) or 0)) * 60;
    if alert.last_day == nil then
        -- First check after load: don't announce what was already due.
        alert.last_day = v.total_days;
        if lead > 0 and v.to_next <= lead then alert.armed_day = v.total_days; end
        return;
    end
    if not a.enabled then
        alert.last_day = v.total_days;
        return;
    end
    if lead == 0 then
        if v.total_days ~= alert.last_day then
            if a.days[v.day + 1] ~= false then
                local el = schedule.ELEMENTS[v.day].name;
                announce(v.day, ('%s has begun (%s).'):format(vana.DAYS[v.day], el));
            end
        end
    elseif v.to_next <= lead and alert.armed_day ~= v.total_days then
        alert.armed_day = v.total_days;
        if a.days[v.next_day + 1] ~= false then
            announce(v.next_day, ('%s begins in %s.'):format(vana.DAYS[v.next_day], schedule.span(v.to_next)));
        end
    end
    alert.last_day = v.total_days;
end

local function test_alert()
    local v = vana.now();
    local a = cfg.alert;
    local msg = (tonumber(a.minutes) or 0) > 0
        and ('%s begins in %dm. (test)'):format(vana.DAYS[v.next_day], a.minutes)
        or ('%s has begun. (test)'):format(vana.DAYS[v.next_day]);
    if a.chat then print('[IzClock] ' .. msg); end
    if a.flash then clock.flash(v.next_day, a.flash_secs); end
end

local ctx = {
    dirty = dirty,
    defaults = defaults,
    default_segments = default_segments,
    view_defaults = function(which) if which == 'second' then return second_defaults(); end return view_defaults(); end,
    day_colors = day_colors,
    test_alert = test_alert,
    info_toggle = function() info.toggle(); end,
    reset_position = function(which)
        if which == nil or which == 'main' then
            cfg.x, cfg.y = 50, 50;
            clocks.main:place();
        end
        if which == nil or which == 'second' then
            cfg.second.x, cfg.second.y = 50, 110;
            clocks.second:place();
        end
        if which == nil then
            cfg.info_pos.x, cfg.info_pos.y = -1, -1;
            info.placed = false;
        end
        dirty();
    end,
};

-- The character's own settings arrive after login.
settings.register('settings', 'izclock_settings_update', function(s)
    if s == nil then return; end
    cfg = s;
    prepare(cfg);
    clocks.main:place();
    clocks.second:place();
    dirty();
    save_at = nil;
end);

local HELP = {
    '/ic or /izclock - show / hide the clock(s)',
    '/ic config - settings (also /icconfig, or right-click the clock)',
    '/ic info - the info window (or click the clock)',
    '/ic second - show / hide the second clock',
    '/ic lock - lock / unlock the clocks\' positions',
    '/ic reset - move the clocks back to the top-left corner',
};

ashita.events.register('command', 'izclock_command_cb', function(e)
    local args = e.command:args();
    if #args == 0 then return; end
    local cmd = args[1]:lower();
    if cmd == '/icconfig' then
        e.blocked = true;
        config.toggle();
        return;
    end
    if cmd ~= '/ic' and cmd ~= '/izclock' then return; end
    e.blocked = true;
    local sub = (args[2] or ''):lower();
    if sub == '' or sub == 'toggle' then
        cfg.visible = not cfg.visible;
    elseif sub == 'show' then
        cfg.visible = true;
    elseif sub == 'hide' then
        cfg.visible = false;
    elseif sub == 'config' or sub == 'settings' then
        config.toggle();
    elseif sub == 'info' then
        info.toggle();
    elseif sub == 'second' then
        cfg.second.enabled = not cfg.second.enabled;
        if cfg.second.enabled then clocks.second:place(); end
        print('[IzClock] Second clock ' .. (cfg.second.enabled and 'on.' or 'off.'));
        dirty();
    elseif sub == 'lock' then
        cfg.lock = not cfg.lock;
        cfg.second.lock = cfg.lock;
        print('[IzClock] Position ' .. (cfg.lock and 'locked.' or 'unlocked.'));
        dirty();
    elseif sub == 'reset' then
        ctx.reset_position();
        print('[IzClock] Clocks moved to the top-left corner.');
    else
        for _, line in ipairs(HELP) do print('[IzClock] ' .. line); end
    end
end);

local ui = { config = config, info = info };

local function report(where, ok, err)
    if ok then return; end
    err = tostring(err);
    if ui[where .. '_error'] ~= err then
        ui[where .. '_error'] = err;
        print('[IzClock] ' .. where .. ' error: ' .. err);
    end
end

ashita.events.register('d3d_present', 'izclock_present_cb', function()
    report('alert', pcall(check_alert));
    if cfg.visible then
        report('clock', pcall(clocks.main.draw, clocks.main, cfg, cfg, ctx, ui));
        if cfg.second.enabled then
            report('second clock', pcall(clocks.second.draw, clocks.second, cfg.second, cfg, ctx, ui));
        end
    end
    report('info', pcall(info.draw, cfg, ctx));
    report('settings', pcall(config.draw, cfg, ctx));
    cursor.draw(cfg.pointer);
    if save_at ~= nil and os.clock() - save_at > 0.6 and not imgui.IsAnyItemActive() then
        save_now();
    end
end);

ashita.events.register('unload', 'izclock_unload_cb', function()
    save_now();
end);
