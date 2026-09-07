--[[
    MobHunt - Ashita v4 / HorizonXI
    Version 1.0.4

    Tracks monsters by Zone + Mob Name:
      * Fights / encounters
      * Kills (party/alliance kill credit after personal participation)
      * Deaths to the mob
      * Lifetime and current-session statistics
      * Treasure-pool drops, quantities, and observed drop percentages
      * Searchable history with per-mob details

    Commands:
      /mobhunt
      /mh
      /mh history
      /mh config
      /mh session
      /mh debug

    Notes:
      * Merely targeting a monster never increments a fight.
      * An encounter starts when the player engages / acts on a monster,
        or when that monster acts on the player.
      * Drops are tied to packet 0x0D2's Dropper id/index when possible.
      * The addon uses per-character Ashita settings for persistent lifetime data.
]]--

addon.name      = 'MobHunt';
addon.author    = 'Izumi (ShiroIzumi)';
addon.version   = '1.0.13';
addon.desc      = 'Tracks mob encounters, kills, deaths, and observed drops by zone.';
addon.link      = '';

require 'common';

local imgui    = require 'imgui';
local settings = require 'settings';

local defaults = T{
    visible = true,
    history_visible = false,
    config_visible = false,

    font_scale = 1.00,

    appearance = T{
        background = T{ 0.00, 0.00, 0.00, 0.45 },
        accent = T{ 0.38, 0.78, 1.00, 1.00 },
        success = T{ 0.30, 1.00, 0.42, 1.00 },
        danger = T{ 1.00, 0.34, 0.38, 1.00 },
        muted = T{ 0.68, 0.70, 0.74, 1.00 },
        border = true,
        title_bar = true,
    },

    behavior = T{
        target_only = true,
        mini_mode = false,
        history_current_zone = true,
        show_session = true,
        show_drops = true,
        show_kills_per_hour = true,
        include_zero_drop_rows = false,
        debug = false,
        encounter_timeout = 120,
    },

    locks = T{
        target = false,
        history = false,
        config = false,
    },

    window = T{
        x = 150,
        y = 150,
        width = 470,
        height = 420,
    },

    mini_window = T{
        x = 150,
        y = 150,
        width = 345,
        height = 118,
    },

    history_window = T{
        x = 650,
        y = 130,
        width = 900,
        height = 700,
    },

    config_window = T{
        x = 1160,
        y = 150,
        width = 470,
        height = 590,
    },

    records = T{},

    -- Lightweight reload-safe markers. These do NOT add statistics themselves;
    -- they only tell a newly-loaded MobHunt instance that a fight was already
    -- counted before the addon reload.
    active_encounters = T{},
};

local config = settings.load(defaults);

local state = T{
    visible = { config.visible ~= false },
    history_visible = { config.history_visible == true },
    config_visible = { config.config_visible == true },

    font_scale = { tonumber(config.font_scale) or 1.00 },

    background = {
        tonumber(config.appearance and config.appearance.background and config.appearance.background[1]) or defaults.appearance.background[1],
        tonumber(config.appearance and config.appearance.background and config.appearance.background[2]) or defaults.appearance.background[2],
        tonumber(config.appearance and config.appearance.background and config.appearance.background[3]) or defaults.appearance.background[3],
        tonumber(config.appearance and config.appearance.background and config.appearance.background[4]) or defaults.appearance.background[4],
    },
    accent = {
        tonumber(config.appearance and config.appearance.accent and config.appearance.accent[1]) or defaults.appearance.accent[1],
        tonumber(config.appearance and config.appearance.accent and config.appearance.accent[2]) or defaults.appearance.accent[2],
        tonumber(config.appearance and config.appearance.accent and config.appearance.accent[3]) or defaults.appearance.accent[3],
        tonumber(config.appearance and config.appearance.accent and config.appearance.accent[4]) or defaults.appearance.accent[4],
    },
    success = {
        tonumber(config.appearance and config.appearance.success and config.appearance.success[1]) or defaults.appearance.success[1],
        tonumber(config.appearance and config.appearance.success and config.appearance.success[2]) or defaults.appearance.success[2],
        tonumber(config.appearance and config.appearance.success and config.appearance.success[3]) or defaults.appearance.success[3],
        tonumber(config.appearance and config.appearance.success and config.appearance.success[4]) or defaults.appearance.success[4],
    },
    danger = {
        tonumber(config.appearance and config.appearance.danger and config.appearance.danger[1]) or defaults.appearance.danger[1],
        tonumber(config.appearance and config.appearance.danger and config.appearance.danger[2]) or defaults.appearance.danger[2],
        tonumber(config.appearance and config.appearance.danger and config.appearance.danger[3]) or defaults.appearance.danger[3],
        tonumber(config.appearance and config.appearance.danger and config.appearance.danger[4]) or defaults.appearance.danger[4],
    },
    muted = {
        tonumber(config.appearance and config.appearance.muted and config.appearance.muted[1]) or defaults.appearance.muted[1],
        tonumber(config.appearance and config.appearance.muted and config.appearance.muted[2]) or defaults.appearance.muted[2],
        tonumber(config.appearance and config.appearance.muted and config.appearance.muted[3]) or defaults.appearance.muted[3],
        tonumber(config.appearance and config.appearance.muted and config.appearance.muted[4]) or defaults.appearance.muted[4],
    },

    border = { not (config.appearance and config.appearance.border == false) },
    title_bar = { not (config.appearance and config.appearance.title_bar == false) },

    target_only = { not (config.behavior and config.behavior.target_only == false) },
    mini_mode = { config.behavior and config.behavior.mini_mode == true },
    history_current_zone = { not (config.behavior and config.behavior.history_current_zone == false) },
    show_session = { not (config.behavior and config.behavior.show_session == false) },
    show_drops = { not (config.behavior and config.behavior.show_drops == false) },
    show_kills_per_hour = { not (config.behavior and config.behavior.show_kills_per_hour == false) },
    debug = { config.behavior and config.behavior.debug == true },
    encounter_timeout = { tonumber(config.behavior and config.behavior.encounter_timeout) or 120 },

    lock_target = { config.locks and config.locks.target == true },
    lock_history = { config.locks and config.locks.history == true },
    lock_config = { config.locks and config.locks.config == true },

    target_apply_geometry = true,
    history_apply_geometry = true,
    config_apply_geometry = true,

    target_geom = {
        tonumber(config.window and config.window.x) or defaults.window.x,
        tonumber(config.window and config.window.y) or defaults.window.y,
        tonumber(config.window and config.window.width) or defaults.window.width,
        tonumber(config.window and config.window.height) or defaults.window.height,
    },
    mini_geom = {
        tonumber(config.mini_window and config.mini_window.x) or defaults.mini_window.x,
        tonumber(config.mini_window and config.mini_window.y) or defaults.mini_window.y,
        tonumber(config.mini_window and config.mini_window.width) or defaults.mini_window.width,
        tonumber(config.mini_window and config.mini_window.height) or defaults.mini_window.height,
    },
    mini_apply_geometry = true,
    history_geom = {
        tonumber(config.history_window and config.history_window.x) or defaults.history_window.x,
        tonumber(config.history_window and config.history_window.y) or defaults.history_window.y,
        tonumber(config.history_window and config.history_window.width) or defaults.history_window.width,
        tonumber(config.history_window and config.history_window.height) or defaults.history_window.height,
    },
    config_geom = {
        tonumber(config.config_window and config.config_window.x) or defaults.config_window.x,
        tonumber(config.config_window and config.config_window.y) or defaults.config_window.y,
        tonumber(config.config_window and config.config_window.width) or defaults.config_window.width,
        tonumber(config.config_window and config.config_window.height) or defaults.config_window.height,
    },

    geometry_dirty = false,
    settings_dirty = false,
    data_dirty = false,
    last_save = 0,

    session_start = os.time(),
    session = T{},
    encounters = T{},       -- [mob_server_id] = encounter
    recent_dead = T{},      -- [mob_server_id] = { key, time, drop_occurrences }
    recent_kills = T{},     -- [mob_server_id] = os.clock()
    recent_deaths = T{},    -- [mob_server_id] = os.clock()
    last_hostile = nil,     -- most recent tracked mob that acted on the player
    last_player_hp = nil,
    player_dead = false,
    inventory_slots = T{},  -- [bag:index] = { item_id, count } used for direct-drop deltas
    inventory_cache_ready = false,
    treasure_slots = T{},   -- [0..9] = last observed ItemId in Ashita treasure-pool memory
    treasure_cache_ready = false,
    treasure_last_scan = 0,
    entity_cache = T{},     -- [server_id] = { index, name, zone_id, zone_name }
    current_target = nil,

    history_search = { '' },
    history_last_search = '',
    history_selected_key = nil,
    history_sort = 'kills',
    history_sort_desc = true,
    history_delete_key = nil,

    debug_counters = T{
        actions = 0,
        starts = 0,
        resumes = 0,
        kills = 0,
        deaths = 0,
        drop_packets = 0,
        treasure_memory_scans = 0,
        treasure_memory_drops = 0,
        inventory_packets = 0,
        direct_drops = 0,
        drops = 0,
        ignored_drops = 0,
    },
};

local DEATH_MESSAGES = T{ 6, 20, 113, 406, 605, 646 };

-- MobHunt originally shipped with an opaque blue-black background. 1.0.10
-- moves the stock appearance to the lighter StatusTimers-style black panel.
local LEGACY_DEFAULT_BG = T{ 0.018, 0.024, 0.032, 0.94 };
local STATUSTIMERS_BG = T{ 0.00, 0.00, 0.00, 0.45 };

local function dbg(message)
    if not state.debug[1] then return; end
    print(('[MobHunt] %s'):fmt(tostring(message)));
end

local function ensure_config_tables()
    if config.appearance == nil then config.appearance = T{}; end
    if config.behavior == nil then config.behavior = T{}; end
    if config.locks == nil then config.locks = T{}; end
    if config.window == nil then config.window = T{}; end
    if config.mini_window == nil then config.mini_window = T{}; end
    if config.history_window == nil then config.history_window = T{}; end
    if config.config_window == nil then config.config_window = T{}; end
    if config.records == nil then config.records = T{}; end
    if config.active_encounters == nil then config.active_encounters = T{}; end

    local names = { 'background', 'accent', 'success', 'danger', 'muted' };
    for _, name in ipairs(names) do
        if config.appearance[name] == nil then config.appearance[name] = T{}; end
    end
end

ensure_config_tables();

local function approximately(a, b)
    return math.abs((tonumber(a) or 0) - (tonumber(b) or 0)) < 0.002;
end

local function is_legacy_default_background(bg)
    if bg == nil then return false; end
    for i = 1, 4 do
        if not approximately(bg[i], LEGACY_DEFAULT_BG[i]) then return false; end
    end
    return true;
end

local function normalize_name(value)
    if value == nil then return ''; end
    return tostring(value):lower():gsub('[^%w]', '');
end

local function record_key(zone_id, name)
    return ('z%d_%s'):fmt(tonumber(zone_id) or 0, normalize_name(name));
end

local function safe_zone_name(zone_id)
    local rm = AshitaCore:GetResourceManager();
    if rm == nil then return ('Zone %d'):fmt(tonumber(zone_id) or 0); end

    local ok, value = pcall(function()
        return rm:GetString('zones.names', tonumber(zone_id) or 0);
    end);

    if ok and value ~= nil and tostring(value) ~= '' then
        return tostring(value);
    end

    return ('Zone %d'):fmt(tonumber(zone_id) or 0);
end

local function get_zone_id()
    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return 0; end

    local party = mm:GetParty();
    if party == nil then return 0; end

    local ok, zid = pcall(function() return party:GetMemberZone(0); end);
    if not ok then return 0; end

    return tonumber(zid) or 0;
end

local function get_player_id()
    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return 0; end

    local party = mm:GetParty();
    if party ~= nil then
        local ok, pid = pcall(function() return party:GetMemberServerId(0); end);
        if ok and tonumber(pid) and tonumber(pid) ~= 0 then
            return tonumber(pid);
        end
    end

    -- Safe fallback; never call GetServerId through a nil player object.
    local player = mm:GetPlayer();
    if not player then return 0; end

    local ok, pid = pcall(function() return player:GetServerId(); end);
    if ok then return tonumber(pid) or 0; end

    return 0;
end

local function get_entity_manager()
    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return nil; end
    local entity_mgr = mm:GetEntity();
    if not entity_mgr then return nil; end
    return entity_mgr;
end

local function get_entity_info(index, forced_id)
    index = tonumber(index);
    if index == nil or index < 0 then return nil; end

    local entity_mgr = get_entity_manager();
    if not entity_mgr then return nil; end

    local ok_id, sid = pcall(function() return entity_mgr:GetServerId(index); end);
    local ok_name, name = pcall(function() return entity_mgr:GetName(index); end);
    local ok_spawn, spawn_flags = pcall(function() return entity_mgr:GetSpawnFlags(index); end);

    sid = ok_id and tonumber(sid) or tonumber(forced_id);
    name = ok_name and tostring(name or '') or '';
    spawn_flags = ok_spawn and tonumber(spawn_flags) or 0;

    if (sid == nil or sid == 0) and tonumber(forced_id) then
        sid = tonumber(forced_id);
    end

    if sid == nil or sid == 0 or name == '' then
        return nil;
    end

    local zone_id = get_zone_id();
    local info = T{
        id = sid,
        index = index,
        name = name,
        zone_id = zone_id,
        zone_name = safe_zone_name(zone_id),
        spawn_flags = spawn_flags,
        is_mob = bit.band(spawn_flags, 0x0010) == 0x0010,
    };

    state.entity_cache[sid] = info;
    return info;
end

local function resolve_entity(server_id, hinted_index)
    server_id = tonumber(server_id);
    if server_id == nil or server_id == 0 then return nil; end

    if hinted_index ~= nil then
        local info = get_entity_info(hinted_index, server_id);
        if info ~= nil and info.id == server_id then return info; end
    end

    local cached = state.entity_cache[server_id];
    if cached ~= nil then
        local info = get_entity_info(cached.index, server_id);
        if info ~= nil and info.id == server_id then return info; end
        state.entity_cache[server_id] = nil;
    end

    local entity_mgr = get_entity_manager();
    if not entity_mgr then return nil; end

    local map_size = 2303;
    local ok_size, size = pcall(function() return entity_mgr:GetEntityMapSize(); end);
    if ok_size and tonumber(size) and tonumber(size) > 0 then
        map_size = math.min(tonumber(size) - 1, 4095);
    end

    for index = 0, map_size do
        local ok, sid = pcall(function() return entity_mgr:GetServerId(index); end);
        if ok and tonumber(sid) == server_id then
            return get_entity_info(index, server_id);
        end
    end

    return nil;
end

local function get_current_target()
    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return nil; end

    local target_mgr = mm:GetTarget();
    if target_mgr == nil then return nil; end

    local target_index = 0;
    local ok_sub, is_sub = pcall(function() return target_mgr:GetIsSubTargetActive(); end);
    if ok_sub and tonumber(is_sub) ~= 0 then
        local ok_idx, idx = pcall(function() return target_mgr:GetTargetIndex(1); end);
        if ok_idx then target_index = tonumber(idx) or 0; end
    else
        local ok_idx, idx = pcall(function() return target_mgr:GetTargetIndex(0); end);
        if ok_idx then target_index = tonumber(idx) or 0; end
    end

    if target_index <= 0 then return nil; end
    local info = get_entity_info(target_index);
    if info == nil or info.is_mob ~= true then return nil; end
    return info;
end

local function get_or_create_record(info)
    if info == nil or info.name == nil or info.name == '' or info.is_mob ~= true then return nil, nil; end

    local key = record_key(info.zone_id, info.name);
    local rec = config.records[key];

    if rec == nil then
        rec = T{
            name = info.name,
            zone_id = tonumber(info.zone_id) or 0,
            zone_name = info.zone_name or safe_zone_name(info.zone_id),
            fights = 0,
            kills = 0,
            deaths = 0,
            first_seen = os.time(),
            last_seen = os.time(),
            last_kill = 0,
            last_death = 0,
            current_streak = 0,
            best_streak = 0,
            drops = T{},
        };
        config.records[key] = rec;
        state.data_dirty = true;
    end

    if rec.drops == nil then rec.drops = T{}; end
    if rec.zone_name == nil or rec.zone_name == '' then rec.zone_name = info.zone_name; end
    if rec.name == nil or rec.name == '' then rec.name = info.name; end

    return rec, key;
end

local function get_session_record(key)
    if key == nil then return nil; end

    local s = state.session[key];
    if s == nil then
        s = T{
            fights = 0,
            kills = 0,
            deaths = 0,
            drops = T{},
            first_fight = 0,
        };
        state.session[key] = s;
    end
    if s.drops == nil then s.drops = T{}; end
    return s;
end

local function encounter_marker_key(mob_id)
    return tostring(tonumber(mob_id) or 0);
end

local function clear_persisted_encounter(mob_id)
    if config.active_encounters == nil then return; end
    config.active_encounters[encounter_marker_key(mob_id)] = nil;
end

local function persist_encounter(enc)
    if enc == nil or enc.id == nil then return; end
    if config.active_encounters == nil then config.active_encounters = T{}; end

    config.active_encounters[encounter_marker_key(enc.id)] = T{
        id = tonumber(enc.id) or 0,
        index = tonumber(enc.index) or 0,
        name = tostring(enc.name or ''),
        zone_id = tonumber(enc.zone_id) or 0,
        zone_name = tostring(enc.zone_name or ''),
        key = tostring(enc.key or ''),
        started_wall = tonumber(enc.started_wall) or os.time(),
        last_activity_wall = os.time(),
    };
end

local function can_resume_persisted_encounter(info, key, marker)
    if marker == nil then return false; end

    local now = os.time();
    local timeout = math.max(15, tonumber(state.encounter_timeout[1]) or 120);
    local last_wall = tonumber(marker.last_activity_wall) or tonumber(marker.started_wall) or 0;

    if last_wall <= 0 or (now - last_wall) > timeout then return false; end
    if tonumber(marker.id) ~= tonumber(info.id) then return false; end
    if tonumber(marker.zone_id) ~= tonumber(info.zone_id) then return false; end
    if tostring(marker.key or '') ~= tostring(key or '') then return false; end
    if normalize_name(marker.name) ~= normalize_name(info.name) then return false; end

    return true;
end

local function start_encounter(info, reason)
    if state.player_dead == true then return; end
    if info == nil or info.id == nil or info.name == nil or info.name == '' or info.is_mob ~= true then return; end

    local existing = state.encounters[info.id];
    if existing ~= nil then
        existing.last_activity = os.clock();
        existing.last_activity_wall = os.time();
        persist_encounter(existing);
        return;
    end

    local rec, key = get_or_create_record(info);
    if rec == nil then return; end

    -- A reload wipes state.encounters, but the persistent marker survives.
    -- If this is the same mob/zone fight and it is still fresh, restore the
    -- runtime encounter WITHOUT incrementing the lifetime fight counter again.
    local marker = config.active_encounters and
        config.active_encounters[encounter_marker_key(info.id)] or nil;

    if can_resume_persisted_encounter(info, key, marker) then
        state.encounters[info.id] = T{
            id = info.id,
            index = info.index,
            name = info.name,
            zone_id = info.zone_id,
            zone_name = info.zone_name,
            key = key,
            started = os.clock(),
            last_activity = os.clock(),
            started_wall = tonumber(marker.started_wall) or os.time(),
            last_activity_wall = os.time(),
            resumed = true,
        };

        -- Session statistics intentionally restart when the addon reloads.
        -- Count the already-active fight once in this new runtime session so a
        -- subsequent kill/death does not produce Kills > Fights for the session.
        local s = get_session_record(key);
        if (tonumber(s.fights) or 0) == 0 then
            s.fights = 1;
            s.first_fight = os.time();
        end

        persist_encounter(state.encounters[info.id]);
        state.debug_counters.resumes = (tonumber(state.debug_counters.resumes) or 0) + 1;
        dbg(('Resumed existing encounter after reload: %s (%s), reason=%s'):fmt(
            info.name, info.zone_name, tostring(reason)));
        return;
    end

    -- Any stale/recycled marker with this server id must not suppress a truly
    -- new fight.
    clear_persisted_encounter(info.id);

    rec.fights = (tonumber(rec.fights) or 0) + 1;
    rec.last_seen = os.time();

    local s = get_session_record(key);
    s.fights = (tonumber(s.fights) or 0) + 1;
    if tonumber(s.first_fight) == 0 then s.first_fight = os.time(); end

    state.encounters[info.id] = T{
        id = info.id,
        index = info.index,
        name = info.name,
        zone_id = info.zone_id,
        zone_name = info.zone_name,
        key = key,
        started = os.clock(),
        last_activity = os.clock(),
        started_wall = os.time(),
        last_activity_wall = os.time(),
        resumed = false,
    };

    persist_encounter(state.encounters[info.id]);

    state.debug_counters.starts = (tonumber(state.debug_counters.starts) or 0) + 1;
    state.data_dirty = true;
    dbg(('Encounter: %s (%s), reason=%s'):fmt(info.name, info.zone_name, tostring(reason)));
end

local function touch_encounter(mob_id)
    mob_id = tonumber(mob_id) or 0;
    local enc = state.encounters[mob_id];
    if enc ~= nil then
        enc.last_activity = os.clock();
        enc.last_activity_wall = os.time();
        persist_encounter(enc);
    end
end

local function count_kill(mob_id, hinted_index, source)
    mob_id = tonumber(mob_id);
    if mob_id == nil or mob_id == 0 then return; end

    local last = state.recent_kills[mob_id];
    if last ~= nil and (os.clock() - last) < 2.0 then
        return;
    end

    local enc = state.encounters[mob_id];
    if enc == nil then
        -- MobHunt only credits kills after the player participated.
        return;
    end

    local info = resolve_entity(mob_id, hinted_index) or T{
        id = mob_id,
        index = enc.index,
        name = enc.name,
        zone_id = enc.zone_id,
        zone_name = enc.zone_name,
        is_mob = true,
    };

    local rec, key = get_or_create_record(info);
    if rec == nil then return; end

    rec.kills = (tonumber(rec.kills) or 0) + 1;
    rec.last_kill = os.time();
    rec.last_seen = os.time();
    rec.current_streak = (tonumber(rec.current_streak) or 0) + 1;
    rec.best_streak = math.max(tonumber(rec.best_streak) or 0, tonumber(rec.current_streak) or 0);

    local s = get_session_record(key);
    s.kills = (tonumber(s.kills) or 0) + 1;

    state.recent_kills[mob_id] = os.clock();
    state.recent_dead[mob_id] = T{
        key = key,
        time = os.clock(),
        info = info,
        treasure_seen = false,
        drop_occurrences = T{},
    };
    state.encounters[mob_id] = nil;
    clear_persisted_encounter(mob_id);

    state.debug_counters.kills = (tonumber(state.debug_counters.kills) or 0) + 1;
    state.data_dirty = true;
    dbg(('Kill: %s (%s), source=%s'):fmt(info.name, info.zone_name, tostring(source)));
end

local function count_death(mob_id, hinted_index, source)
    mob_id = tonumber(mob_id);
    if mob_id == nil or mob_id == 0 then return; end

    local last = state.recent_deaths[mob_id];
    if last ~= nil and (os.clock() - (tonumber(last) or 0)) < 5.0 then
        return;
    end

    local enc = state.encounters[mob_id];
    local info = resolve_entity(mob_id, hinted_index);

    if info == nil and enc ~= nil then
        info = T{
            id = mob_id,
            index = enc.index,
            name = enc.name,
            zone_id = enc.zone_id,
            zone_name = enc.zone_name,
            is_mob = true,
        };
    end

    if info == nil or info.is_mob ~= true then return; end

    -- A killing blow proves participation even if the initial encounter packet
    -- was missed. Temporarily permit start_encounter for this path.
    if enc == nil then
        local dead_state = state.player_dead;
        state.player_dead = false;
        start_encounter(info, 'death');
        state.player_dead = dead_state;
    end

    local rec, key = get_or_create_record(info);
    if rec == nil then return; end

    rec.deaths = (tonumber(rec.deaths) or 0) + 1;
    rec.last_death = os.time();
    rec.last_seen = os.time();
    rec.current_streak = 0;

    local s = get_session_record(key);
    s.deaths = (tonumber(s.deaths) or 0) + 1;

    state.recent_deaths[mob_id] = os.clock();
    state.player_dead = true;

    -- A KO ends combat. Clear all currently-open encounters so packets received
    -- while dead cannot create phantom follow-up fights.
    for id, _ in pairs(state.encounters) do
        clear_persisted_encounter(id);
    end
    state.encounters = T{};

    state.debug_counters.deaths = (tonumber(state.debug_counters.deaths) or 0) + 1;
    state.data_dirty = true;

    dbg(('Death to: %s (%s), source=%s'):fmt(
        info.name, info.zone_name, tostring(source or 'unknown')));
end

local function item_name(item_id)
    item_id = tonumber(item_id) or 0;
    if item_id == 65535 then return 'Gil'; end

    local rm = AshitaCore:GetResourceManager();
    if rm == nil then return ('Item %d'):fmt(tonumber(item_id) or 0); end

    local ok, item = pcall(function() return rm:GetItemById(tonumber(item_id) or 0); end);
    if not ok or item == nil then return ('Item %d'):fmt(tonumber(item_id) or 0); end

    local name = nil;
    pcall(function()
        if item.Name ~= nil then
            name = item.Name[0] or item.Name[1];
        end
    end);

    if name == nil or tostring(name) == '' then
        return ('Item %d'):fmt(tonumber(item_id) or 0);
    end
    return tostring(name);
end

local function count_drop(dropper_id, dropper_index, item_id, count)
    dropper_id = tonumber(dropper_id);
    dropper_index = tonumber(dropper_index);
    item_id = tonumber(item_id);
    count = math.max(1, tonumber(count) or 1);

    state.debug_counters.drop_packets = (tonumber(state.debug_counters.drop_packets) or 0) + 1;

    if dropper_id == nil or dropper_id == 0 or item_id == nil or item_id <= 0 then
        state.debug_counters.ignored_drops = (tonumber(state.debug_counters.ignored_drops) or 0) + 1;
        dbg(('Ignored drop packet: dropper=%s index=%s item=%s count=%s'):fmt(
            tostring(dropper_id), tostring(dropper_index), tostring(item_id), tostring(count)));
        return;
    end

    -- IMPORTANT: Treasure can arrive after the monster has died/despawned and its
    -- spawn flags are no longer useful. Prefer the encounter/death record we already
    -- established instead of requiring the dead entity to resolve as a live mob.
    local key = nil;
    local rec = nil;
    local source_name = nil;

    local enc = state.encounters[dropper_id];
    if enc ~= nil then
        key = enc.key;
        rec = key and config.records[key] or nil;
        source_name = enc.name;
    end

    if rec == nil then
        local dead = state.recent_dead[dropper_id];
        if dead ~= nil and (os.clock() - (tonumber(dead.time) or 0)) <= 30.0 then
            key = dead.key;
            rec = key and config.records[key] or nil;
            source_name = dead.info and dead.info.name or nil;
        end
    end

    -- If the treasure packet arrives before our kill path has run, resolving the
    -- still-live entity is a valid fallback. This path still enforces mob filtering.
    if rec == nil then
        local info = resolve_entity(dropper_id, dropper_index);
        if info ~= nil and info.is_mob == true then
            rec, key = get_or_create_record(info);
            source_name = info.name;
        end
    end

    if rec == nil or key == nil then
        state.debug_counters.ignored_drops = (tonumber(state.debug_counters.ignored_drops) or 0) + 1;
        dbg(('Unassociated treasure: dropper=%d index=%s item=%d (%s) count=%d'):fmt(
            dropper_id, tostring(dropper_index), item_id, item_name(item_id), count));
        return;
    end

    if rec.drops == nil then rec.drops = T{}; end

    local ikey = tostring(item_id);
    local drop = rec.drops[ikey];
    if drop == nil then
        drop = T{
            item_id = item_id,
            name = item_name(item_id),
            occurrences = 0,
            quantity = 0,
            first_seen = os.time(),
            last_seen = os.time(),
        };
        rec.drops[ikey] = drop;
    end

    drop.occurrences = (tonumber(drop.occurrences) or 0) + 1;
    drop.quantity = (tonumber(drop.quantity) or 0) + count;
    drop.last_seen = os.time();

    local srec = get_session_record(key);
    local sdrop = srec.drops[ikey];
    if sdrop == nil then
        sdrop = T{ occurrences = 0, quantity = 0 };
        srec.drops[ikey] = sdrop;
    end
    sdrop.occurrences = (tonumber(sdrop.occurrences) or 0) + 1;
    sdrop.quantity = (tonumber(sdrop.quantity) or 0) + count;

    state.debug_counters.drops = (tonumber(state.debug_counters.drops) or 0) + 1;
    state.data_dirty = true;
    dbg(('Drop recorded: %s x%d from %s [dropper=%d index=%s]'):fmt(
        drop.name, count, tostring(source_name or rec.name or 'Unknown'), dropper_id, tostring(dropper_index)));
end

local function inventory_slot_key(bag, index)
    return ('%d:%d'):fmt(tonumber(bag) or 0, tonumber(index) or 0);
end

local function cache_inventory_slot(bag, index, item_id, count)
    bag = tonumber(bag) or 0;
    index = tonumber(index) or 0;
    if index <= 0 then return; end
    state.inventory_slots[inventory_slot_key(bag, index)] = T{
        item_id = tonumber(item_id) or 0,
        count = tonumber(count) or 0,
    };
end

local function initialize_inventory_cache()
    if state.inventory_cache_ready then return; end

    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return; end
    local inv = mm:GetInventory();
    if inv == nil then return; end

    local max_slots = 80;
    local ok_max, value = pcall(function() return inv:GetContainerCountMax(0); end);
    if ok_max and tonumber(value) and tonumber(value) > 0 then
        max_slots = tonumber(value);
    end

    for index = 1, max_slots do
        local ok_item, item = pcall(function() return inv:GetContainerItem(0, index); end);
        if ok_item and item ~= nil then
            cache_inventory_slot(0, index, item.Id, item.Count);
        else
            cache_inventory_slot(0, index, 0, 0);
        end
    end

    state.inventory_cache_ready = true;
end

local function most_recent_direct_drop_source()
    local now = os.clock();
    local best = nil;
    local best_time = -1;

    for _, dead in pairs(state.recent_dead) do
        if dead ~= nil then
            local t = tonumber(dead.time) or 0;
            local age = now - t;
            -- Direct inventory awards normally arrive essentially with the kill.
            -- Keep this deliberately tight to avoid attributing unrelated inventory changes.
            if age >= 0 and age <= 6.0 and dead.treasure_seen ~= true and t > best_time then
                if dead.key ~= nil and config.records[dead.key] ~= nil then
                    best = dead;
                    best_time = t;
                end
            end
        end
    end

    return best;
end

local function most_recent_kill_source(max_age)
    local now = os.clock();
    local best = nil;
    local best_time = -1;
    max_age = tonumber(max_age) or 12.0;

    for _, dead in pairs(state.recent_dead) do
        if dead ~= nil then
            local t = tonumber(dead.time) or 0;
            local age = now - t;
            if age >= 0 and age <= max_age and t > best_time then
                best = dead;
                best_time = t;
            end
        end
    end

    return best;
end

local function record_drop_for_dead(dead, item_id, quantity, source)
    if dead == nil or dead.key == nil then return false; end

    item_id = tonumber(item_id) or 0;
    quantity = math.max(1, tonumber(quantity) or 1);

    -- 0 = invalid; 65535 is gil in the treasure pool and is not treated as an item drop.
    if item_id <= 0 or item_id == 65535 then return false; end

    local rec = config.records[dead.key];
    if rec == nil then
        dbg(('Drop ignored: record no longer exists for key=%s item=%d source=%s'):fmt(
            tostring(dead.key), item_id, tostring(source)));
        return false;
    end

    if rec.drops == nil then rec.drops = T{}; end

    local ikey = tostring(item_id);
    local drop = rec.drops[ikey];
    if drop == nil then
        drop = T{
            item_id = item_id,
            name = item_name(item_id),
            occurrences = 0,
            quantity = 0,
            first_seen = os.time(),
            last_seen = os.time(),
        };
        rec.drops[ikey] = drop;
    end

    -- Occurrence means "this item appeared on this kill", not item quantity.
    -- Three Fire Crystals from one kill = occurrences 1, quantity 3.
    if dead.drop_occurrences == nil then dead.drop_occurrences = T{}; end
    local first_for_kill = dead.drop_occurrences[ikey] ~= true;

    if first_for_kill then
        drop.occurrences = (tonumber(drop.occurrences) or 0) + 1;
        dead.drop_occurrences[ikey] = true;
    end

    drop.quantity = (tonumber(drop.quantity) or 0) + quantity;
    drop.last_seen = os.time();

    local srec = get_session_record(dead.key);
    local sdrop = srec.drops[ikey];
    if sdrop == nil then
        sdrop = T{ occurrences = 0, quantity = 0 };
        srec.drops[ikey] = sdrop;
    end

    if first_for_kill then
        sdrop.occurrences = (tonumber(sdrop.occurrences) or 0) + 1;
    end
    sdrop.quantity = (tonumber(sdrop.quantity) or 0) + quantity;

    state.debug_counters.drops = (tonumber(state.debug_counters.drops) or 0) + 1;
    state.data_dirty = true;

    dbg(('Drop recorded: %s x%d from %s [%s]'):fmt(
        tostring(drop.name or ('Item ' .. tostring(item_id))),
        quantity,
        tostring(rec.name or 'Unknown'),
        tostring(source or 'unknown')
    ));

    return true;
end

local function initialize_treasure_cache()
    if state.treasure_cache_ready then return; end

    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return; end

    local inventory = mm:GetInventory();
    if inventory == nil then return; end

    -- Baseline the currently-visible pool. This prevents MobHunt from attributing
    -- treasure that was already in the pool when the addon was loaded/reloaded.
    for slot = 0, 9 do
        local ok, item = pcall(function() return inventory:GetTreasurePoolItem(slot); end);
        if ok and item ~= nil and item.ItemId ~= nil then
            local item_id = tonumber(item.ItemId) or 0;
            if item_id > 0 and item_id ~= 65535 then
                state.treasure_slots[slot] = item_id;
            else
                state.treasure_slots[slot] = nil;
            end
        else
            state.treasure_slots[slot] = nil;
        end
    end

    state.treasure_cache_ready = true;
    dbg('Treasure-pool memory baseline initialized.');
end

local function scan_treasure_pool_memory()
    initialize_treasure_cache();
    if not state.treasure_cache_ready then return; end

    local now = os.clock();
    if (now - (tonumber(state.treasure_last_scan) or 0)) < 0.10 then return; end
    state.treasure_last_scan = now;

    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return; end

    local inventory = mm:GetInventory();
    if inventory == nil then return; end

    state.debug_counters.treasure_memory_scans =
        (tonumber(state.debug_counters.treasure_memory_scans) or 0) + 1;

    for slot = 0, 9 do
        local item_id = 0;
        local ok, item = pcall(function() return inventory:GetTreasurePoolItem(slot); end);

        if ok and item ~= nil and item.ItemId ~= nil then
            item_id = tonumber(item.ItemId) or 0;
        end

        if item_id == 65535 then
            -- Gil is intentionally excluded from the item drop table.
            item_id = 0;
        end

        local previous = tonumber(state.treasure_slots[slot]) or 0;

        -- A slot either went from empty -> item, or changed directly to a new item.
        if item_id > 0 and item_id ~= previous then
            local dead = most_recent_kill_source(12.0);
            if dead ~= nil then
                if record_drop_for_dead(dead, item_id, 1, ('treasure-memory slot %d'):fmt(slot)) then
                    dead.treasure_seen = true;
                    state.debug_counters.treasure_memory_drops =
                        (tonumber(state.debug_counters.treasure_memory_drops) or 0) + 1;
                end
            else
                dbg(('New treasure-pool item ignored: slot=%d item=%d (%s); no recent MobHunt kill.'):fmt(
                    slot, item_id, item_name(item_id)));
            end
        end

        if item_id > 0 then
            state.treasure_slots[slot] = item_id;
        else
            state.treasure_slots[slot] = nil;
        end
    end
end

local function record_direct_inventory_drop(item_id, quantity, source_packet)
    item_id = tonumber(item_id) or 0;
    quantity = tonumber(quantity) or 0;
    if item_id <= 0 or quantity <= 0 then return false; end

    local dead = most_recent_direct_drop_source();
    if dead == nil then
        dbg(('Direct inventory candidate ignored: item=%d (%s) qty=%d source=%s; no recent unpooled kill.'):fmt(
            item_id, item_name(item_id), quantity, tostring(source_packet)));
        return false;
    end

    if record_drop_for_dead(dead, item_id, quantity, source_packet) then
        state.debug_counters.direct_drops = (tonumber(state.debug_counters.direct_drops) or 0) + 1;
        return true;
    end

    return false;
end

local function parse_inventory_assign_packet(e)
    if e == nil or e.data_modified == nil then return nil; end
    local ok, p = pcall(function()
        return T{
            count = struct.unpack('I', e.data_modified, 0x04 + 1),
            item = struct.unpack('H', e.data_modified, 0x08 + 1),
            bag = struct.unpack('B', e.data_modified, 0x0A + 1),
            index = struct.unpack('B', e.data_modified, 0x0B + 1),
        };
    end);
    if not ok then return nil; end
    return p;
end

local function parse_inventory_modify_packet(e)
    if e == nil or e.data_modified == nil then return nil; end
    local ok, p = pcall(function()
        return T{
            count = struct.unpack('I', e.data_modified, 0x04 + 1),
            bag = struct.unpack('B', e.data_modified, 0x08 + 1),
            index = struct.unpack('B', e.data_modified, 0x09 + 1),
        };
    end);
    if not ok then return nil; end
    return p;
end

local function parse_action_packet(e)
    if e == nil or e.data_raw == nil then return nil; end

    local ok, result = pcall(function()
        local bit_offset = 40;
        local function read_bits(count)
            local value = ashita.bits.unpack_be(e.data_raw, bit_offset, count);
            bit_offset = bit_offset + count;
            return tonumber(value) or 0;
        end

        local act = T{
            actor_id = read_bits(32),
            target_count = read_bits(6),
            _res = read_bits(4),
            category = read_bits(4),
            param = read_bits(32),
            info = read_bits(32),
            targets = T{},
        };

        for _ = 1, act.target_count do
            local target = T{
                id = read_bits(32),
                action_count = read_bits(4),
            };
            act.targets:append(target);

            for _ = 1, target.action_count do
                read_bits(3);   -- miss
                read_bits(2);   -- kind
                read_bits(12);  -- sub-kind
                read_bits(5);   -- info
                read_bits(5);   -- scale
                read_bits(17);  -- value
                read_bits(10);  -- message
                read_bits(31);  -- bit

                local has_proc = read_bits(1);
                if has_proc ~= 0 then
                    read_bits(6);
                    read_bits(4);
                    read_bits(17);
                    read_bits(10);
                end

                local has_react = read_bits(1);
                if has_react ~= 0 then
                    read_bits(6);
                    read_bits(4);
                    read_bits(14);
                    read_bits(10);
                end
            end
        end

        return act;
    end);

    if not ok then
        dbg(('Action parse failed: %s'):fmt(tostring(result)));
        return nil;
    end

    return result;
end

local function parse_action_message(e)
    if e == nil or e.data_modified == nil then return nil; end

    local ok, p = pcall(function()
        return T{
            actor = struct.unpack('I', e.data_modified, 0x04 + 1),
            target = struct.unpack('I', e.data_modified, 0x08 + 1),
            param1 = struct.unpack('I', e.data_modified, 0x0C + 1),
            param2 = struct.unpack('I', e.data_modified, 0x10 + 1),
            actor_index = struct.unpack('H', e.data_modified, 0x14 + 1),
            target_index = struct.unpack('H', e.data_modified, 0x16 + 1),
            message = struct.unpack('H', e.data_modified, 0x18 + 1),
        };
    end);

    if not ok then return nil; end
    return p;
end

local function parse_kill_packet(e)
    if e == nil or e.data_modified == nil then return nil; end

    local ok, p = pcall(function()
        return T{
            player = struct.unpack('I', e.data_modified, 0x04 + 1),
            target = struct.unpack('I', e.data_modified, 0x08 + 1),
            player_index = struct.unpack('H', e.data_modified, 0x0C + 1),
            target_index = struct.unpack('H', e.data_modified, 0x0E + 1),
            amount = struct.unpack('I', e.data_modified, 0x10 + 1),
            chain = struct.unpack('I', e.data_modified, 0x14 + 1),
            message = struct.unpack('H', e.data_modified, 0x18 + 1),
        };
    end);

    if not ok then return nil; end
    return p;
end

local function parse_drop_packet(e)
    if e == nil or e.data_modified == nil then return nil; end

    local ok, p = pcall(function()
        return T{
            dropper = struct.unpack('I', e.data_modified, 0x04 + 1),
            count = struct.unpack('I', e.data_modified, 0x08 + 1),
            item = struct.unpack('H', e.data_modified, 0x0C + 1),
            dropper_index = struct.unpack('H', e.data_modified, 0x0E + 1),
            pool_index = struct.unpack('B', e.data_modified, 0x10 + 1),
        };
    end);

    if not ok then return nil; end
    return p;
end

local function get_player_hp()
    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return nil; end

    local party = mm:GetParty();
    if party == nil then return nil; end

    local ok, hp = pcall(function() return party:GetMemberHP(0); end);
    if not ok then return nil; end

    hp = tonumber(hp);
    if hp == nil then return nil; end
    return hp;
end

local function get_single_active_encounter()
    local found = nil;
    for _, enc in pairs(state.encounters) do
        if enc ~= nil then
            if found ~= nil then return nil; end
            found = enc;
        end
    end
    return found;
end

local function monitor_player_death()
    local hp = get_player_hp();
    if hp == nil then return; end

    if state.last_player_hp == nil then
        state.last_player_hp = hp;
        state.player_dead = hp <= 0;
        return;
    end

    if state.last_player_hp > 0 and hp <= 0 then
        state.player_dead = true;

        local source = nil;
        if state.last_hostile ~= nil
            and (os.clock() - (tonumber(state.last_hostile.time) or 0)) <= 10.0
            and state.encounters[tonumber(state.last_hostile.id) or 0] ~= nil then
            source = state.last_hostile;
        else
            local enc = get_single_active_encounter();
            if enc ~= nil then
                source = T{ id = enc.id, index = enc.index, time = os.clock() };
            end
        end

        if source ~= nil then
            count_death(source.id, source.index, 'hp_zero');
        else
            dbg('HP reached 0, but no single safe MobHunt killer could be identified.');
        end
    elseif state.last_player_hp <= 0 and hp > 0 then
        state.player_dead = false;
        dbg('Player revived; new encounters may begin.');
    else
        state.player_dead = hp <= 0;
    end

    state.last_player_hp = hp;
end

local function cleanup_runtime()
    local now = os.clock();
    local timeout = math.max(15, tonumber(state.encounter_timeout[1]) or 120);

    for id, enc in pairs(state.encounters) do
        if enc == nil or (now - (tonumber(enc.last_activity) or now)) > timeout then
            state.encounters[id] = nil;
            clear_persisted_encounter(id);
            state.data_dirty = true;
        end
    end

    -- Also remove stale markers that survived a previous unload but were never
    -- restored into runtime state.
    if config.active_encounters ~= nil then
        local wall_now = os.time();
        local current_zone = get_zone_id();
        for marker_id, marker in pairs(config.active_encounters) do
            local last_wall = marker and
                (tonumber(marker.last_activity_wall) or tonumber(marker.started_wall)) or 0;
            local marker_zone = marker and tonumber(marker.zone_id) or -1;

            if last_wall <= 0
                or (wall_now - last_wall) > timeout
                or (current_zone ~= 0 and marker_zone ~= current_zone) then
                config.active_encounters[marker_id] = nil;
                state.data_dirty = true;
            end
        end
    end

    for id, dead in pairs(state.recent_dead) do
        if dead == nil or (now - (tonumber(dead.time) or now)) > 35 then
            state.recent_dead[id] = nil;
        end
    end

    for id, ts in pairs(state.recent_kills) do
        if (now - (tonumber(ts) or now)) > 10 then
            state.recent_kills[id] = nil;
        end
    end

    for id, ts in pairs(state.recent_deaths) do
        if (now - (tonumber(ts) or now)) > 10 then
            state.recent_deaths[id] = nil;
        end
    end

    if state.last_hostile ~= nil
        and (now - (tonumber(state.last_hostile.time) or now)) > 15 then
        state.last_hostile = nil;
    end
end

local function save_all()
    ensure_config_tables();

    config.visible = state.visible[1];
    config.history_visible = state.history_visible[1];
    config.config_visible = state.config_visible[1];
    config.font_scale = state.font_scale[1];

    local colors = {
        background = state.background,
        accent = state.accent,
        success = state.success,
        danger = state.danger,
        muted = state.muted,
    };
    for name, values in pairs(colors) do
        for i = 1, 4 do config.appearance[name][i] = values[i]; end
    end

    config.appearance.border = state.border[1];
    config.appearance.title_bar = state.title_bar[1];

    config.behavior.target_only = state.target_only[1];
    config.behavior.mini_mode = state.mini_mode[1];
    config.behavior.history_current_zone = state.history_current_zone[1];
    config.behavior.show_session = state.show_session[1];
    config.behavior.show_drops = state.show_drops[1];
    config.behavior.show_kills_per_hour = state.show_kills_per_hour[1];
    config.behavior.debug = state.debug[1];
    config.behavior.encounter_timeout = math.floor(math.max(15, tonumber(state.encounter_timeout[1]) or 120));

    config.locks.target = state.lock_target[1];
    config.locks.history = state.lock_history[1];
    config.locks.config = state.lock_config[1];

    local function write_geom(dst, src)
        dst.x = src[1]; dst.y = src[2]; dst.width = src[3]; dst.height = src[4];
    end

    write_geom(config.window, state.target_geom);
    write_geom(config.mini_window, state.mini_geom);
    write_geom(config.history_window, state.history_geom);
    write_geom(config.config_window, state.config_geom);

    settings.save();
end

local function capture_geometry(geom)
    local x, y = imgui.GetWindowPos();
    local w, h = imgui.GetWindowSize();

    x = tonumber(x); y = tonumber(y); w = tonumber(w); h = tonumber(h);
    if x == nil or y == nil or w == nil or h == nil then return; end

    if math.abs(x - geom[1]) >= 1 or math.abs(y - geom[2]) >= 1
        or math.abs(w - geom[3]) >= 1 or math.abs(h - geom[4]) >= 1 then
        geom[1] = x; geom[2] = y; geom[3] = w; geom[4] = h;
        state.geometry_dirty = true;
    end
end

local function push_theme()
    imgui.PushStyleColor(ImGuiCol_WindowBg, state.background);
    imgui.PushStyleColor(ImGuiCol_Header, { state.accent[1] * 0.32, state.accent[2] * 0.32, state.accent[3] * 0.32, 0.78 });
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, { state.accent[1] * 0.44, state.accent[2] * 0.44, state.accent[3] * 0.44, 0.88 });
    imgui.PushStyleColor(ImGuiCol_HeaderActive, { state.accent[1] * 0.58, state.accent[2] * 0.58, state.accent[3] * 0.58, 0.96 });

    -- StatusTimers-inspired presentation: rounded black panel and tight spacing.
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 7.0);
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 4.0 * state.font_scale[1], 3.0 * state.font_scale[1] });
end

local function pop_theme()
    imgui.PopStyleVar(3);
    imgui.PopStyleColor(4);
end

local function window_flags(locked, auto_resize)
    local flags = ImGuiWindowFlags_NoNav;

    if auto_resize then
        flags = bit.bor(flags, ImGuiWindowFlags_AlwaysAutoResize);
    elseif locked then
        flags = bit.bor(flags, ImGuiWindowFlags_NoResize);
    end

    if locked then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove);
    end

    if not state.title_bar[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar);
    end

    return flags;
end

local function custom_close(id, open_ref)
    if state.title_bar[1] then return; end

    local window_w = select(1, imgui.GetWindowSize());
    window_w = tonumber(window_w) or 300;
    local sx, sy = imgui.GetCursorPos();

    imgui.SetCursorPos({ math.max(8, window_w - 30), 6 });
    if imgui.Button('X##' .. id, { 22, 20 }) then
        open_ref[1] = false;
        state.settings_dirty = true;
    end

    imgui.SetCursorPos({ sx, sy });
end

local function pct(part, total)
    part = tonumber(part) or 0;
    total = tonumber(total) or 0;
    if total <= 0 then return 0.0; end
    return (part / total) * 100.0;
end

local function fmt_time(ts)
    ts = tonumber(ts) or 0;
    if ts <= 0 then return '--'; end
    return os.date('%Y-%m-%d %I:%M:%S %p', ts);
end

local function session_kph(s)
    if s == nil or (tonumber(s.first_fight) or 0) <= 0 then return 0.0; end
    local elapsed = math.max(1, os.time() - tonumber(s.first_fight));
    return ((tonumber(s.kills) or 0) * 3600.0) / elapsed;
end

local function sorted_drops(rec)
    local rows = {};
    if rec == nil or rec.drops == nil then return rows; end

    for _, drop in pairs(rec.drops) do
        if drop ~= nil then table.insert(rows, drop); end
    end

    table.sort(rows, function(a, b)
        local ao = tonumber(a.occurrences) or 0;
        local bo = tonumber(b.occurrences) or 0;
        if ao == bo then
            return tostring(a.name or ''):lower() < tostring(b.name or ''):lower();
        end
        return ao > bo;
    end);

    return rows;
end

local function draw_drop_table(rec, key, compact)
    local drops = sorted_drops(rec);
    if #drops == 0 then
        imgui.TextColored(state.muted, 'No recorded drops.');
        return;
    end

    local table_flags = 0;
    if ImGuiTableFlags_RowBg ~= nil then table_flags = bit.bor(table_flags, ImGuiTableFlags_RowBg); end
    if ImGuiTableFlags_BordersInnerH ~= nil then table_flags = bit.bor(table_flags, ImGuiTableFlags_BordersInnerH); end

    if imgui.BeginTable ~= nil and imgui.BeginTable('##mobhunt_drops_' .. tostring(key), compact and 3 or 5, table_flags) then
        if compact then
            imgui.TableSetupColumn('Item', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);
            imgui.TableSetupColumn('Drops', ImGuiTableColumnFlags_WidthFixed or 0, 72.0);
            imgui.TableSetupColumn('Rate', ImGuiTableColumnFlags_WidthFixed or 0, 78.0);
        else
            imgui.TableSetupColumn('Item', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);
            imgui.TableSetupColumn('Drops', ImGuiTableColumnFlags_WidthFixed or 0, 72.0);
            imgui.TableSetupColumn('Rate', ImGuiTableColumnFlags_WidthFixed or 0, 78.0);
            imgui.TableSetupColumn('Qty', ImGuiTableColumnFlags_WidthFixed or 0, 58.0);
            imgui.TableSetupColumn('Session', ImGuiTableColumnFlags_WidthFixed or 0, 88.0);
        end
        imgui.TableHeadersRow();

        local s = state.session[key];

        for _, drop in ipairs(drops) do
            imgui.TableNextRow();
            imgui.TableNextColumn(); imgui.Text(tostring(drop.name or ('Item ' .. tostring(drop.item_id or '?'))));
            imgui.TableNextColumn(); imgui.Text(tostring(tonumber(drop.occurrences) or 0));
            imgui.TableNextColumn(); imgui.Text(('%.1f%%'):fmt(pct(drop.occurrences, rec.kills)));

            if not compact then
                imgui.TableNextColumn(); imgui.Text(tostring(tonumber(drop.quantity) or 0));
                imgui.TableNextColumn();
                local sdrop = s and s.drops and s.drops[tostring(drop.item_id)] or nil;
                if sdrop then
                    imgui.Text(('%d / %d'):fmt(tonumber(sdrop.occurrences) or 0, tonumber(sdrop.quantity) or 0));
                else
                    imgui.TextColored(state.muted, '--');
                end
            end
        end
        imgui.EndTable();
    else
        for _, drop in ipairs(drops) do
            imgui.Text(('%s  %d  %.1f%%'):fmt(
                tostring(drop.name or ('Item ' .. tostring(drop.item_id or '?'))),
                tonumber(drop.occurrences) or 0,
                pct(drop.occurrences, rec.kills)
            ));
        end
    end
end

local function draw_three_stats(id, fights, kills, deaths)
    local flags = 0;
    if imgui.BeginTable ~= nil and imgui.BeginTable('##mobhunt_stats_' .. tostring(id), 3, flags) then
        imgui.TableSetupColumn('##fights', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);
        imgui.TableSetupColumn('##kills', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);
        imgui.TableSetupColumn('##deaths', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);

        imgui.TableNextRow();
        imgui.TableNextColumn(); imgui.Text(('Fights: %d'):fmt(tonumber(fights) or 0));
        imgui.TableNextColumn(); imgui.TextColored(state.success, ('Kills: %d'):fmt(tonumber(kills) or 0));
        imgui.TableNextColumn(); imgui.TextColored(state.danger, ('Deaths: %d'):fmt(tonumber(deaths) or 0));

        imgui.EndTable();
    else
        imgui.Text(('Fights: %d'):fmt(tonumber(fights) or 0));
        imgui.SameLine(0, 26); imgui.TextColored(state.success, ('Kills: %d'):fmt(tonumber(kills) or 0));
        imgui.SameLine(0, 26); imgui.TextColored(state.danger, ('Deaths: %d'):fmt(tonumber(deaths) or 0));
    end
end

local function draw_record_summary(rec, key, include_header)
    if rec == nil then return; end
    local s = state.session[key];

    if include_header then
        imgui.TextColored(state.accent, tostring(rec.name or 'Unknown'));
        imgui.TextColored(state.muted, tostring(rec.zone_name or safe_zone_name(rec.zone_id)));
        imgui.Separator();
    end

    local fights = tonumber(rec.fights) or 0;
    local kills = tonumber(rec.kills) or 0;
    local deaths = tonumber(rec.deaths) or 0;

    draw_three_stats('lifetime_' .. tostring(key), fights, kills, deaths);

    imgui.Text(('Win Rate: %.1f%%'):fmt(pct(kills, fights)));

    if state.show_session[1] then
        imgui.Separator();
        imgui.TextColored(state.accent, 'This Session');
        draw_three_stats(
            'session_' .. tostring(key),
            s and (tonumber(s.fights) or 0) or 0,
            s and (tonumber(s.kills) or 0) or 0,
            s and (tonumber(s.deaths) or 0) or 0
        );
        if state.show_kills_per_hour[1] then
            imgui.Text(('Kills / Hour: %.1f'):fmt(session_kph(s)));
        end
    end

    if state.show_drops[1] then
        imgui.Separator();
        imgui.TextColored(state.accent, 'Observed Drops');
        draw_drop_table(rec, key, true);
    end
end

local function draw_target_window()
    if not state.visible[1] then
        state.target_apply_geometry = true;
        state.mini_apply_geometry = true;
        return;
    end

    local target = get_current_target();
    state.current_target = target;

    if state.target_only[1] and target == nil then
        state.target_apply_geometry = true;
        state.mini_apply_geometry = true;
        return;
    end

    local geom = state.mini_mode[1] and state.mini_geom or state.target_geom;
    local apply_key = state.mini_mode[1] and 'mini_apply_geometry' or 'target_apply_geometry';

    if state[apply_key] then
        imgui.SetNextWindowPos({ geom[1], geom[2] }, { 0, 0 });
        state[apply_key] = false;
    end

    -- StatusTimers-style content-driven sizing. Preserve the selected width,
    -- but never preserve a stale height; new drop rows grow the window and
    -- shorter lists shrink it automatically.
    local target_width = math.max(state.mini_mode[1] and 260 or 410, tonumber(geom[3]) or 0);
    imgui.SetNextWindowContentSize({ target_width - 18, 0 });

    push_theme();
    local title = state.mini_mode[1] and 'MobHunt Mini##target' or 'MobHunt##target';
    if imgui.Begin(title, state.visible, window_flags(state.lock_target[1], true)) then
        custom_close('mobhunt_target_close', state.visible);
        imgui.PushFont(nil, imgui.GetFontSize() * state.font_scale[1]);

        if target == nil then
            imgui.TextColored(state.muted, state.mini_mode[1]
                and 'No monster targeted.'
                or 'Target a monster to view MobHunt statistics.');
        else
            local key = record_key(target.zone_id, target.name);
            local rec = config.records[key];
            local srec = state.session[key];

            imgui.TextColored(state.accent, tostring(target.name));
            imgui.SameLine();
            if state.encounters[target.id] ~= nil then
                imgui.TextColored(state.success, '[In Combat]');
            end

            if state.mini_mode[1] then
                if rec == nil then
                    imgui.TextColored(state.muted, ('%s  |  No history'):fmt(tostring(target.zone_name)));
                else
                    imgui.TextColored(state.muted, tostring(target.zone_name));
                    imgui.Text(('F: %d   K: %d   D: %d   Win: %.1f%%'):fmt(
                        tonumber(rec.fights) or 0,
                        tonumber(rec.kills) or 0,
                        tonumber(rec.deaths) or 0,
                        pct(rec.kills, rec.fights)
                    ));
                    if state.show_session[1] then
                        imgui.Text(('Session  F: %d   K: %d   D: %d'):fmt(
                            srec and (tonumber(srec.fights) or 0) or 0,
                            srec and (tonumber(srec.kills) or 0) or 0,
                            srec and (tonumber(srec.deaths) or 0) or 0
                        ));
                    end
                end
            else
                imgui.TextColored(state.muted, tostring(target.zone_name));
                imgui.Separator();

                if rec == nil then
                    imgui.TextColored(state.muted, 'No recorded encounters with this mob in this zone.');
                else
                    draw_record_summary(rec, key, false);
                end

                imgui.Separator();
                if imgui.Button('History') then
                    state.history_visible[1] = not state.history_visible[1];
                    state.settings_dirty = true;
                end
                imgui.SameLine();
                if imgui.Button('Config') then
                    state.config_visible[1] = not state.config_visible[1];
                    state.settings_dirty = true;
                end
                imgui.SameLine();
                if imgui.Button('Mini') then
                    state.mini_mode[1] = true;
                    state.mini_apply_geometry = true;
                    state.settings_dirty = true;
                end
            end
        end

        if state.mini_mode[1] then
            imgui.Separator();
            if imgui.SmallButton('Full##mh_full') then
                state.mini_mode[1] = false;
                state.target_apply_geometry = true;
                state.settings_dirty = true;
            end
            imgui.SameLine();
            if imgui.SmallButton('History##mh_mini_hist') then
                state.history_visible[1] = not state.history_visible[1];
                state.settings_dirty = true;
            end
            imgui.SameLine();
            if imgui.SmallButton('Config##mh_mini_cfg') then
                state.config_visible[1] = not state.config_visible[1];
                state.settings_dirty = true;
            end
        end

        imgui.PopFont();
        if not state.lock_target[1] then
            local old_height = geom[4];
            capture_geometry(geom);
            -- Height is controlled by content / AlwaysAutoResize. Keep the
            -- observed value only for settings visibility; it is never applied.
            geom[4] = select(2, imgui.GetWindowSize()) or old_height;
        end
    end
    imgui.End();
    pop_theme();
end

local function filtered_history()
    local search = tostring(state.history_search[1] or ''):lower();
    local rows = {};
    local current_zone_id = get_zone_id();

    for key, rec in pairs(config.records) do
        if rec ~= nil then
            local zone_matches = (not state.history_current_zone[1])
                or ((tonumber(rec.zone_id) or 0) == current_zone_id);
            local hay = (tostring(rec.name or '') .. ' ' .. tostring(rec.zone_name or '')):lower();
            local matches = zone_matches and ((search == '') or hay:find(search, 1, true) ~= nil);

            if not matches and rec.drops ~= nil then
                for _, drop in pairs(rec.drops) do
                    if tostring(drop.name or ''):lower():find(search, 1, true) ~= nil then
                        matches = true;
                        break;
                    end
                end
            end

            if matches then
                table.insert(rows, T{ key = key, rec = rec });
            end
        end
    end

    table.sort(rows, function(a, b)
        local av, bv;
        if state.history_sort == 'name' then
            av = tostring(a.rec.name or ''):lower();
            bv = tostring(b.rec.name or ''):lower();
        elseif state.history_sort == 'zone' then
            av = tostring(a.rec.zone_name or ''):lower();
            bv = tostring(b.rec.zone_name or ''):lower();
        elseif state.history_sort == 'fights' then
            av = tonumber(a.rec.fights) or 0;
            bv = tonumber(b.rec.fights) or 0;
        elseif state.history_sort == 'deaths' then
            av = tonumber(a.rec.deaths) or 0;
            bv = tonumber(b.rec.deaths) or 0;
        else
            av = tonumber(a.rec.kills) or 0;
            bv = tonumber(b.rec.kills) or 0;
        end

        if av == bv then
            return tostring(a.rec.name or ''):lower() < tostring(b.rec.name or ''):lower();
        end

        if state.history_sort_desc then return av > bv; end
        return av < bv;
    end);

    return rows;
end

local function sort_header(label, mode)
    local active = state.history_sort == mode;
    local text = label;
    if active then text = text .. (state.history_sort_desc and ' v' or ' ^'); end

    if imgui.SmallButton(text .. '##mh_sort_' .. mode) then
        if active then
            state.history_sort_desc = not state.history_sort_desc;
        else
            state.history_sort = mode;
            state.history_sort_desc = (mode ~= 'name' and mode ~= 'zone');
        end
    end
end

local function delete_history_record(key)
    if key == nil or config.records[key] == nil then return; end

    config.records[key] = nil;
    state.session[key] = nil;

    for id, enc in pairs(state.encounters) do
        if enc ~= nil and enc.key == key then
            state.encounters[id] = nil;
            clear_persisted_encounter(id);
        end
    end
    if config.active_encounters ~= nil then
        for marker_id, marker in pairs(config.active_encounters) do
            if marker ~= nil and marker.key == key then
                config.active_encounters[marker_id] = nil;
            end
        end
    end
    for id, dead in pairs(state.recent_dead) do
        if dead ~= nil and dead.key == key then state.recent_dead[id] = nil; end
    end

    state.history_selected_key = nil;
    state.history_delete_key = nil;
    state.data_dirty = true;
    settings.save();
end

local function draw_history_window()
    if not state.history_visible[1] then
        state.history_apply_geometry = true;
        return;
    end

    if state.history_apply_geometry then
        imgui.SetNextWindowPos({ state.history_geom[1], state.history_geom[2] }, { 0, 0 });
        imgui.SetNextWindowSize({ state.history_geom[3], state.history_geom[4] });
        state.history_apply_geometry = false;
    end

    push_theme();
    if imgui.Begin('MobHunt History##history', state.history_visible, window_flags(state.lock_history[1])) then
        custom_close('mobhunt_history_close', state.history_visible);

        imgui.PushFont(nil, imgui.GetFontSize() * state.font_scale[1]);

        -- History scope: Current Zone | All
        local zone_scope_active = state.history_current_zone[1];
        if zone_scope_active then
            imgui.PushStyleColor(ImGuiCol_Button, { state.accent[1] * 0.55, state.accent[2] * 0.55, state.accent[3] * 0.55, 0.95 });
        end
        if imgui.Button('Current Zone##mh_history_scope_zone') then
            state.history_current_zone[1] = true;
            state.history_selected_key = nil;
            state.settings_dirty = true;
        end
        if zone_scope_active then imgui.PopStyleColor(1); end

        imgui.SameLine();

        local all_scope_active = not state.history_current_zone[1];
        if all_scope_active then
            imgui.PushStyleColor(ImGuiCol_Button, { state.accent[1] * 0.55, state.accent[2] * 0.55, state.accent[3] * 0.55, 0.95 });
        end
        if imgui.Button('All##mh_history_scope_all') then
            state.history_current_zone[1] = false;
            state.settings_dirty = true;
        end
        if all_scope_active then imgui.PopStyleColor(1); end

        imgui.SameLine();
        if state.history_current_zone[1] then
            imgui.TextColored(state.muted, safe_zone_name(get_zone_id()));
        else
            imgui.TextColored(state.muted, 'All saved zones');
        end

        imgui.Text('Search:');
        imgui.SameLine();
        imgui.PushItemWidth(320);
        imgui.InputText('##mobhunt_history_search', state.history_search, 128);
        imgui.PopItemWidth();
        imgui.SameLine();
        if imgui.Button('Clear') then state.history_search[1] = ''; end
        imgui.SameLine();
        imgui.TextColored(state.muted, 'Search mob, zone, or drop');

        local rows = filtered_history();
        imgui.Text(('Recorded Mob/Zone Entries: %d'):fmt(#rows));

        if imgui.BeginTable ~= nil and imgui.BeginTable('##mobhunt_history_table', 6,
            bit.bor(ImGuiTableFlags_RowBg or 0, ImGuiTableFlags_BordersInnerH or 0, ImGuiTableFlags_Resizable or 0)) then

            imgui.TableSetupColumn('Mob');
            imgui.TableSetupColumn('Zone');
            imgui.TableSetupColumn('Fights');
            imgui.TableSetupColumn('Kills');
            imgui.TableSetupColumn('Deaths');
            imgui.TableSetupColumn('Win %');

            imgui.TableNextRow();
            imgui.TableNextColumn(); sort_header('Mob', 'name');
            imgui.TableNextColumn(); sort_header('Zone', 'zone');
            imgui.TableNextColumn(); sort_header('Fights', 'fights');
            imgui.TableNextColumn(); sort_header('Kills', 'kills');
            imgui.TableNextColumn(); sort_header('Deaths', 'deaths');
            imgui.TableNextColumn(); imgui.TextColored(state.accent, 'Win %');

            for _, row in ipairs(rows) do
                local rec = row.rec;
                imgui.TableNextRow();
                imgui.TableNextColumn();

                local selected = state.history_selected_key == row.key;
                if imgui.Selectable(tostring(rec.name or 'Unknown') .. '##mh_hist_' .. row.key, selected, ImGuiSelectableFlags_SpanAllColumns or 0) then
                    state.history_selected_key = row.key;
                end

                imgui.TableNextColumn(); imgui.Text(tostring(rec.zone_name or '--'));
                imgui.TableNextColumn(); imgui.Text(tostring(tonumber(rec.fights) or 0));
                imgui.TableNextColumn(); imgui.TextColored(state.success, tostring(tonumber(rec.kills) or 0));
                imgui.TableNextColumn(); imgui.TextColored(state.danger, tostring(tonumber(rec.deaths) or 0));
                imgui.TableNextColumn(); imgui.Text(('%.1f%%'):fmt(pct(rec.kills, rec.fights)));
            end
            imgui.EndTable();
        else
            for _, row in ipairs(rows) do
                local rec = row.rec;
                if imgui.Selectable(('%s - %s##fallback_%s'):fmt(rec.name or 'Unknown', rec.zone_name or '--', row.key),
                    state.history_selected_key == row.key) then
                    state.history_selected_key = row.key;
                end
            end
        end

        local selected = state.history_selected_key and config.records[state.history_selected_key] or nil;
        if selected ~= nil then
            imgui.Separator();
            draw_record_summary(selected, state.history_selected_key, true);

            imgui.Separator();
            imgui.TextColored(state.accent, 'Lifetime Details');
            imgui.Text(('First Seen: %s'):fmt(fmt_time(selected.first_seen)));
            imgui.Text(('Last Kill: %s'):fmt(fmt_time(selected.last_kill)));
            imgui.Text(('Last Death: %s'):fmt(fmt_time(selected.last_death)));

            imgui.Separator();
            if state.history_delete_key ~= state.history_selected_key then
                if imgui.Button('Delete Record##mh_delete_record') then
                    state.history_delete_key = state.history_selected_key;
                end
                imgui.SameLine();
                imgui.TextColored(state.muted, 'Deletes this mob + zone lifetime record and its drops.');
            else
                imgui.TextColored(state.danger, 'Delete this record permanently?');
                if imgui.Button('Confirm Delete##mh_confirm_delete') then
                    delete_history_record(state.history_selected_key);
                    selected = nil;
                end
                imgui.SameLine();
                if imgui.Button('Cancel##mh_cancel_delete') then
                    state.history_delete_key = nil;
                end
            end

            if selected ~= nil and selected.drops ~= nil and next(selected.drops) ~= nil then
                imgui.Separator();
                imgui.TextColored(state.accent, 'Full Drop History');
                draw_drop_table(selected, state.history_selected_key, false);
            end
        end

        imgui.PopFont();

        if not state.lock_history[1] then capture_geometry(state.history_geom); end
    end
    imgui.End();
    pop_theme();
end

local function draw_config_window()
    if not state.config_visible[1] then
        state.config_apply_geometry = true;
        return;
    end

    if state.config_apply_geometry then
        imgui.SetNextWindowPos({ state.config_geom[1], state.config_geom[2] }, { 0, 0 });
        imgui.SetNextWindowSize({ state.config_geom[3], state.config_geom[4] });
        state.config_apply_geometry = false;
    end

    push_theme();
    if imgui.Begin('MobHunt Config##config', state.config_visible, window_flags(state.lock_config[1])) then
        custom_close('mobhunt_config_close', state.config_visible);

        if imgui.BeginTabBar ~= nil and imgui.BeginTabBar('##mobhunt_config_tabs') then
            if imgui.BeginTabItem('Window') then
                if imgui.Checkbox('Lock Target Window', state.lock_target) then state.settings_dirty = true; end
                if imgui.Checkbox('Lock History Window', state.lock_history) then state.settings_dirty = true; end
                if imgui.Checkbox('Lock Config Window', state.lock_config) then state.settings_dirty = true; end
                imgui.Separator();

                if imgui.Checkbox('Show Title Bars', state.title_bar) then state.settings_dirty = true; end
                if imgui.Checkbox('Show Borders', state.border) then state.settings_dirty = true; end
                if imgui.Checkbox('Only Show Target Window With a Target', state.target_only) then state.settings_dirty = true; end
                if imgui.Checkbox('Mini Target Window', state.mini_mode) then
                    state.target_apply_geometry = true;
                    state.mini_apply_geometry = true;
                    state.settings_dirty = true;
                end

                imgui.Separator();
                imgui.Text('Font Scale');
                imgui.PushItemWidth(220);
                if imgui.SliderFloat('##mh_font_scale', state.font_scale, 0.75, 2.00, '%.2fx') then state.settings_dirty = true; end
                imgui.PopItemWidth();

                imgui.Text('Background / Opacity');
                if imgui.ColorEdit4('##mh_bg', state.background) then state.settings_dirty = true; end

    
            local opacity_percent = T{ math.floor((tonumber(state.background[4]) or 0.45) * 100 + 0.5) };
            imgui.SetNextItemWidth(220 * state.font_scale[1]);
            if imgui.SliderInt('Opacity##background_opacity', opacity_percent, 0, 100, '%d%%') then
                state.background[4] = opacity_percent[1] / 100.0;
                config.appearance.background[4] = state.background[4];
                state.settings_dirty = true;
            end

            if imgui.Button('Reset Window Positions / Sizes') then
                    state.target_geom = { defaults.window.x, defaults.window.y, defaults.window.width, defaults.window.height };
                    state.mini_geom = { defaults.mini_window.x, defaults.mini_window.y, defaults.mini_window.width, defaults.mini_window.height };
                    state.history_geom = { defaults.history_window.x, defaults.history_window.y, defaults.history_window.width, defaults.history_window.height };
                    state.config_geom = { defaults.config_window.x, defaults.config_window.y, defaults.config_window.width, defaults.config_window.height };
                    state.target_apply_geometry = true;
                    state.mini_apply_geometry = true;
                    state.history_apply_geometry = true;
                    state.config_apply_geometry = true;
                    state.geometry_dirty = true;
                end
                imgui.EndTabItem();
            end

            if imgui.BeginTabItem('Display') then
                if imgui.Checkbox('Show Session Statistics', state.show_session) then state.settings_dirty = true; end
                if imgui.Checkbox('Show Observed Drops', state.show_drops) then state.settings_dirty = true; end
                if imgui.Checkbox('Show Kills / Hour', state.show_kills_per_hour) then state.settings_dirty = true; end

                imgui.Separator();
                imgui.Text('Accent Color'); if imgui.ColorEdit4('##mh_accent', state.accent) then state.settings_dirty = true; end
                imgui.Text('Kill / Success Color'); if imgui.ColorEdit4('##mh_success', state.success) then state.settings_dirty = true; end
                imgui.Text('Death / Danger Color'); if imgui.ColorEdit4('##mh_danger', state.danger) then state.settings_dirty = true; end
                imgui.Text('Muted Text Color'); if imgui.ColorEdit4('##mh_muted', state.muted) then state.settings_dirty = true; end
                imgui.EndTabItem();
            end

            if imgui.BeginTabItem('Tracking') then
                imgui.TextWrapped('A fight begins only after you engage/act on a mob, or that mob acts on you. Merely targeting a mob does not count.');
                imgui.Separator();

                imgui.Text('Encounter timeout (seconds)');
                imgui.PushItemWidth(180);
                if imgui.SliderInt('##mh_enc_timeout', state.encounter_timeout, 15, 600, '%d sec') then state.settings_dirty = true; end
                imgui.PopItemWidth();

                if imgui.Checkbox('Debug Packet / Tracking Messages', state.debug) then state.settings_dirty = true; end

                imgui.Separator();
                imgui.TextColored(state.accent, 'Session Controls');
                if imgui.Button('Reset Current Session Statistics') then
                    state.session = T{};
                    state.session_start = os.time();
                    dbg('Session statistics reset.');
                end

                imgui.Separator();
                imgui.TextColored(state.accent, 'Diagnostics');
                imgui.Text(('Action packets: %d'):fmt(tonumber(state.debug_counters.actions) or 0));
                imgui.Text(('Encounters started: %d'):fmt(tonumber(state.debug_counters.starts) or 0));
                imgui.Text(('Encounters resumed: %d'):fmt(tonumber(state.debug_counters.resumes) or 0));
                imgui.Text(('Kills counted: %d'):fmt(tonumber(state.debug_counters.kills) or 0));
                imgui.Text(('Deaths counted: %d'):fmt(tonumber(state.debug_counters.deaths) or 0));
                imgui.Text(('Player HP: %s'):fmt(state.last_player_hp == nil and '--' or tostring(state.last_player_hp)));
                imgui.Text(('Player dead state: %s'):fmt(state.player_dead and 'YES' or 'NO'));
                imgui.Text(('Treasure packets seen: %d'):fmt(tonumber(state.debug_counters.drop_packets) or 0));
                imgui.Text(('Treasure memory scans: %d'):fmt(tonumber(state.debug_counters.treasure_memory_scans) or 0));
                imgui.Text(('Treasure memory drops: %d'):fmt(tonumber(state.debug_counters.treasure_memory_drops) or 0));
                imgui.Text(('Inventory packets seen: %d'):fmt(tonumber(state.debug_counters.inventory_packets) or 0));
                imgui.Text(('Direct inventory drops: %d'):fmt(tonumber(state.debug_counters.direct_drops) or 0));
                imgui.Text(('Drops counted: %d'):fmt(tonumber(state.debug_counters.drops) or 0));
                imgui.Text(('Drops ignored/unassociated: %d'):fmt(tonumber(state.debug_counters.ignored_drops) or 0));
                imgui.EndTabItem();
            end

            imgui.EndTabBar();
        end

        if not state.lock_config[1] then capture_geometry(state.config_geom); end
    end
    imgui.End();
    pop_theme();
end

local function reset_session()
    state.session = T{};
    state.session_start = os.time();
    dbg('Session statistics reset.');
end

local function apply_loaded_config(s)
    if s == nil then return; end
    config = s;
    ensure_config_tables();

    -- Runtime state is intentionally refreshed after Ashita resolves the active
    -- character settings context.
    state.visible[1] = config.visible ~= false;
    state.history_visible[1] = config.history_visible == true;
    state.config_visible[1] = config.config_visible == true;
    state.font_scale[1] = tonumber(config.font_scale) or defaults.font_scale;

    local function apply_color(dst, src, def)
        src = src or T{};
        for i = 1, 4 do dst[i] = tonumber(src[i]) or def[i]; end
    end
    apply_color(state.background, config.appearance.background, defaults.appearance.background);

    if is_legacy_default_background(state.background) then
        for i = 1, 4 do state.background[i] = STATUSTIMERS_BG[i]; end
        for i = 1, 4 do config.appearance.background[i] = STATUSTIMERS_BG[i]; end
        state.settings_dirty = true;
    end

    apply_color(state.accent, config.appearance.accent, defaults.appearance.accent);
    apply_color(state.success, config.appearance.success, defaults.appearance.success);
    apply_color(state.danger, config.appearance.danger, defaults.appearance.danger);
    apply_color(state.muted, config.appearance.muted, defaults.appearance.muted);

    state.border[1] = config.appearance.border ~= false;
    state.title_bar[1] = config.appearance.title_bar ~= false;

    state.target_only[1] = config.behavior.target_only ~= false;
    state.mini_mode[1] = config.behavior.mini_mode == true;
    state.history_current_zone[1] = config.behavior.history_current_zone ~= false;
    state.show_session[1] = config.behavior.show_session ~= false;
    state.show_drops[1] = config.behavior.show_drops ~= false;
    state.show_kills_per_hour[1] = config.behavior.show_kills_per_hour ~= false;
    state.debug[1] = config.behavior.debug == true;
    state.encounter_timeout[1] = tonumber(config.behavior.encounter_timeout) or defaults.behavior.encounter_timeout;

    state.lock_target[1] = config.locks.target == true;
    state.lock_history[1] = config.locks.history == true;
    state.lock_config[1] = config.locks.config == true;

    local function load_geom(dst, src, def)
        dst[1] = tonumber(src.x) or def.x;
        dst[2] = tonumber(src.y) or def.y;
        dst[3] = tonumber(src.width) or def.width;
        dst[4] = tonumber(src.height) or def.height;
    end
    load_geom(state.target_geom, config.window, defaults.window);
    load_geom(state.mini_geom, config.mini_window, defaults.mini_window);
    load_geom(state.history_geom, config.history_window, defaults.history_window);
    load_geom(state.config_geom, config.config_window, defaults.config_window);

    state.target_apply_geometry = true;
    state.mini_apply_geometry = true;
    state.history_apply_geometry = true;
    state.config_apply_geometry = true;
end

settings.register('settings', 'mobhunt_settings_update', function(s)
    apply_loaded_config(s);
end);

ashita.events.register('packet_in', 'mobhunt_packet_in_cb', function(e)
    if e == nil then return; end

    local player_id = get_player_id();
    if player_id == 0 then return; end

    if e.id == 0x028 then
        local act = parse_action_packet(e);
        if act == nil then return; end
        state.debug_counters.actions = (tonumber(state.debug_counters.actions) or 0) + 1;

        if act.actor_id == player_id then
            for _, target in ipairs(act.targets) do
                if target.id ~= player_id then
                    local info = resolve_entity(target.id);
                    if info ~= nil then start_encounter(info, 'player_action'); end
                    touch_encounter(target.id);
                end
            end
        else
            for _, target in ipairs(act.targets) do
                if target.id == player_id then
                    local info = resolve_entity(act.actor_id);
                    if info ~= nil and info.is_mob == true then
                        start_encounter(info, 'mob_action');
                        state.last_hostile = T{
                            id = act.actor_id,
                            index = info.index,
                            time = os.clock(),
                        };
                    end
                    touch_encounter(act.actor_id);
                end
            end
        end

    elseif e.id == 0x029 then
        local p = parse_action_message(e);
        if p == nil then return; end

        if DEATH_MESSAGES:contains(p.message) then
            if p.target == player_id and p.actor ~= player_id then
                count_death(p.actor, p.actor_index, 'action_message');
            elseif p.target ~= player_id then
                -- Death messages for a mob are an important no-EXP / NM fallback.
                count_kill(p.target, p.target_index, 'death_message');
            end
        end

    elseif e.id == 0x02D then
        local p = parse_kill_packet(e);
        if p == nil then return; end
        if p.target ~= 0 and p.target ~= player_id then
            count_kill(p.target, p.target_index, 'kill_packet');
        end

    elseif e.id == 0x01F then
        -- Item assigned directly into inventory. This is how many solo / no-pool
        -- monster drops arrive, so 0x0D2 alone is not sufficient.
        local p = parse_inventory_assign_packet(e);
        if p ~= nil then
            state.debug_counters.inventory_packets = (tonumber(state.debug_counters.inventory_packets) or 0) + 1;
            local old = state.inventory_slots[inventory_slot_key(p.bag, p.index)];
            local old_count = (old ~= nil and tonumber(old.item_id) == tonumber(p.item)) and (tonumber(old.count) or 0) or 0;
            local delta = math.max(0, (tonumber(p.count) or 0) - old_count);
            cache_inventory_slot(p.bag, p.index, p.item, p.count);
            if tonumber(p.bag) == 0 and delta > 0 then
                record_direct_inventory_drop(p.item, delta, '0x01F');
            end
        end

    elseif e.id == 0x01E then
        -- Count-only inventory modification; commonly used when a drop stacks onto
        -- an item already in inventory. Use our pre-packet slot cache to obtain id.
        local p = parse_inventory_modify_packet(e);
        if p ~= nil then
            state.debug_counters.inventory_packets = (tonumber(state.debug_counters.inventory_packets) or 0) + 1;
            local skey = inventory_slot_key(p.bag, p.index);
            local old = state.inventory_slots[skey];
            if old ~= nil then
                local old_count = tonumber(old.count) or 0;
                local new_count = tonumber(p.count) or 0;
                local delta = new_count - old_count;
                if tonumber(p.bag) == 0 and tonumber(old.item_id) and tonumber(old.item_id) > 0 and delta > 0 then
                    record_direct_inventory_drop(old.item_id, delta, '0x01E');
                end
                cache_inventory_slot(p.bag, p.index, old.item_id, new_count);
            end
        end

    elseif e.id == 0x0D2 then
        -- HorizonXI's 0x0D2 layout does not match the retail/Windower field
        -- layout used by earlier MobHunt builds. Keep this packet as a diagnostic
        -- signal only; the authoritative item id now comes from Ashita's live
        -- treasure-pool memory (GetTreasurePoolItem).
        state.debug_counters.drop_packets = (tonumber(state.debug_counters.drop_packets) or 0) + 1;

        if state.debug[1] then
            local p = parse_drop_packet(e);
            if p ~= nil then
                dbg(('0x0D2 seen (diagnostic only): a=%d b=%d c=%d d=%d e=%d'):fmt(
                    tonumber(p.dropper) or 0,
                    tonumber(p.count) or 0,
                    tonumber(p.item) or 0,
                    tonumber(p.dropper_index) or 0,
                    tonumber(p.pool_index) or 0
                ));
            else
                dbg('0x0D2 seen (diagnostic only); parser could not read legacy layout.');
            end
        end
    end
end);

ashita.events.register('packet_out', 'mobhunt_packet_out_cb', function(e)
    if e == nil or e.id ~= 0x01A or e.data_modified == nil then return; end

    local ok, target_id, target_index, category = pcall(function()
        return struct.unpack('I', e.data_modified, 0x04 + 1),
               struct.unpack('H', e.data_modified, 0x08 + 1),
               struct.unpack('H', e.data_modified, 0x0A + 1);
    end);

    if not ok then return; end

    -- 0x02 = Engage monster.
    if tonumber(category) == 0x02 and tonumber(target_id) and tonumber(target_id) ~= 0 then
        local info = resolve_entity(target_id, target_index);
        if info ~= nil then start_encounter(info, 'engage'); end
    end
end);

ashita.events.register('command', 'mobhunt_command_cb', function(e)
    if e == nil or e.command == nil then return; end

    local args = e.command:args();
    if #args == 0 or not args[1]:any('/mobhunt', '/mh') then return; end

    e.blocked = true;

    if #args >= 2 then
        local sub = tostring(args[2]):lower();

        if sub == 'mini' then
            state.mini_mode[1] = not state.mini_mode[1];
            state.target_apply_geometry = true;
            state.mini_apply_geometry = true;
            state.settings_dirty = true;
            return;
        elseif sub == 'history' or sub == 'hist' then
            state.history_visible[1] = not state.history_visible[1];
            state.settings_dirty = true;
            return;
        elseif sub == 'config' or sub == 'settings' then
            state.config_visible[1] = not state.config_visible[1];
            state.settings_dirty = true;
            return;
        elseif sub == 'session' or sub == 'resetsession' then
            reset_session();
            print('[MobHunt] Current session statistics reset.');
            return;
        elseif sub == 'debug' then
            state.debug[1] = not state.debug[1];
            state.settings_dirty = true;
            print(('[MobHunt] Debug messages: %s'):fmt(state.debug[1] and 'ON' or 'OFF'));
            return;
        elseif sub == 'help' then
            print('[MobHunt] /mh - open History + Config');
            print('[MobHunt] /mh mini - toggle Full / Mini target view');
            print('[MobHunt] /mh history - toggle searchable history');
            print('[MobHunt] /mh config - toggle configuration');
            print('[MobHunt] /mh session - reset current-session counters only');
            print('[MobHunt] /mh debug - toggle tracking diagnostics');
            return;
        end
    end

    -- Bare /mh is the MobHunt control-center shortcut.
    -- Keep the target window's normal target-driven visibility untouched and
    -- bring up both management windows together.
    state.history_visible[1] = true;
    state.config_visible[1] = true;
    state.history_apply_geometry = true;
    state.config_apply_geometry = true;
    state.settings_dirty = true;
end);

ashita.events.register('d3d_present', 'mobhunt_present_cb', function()
    initialize_inventory_cache();
    scan_treasure_pool_memory();
    monitor_player_death();
    cleanup_runtime();

    -- Keep the current target cached so packet-time resolution usually avoids
    -- scanning the full entity map.
    local target = get_current_target();
    if target ~= nil then
        state.entity_cache[target.id] = target;
    end

    draw_target_window();
    draw_history_window();
    draw_config_window();

    if (state.geometry_dirty or state.settings_dirty or state.data_dirty)
        and (os.clock() - state.last_save) >= 0.75 then
        save_all();
        state.geometry_dirty = false;
        state.settings_dirty = false;
        state.data_dirty = false;
        state.last_save = os.clock();
    end
end);

ashita.events.register('unload', 'mobhunt_unload_cb', function()
    save_all();
end);

ashita.events.register('zone_change', 'mobhunt_zone_change_cb', function()
    state.encounters = T{};
    state.recent_dead = T{};
    state.recent_kills = T{};
    state.recent_deaths = T{};
    state.last_hostile = nil;
    state.last_player_hp = nil;
    state.player_dead = false;
    state.entity_cache = T{};
    state.inventory_slots = T{};
    state.inventory_cache_ready = false;
    state.treasure_slots = T{};
    state.treasure_cache_ready = false;
    state.treasure_last_scan = 0;
    state.current_target = nil;

    if config.active_encounters == nil then config.active_encounters = T{}; end
    config.active_encounters = T{};
    state.data_dirty = true;
end);
