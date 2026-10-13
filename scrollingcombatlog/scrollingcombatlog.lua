addon.name    = 'scrollingcombatlog';
addon.author  = 'Izumi (ShiroIzumi)';
addon.version = '1.3.2';
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

ashita.events.register('d3d_present', 'scl_scroll_present_cb', function()
    update_low_hp();
    rewards.update_exp_memory_watch();
    rewards.update_rest_watch();
    rewards.update_zone_banner();
    render.draw_events();
    ui.draw_config();
    ui.draw_session_window();
    ui.draw_move_mode();
end);

ashita.events.register('unload', 'scl_scroll_unload_cb', function()
    render.destroy_font_pool();
    render.destroy_preview_font_pool();
    core.save_settings();
end);

print(('[SCL] Loaded version %s (self-only / packet-driven / completed actions only).'):fmt(addon.version));
