--[[
    MogSuite - modules/calendar/init.lua

    How MogSuite talks to the Calendar module.
]]

module_info = {
    key = 'calendar',
    label = 'Calendar',
    color = COLORS.light,
    tooltip = "Vana'diel days, moon, conquest, your timers and events",
};

local function logged_in()
    local name = '';
    pcall(function() name = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0) or ''; end);
    return tostring(name) ~= '', tostring(name);
end

state.visible[1] = config.visible == true;

function module_present()
    local ok, name = logged_in();
    if not ok then
        state.login_name = nil;
        return;
    end
    -- Login summary a few seconds after a (new) character is in the game.
    if state.login_name ~= name then
        state.login_name = name;
        state.login_at = os.clock();
        state.login_shown = false;
    end
    if not state.login_shown and state.login_at ~= nil and os.clock() - state.login_at > 6 then
        state.login_shown = true;
        -- Timers already ready before you logged in are not "new".
        for _, tm in ipairs(config.timers or {}) do
            if timer_status(tm) == 'ready' then state.ready_seen[tm.id] = true; end
        end
        pcall(show_login);
    end
    if state.login_shown then pcall(check_notices); end

    draw_calendar_window();
    draw_popups();

    if state.settings_dirty and (os.clock() - state.last_save) > 0.6 and not imgui.IsAnyItemActive() then
        state.settings_dirty = false;
        state.last_save = os.clock();
        settings.save();
    end
end

function module_settings_changed()
    state.visible[1] = config.visible == true;
    state.apply_geometry = true;
    state.ready_seen = {};
    state.login_name = nil;
end

function module_unload() settings.save(); end

function module_toggle(force)
    if force == true then state.visible[1] = true; else state.visible[1] = not state.visible[1]; end
    state.apply_geometry = true;
    config.visible = state.visible[1];
    mark_dirty();
end

function module_close_all()
    state.visible[1] = false;
    state.login_lines = nil;
    state.toast = nil;
end

function module_is_open() return state.visible[1] == true; end

function module_reset_position()
    config.window.x, config.window.y, config.window.w, config.window.h = -1, -1, 820, 600;
    state.apply_geometry = true;
    mark_dirty();
end

function module_is_locked() return config.locked == true; end
function module_set_locked(v) config.locked = v == true; mark_dirty(); end
