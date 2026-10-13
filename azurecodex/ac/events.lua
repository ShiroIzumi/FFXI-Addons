--[[
    Azure Codex - ac/events.lua

    Ashita events: commands, unload, the per-frame draw, and packets.
]]

ashita.events.register('command', 'bluspells_command_cb', function(e)
    if e == nil or e.command == nil then return; end

    local args = e.command:args();
    if #args == 0 then return; end

    local command = tostring(args[1] or ''):lower();

    -- Direct Zone Info aliases. These do not toggle the main BLUSpells window.
    if command == '/acz' or command == '/azurecodexzone' or command == '/bsz' or command == '/bluspellszone' then
        e.blocked = true;

        state.zone_info_open[1] = not state.zone_info_open[1];
        state.zone_apply_saved_geometry = true;

        if state.zone_info_open[1] then
            state.zone_reset_scroll = true;
        end

        return;
    end

    if command ~= '/azurecodex' and command ~= '/ac'
        and command ~= '/bluspells' and command ~= '/bsp' and command ~= '/bsl' then return; end

    e.blocked = true;

    if #args >= 2 and tostring(args[2]):lower() == 'config' then
        state.config_open[1] = not state.config_open[1];
        return;
    end
    if #args >= 2 and tostring(args[2]):lower() == 'farm' then
        state.farm_open[1] = not state.farm_open[1];
        state.farm_apply_geometry = true;
        return;
    end
    if #args >= 2 and tostring(args[2]):lower() == 'log' then
        state.log_open[1] = not state.log_open[1];
        state.log_apply_geometry = true;
        return;
    end

    state.open[1] = not state.open[1];

    if not state.open[1] then
        state.config_open[1] = false;
        state.location_open[1] = false;
        state.location_spell = nil;
        state.zone_info_open[1] = false;
        state.build_page[1] = false;
        state.spellsets_page[1] = false;
        state.bluprint_view_page[1] = false;
    end
end);

ashita.events.register('unload', 'bluspells_unload_cb', function()
    save_config();
end);

ashita.events.register('d3d_present', 'bluspells_present_cb', function()
    -- Runs every frame (cheap unless a spell was just learned) so the
    -- Learned Log records the right time / zone / mob even with the main
    -- window closed.
    update_known_snapshot();
    update_set_cooldown();
    draw_window();
    draw_set_cooldown_window();
    draw_farm_window();
    draw_log_window();
    draw_target_tag();
    draw_mouse_pointer();
end);

-- 0x028: note which blue spells a mob has used (Target Tag "and has been
-- used!"; finished TP moves only).
-- 0x029: remember the last mob you (or your party) defeated, so the Learned
-- Log can say which mob taught a spell. Messages 6 / 20 = defeated.
ashita.events.register('packet_in', 'azurecodex_packet_in_cb', function(e)
    if e == nil then return; end
    if e.id == 0x028 then
        note_mob_ability(e);
        return;
    end
    if e.id ~= 0x029 or e.data_modified == nil then return; end
    local ok, target_index, message = pcall(function()
        return struct.unpack('H', e.data_modified, 0x16 + 1), struct.unpack('H', e.data_modified, 0x18 + 1);
    end);
    if not ok then return; end
    message = bit.band(tonumber(message) or 0, 0x7FFF);
    if message ~= 6 and message ~= 20 then return; end

    -- The defeated mob (0x08 = target id): forget the moves it used, since it
    -- respawns with the same id.
    pcall(function() mob_used_forget(struct.unpack('I', e.data_modified, 0x08 + 1)); end);

    local ok_name, name = pcall(function()
        local entity = AshitaCore:GetMemoryManager():GetEntity();
        local flags = tonumber(entity:GetSpawnFlags(target_index)) or 0;
        if bit.band(flags, 0x10) == 0 then return nil; end
        return entity:GetName(target_index);
    end);
    if ok_name and name ~= nil and tostring(name) ~= '' then
        state.last_defeat = { name = tostring(name), time = os.time(), zone = safe_current_zone_id() };
    end
end);
