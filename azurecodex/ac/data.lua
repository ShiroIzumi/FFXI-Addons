--[[
    Azure Codex - ac/data.lua

    Spell data and game reads: name normalizing, traits and trait tiers, known
    spells, zone rows, BLU level / skill / points, search, filters, sorting,
    the Learned Log, and table column setup.
]]

-- Memoized: names are normalized thousands of times per frame otherwise.
normalize_cache = {};
function normalize_name(value)
    if value == nil then return ''; end
    local raw = tostring(value);
    local cached = normalize_cache[raw];
    if cached == nil then
        cached = raw:lower():gsub('[^%w]', '');
        normalize_cache[raw] = cached;
    end
    return cached;
end

-- Static per-spell values computed once.
for _, spell in ipairs(spells) do
    spell._key = normalize_name(spell.name);
end


function get_spell_trait_display(spell)
    return tostring(spell and spell.trait or 'None')
end



-- ----------------------------------------------------------------------------
-- Blue Magic traits, HorizonXI / LandSandBoat 75-era rules.
--
-- Each set spell adds its trait points (4 for almost every spell) to the
-- trait named in spells.lua. Internally that is a weight of points / 4
-- (TRAIT_POINT_SCALE), and a trait tier unlocks at the thresholds below,
-- in weight units, so a normal tier reads as 8 trait points.
--   * most traits: a tier every 2 spells (8 pts)
--   * Auto Refresh, Auto Regen, Conserve MP: one tier only (Tier I at 8 pts;
--     the ToAU-era cap on HorizonXI)
--   * Resist Gravity: 2 / 3 / 4 weight
-- Spells that give other than 4 points are listed in TRAIT_POINTS below
-- (HorizonXI's current values, 2026-10).
-- ----------------------------------------------------------------------------
TRAIT_POINT_SCALE = 4;

TRAIT_TIERS = {
    beastkiller = { 2, 4, 6 },
    autoregen = { 2 }, -- Tier I only: 8 trait points (ToAU-era cap).
    lizardkiller = { 2, 4, 6 },
    clearmind = { 2, 4, 6, 8, 10, 12 },
    resistsleep = { 2, 4, 6, 8 },
    magicattackbonus = { 2, 4, 6, 8, 10, 12 },
    undeadkiller = { 2, 4, 6 },
    attackbonus = { 2, 4, 6, 8, 10, 12 },
    rapidshot = { 2, 4, 6 },
    maxmpboost = { 2, 4 },
    defensebonus = { 2, 4, 6, 8, 10, 12 },
    plantoidkiller = { 2, 4, 6 },
    magicdefensebonus = { 2, 4, 6, 8, 10 },
    autorefresh = { 2 }, -- Tier I only: 8 trait points.
    maxhpboost = { 2, 4, 6, 8, 10, 12 },
    accuracybonus = { 2, 4, 6, 8, 10, 12 },
    conservemp = { 2 }, -- Tier I only: 8 trait points.
    evasionbonus = { 2, 4, 6, 8, 10 },
    resistgravity = { 2, 3, 4 },
    storetp = { 2, 4, 6, 8, 10 },
    counter = { 2, 4, 6, 8 },
    fastcast = { 2, 4, 6, 8, 10 },
    -- HorizonXI-only trait (Bomb Toss and others in spells.lua); tiers
    -- assumed to follow the common 2 / 4 / 6 pattern.
    magicaccuracy = { 2, 4, 6 },
};

-- Trait points per spell, for spells that don't give the usual 4.
-- (Geist Wall, Blood Saber, Actinic Burst and Plasma Charge give 4.)
TRAIT_POINTS = {
    stinkinggas = 1,
    coldwave = 1,
    frightfulroar = 2,
    selfdestruct = 2,
    windsofpromy = 2,
    windsofpromyvion = 2,
    lightofpenance = 3,
    voracioustrunk = 3,
};

-- The same as weights (points / 4); a spell not listed weighs 1.
TRAIT_WEIGHTS = {};
for key, pts in pairs(TRAIT_POINTS) do
    TRAIT_WEIGHTS[key] = pts / TRAIT_POINT_SCALE;
end

ROMAN = { 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII' };

function get_spell_trait_name(spell)
    local text = tostring(spell and spell.trait or '');
    if text == '' or text:lower() == 'none' then return nil; end
    return text;
end

function get_trait_weight(spell)
    return TRAIT_WEIGHTS[spell._key or normalize_name(spell.name)] or 1;
end

function trait_tiers_for(trait_name)
    return TRAIT_TIERS[normalize_name(trait_name)] or { 2, 4, 6 };
end

-- Totals for a list of spells. Each entry:
--   name, key, weight, points, tier, max_tier, next_points, prev_points, maxed
function compute_traits(spell_list)
    local totals = {};
    for _, spell in ipairs(spell_list or {}) do
        local trait_name = get_spell_trait_name(spell);
        if trait_name ~= nil then
            local key = normalize_name(trait_name);
            if totals[key] == nil then
                totals[key] = { name = trait_name, key = key, weight = 0 };
            end
            totals[key].weight = totals[key].weight + get_trait_weight(spell);
        end
    end

    local result = {};
    for _, entry in pairs(totals) do
        local tiers = trait_tiers_for(entry.name);
        local tier = 0;
        for index, need in ipairs(tiers) do
            if entry.weight >= need then tier = index; end
        end
        entry.tier = tier;
        entry.max_tier = #tiers;
        entry.maxed = tier >= #tiers;
        entry.points = entry.weight * TRAIT_POINT_SCALE;
        entry.next_need = tiers[tier + 1];
        entry.next_points = entry.next_need and (entry.next_need * TRAIT_POINT_SCALE) or nil;
        entry.prev_points = (tier > 0) and (tiers[tier] * TRAIT_POINT_SCALE) or 0;
        result[#result + 1] = entry;
    end

    table.sort(result, function(a, b)
        if a.tier ~= b.tier then return a.tier > b.tier; end
        if a.points ~= b.points then return a.points > b.points; end
        return a.name:lower() < b.name:lower();
    end);

    return result;
end

function trait_label(entry)
    if entry.tier > 0 then
        return ('%s %s'):fmt(entry.name, ROMAN[entry.tier] or tostring(entry.tier));
    end
    return entry.name;
end

function get_trait_totals()
    local selected_spells = {};
    for _, spell in ipairs(spells) do
        if state.build_selected[spell._key] == true then
            selected_spells[#selected_spells + 1] = spell;
        end
    end
    return compute_traits(selected_spells), selected_spells;
end

-- Spells that give other than 4 trait points show their points next to
-- the trait, like the in-game description, e.g. "Auto Refresh (1)".
function get_spell_trait_badge(spell)
    local name = tostring(spell and spell.trait or 'None');
    if name:lower() == 'none' then return name; end
    local pts = TRAIT_POINTS[spell._key or ''];
    if pts ~= nil and pts ~= TRAIT_POINT_SCALE then return ('%s (%d)'):fmt(name, pts); end
    return name;
end

resource_aliases = T{
    -- spells.lua intentionally keeps the full display names. Horizon/Ashita's
    -- spell resources abbreviate these names, so learned-status checks use
    -- the normalized resource aliases below.
    ['windsofpromyvion'] = 'windsofpromy',
    ['quadraticcontinnuum'] = 'quadcontinuum',
};

function build_resource_cache()
    if state.resource_cache_ready then return; end

    local rm = AshitaCore:GetResourceManager();
    if not rm then return; end

    local wanted = T{};
    for _, spell in ipairs(spells) do
        local key = normalize_name(spell.name);
        wanted[key] = true;
        if resource_aliases[key] ~= nil then
            wanted[resource_aliases[key]] = true;
        end
    end

    for id = 0, 2048 do
        local res = rm:GetSpellById(id);
        if res ~= nil and res.Name ~= nil and res.Name[1] ~= nil then
            local key = normalize_name(res.Name[1]);
            if wanted[key] then
                state.resource_ids[key] = id;
            end
        end
    end

    for source_key, resource_key in pairs(resource_aliases) do
        if state.resource_ids[source_key] == nil and state.resource_ids[resource_key] ~= nil then
            state.resource_ids[source_key] = state.resource_ids[resource_key];
        end
    end

    state.resource_cache_ready = true;
end

function safe_player()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then return nil; end
    local player = mm:GetPlayer();
    if not player then return nil; end
    return player;
end

-- Known-spell cache. Refreshed at most twice a second; every view reads
-- from it. version changes whenever any spell's known state changes, which
-- invalidates the list / zone / farm caches below.
known_cache = { by_key = {}, count = 0, version = 0, checked = -1 };

function refresh_known_cache(force)
    local now = os.clock();
    if not force and known_cache.checked >= 0 and (now - known_cache.checked) < 0.5 then
        return;
    end
    known_cache.checked = now;

    local player = safe_player();
    if not player then return; end

    if not state.resource_cache_ready then
        build_resource_cache();
    end

    local changed = false;
    local count = 0;
    for _, spell in ipairs(spells) do
        local key = spell._key;
        local id = state.resource_ids[key];
        local known = false;
        if id ~= nil then
            local ok, value = pcall(function() return player:HasSpell(id); end);
            known = ok and value == true;
        end
        if known then count = count + 1; end
        if known_cache.by_key[key] ~= known then
            known_cache.by_key[key] = known;
            changed = true;
        end
    end

    known_cache.count = count;
    if changed then
        known_cache.version = known_cache.version + 1;
    end
end

function is_known(spell_name)
    refresh_known_cache(false);
    return known_cache.by_key[normalize_name(spell_name)] == true;
end

function get_learned_count()
    refresh_known_cache(false);
    return known_cache.count;
end

function safe_current_zone_id()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then return nil; end

    local party = mm:GetParty();
    if not party then return nil; end

    local zone_id = nil;

    if party.GetMemberZone ~= nil then
        local ok, value = pcall(function()
            return party:GetMemberZone(0);
        end);
        if ok then
            zone_id = tonumber(value);
        end
    end

    if (zone_id == nil or zone_id <= 0) and party.GetMemberZone2 ~= nil then
        local ok, value = pcall(function()
            return party:GetMemberZone2(0);
        end);
        if ok then
            zone_id = tonumber(value);
        end
    end

    if zone_id == nil or zone_id <= 0 then
        return nil;
    end

    return zone_id;
end

function get_zone_spell_rows(zone_id)
    zone_id = tonumber(zone_id);
    if not zone_id then
        return {};
    end

    local rows = {};

    for _, spell in ipairs(spells) do
        local entries = locations.get(spell.name) or {};
        local mob_lookup = {};
        local mobs = {};

        for _, entry in ipairs(entries) do
            if tonumber(entry.zone) == zone_id then
                for _, mob in ipairs(entry.mobs or {}) do
                    local mob_name = tostring(mob or '');
                    local key = mob_name:lower();
                    if mob_name ~= '' and not mob_lookup[key] then
                        mob_lookup[key] = true;
                        mobs[#mobs + 1] = mob_name;
                    end
                end
            end
        end

        if #mobs > 0 then
            table.sort(mobs, function(a, b)
                return tostring(a):lower() < tostring(b):lower();
            end);

            rows[#rows + 1] = {
                spell = spell,
                mobs = mobs,
                known = is_known(spell.name),
            };
        end
    end

    table.sort(rows, function(a, b)
        return tostring(a.spell.name):lower() < tostring(b.spell.name):lower();
    end);

    return rows;
end

zone_rows_cache = { key = nil, rows = {} };

function get_zone_progress(zone_id)
    refresh_known_cache(false);
    local cache_key = tostring(zone_id) .. '|' .. tostring(known_cache.version);
    if zone_rows_cache.key ~= cache_key then
        zone_rows_cache.rows = get_zone_spell_rows(zone_id);
        zone_rows_cache.key = cache_key;
    end
    local rows = zone_rows_cache.rows;
    local known = 0;

    for _, row in ipairs(rows) do
        if row.known then
            known = known + 1;
        end
    end

    return known, #rows, rows;
end

function safe_blu_level()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then return nil; end

    -- Prefer IPlayer because it is the local player's authoritative job/level
    -- structure and does not depend on party-member data being populated.
    local player = mm:GetPlayer();
    if player then
        local main_job = nil;
        local main_level = nil;

        if player.GetMainJob ~= nil then
            local ok, value = pcall(function()
                return player:GetMainJob();
            end);
            if ok then main_job = tonumber(value); end
        end

        if player.GetMainJobLevel ~= nil then
            local ok, value = pcall(function()
                return player:GetMainJobLevel();
            end);
            if ok then main_level = tonumber(value); end
        end

        -- Blue Mage job id is 16.
        if main_job == 16 and main_level and main_level > 0 then
            return main_level;
        end
    end

    -- Fallback for clients / moments where IPlayer has not populated yet.
    local party = mm:GetParty();
    if not party then return nil; end

    local main_job = nil;
    local main_level = nil;

    if party.GetMemberMainJob ~= nil then
        local ok, value = pcall(function()
            return party:GetMemberMainJob(0);
        end);
        if ok then main_job = tonumber(value); end
    end

    if party.GetMemberMainJobLevel ~= nil then
        local ok, value = pcall(function()
            return party:GetMemberMainJobLevel(0);
        end);
        if ok then main_level = tonumber(value); end
    end

    if main_job == 16 and main_level and main_level > 0 then
        return main_level;
    end

    return nil;
end

read_blue_magic_skill = nil;
skill_cache = { value = nil, at = -1 };

-- Cached for a quarter second (it was read once per table row per frame).
function safe_blue_magic_skill()
    local now = os.clock();
    if skill_cache.at >= 0 and (now - skill_cache.at) < 0.25 then
        return skill_cache.value;
    end
    skill_cache.value = read_blue_magic_skill();
    skill_cache.at = now;
    return skill_cache.value;
end

read_blue_magic_skill = function()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then return nil; end

    local player = mm:GetPlayer();
    if not player then return nil; end

    if player.GetCombatSkill == nil then
        return nil;
    end

    -- Ashita combat-skill index 43 is Blue Magic.
    local ok, skill = pcall(function()
        return player:GetCombatSkill(43);
    end);

    if not ok or skill == nil then
        return nil;
    end

    if skill.GetSkill == nil then
        return nil;
    end

    local ok_value, value = pcall(function()
        return skill:GetSkill();
    end);

    if not ok_value then
        return nil;
    end

    value = tonumber(value);
    if value == nil or value < 0 then
        return nil;
    end

    return value;
end

-- Reads the player's current BLU set points from Ashita's BLU state.
blu_points_ptr = nil;
function get_blu_points()
    if blu_points_ptr == nil then
        local ok, ptr = pcall(function()
            return ffi.cast('uint8_t***', ashita.memory.find(0, 0, 'A1????????33C98A4E5E33D28A565D5F5E8950148948185B83C414C20400', 1, 0));
        end);
        if not ok or ptr == nil then return nil, nil; end
        blu_points_ptr = ptr;
    end

    -- Guard every link of the pointer chain (NULL compares equal to nil in
    -- LuaJIT); reading through a NULL pointer would crash the client.
    local ok, spent, max = pcall(function()
        if blu_points_ptr == nil or blu_points_ptr[0] == nil or blu_points_ptr[0][0] == nil then
            return nil, nil;
        end
        return tonumber(blu_points_ptr[0][0][0x14]), tonumber(blu_points_ptr[0][0][0x18]);
    end);
    if not ok or spent == nil or max == nil or max <= 0 then return nil, nil; end
    return spent, max;
end

-- HorizonXI BLU has A+ Blue Magic skill.
-- A spell's learning skill is its A+ cap at the spell's usable level.
-- HorizonXI documents a maximum learning gap of 31 skill points, so the
-- minimum skill shown here is: A+ cap at spell level - 31.
function blue_magic_cap_for_level(level)
    level = math.floor(tonumber(level) or 1);
    if level < 1 then level = 1; end
    if level > 75 then level = 75; end

    if level <= 50 then
        return (level * 3) + 3;
    elseif level <= 60 then
        return 153 + ((level - 50) * 5);
    elseif level <= 67 then
        -- HorizonXI A+ caps: 61=207, 62=212, 63=217, 64=222,
        -- 65=227, 66=232, 67=236.
        if level == 67 then return 236; end
        return 207 + ((level - 61) * 5);
    end

    return 236 + ((level - 67) * 5);
end

function blue_magic_learn_skill(spell)
    local cap = blue_magic_cap_for_level(spell and spell.level or 1);
    return math.max(0, cap - 31);
end

-- HorizonXI BLU set limits by level (Blue Magic Points, spells you can set).
HORIZON_BLU_CAPS = {
    { 10, 10, 6 },
    { 20, 15, 8 },
    { 30, 20, 10 },
    { 40, 25, 12 },
    { 50, 30, 14 },
    { 60, 35, 16 },
    { 70, 40, 18 },
    { 75, 45, 20 },
};

function horizon_blu_caps(level)
    level = math.floor(tonumber(level) or 75);
    -- Assimilation merits (+1 Blue Magic Point each, Lv75) from Config.
    local merits = math.max(0, math.min(5, math.floor(tonumber(state.assimilation and state.assimilation[1]) or 0)));
    for _, row in ipairs(HORIZON_BLU_CAPS) do
        if level <= row[1] then
            if row[1] == 75 then return row[2] + merits, row[3]; end
            return row[2], row[3];
        end
    end
    return 45 + merits, 20;
end

-- Point cap, slot cap, whether the point cap is an estimate, live spent.
-- Live points are used when the client exposes them; otherwise the HorizonXI
-- level table. Not on BLU: Lv75 limits (planning mode).
function get_build_caps()
    local spent, live_max = get_blu_points();
    local level = safe_blu_level();
    local points, slots = horizon_blu_caps(level or 75);
    local estimated = true;
    if live_max ~= nil and live_max > 0 then
        points = live_max;
        estimated = false;
    end
    return points, slots, estimated, spent;
end

-- Returns the display state for a spell:
--   Known       = already learned
--   Learnable   = not learned, current BLU level is high enough, and current
--                 Blue Magic skill meets the minimum learning threshold
--   Unlearnable = not currently learnable by the local player
function get_spell_display_state(spell)
    if spell == nil then
        return 'unlearnable', state.unknown_color;
    end

    if is_known(spell.name) then
        return 'known', state.known_color;
    end

    local blu_skill = safe_blue_magic_skill();
    local learn_skill = blue_magic_learn_skill(spell);

    -- Learning availability is based on the player's current Blue Magic skill,
    -- not the spell's listed job level. A BLU can learn a spell above its
    -- current job level when its Blue Magic skill meets the learning threshold.
    if blu_skill ~= nil and blu_skill >= learn_skill then
        return 'learnable', state.learnable_color;
    end

    return 'unlearnable', state.unknown_color;
end

function spell_state_text(spell)
    local display_state = get_spell_display_state(spell);
    if display_state == 'known' then return 'Known'; end
    if display_state == 'learnable' then return 'Learnable'; end
    return 'Unlearnable';
end

function split_search_terms(value)
    local terms = {};
    value = tostring(value or ''):lower();

    for term in value:gmatch('[^|]+') do
        term = term:gsub('^%s+', ''):gsub('%s+$', '');
        if term ~= '' then
            terms[#terms + 1] = term;
        end
    end

    return terms;
end

-- Built once per spell (all of these fields are static).
function spell_haystack(spell)
    if spell._haystack == nil then
        spell._haystack = table.concat({
            tostring(spell.name or ''),
            tostring(spell.level or ''),
            tostring(spell.points or ''),
            tostring(blue_magic_learn_skill(spell)),
            tostring(spell.type or ''),
            tostring(spell.trait or ''),
            tostring(spell.mob_family or ''),
        }, ' '):lower();
    end
    return spell._haystack;
end

function spell_matches_search(spell, terms)
    if #terms == 0 then return true; end

    local haystack = spell_haystack(spell);

    -- "|" searches are OR matches, matching FancyChat behavior.
    for _, term in ipairs(terms) do
        if haystack:find(term, 1, true) ~= nil then
            return true;
        end
    end

    return false;
end

function filter_accepts(spell, known, blu_level)
    if state.filter_mode == 'known' then
        return known;
    elseif state.filter_mode == 'missing' then
        return not known;
    elseif state.filter_mode == 'ready' then
        return (not known) and blu_level ~= nil and tonumber(spell.level) <= blu_level;
    end
    return true;
end

function compare_spells(a, b)
    local key = state.sort_mode;
    local av, bv;

    if key == 'name' then
        av, bv = a.name:lower(), b.name:lower();
    elseif key == 'points' then
        av, bv = tonumber(a.points) or 0, tonumber(b.points) or 0;
    elseif key == 'learn_skill' then
        av, bv = blue_magic_learn_skill(a), blue_magic_learn_skill(b);
    elseif key == 'type' then
        av, bv = tostring(a.type or ''):lower(), tostring(b.type or ''):lower();
    elseif key == 'trait' then
        av, bv = tostring(a.trait or ''):lower(), tostring(b.trait or ''):lower();
    elseif key == 'mob_family' then
        av, bv = tostring(a.mob_family or ''):lower(), tostring(b.mob_family or ''):lower();
    else
        av, bv = tonumber(a.level) or 0, tonumber(b.level) or 0;
    end

    if av == bv then
        local an = a.name:lower();
        local bn = b.name:lower();
        if an == bn then
            return (tonumber(a.level) or 0) < (tonumber(b.level) or 0);
        end
        return an < bn;
    end

    if state.sort_desc then
        return av > bv;
    end
    return av < bv;
end

filtered_cache = { key = nil, result = {}, blu_level = nil };

-- Rebuilt only when search / filter / sort / known spells / level change.
function get_filtered_spells()
    refresh_known_cache(false);
    local blu_level = safe_blu_level();
    local cache_key = table.concat({
        tostring(state.search[1] or ''), state.filter_mode, state.sort_mode,
        tostring(state.sort_desc), tostring(known_cache.version), tostring(blu_level),
    }, '\1');
    if filtered_cache.key == cache_key then
        return filtered_cache.result, filtered_cache.blu_level;
    end

    local terms = split_search_terms(state.search[1]);
    local result = {};

    for _, spell in ipairs(spells) do
        local known = is_known(spell.name);
        if filter_accepts(spell, known, blu_level) and spell_matches_search(spell, terms) then
            result[#result + 1] = spell;
        end
    end

    table.sort(result, compare_spells);
    filtered_cache.key = cache_key;
    filtered_cache.result = result;
    filtered_cache.blu_level = blu_level;
    return result, blu_level;
end

function clamp_page(total_rows)
    local pages = math.max(1, math.ceil(total_rows / math.max(1, state.per_page)));
    if state.page < 1 then
        state.page = 1;
    elseif state.page > pages then
        state.page = pages;
    end
    return pages;
end

function mark_ui_state_changed(reset_page)
    if reset_page then
        state.page = 1;
    end
    state.settings_dirty = true;
end

function set_filter(mode)
    if state.filter_mode ~= mode then
        state.filter_mode = mode;
        state.build_page[1] = false;
        state.spellsets_page[1] = false;
        state.bluprint_view_page[1] = false;
        mark_ui_state_changed(true);
    elseif state.build_page[1] or state.spellsets_page[1] or state.bluprint_view_page[1] then
        -- Clicking any main filter returns to the spell list, even when
        -- that filter was already active (BLUPrint-View included).
        state.build_page[1] = false;
        state.spellsets_page[1] = false;
        state.bluprint_view_page[1] = false;
        mark_ui_state_changed(true);
    end
end

function set_sort(mode)
    if state.sort_mode == mode then
        state.sort_desc = not state.sort_desc;
    else
        state.sort_mode = mode;
        state.sort_desc = false;
    end
    mark_ui_state_changed(true);
end

function sort_label(label, mode)
    if state.sort_mode ~= mode then
        return label;
    end
    return label .. (state.sort_desc and ' v' or ' ^');
end

function draw_sort_header(label, mode)
    local active = state.sort_mode == mode;

    imgui.PushStyleColor(ImGuiCol_Button, TRANSPARENT);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, accent(0.14));
    imgui.PushStyleColor(ImGuiCol_ButtonActive, accent(0.24));
    imgui.PushStyleColor(ImGuiCol_Text, active and accent() or accent(0.78));
    if imgui.Button(sort_label(label, mode) .. '##sort_' .. mode) then
        set_sort(mode);
    end
    if active then
        draw_item_underline();
    end
    imgui.PopStyleColor(4);
end

-- Learned log (per character, newest last; capped).
LEARNED_LOG_MAX = 500;

function add_learned_log_entry(spell)
    if config.learned_log == nil then config.learned_log = T{}; end

    local zone_id = safe_current_zone_id();
    local mob = nil;
    local defeat = state.last_defeat;
    if defeat ~= nil and (os.time() - (tonumber(defeat.time) or 0)) <= 90
        and (zone_id == nil or tonumber(defeat.zone) == zone_id) then
        mob = defeat.name;
    end

    config.learned_log[#config.learned_log + 1] = T{
        spell = tostring(spell.name),
        time = os.time(),
        zone = zone_id or 0,
        mob = mob or '',
    };
    while #config.learned_log > LEARNED_LOG_MAX do
        table.remove(config.learned_log, 1);
    end
    state.settings_dirty = true;
end

function update_known_snapshot()
    refresh_known_cache(false);
    if state.known_snapshot_initialized and state.snapshot_version == known_cache.version then
        return;
    end
    state.snapshot_version = known_cache.version;

    local now = os.clock();

    if not state.known_snapshot_initialized then
        for _, spell in ipairs(spells) do
            state.known_snapshot[spell._key] = is_known(spell.name);
        end
        state.known_snapshot_initialized = true;
        return;
    end

    -- Collect newly learned spells first. More than 3 at once is the
    -- client loading the spell list (login / job change), not learning.
    local newly = {};
    for _, spell in ipairs(spells) do
        local key = spell._key;
        local known = is_known(spell.name);
        if known and state.known_snapshot[key] ~= true then
            newly[#newly + 1] = spell;
        end
        state.known_snapshot[key] = known;
    end

    if #newly == 0 or #newly > 3 then
        return;
    end

    for _, spell in ipairs(newly) do
        add_learned_log_entry(spell);
        if state.auto_highlight_learned[1] then
            state.selected_spell = spell.name;
            state.learned_flash_until = now + 5.0;
            state.jump_to_selected = true;
        end
    end
end

function maybe_jump_to_selected(filtered)
    if not state.jump_to_selected or not state.selected_spell then
        return;
    end

    for index, spell in ipairs(filtered) do
        if spell.name == state.selected_spell then
            state.page = math.floor((index - 1) / math.max(1, state.per_page)) + 1;
            break;
        end
    end

    state.jump_to_selected = false;
end

function active_column_count()
    local count = 1;
    if state.columns.level[1] then count = count + 1; end
    if state.columns.points[1] then count = count + 1; end
    if state.columns.learn_skill[1] then count = count + 1; end
    if state.columns.type[1] then count = count + 1; end
    if state.columns.trait[1] then count = count + 1; end
    if state.columns.mob_family[1] then count = count + 1; end
    return count;
end

-- Lvl / Points / Learn are narrow fixed columns sized from the header text
-- (plus the sort arrow); Spell, Type, Trait and Mob Family share the rest
-- equally.
function setup_table_columns()
    local function fixed_w(header, sample)
        local a = tonumber((imgui.CalcTextSize(header .. ' ^'))) or 40;
        local b = tonumber((imgui.CalcTextSize(sample))) or 30;
        return math.max(a, b) + 14;
    end
    local stretch = ImGuiTableColumnFlags_WidthStretch or 0;
    local fixed = ImGuiTableColumnFlags_WidthFixed or 0;

    imgui.TableSetupColumn('Spell', stretch, 1.15);
    if state.columns.level[1] then imgui.TableSetupColumn('Lvl', fixed, fixed_w('Lvl', '75')); end
    if state.columns.points[1] then imgui.TableSetupColumn('Points', fixed, fixed_w('Points', '5')); end
    if state.columns.learn_skill[1] then imgui.TableSetupColumn('Learn', fixed, fixed_w('Learn', '000')); end
    if state.columns.type[1] then imgui.TableSetupColumn('Type', stretch, 1.0); end
    if state.columns.trait[1] then imgui.TableSetupColumn('Trait', stretch, 1.0); end
    if state.columns.mob_family[1] then imgui.TableSetupColumn('Mob Family', stretch, 1.0); end
end
