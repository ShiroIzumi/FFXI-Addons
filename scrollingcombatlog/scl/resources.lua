require('common');

local safe_resource_name;

local function safe_status_name(status_id)
    local rm = AshitaCore:GetResourceManager();
    if not rm then return nil end

    status_id = tonumber(status_id);
    if not status_id then return nil end

    -- Ashita v4 exposes status-effect names through the ResourceManager
    -- string tables. GetStatusById is not available/reliable on current v4
    -- builds, which caused valid effects to fall back to "Status #<id>".
    local ok, name = pcall(function()
        return rm:GetString('buffs.names', status_id);
    end);

    if ok and name ~= nil then
        name = tostring(name);
        if name ~= '' then
            return name;
        end
    end

    -- Secondary log-name table fallback for resources whose normal name is
    -- absent on a particular client/resource build.
    ok, name = pcall(function()
        return rm:GetString('buffs.names_log', status_id, 2);
    end);

    if ok and name ~= nil then
        name = tostring(name);
        if name ~= '' then
            return name;
        end
    end

    return nil;
end

-- ============================================================================
-- Entity helpers
-- ============================================================================

local entity_name_cache = {};
local entity_name_cache_count = 0;
local entity_name_misses = {};

local function safe_player_server_id()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then
        return nil;
    end

    local party = mm:GetParty();
    if not party then
        return nil;
    end

    local server_id = party:GetMemberServerId(0);
    if not server_id or server_id == 0 then
        return nil;
    end

    return server_id;
end

-- Pet ownership: the player entity's PetTargetIndex points at the pet's
-- entity slot. Cached briefly because this is read for every action packet.
local pet_cache = { id = nil, checked = -1 };

local function safe_pet_server_id()
    local now = os.clock();
    if (now - pet_cache.checked) < 0.5 then
        return pet_cache.id;
    end
    pet_cache.checked = now;
    pet_cache.id = nil;

    local ok, pet_id = pcall(function()
        local mm = AshitaCore:GetMemoryManager();
        if not mm then return nil end

        local party = mm:GetParty();
        local entity = mm:GetEntity();
        if not party or not entity then return nil end

        local player_index = party:GetMemberTargetIndex(0);
        if not player_index or player_index == 0 then return nil end

        local pet_index = entity:GetPetTargetIndex(player_index);
        if not pet_index or pet_index == 0 then return nil end

        local id = entity:GetServerId(pet_index);
        if not id or id == 0 then return nil end
        return id;
    end);

    if ok and pet_id then
        pet_cache.id = pet_id;
    end

    return pet_cache.id;
end

local function cache_entity_name(server_id, name)
    if entity_name_cache_count > 512 then
        entity_name_cache = {};
        entity_name_cache_count = 0;
    end
    entity_name_cache[server_id] = name;
    entity_name_cache_count = entity_name_cache_count + 1;
end

local function safe_entity_name(server_id)
    server_id = tonumber(server_id);
    if server_id == nil or server_id == 0 then
        return 'Unknown';
    end

    local cached = entity_name_cache[server_id];
    if cached then
        return cached;
    end

    -- A recent failed lookup is not retried every hit.
    local missed = entity_name_misses[server_id];
    if missed and (os.clock() - missed) < 5.0 then
        return 'Unknown';
    end

    local mm = AshitaCore:GetMemoryManager();
    if not mm then
        return 'Unknown';
    end

    local entity_mgr = mm:GetEntity();
    if not entity_mgr then
        return 'Unknown';
    end

    local function name_at(index)
        local ok_id, id = pcall(function() return entity_mgr:GetServerId(index); end);
        if not ok_id or id ~= server_id then
            return nil;
        end
        local ok_name, name = pcall(function() return entity_mgr:GetName(index); end);
        if ok_name and type(name) == 'string' and name ~= '' then
            return name;
        end
        return nil;
    end

    -- Fast path: monsters and NPCs encode their entity index in the server id.
    if bit.band(server_id, 0x1000000) ~= 0 then
        local index = bit.band(server_id, 0xFFF);
        if index >= 0x900 then
            index = index - 0x100;
        end
        if index < 0x900 then
            local name = name_at(index);
            if name then
                cache_entity_name(server_id, name);
                return name;
            end
        end
    end

    -- Party / alliance members.
    local party = mm:GetParty();
    if party then
        for slot = 0, 17 do
            local ok_id, id = pcall(function() return party:GetMemberServerId(slot); end);
            if ok_id and id == server_id then
                local ok_name, name = pcall(function() return party:GetMemberName(slot); end);
                if ok_name and type(name) == 'string' and name ~= '' then
                    cache_entity_name(server_id, name);
                    return name;
                end
            end
        end
    end

    -- Last resort: full entity scan (rare; result is cached).
    for index = 0, 0x8FF do
        local name = name_at(index);
        if name then
            cache_entity_name(server_id, name);
            return name;
        end
    end

    entity_name_misses[server_id] = os.clock();
    return 'Unknown';
end

safe_resource_name = function(resource)
    if resource == nil then
        return nil;
    end

    -- Current Ashita v4 resources expose Name as an indexable object/userdata.
    -- This is the same access pattern already proven in BLUSpells.
    local ok, name = pcall(function()
        if resource.Name ~= nil then
            local n = resource.Name[1];
            if type(n) == 'string' and n ~= '' then
                return n;
            end

            n = resource.Name[0];
            if type(n) == 'string' and n ~= '' then
                return n;
            end
        end

        return nil;
    end);

    if ok and type(name) == 'string' and name ~= '' then
        return name;
    end

    return nil;
end;

local function safe_spell_name(spell_id)
    local rm = AshitaCore:GetResourceManager();
    if not rm or not spell_id then
        return nil;
    end

    local ok, resource = pcall(function()
        return rm:GetSpellById(spell_id);
    end);

    if not ok then
        return nil;
    end

    return safe_resource_name(resource);
end

-- Element of a spell (0-7), or nil when the spell has no element.
local spell_element_cache = {};

local function safe_spell_element(spell_id)
    local id = tonumber(spell_id);
    if not id then return nil end

    local cached = spell_element_cache[id];
    if cached ~= nil then
        return cached ~= false and cached or nil;
    end

    local element = nil;
    pcall(function()
        local rm = AshitaCore:GetResourceManager();
        local resource = rm and rm:GetSpellById(id);
        if resource then
            local value = tonumber(resource.Element);
            if value and value >= 0 and value <= 7 then
                element = value;
            end
        end
    end);

    spell_element_cache[id] = element or false;
    return element;
end

local function safe_ability_name(ability_id)
    local rm = AshitaCore:GetResourceManager();
    if not rm or ability_id == nil then
        return nil;
    end

    local id = tonumber(ability_id);
    if not id then
        return nil;
    end

    local ok, resource = pcall(function()
        return rm:GetAbilityById(id);
    end);

    if not ok or not resource then
        return nil;
    end

    return safe_resource_name(resource);
end

local function safe_item_name(item_id)
    local rm = AshitaCore:GetResourceManager();
    local id = tonumber(item_id);
    if not rm or not id then
        return nil;
    end

    local ok, resource = pcall(function()
        return rm:GetItemById(id);
    end);

    if not ok or not resource then
        return nil;
    end

    return safe_resource_name(resource);
end

local function safe_monster_ability_name(ability_id)
    local id = tonumber(ability_id);
    if not id then
        return nil;
    end

    local rm = AshitaCore:GetResourceManager();
    if not rm then
        return nil;
    end

    -- Monster skills are not normal player Ability resources.
    -- For monster skills, the action packet argument uses a +256 offset.
    -- Resolve through the dedicated monsters.abilities string table.
    if id >= 256 then
        local ok, name = pcall(function()
            return rm:GetString('monsters.abilities', id - 256);
        end);

        if ok and type(name) == 'string' and name ~= '' then
            return name;
        end
    end

    -- Some pet/trust skill cases can use an ordinary ability id.
    local name = safe_ability_name(id);
    if name and name ~= '' then
        return name;
    end

    return nil;
end

return {
    safe_status_name = safe_status_name,
    safe_player_server_id = safe_player_server_id,
    safe_pet_server_id = safe_pet_server_id,
    safe_entity_name = safe_entity_name,
    safe_resource_name = safe_resource_name,
    safe_spell_name = safe_spell_name,
    safe_spell_element = safe_spell_element,
    safe_ability_name = safe_ability_name,
    safe_item_name = safe_item_name,
    safe_monster_ability_name = safe_monster_ability_name,
};
