addon.name    = 'scrollingcombatlog';
addon.author  = 'Izumi (ShiroIzumi)';
addon.version = '1.5.2';
addon.desc    = 'Self-only packet-driven Ashita v4 scrolling combat text inspired by MSBT. Shows completed actions only.';
addon.link    = '';

--[[
    ScrollingCombatLog

    File layout (all under this addon folder):
      scrollingcombatlog.lua  this file: Ashita events and /scl commands
      scl\core.lua            settings, shared state, small text helpers
      scl\session.lua         session summary numbers (your own only)
      scl\debuglog.lua        /scl debug unmapped-message log
      scl\events.lua          event creation, colors, symbols, sizes, lanes
      scl\resources.lua       names: entities, spells, abilities, items, statuses
      scl\packets.lua         0x028 action packets (combat)
      scl\rewards.lua         0x029 / 0x02D / zone packets, chat fallback, EXP watch
      scl\render.lua          lane drawing (Performance + Custom Font renderers)
      scl\theme.lua           config window theme and styled widgets
      scl\ui.lua              config, Preview & Tools, Session window, move handles
      scl\history.lua         the History window (last events of each side, 1.4.0)
      scl\uifont.lua          the font of SCL's windows (Tahoma; not the floating text)

    HorizonXI rule: only COMPLETED actions are ever shown. Start-of-action
    packets ("readies", "starts casting", ...) are discarded in scl\packets.lua.
]]

require('common');

local ashita_settings = require('settings');
local core      = require('scl.core');
local session   = require('scl.session');
local debuglog  = require('scl.debuglog');
local packets   = require('scl.packets');
local rewards   = require('scl.rewards');
local render    = require('scl.render');
local ui        = require('scl.ui');
local history   = require('scl.history');
local uifont    = require('scl.uifont');

local settings = core.settings;
local state = core.state;

-- Ashita v4 settings are per-character and can be replaced after login or a
-- character switch. Point SCL at the active character's table.
ashita_settings.register('settings', 'scrollingcombatlog_settings_update', function(s)
    if s == nil then
        return;
    end

    core.set_settings(s);

    state.move_mode = settings.locked == false;
    state.move_initialized.incoming = false;
    state.move_initialized.outgoing = false;
    state.move_initialized.notification = false;

    state.config_geometry.main_initialized = false;
    state.config_geometry.tools_initialized = false;
    state.config_geometry.last_main = nil;
    state.config_geometry.last_tools = nil;
    state.config_geometry.last_session = nil;
    state.session_geometry_initialized = false;

    state.xp_watch.initialized = false;
    state.exp_tracking.pending = nil;
    state.combine = {};

    render.rebuild_font_pool();
end);

ashita.events.register('packet_in', 'scl_scroll_packet_in_cb', function(e)
    if not e or state.paused or not settings.enabled then
        return;
    end

    if e.id == 0x28 then
        packets.handle_action_packet(e);
    elseif e.id == 0x29 then
        rewards.handle_message_packet(e);
    elseif e.id == 0x2D then
        rewards.handle_exp_packet(e);
    elseif e.id == 0x0A or e.id == 0x0B then
        rewards.handle_zone_packet(e);
    end
end);

-- Reward lines only (EXP, gil, skill-ups, drops, wear-offs). Never combat.
ashita.events.register('text_in', 'scl_scroll_exp_text_in_cb', function(e)
    rewards.handle_text_in(e);
end);

ashita.events.register('command', 'scl_scroll_command_cb', function(e)
    if not e or not e.command then return end
    local args = e.command:args();
    if #args == 0 or tostring(args[1]):lower() ~= '/scl' then return end

    e.blocked = true;
    local sub = (args[2] or ''):lower();

    if sub == '' then
        settings.enabled = not settings.enabled;
        core.save_settings();
        print(('[SCL] %s'):fmt(settings.enabled and 'Enabled.' or 'Hidden.'));
    elseif sub == 'config' or sub == 'settings' then
        state.config_open[1] = not state.config_open[1];
        if state.config_open[1] then
            state.config_size_initialized = false;
        end
    elseif sub == 'history' or sub == 'log' then
        history.toggle();
    elseif sub == 'session' then
        state.session_open[1] = not state.session_open[1];
        state.session_geometry_initialized = false;
        if (args[3] or ''):lower() == 'reset' then
            session.reset();
            state.session_open[1] = true;
            print('[SCL] Session reset.');
        end
    elseif sub == 'debug' then
        debuglog.set_enabled(not state.debug);
    elseif sub == 'pause' then
        state.paused = not state.paused;
        print(('[SCL] %s'):fmt(state.paused and 'Paused.' or 'Resumed.'));
    elseif sub == 'lock' then
        settings.locked = true;
        state.move_mode = false;
        core.save_settings();
        print('[SCL] Positions locked. Move handles hidden.');
    elseif sub == 'unlock' then
        settings.locked = false;
        state.move_mode = true;
        state.move_initialized.incoming = false;
        state.move_initialized.outgoing = false;
        state.move_initialized.notification = false;
        core.save_settings();
        print('[SCL] Positions unlocked. Drag the Incoming / Outgoing / Notifications handles.');
    elseif sub == 'clear' then
        state.events = {};
        render.hide_unused_fonts(1);
    elseif sub == 'test' then
        ui.add_test_events();
    elseif sub == 'help' then
        print('[SCL] /scl - toggle display');
        print('[SCL] /scl config - open configuration');
        print('[SCL] /scl session - session summary window (/scl session reset)');
        print('[SCL] /scl history - the last 50 events of each side');
        print('[SCL] /scl debug - log unmapped messages to addons\\scrollingcombatlog\\logs');
        print('[SCL] /scl test - show sample scrolling events');
        print('[SCL] /scl unlock - unlock positions and show draggable anchors');
        print('[SCL] /scl lock - lock positions and hide draggable anchors');
        print('[SCL] /scl pause - pause/resume capture');
        print('[SCL] /scl clear - clear active events');
        print('[SCL] Only completed actions are shown; "readies" / "starts casting" are never displayed.');
    end
end);

-- Low HP warning: once when your HP falls to the set percent, again only
-- after it has climbed back above it (+10%). Reads your own HP only.
local events = require('scl.events');
local low_hp = { armed = true, checked = 0 };

local function update_low_hp()
    local now = os.clock();
    if now - low_hp.checked < 0.2 then return; end
    low_hp.checked = now;
    if state.paused or not settings.enabled then return; end

    local hpp = nil;
    pcall(function()
        local mm = AshitaCore:GetMemoryManager();
        if mm:GetPlayer():GetIsZoning() ~= 0 then return; end
        hpp = tonumber(mm:GetParty():GetMemberHPPercent(0));
    end);
    if hpp == nil or hpp <= 0 then
        low_hp.armed = true;
        return;
    end

    local limit = tonumber(settings.low_hp_percent) or 25;
    if low_hp.armed and hpp <= limit then
        low_hp.armed = false;
        events.add_event('incoming', 'incoming', ('LOW HP  %d%%'):fmt(hpp), 'low_hp');
    elseif not low_hp.armed and hpp > limit + 10 then
        low_hp.armed = true;
    end
end

-- Food running out: "Food wears off in 20s", then every 5 seconds (15, 10,
-- 5). Reads your own status timers (the same math as the statustimers addon);
-- the "Food wore off" line itself comes from the game's wear-off message.
local FOOD_STATUS = 251;
local FOOD_MARKS = { 20, 15, 10, 5 };
local INFINITE_DURATION = 0x7FFFFFFF;
local VANA_BASE_STAMP = 0x3C307D70;
local food = { checked = 0, next_mark = 1, last_left = nil, utc_ptr = nil, utc_scanned = false };

-- The game's own UTC clock when it can be found (falls back to the PC clock).
local function game_utc_stamp()
    local now = os.time();
    if not food.utc_scanned then
        food.utc_scanned = true;
        pcall(function()
            food.utc_ptr = ashita.memory.find('FFXiMain.dll', 0, '8B0D????????8B410C8B49108D04808D04808D04808D04C1C3', 2, 0);
        end);
    end
    local ptr = food.utc_ptr;
    if ptr == nil or ptr == 0 then return now; end
    local ok, stamp = pcall(function()
        local p1 = ashita.memory.read_uint32(ptr);
        if p1 == nil or p1 == 0 then return nil; end
        local p2 = ashita.memory.read_uint32(p1);
        if p2 == nil or p2 == 0 then return nil; end
        return ashita.memory.read_uint32(p2 + 0x0C);
    end);
    if not ok or stamp == nil or stamp == 0 or math.abs(stamp - now) > 86400 then return now; end
    return stamp;
end

-- Seconds of food left, or nil when no food is active (-1 = no time limit).
local function food_seconds_left()
    local left = nil;
    pcall(function()
        local player = AshitaCore:GetMemoryManager():GetPlayer();
        local icons = player:GetStatusIcons();
        local timers = player:GetStatusTimers();
        for i = 1, 32 do
            if tonumber(icons[i]) == FOOD_STATUS then
                local raw = tonumber(timers[i]) or 0;
                if raw == INFINITE_DURATION then left = -1; return; end
                local real = raw - (game_utc_stamp() - VANA_BASE_STAMP) * 60;
                while real < -2147483648 do real = real + 0xFFFFFFFF; end
                left = (real < 1) and 0 or math.ceil(real / 60);
                return;
            end
        end
    end);
    return left;
end

local function update_food_watch()
    local now = os.clock();
    if now - food.checked < 0.25 then return; end
    food.checked = now;
    if state.paused or not settings.enabled then return; end

    local left = food_seconds_left();
    if left == nil or left < 0 then
        food.next_mark, food.last_left = 1, nil;
        return;
    end
    -- New food (more time than before): start over.
    if food.last_left ~= nil and left > food.last_left + 2 then food.next_mark = 1; end
    food.last_left = left;

    -- Skip marks that already passed (for example after a reload with 8s left)
    -- and announce only the latest one reached.
    local announce = nil;
    while FOOD_MARKS[food.next_mark] ~= nil and left <= FOOD_MARKS[food.next_mark] do
        if left > 0 then announce = FOOD_MARKS[food.next_mark]; end
        food.next_mark = food.next_mark + 1;
    end
    if announce ~= nil then
        -- Say the mark (20, 15, ...) when we are on it, the real time when we
        -- came in late (after a reload).
        local shown = (announce - left <= 1) and announce or math.max(1, left);
        events.add_event('incoming', 'ability', ('Food wears off in %ds'):fmt(shown), 'food_warning');
    end
end

-- Your character is in the world (not the title / character select screen,
-- where party memory still holds the last character's data). Same check as
-- Triage / XIUI: your entity is drawn (render flag 0x200) and not hidden
-- (0x4000).
local function logged_in()
    local ok, r = pcall(function()
        local idx = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
        if (tonumber(idx) or 0) == 0 then return false; end
        local flags = tonumber(AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags0(idx)) or 0;
        return bit.band(flags, 0x200) == 0x200 and bit.band(flags, 0x4000) == 0;
    end);
    if not ok then return true; end   -- can't tell: don't hide
    return r == true;
end

-- 1.4.0: the font of SCL's windows (settings.ui_font, Tahoma by default).
uifont.addon = 'scrollingcombatlog';
uifont.defaults(settings.ui_font);
uifont.set_global(settings.ui_font);
uifont.install_tooltips();
ashita.events.register('load', 'scl_scroll_load_cb', function()
    uifont.defaults(settings.ui_font);
    pcall(uifont.load, settings.ui_font);
end);

ashita.events.register('d3d_present', 'scl_scroll_present_cb', function()
    -- Settings can be replaced at login: keep the window font on them.
    if settings.ui_font ~= nil and settings.ui_font.font_family == nil then uifont.defaults(settings.ui_font); end
    uifont.set_global(settings.ui_font);
    -- Before you log in (title / character select) only the settings window
    -- can show: no combat text, session window or Move Mode handles.
    if not logged_in() then
        ui.draw_config();
        return;
    end
    update_low_hp();
    update_food_watch();
    rewards.update_exp_memory_watch();
    rewards.update_rest_watch();
    rewards.update_zone_banner();
    render.draw_events();
    ui.draw_config();
    ui.draw_session_window();
    pcall(history.draw);
    ui.draw_move_mode();
end);

ashita.events.register('unload', 'scl_scroll_unload_cb', function()
    render.destroy_font_pool();
    render.destroy_preview_font_pool();
    core.save_settings();
end);

print(('[SCL] Loaded version %s (self-only / packet-driven / completed actions only).'):fmt(addon.version));
