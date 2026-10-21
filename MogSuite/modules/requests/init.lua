--[[
    MogSuite - modules/requests/init.lua

    How MogSuite talks to the Requests module (party / alliance invites and
    trade requests). It has no window of its own: the popup shows when a
    request comes in.
]]

module_info = {
    key = 'requests',
    label = 'Requests',
    color = COLORS.wind,
    tooltip = 'Popups for party / alliance invites and trade requests',
    no_window = true,
};

-- Party invites carry an invite type (LandSandBoat: 0 = party, 5 = alliance).
local INVITE_ALLIANCE = 5;

-- A test popup: same look, but its buttons only close it.
function show_test(kind)
    show_popup(kind, 'Izumi', 0, 0, true);
end

function module_packet_in(e)
    local id = e.id;
    if id == 0x0DC then
        -- Party / alliance invite: 0x04 inviter id, 0x0B invite type, 0x0C name[16].
        local data = e.data_modified or e.data;
        if data == nil then return; end
        local name, kind = '', 'party';
        pcall(function() name = trim_zero(data:sub(0x0C + 1, 0x0C + 16)); end);
        pcall(function() if data:byte(0x0B + 1) == INVITE_ALLIANCE then kind = 'alliance'; end end);
        show_popup(kind, name);
    elseif id == 0x021 then
        -- Trade request: 0x04 requester id, 0x08 requester index.
        local data = e.data_modified or e.data;
        if data == nil then return; end
        local pid, pidx = 0, 0;
        pcall(function() pid = struct.unpack('L', data, 0x04 + 1); end);
        pcall(function() pidx = struct.unpack('H', data, 0x08 + 1); end);
        show_popup('trade', entity_name(pidx, 'Someone'), pid, pidx);
    elseif id == 0x022 then
        -- Trade window opened / cancelled / done: the request is answered.
        if state.popup.active and state.popup.kind == 'trade' then close_popup(); end
    end
end

-- You answered from the game's own menu or chat: close the popup.
function module_packet_out(e)
    local p = state.popup;
    if not p.active then return; end
    if e.id == 0x074 and p.kind ~= 'trade' then close_popup();       -- party invite answer
    elseif e.id == 0x033 and p.kind == 'trade' then close_popup(); end -- trade request answer
end

function module_present()
    local p = state.popup;
    if p.active then
        local limit = tonumber(config.auto_close) or 0;
        if limit > 0 and os.clock() - p.opened_at > limit then close_popup(); end
    end
    draw_popup();

    if state.settings_dirty and (os.clock() - state.last_save) > 0.6 and not imgui.IsAnyItemActive() then
        state.settings_dirty = false;
        state.last_save = os.clock();
        settings.save();
    end
end

function module_settings_changed()
    close_popup();
    state.apply_geometry = true;
end

function module_unload()
    settings.save();
end

function module_toggle() end

-- Esc (core): dismiss an open invite / trade popup. Nothing is sent; the
-- request stays open in the game's own menu.
function module_close_all()
    if state.popup ~= nil and state.popup.active then close_popup(); end
end

function module_reset_position()
    config.window.x, config.window.y = -1, -1;
    state.apply_geometry = true;
    mark_dirty();
end

function module_is_locked() return config.locked == true; end
function module_set_locked(v) config.locked = v == true; mark_dirty(); end
