--[[
    MogSuite - modules/actions/init.lua

    How MogSuite talks to the Actions module: present, packets, open key,
    settings changes and window helpers.
]]

module_info = {
    key = 'actions',
    label = 'Actions',
    color = COLORS.fire,
    tooltip = 'Abilities, weapon skills, magic and pet commands',
};

function save_config()
    config.visible = state.visible[1];
    settings.save();
end

-- Ashita replaced the settings table (login / character change).
function module_settings_changed()
    state.visible[1] = config.visible ~= false;
    state.apply_geometry = true;
    state.lists_key = nil;
    state.spell_cache = nil;
    state.selected = nil;
    ja_mode, ws_mode = nil, nil;
end

function module_packet_in(e)
    if e == nil then return; end
    -- Job change / zone: re-check what you have.
    if e.id == 0x00A or e.id == 0x01B or e.id == 0x0AC or e.id == 0x0AA then
        state.lists_key = nil;
        if e.id == 0x00A or e.id == 0x01B then ja_mode, ws_mode = nil, nil; end
    end
end

function module_present()
    local me = nil;
    pcall(function() me = read_player(); end);
    state.me = me;

    if me ~= nil and me.job > 0 and state.visible[1] then
        local any_pet_job = pet_job_active(me, me.job) or pet_job_active(me, me.sub);
        state.pet = any_pet_job and read_pet(me) or nil;
        if state.pet ~= nil then state.pet.owner = pet_owner(me, state.pet); end
        update_recasts();
        refresh_lists(me);
    end

    draw_main_window();

    if state.settings_dirty and (os.clock() - state.last_save) > 0.6 and not imgui.IsAnyItemActive() then
        state.settings_dirty = false;
        state.last_save = os.clock();
        save_config();
    end
end

function module_unload()
    save_config();
end

function module_toggle(force)
    if force == true then state.visible[1] = true; else state.visible[1] = not state.visible[1]; end
    state.apply_geometry = true;
    mark_dirty();
end

function module_reset_position()
    config.window.x, config.window.y, config.window.w, config.window.h = 260, 160, 470, 620;
    state.apply_geometry = true;
    mark_dirty();
end

function module_is_locked() return config.locked == true; end
function module_set_locked(v) config.locked = v == true; mark_dirty(); end
