--[[
    MogSuite - modules/crafting/data.lua

    Recipes (data/synth.lua: LandSandBoat, Horizon-era, with HQ results),
    your crafting skills and how many of each material you have.
]]

-- Order of the levels in data/synth.lua, and the game's craft skill index.
CRAFTS = {
    { name = 'Woodworking',  short = 'Wood',    skill = 1, color = COLORS.wind },
    { name = 'Smithing',     short = 'Smith',   skill = 2, color = COLORS.fire },
    { name = 'Goldsmithing', short = 'Gold',    skill = 3, color = COLORS.light },
    { name = 'Clothcraft',   short = 'Cloth',   skill = 4, color = COLORS.ice },
    { name = 'Leathercraft', short = 'Leather', skill = 5, color = COLORS.earth },
    { name = 'Bonecraft',    short = 'Bone',    skill = 6, color = COLORS.dark },
    { name = 'Alchemy',      short = 'Alchemy', skill = 7, color = COLORS.thunder },
    { name = 'Cooking',      short = 'Cooking', skill = 8, color = COLORS.water },
};
CRAFT_BY_NAME = {};
for i, c in ipairs(CRAFTS) do c.index = i; CRAFT_BY_NAME[c.name] = c; end

CRYSTALS = {
    [4096] = 'Fire', [4097] = 'Ice', [4098] = 'Wind', [4099] = 'Earth',
    [4100] = 'Lightning', [4101] = 'Water', [4102] = 'Light', [4103] = 'Dark',
    [4238] = 'Inferno', [4239] = 'Glacier', [4240] = 'Cyclone', [4241] = 'Terra',
    [4242] = 'Plasma', [4243] = 'Torrent', [4244] = 'Aurora', [4245] = 'Twilight',
};

RECIPES = nil;
BY_KEY = nil;        -- [crystal .. ':' .. sorted ingredients] = { recipe, ... }

local function names_cache_name(id)
    local info = MS.item_info and MS.item_info(id) or nil;
    if info ~= nil then return info.name; end
    local n = nil;
    pcall(function() n = AshitaCore:GetResourceManager():GetItemById(id).Name[1]; end);
    return n or ('Item ' .. tostring(id));
end
item_name = names_cache_name;

local function key_of(crystal, ings)
    local t = {};
    for _, i in ipairs(ings) do t[#t + 1] = tonumber(i) or 0; end
    table.sort(t);
    return tostring(crystal) .. ':' .. table.concat(t, ',');
end
recipe_key = key_of;

function load_recipes()
    if RECIPES ~= nil then return RECIPES; end
    RECIPES, BY_KEY = {}, {};
    local chunk = loadfile(((addon.path .. '\\data\\synth.lua'):gsub('[\\/]+', '\\')));
    local ok, rows = false, nil;
    if chunk ~= nil then ok, rows = pcall(chunk); end
    if not ok or type(rows) ~= 'table' then return RECIPES; end
    for _, r in ipairs(rows) do
        local lv = r[4];
        local main, main_lv, subs = nil, 0, {};
        for i, v in ipairs(lv) do
            if v > main_lv then main, main_lv = i, v; end
        end
        for i, v in ipairs(lv) do
            if v > 0 and i ~= main then subs[#subs + 1] = { craft = CRAFTS[i], level = v }; end
        end
        local rec = {
            id = r[1], desynth = r[2] == 1, ki = r[3], levels = lv,
            crystal = r[5], hq_crystal = r[6], ings = r[7],
            result = r[8], qty = r[9], hq = { { r[10], r[11] }, { r[12], r[13] }, { r[14], r[15] } },
            craft = main and CRAFTS[main] or CRAFTS[1], level = main_lv, subs = subs,
        };
        RECIPES[#RECIPES + 1] = rec;
        for _, c in ipairs({ rec.crystal, rec.hq_crystal }) do
            if c ~= nil and c > 0 then
                local k = key_of(c, rec.ings);
                BY_KEY[k] = BY_KEY[k] or {};
                table.insert(BY_KEY[k], rec);
            end
        end
    end
    return RECIPES;
end

-- The recipe's name (cached): the result item.
function recipe_name(rec)
    if rec.name == nil then
        rec.name = item_name(rec.result);
        rec.name_lower = rec.name:lower();
    end
    return rec.name;
end

-- Ingredients grouped: { { id, n }, ... } in recipe order.
function recipe_needs(rec)
    if rec.needs ~= nil then return rec.needs; end
    local seen, out = {}, {};
    for _, id in ipairs(rec.ings) do
        if seen[id] == nil then
            seen[id] = { id = id, n = 0 };
            out[#out + 1] = seen[id];
        end
        seen[id].n = seen[id].n + 1;
    end
    rec.needs = out;
    return out;
end

-- How many times you can make it with what you have (crystal included).
function times_you_can(rec)
    local c = state.counts;
    local n = (c[rec.crystal] or 0) + ((rec.hq_crystal or 0) > 0 and (c[rec.hq_crystal] or 0) or 0);
    if n <= 0 then return 0; end
    for _, need in ipairs(recipe_needs(rec)) do
        n = math.min(n, math.floor((c[need.id] or 0) / need.n));
        if n <= 0 then return 0; end
    end
    return n;
end

-- Your skill in each craft (whole levels).
function read_skills()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if player == nil then return; end
    for _, c in ipairs(CRAFTS) do
        pcall(function()
            local e = player:GetCraftSkill(c.skill);
            state.skills[c.name] = tonumber(e:GetSkill()) or 0;
        end);
    end
end

-- Can your skill do it: main craft and every sub craft.
function skill_ok(rec)
    if (state.skills[rec.craft.name] or 0) < rec.level then return false; end
    for _, s in ipairs(rec.subs) do
        if (state.skills[s.craft.name] or 0) < s.level then return false; end
    end
    return true;
end

function refresh_counts()
    if os.clock() - state.counts_at < 2 then return; end
    state.counts_at = os.clock();
    if MS.item_counts ~= nil then
        local ok, c, w = pcall(MS.item_counts);
        if ok and c ~= nil then state.counts, state.where = c, w or {}; end
    end
    read_skills();
end
