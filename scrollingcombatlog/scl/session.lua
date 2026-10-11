require('common');

-- ============================================================================
-- Session summary (local player only)
-- ============================================================================
-- Tracks your own rewards and damage for the Session window. Nothing here
-- looks at other players, and nothing predicts anything: every number is
-- recorded after the fact from events the addon already displays.

-- A "fight" ends after this many seconds without dealing damage.
local FIGHT_IDLE_SECONDS = 8.0;

local data = {};

local function reset()
    data.started = os.clock();
    data.exp = 0;
    data.limit = 0;
    data.capacity = 0;
    data.gil = 0;
    data.kills = 0;
    data.damage_total = 0;
    data.drops = {};
    data.drop_order = {};
    data.biggest_hit = nil;   -- { amount, target, crit }
    data.biggest_ws = nil;    -- { amount, name, target }
    data.biggest_magic = nil; -- { amount, name, target }  (any spell: WHM/BLM/BLU/NIN/...)
    data.biggest_pet = nil;   -- { amount, name, pet, target }
    data.biggest_heal_done = nil;     -- { amount, name, target }
    data.biggest_hit_taken = nil;     -- { amount, name, source }
    data.biggest_heal_taken = nil;    -- { amount, name, source }
    data.fight = nil;         -- { started, last, total, target }
    data.last_fight = nil;
end

reset();

local function record_damage(amount, kind, name, target)
    amount = tonumber(amount) or 0;
    if amount <= 0 then
        return;
    end

    local now = os.clock();
    data.damage_total = data.damage_total + amount;

    local fight = data.fight;
    if fight == nil or (now - fight.last) > FIGHT_IDLE_SECONDS then
        if fight ~= nil then
            data.last_fight = fight;
        end
        fight = { started = now, last = now, total = 0, target = target };
        data.fight = fight;
    end
    fight.total = fight.total + amount;
    fight.last = now;
    fight.target = target or fight.target;

    if kind == 'melee' or kind == 'crit' or kind == 'ranged' then
        if data.biggest_hit == nil or amount > data.biggest_hit.amount then
            data.biggest_hit = { amount = amount, target = target, crit = kind == 'crit' };
        end
    elseif kind == 'ws' then
        if data.biggest_ws == nil or amount > data.biggest_ws.amount then
            data.biggest_ws = { amount = amount, name = name, target = target };
        end
    elseif kind == 'spell' then
        if data.biggest_magic == nil or amount > data.biggest_magic.amount then
            data.biggest_magic = { amount = amount, name = name, target = target };
        end
    end
end

-- Heals you cast / used (on anyone, including yourself).
local function record_heal_done(amount, name, target)
    amount = tonumber(amount) or 0;
    if amount <= 0 then return end
    if data.biggest_heal_done == nil or amount > data.biggest_heal_done.amount then
        data.biggest_heal_done = { amount = amount, name = name, target = target };
    end
end

-- Damage you took: melee / ranged (name = nil) or a named spell / TP move.
local function record_hit_taken(amount, name, source)
    amount = tonumber(amount) or 0;
    if amount <= 0 then return end
    if data.biggest_hit_taken == nil or amount > data.biggest_hit_taken.amount then
        data.biggest_hit_taken = { amount = amount, name = name, source = source };
    end
end

-- Healing you received (from anyone, including yourself).
local function record_heal_taken(amount, name, source)
    amount = tonumber(amount) or 0;
    if amount <= 0 then return end
    if data.biggest_heal_taken == nil or amount > data.biggest_heal_taken.amount then
        data.biggest_heal_taken = { amount = amount, name = name, source = source };
    end
end

-- Your own pet only. Pet damage is kept separate from your damage totals.
-- name: the pet's ability (nil for a melee hit); pet: the pet's name.
local function record_pet_damage(amount, name, pet, target)
    amount = tonumber(amount) or 0;
    if amount <= 0 then
        return;
    end
    if data.biggest_pet == nil or amount > data.biggest_pet.amount then
        data.biggest_pet = { amount = amount, name = name, pet = pet, target = target };
    end
end

local function record_kill()
    data.kills = data.kills + 1;
end

-- kind: 'exp', 'limit', 'capacity'
local function record_points(kind, amount)
    amount = tonumber(amount) or 0;
    if amount <= 0 then return end
    if kind == 'exp' then
        data.exp = data.exp + amount;
    elseif kind == 'limit' then
        data.limit = data.limit + amount;
    elseif kind == 'capacity' then
        data.capacity = data.capacity + amount;
    end
end

local function record_gil(amount)
    amount = tonumber(amount) or 0;
    if amount > 0 then
        data.gil = data.gil + amount;
    end
end

local function record_obtain(item)
    item = tostring(item or '');
    if item == '' then return end
    local key = item:lower();
    if data.drops[key] == nil then
        data.drops[key] = { name = item, count = 0 };
        data.drop_order[#data.drop_order + 1] = key;
    end
    data.drops[key].count = data.drops[key].count + 1;
end

-- Called from add_progression_event with the final displayed reward text,
-- so a reward is counted exactly once whichever source reported it.
local function record_reward_text(kind, value)
    local text = tostring(value or '');
    local amount = tonumber(text:match('^%+(%d+)'));
    if not amount then return end

    if kind == 'gil' then
        record_gil(amount);
    elseif text:find(' EXP', 1, true) then
        record_points('exp', amount);
    elseif text:find('Limit Points', 1, true) then
        record_points('limit', amount);
    elseif text:find('Capacity Points', 1, true) then
        record_points('capacity', amount);
    end
end

local function get()
    local now = os.clock();
    local fight = data.fight;
    local current = nil;

    if fight ~= nil then
        local active = (now - fight.last) <= FIGHT_IDLE_SECONDS;
        local seconds = math.max(1.0, fight.last - fight.started);
        current = {
            active = active,
            total = fight.total,
            dps = fight.total / seconds,
            seconds = seconds,
            target = fight.target,
        };
    end

    return {
        elapsed = math.max(1.0, now - data.started),
        exp = data.exp,
        limit = data.limit,
        capacity = data.capacity,
        gil = data.gil,
        kills = data.kills,
        damage_total = data.damage_total,
        drops = data.drops,
        drop_order = data.drop_order,
        biggest_hit = data.biggest_hit,
        biggest_ws = data.biggest_ws,
        biggest_magic = data.biggest_magic,
        biggest_pet = data.biggest_pet,
        biggest_heal_done = data.biggest_heal_done,
        biggest_hit_taken = data.biggest_hit_taken,
        biggest_heal_taken = data.biggest_heal_taken,
        fight = current,
    };
end

return {
    reset = reset,
    record_damage = record_damage,
    record_pet_damage = record_pet_damage,
    record_heal_done = record_heal_done,
    record_hit_taken = record_hit_taken,
    record_heal_taken = record_heal_taken,
    record_kill = record_kill,
    record_points = record_points,
    record_gil = record_gil,
    record_obtain = record_obtain,
    record_reward_text = record_reward_text,
    get = get,
};
