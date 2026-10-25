--[[
    WhatsMyDamage - core/names.lua

    Names from the game's resources, cached: spells, weapon skills, job
    abilities (+512 in Ashita's ability table), items, monster / pet TP moves
    (+256, from the monsters.abilities strings), and entities by server id.
]]

require('common');

local names = {};
local C = { spell = {}, ws = {}, ja = {}, item = {}, tp = {}, entity = {} };   -- caches

local function res_name(r)
    if r == nil then return nil; end
    local ok, n = pcall(function()
        local v = r.Name[1];
        if type(v) ~= 'string' or v == '' then v = r.Name[0]; end
        return v;
    end);
    if ok and type(n) == 'string' and n ~= '' then return n; end
    return nil;
end

local function cached(tbl, id, fn, fallback)
    id = tonumber(id) or -1;
    local v = tbl[id];
    if v ~= nil then return v; end
    local ok, n = pcall(fn, id);
    v = (ok and type(n) == 'string' and n ~= '') and n or (fallback .. ' #' .. id);
    tbl[id] = v;
    return v;
end

function names.spell(id)
    return cached(C.spell, id, function(i)
        return res_name(AshitaCore:GetResourceManager():GetSpellById(i));
    end, 'Spell');
end

function names.ws(id)
    return cached(C.ws, id, function(i)
        return res_name(AshitaCore:GetResourceManager():GetAbilityById(i));
    end, 'Weapon Skill');
end

function names.ja(id)
    return cached(C.ja, id, function(i)
        return res_name(AshitaCore:GetResourceManager():GetAbilityById(i + 512));
    end, 'Ability');
end

function names.item(id)
    return cached(C.item, id, function(i)
        return res_name(AshitaCore:GetResourceManager():GetItemById(i));
    end, 'Item');
end

-- Monster / pet TP moves and Blood Pacts.
function names.tp(id)
    return cached(C.tp, id, function(i)
        local rm = AshitaCore:GetResourceManager();
        if i >= 256 then
            local s = rm:GetString('monsters.abilities', i - 256);
            if type(s) == 'string' and s ~= '' then return s; end
        end
        local r = res_name(rm:GetAbilityById(i));
        if r ~= nil then return r; end
        return res_name(rm:GetAbilityById(i + 512));
    end, 'TP Move');
end

-- Entity name for a server id (monsters keep their entity index in the
-- low 12 bits). Cached; misses are retried after a few seconds.
local misses = {};
function names.entity(sid)
    sid = tonumber(sid) or 0;
    if sid == 0 then return 'Unknown'; end
    local v = C.entity[sid];
    if v ~= nil then return v; end
    if misses[sid] and os.clock() - misses[sid] < 3 then return 'Unknown'; end
    local found = nil;
    pcall(function()
        local em = AshitaCore:GetMemoryManager():GetEntity();
        local function at(i)
            if (tonumber(em:GetServerId(i)) or 0) ~= sid then return nil; end
            local n = em:GetName(i);
            if type(n) == 'string' and n ~= '' then return n; end
            return nil;
        end
        if sid >= 0x01000000 then
            local idx = bit.band(sid, 0xFFF);
            if idx >= 0x900 then idx = idx - 0x100; end
            found = at(idx);
        end
        if found == nil then
            local p = AshitaCore:GetMemoryManager():GetParty();
            for s = 0, 17 do
                if (tonumber(p:GetMemberServerId(s)) or 0) == sid then
                    local n = p:GetMemberName(s);
                    if type(n) == 'string' and n ~= '' then found = n; end
                end
            end
        end
    end);
    if found ~= nil then
        C.entity[sid] = found;
        return found;
    end
    misses[sid] = os.clock();
    return 'Unknown';
end

return names;
