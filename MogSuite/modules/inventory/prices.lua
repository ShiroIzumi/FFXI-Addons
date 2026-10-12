--[[
    MogSuite - modules/inventory/prices.lua

    NPC sell prices and Auction House categories: the built-in list (from LandSandBoat),
    an item_basic.sql in the MogSuite folder if you add one, and exact prices learned
    when a shop appraises your items.
]]

-- Reads LandSandBoat's item_basic.sql. Done once, the first time a price is
-- needed. Works with the current layout
--   (itemid, subid, 'name', 'sortname', 'name_jp', @TYPE, stackSize, @FLAGS | ..., @AH, BaseSell);
-- where "can't sell" is the @FLAG_NOSALE flag, and the older all-number one
--   (itemid, subid, 'name', 'sortname', stackSize, flags, aH, NoSale, BaseSell).
FLAG_NOSALE_BIT = 0x1000;

function trim(s)
    return (tostring(s):gsub('^%s+', ''):gsub('%s+$', ''));
end

-- Auction House categories (LandSandBoat's aH numbers).
AH_PATHS = {
    [1] = 'Weapons > Hand-to-Hand', [2] = 'Weapons > Dagger', [3] = 'Weapons > Sword', [4] = 'Weapons > Great Sword',
    [5] = 'Weapons > Axe', [6] = 'Weapons > Great Axe', [7] = 'Weapons > Scythe', [8] = 'Weapons > Polearm',
    [9] = 'Weapons > Katana', [10] = 'Weapons > Great Katana', [11] = 'Weapons > Club', [12] = 'Weapons > Staff',
    [13] = 'Weapons > Ranged', [14] = 'Weapons > Instruments', [15] = 'Weapons > Ammo & Misc. > Ammunition',
    [16] = 'Armor > Shields', [17] = 'Armor > Head', [18] = 'Armor > Body', [19] = 'Armor > Hands',
    [20] = 'Armor > Legs', [21] = 'Armor > Feet', [22] = 'Armor > Neck', [23] = 'Armor > Waist',
    [24] = 'Armor > Earrings', [25] = 'Armor > Rings', [26] = 'Armor > Back',
    [28] = 'Scrolls > White Magic', [29] = 'Scrolls > Black Magic', [30] = 'Scrolls > Summoning',
    [31] = 'Scrolls > Ninjutsu', [32] = 'Scrolls > Songs', [33] = 'Medicines', [34] = 'Furnishings',
    [35] = 'Crystals', [36] = 'Others > Cards', [37] = 'Others > Cursed Items', [38] = 'Materials > Smithing',
    [39] = 'Materials > Goldsmithing', [40] = 'Materials > Clothcraft', [41] = 'Materials > Leathercraft',
    [42] = 'Materials > Bonecraft', [43] = 'Materials > Woodworking', [44] = 'Materials > Alchemy',
    [45] = 'Scrolls > Geomancy', [46] = 'Others > Misc.', [47] = 'Weapons > Ammo & Misc. > Fishing Gear',
    [48] = 'Weapons > Ammo & Misc. > Pet Items', [49] = 'Others > Ninja Tools', [50] = 'Others > Beast-made',
    [51] = 'Food > Fish', [52] = 'Food > Meals > Meat & Eggs', [53] = 'Food > Meals > Seafood',
    [54] = 'Food > Meals > Vegetables', [55] = 'Food > Meals > Soups', [56] = 'Food > Meals > Breads & Rice',
    [57] = 'Food > Meals > Sweets', [58] = 'Food > Meals > Drinks', [59] = 'Food > Ingredients',
    [60] = 'Scrolls > Dice', [61] = 'Others > Automaton', [62] = 'Weapons > Ammo & Misc. > Grips',
    [63] = 'Materials > Alchemy 2', [64] = 'Others > Misc. 2', [65] = 'Others > Misc. 3',
};
ah_vars = {};   -- [@NAME] = number, from the SET lines at the top of the file

function parse_ah_value(v)
    v = trim(v or '');
    if v:sub(1, 1) == '@' then return ah_vars[v:sub(2)]; end
    return tonumber(v);
end

function parse_price_line(line)
    if line:find('^INSERT INTO `item_basic` VALUES %(') == nil then return nil; end
    local stop = line:find(');', 1, true);   -- anything after is a comment
    if stop == nil then return nil; end
    local vals = line:sub(1, stop - 1);
    local id = tonumber(vals:match('VALUES %((%d+),'));
    if id == nil then return nil; end

    -- The number fields come after the last quoted name.
    local q, pos = nil, 1;
    while true do
        local s = vals:find("'", pos, true);
        if s == nil then break; end
        q, pos = s, s + 1;
    end
    if q == nil then return nil; end
    local f = {};
    for field in vals:sub(q + 1):gmatch('[^,]+') do f[#f + 1] = trim(field); end
    if #f ~= 5 then return nil; end

    local sell = tonumber(f[5]);
    if sell == nil then return nil; end
    local nosale = false;
    local ah = nil;
    if f[1]:sub(1, 1) == '@' then
        ah = parse_ah_value(f[4]);
        -- Current layout: type, stack, flags, aH, BaseSell.
        local flags = f[3];
        if flags:find('FLAG_NOSALE', 1, true) ~= nil then
            nosale = true;
        elseif tonumber(flags) ~= nil then
            nosale = bit.band(tonumber(flags), FLAG_NOSALE_BIT) ~= 0;
        end
    else
        -- Older layout: stack, flags, aH, NoSale, BaseSell.
        nosale = tonumber(f[4]) == 1;
        ah = tonumber(f[3]);
    end
    return id, sell, nosale, ah;
end

function load_price_list()
    if prices.loaded then return; end
    prices.loaded = true;

    -- A LandSandBoat item_basic.sql in the MogSuite folder (newer data) wins.
    local candidates = { clean_path(addon.path .. '\\item_basic.sql'), DATA_DIR .. 'item_basic.sql' };
    for _, path in ipairs(candidates) do
        local f = io.open(path, 'r');
        if f ~= nil then
            local count = 0;
            for line in f:lines() do
                local var, num = line:match('^SET @([%w_]+)%s*=%s*(%d+)%s*;');
                if var ~= nil then
                    ah_vars[var] = tonumber(num);
                else
                    local id, sell, nosale, ah = parse_price_line(line);
                    if id ~= nil then
                        prices.base[id] = sell;
                        if nosale then prices.nosale[id] = true; end
                        if ah ~= nil then prices.ah[id] = ah; end
                        count = count + 1;
                    end
                end
            end
            f:close();
            prices.count = count;
            prices.source = path;
            return;
        end
    end

    -- Otherwise the built-in list (data\\item_prices.lua, generated from
    -- LandSandBoat): one "id,sell,nosale,ah" line per item.
    local ok, text = pcall(function()
        local chunk = loadfile(DATA_DIR .. 'item_prices.lua');
        if chunk == nil then return nil; end
        return chunk();
    end);
    if ok and type(text) == 'string' then
        local count = 0;
        for id, sell, nosale, ah in text:gmatch('(%d+),(%-?%d+),(%d),(%-?%d+)') do
            id = tonumber(id);
            prices.base[id] = tonumber(sell);
            if nosale == '1' then prices.nosale[id] = true; end
            ah = tonumber(ah);
            if ah ~= nil and ah >= 0 then prices.ah[id] = ah; end
            count = count + 1;
        end
        prices.count = count;
        prices.source = 'Built-in price list (LandSandBoat item_basic.sql)';
    end
end

-- Sell price per item: value, source ('vendor' exact | 'list' | 'nosale' | nil).
function price_of(id)
    id = tonumber(id) or 0;
    local l = learned[id];
    if l ~= nil then return tonumber(l), 'vendor'; end
    load_price_list();
    if prices.nosale[id] then return nil, 'nosale'; end
    local b = prices.base[id];
    if b ~= nil then return b, 'list'; end
    return nil, nil;
end

-- Auction House category path, 'none' when it isn't sold there, or nil.
function ah_of(id)
    load_price_list();
    local n = prices.ah[tonumber(id) or 0];
    if n == nil then return nil; end
    if n == 0 then return 'none'; end
    return AH_PATHS[n];
end

function learn_price(id, value)
    id = tonumber(id) or 0;
    value = tonumber(value) or -1;
    if id <= 0 or value < 0 then return; end
    if learned[id] == value then return; end
    learned[id] = value;
    write_lua_file(DATA_DIR .. 'prices_learned.lua', learned);
end
