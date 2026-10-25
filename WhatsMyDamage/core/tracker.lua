--[[
    WhatsMyDamage - core/tracker.lua

    Counts damage done, healing done and damage taken for you, your party
    (and the alliance when that's on) and their pets, from the action
    packets the game already shows you:

      0x028 (actions): melee, ranged, weapon skills, spells, abilities,
        items, pet moves; hits / crits / misses / resists; additional
        effects (enspells), skillchains, magic bursts; spikes and counters;
        monsters' actions on you (damage taken, evaded, shadows, parries).
      0x029 (messages): deaths and kills.

    Damage only counts against monsters. Nothing is ever sent.

    Store (one "overall" segment, cleared with Reset):
      actors[sid] = { sid, name, job, pet, owner, alliance, me,
                      damage = stat, heal = stat, taken = stat,
                      kills, deaths = { {t, killer, recap} }, recent = {..} }
      stat = { total, cats = { [key] = cat } }
      cat  = { key, group, name, total, hits, crits, misses, avoided,
               resisted, count, min, max, mb, from = { [mob] = amount } }
]]

require('common');
local data = require('core.data');
local names = require('core.names');
local roster = require('core.roster');

local tracker = {
    real = nil,         -- the live store
    fake = nil,         -- test mode store
    test = false,
    rev = 0,            -- bumped on every change (windows re-sort on it)
    next_fake = 0,
};

local function new_store()
    return { actors = {}, started = nil, last = nil };
end

local function new_stat() return { total = 0, cats = {} }; end

tracker.real = new_store();

function tracker.store() return tracker.test and tracker.fake or tracker.real; end

function tracker.reset()
    tracker.real = new_store();
    roster.reset_pets();
    tracker.rev = tracker.rev + 1;
end

-- ============================================================================
-- Actors and counting
-- ============================================================================

local function actor(st, sid)
    local a = st.actors[sid];
    if a == nil then
        a = { sid = sid, damage = new_stat(), heal = new_stat(), taken = new_stat(),
              kills = 0, deaths = {}, recent = {} };
        st.actors[sid] = a;
    end
    -- Refresh who they are (job changes, pets).
    local m = roster.members[sid];
    if m ~= nil then
        a.name, a.job, a.alliance, a.me, a.pet, a.owner = m.name, (m.job ~= '' and m.job or a.job), m.alliance, m.me, false, nil;
    else
        local owner = roster.pets[sid];
        if owner ~= nil then
            a.pet, a.owner = true, owner;
            a.name = roster.pet_names[sid] or a.name or names.entity(sid);
            local om = roster.members[owner];
            if om ~= nil then a.alliance = om.alliance; end
        end
    end
    a.name = a.name or names.entity(sid);
    return a;
end
tracker.actor = actor;

local function cat_of(stat, group, name)
    local key = group .. ':' .. name;
    local c = stat.cats[key];
    if c == nil then
        c = { key = key, group = group, name = name, total = 0, hits = 0, crits = 0, misses = 0,
              avoided = 0, resisted = 0, count = 0, min = nil, max = 0, mb = 0, from = {}, avoid = {} };
        stat.cats[key] = c;
    end
    return c;
end
tracker.cat_of = cat_of;

-- amount > 0: a landed hit / heal. Returns the category.
local function add(st, a, mode, group, name, amount, crit, mb, from)
    local stat = a[mode];
    local c = cat_of(stat, group, name);
    amount = math.max(0, math.floor(tonumber(amount) or 0));
    c.total = c.total + amount;
    c.hits = c.hits + 1;
    c.count = c.count + 1;
    if crit then c.crits = c.crits + 1; end
    if mb then c.mb = c.mb + 1; c.mb_total = (c.mb_total or 0) + amount; end
    if c.min == nil or amount < c.min then c.min = amount; end
    if amount > c.max then c.max = amount; end
    if from ~= nil then c.from[from] = (c.from[from] or 0) + amount; end
    stat.total = stat.total + amount;
    local now = os.time();
    st.started = st.started or now;
    st.last = now;
    tracker.rev = tracker.rev + 1;
    return c;
end
tracker.add = add;

local function note(st, a, mode, group, name, field, from, avoid_kind)
    local c = cat_of(a[mode], group, name);
    c[field] = c[field] + 1;
    if field ~= 'avoided' and field ~= 'resisted' then c.count = c.count + 1; end
    if avoid_kind ~= nil then c.avoid[avoid_kind] = (c.avoid[avoid_kind] or 0) + 1; end
    if from ~= nil then c.from[from] = c.from[from] or 0; end
    tracker.rev = tracker.rev + 1;
end

-- What an action is: group and name, for our side.
local function source_of(cat, param, is_pet)
    if cat == data.CAT_MELEE then return 'melee', 'Melee'; end
    if cat == data.CAT_RANGED then return 'ranged', 'Ranged'; end
    if cat == data.CAT_WS then
        if is_pet then return 'ja', names.tp(param); end
        return 'ws', names.ws(param);
    end
    if cat == data.CAT_SPELL then return 'magic', names.spell(param); end
    if cat == data.CAT_ITEM then return 'item', names.item(param); end
    if cat == data.CAT_JA or cat == data.CAT_DANCE or cat == data.CAT_RUNE then return 'ja', names.ja(param); end
    if cat == data.CAT_PET or cat == data.CAT_MOB_TP then return 'ja', names.tp(param); end
    return nil, nil;
end

-- What a monster's action on us is.
local function mob_source(cat, param)
    if cat == data.CAT_MELEE then return 'melee', 'Melee'; end
    if cat == data.CAT_RANGED then return 'ranged', 'Ranged'; end
    if cat == data.CAT_SPELL then return 'magic', names.spell(param); end
    if cat == data.CAT_MOB_TP or cat == data.CAT_WS or cat == data.CAT_PET then return 'tp', names.tp(param); end
    if cat == data.CAT_JA then return 'ja', names.ja(param); end
    return nil, nil;
end

-- ============================================================================
-- 0x028
-- ============================================================================

local function parse_0x028(e)
    local raw = e.data_raw;
    local max_bits = (tonumber(e.size) or 0) * 8;
    local pos = 40;
    local bad = false;
    local function bits(n)
        if pos + n > max_bits then bad = true; return 0; end
        local v = ashita.bits.unpack_be(raw, 0, pos, n);
        pos = pos + n;
        return v;
    end
    local act = { targets = {} };
    act.actor = bits(32);
    local tcount = bits(6);
    pos = pos + 4;
    act.cat = bits(4);
    if act.cat == 8 or act.cat == 9 then
        act.param = bits(16);
        bits(16);
    else
        act.param = bits(32);
    end
    bits(32);   -- recast
    for _ = 1, tcount do
        local t = { id = bits(32), actions = {} };
        local n = bits(4);
        for _ = 1, n do
            local a = {};
            a.reaction = bits(5);
            bits(12);   -- animation
            bits(7);    -- special effect
            bits(3);    -- knockback
            a.param = bits(17);
            a.msg = bits(10);
            bits(31);   -- flags
            if bits(1) == 1 then
                bits(10);
                a.add = { param = bits(17), msg = bits(10) };
            end
            if bits(1) == 1 then
                bits(10);
                a.spike = { param = bits(14), msg = bits(10) };
            end
            t.actions[#t.actions + 1] = a;
        end
        act.targets[#act.targets + 1] = t;
        if bad then break; end
    end
    if bad then return nil; end
    return act;
end

function tracker.packet_0x028(e)
    if tracker.test then return; end
    local act = parse_0x028(e);
    if act == nil or act.cat == 7 or act.cat == 8 or act.cat == 9 or act.cat == 12 then return; end   -- starts are never used
    roster.update();
    local st = tracker.real;
    local kind = roster.kind(act.actor);

    if kind ~= nil then
        -- One of us acted.
        local a = actor(st, act.actor);
        local group, name = source_of(act.cat, act.param, kind == 'pet');
        if group == nil then return; end
        for _, t in ipairs(act.targets) do
            local mob = roster.is_mob(t.id);
            for _, x in ipairs(t.actions) do
                local msg = x.msg;
                if data.HEAL[msg] and not mob then
                    if x.param > 0 then add(st, a, 'heal', group, name, x.param, false, false, names.entity(t.id)); end
                elseif mob then
                    local mname = names.entity(t.id);
                    if data.DAMAGE[msg] then
                        add(st, a, 'damage', group, name, x.param, data.CRIT[msg] == true, data.MAGIC_BURST[msg] == true, mname);
                    elseif data.MISS[msg] then
                        note(st, a, 'damage', group, name, 'misses', mname);
                    elseif data.AVOID[msg] then
                        note(st, a, 'damage', group, name, 'avoided', mname, data.AVOID[msg]);
                    elseif data.RESIST[msg] then
                        note(st, a, 'damage', group, name, 'resisted', mname);
                    end
                    -- Skillchain / additional effect riding on it.
                    if x.add ~= nil then
                        local sc = data.SKILLCHAIN[x.add.msg];
                        if sc ~= nil then
                            add(st, a, 'damage', 'sc', sc, x.add.param, false, false, mname);
                        elseif data.ADD_DAMAGE[x.add.msg] then
                            add(st, a, 'damage', 'add', 'Additional Effect', x.add.param, false, false, mname);
                        end
                    end
                end
            end
        end
        return;
    end

    if roster.is_mob(act.actor) then
        -- A monster acted: damage taken (and our spikes / counters).
        local group, name = mob_source(act.cat, act.param);
        local mname = names.entity(act.actor);
        for _, t in ipairs(act.targets) do
            if roster.kind(t.id) ~= nil then
                local a = actor(st, t.id);
                for _, x in ipairs(t.actions) do
                    local msg = x.msg;
                    if group ~= nil then
                        if data.DAMAGE[msg] and x.param > 0 then
                            add(st, a, 'taken', group, name, x.param, data.CRIT[msg] == true, false, mname);
                            local r = a.recent;
                            r[#r + 1] = { t = os.time(), from = mname, what = name, amount = x.param, crit = data.CRIT[msg] == true };
                            if #r > 8 then table.remove(r, 1); end
                        elseif data.MISS[msg] then
                            note(st, a, 'taken', group, name, 'misses', mname, 'evaded');
                        elseif data.AVOID[msg] then
                            note(st, a, 'taken', group, name, 'avoided', mname, data.AVOID[msg]);
                        elseif data.RESIST[msg] then
                            note(st, a, 'taken', group, name, 'resisted', mname, 'resisted');
                        end
                    end
                    -- Our counter / retaliation hits the monster.
                    if data.COUNTER[msg] and x.param > 0 then
                        add(st, a, 'damage', 'spikes', 'Counter', x.param, false, false, mname);
                    end
                    -- Our spikes hit the monster.
                    if x.spike ~= nil and data.SPIKES[x.spike.msg] and x.spike.param > 0 then
                        add(st, a, 'damage', 'spikes', 'Spikes', x.spike.param, false, false, mname);
                    end
                    -- The monster's enspell / added effect on us.
                    if x.add ~= nil and data.ADD_DAMAGE[x.add.msg] and x.add.param > 0 then
                        add(st, a, 'taken', 'add', 'Additional Effect', x.add.param, false, false, mname);
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- 0x029: deaths and kills
-- ============================================================================

function tracker.packet_0x029(e)
    if tracker.test then return; end
    local d = e.data;
    if d == nil or #d < 0x1A then return; end
    local function u32(at)
        local b1, b2, b3, b4 = d:byte(at + 1, at + 4);
        return (b1 or 0) + (b2 or 0) * 256 + (b3 or 0) * 65536 + (b4 or 0) * 16777216;
    end
    local actor_id, target_id = u32(0x04), u32(0x08);
    local msg = ((d:byte(0x19) or 0) + (d:byte(0x1A) or 0) * 256) % 0x8000;
    if not data.DEFEAT[msg] then return; end
    roster.update();
    local st = tracker.real;
    -- 97: "<player> was defeated by the <monster>" (the player is the actor).
    if msg == 97 then actor_id, target_id = target_id, actor_id; end
    if roster.kind(target_id) ~= nil then
        local a = actor(st, target_id);
        local killer = (actor_id ~= 0 and actor_id ~= target_id) and names.entity(actor_id) or nil;
        local recap, now = {}, os.time();
        for _, r in ipairs(a.recent) do
            if now - r.t <= 30 then recap[#recap + 1] = r; end
        end
        a.deaths[#a.deaths + 1] = { t = now, killer = killer, recap = recap };
        a.recent = {};
        tracker.rev = tracker.rev + 1;
    elseif roster.kind(actor_id) ~= nil and roster.is_mob(target_id) then
        local a = actor(st, actor_id);
        a.kills = a.kills + 1;
        tracker.rev = tracker.rev + 1;
    end
end

-- ============================================================================
-- Rows for a window
-- ============================================================================

-- opts: { combine = pets into owners, alliance = show alliance }
-- Returns rows sorted by value: { sid, name, job, value, pct, pet, owner_name, me, a, pets = { actor } }
function tracker.rows(mode, opts)
    local st = tracker.store();
    local rows, by_sid, total = {}, {}, 0;
    for sid, a in pairs(st.actors) do
        if not a.pet and (opts.alliance or not a.alliance) then
            local r = { sid = sid, name = a.name, job = a.job, value = a[mode].total, me = a.me, a = a, pets = {} };
            by_sid[sid] = r;
            rows[#rows + 1] = r;
        end
    end
    for sid, a in pairs(st.actors) do
        if a.pet then
            local owner = by_sid[a.owner];
            if owner ~= nil then
                if opts.combine then
                    owner.value = owner.value + a[mode].total;
                    owner.pets[#owner.pets + 1] = a;
                else
                    rows[#rows + 1] = { sid = sid, name = a.name, job = owner.job, value = a[mode].total, pet = true,
                        owner_name = owner.name, a = a, pets = {} };
                end
            end
        end
    end
    local out = {};
    for _, r in ipairs(rows) do
        if r.value > 0 then
            out[#out + 1] = r;
            total = total + r.value;
        end
    end
    table.sort(out, function(x, y)
        if x.value ~= y.value then return x.value > y.value; end
        return tostring(x.name) < tostring(y.name);
    end);
    for i, r in ipairs(out) do
        r.rank = i;
        r.pct = (total > 0) and (r.value * 100 / total) or 0;
    end
    return out, total;
end

-- Seconds since the first counted action (for the header tooltip).
function tracker.elapsed()
    local st = tracker.store();
    if st.started == nil then return 0; end
    return math.max(0, (st.last or st.started) - st.started);
end

-- ============================================================================
-- Test mode: a made-up party that keeps fighting
-- ============================================================================

local FAKE = {
    { 9001, 'Izumi', 'RNG', true }, { 9002, 'Hikarabikara', 'BLU' }, { 9003, 'Kindone', 'BRD' },
    { 9004, 'Kotorfan', 'COR' }, { 9005, 'Msmcmuffinpants', 'PUP' }, { 9006, 'Thilibant', 'MNK' },
    { 9007, 'Ecreus', 'PLD', false, true }, { 9008, 'Noellesakura', 'WHM', false, true }, { 9009, 'Spockk', 'BLM', false, true },
};

local function fake_setup()
    local st = new_store();
    st.started = os.time();
    for _, f in ipairs(FAKE) do
        st.actors[f[1]] = { sid = f[1], name = f[2], job = f[3], me = f[4] == true, alliance = f[5] == true,
            damage = new_stat(), heal = new_stat(), taken = new_stat(), kills = 0, deaths = {}, recent = {} };
    end
    st.actors[9105] = { sid = 9105, name = 'Valoredge', pet = true, owner = 9005, damage = new_stat(), heal = new_stat(),
        taken = new_stat(), kills = 0, deaths = {}, recent = {} };
    st.actors[9104] = { sid = 9104, name = 'Carbuncle', pet = true, owner = 9002, damage = new_stat(), heal = new_stat(),
        taken = new_stat(), kills = 0, deaths = {}, recent = {} };
    tracker.fake = st;
end

local MOBS = { 'Marsh Murre', 'Goblin Smithy', 'Ancient Bat', 'Bloodlapper' };
local PLAN = {
    -- sid, group, name, base, crit chance, miss chance
    { 9001, 'ranged', 'Ranged', 150, 0.15, 0.06 }, { 9001, 'ws', 'Sidewinder', 900, 0, 0.05 }, { 9001, 'ja', 'Barrage', 420, 0.1, 0.1 },
    { 9002, 'melee', 'Melee', 70, 0.08, 0.08 }, { 9002, 'magic', 'Sickle Slash', 520, 0.1, 0.06 }, { 9002, 'magic', 'Head Butt', 260, 0, 0.1 },
    { 9003, 'melee', 'Melee', 35, 0.05, 0.12 },
    { 9004, 'ranged', 'Ranged', 110, 0.1, 0.08 }, { 9004, 'ws', 'Slug Shot', 760, 0, 0.1 }, { 9004, 'ja', 'Quick Draw', 340, 0, 0 },
    { 9005, 'melee', 'Melee', 75, 0.07, 0.1 }, { 9005, 'ws', 'Victory Smite', 610, 0, 0.05 },
    { 9105, 'melee', 'Melee', 55, 0.06, 0.12 }, { 9105, 'ja', 'Chimera Ripper', 320, 0, 0.1 },
    { 9006, 'melee', 'Melee', 90, 0.1, 0.06 }, { 9006, 'ws', 'Asuran Fists', 880, 0, 0.04 }, { 9006, 'add', 'Additional Effect', 25, 0, 0 },
    { 9104, 'ja', 'Poison Nails', 260, 0, 0.1 },
    { 9007, 'melee', 'Melee', 50, 0.05, 0.1 }, { 9009, 'magic', 'Thunder III', 980, 0, 0.05 }, { 9009, 'magic', 'Blizzard III', 870, 0, 0.05 },
};
local HEALS = {
    { 9003, 'magic', 'Ballad (Refresh)', 0 }, { 9008, 'magic', 'Cure IV', 420 }, { 9008, 'magic', 'Curaga II', 380 },
    { 9002, 'magic', 'Wild Carrot', 300 }, { 9004, 'ja', 'Curing Waltz II', 240 }, { 9104, 'ja', 'Healing Ruby', 180 },
};

function tracker.set_test(on)
    tracker.test = on == true;
    if tracker.test then
        fake_setup();
        for _ = 1, 60 do tracker.fake_tick(true); end
    end
    tracker.rev = tracker.rev + 1;
end

function tracker.fake_tick(force)
    if not tracker.test then return; end
    local now = os.clock();
    if not force and now < tracker.next_fake then return; end
    tracker.next_fake = now + 0.35;
    local st = tracker.fake;
    local mob = MOBS[math.random(1, #MOBS)];
    for _ = 1, 3 do
        local p = PLAN[math.random(1, #PLAN)];
        local a = st.actors[p[1]];
        if math.random() < p[6] then
            note(st, a, 'damage', p[2], p[3], 'misses', mob);
        else
            local crit = math.random() < p[5];
            local amt = math.floor(p[4] * (0.75 + math.random() * 0.5) * (crit and 1.6 or 1));
            add(st, a, 'damage', p[2], p[3], amt, crit, p[2] == 'magic' and math.random() < 0.12, mob);
            if p[2] == 'ws' and math.random() < 0.25 then
                add(st, a, 'damage', 'sc', ({ 'Fusion', 'Distortion', 'Fragmentation', 'Light' })[math.random(1, 4)], math.floor(amt * 0.8), false, false, mob);
            end
        end
    end
    if math.random() < 0.5 then
        local h = HEALS[math.random(2, #HEALS)];
        add(st, st.actors[h[1]], 'heal', h[2], h[3], math.floor(h[4] * (0.8 + math.random() * 0.4)), false, false, 'Ecreus');
    end
    if math.random() < 0.6 then
        local tgt = ({ 9007, 9007, 9007, 9002, 9006, 9105, 9001 })[math.random(1, 7)];
        local a = st.actors[tgt];
        if math.random() < 0.2 then
            local kinds = { 'evaded', 'shadows', 'parried' };
            note(st, a, 'taken', 'melee', 'Melee', math.random() < 0.5 and 'misses' or 'avoided', mob, kinds[math.random(1, 3)]);
        else
            local tp = math.random() < 0.15;
            local amt = math.floor((tp and 260 or 85) * (0.7 + math.random() * 0.6));
            add(st, a, 'taken', tp and 'tp' or 'melee', tp and 'Bomb Toss' or 'Melee', amt, false, false, mob);
            local r = a.recent;
            r[#r + 1] = { t = os.time(), from = mob, what = tp and 'Bomb Toss' or 'Melee', amount = amt };
            if #r > 8 then table.remove(r, 1); end
        end
    end
    -- Someone dies now and then (death recap).
    if math.random() < 0.01 then
        local a = st.actors[9002];
        a.deaths[#a.deaths + 1] = { t = os.time(), killer = mob, recap = { unpack(a.recent) } };
        a.recent = {};
    end
    if math.random() < 0.05 then st.actors[9001].kills = st.actors[9001].kills + 1; end
end

return tracker;
