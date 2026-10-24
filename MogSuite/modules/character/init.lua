--[[
    MogSuite - modules/character/init.lua

    How MogSuite talks to the Character module: present, packets, chat text,
    open key, settings changes and window helpers.
]]

module_info = {
    key = 'character',
    label = 'Character',
    color = COLORS.water,
    tooltip = 'Stats, resistances, jobs, skills, currencies and gear stats',
};

-- Ashita replaced the settings table (login / character change).
function module_settings_changed()
    apply_loaded_config();
    ensure_recap_config();
    ensure_progress_config();
    ensure_equip_config();
    stat_cache = {};
end

-- Skill-ups (0x029 message 38) and the Currencies list (0x113).
function module_packet_in(e)
    if e == nil or e.data_modified == nil then return; end

    if e.id == 0x028 then pcall(recap_packet, e); return; end
    if e.id == 0x056 or e.id == 0x05E or e.id == 0x032 or e.id == 0x034 or e.id == 0x055 then pcall(progress_packet, e); return; end
    -- 1.5.3: zone in / login starts a fresh key item list (another character may have logged in).
    if e.id == 0x00A then pcall(progress_packet, e); end

    -- Currencies (sent when you open Main Menu > Currencies).
    if e.id == 0x113 then
        local ok, values = pcall(parse_currencies, e.data_modified);
        if ok and values ~= nil and next(values) ~= nil then
            config.currencies = T{ at = os.time(), values = values };
            state.settings_dirty = true;
        end
        return;
    end

    if e.id ~= 0x029 then return; end

    local ok, actor, target, param1, param2, message = pcall(function()
        return struct.unpack('I', e.data_modified, 0x04 + 1),
               struct.unpack('I', e.data_modified, 0x08 + 1),
               struct.unpack('I', e.data_modified, 0x0C + 1),
               struct.unpack('I', e.data_modified, 0x10 + 1),
               struct.unpack('H', e.data_modified, 0x18 + 1);
    end);
    if not ok then return; end

    message = bit.band(tonumber(message) or 0, 0x7FFF);
    if message ~= 38 then return; end

    local self_id = tonumber(safe_call(get_party(), 'GetMemberServerId', 0)) or 0;
    if self_id == 0 or (tonumber(actor) ~= self_id and tonumber(target) ~= self_id) then return; end

    skillups.packet_at[tonumber(param1) or 0] = os.clock();
    record_skillup(param1, param2);
end

-- Fallback when the 0x029 message did not arrive: "<name>'s <skill> skill
-- rises 0.1 points." Ignored if the packet already counted it.
function module_text_in(e)
    if e == nil then return; end
    local line = tostring(e.message_modified or e.message or '');
    if line == '' or not line:lower():find('skill rises', 1, true) then return; end

    local me = tostring(safe_call(get_party(), 'GetMemberName', 0) or '');
    if me == '' or not line:find(me, 1, true) then return; end

    -- Strip FFXI colour / control codes before matching.
    line = line:gsub('\30.', ''):gsub('\31.', ''):gsub('[%c]', ' ');
    local skill_name, rise = line:match("'s%s+([%a][%a%s%-]-)%s+[Ss]kill%s+[Rr]ises%s+(%d+%.?%d*)%s+[Pp]oint");
    if skill_name == nil then return; end

    local id = skill_lookup().by_name[skill_name:lower()];
    if id == nil then return; end
    local at = skillups.packet_at[id];
    if at ~= nil and (os.clock() - at) < 1.5 then return; end

    record_skillup(id, math.floor((tonumber(rise) or 0) * 10 + 0.5));
end

function module_present()
    draw_main();
    local ok, err = pcall(draw_equip_panel);
    if not ok then print('[MogSuite] gear panel: ' .. tostring(err)); equip_panel.open[1] = false; end
    pcall(recap_watch);
    draw_recap_window();

    -- Closing with the title bar's X also counts as a change to save.
    if state.open[1] ~= state.last_open then
        state.last_open = state.open[1];
        state.settings_dirty = true;
    end

    if (state.geometry_dirty or state.settings_dirty) and (os.clock() - state.last_save) >= 0.50 then
        save_config();
        state.geometry_dirty = false;
        state.settings_dirty = false;
        state.last_save = os.clock();
    end
end

function module_unload()
    save_config();
end

function module_toggle(force)
    if force == true then
        state.open[1] = true;
        state.apply_saved_geometry = true;
        state.settings_dirty = true;
        return;
    end
    toggle_sheet();
end

-- Esc (core): close the character sheet.
function module_close_all()
    if state.open[1] then
        state.open[1] = false;
        state.settings_dirty = true;
    end
    equip_panel.open[1] = false;
    recap.open[1] = false;
end

function module_reset_position()
    state.last_x, state.last_y = 120, 100;
    state.last_w, state.last_h = 600 * state.ui_scale[1], 660 * state.ui_scale[1];
    state.apply_saved_geometry = true;
    state.settings_dirty = true;
end

-- Settings window sidebar: is the Character window showing?
function module_is_open() return state.open[1] == true; end

function module_is_locked() return state.locked[1] == true; end
function module_set_locked(v) state.locked[1] = v == true; state.settings_dirty = true; end
