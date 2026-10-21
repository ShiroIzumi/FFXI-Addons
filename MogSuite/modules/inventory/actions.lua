--[[
    MogSuite - modules/inventory/actions.lua

    Use / Equip / Drop (only ever when you click), favorites and item values.
]]

-- ============================================================================
-- Actions (only ever on click)
-- ============================================================================

function queue(cmd)
    AshitaCore:GetChatManager():QueueCommand(1, cmd);
end

function do_use(row)
    queue(('/item "%s" <me>'):fmt(row.info.name));
end

function do_equip(row, slot)
    local s = EQUIP_SLOTS[slot];
    if s == nil then return; end
    queue(('/equip %s "%s"'):fmt(s, row.info.name));
end

-- Drop: the same packet the game's own Drop sends (0x028: quantity, bag, slot).
function do_drop(row, qty)
    qty = math.max(1, math.min(tonumber(qty) or 1, row.count));
    local data = {
        0x28, 0x06, 0x00, 0x00,
        bit.band(qty, 0xFF), bit.band(bit.rshift(qty, 8), 0xFF), bit.band(bit.rshift(qty, 16), 0xFF), bit.band(bit.rshift(qty, 24), 0xFF),
        row.bag, row.index, 0x00, 0x00,
    };
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x28, data);
    state.rows_dirty = true;
end

function is_favorite(row)
    return config.favorites ~= nil and config.favorites[row.id] == true;
end

-- Can your current job / level wear this? (true for non-gear)
function can_wear(info)
    if info.type ~= TYPE_WEAPON and info.type ~= TYPE_ARMOR then return true; end
    local job, lvl = state.job or 0, state.level or 0;
    if job <= 0 then return true; end
    if (info.jobs or 0) ~= 0 and bit.band(info.jobs, bit.lshift(1, job)) == 0 then return false, 'job'; end
    if (info.level or 0) > lvl then return false, 'level'; end
    return true;
end

-- Live rows only (not snapshots or other characters).
function can_use(row)
    if row.source ~= nil then return false; end
    -- Enchanted gear (charges): usable while equipped, from any bag.
    if row.info.enchanted and row.equipped ~= nil then return true; end
    return row.info.type == TYPE_USABLE and (row.bag == 0 or row.bag == 3);
end

-- Enchanted gear in the list: " (19/30)" and, while it can't be used yet
-- (just equipped, or recharging), the time left like "3:20". The timer
-- disappears once the item is usable.
function enchant_suffix(row)
    if row == nil or row.info == nil or not row.info.enchanted or row.charges == nil then return nil, nil; end
    local charges = nil;
    if (row.info.charges or 0) > 0 then charges = (' (%d/%d)'):fmt(row.charges, row.info.charges); end
    local timer = nil;
    if row.ready_at ~= nil then
        local left = row.ready_at - os.time();
        if left > 0 then
            local h, m, s = math.floor(left / 3600), math.floor((left % 3600) / 60), left % 60;
            if h > 0 then timer = ('  %d:%02d:%02d'):fmt(h, m, s); else timer = ('  %d:%02d'):fmt(m, s); end
        end
    end
    return charges, timer;
end

-- Enchanted gear: (label, ready). Label like "Use  (2/5, ready in 3:20)".
function use_label(row)
    if not (row.info.enchanted and row.equipped ~= nil) then return 'Use', true; end
    local parts = {};
    if row.charges ~= nil and (row.info.charges or 0) > 0 then
        parts[#parts + 1] = ('%d/%d charges'):fmt(row.charges, row.info.charges);
    end
    local ready = true;
    if row.charges ~= nil and row.charges <= 0 then ready = false; end
    if row.ready_at ~= nil then
        local left = row.ready_at - os.time();
        if left > 0 then
            ready = false;
            local h, m, s = math.floor(left / 3600), math.floor((left % 3600) / 60), left % 60;
            if h > 0 then parts[#parts + 1] = ('ready in %d:%02d:%02d'):fmt(h, m, s);
            else parts[#parts + 1] = ('ready in %d:%02d'):fmt(m, s); end
        else
            parts[#parts + 1] = 'ready';
        end
    end
    if #parts == 0 then return 'Use', true; end
    return 'Use  (' .. table.concat(parts, ', ') .. ')', ready;
end

function can_equip(row)
    return row.source == nil and (row.info.type == TYPE_WEAPON or row.info.type == TYPE_ARMOR) and EQUIP_BAG[row.bag] == true
        and row.equipped == nil and #equip_slot_list(row.info) > 0;
end

function can_drop(row)
    return row.source == nil and row.bag == 0 and row.equipped == nil;
end

-- "Sells for ..." line and its color.
function value_line(row)
    local each, src = price_of(row.id);
    if src == 'nosale' then return "Can't be sold to NPCs", UI_MUTED; end
    if each == nil then return 'Sell price unknown (learned when a vendor appraises it)', UI_MUTED; end
    local t = ('Sells for %s gil'):fmt(fmt_gil(each));
    if row.count > 1 then t = t .. (' (%s for %d)'):fmt(fmt_gil(each * row.count), row.count); end
    t = t .. ((src == 'vendor') and '  [vendor]' or '  [price list]');
    return t, config.qty_color;
end

function rows_value(rows)
    local total, known = 0, 0;
    for _, row in ipairs(rows) do
        local each = price_of(row.id);
        if each ~= nil then
            total = total + each * row.count;
            known = known + 1;
        end
    end
    return total, known;
end
