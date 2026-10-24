--[[
    MogSuite - modules/crafting/ledger.lua

    Your synthesis ledger: every synth you make is counted per recipe
    (NQ / HQ1 / HQ2 / HQ3 / break), with the Vana'diel day, the moon and the
    way you were facing, so you get your own HQ and break rates.

    Read from the game's synthesis result (0x06F: result @0x04, count @0x06,
    item @0x08, crystal @0x22, materials @0x24 .. 0x33; LandSandBoat). The
    recipe is found from the crystal and materials.

    Kept outside the addon folder, for all your characters:
      config\addons\mogsuite\synth_ledger.lua
]]

LEDGER = nil;   -- [recipe id] = { n, nq, hq1, hq2, hq3, brk, last, days = {[0..7] = {n, hq, brk}}, moons = {...}, dirs = {...} }

local DIRS = { 'East', 'South-east', 'South', 'South-west', 'West', 'North-west', 'North', 'North-east' };
local DAY_NAMES = { [0] = 'Firesday', [1] = 'Earthsday', [2] = 'Watersday', [3] = 'Windsday', [4] = 'Iceday', [5] = 'Lightningday', [6] = 'Lightsday', [7] = 'Darksday' };
LEDGER_DIRS = DIRS;
LEDGER_DAYS = DAY_NAMES;

local function ledger_path()
    local p = '';
    pcall(function() p = AshitaCore:GetInstallPath(); end);
    p = tostring(p or ''):gsub('[\\/]+$', '');
    return p .. '\\config\\addons\\mogsuite', p .. '\\config\\addons\\mogsuite\\synth_ledger.lua';
end

function load_ledger()
    if LEDGER ~= nil then return LEDGER; end
    LEDGER = {};
    local _, path = ledger_path();
    local chunk = loadfile(path);
    if chunk ~= nil then
        local ok, t = pcall(chunk);
        if ok and type(t) == 'table' then LEDGER = t; end
    end
    return LEDGER;
end

local function ser(v)
    if type(v) == 'table' then
        local parts = {};
        for k, x in pairs(v) do
            local kk = (type(k) == 'number') and ('[' .. k .. ']') or ('[' .. ('%q'):format(k) .. ']');
            parts[#parts + 1] = kk .. '=' .. ser(x);
        end
        return '{' .. table.concat(parts, ',') .. '}';
    elseif type(v) == 'number' then
        return tostring(v);
    end
    return ('%q'):format(tostring(v));
end

function save_ledger()
    local dir, path = ledger_path();
    pcall(function() if not ashita.fs.exists(dir) then ashita.fs.create_directory(dir); end end);
    local f = io.open(path, 'w');
    if f == nil then return; end
    f:write('-- MogSuite Crafting: your synthesis ledger (all characters). Written by MogSuite.\nreturn {\n');
    for id, e in pairs(LEDGER or {}) do f:write(('  [%d] = %s,\n'):format(id, ser(e))); end
    f:write('}\n');
    f:close();
end

-- Which way you face (one of 8).
local function facing()
    local dir = nil;
    pcall(function()
        local idx = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
        local yaw = AshitaCore:GetMemoryManager():GetEntity():GetLocalPositionYaw(idx);
        if yaw ~= nil then
            -- 0 = east, turning clockwise in steps of 45 degrees.
            local a = (tonumber(yaw) or 0) % (2 * math.pi);
            dir = math.floor((a + math.pi / 8) / (math.pi / 4)) % 8 + 1;
        end
    end);
    return dir;
end

local function bump(t, k, field)
    t[k] = t[k] or { n = 0, hq = 0, brk = 0 };
    t[k].n = t[k].n + 1;
    if field ~= nil then t[k][field] = (t[k][field] or 0) + 1; end
end

-- The tier of a success: 0 NQ, 1-3 HQ.
local function tier_of(rec, item, count)
    for t = 3, 1, -1 do
        local h = rec.hq[t];
        if h[1] == item and h[2] == count and not (rec.result == item and rec.qty == count) then return t; end
    end
    for t = 1, 3 do
        local h = rec.hq[t];
        if h[1] == item and h[1] ~= rec.result then return t; end
    end
    return 0;
end

function ledger_packet(data)
    if config.ledger.enabled == false then return; end
    if data == nil or #data < 0x34 then return; end
    local result = data:byte(0x04 + 1);
    if result ~= 0 and result ~= 1 then return; end      -- success / break only
    local function u16(o) local a, b = data:byte(o + 1, o + 2); return (a or 0) + (b or 0) * 256; end
    local count = data:byte(0x06 + 1) or 0;
    local item = u16(0x08);
    local crystal = u16(0x22);
    local ings = {};
    for i = 0, 7 do
        local id = u16(0x24 + i * 2);
        if id ~= 0 then ings[#ings + 1] = id; end
    end
    load_recipes();
    local list = BY_KEY[recipe_key(crystal, ings)];
    if list == nil then return; end
    local rec = list[1];
    if #list > 1 and result == 0 then
        for _, r in ipairs(list) do
            if r.result == item or r.hq[1][1] == item then rec = r; break; end
        end
    end
    local L = load_ledger();
    local e = L[rec.id] or { n = 0, nq = 0, hq1 = 0, hq2 = 0, hq3 = 0, brk = 0, days = {}, moons = {}, dirs = {} };
    L[rec.id] = e;
    e.n = e.n + 1;
    e.last = os.time();
    local v = vana_now and vana_now() or nil;
    local field;
    if result == 1 then
        e.brk = e.brk + 1;
        field = 'brk';
    else
        local t = tier_of(rec, item, count);
        if t == 0 then e.nq = e.nq + 1; else e['hq' .. t] = (e['hq' .. t] or 0) + 1; field = 'hq'; end
    end
    if v ~= nil then
        bump(e.days, v.weekday, field);
        bump(e.moons, v.moon_phase, field);
    end
    local d = facing();
    if d ~= nil then bump(e.dirs, d, field); end
    save_ledger();
    if config.ledger.chat == true then
        local what = (result == 1) and 'break' or ((field == 'hq') and 'HQ' or 'NQ');
        print(('\30\81[MogSuite]\30\01 %s: %s  (%d made, %d%% HQ, %d%% break)'):fmt(recipe_name(rec), what, e.n,
            math.floor((e.hq1 + e.hq2 + e.hq3) * 100 / e.n + 0.5), math.floor(e.brk * 100 / e.n + 0.5)));
    end
end

-- Vana'diel day and moon (same math as the Calendar).
function vana_now()
    local raw = os.time() + 92514960;
    local td = math.floor(raw / 3456);
    local signed = ((((td + 26) % 84) - 42) / 42) * 100;
    local phase;
    if signed >= 7 and signed <= 38 then phase = 1;
    elseif signed >= 40 and signed <= 55 then phase = 2;
    elseif signed >= 57 and signed <= 88 then phase = 3;
    elseif signed >= 90 or signed <= -95 then phase = 4;
    elseif signed >= -93 and signed <= -62 then phase = 5;
    elseif signed >= -60 and signed <= -45 then phase = 6;
    elseif signed >= -43 and signed <= -12 then phase = 7;
    else phase = 0; end
    return { weekday = td % 8, moon_phase = phase, moon_pct = math.floor(math.abs(signed) + 0.5) };
end
MOON_NAMES = { [0] = 'New Moon', [1] = 'Waxing Crescent', [2] = 'First Quarter', [3] = 'Waxing Gibbous',
    [4] = 'Full Moon', [5] = 'Waning Gibbous', [6] = 'Last Quarter', [7] = 'Waning Crescent' };

-- Rates of a ledger entry: hq %, break %.
function ledger_rates(e)
    if e == nil or (e.n or 0) == 0 then return 0, 0; end
    return ((e.hq1 or 0) + (e.hq2 or 0) + (e.hq3 or 0)) * 100 / e.n, (e.brk or 0) * 100 / e.n;
end
