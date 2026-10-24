--[[
    MogSuite - modules/crafting/init.lua

    How MogSuite talks to the Crafting module.
]]

module_info = {
    key = 'crafting',
    label = 'Crafting',
    color = COLORS.wind,
    tooltip = 'Crafting skills, recipes, what you can make and your synthesis ledger',
};

state.visible[1] = config.visible == true;

function module_packet_in(e)
    if e.id == 0x06F then pcall(ledger_packet, e.data); end
end

function module_present()
    draw_crafting_window();
    if state.settings_dirty and (os.clock() - state.last_save) > 0.6 and not imgui.IsAnyItemActive() then
        state.settings_dirty = false;
        state.last_save = os.clock();
        settings.save();
    end
end

function module_settings_changed()
    state.visible[1] = config.visible == true;
    state.apply_geometry = true;
    state.list_cache = nil;
    state.counts_at = 0;
end

function module_unload() settings.save(); end

function module_toggle(force)
    if force == true then state.visible[1] = true; else state.visible[1] = not state.visible[1]; end
    state.apply_geometry = true;
    config.visible = state.visible[1];
    mark_dirty();
end

function module_close_all() state.visible[1] = false; end
function module_is_open() return state.visible[1] == true; end

function module_reset_position()
    config.window.x, config.window.y, config.window.w, config.window.h = -1, -1, 900, 620;
    state.apply_geometry = true;
    mark_dirty();
end

function module_is_locked() return config.locked == true; end
function module_set_locked(v) config.locked = v == true; mark_dirty(); end
