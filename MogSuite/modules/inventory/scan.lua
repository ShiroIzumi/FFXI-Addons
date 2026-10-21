--[[
    MogSuite - modules/inventory/scan.lua

    Reads every bag, tracks new items, the loot log and gil, saves every character's
    bags, and builds the filtered / sorted rows for each window.
]]

function get_player_name()
    local name = nil;
    pcall(function()
        name = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0);
    end);
    if name == nil or tostring(name) == '' then return nil; end
    return tostring(name);
end

function save_chars(force)
    if not chars_dirty and not force then return; end
    if not force and os.clock() - chars_saved_at < 20 then return; end
    chars_dirty = false;
    chars_saved_at = os.clock();
    write_lua_file(DATA_DIR .. 'characters.lua', chars);
end

-- Bags you carry (count toward the loot log); Mog House bags do not.
CARRIED_BAG = { [0] = true, [3] = true, [5] = true, [6] = true, [7] = true, [8] = true,
    [10] = true, [11] = true, [12] = true, [13] = true, [14] = true, [15] = true, [16] = true };

function rows_from_list(list, bag, source, char)
    local rows = {};
    for k, e in ipairs(list or {}) do
        local id, count = tonumber(e[1]) or 0, tonumber(e[2]) or 0;
        local info = get_item_info(id);
        if info ~= nil and count > 0 then
            rows[#rows + 1] = {
                bag = bag, index = k, id = id, count = count, info = info, source = source, char = char,
                uid = ('%s_%s_%d_%d'):fmt(source or 'live', tostring(char or ''), bag, k),
            };
        end
    end
    return rows;
end

-- Marks partial stacks of the same item in one bag (they could be merged).
function mark_split(rows)
    local groups = {};
    for _, r in ipairs(rows) do
        local st = tonumber(r.info.stack) or 1;
        if st > 1 and r.count < st then
            groups[r.id] = groups[r.id] or {};
            table.insert(groups[r.id], r);
        end
    end
    for _, g in pairs(groups) do
        if #g >= 2 then
            local total = 0;
            for _, r in ipairs(g) do total = total + r.count; end
            for _, r in ipairs(g) do r.split = #g; r.split_total = total; end
        end
    end
end

function list_signature(list)
    local parts = {};
    for _, e in ipairs(list) do parts[#parts + 1] = e[1] .. 'x' .. e[2]; end
    return table.concat(parts, ',');
end

-- Reads every bag. Runs on inventory packets, about once a second while the
-- window is open, and every few seconds in the background (loot log / gil).
-- Enchanted gear (Chariot Band, Warp Cudgel...): charges left and when it can
-- be used next, read the same way as Ashita's own libs\ffxi\itemdata.lua:
-- item.Extra is a string of raw bytes; byte 0 = 1 (timer item), byte 1 =
-- charges left, bytes 2-3 flags, bytes 4-7 next-use time, bytes 8-11
-- usable-after-equip time (game timestamps). The equip delay only counts
-- while the item is equipped. Returns charges, ready_at (os.time) or nil.
local FFXI_EPOCH = 0x3C307D70;
local timelib = nil;
pcall(function() timelib = require('ffxi.time'); end);

local function xbyte(x, o)
    if type(x) == 'string' then return string.byte(x, o + 1) or 0; end
    return tonumber(x[o]) or 0;   -- cdata (0-based)
end
local function xu32(x, o)
    return xbyte(x, o) + xbyte(x, o + 1) * 0x100 + xbyte(x, o + 2) * 0x10000 + xbyte(x, o + 3) * 0x1000000;
end
-- Seconds from now until a game timestamp (0 when it has passed).
local function secs_until(raw)
    if raw == nil or raw == 0 then return 0; end
    if timelib ~= nil and timelib.game_time_diff ~= nil then
        local ok, d = pcall(timelib.game_time_diff, raw);
        if ok and d ~= nil then return math.max(0, tonumber(d) or 0); end
    end
    return math.max(0, raw + FFXI_EPOCH - os.time());
end

function read_enchant(item, equipped)
    local ok, charges, ready = pcall(function()
        local x = item.Extra;
        if x == nil then return nil, nil; end
        if xbyte(x, 0) ~= 1 then return nil, nil; end
        local c = xbyte(x, 1);
        local wait = secs_until(xu32(x, 4));
        if equipped then wait = math.max(wait, secs_until(xu32(x, 8))); end
        local r = nil;
        if c > 0 and wait > 0 and wait < 8 * 86400 then r = os.time() + math.ceil(wait); end
        return c, r;
    end);
    if not ok then return nil, nil; end
    return charges, ready;
end

function scan_bags()
    local inv = get_inventory();
    if inv == nil then return; end
    local now = os.clock();

    state.player_name = get_player_name() or state.player_name;
    local me = nil;
    if state.player_name ~= nil then
        me = chars[state.player_name];
        if me == nil then
            me = { bags = {}, mh_time = {} };
            chars[state.player_name] = me;
        end
        me.bags = me.bags or {};
        me.mh_time = me.mh_time or {};
        state.bag_sig = state.bag_sig or {};
    end

    -- Equipped items.
    local equipped = {};
    for slot = 0, 15 do
        local ok, e = pcall(function() return inv:GetEquippedItem(slot); end);
        if ok and e ~= nil and tonumber(e.Index) ~= nil and tonumber(e.Index) ~= 0 then
            local idx = tonumber(e.Index);
            local bag = math.floor(bit.band(idx, 0xFF00) / 0x100);
            local pos = idx % 0x100;
            equipped[('%d:%d'):fmt(bag, pos)] = slot;
        end
    end
    state.equipped = equipped;

    local bags, order = {}, {};
    local counts, totals, mh_totals = {}, {}, {};
    local equip_use_rows = {};
    for bag = 0, BAG_MAX_ID do
        local ok_max, max = pcall(function() return inv:GetContainerCountMax(bag); end);
        max = ok_max and (tonumber(max) or 0) or 0;
        local rows, used = {}, 0;
        if max > 0 then
            counts[bag] = {};
            for index = 1, max do
                local ok, item = pcall(function() return inv:GetContainerItem(bag, index); end);
                if ok and item ~= nil then
                    local id = tonumber(item.Id) or 0;
                    local count = tonumber(item.Count) or 0;
                    if id > 0 and id ~= 65535 and count > 0 then
                        used = used + 1;
                        local info = get_item_info(id);
                        if info ~= nil then
                            local row = {
                                bag = bag, index = index, id = id, count = count, info = info,
                                equipped = equipped[('%d:%d'):fmt(bag, index)],
                                uid = ('live_%d_%d'):fmt(bag, index),
                            };
                            if info.enchanted then
                                -- Charges (and the usable-again time) for every copy, worn or not.
                                row.charges, row.ready_at = read_enchant(item, row.equipped ~= nil);
                                -- Equipped from a wardrobe: also shown (blue) in Inventory.
                                if row.equipped ~= nil and bag ~= 0 then equip_use_rows[#equip_use_rows + 1] = row; end
                            end
                            rows[#rows + 1] = row;
                            counts[bag][id] = (counts[bag][id] or 0) + count;
                            if CARRIED_BAG[bag] then totals[id] = (totals[id] or 0) + count; end
                            if VIEW_ONLY_BAG[bag] then mh_totals[id] = (mh_totals[id] or 0) + count; end
                            if state.first_seen[id] == nil then state.first_seen[id] = now; end
                        end
                    end
                end
            end
        end

        -- Remember this character's bags (Characters tab, Mog House snapshots).
        if me ~= nil and used > 0 then
            local list = {};
            for _, r in ipairs(rows) do list[#list + 1] = { r.id, r.count }; end
            local sig = list_signature(list);
            if state.bag_sig[bag] ~= sig then
                state.bag_sig[bag] = sig;
                me.bags[bag] = list;
                me.updated = os.time();
                if VIEW_ONLY_BAG[bag] then me.mh_time[bag] = os.time(); end
                chars_dirty = true;
            end
        end

        if VIEW_ONLY_BAG[bag] and used == 0 and me ~= nil and me.bags[bag] ~= nil and #me.bags[bag] > 0 then
            -- Not loaded right now: show the last snapshot (view only).
            local snap = rows_from_list(me.bags[bag], bag, 'snapshot', nil);
            mark_split(snap);
            bags[bag] = { max = math.max(max, #snap), used = #snap, rows = snap, snapshot = me.mh_time[bag] };
        elseif max > 0 then
            mark_split(rows);
            bags[bag] = { max = max, used = used, rows = rows };
        end
    end
    for _, bag in ipairs(TAB_ORDER) do
        if bags[bag] ~= nil and not (config.hidden_bags and config.hidden_bags[bag]) then
            if bag ~= 3 or bags[bag].used > 0 then order[#order + 1] = bag; end
        end
    end

    -- Gil lives in inventory slot 0.
    local inv_loaded = bags[0] ~= nil and bags[0].used > 0;
    local ok_gil, gil = pcall(function() return inv:GetContainerItem(0, 0); end);
    if ok_gil and gil ~= nil and inv_loaded then
        state.gil = tonumber(gil.Count) or state.gil;
        if state.session_gil == nil then state.session_gil = state.gil; end
        local today = os.date('%Y-%m-%d');
        if config.gil_day ~= today or (tonumber(config.gil_day_start) or -1) < 0 then
            config.gil_day = today;
            config.gil_day_start = state.gil;
            mark_dirty();
        end
    end

    local settled = now > state.baseline_until;

    -- New-item highlight: count went up in a bag since the last scan.
    if state.prev_counts ~= nil and settled then
        for bag, ids in pairs(counts) do
            local before = state.prev_counts[bag];
            if before ~= nil then
                for id, count in pairs(ids) do
                    if count > (before[id] or 0) then
                        state.new_at[bag] = state.new_at[bag] or {};
                        state.new_at[bag][id] = now;
                        state.first_seen[id] = now;
                    end
                end
            end
        end
    end

    -- Loot log: items gained across carried bags (moves between them don't
    -- count, and neither does taking things out of Mog House storage).
    if state.prev_totals ~= nil and settled then
        local prev_mh = state.prev_mh or {};
        for id, count in pairs(totals) do
            local gain = count - (state.prev_totals[id] or 0);
            if gain > 0 then
                local from_mh = (prev_mh[id] or 0) - (mh_totals[id] or 0);
                if from_mh > 0 then gain = gain - from_mh; end
                if gain > 0 then
                    table.insert(state.log, 1, { time = os.time(), id = id, qty = gain });
                end
            end
        end
        while #state.log > 300 do table.remove(state.log); end
    end

    -- Inventory-full warning when a new item arrives near the limit.
    local inv0 = bags[0];
    if inv0 ~= nil and inv_loaded then
        local free = inv0.max - inv0.used;
        if config.warn_full and settled and state.last_inv_used ~= nil and inv0.used > state.last_inv_used
            and free <= (tonumber(config.warn_free) or 5) then
            state.warn_until = now + 5.0;
        end
        state.last_inv_used = inv0.used;
    end

    -- An empty inventory usually means zoning / loading: rebase.
    if not inv_loaded then
        state.prev_counts = nil;
        state.prev_totals = nil;
        state.prev_mh = nil;
        state.last_inv_used = nil;
        state.baseline_until = now + 3.0;
    else
        state.prev_counts = counts;
        state.prev_totals = totals;
        state.prev_mh = mh_totals;
    end

    state.bags = bags;
    state.bag_order = order;
    -- Mirror rows for the Inventory tab: equipped usable gear from other bags.
    local mirrors = {};
    for _, r in ipairs(equip_use_rows) do
        local m = {};
        for k, v in pairs(r) do m[k] = v; end
        m.mirror = true;
        m.uid = 'mirror_' .. r.uid;
        mirrors[#mirrors + 1] = m;
    end
    state.equip_use_rows = mirrors;
    state.view_gen = state.view_gen + 1;
    state.rows_dirty = false;
    state.last_scan = now;
end

-- ============================================================================
-- Filtering / sorting (cached per scan + settings)
-- ============================================================================

function row_matches_filter(row, filter)
    local info = row.info;
    if filter == 'weapon' then return info.type == TYPE_WEAPON; end
    if filter == 'armor' then return info.type == TYPE_ARMOR; end
    if filter == 'usable' then return info.type == TYPE_USABLE; end
    if filter == 'crystal' then return info.type == TYPE_CRYSTAL; end
    if filter == 'material' then
        return info.type ~= TYPE_WEAPON and info.type ~= TYPE_ARMOR and info.type ~= TYPE_USABLE and info.type ~= TYPE_CRYSTAL;
    end
    if filter == 'rareex' then return info.rare or info.ex; end
    if filter == 'favorites' then return config.favorites ~= nil and config.favorites[row.id] == true; end
    return true;
end

function get_view_rows()
    local key = table.concat({ tostring(state.view_gen), tostring(V.bag), tostring(V.filter), tostring(VS.search[1] or ''):lower(),
        tostring(V.sort), tostring(V.sort_desc), tostring(V.view), tostring(config.pin_favorites) }, '|');
    if VS.cache ~= nil and VS.key == key then return VS.cache; end

    local query = tostring(VS.search[1] or ''):lower():gsub('^%s+', ''):gsub('%s+$', '');
    local rows = {};
    local function add_bag(bag)
        local b = state.bags[bag];
        if b == nil then return; end
        for _, row in ipairs(b.rows) do
            if row_matches_filter(row, V.filter)
                and (query == '' or row.info.name_lower:find(query, 1, true) ~= nil) then
                rows[#rows + 1] = row;
            end
        end
    end
    local function add_rows(list)
        for _, row in ipairs(list) do
            if row_matches_filter(row, V.filter)
                and (query == '' or row.info.name_lower:find(query, 1, true) ~= nil) then
                rows[#rows + 1] = row;
            end
        end
    end
    if V.bag == -1 then
        for _, bag in ipairs(state.bag_order) do add_bag(bag); end
    elseif V.bag == -2 then
        -- Every character's last known bags (view only).
        for name, rec in pairs(chars) do
            for bag, list in pairs(rec.bags or {}) do
                add_rows(rows_from_list(list, tonumber(bag) or 0, 'alt', name));
            end
        end
    else
        add_bag(V.bag);
        -- Inventory tab: equipped gear with a Use (charges) that sits in a
        -- wardrobe or other bag also shows here, in blue, so you can use it.
        if V.bag == 0 then add_rows(state.equip_use_rows or {}); end
    end

    local mode, desc = V.sort, V.sort_desc == true;
    local pin = config.pin_favorites ~= false and V.view ~= 'categories';
    local favs = config.favorites or {};
    table.sort(rows, function(a, b)
        if pin then
            local fa, fb = favs[a.id] == true, favs[b.id] == true;
            if fa ~= fb then return fa; end
        end
        if V.bag == -2 and a.char ~= b.char and mode == 'slot' then
            return tostring(a.char) < tostring(b.char);
        end
        local av, bv;
        if mode == 'name' then av, bv = a.info.name_lower, b.info.name_lower;
        elseif mode == 'type' then av, bv = a.info.type, b.info.type;
        elseif mode == 'qty' then av, bv = a.count, b.count;
        elseif mode == 'newest' then av, bv = -(state.first_seen[a.id] or 0), -(state.first_seen[b.id] or 0);
        else av, bv = a.bag * 1000 + a.index, b.bag * 1000 + b.index; end
        if av == bv then
            if a.info.name_lower == b.info.name_lower then
                if a.char ~= b.char then return tostring(a.char) < tostring(b.char); end
                return (a.bag * 1000 + a.index) < (b.bag * 1000 + b.index);
            end
            return a.info.name_lower < b.info.name_lower;
        end
        if desc then return av > bv; end
        return av < bv;
    end);

    VS.cache = rows;
    VS.key = key;
    return rows;
end
