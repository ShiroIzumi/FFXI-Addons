--[[
    MogSuite - modules/crafting/advice.lua (1.6.2)

    "Just tell me what to do": your odds for a recipe, whether it is worth
    it for skill-ups, where its guild is (and if it is open), where to get a
    missing material, a shopping list for N synths, and the best next
    recipes to skill up on.

    The odds follow LandSandBoat's synthesis code (synthutils.cpp, which
    HorizonXI is built on):
      success starts at 95%; every level you are UNDER a recipe's skill takes
      10% off (each craft of the recipe rolls on its own, never under 5%)
      HQ only when you are at or over every craft of the recipe:
        0-10 over 1%, 11-30 over 5%, 31-50 over 25%, 51+ over 50%
        (the lowest of the recipe's crafts counts); an HQ1 becomes HQ2 25%
        of the time, an HQ2 becomes HQ3 25% of the time
      skill-ups only come from recipes above your skill (by the main craft),
        more often the further above
    Crafting gear and guild image support raise your skill a little; they are
    not counted here.
]]

-- Crafting guilds (LandSandBoat guild hours, the same as the Calendar).
GUILD_OF = {
    Woodworking  = { where = "Northern San d'Oria", open = 6, close = 21, holiday = 0 },
    Smithing     = { where = "Northern San d'Oria / Metalworks", open = 8, close = 23, holiday = 2 },
    Goldsmithing = { where = 'Bastok Markets', open = 8, close = 23, holiday = 4 },
    Clothcraft   = { where = 'Windurst Woods', open = 6, close = 21, holiday = 0 },
    Leathercraft = { where = "Southern San d'Oria", open = 3, close = 18, holiday = 4 },
    Bonecraft    = { where = 'Windurst Woods', open = 8, close = 23, holiday = 3 },
    Alchemy      = { where = 'Bastok Mines', open = 8, close = 23, holiday = 6 },
    Cooking      = { where = 'Windurst Waters', open = 5, close = 20, holiday = 7 },
};
VDAY_NAMES = { [0] = 'Firesday', [1] = 'Earthsday', [2] = 'Watersday', [3] = 'Windsday', [4] = 'Iceday', [5] = 'Lightningday', [6] = 'Lightsday', [7] = 'Darksday' };

local function span(secs)
    secs = math.max(0, math.floor(secs or 0));
    local h, m = math.floor(secs / 3600), math.floor(secs % 3600 / 60);
    if h > 0 then return ('%dh %02dm'):format(h, m); end
    return ('%dm'):format(math.max(1, m));
end

-- open (bool), Earth seconds until that changes, 'holiday' | 'hours' | nil
function guild_status(g)
    local raw = os.time() + 92514960;
    local weekday = math.floor(raw / 3456) % 8;
    local into_min = (raw % 3456) / 2.4;
    local open_min, close_min = g.open * 60, g.close * 60;
    if weekday ~= g.holiday and into_min >= open_min and into_min < close_min then
        return true, (close_min - into_min) * 2.4, nil;
    end
    local why = (weekday == g.holiday) and 'holiday' or 'hours';
    for ahead = 0, 8 do
        local d = (weekday + ahead) % 8;
        if d ~= g.holiday then
            local at = ahead * 1440 + open_min;
            if at > into_min then return false, (at - into_min) * 2.4, why; end
        end
    end
    return false, 0, why;
end

function guild_line(craft_name)
    local g = GUILD_OF[craft_name];
    if g == nil then return nil; end
    local open, secs, why = guild_status(g);
    if open then
        return ('%s guild, %s: open, closes in %s'):fmt(craft_name, g.where, span(secs)), true;
    end
    if why == 'holiday' then
        return ('%s guild, %s: closed for its holiday (%s), opens in %s'):fmt(craft_name, g.where, VDAY_NAMES[g.holiday], span(secs)), false;
    end
    return ('%s guild, %s: closed, opens in %s'):fmt(craft_name, g.where, span(secs)), false;
end

-- ============================================================================
-- Odds
-- ============================================================================

-- { success, brk, hq, hq2, hq3, can_hq, tier, worst = { craft, diff }, crafts = { { craft, level, skill, diff } } }
function recipe_odds(rec)
    local out = { crafts = {} };
    local success, rate = 1.0, 95;
    local tier = 4;
    local can_hq = true;
    local worst = nil;
    local list = { { craft = rec.craft, level = rec.level } };
    for _, s in ipairs(rec.subs) do list[#list + 1] = { craft = s.craft, level = s.level }; end
    for _, c in ipairs(list) do
        local skill = state.skills[c.craft.name] or 0;
        local diff = c.level - skill;           -- > 0: under the recipe
        out.crafts[#out.crafts + 1] = { craft = c.craft, level = c.level, skill = skill, diff = diff };
        if diff <= 0 then
            local over = -diff;
            local t = (over <= 10) and 1 or ((over <= 30) and 2 or ((over <= 50) and 3 or 4));
            tier = math.min(tier, t);
        else
            can_hq = false;
            rate = math.max(5, rate - diff * 10);
        end
        success = success * (math.min(99, rate) / 100);
        if worst == nil or diff > worst.diff then worst = { craft = c.craft, diff = diff }; end
    end
    if rec.desynth then success = success * (45 / 95); end
    local hq_pct = 0;
    if can_hq then hq_pct = ({ 1, 5, 25, 50 })[tier] or 0; end
    if rec.desynth then hq_pct = math.min(80, hq_pct * 1.5); end
    local hq = success * hq_pct / 100;
    out.success = success;
    out.brk = 1 - success;
    out.hq = hq;
    out.hq2 = hq * 0.25;
    out.hq3 = hq * 0.25 * 0.25;
    out.can_hq = can_hq;
    out.tier = can_hq and tier or 0;
    out.worst = worst;
    return out;
end

-- Skill-up verdict for the main craft: text, color key ('good' | 'ok' | 'bad' | 'none'), approx chance.
function skillup_verdict(rec)
    local skill = state.skills[rec.craft.name] or 0;
    local d = rec.level - skill;
    if rec.desynth then return 'Desynthesis: skill-ups work like a synth of this level.', 'ok'; end
    -- Approximate chance (LandSandBoat's classic formula, before penalties).
    local chance = 0;
    if d > 0 then
        chance = d * (3 - math.log(1.2 + math.floor(skill / 10))) / 10;
        chance = math.max(0, math.min(1, chance));
    end
    if d <= 0 then
        return ('Too easy for skill-ups: you are %d over it.'):fmt(-d), 'none', 0;
    elseif d <= 3 then
        return ('Good for skill-ups: %d over your skill (about %d%% a synth).'):fmt(d, math.floor(chance * 100 + 0.5)), 'good', chance;
    elseif d <= 6 then
        return ('Skill-ups, but you will break often (%d over your skill).'):fmt(d), 'ok', chance;
    end
    return ('Too hard for now: %d over your skill, it will mostly break.'):fmt(d), 'bad', chance;
end

-- ============================================================================
-- Where to get a material
-- ============================================================================

RECIPES_BY_RESULT = nil;
function recipes_making(id)
    if RECIPES_BY_RESULT == nil then
        RECIPES_BY_RESULT = {};
        for _, r in ipairs(load_recipes()) do
            if not r.desynth then
                RECIPES_BY_RESULT[r.result] = RECIPES_BY_RESULT[r.result] or {};
                table.insert(RECIPES_BY_RESULT[r.result], r);
            end
        end
        for _, list in pairs(RECIPES_BY_RESULT) do table.sort(list, function(a, b) return a.level < b.level; end); end
    end
    return RECIPES_BY_RESULT[id];
end

-- Up to n "Monster (Zone)" strings.
function drop_sources(id, n)
    local d = MS.drops_of and MS.drops_of(id) or nil;
    if d == nil then return nil; end
    local out, seen = {}, {};
    for i = 1, #d, 2 do
        local s = ('%s (%s)'):fmt(tostring(d[i + 1]), MS.zone_name and MS.zone_name(d[i]) or tostring(d[i]));
        if not seen[s] then
            seen[s] = true;
            out[#out + 1] = s;
            if #out >= (n or 3) then break; end
        end
    end
    return out, #d / 2;
end

-- ============================================================================
-- Shopping list for n synths: { { id, need, have, short } }
-- ============================================================================

function shopping_list(rec, n)
    n = math.max(1, math.floor(tonumber(n) or 1));
    local c = state.counts;
    local out = {};
    local cry = (c[rec.crystal] or 0) + ((rec.hq_crystal or 0) > 0 and (c[rec.hq_crystal] or 0) or 0);
    out[#out + 1] = { id = rec.crystal, need = n, have = cry, short = math.max(0, n - cry) };
    for _, need in ipairs(recipe_needs(rec)) do
        local have = c[need.id] or 0;
        out[#out + 1] = { id = need.id, need = need.n * n, have = have, short = math.max(0, need.n * n - have) };
    end
    return out;
end

-- How many materials (kinds) are missing for one synth.
function missing_kinds(rec)
    local n = 0;
    for _, s in ipairs(shopping_list(rec, 1)) do if s.short > 0 then n = n + 1; end end
    return n;
end

-- ============================================================================
-- Best next recipes to skill up a craft
-- ============================================================================

function next_recipes(craft, count)
    load_recipes();
    local skill = state.skills[craft.name] or 0;
    local out = {};
    for _, rec in ipairs(RECIPES) do
        if not rec.desynth and rec.craft == craft and rec.level > skill and rec.level <= skill + 4 then
            -- Sub crafts must not hold you back.
            local subs_ok = true;
            for _, s in ipairs(rec.subs) do
                if (state.skills[s.craft.name] or 0) < s.level then subs_ok = false; break; end
            end
            if subs_ok and (rec.ki or 0) == 0 then
                out[#out + 1] = { rec = rec, missing = missing_kinds(rec), times = times_you_can(rec), d = rec.level - skill };
            end
        end
    end
    table.sort(out, function(a, b)
        if (a.times > 0) ~= (b.times > 0) then return a.times > 0; end
        if a.missing ~= b.missing then return a.missing < b.missing; end
        if a.d ~= b.d then return a.d < b.d; end
        return recipe_name(a.rec) < recipe_name(b.rec);
    end);
    while #out > (count or 3) do table.remove(out); end
    return out;
end
