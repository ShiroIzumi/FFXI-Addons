--[[
    MogSuite - modules/actions/player.lua

    Resources, your character snapshot, "do you have it?" checks and recast timers.
]]

-- ============================================================================
-- Resources
-- ============================================================================

function res_string(arr)
    local v = nil;
    pcall(function() v = arr[1] or arr[0]; end);
    if v == nil then return ''; end
    return tostring(v);
end

function clean_desc(text)
    text = tostring(text or '');
    text = text:gsub('\x81\x60', '~')
        :gsub('\xEF\x1F', 'Fire'):gsub('\xEF\x20', 'Ice'):gsub('\xEF\x21', 'Wind')
        :gsub('\xEF\x22', 'Earth'):gsub('\xEF\x23', 'Lightning'):gsub('\xEF\x24', 'Water')
        :gsub('\xEF\x25', 'Light'):gsub('\xEF\x26', 'Dark');
    return text;
end

ability_cache = {};   -- [name] = resource or false

function ability_by_name(name)
    local c = ability_cache[name];
    if c ~= nil then return c or nil; end
    local res = nil;
    pcall(function() res = AshitaCore:GetResourceManager():GetAbilityByName(name, 0); end);
    if res == nil then
        pcall(function() res = AshitaCore:GetResourceManager():GetAbilityByName(name); end);
    end
    ability_cache[name] = res or false;
    return res;
end

function res_field(res, key)
    if res == nil then return nil; end
    local v = nil;
    pcall(function() v = res[key]; end);
    return v;
end

item_name_cache = {};
function item_name(id)
    id = tonumber(id) or 0;
    if id <= 0 then return nil; end
    local c = item_name_cache[id];
    if c ~= nil then return c or nil; end
    local name = nil;
    pcall(function()
        local res = AshitaCore:GetResourceManager():GetItemById(id);
        if res ~= nil then name = res_string(res.Name); end
    end);
    item_name_cache[id] = name or false;
    return name;
end

function item_skill(id)
    local s = 0;
    pcall(function()
        local res = AshitaCore:GetResourceManager():GetItemById(id);
        if res ~= nil then s = tonumber(res.Skill) or 0; end
    end);
    return s;
end

-- ============================================================================
-- Player snapshot
-- ============================================================================

function equipped_item_id(slot)
    local id = 0;
    pcall(function()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local e = inv:GetEquippedItem(slot);
        local idx = tonumber(e.Index) or 0;
        if idx == 0 then return; end
        local bag = math.floor(bit.band(idx, 0xFF00) / 0x100);
        local pos = idx % 0x100;
        local item = inv:GetContainerItem(bag, pos);
        if item ~= nil then id = tonumber(item.Id) or 0; end
    end);
    if id == 65535 then id = 0; end
    return id;
end

function has_target()
    local yes = false;
    pcall(function()
        local t = AshitaCore:GetMemoryManager():GetTarget();
        yes = (tonumber(t:GetTargetIndex(0)) or 0) ~= 0;
    end);
    return yes;
end

function read_player()
    local mm = AshitaCore:GetMemoryManager();
    local player = mm:GetPlayer();
    local party = mm:GetParty();
    if player == nil or party == nil then return nil; end
    local me = { job = 0, lvl = 0, sub = 0, sublvl = 0, tp = 0, mp = 0, mpmax = 0, hp = 0, hpmax = 0 };
    pcall(function()
        me.job = tonumber(player:GetMainJob()) or 0;
        me.lvl = tonumber(player:GetMainJobLevel()) or 0;
        me.sub = tonumber(player:GetSubJob()) or 0;
        me.sublvl = tonumber(player:GetSubJobLevel()) or 0;
    end);
    pcall(function()
        me.tp = tonumber(party:GetMemberTP(0)) or 0;
        me.mp = tonumber(party:GetMemberMP(0)) or 0;
        me.hp = tonumber(party:GetMemberHP(0)) or 0;
    end);
    pcall(function()
        me.mpmax = tonumber(player:GetMPMax()) or 0;
        me.hpmax = tonumber(player:GetHPMax()) or 0;
    end);
    me.player = player;
    return me;
end

-- ============================================================================
-- "Do you have it?" checks, calibrated once against something you surely know
-- ============================================================================

-- HasAbility: 'raw' = resource id, 'minus' = resource id - 0x200,
-- false = not usable (fall back to levels), nil = not calibrated yet.
ja_mode = nil;
ws_mode = nil;   -- true = HasWeaponSkill works, false = use skill levels
spell_off = nil; -- LevelRequired index offset (1 = job + 1)

function call_has_ability(player, id)
    local ok, v = pcall(function() return player:HasAbility(id); end);
    return ok and v == true;
end

function calibrate_ja(me)
    if ja_mode ~= nil or me == nil or me.job <= 0 then return; end
    local list = JOB_ABILITIES[me.job];
    if list == nil then ja_mode = false; return; end
    for _, a in ipairs(list) do
        if a[3] == nil and a[2] <= me.lvl then
            local res = ability_by_name(a[1]);
            local id = tonumber(res_field(res, 'Id'));
            if id ~= nil then
                local raw = call_has_ability(me.player, id);
                local minus = id >= 0x200 and call_has_ability(me.player, id - 0x200) or false;
                if raw and not minus then ja_mode = 'raw';
                elseif minus and not raw then ja_mode = 'minus';
                elseif raw and minus then ja_mode = 'raw';
                else ja_mode = false; end
                return;
            end
        end
    end
    -- Nothing learned yet to test with: try again later.
end

function has_ability(me, res)
    if not ja_mode or res == nil then return nil; end
    local id = tonumber(res_field(res, 'Id'));
    if id == nil then return nil; end
    if ja_mode == 'minus' then id = id - 0x200; end
    return call_has_ability(me.player, id);
end

function calibrate_spells()
    if spell_off ~= nil then return; end
    pcall(function()
        local cure = AshitaCore:GetResourceManager():GetSpellById(1);
        if cure == nil then return; end
        local lr = cure.LevelRequired;
        local function at(i) local v = nil; pcall(function() v = tonumber(lr[i]); end); return v; end
        -- Cure: WHM (3) level 1, RDM (5) level 3.
        if at(4) == 1 and at(6) == 3 then spell_off = 1;
        elseif at(3) == 1 and at(5) == 3 then spell_off = 0; end
    end);
    if spell_off == nil then spell_off = 1; end
end

function spell_level(spell, job)
    if job == nil or job <= 0 then return nil; end
    local v = nil;
    pcall(function() v = tonumber(spell.LevelRequired[job + spell_off]); end);
    if v == nil or v < 1 or v > 99 then return nil; end
    return v;
end

function has_spell(me, index)
    local ok, v = pcall(function() return me.player:HasSpell(index); end);
    return ok and v == true;
end

function combat_skill(me, skill)
    local value, capped = 0, false;
    pcall(function()
        local cs = me.player:GetCombatSkill(skill);
        value = tonumber(cs:GetSkill()) or 0;
        capped = cs:IsCapped() == true;
    end);
    return value, capped;
end

-- ============================================================================
-- Recast timers (your own, as the game shows them)
-- ============================================================================

function update_recasts()
    local cds = {};
    pcall(function()
        local recast = AshitaCore:GetMemoryManager():GetRecast();
        for i = 0, 31 do
            local id = tonumber(recast:GetAbilityTimerId(i)) or 0;
            local t = tonumber(recast:GetAbilityTimer(i)) or 0;
            if (id ~= 0 or i == 0) and t > 0 then
                cds[id] = t / 60;
            end
        end
    end);
    state.ja_cd = cds;
end

function spell_recast(index)
    local t = 0;
    pcall(function()
        t = (tonumber(AshitaCore:GetMemoryManager():GetRecast():GetSpellTimer(index)) or 0) / 60;
    end);
    return t;
end

function fmt_time(sec)
    sec = math.max(0, math.ceil(tonumber(sec) or 0));
    if sec >= 3600 then return ('%d:%02d:%02d'):fmt(math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60); end
    return ('%d:%02d'):fmt(math.floor(sec / 60), sec % 60);
end

-- Remaining / longest seen, for the cooldown fill.
function cd_fraction(key, left)
    if left <= 0 then state.cd_max[key] = nil; return 0; end
    local m = state.cd_max[key];
    if m == nil or left > m then m = left; state.cd_max[key] = m; end
    return math.min(1, left / m);
end
