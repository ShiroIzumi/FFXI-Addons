--[[
    WhatsMyDamage - core/data.lua

    Static data: jobs and their bar colors, the battle message ids the
    tracker understands (from LandSandBoat's msg_basic.h), and the action
    categories of packet 0x028.
]]

local data = {};

data.JOBS = {
    'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG',
    'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN',
};

data.JOB_NAMES = {
    WAR = 'Warrior', MNK = 'Monk', WHM = 'White Mage', BLM = 'Black Mage', RDM = 'Red Mage', THF = 'Thief',
    PLD = 'Paladin', DRK = 'Dark Knight', BST = 'Beastmaster', BRD = 'Bard', RNG = 'Ranger', SAM = 'Samurai',
    NIN = 'Ninja', DRG = 'Dragoon', SMN = 'Summoner', BLU = 'Blue Mage', COR = 'Corsair', PUP = 'Puppetmaster',
    DNC = 'Dancer', SCH = 'Scholar', GEO = 'Geomancer', RUN = 'Rune Fencer',
};

-- One strong, distinct color per job (like Details' class colors); every
-- one can be changed in the settings.
data.JOB_COLORS = {
    WAR = { 0.78, 0.24, 0.20, 1 },  -- crimson
    MNK = { 0.90, 0.52, 0.12, 1 },  -- orange
    WHM = { 0.86, 0.86, 0.80, 1 },  -- ivory
    BLM = { 0.42, 0.22, 0.72, 1 },  -- deep violet
    RDM = { 0.80, 0.22, 0.42, 1 },  -- rose red
    THF = { 0.90, 0.80, 0.22, 1 },  -- gold
    PLD = { 0.62, 0.76, 0.92, 1 },  -- steel blue
    DRK = { 0.38, 0.14, 0.24, 1 },  -- dark wine
    BST = { 0.56, 0.38, 0.18, 1 },  -- brown
    BRD = { 0.94, 0.56, 0.72, 1 },  -- pink
    RNG = { 0.40, 0.66, 0.22, 1 },  -- moss green
    SAM = { 0.86, 0.36, 0.10, 1 },  -- burnt orange
    NIN = { 0.30, 0.34, 0.50, 1 },  -- slate
    DRG = { 0.20, 0.44, 0.86, 1 },  -- royal blue
    SMN = { 0.20, 0.74, 0.66, 1 },  -- teal
    BLU = { 0.16, 0.62, 0.90, 1 },  -- azure
    COR = { 0.70, 0.54, 0.30, 1 },  -- bronze
    PUP = { 0.62, 0.44, 0.36, 1 },  -- copper
    DNC = { 0.94, 0.42, 0.58, 1 },  -- coral
    SCH = { 0.54, 0.50, 0.86, 1 },  -- lavender
    GEO = { 0.30, 0.78, 0.42, 1 },  -- emerald
    RUN = { 0.62, 0.26, 0.12, 1 },  -- rust
};
data.PET_COLOR = { 0.55, 0.60, 0.66, 1 };      -- pets in their own rows
data.UNKNOWN_COLOR = { 0.50, 0.50, 0.55, 1 };  -- job not known yet

function data.job(id)
    id = tonumber(id) or 0;
    return data.JOBS[id] or '';
end

-- ============================================================================
-- Battle messages (0x028 action messages / 0x029)
-- ============================================================================

local function set(list)
    local t = {};
    for _, v in ipairs(list) do t[v] = true; end
    return t;
end

-- Damage done to the target (amount = action param).
data.DAMAGE = set({
    1,    -- melee hit
    2,    -- spell damage
    67,   -- melee critical
    77,   -- Sange
    110,  -- ability damage
    157,  -- Barrage
    185,  -- weapon skill / TP move damage
    187,  -- weapon skill / TP move HP drained
    197,  -- ability, resisted but damage
    227,  -- spell HP drained
    252,  -- spell, Magic Burst
    264,  -- target takes damage (AoE)
    274,  -- Magic Burst HP drained
    281,  -- HP drained
    317,  -- job ability damage
    352,  -- ranged hit
    353,  -- ranged critical
    576,  -- ranged hit squarely
    577,  -- ranged strikes true
});
data.CRIT = set({ 67, 353 });
data.MAGIC_BURST = set({ 252, 274 });

-- The attack missed (counts against accuracy).
data.MISS = set({ 15, 158, 188, 282, 324, 354 });

-- Blocked without a miss: shadows, anticipate, dodge, parry. Not counted
-- for accuracy; shown as "avoided" on damage taken.
data.AVOID = {
    [14] = 'shadows', [31] = 'shadows', [30] = 'anticipated', [32] = 'dodged', [70] = 'parried',
};

-- Spell resisted completely.
data.RESIST = set({ 85, 284, 655, 656 });

-- HP restored to the target.
data.HEAL = set({ 7, 24, 102, 103, 238, 263, 306, 318, 367 });

-- Additional effects on a hit that deal damage (enspells, added damage, drains).
data.ADD_DAMAGE = set({ 161, 163, 229 });

-- Skillchain damage, in the additional effect of the closing action.
data.SKILLCHAIN = {
    [288] = 'Light', [289] = 'Darkness', [290] = 'Gravitation', [291] = 'Fragmentation',
    [292] = 'Distortion', [293] = 'Fusion', [294] = 'Compression', [295] = 'Liquefaction',
    [296] = 'Induration', [297] = 'Reverberation', [298] = 'Transfixion', [299] = 'Scission',
    [300] = 'Detonation', [301] = 'Impaction', [302] = 'Cosmic Elucidation',
    [767] = 'Radiance', [768] = 'Umbra',
};

-- Spikes on the defender dealing damage to the attacker.
data.SPIKES = set({ 44 });
-- The defender countered / retaliated: damage to the attacker.
data.COUNTER = set({ 33, 536 });

-- 0x029: someone was defeated (target = who died / what was killed).
data.DEFEAT = set({ 6, 20, 97, 113, 406, 605, 646 });

-- ============================================================================
-- Action categories (0x028)
-- ============================================================================

data.CAT_MELEE = 1;
data.CAT_RANGED = 2;
data.CAT_WS = 3;
data.CAT_SPELL = 4;
data.CAT_ITEM = 5;
data.CAT_JA = 6;
data.CAT_MOB_TP = 11;
data.CAT_PET = 13;
data.CAT_DANCE = 14;
data.CAT_RUNE = 15;

-- Breakdown groups, in the order they are listed.
data.GROUPS = {
    { key = 'melee', label = 'Melee' },
    { key = 'ranged', label = 'Ranged' },
    { key = 'ws', label = 'Weapon Skills' },
    { key = 'sc', label = 'Skillchains' },
    { key = 'magic', label = 'Magic' },
    { key = 'ja', label = 'Abilities' },
    { key = 'item', label = 'Items' },
    { key = 'add', label = 'Additional Effects' },
    { key = 'spikes', label = 'Spikes & Counters' },
    { key = 'tp', label = 'TP Moves' },
};
data.GROUP_LABEL = {};
for _, g in ipairs(data.GROUPS) do data.GROUP_LABEL[g.key] = g.label; end

-- Modes a window can show.
data.MODES = {
    { key = 'damage', label = 'Damage Done', short = 'Damage' },
    { key = 'heal', label = 'Healing Done', short = 'Healing' },
    { key = 'taken', label = 'Damage Taken', short = 'Taken' },
};
data.MODE_LABEL = {};
for _, m in ipairs(data.MODES) do data.MODE_LABEL[m.key] = m.label; end

return data;
