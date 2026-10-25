--[[
    WhatsMyDamage (WMD) - Ashita v4 / HorizonXI
    Version 1.1.0

    A damage meter in the style of WoW's Details!: colored bars with
    "1. Name" on the left and "amount (share%)" on the right, for
    Damage Done, Healing Done and Damage Taken.

      * up to three meter windows, each showing any of the three modes
      * drag windows anywhere; drop one next to another to snap them
        together and move them as one (Ctrl + drag pulls one out)
      * hover a bar: every source (melee, ranged, each spell / weapon skill /
        ability, skillchains, magic bursts, additional effects, spikes),
        accuracy per source and overall, pets, deaths
      * click a bar: the full details window (hits, avg, min, max, crit,
        accuracy, targets, pets, death recap)
      * your party (and you solo), or the whole alliance; pets combined or
        on their own bars
      * 9 bar styles, job colors, 40+ Windows fonts, outline / shadow, icons
      * report to party / linkshell / say, test mode
      * asks whether to reset the meters when you join a new party

    Counts only what the game already shows you (action packet 0x028 and
    defeat messages in 0x029), against monsters only. It never sends
    anything except a report you ask for.

    Commands: /wmd or /whatsmydamage  (/wmd help lists them)

    Files:
      whatsmydamage.lua    settings, commands, events
      core/data.lua        jobs, colors, battle message ids
      core/names.lua       spell / ability / monster names
      core/roster.lua      party, alliance and pets
      core/tracker.lua     the counting (and test mode)
      core/fonts.lua       Windows fonts, outline / shadow text
      core/icons.lua       job icons (from XIUI)
      core/theme.lua       window look (same as Triage)
      core/cursor.lua      mouse pointer over WMD windows
      core/gamestate.lua   hide before login / during cutscenes
      ui/meter.lua         the meter windows, snapping
      ui/styles.lua        bar styles
      ui/detail.lua        hover breakdown and details window
      ui/report.lua        report to chat
      ui/newparty.lua      "reset the meters?" when you join a new party
      ui/config.lua        settings window
      cfgui.lua            settings window kit (same as MobHunt / IzClock / SCL)
      uifont.lua           the window font (Tahoma) and tooltips
]]

addon.name      = 'whatsmydamage';
addon.author    = 'Izumi (ShiroIzumi)';
addon.version   = '1.1.0';
addon.desc      = 'WhatsMyDamage: a Details!-style damage, healing and damage taken meter.';
addon.link      = '';

require('common');
local imgui = require('imgui');
local settings = require('settings');
local theme = require('core.theme');
local uifont = require('uifont');
local cursor = require('core.cursor');
local gamestate = require('core.gamestate');
local fonts = require('core.fonts');
local icons = require('core.icons');
local roster = require('core.roster');
local tracker = require('core.tracker');
local meter = require('ui.meter');
local detail = require('ui.detail');
local report = require('ui.report');
local config = require('ui.config');
local newparty = require('ui.newparty');

cursor.install();

local function font(family, size, color, outline, shadow)
    return { family = family, size = size, color = color, outline = outline, outline_color = { 0, 0, 0, 1 },
             shadow = shadow, shadow_offset = 1.5, shadow_alpha = 0.75 };
end

local function win(enabled, mode, x, y, snap_to, snap_side)
    return { enabled = enabled, mode = mode, x = x, y = y, w = 300, grow = 'down', size = 'grow', rows = 8,
             max_rows = 0, snap_to = snap_to, snap_side = snap_side };
end

local defaults = T{
    version = 1,
    visible = true,
    windows = {
        win(true, 'damage', 60, 420, 0, ''),
        win(false, 'heal', 60, 640, 1, 'below'),
        win(false, 'taken', 60, 860, 2, 'below'),
    },
    alliance = false,
    combine_pets = true,
    me_always = false,
    reset_on_zone = false,
    new_party = 'ask',          -- joined a new party: ask | reset | keep
    hide_events = true,
    lock = false,
    snap_distance = 14,
    snap_gap = 2,
    snap_match = true,

    -- Meter look
    scale = 1.0,
    bg = { 0.03, 0.03, 0.035, 1 },
    bg_alpha = 0.70,
    border = false,
    border_color = { 0.30, 0.30, 0.33, 0.90 },
    rounding = 0,
    padding = 2,
    header = { show = true, height = 24, bg = { 0.07, 0.07, 0.08, 1 }, bg_alpha = 0.92, accent_line = true },
    bars = {
        style = 'details', height = 22, spacing = 1, rounding = 0, alpha = 1.0,
        track = { 1, 1, 1, 0.04 }, color_by = 'job', single = { 0.30, 0.55, 0.85, 1 },
        pet_color = { 0.45, 0.62, 0.78, 1 }, pet_owner_color = true,
        anim = true, slide = true, me_highlight = false,
    },
    icons = { show = true, set = 'Classic' },
    fonts = {
        title = font('bahnschrift', 16, { 0.95, 0.95, 0.97, 1 }, 0, true),
        name = font('bahnschrift', 15, { 1, 1, 1, 1 }, 1, false),
        value = font('bahnschrift', 15, { 1, 1, 1, 1 }, 1, false),
    },
    name_color = 'white',
    numbers = 'full',
    job_colors = {},
    tooltip = { show = true, size = 14 },
    detail = { x = -1, y = -1, w = -1, h = -1, size = 14 },
    report = { channel = 'p', lines = 5, show_job = false, show_acc = true, close_after = true },

    -- Settings window
    config_theme = 'silver',
    config_scale = 1.0,
    config_pos = { x = -1, y = -1, w = -1, h = -1 },
    config_page = 'general',

    -- 1.1.0: each window's own look (size and, optionally, opacity), the
    -- shared background of the settings / details / report / new party
    -- windows, stat colors and the window font (Tahoma).
    look = {
        detail = { own_alpha = false, alpha = 0.97 },
        report = { scale = 1.0, own_alpha = false, alpha = 0.97 },
        newparty = { scale = 1.0, own_alpha = false, alpha = 0.97 },
        config = { alpha = 0.97 },
    },
    look_v = 0,
    ui_bg = { use_theme = true, color = { 0.035, 0.035, 0.040, 1 }, alpha = 0.97 },
    colors = {
        good = { 0.43, 0.80, 0.50, 1 }, bad = { 0.90, 0.36, 0.36, 1 },
        warn = { 0.92, 0.70, 0.32, 1 }, muted = { 0.62, 0.62, 0.66, 1 },
    },
    ui_font = {},
    pointer = { enabled = true, size = 1.4, color = { 1.00, 0.10, 0.75, 1.00 }, outline = { 0.05, 0.00, 0.05, 1.00 }, shadow = true },
};

uifont.addon = 'whatsmydamage';
uifont.defaults(defaults.ui_font);   -- Tahoma 15 and the tooltip look

local cfg = settings.load(defaults);

local function copy(v)
    if type(v) ~= 'table' then return v; end
    local o = {};
    for k, x in pairs(v) do o[k] = copy(x); end
    return o;
end

-- Adds missing keys from the defaults (older saves).
local function fill(dst, def)
    for k, v in pairs(def) do
        if dst[k] == nil or type(dst[k]) ~= type(v) then
            dst[k] = copy(v);
        elseif type(v) == 'table' and (#v == 0 or type(v[1]) == 'table') then
            fill(dst[k], v);
        end
    end
end

local DEFAULT_COLORS = copy(defaults.colors);

local function set4(dst, src)
    if type(src) ~= 'table' then return; end
    dst[1], dst[2], dst[3], dst[4] = tonumber(src[1]) or dst[1], tonumber(src[2]) or dst[2], tonumber(src[3]) or dst[3], tonumber(src[4]) or 1;
end

local function profile()
    local b = cfg.ui_bg or defaults.ui_bg;
    theme.set_profile({ theme = cfg.config_theme, opacity = tonumber(b.alpha) or 0.97, use_theme_bg = b.use_theme ~= false,
        background = b.color, text_effect = 'shadow' });
    theme.apply(cfg.config_theme);
    -- Stat colors (the tables are shared by reference, so update in place).
    local c = cfg.colors or defaults.colors;
    set4(theme.UI_GOOD, c.good);
    set4(theme.UI_DANGER, c.bad);
    set4(theme.UI_WARN, c.warn);
    set4(theme.UI_MUTED, c.muted);
end

-- 1.1.0: the report and new party windows used the settings window's size;
-- they start at that size now, with their own setting.
local function migrate()
    if (tonumber(cfg.look_v) or 0) >= 1 then return; end
    local s = tonumber(cfg.config_scale) or 1;
    cfg.look.report.scale = s;
    cfg.look.newparty.scale = s;
    cfg.look_v = 1;
end

local function prepare()
    fill(cfg, defaults);
    for _, k in ipairs({ 'detail', 'report', 'newparty', 'config' }) do fill(cfg.look[k], defaults.look[k]); end
    fill(cfg.colors, defaults.colors);
    fill(cfg.ui_bg, defaults.ui_bg);
    uifont.defaults(cfg.ui_font);
    migrate();
    uifont.set_global(cfg.ui_font);
end

prepare();
profile();
uifont.install_tooltips();

local save_at = nil;
local function dirty()
    save_at = os.clock();
    profile();
end
local function save_now()
    save_at = nil;
    pcall(settings.save);
end

local function say(text) print('[WMD] ' .. tostring(text)); end

local errors = {};
local function report_error(where, err)
    err = tostring(err);
    if errors[where] ~= err then
        errors[where] = err;
        print('[WMD] ' .. where .. ' error: ' .. err);
    end
end

local ctx;
ctx = {
    dirty = dirty,
    say = say,
    error = report_error,
    config_toggle = function() config.toggle(); end,
    open_detail = function() detail.open(detail.sid, 'damage'); end,
    unsnap = function(i) meter.unsnap(cfg, i); dirty(); end,
    stack = function()
        for i = 2, 3 do
            local w = cfg.windows[i];
            w.snap_to, w.snap_side = i - 1, 'below';
        end
        cfg.windows[1].snap_to, cfg.windows[1].snap_side = 0, '';
        dirty();
    end,
    reset_colors = function()
        cfg.colors = copy(DEFAULT_COLORS);
        dirty();
    end,
    reset_positions = function()
        for i = 1, 3 do
            local d = defaults.windows[i];
            local w = cfg.windows[i];
            w.x, w.y, w.w, w.snap_to, w.snap_side = d.x, d.y, d.w, d.snap_to, d.snap_side;
        end
        dirty();
    end,
};

settings.register('settings', 'wmd_settings_update', function(s)
    if s == nil then return; end
    cfg = s;
    prepare();
    if cfg.bars.style == 'striped' then cfg.bars.style = 'rounded'; end   -- 1.0.1
    for i = 1, 3 do fill(cfg.windows[i], defaults.windows[i]); end
    profile();
    save_at = nil;
end);
for i = 1, 3 do fill(cfg.windows[i], defaults.windows[i]); end
if cfg.bars ~= nil and cfg.bars.style == 'striped' then cfg.bars.style = 'rounded'; end   -- 1.0.1: Striped became Rounded

-- ============================================================================
-- Commands
-- ============================================================================

local HELP = {
    '/wmd - show / hide the meters',
    '/wmd config - settings (or the gear icon / right-click a meter)',
    '/wmd reset - clear all data',
    '/wmd test - test mode on / off (a made-up party)',
    '/wmd report [damage|heal|taken] [p|l|l2|s|echo] - report window, or send right away with a channel',
    '/wmd details - the details window',
    '/wmd window <1-3> [on|off] - show / hide one window',
    '/wmd mode <1-3> <damage|heal|taken> - what a window shows',
    '/wmd stack - snap the windows under each other;  /wmd unsnap - pull them apart',
    '/wmd lock - lock / unlock moving;  /wmd resetpos - windows back to the default place',
};

local MODE_ALIAS = { damage = 'damage', dmg = 'damage', dps = 'damage', heal = 'heal', heals = 'heal', healing = 'heal',
    taken = 'taken', tank = 'taken', dt = 'taken' };
local CHANNEL_ALIAS = { p = 'p', party = 'p', l = 'l', ls = 'l', linkshell = 'l', l2 = 'l2', ls2 = 'l2', s = 's', say = 's', echo = 'echo', me = 'echo' };

ashita.events.register('command', 'wmd_command_cb', function(e)
    local args = e.command:args();
    if #args == 0 then return; end
    local cmd = args[1]:lower();
    if cmd ~= '/wmd' and cmd ~= '/whatsmydamage' then return; end
    e.blocked = true;
    local sub = (args[2] or ''):lower();
    if sub == '' or sub == 'toggle' then
        cfg.visible = not cfg.visible;
        dirty();
    elseif sub == 'show' then
        cfg.visible = true; dirty();
    elseif sub == 'hide' then
        cfg.visible = false; dirty();
    elseif sub == 'config' or sub == 'settings' or sub == 'cfg' then
        config.toggle();
    elseif sub == 'reset' or sub == 'clear' then
        tracker.reset();
        say('All data cleared.');
    elseif sub == 'test' then
        tracker.set_test(not tracker.test);
        say(tracker.test and 'Test mode on (made-up numbers). /wmd test again to stop.' or 'Test mode off.');
    elseif sub == 'report' then
        local mode, ch = 'damage', nil;
        for i = 3, #args do
            local a = args[i]:lower();
            if MODE_ALIAS[a] then mode = MODE_ALIAS[a]; elseif CHANNEL_ALIAS[a] then ch = CHANNEL_ALIAS[a]; end
        end
        if ch ~= nil then report.send(cfg, mode, ch); else report.open(mode); end
    elseif sub == 'details' or sub == 'detail' then
        ctx.open_detail();
    elseif sub == 'window' or sub == 'win' then
        local i = tonumber(args[3] or '');
        if i == nil or i < 1 or i > 3 then say('Use: /wmd window <1-3> [on|off]'); return; end
        local w = cfg.windows[i];
        local v = (args[4] or ''):lower();
        if v == 'on' then w.enabled = true; elseif v == 'off' then w.enabled = false; else w.enabled = not w.enabled; end
        cfg.visible = true;
        dirty();
    elseif sub == 'mode' then
        local i = tonumber(args[3] or '');
        local m = MODE_ALIAS[(args[4] or ''):lower()];
        if i == nil or i < 1 or i > 3 or m == nil then say('Use: /wmd mode <1-3> <damage|heal|taken>'); return; end
        cfg.windows[i].mode = m;
        dirty();
    elseif sub == 'stack' then
        ctx.stack();
    elseif sub == 'unsnap' then
        for i = 1, 3 do meter.unsnap(cfg, i); end
        dirty();
    elseif sub == 'lock' then
        cfg.lock = not cfg.lock;
        say(cfg.lock and 'Windows locked.' or 'Windows unlocked.');
        dirty();
    elseif sub == 'resetpos' then
        ctx.reset_positions();
        cfg.visible = true;
        say('Windows moved back to the default place.');
    else
        for _, line in ipairs(HELP) do say(line); end
    end
end);

-- ============================================================================
-- Events
-- ============================================================================

ashita.events.register('d3d_present', 'wmd_present_cb', function()
    local logged = gamestate.logged_in();
    if logged then
        roster.alliance = cfg.alliance == true;
        local ok, err = pcall(roster.update);
        if not ok then report_error('roster', err); end
        ok, err = pcall(newparty.check, cfg, ctx);
        if not ok then report_error('new party check', err); end
    end
    local hidden = not logged or (cfg.hide_events ~= false and (gamestate.in_event() or gamestate.interface_hidden()));
    if not hidden then
        if cfg.visible then
            local ok, err = pcall(meter.draw, cfg, ctx);
            if not ok then report_error('meter', err); end
        end
        local ok, err = pcall(detail.draw, cfg, ctx, function(job) return meter.job_color(cfg, job); end);
        if not ok then report_error('details', err); end
        ok, err = pcall(report.draw, cfg, ctx);
        if not ok then report_error('report', err); end
        ok, err = pcall(newparty.draw, cfg, ctx, cfg.visible and meter.rects[1] or nil);
        if not ok then report_error('new party question', err); end
    end
    local ok, err = pcall(config.draw, cfg, ctx);
    if not ok then report_error('settings', err); end
    report.tick();
    cursor.draw(cfg.pointer);
    if save_at ~= nil and os.clock() - save_at > 0.6 and not imgui.IsAnyItemActive() then
        save_now();
    end
end);

-- Fonts are added once here, outside of drawing.
ashita.events.register('load', 'wmd_load_cb', function()
    pcall(fonts.load_all);
    pcall(uifont.load, cfg.ui_font);
end);

ashita.events.register('packet_in', 'wmd_packet_in_cb', function(e)
    if e.id == 0x028 then
        local ok, err = pcall(tracker.packet_0x028, e);
        if not ok then report_error('action packet', err); end
    elseif e.id == 0x029 then
        local ok, err = pcall(tracker.packet_0x029, e);
        if not ok then report_error('message packet', err); end
    elseif e.id == 0x00A then
        if cfg.reset_on_zone then tracker.reset(); end
    end
end);

ashita.events.register('unload', 'wmd_unload_cb', function()
    save_now();
    icons.reset();
end);
