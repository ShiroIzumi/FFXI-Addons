--[[
    MogSuite - core/latents.lua  (1.8.0)

    When an item's latent effect switches on. The game's item text only
    says "Latent effect: AGI+3"; the condition comes from LandSandBoat's
    item_latents table (data/latents.lua, generated; HorizonXI can differ):

        latents.lines(item_id) -> { { text = 'Support job is NIN', on = true | false | nil }, ... }

    on = true: the condition is met right now (green), false: not met
    (grey), nil: MogSuite can't tell (shown plain).

    Drawing helpers for the two tooltip looks:
        latents.draw_game(game_tip, item_id)       -- after game_tip.sep()
        latents.draw_theme(item_id, good, muted, text)
]]

require('common');
local imgui = require('imgui');
local bit = require('bit');

local latents = {};
local DATA = nil;

local function data()
    if DATA ~= nil then return DATA; end
    DATA = {};
    pcall(function()
        local f = loadfile(addon.path .. 'data\\latents.lua');
        if f ~= nil then
            local ok, t = pcall(f);
            if ok and type(t) == 'table' then DATA = t; end
        end
    end);
    return DATA;
end

local JOBS = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN',
    'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN' };
local function job(p) return JOBS[p] or ('job ' .. tostring(p)); end

local SLOTS = { [0] = 'Main', 'Sub', 'Range', 'Ammo', 'Head', 'Body', 'Hands', 'Legs', 'Feet', 'Neck', 'Waist',
    'Ear', 'Ear', 'Ring', 'Ring', 'Back' };
local NATIONS = { [0] = "San d'Oria", 'Bastok', 'Windurst' };
local DAYS = { [28] = 'Firesday', [29] = 'Earthsday', [30] = 'Watersday', [31] = 'Windsday', [32] = 'Darksday',
    [34] = 'Iceday', [35] = 'Lightningday', [36] = 'Lightsday' };
local DAY_NUM = { [28] = 0, [29] = 1, [30] = 2, [31] = 3, [34] = 4, [35] = 5, [36] = 6, [32] = 7 };
local MOONS = { [0] = 'New Moon', 'Waxing Crescent', 'First Quarter', 'Waxing Gibbous', 'Full Moon', 'Waning Gibbous',
    'Last Quarter', 'Waning Crescent' };
local HOURS = { 'new day (4:00-6:00)', 'dawn (6:00-7:00)', 'daytime (7:00-17:00)', 'dusk (17:00-18:00)',
    'evening (18:00-20:00)', 'dead of night (20:00-4:00)' };
local ELEMENTS = { [0] = 'none', 'fire', 'ice', 'wind', 'earth', 'thunder', 'water', 'light', 'dark' };
-- LandSandBoat pet ids (xi.petId).
local PETS = { [0] = 'Fire Spirit', 'Ice Spirit', 'Air Spirit', 'Earth Spirit', 'Thunder Spirit', 'Water Spirit',
    'Light Spirit', 'Dark Spirit', 'Carbuncle', 'Fenrir', 'Ifrit', 'Titan', 'Leviathan', 'Garuda', 'Shiva', 'Ramuh',
    'Diabolos', 'Alexander', 'Odin', 'Atomos', 'Cait Sith' };
local CRAFTS = { [48] = 'Fishing', [49] = 'Woodworking', [50] = 'Smithing', [51] = 'Goldsmithing', [52] = 'Clothcraft',
    [53] = 'Leathercraft', [54] = 'Bonecraft', [55] = 'Alchemy', [56] = 'Cooking' };
local DYNAMIS = { [39] = true, [40] = true, [41] = true, [42] = true, [134] = true, [135] = true,
    [185] = true, [186] = true, [187] = true, [188] = true };

local function rstring(kind, id)
    local s = nil;
    pcall(function() s = AshitaCore:GetResourceManager():GetString(kind, id); end);
    if s == nil or s == '' then return nil; end
    return s;
end
local function buff_name(p) return rstring('buffs.names', p) or ('effect ' .. tostring(p)); end
local function zone(p) return rstring('zones.names', p) or ('zone ' .. tostring(p)); end
local function item_name(p)
    local n = nil;
    pcall(function() n = AshitaCore:GetResourceManager():GetItemById(p).Name[1]; end);
    return n or ('item ' .. tostring(p));
end

-- Text of one condition.
local function text_of(c, p)
    if c == 0 then return ('HP %d%% or less'):format(p);
    elseif c == 1 then return ('HP above %d%%'):format(p);
    elseif c == 2 then return ('HP %d%% or less and TP under 1000'):format(p);
    elseif c == 3 then return ('HP above %d%% and TP under 1000'):format(p);
    elseif c == 4 then return ('MP %d%% or less'):format(p);
    elseif c == 5 then return ('MP under %d'):format(p);
    elseif c == 6 then return ('TP under %d'):format(p);
    elseif c == 7 then return ('TP over %d'):format(p);
    elseif c == 8 then return 'Support job is ' .. job(p);
    elseif c == 9 then return 'With ' .. (PETS[p] or ('pet ' .. p)) .. ' out';
    elseif c == 10 then return 'Weapon drawn';
    elseif c == 11 then return 'Weapon sheathed';
    elseif c == 12 then return 'Under Signet, vs. an even match or easier';
    elseif c == 13 then return 'While ' .. buff_name(p) .. ' is on you';
    elseif c == 14 then return 'No food effect';
    elseif c == 15 then return ('Party of %d or more'):format(p);
    elseif c == 16 then return ('%d or more party members in the zone'):format(p);
    elseif c == 17 or c == 18 then return 'Under Sanction (Besieged area)';
    elseif c == 19 or c == 20 then return 'Under Sigil (Campaign area)';
    elseif c == 21 then return (p == 21) and 'An avatar in the party' or ('With ' .. (PETS[p] or ('avatar ' .. p)) .. ' in the party');
    elseif c == 22 then return job(p) .. ' in the party';
    elseif c == 23 then return 'In ' .. zone(p);
    elseif c == 24 then return (CRAFTS[p] or 'Craft') .. ' skill under 40 (no support)';
    elseif c == 25 then return 'A song or roll on you';
    elseif c == 26 then return p == 0 and 'Daytime (6:00-18:00)' or (p == 1 and 'Nighttime (18:00-6:00)' or 'Dusk to dawn');
    elseif c == 27 then return 'At ' .. (HOURS[p] or ('time ' .. p));
    elseif DAYS[c] ~= nil then return 'On ' .. DAYS[c];
    elseif c == 37 then return 'During ' .. (MOONS[p] or ('moon ' .. p));
    elseif c == 38 then return p == 0 and 'At an odd level' or (p == 2 and 'At an even level' or ('At a level divisible by ' .. p));
    elseif c == 39 then return (p == 0 and 'At an odd level' or (p == 2 and 'At an even level' or ('At a level divisible by ' .. p))) .. ', at night';
    elseif c == 40 then return 'Worn in the ' .. (SLOTS[p] or ('slot ' .. p)) .. ' slot';
    elseif c == 41 then return 'During weapon skills';
    elseif c == 42 then return 'In certain weather';
    elseif c == 43 then return ('Weapon drawn and HP %d%% or less'):format(p);
    elseif c == 44 then return 'Citizen of ' .. (NATIONS[p] or ('nation ' .. p));
    elseif c == 45 then return ('MP %d%% or less'):format(p);
    elseif c == 46 then return ('HP %d%% or more'):format(p);
    elseif c == 47 then return 'Once the weapon is broken';
    elseif c == 48 then return 'In Dynamis';
    elseif c == 49 then return 'While ' .. item_name(p) .. ' food is on';
    elseif c == 50 then return ('Under level %d'):format(p);
    elseif c == 51 then return ('Level %d and up'):format(p);
    elseif c == 52 then return 'In ' .. (ELEMENTS[p] or 'elemental') .. ' weather';
    elseif c == 53 then return p == 0 and "In an area your nation controls" or "In an area your nation doesn't control";
    elseif c == 54 then return 'In your home nation';
    elseif c == 55 then return ('MP over %d'):format(p);
    elseif c == 56 then return ('Weapon drawn and MP over %d'):format(p);
    elseif c == 57 then return 'A roll of 11 on you';
    elseif c == 58 then return 'In Assault';
    elseif c == 59 then return 'Vs. certain monster types';
    elseif c == 60 or c == 61 then return 'Vs. certain monsters';
    elseif c == 62 then return 'Main job is ' .. job(p);
    elseif c == 63 then return 'In Adoulin';
    elseif c == 64 then return 'During Garrison';
    end
    return 'Special condition';
end

-- ---------------------------------------------------------------- live state

local function mm() return AshitaCore:GetMemoryManager(); end

local function snapshot()
    local s = {};
    pcall(function()
        local party = mm():GetParty();
        local player = mm():GetPlayer();
        s.hpp = party:GetMemberHPPercent(0);
        s.mpp = party:GetMemberMPPercent(0);
        s.mp = party:GetMemberMP(0);
        s.tp = party:GetMemberTP(0);
        s.zone = party:GetMemberZone(0);
        s.main = player:GetMainJob();
        s.sub = player:GetSubJob();
        s.lvl = player:GetMainJobLevel();
        local idx = party:GetMemberTargetIndex(0);
        s.status = mm():GetEntity():GetStatus(idx);
        s.pet_idx = mm():GetEntity():GetPetTargetIndex(idx);
        s.buffs = {};
        for _, b in ipairs(player:GetBuffs() or {}) do
            b = tonumber(b) or -1;
            if b >= 0 and b ~= 255 then s.buffs[b] = true; end
        end
        local n, inzone, jobs = 0, 0, {};
        for i = 0, 5 do
            if party:GetMemberIsActive(i) == 1 then
                n = n + 1;
                if party:GetMemberZone(i) == s.zone then inzone = inzone + 1; end
                if i > 0 then jobs[party:GetMemberMainJob(i)] = true; end
            end
        end
        s.party, s.inzone, s.jobs = n, inzone, jobs;
    end);
    pcall(function() s.nation = mm():GetPlayer():GetNation(); end);
    pcall(function()
        if s.pet_idx ~= nil and s.pet_idx > 0 then s.pet = mm():GetEntity():GetName(s.pet_idx); end
    end);
    -- Vana'diel clock (same math as the Calendar module).
    local raw = os.time() + 92514960;
    local td = math.floor(raw / 3456);
    s.vday = td % 8;
    s.vhour = math.floor((raw % 3456) / 144);
    local signed = ((((td + 26) % 84) - 42) / 42) * 100;
    local ph = 0;
    if signed >= 7 and signed <= 38 then ph = 1; elseif signed >= 40 and signed <= 55 then ph = 2;
    elseif signed >= 57 and signed <= 88 then ph = 3; elseif signed >= 90 or signed <= -95 then ph = 4;
    elseif signed >= -93 and signed <= -62 then ph = 5; elseif signed >= -60 and signed <= -45 then ph = 6;
    elseif signed >= -43 and signed <= -12 then ph = 7; end
    s.moon = ph;
    return s;
end

local function equipped_id(slot)
    local id = nil;
    pcall(function()
        local inv = mm():GetInventory();
        local e = inv:GetEquippedItem(slot);
        local idx = tonumber(e.Index) or 0;
        if idx ~= 0 then
            local it = inv:GetContainerItem(math.floor(bit.band(idx, 0xFF00) / 0x100), idx % 0x100);
            id = it and it.Id or nil;
        end
    end);
    return id;
end

local function night(h) return h >= 18 or h < 6; end
local function hour_type(h)
    if h >= 4 and h < 6 then return 1; elseif h >= 6 and h < 7 then return 2; elseif h >= 7 and h < 17 then return 3;
    elseif h >= 17 and h < 18 then return 4; elseif h >= 18 and h < 20 then return 5; end
    return 6;
end
local function level_fits(lvl, p)
    if lvl == nil or lvl <= 0 then return nil; end
    if p == 0 then return lvl % 2 == 1; end
    if p == 2 then return lvl % 2 == 0; end
    if p > 2 then return lvl % p == 0; end
    return nil;
end

local function state_of(c, p, s, item_id)
    local hpp, mpp, tp = s.hpp, s.mpp, s.tp;
    if hpp == nil then return nil; end
    if c == 0 then return hpp <= p;
    elseif c == 1 then return hpp > p;
    elseif c == 2 then return hpp <= p and tp < 1000;
    elseif c == 3 then return hpp > p and tp < 1000;
    elseif c == 4 or c == 45 then return mpp <= p;
    elseif c == 5 then return (s.mp or 0) < p;
    elseif c == 6 then return tp < p;
    elseif c == 7 then return tp > p;
    elseif c == 8 then return s.sub == p;
    elseif c == 9 then if PETS[p] == nil then return nil; end return s.pet ~= nil and s.pet == PETS[p];
    elseif c == 10 then return s.status == 1;
    elseif c == 11 then return s.status ~= 1;
    elseif c == 13 then return s.buffs[p] == true;
    elseif c == 14 then return s.buffs[251] ~= true;
    elseif c == 15 then return (s.party or 1) >= p;
    elseif c == 16 then return (s.inzone or 1) >= p;
    elseif c == 22 then return s.jobs[p] == true;
    elseif c == 23 then return s.zone == p;
    elseif c == 26 then
        if p == 0 then return not night(s.vhour); elseif p == 1 then return night(s.vhour); end
        return s.vhour >= 17 or s.vhour < 7;
    elseif c == 27 then return hour_type(s.vhour) == p;
    elseif DAY_NUM[c] ~= nil then return s.vday == DAY_NUM[c];
    elseif c == 37 then return s.moon == p;
    elseif c == 38 then return level_fits(s.lvl, p);
    elseif c == 39 then local f = level_fits(s.lvl, p); if f == nil then return nil; end return f and night(s.vhour);
    elseif c == 40 then if item_id == nil then return nil; end return equipped_id(p) == item_id;
    elseif c == 43 then return s.status == 1 and hpp <= p;
    elseif c == 44 then if s.nation == nil then return nil; end return s.nation == p;
    elseif c == 46 then return hpp >= p;
    elseif c == 48 then return DYNAMIS[s.zone] == true;
    elseif c == 49 then if s.buffs[251] ~= true then return false; end return nil;
    elseif c == 50 then if (s.lvl or 0) <= 0 then return nil; end return s.lvl < p;
    elseif c == 51 then if (s.lvl or 0) <= 0 then return nil; end return s.lvl >= p;
    elseif c == 55 then return (s.mp or 0) > p;
    elseif c == 56 then return s.status == 1 and (s.mp or 0) > p;
    elseif c == 62 then return s.main == p;
    end
    return nil;
end

local CACHE = { at = -1, s = nil };

function latents.has(item_id) return data()[tonumber(item_id) or -1] ~= nil; end

function latents.lines(item_id)
    local d = data()[tonumber(item_id) or -1];
    if d == nil then return nil; end
    if os.clock() - CACHE.at > 0.25 or CACHE.s == nil then CACHE.s = snapshot(); CACHE.at = os.clock(); end
    local out = {};
    for i = 1, #d, 2 do
        local c, p = d[i], d[i + 1];
        local ok, on = pcall(state_of, c, p, CACHE.s, tonumber(item_id));
        out[#out + 1] = { text = text_of(c, p), on = ok and on or nil };
    end
    return out;
end

local function suffix(on)
    if on == true then return '  (on now)'; elseif on == false then return '  (off now)'; end
    return '';
end

latents.ON = { 0.45, 0.95, 0.50, 1.00 };
latents.OFF = { 0.62, 0.64, 0.72, 1.00 };

function latents.draw_game(GT, item_id)
    local list = latents.lines(item_id);
    if list == nil then return; end
    for _, l in ipairs(list) do
        local col = (l.on == true) and latents.ON or ((l.on == false) and latents.OFF or GT.LINE);
        GT.wrapped(col, 'Latent: ' .. l.text .. suffix(l.on));
    end
end

function latents.draw_theme(item_id, good, muted, text)
    local list = latents.lines(item_id);
    if list == nil then return; end
    for _, l in ipairs(list) do
        local col = (l.on == true) and (good or latents.ON) or ((l.on == false) and (muted or latents.OFF) or (text or { 1, 1, 1, 1 }));
        imgui.TextColored(col, 'Latent: ' .. l.text .. suffix(l.on));
    end
end

return latents;
