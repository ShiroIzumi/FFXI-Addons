--[[
    MogSuite - modules/inventory/items.lua

    Bags, item info from the game resources, icons and small formatting helpers.
]]

C = ffi.C;

-- ============================================================================
-- Bags, items, icons
-- ============================================================================

BAG_NAMES = {
    [0] = 'Inventory', [1] = 'Safe', [2] = 'Storage', [3] = 'Temporary',
    [4] = 'Locker', [5] = 'Satchel', [6] = 'Sack', [7] = 'Case',
    [8] = 'Wardrobe', [9] = 'Safe 2', [10] = 'Wardrobe 2', [11] = 'Wardrobe 3',
    [12] = 'Wardrobe 4', [13] = 'Wardrobe 5', [14] = 'Wardrobe 6', [15] = 'Wardrobe 7',
    [16] = 'Wardrobe 8',
};
BAG_MAX_ID = 16;
-- Tab order (bags you don't have are skipped).
TAB_ORDER = { 0, 1, 5, 9, 8, 10, 11, 12, 13, 14, 15, 16, 2, 4, 6, 7, 3 };
-- Mog House storage: shown for viewing, no actions.
VIEW_ONLY_BAG = { [1] = true, [2] = true, [4] = true, [9] = true };
EQUIP_BAG = { [0] = true, [8] = true, [10] = true, [11] = true, [12] = true,
    [13] = true, [14] = true, [15] = true, [16] = true };

EQUIP_SLOTS = {
    [0] = 'main', [1] = 'sub', [2] = 'range', [3] = 'ammo', [4] = 'head', [5] = 'body',
    [6] = 'hands', [7] = 'legs', [8] = 'feet', [9] = 'neck', [10] = 'waist', [11] = 'ear1',
    [12] = 'ear2', [13] = 'ring1', [14] = 'ring2', [15] = 'back',
};
SLOT_LABELS = {
    [0] = 'Main', [1] = 'Sub', [2] = 'Range', [3] = 'Ammo', [4] = 'Head', [5] = 'Body',
    [6] = 'Hands', [7] = 'Legs', [8] = 'Feet', [9] = 'Neck', [10] = 'Waist', [11] = 'Ear 1',
    [12] = 'Ear 2', [13] = 'Ring 1', [14] = 'Ring 2', [15] = 'Back',
};
JOBS = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG',
    'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH' };

TYPE_WEAPON, TYPE_ARMOR, TYPE_USABLE, TYPE_CRYSTAL = 4, 5, 7, 8;
FLAG_RARE, FLAG_EX = 0x8000, 0x6040;

FILTERS = {
    { key = 'all', label = 'All' },
    { key = 'weapon', label = 'Weapons' },
    { key = 'armor', label = 'Armor' },
    { key = 'usable', label = 'Usable' },
    { key = 'crystal', label = 'Crystals' },
    { key = 'material', label = 'Materials' },
    { key = 'rareex', label = 'Rare / Ex' },
    { key = 'favorites', label = 'Favorites' },
};

item_cache = {};   -- [id] = info table
icon_cache = {};   -- [id] = { tex = texture, id = imgui id } or false

function clean_desc(text)
    text = tostring(text or '');
    text = text:gsub('\x81\x60', '~')
        :gsub('\xEF\x1F', 'Fire'):gsub('\xEF\x20', 'Ice'):gsub('\xEF\x21', 'Wind')
        :gsub('\xEF\x22', 'Earth'):gsub('\xEF\x23', 'Lightning'):gsub('\xEF\x24', 'Water')
        :gsub('\xEF\x25', 'Light'):gsub('\xEF\x26', 'Dark');
    return text;
end

function res_string(arr)
    local v = nil;
    pcall(function() v = arr[1] or arr[0]; end);
    if v == nil then return ''; end
    return tostring(v);
end

function get_item_info(id)
    id = tonumber(id) or 0;
    if id <= 0 then return nil; end
    local cached = item_cache[id];
    if cached ~= nil then return cached or nil; end

    local rm = AshitaCore:GetResourceManager();
    local ok, res = pcall(function() return rm:GetItemById(id); end);
    if not ok or res == nil then
        item_cache[id] = false;
        return nil;
    end

    local info = { id = id };
    pcall(function() info.name = res_string(res.Name); end);
    pcall(function() info.desc = clean_desc(res_string(res.Description)); end);
    pcall(function() info.type = tonumber(res.Type) or 0; end);
    pcall(function() info.flags = tonumber(res.Flags) or 0; end);
    pcall(function() info.slots = tonumber(res.Slots) or 0; end);
    pcall(function() info.level = tonumber(res.Level) or 0; end);
    pcall(function() info.jobs = tonumber(res.Jobs) or 0; end);
    pcall(function() info.stack = tonumber(res.StackSize) or 1; end);
    pcall(function() info.bitmap = res.Bitmap; info.image_size = tonumber(res.ImageSize) or 0; end);
    info.name = (info.name ~= nil and info.name ~= '') and info.name or ('Item ' .. tostring(id));
    info.name_lower = info.name:lower();
    info.type = info.type or 0;
    info.flags = info.flags or 0;
    info.slots = info.slots or 0;
    info.rare = bit.band(info.flags, FLAG_RARE) ~= 0;
    info.ex = bit.band(info.flags, FLAG_EX) ~= 0;
    item_cache[id] = info;
    return info;
end

function get_icon(info)
    if info == nil then return nil; end
    local cached = icon_cache[info.id];
    if cached ~= nil then return cached or nil; end
    icon_cache[info.id] = false;
    if info.bitmap == nil or (info.image_size or 0) <= 0 then return nil; end

    local ok, result = pcall(function()
        local ptr = ffi.new('IDirect3DTexture8*[1]');
        local hr = C.D3DXCreateTextureFromFileInMemoryEx(
            d3d.get_device(), info.bitmap, info.image_size, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
            C.D3DFMT_A8R8G8B8, C.D3DPOOL_MANAGED, C.D3DX_DEFAULT, C.D3DX_DEFAULT,
            0xFF000000, nil, nil, ptr);
        if hr ~= C.S_OK then return nil; end
        local tex = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
        return { tex = tex, id = tonumber(ffi.cast('uint32_t', tex)) };
    end);
    if ok and result ~= nil then
        icon_cache[info.id] = result;
        return result;
    end
    return nil;
end

function get_inventory()
    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return nil; end
    return mm:GetInventory();
end

function equip_slot_list(info)
    local list = {};
    if info == nil or info.slots == 0 then return list; end
    for s = 0, 15 do
        if bit.band(info.slots, bit.lshift(1, s)) ~= 0 then list[#list + 1] = s; end
    end
    return list;
end

function jobs_text(mask)
    mask = tonumber(mask) or 0;
    local out, count = {}, 0;
    for i, j in ipairs(JOBS) do
        if bit.band(mask, bit.lshift(1, i)) ~= 0 then
            out[#out + 1] = j;
            count = count + 1;
        end
    end
    if count == 0 then return ''; end
    if count >= #JOBS - 2 then return 'All Jobs'; end
    return table.concat(out, '/');
end

function fmt_gil(n)
    local s = tostring(math.floor(tonumber(n) or 0));
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse();
    return (out:gsub('^,', ''));
end
