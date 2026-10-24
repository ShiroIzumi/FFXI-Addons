--[[
    MogSuite - modules/inventory/init.lua

    How MogSuite talks to the Inventory module: present, packets, open key,
    settings changes and window helpers.
]]

module_info = {
    key = 'inventory',
    label = 'Inventory',
    color = COLORS.earth,
    tooltip = 'Every bag, key items, values and your other characters',
};

function save_config()
    config.visible = state.visible[1];
    config.hidden = state.hidden == true;
    settings.save();
end

-- Ashita replaced the settings table (login / character change).
function module_settings_changed()
    state.visible[1] = config.visible ~= false;
    state.hidden = config.hidden == true;
    state.main_rt = { search = { '' }, cache = nil, key = nil, apply_geometry = true };
    state.pop_rt = {};
    V, VS = config, state.main_rt;
    state.rows_dirty = true;
    state.prev_counts = nil;
    state.prev_totals = nil;
    state.prev_mh = nil;
    state.new_at = {};
    -- Possibly a different character: start fresh.
    save_chars(true);
    state.player_name = nil;
    state.bag_sig = nil;
    state.session_gil = nil;
    state.session_start = os.time();
    state.key_items = nil;
end

function module_packet_in(e)
    if e == nil then return; end
    local id = e.id;
    -- Inventory changes: refresh soon.
    if id == 0x01E or id == 0x01F or id == 0x020 or id == 0x01D or id == 0x050 then
        state.rows_dirty = true;
    elseif id == 0x00A or id == 0x00B then
        -- Zoning reloads the inventory; do not flag everything as new.
        state.prev_counts = nil;
        state.baseline_until = os.clock() + 8.0;
        state.rows_dirty = true;
        if id == 0x00B then save_chars(true); end
        if id == 0x00A then
            -- 1.5.3: a fresh key item list for whoever just logged in / zoned
            -- (the name comes from this packet, so another character's key
            -- items are never filed under you).
            state.ki_session = {};
            state.ki_login_name = nil;
            pcall(function()
                local n = tostring(e.data:sub(0x84 + 1, 0x84 + 16)):gsub('%z.*', '');
                if n:match('^%a%a%a+$') and #n <= 15 then state.ki_login_name = n; end
            end);
        end
    elseif id == 0x055 then
        -- Key item list: 64 bytes of "have" bits for one table of 512 ids.
        pcall(function()
            local d = e.data;
            if d == nil or #d < 0x85 then return; end
            local tbl = d:byte(0x84 + 1);
            local ids = {};
            for i = 0, 0x3F do
                local byte = d:byte(0x04 + i + 1);
                if byte ~= 0 then
                    for bitn = 0, 7 do
                        if bit.band(byte, bit.lshift(1, bitn)) ~= 0 then
                            ids[#ids + 1] = tbl * 512 + i * 8 + bitn;
                        end
                    end
                end
            end
            -- Kept for this session even if your name isn't known yet (login).
            local name = state.ki_login_name or get_player_name() or state.player_name;
            state.ki_session = state.ki_session or {};
            state.ki_session[tbl] = { owner = name, ids = ids };
            if name ~= nil then
                chars[name] = chars[name] or { bags = {}, mh_time = {} };
                chars[name].ki = chars[name].ki or {};
                chars[name].ki[tbl] = ids;
                chars_dirty = true;
            end
            state.key_items = nil;
        end);
    elseif id == 0x03D then
        -- Shop appraisal: the exact sell price (per item) for an inventory slot.
        pcall(function()
            local d = e.data;
            if d == nil or #d < 9 then return; end
            local price = d:byte(5) + d:byte(6) * 0x100 + d:byte(7) * 0x10000 + d:byte(8) * 0x1000000;
            local slot = d:byte(9);
            local item = get_inventory():GetContainerItem(0, slot);
            if item ~= nil and (tonumber(item.Id) or 0) > 0 then
                learn_price(tonumber(item.Id), price);
            end
        end);
    end
end

function module_present()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if player == nil then return; end

    pcall(function()
        state.job = tonumber(player:GetMainJob()) or 0;
        state.level = tonumber(player:GetMainJobLevel()) or 0;
    end);

    -- Scans: right after inventory packets, every second while the window
    -- is open, every few seconds otherwise (loot log, gil, full warning).
    local now = os.clock();
    local shown = not state.hidden and (state.visible[1] or #(config.popouts or {}) > 0);
    -- Closing the window clears the new-item highlights (sticky mode).
    if state.was_shown and not shown and config.new_sticky ~= false and next(state.new_at) ~= nil then
        state.new_at = {};
        state.view_gen = (state.view_gen or 0) + 1;
    end
    state.was_shown = shown;
    local interval = shown and 1.0 or 5.0;
    if (state.rows_dirty and now - state.last_scan >= 0.25) or now - state.last_scan >= interval then
        scan_bags();
    end
    save_chars(false);

    draw_main_window();
    draw_log_window();
    draw_watch_window();
    draw_stacks_window();
    if config.warn_full ~= false then draw_full_warning(); end

    if state.settings_dirty and (os.clock() - state.last_save) > 0.6 and not imgui.IsAnyItemActive() then
        state.settings_dirty = false;
        state.last_save = os.clock();
        save_config();
    end
end

function module_unload()
    save_config();
    save_chars(true);
end

-- Open key / command: hide everything that's showing, or show it again.
function module_toggle(force)
    if force == true then
        state.hidden = false;
        state.visible[1] = true;
        state.main_rt.apply_geometry = true;
        mark_dirty();
        return;
    end
    toggle_all();
end

-- Esc (core): hide the main window and every pop-out (same as the open key;
-- pop-outs you didn't close with X come back next time).
function module_close_all()
    if stacks ~= nil then stacks.open[1] = false; end
    local showing = (not state.hidden) and (state.visible[1] or #(config.popouts or {}) > 0);
    if showing then
        state.hidden = true;
        mark_dirty();
    end
end

function module_reset_position()
    config.window.x, config.window.y, config.window.w, config.window.h = 220, 180, 440, 560;
    state.main_rt.apply_geometry = true;
    mark_dirty();
end

-- Settings window sidebar: is the inventory window showing?
function module_is_open() return (not state.hidden) and state.visible[1] == true; end

function module_is_locked() return config.locked == true; end
function module_set_locked(v) config.locked = v == true; mark_dirty(); end
