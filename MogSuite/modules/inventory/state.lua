--[[
    MogSuite - modules/inventory/state.lua

    Runtime state of the inventory windows, and Ctrl / Alt / Shift from Windows.
]]

-- ============================================================================
-- State
-- ============================================================================

state = {
    visible = { config.visible ~= false },
    main_rt = { search = { '' }, cache = nil, key = nil, apply_geometry = true },
    pop_rt = {},               -- [bag] = runtime bits of a pop-out window
    hidden = config.hidden == true, -- open key hid every window
    view_gen = 0,              -- bumped when rows / favorites change
    settings_dirty = false,
    last_save = 0,

    rows_dirty = true,
    last_scan = 0,
    bags = {},                 -- [bag] = { max, used, rows = {} }
    bag_order = {},            -- visible bag ids in order
    gil = 0,
    equipped = {},             -- ['bag:index'] = slot id

    prev_counts = nil,         -- [bag] = { [item_id] = count }
    baseline_until = 0,        -- ignore count changes until this clock (zoning)
    new_at = {},               -- [bag] = { [item_id] = clock }
    first_seen = {},           -- [item_id] = clock (for "newest" sort)

    -- 1.1.0
    log = {},                  -- session loot log: { time, id, qty }
    log_visible = { false },
    apply_log_geometry = true,
    session_start = os.time(),
    session_gil = nil,         -- gil at session start
    prev_totals = nil,         -- [item_id] = count across carried bags
    warn_until = 0,            -- inventory-full banner shown until (clock)
    last_inv_used = nil,
    key_items = nil,           -- { {id, name} } cache for the Key Items tab
    key_items_at = 0,
    player_name = nil,

    ctx = nil,                 -- row for the right-click menu
    drop = nil,                -- { row, qty, armed_at } for the drop dialog
    mods = { ctrl = false, alt = false, shift = false },
};

function mark_dirty() state.settings_dirty = true; end

-- Real Ctrl / Alt / Shift state from Windows. Tracking them from key events
-- alone can get stuck (e.g. Alt+Tab: the Alt release goes to another
-- window), which made the open key stop working until a reload.
pcall(ffi.cdef, 'short __stdcall GetAsyncKeyState(int vKey);');

function mod_down(vk, fallback)
    local ok, v = pcall(function() return ffi.C.GetAsyncKeyState(vk); end);
    if ok and v ~= nil then return bit.band(tonumber(v) or 0, 0x8000) ~= 0; end
    return fallback == true;
end

function current_mods()
    state.mods.ctrl = mod_down(0x11, state.mods.ctrl);
    state.mods.alt = mod_down(0x12, state.mods.alt);
    state.mods.shift = mod_down(0x10, state.mods.shift);
    return state.mods;
end

-- The window being drawn: V = its settings (config for the main window, a
-- pop-out entry otherwise), VS = its runtime bits (search, row cache).
V, VS = config, state.main_rt;
