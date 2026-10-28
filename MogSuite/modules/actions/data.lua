--[[
    MogSuite - modules/actions/data.lua

    Game data for the 75 era: job abilities, weapon skills, spell schools,
    elements, ninja tools, blood pacts and pet jobs.
]]

-- ============================================================================
-- Game data (75 era)
-- ============================================================================

JOB_SHORT = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG',
    'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH' };
JOB_NAMES = { 'Warrior', 'Monk', 'White Mage', 'Black Mage', 'Red Mage', 'Thief', 'Paladin',
    'Dark Knight', 'Beastmaster', 'Bard', 'Ranger', 'Samurai', 'Ninja', 'Dragoon', 'Summoner',
    'Blue Mage', 'Corsair', 'Puppetmaster', 'Dancer', 'Scholar' };

-- { name, level, kind }  kind: nil = job ability, 'sp' = two-hour,
-- 'merit' = merit ability, 'pet' = pet command (/pet), 'roll', 'shot', 'man'.
-- HorizonXI job abilities (from horizonffxi.wiki job pages, 2026-10-16).
-- Horizon is a 75-cap Chains of Promathia era+ server, so several later
-- abilities (Afflatus, Composure, Snarl, Elemental Siphon...) don't exist
-- and some levels / merits differ from retail. Changed entries carry a note
-- in HORIZON_NOTES below and show an "H" mark in the window.
JOB_ABILITIES = {
    [1] = { -- WAR
        { 'Mighty Strikes', 1, 'sp' }, { 'Provoke', 5 }, { 'Berserk', 15 }, { 'Defender', 25 },
        { 'Warcry', 35 }, { 'Aggressor', 45 }, { 'Retaliation', 50 },
    },
    [2] = { -- MNK
        { 'Hundred Fists', 1, 'sp' }, { 'Boost', 5 }, { 'Focus', 15 }, { 'Dodge', 25 }, { 'Chakra', 35 },
        { 'Chi Blast', 41 }, { 'Counterstance', 45 },
        { 'Mantra', 75, 'merit' }, { 'Formless Strikes', 75, 'merit' }, { 'Invigorate', 75, 'merit' }, { 'Penance', 75, 'merit' },
    },
    [3] = { -- WHM
        { 'Benediction', 1, 'sp' }, { 'Divine Seal', 15 }, { 'Devotion', 45 },
    },
    [4] = { -- BLM
        { 'Manafont', 1, 'sp' }, { 'Elemental Seal', 15 },
    },
    [5] = { -- RDM
        { 'Chainspell', 1, 'sp' }, { 'Convert', 40 },
    },
    [6] = { -- THF
        { 'Perfect Dodge', 1, 'sp' }, { 'Steal', 5 }, { 'Sneak Attack', 15 }, { 'Flee', 25 },
        { 'Trick Attack', 30 }, { 'Mug', 35 }, { 'Bully', 40 }, { 'Hide', 45 }, { 'Accomplice', 45 },
        { 'Collaborator', 45 },
        { "Assassin's Charge", 75, 'merit' }, { 'Feint', 75, 'merit' }, { 'Aura Steal', 75, 'merit' },
        { 'Oppressor', 75, 'merit' },
    },
    [7] = { -- PLD
        { 'Invincible', 1, 'sp' }, { 'Holy Circle', 5 }, { 'Shield Bash', 15 }, { 'Sentinel', 30 },
        { 'Cover', 35 }, { 'Chivalry', 45 }, { 'Rampart', 62 },
    },
    [8] = { -- DRK
        { 'Blood Weapon', 1, 'sp' }, { 'Arcane Circle', 5 }, { 'Last Resort', 15 }, { 'Weapon Bash', 20 },
        { 'Souleater', 30 },
        { 'Dark Seal', 75, 'merit' }, { 'Diabolic Eye', 75, 'merit' },
    },
    [9] = { -- BST
        { 'Familiar', 1, 'sp' }, { 'Charm', 1 }, { 'Gauge', 10 }, { 'Reward', 12 }, { 'Call Beast', 23 },
        { 'Tame', 30 },
        { 'Fight', 1, 'pet' }, { 'Heel', 10, 'pet' }, { 'Stay', 15, 'pet' }, { 'Sic', 25, 'pet' },
        { 'Ready', 25, 'pet' }, { 'Leave', 35, 'pet' },
        { 'Feral Howl', 75, 'merit' }, { 'Killer Instinct', 75, 'merit' },
    },
    [10] = { -- BRD
        { 'Soul Voice', 1, 'sp' },
        { 'Nightingale', 75, 'merit' }, { 'Troubadour', 75, 'merit' },
    },
    [11] = { -- RNG
        { 'Eagle Eye Shot', 1, 'sp' }, { 'Sharpshot', 1 }, { 'Scavenge', 10 }, { 'Camouflage', 20 },
        { 'Barrage', 30 }, { 'Shadowbind', 40 }, { 'Velocity Shot', 45 }, { 'Unlimited Shot', 51 },
    },
    [12] = { -- SAM
        { 'Meikyo Shisui', 1, 'sp' }, { 'Warding Circle', 5 }, { 'Third Eye', 15 }, { 'Hasso', 25 },
        { 'Meditate', 30 }, { 'Seigan', 35 },
        { 'Shikikoyo', 75, 'merit' }, { 'Shuuren', 75, 'merit' }, { 'Ikishoten', 75, 'merit' },
        { 'Overwhelm', 75, 'merit' },
    },
    [13] = { -- NIN
        { 'Mikage', 1, 'sp' }, { 'Yonin', 20 },
    },
    [14] = { -- DRG
        { 'Spirit Surge', 1, 'sp' }, { 'Call Wyvern', 1 }, { 'Dismiss', 1 }, { 'Ancient Circle', 5 }, { 'Jump', 10 },
        { 'Spirit Link', 25 }, { 'Steady Wing', 30 }, { 'High Jump', 35 }, { 'Super Jump', 50 },
        { 'Deep Breathing', 75, 'merit' }, { 'Angon', 75, 'merit' },
    },
    [15] = { -- SMN
        { 'Astral Flow', 1, 'sp' },
        { 'Assault', 1, 'pet' }, { 'Retreat', 1, 'pet' }, { 'Release', 1, 'pet' },
    },
    [16] = { -- BLU
        { 'Azure Lore', 1, 'sp' }, { 'Burst Affinity', 25 }, { 'Chain Affinity', 40 }, { 'Convergence', 45 },
        { 'Diffusion', 75, 'merit' },
    },
    [17] = { -- COR (roll levels are Horizon's)
        { 'Wild Card', 1, 'sp' }, { 'Double-Up', 5 }, { 'Random Deal', 50 },
        { 'Ninja Roll', 5, 'roll' }, { "Hunter's Roll", 8, 'roll' }, { 'Chaos Roll', 11, 'roll' },
        { "Magus's Roll", 14, 'roll' }, { "Healer's Roll", 17, 'roll' }, { 'Puppet Roll', 20, 'roll' },
        { 'Choral Roll', 23, 'roll' }, { "Monk's Roll", 26, 'roll' }, { 'Beast Roll', 31, 'roll' },
        { 'Samurai Roll', 34, 'roll' }, { "Gallant's Roll", 37, 'roll' }, { "Evoker's Roll", 40, 'roll' },
        { "Rogue's Roll", 43, 'roll' }, { "Warlock's Roll", 46, 'roll' }, { "Fighter's Roll", 49, 'roll' },
        { 'Drachen Roll', 52, 'roll' }, { "Wizard's Roll", 55, 'roll' }, { "Corsair's Roll", 75, 'roll' },
        { 'Fire Shot', 40, 'shot' }, { 'Ice Shot', 40, 'shot' }, { 'Wind Shot', 40, 'shot' },
        { 'Earth Shot', 40, 'shot' }, { 'Thunder Shot', 40, 'shot' }, { 'Water Shot', 40, 'shot' },
        { 'Light Shot', 40, 'shot' }, { 'Dark Shot', 40, 'shot' },
        { 'Snake Eye', 75, 'merit' }, { 'Fold', 75, 'merit' },
    },
    [18] = { -- PUP
        { 'Overdrive', 1, 'sp' }, { 'Activate', 1 }, { 'Repair', 15 },
        { 'Deploy', 1, 'pet' }, { 'Deactivate', 1, 'pet' }, { 'Retrieve', 10, 'pet' },
        { 'Fire Maneuver', 1, 'man' }, { 'Ice Maneuver', 1, 'man' }, { 'Wind Maneuver', 1, 'man' },
        { 'Earth Maneuver', 1, 'man' }, { 'Thunder Maneuver', 1, 'man' }, { 'Water Maneuver', 1, 'man' },
        { 'Light Maneuver', 1, 'man' }, { 'Dark Maneuver', 1, 'man' },
        { 'Role Reversal', 75, 'merit' }, { 'Ventriloquy', 75, 'merit' },
    },
};

-- Pet commands aimed at your target (the rest go on yourself / your pet).
PET_ENEMY = { Fight = true, Sic = true, Assault = true, Deploy = true };

KIND_BADGE = {
    ja = { 'JA', nil }, sp = { 'SP', { 1.00, 0.80, 0.32, 1.0 } }, merit = { 'MRT', { 0.95, 0.55, 0.80, 1.0 } },
    pet = { 'PET', { 0.45, 0.85, 0.55, 1.0 } }, roll = { 'ROLL', { 0.95, 0.75, 0.40, 1.0 } },
    shot = { 'QD', { 1.00, 0.58, 0.32, 1.0 } }, man = { 'MAN', { 0.40, 0.82, 0.86, 1.0 } },
    rage = { 'RAGE', { 0.95, 0.42, 0.36, 1.0 } }, ward = { 'WARD', { 0.40, 0.80, 0.90, 1.0 } },
    af = { 'AF', { 1.00, 0.80, 0.32, 1.0 } },
    trait = { 'TRT', { 0.62, 0.78, 0.95, 1.0 } },
};
HORIZON_MARK_COLOR = { 1.00, 0.78, 0.30, 1.0 };   -- the "H" (changed on Horizon) mark

SKILL_NAMES = {
    [1] = 'Hand-to-Hand', [2] = 'Dagger', [3] = 'Sword', [4] = 'Great Sword', [5] = 'Axe',
    [6] = 'Great Axe', [7] = 'Scythe', [8] = 'Polearm', [9] = 'Katana', [10] = 'Great Katana',
    [11] = 'Club', [12] = 'Staff', [25] = 'Archery', [26] = 'Marksmanship', [27] = 'Throwing',
};
SKILL_SHORT = {
    [1] = 'H2H', [2] = 'DAG', [3] = 'SWD', [4] = 'GS', [5] = 'AXE', [6] = 'GA', [7] = 'SCY',
    [8] = 'POL', [9] = 'KAT', [10] = 'GK', [11] = 'CLB', [12] = 'STF', [25] = 'ARC', [26] = 'MRK', [27] = 'THR',
};

-- { name, skill needed, tag }  tag: nil = learned at that skill,
-- 'quest' = weapon skill quest, 'relic' = relic weapon only. HorizonXI levels
-- (every weapon's first WS at skill 5; Starlight / Seraph Strike swapped).
-- Mythic weapon skills are not on Horizon and are not listed.
WS_DATA = {
    [1] = { { 'Combo', 5 }, { 'Shoulder Tackle', 40 }, { 'One Inch Punch', 75 }, { 'Backhand Blow', 100 },
        { 'Raging Fists', 125 }, { 'Spinning Attack', 150 }, { 'Howling Fist', 200 }, { 'Dragon Kick', 225 },
        { 'Asuran Fists', 250, 'quest' }, { 'Final Heaven', 0, 'relic' } },
    [2] = { { 'Wasp Sting', 5 }, { 'Gust Slash', 40 }, { 'Shadowstitch', 70 }, { 'Viper Bite', 100 },
        { 'Cyclone', 125 }, { 'Energy Steal', 150 }, { 'Energy Drain', 175 }, { 'Dancing Edge', 200 },
        { 'Shark Bite', 225 }, { 'Evisceration', 230, 'quest' }, { 'Mercy Stroke', 0, 'relic' } },
    [3] = { { 'Fast Blade', 5 }, { 'Burning Blade', 30 }, { 'Red Lotus Blade', 50 }, { 'Flat Blade', 75 },
        { 'Shining Blade', 100 }, { 'Seraph Blade', 125 }, { 'Circle Blade', 150 }, { 'Spirits Within', 175 },
        { 'Vorpal Blade', 200 }, { 'Swift Blade', 225 }, { 'Savage Blade', 240, 'quest' },
        { 'Knights of Round', 0, 'relic' } },
    [4] = { { 'Hard Slash', 5 }, { 'Power Slash', 30 }, { 'Frostbite', 70 }, { 'Freezebite', 100 },
        { 'Shockwave', 150 }, { 'Crescent Moon', 175 }, { 'Sickle Moon', 200 }, { 'Spinning Slash', 225 },
        { 'Ground Strike', 250, 'quest' }, { 'Scourge', 0, 'relic' } },
    [5] = { { 'Raging Axe', 5 }, { 'Smash Axe', 40 }, { 'Gale Axe', 70 }, { 'Avalanche Axe', 100 },
        { 'Spinning Axe', 150 }, { 'Rampage', 175 }, { 'Calamity', 200 }, { 'Mistral Axe', 225 },
        { 'Decimation', 240, 'quest' }, { 'Onslaught', 0, 'relic' } },
    [6] = { { 'Shield Break', 5 }, { 'Iron Tempest', 40 }, { 'Sturmwind', 70 }, { 'Armor Break', 100 },
        { 'Keen Edge', 150 }, { 'Weapon Break', 175 }, { 'Raging Rush', 200 }, { 'Full Break', 225 },
        { 'Steel Cyclone', 240, 'quest' }, { 'Metatron Torment', 0, 'relic' } },
    [7] = { { 'Slice', 5 }, { 'Dark Harvest', 30 }, { 'Shadow of Death', 70 }, { 'Nightmare Scythe', 100 },
        { 'Spinning Scythe', 125 }, { 'Vorpal Scythe', 150 }, { 'Guillotine', 200 }, { 'Cross Reaper', 225 },
        { 'Spiral Hell', 240, 'quest' }, { 'Catastrophe', 0, 'relic' } },
    [8] = { { 'Double Thrust', 5 }, { 'Thunder Thrust', 30 }, { 'Raiden Thrust', 70 }, { 'Leg Sweep', 100 },
        { 'Penta Thrust', 150 }, { 'Vorpal Thrust', 175 }, { 'Skewer', 200 }, { 'Wheeling Thrust', 225 },
        { 'Impulse Drive', 240, 'quest' }, { 'Geirskogul', 0, 'relic' } },
    [9] = { { 'Blade: Rin', 5 }, { 'Blade: Retsu', 30 }, { 'Blade: Teki', 70 }, { 'Blade: To', 100 },
        { 'Blade: Chi', 150 }, { 'Blade: Ei', 175 }, { 'Blade: Jin', 200 }, { 'Blade: Ten', 225 },
        { 'Blade: Ku', 250, 'quest' }, { 'Blade: Metsu', 0, 'relic' } },
    [10] = { { 'Tachi: Enpi', 5 }, { 'Tachi: Hobaku', 30 }, { 'Tachi: Goten', 70 }, { 'Tachi: Kagero', 100 },
        { 'Tachi: Jinpu', 150 }, { 'Tachi: Koki', 175 }, { 'Tachi: Yukikaze', 200 }, { 'Tachi: Gekko', 225 },
        { 'Tachi: Kasha', 250, 'quest' }, { 'Tachi: Kaiten', 0, 'relic' } },
    [11] = { { 'Shining Strike', 5 }, { 'Starlight', 40 }, { 'Brainshaker', 70 }, { 'Seraph Strike', 100 },
        { 'Moonlight', 125 }, { 'Skullbreaker', 150 }, { 'True Strike', 175 }, { 'Judgment', 200 },
        { 'Hexa Strike', 220 }, { 'Black Halo', 230, 'quest' }, { 'Randgrith', 0, 'relic' } },
    [12] = { { 'Heavy Swing', 5 }, { 'Rock Crusher', 40 }, { 'Earth Crusher', 70 }, { 'Starburst', 100 },
        { 'Sunburst', 150 }, { 'Shell Crusher', 175 }, { 'Full Swing', 200 }, { 'Spirit Taker', 215 },
        { 'Retribution', 230, 'quest' }, { 'Gate of Tartarus', 0, 'relic' } },
    [25] = { { 'Flaming Arrow', 5 }, { 'Piercing Arrow', 40 }, { 'Dulling Arrow', 80 }, { 'Sidewinder', 175 },
        { 'Blast Arrow', 200 }, { 'Arching Arrow', 225 }, { 'Empyreal Arrow', 250, 'quest' },
        { 'Namas Arrow', 0, 'relic' } },
    [26] = { { 'Hot Shot', 5 }, { 'Split Shot', 40 }, { 'Sniper Shot', 80 }, { 'Slug Shot', 175 },
        { 'Blast Shot', 200 }, { 'Heavy Shot', 225 }, { 'Detonator', 250, 'quest' }, { 'Coronach', 0, 'relic' } },
};

-- Spell schools (resource Type).
SCHOOLS = {
    { type = 1, key = 'white', label = 'White Magic' },
    { type = 2, key = 'black', label = 'Black Magic' },
    { type = 3, key = 'summon', label = 'Summoning' },
    { type = 4, key = 'ninjutsu', label = 'Ninjutsu' },
    { type = 5, key = 'song', label = 'Songs' },
    { type = 6, key = 'blue', label = 'Blue Magic' },
};
SCHOOL_OF = {};
for _, s in ipairs(SCHOOLS) do SCHOOL_OF[s.type] = s; end
BLUE_MAGIC_TYPE = 6;

-- Element colors (resource Element: 0 Fire .. 7 Dark).
ELEMENTS = {
    [0] = { 'Fire', { 0.95, 0.38, 0.25, 1.0 } },
    [1] = { 'Ice', { 0.55, 0.85, 1.00, 1.0 } },
    [2] = { 'Wind', { 0.45, 0.88, 0.45, 1.0 } },
    [3] = { 'Earth', { 0.85, 0.70, 0.35, 1.0 } },
    [4] = { 'Lightning', { 0.75, 0.55, 1.00, 1.0 } },
    [5] = { 'Water', { 0.35, 0.55, 1.00, 1.0 } },
    [6] = { 'Light', { 1.00, 0.97, 0.80, 1.0 } },
    [7] = { 'Dark', { 0.55, 0.40, 0.70, 1.0 } },
};
NO_ELEMENT = { 'None', { 0.60, 0.60, 0.65, 1.0 } };

-- Ninjutsu tools (by the start of the spell name).
NIN_TOOLS = {
    { 'Utsusemi', 'Shihei' }, { 'Katon', 'Uchitake' }, { 'Hyoton', 'Tsurara' }, { 'Huton', 'Kawahori-ogi' },
    { 'Doton', 'Makibishi' }, { 'Raiton', 'Hiraishin' }, { 'Suiton', 'Mizu-deppo' }, { 'Tonko', 'Shinobi-tabi' },
    { 'Kurayami', 'Sairui-ran' }, { 'Hojo', 'Kaginawa' }, { 'Jubaku', 'Jusatsu' }, { 'Dokumori', 'Kodoku' },
    { 'Monomi', 'Sanjaku-tenugui' },
};

-- Blood pacts by avatar (75 era, SMN level).
-- { name, level, 'rage' | 'ward', tag }  tag: nil, 'merit' (merit pact),
-- 'af' (only while Astral Flow is up).
BLOOD_PACTS = {
    -- HorizonXI levels (horizonffxi.wiki Summoner page). The level 75 pacts
    -- (tag 'merit') come from a solo avatar trial on Horizon, not merits.
    Carbuncle = {
        { 'Healing Ruby', 1, 'ward' }, { 'Poison Nails', 5, 'rage' }, { 'Shining Ruby', 24, 'ward' },
        { 'Glittering Ruby', 44, 'ward' }, { 'Meteorite', 55, 'rage' }, { 'Healing Ruby II', 65, 'ward' },
        { 'Searing Light', 1, 'rage', 'af' },
    },
    Fenrir = {
        { 'Moonlit Charge', 5, 'rage' }, { 'Crescent Fang', 10, 'rage' }, { 'Lunar Cry', 21, 'ward' },
        { 'Lunar Roar', 32, 'ward' }, { 'Ecliptic Howl', 43, 'ward' }, { 'Ecliptic Growl', 54, 'ward' },
        { 'Eclipse Bite', 65, 'rage' }, { 'Howling Moon', 1, 'rage', 'af' },
    },
    Ifrit = {
        { 'Punch', 1, 'rage' }, { 'Fire II', 10, 'rage' }, { 'Burning Strike', 23, 'rage' },
        { 'Double Punch', 30, 'rage' }, { 'Crimson Howl', 39, 'ward' }, { 'Fire IV', 60, 'rage' },
        { 'Flaming Crush', 70, 'rage' }, { 'Meteor Strike', 75, 'rage', 'merit' }, { 'Inferno', 1, 'rage', 'af' },
    },
    Titan = {
        { 'Rock Throw', 1, 'rage' }, { 'Stone II', 10, 'rage' }, { 'Rock Buster', 21, 'rage' },
        { 'Megalith Throw', 35, 'rage' }, { 'Earthen Ward', 46, 'ward' }, { 'Stone IV', 60, 'rage' },
        { 'Mountain Buster', 70, 'rage' }, { 'Geocrush', 75, 'rage', 'merit' }, { 'Earthen Fury', 1, 'rage', 'af' },
    },
    Leviathan = {
        { 'Barracuda Dive', 1, 'rage' }, { 'Water II', 10, 'rage' }, { 'Tail Whip', 26, 'rage' },
        { 'Slowga', 33, 'ward' }, { 'Spring Water', 47, 'ward' }, { 'Water IV', 60, 'rage' },
        { 'Spinning Dive', 70, 'rage' }, { 'Grand Fall', 75, 'rage', 'merit' }, { 'Tidal Wave', 1, 'rage', 'af' },
    },
    Garuda = {
        { 'Claw', 1, 'rage' }, { 'Aero II', 10, 'rage' }, { 'Aerial Armor', 25, 'ward' },
        { 'Whispering Wind', 38, 'ward' }, { 'Hastega', 48, 'ward' }, { 'Aero IV', 60, 'rage' },
        { 'Predator Claws', 70, 'rage' }, { 'Wind Blade', 75, 'rage', 'merit' }, { 'Aerial Blast', 1, 'rage', 'af' },
    },
    Shiva = {
        { 'Axe Kick', 1, 'rage' }, { 'Blizzard II', 10, 'rage' }, { 'Frost Armor', 28, 'ward' },
        { 'Sleepga', 39, 'ward' }, { 'Double Slap', 50, 'rage' }, { 'Blizzard IV', 60, 'rage' },
        { 'Rush', 70, 'rage' }, { 'Heavenly Strike', 75, 'rage', 'merit' }, { 'Diamond Dust', 1, 'rage', 'af' },
    },
    Ramuh = {
        { 'Shock Strike', 1, 'rage' }, { 'Thunder II', 10, 'rage' }, { 'Thunderspark', 19, 'rage' },
        { 'Rolling Thunder', 31, 'ward' }, { 'Lightning Armor', 42, 'ward' }, { 'Thunder IV', 60, 'rage' },
        { 'Chaotic Strike', 70, 'rage' }, { 'Thunderstorm', 75, 'rage', 'merit' }, { 'Judgment Bolt', 1, 'rage', 'af' },
    },
    Diabolos = {
        { 'Camisado', 1, 'rage' }, { 'Somnolence', 20, 'rage' }, { 'Nightmare', 29, 'ward' },
        { 'Ultimate Terror', 37, 'ward' }, { 'Noctoshield', 49, 'ward' }, { 'Dream Shroud', 56, 'ward' },
        { 'Nether Blast', 65, 'rage' }, { 'Ruinous Omen', 1, 'rage', 'af' },
    },
};
SPIRITS = {
    ['Fire Spirit'] = true, ['Ice Spirit'] = true, ['Air Spirit'] = true, ['Earth Spirit'] = true,
    ['Thunder Spirit'] = true, ['Water Spirit'] = true, ['Light Spirit'] = true, ['Dark Spirit'] = true,
};
ASTRAL_FLOW_BUFF = 55;
SMN_JOB = 15;
BST_JOB, DRG_JOB, PUP_JOB = 9, 14, 18;

-- Pet jobs and their tabs. sub = the support job can use a pet too.
-- abilities = which of the job's abilities go on the tab (nil = all);
-- pet commands always do.
PET_JOBS = {
    [SMN_JOB] = { tab = 'summons', label = 'Summons', sub = true, kind = 'Avatar' },
    [DRG_JOB] = { tab = 'wyvern', label = 'Wyvern', sub = false, kind = 'Wyvern',
        abilities = { ['Spirit Surge'] = true, ['Call Wyvern'] = true, ['Dismiss'] = true, ['Spirit Link'] = true,
            ['Steady Wing'] = true, ['Deep Breathing'] = true } },
    [PUP_JOB] = { tab = 'automaton', label = 'Automaton', sub = true, kind = 'Automaton' },
    [BST_JOB] = { tab = 'beast', label = 'Beast', sub = true, kind = 'Pet',
        abilities = { ['Familiar'] = true, ['Charm'] = true, ['Gauge'] = true, ['Reward'] = true, ['Call Beast'] = true,
            ['Feral Howl'] = true, ['Killer Instinct'] = true } },
};

-- Is this pet job's tab available to you (main job, or support job when allowed)?
function pet_job_active(me, job)
    local info = PET_JOBS[job];
    if info == nil or me == nil then return false; end
    if me.job == job then return true; end
    return me.sub == job and info.sub == true;
end

-- Summons HorizonXI doesn't have: never listed.
NOT_ON_SERVER = {
    ['Alexander'] = true, ['Atomos'] = true, ['Odin'] = true, ['Siren'] = true, ['Cait Sith'] = true,
};

-- ============================================================================
-- Job traits (HorizonXI, horizonffxi.wiki job pages, 2026-10-16)
-- { name, level }  (merit traits use level 75 and 'merit')
-- Blue Mage traits come from set spells, so BLU has none here.
-- ============================================================================
JOB_TRAITS = {
    [1] = { { 'Resist Virus', 5 }, { 'Defense Bonus', 10 }, { 'Double Attack', 25 }, { 'Attack Bonus', 30 },
        { 'Resist Virus II', 35 }, { 'Resist Virus III', 55 }, { 'Resist Virus IV', 70 }, { 'Shield Mastery', 75 } },
    [2] = { { 'Martial Arts', 1 }, { 'Subtle Blow', 5 }, { 'Counter', 10 }, { 'Max HP Boost', 15 }, { 'Martial Arts II', 16 },
        { 'Max HP Boost II', 25 }, { 'Subtle Blow II', 25 }, { 'Martial Arts III', 31 }, { 'Max HP Boost III', 35 },
        { 'Max HP Boost IV', 45 }, { 'Subtle Blow III', 45 }, { 'Martial Arts IV', 46 }, { 'Kick Attacks', 51 },
        { 'Max HP Boost V', 55 }, { 'Martial Arts V', 61 }, { 'Max HP Boost VI', 65 }, { 'Subtle Blow IV', 65 },
        { 'Kick Attacks II', 71 }, { 'Martial Arts VI', 75 } },
    [3] = { { 'Magic Defense Bonus', 10 }, { 'Clear Mind', 15 }, { 'Auto Regen', 25 }, { 'Magic Defense Bonus II', 30 },
        { 'Clear Mind II', 35 }, { 'Clear Mind III', 45 }, { 'Divine Veil', 50 }, { 'Magic Defense Bonus III', 50 },
        { 'Clear Mind IV', 55 }, { 'Clear Mind V', 65 }, { 'Magic Defense Bonus IV', 70 }, { 'Clear Mind VI', 75 } },
    [4] = { { 'Magic Attack Bonus', 10 }, { 'Clear Mind', 15 }, { 'Conserve MP', 20 }, { 'Clear Mind II', 30 },
        { 'Magic Attack Bonus II', 30 }, { 'Clear Mind III', 45 }, { 'Magic Attack Bonus III', 50 }, { 'Clear Mind IV', 60 },
        { 'Magic Attack Bonus IV', 70 }, { 'Clear Mind V', 75 } },
    [5] = { { 'Resist Petrify', 10 }, { 'Fast Cast', 15 }, { 'Magic Attack Bonus', 20 }, { 'Magic Defense Bonus', 25 },
        { 'Resist Petrify II', 30 }, { 'Clear Mind', 31 }, { 'Fast Cast II', 35 }, { 'Magic Attack Bonus II', 40 },
        { 'Magic Defense Bonus II', 45 }, { 'Resist Petrify III', 50 }, { 'Clear Mind II', 53 }, { 'Fast Cast III', 55 },
        { 'Magic Attack Bonus III', 60 }, { 'Resist Petrify IV', 70 }, { 'Clear Mind III', 75 } },
    [6] = { { 'Gilfinder', 5 }, { 'Evasion Bonus', 10 }, { 'Treasure Hunter', 15 }, { 'Resist Gravity', 20 },
        { 'Evasion Bonus II', 30 }, { 'Triple Attack', 30 }, { 'Resist Gravity II', 40 }, { 'Treasure Hunter II', 45 },
        { 'Evasion Bonus III', 50 }, { 'Assassin', 50 }, { 'Resist Gravity III', 60 }, { 'Evasion Bonus IV', 70 },
        { 'Resist Gravity IV', 75 } },
    [7] = { { 'Undead Killer', 5 }, { 'Defense Bonus', 10 }, { 'Resist Sleep', 20 }, { 'Shield Mastery', 25 },
        { 'Auto Refresh', 25 }, { 'Defense Bonus II', 30 }, { 'Resist Sleep II', 40 }, { 'Defense Bonus III', 50 },
        { 'Shield Mastery II', 50 }, { 'Resist Sleep III', 60 }, { 'Defense Bonus IV', 70 }, { 'Shield Mastery III', 75 } },
    [8] = { { 'Attack Bonus', 10 }, { 'Desperate Blows', 15 }, { 'Resist Paralyze', 20 }, { 'Arcana Killer', 25 },
        { 'Attack Bonus II', 30 }, { 'Desperate Blows II', 30 }, { 'Resist Paralyze II', 40 }, { 'Desperate Blows III', 40 },
        { 'Attack Bonus III', 50 }, { 'Resist Paralyze III', 60 }, { 'Attack Bonus IV', 70 }, { 'Resist Paralyze IV', 75 },
        { 'Muted Soul', 75, 'merit' } },
    [9] = { { 'Wide Scan', 1 }, { 'Vermin Killer', 10 }, { 'Resist Slow', 15 }, { 'Bird Killer', 20 }, { 'Wide Scan II', 20 },
        { 'Amorph Killer', 30 }, { 'Lizard Killer', 40 }, { 'Wide Scan III', 40 }, { 'Aquan Killer', 50 },
        { 'Plantoid Killer', 60 }, { 'Wide Scan IV', 60 }, { 'Beast Killer', 70 },
        { 'Tandem Strike', 75, 'merit' }, { 'Beast Healer', 75, 'merit' } },
    [10] = { { 'Resist Silence', 5 }, { 'Resist Silence II', 25 }, { 'Resist Silence III', 45 }, { 'Resist Silence IV', 65 } },
    [11] = { { 'Wide Scan', 1 }, { 'Alertness', 5 }, { 'Accuracy Bonus', 10 }, { 'Rapid Shot', 15 }, { 'Wide Scan II', 20 },
        { 'Resist Poison', 20 }, { 'Accuracy Bonus II', 30 }, { 'Resist Poison II', 40 }, { 'Wide Scan III', 40 },
        { 'Accuracy Bonus III', 50 }, { 'Resist Poison III', 60 }, { 'Wide Scan IV', 60 }, { 'Accuracy Bonus IV', 70 },
        { 'Dead Aim', 75 } },
    [12] = { { 'Resist Blind', 5 }, { 'Store TP', 10 }, { 'Zanshin', 20 }, { 'Resist Blind II', 25 }, { 'Store TP II', 30 },
        { 'Zanshin II', 35 }, { 'Demon Killer', 40 }, { 'Resist Blind III', 45 }, { 'Store TP III', 50 }, { 'Zanshin III', 50 },
        { 'Resist Blind IV', 65 }, { 'Store TP IV', 70 }, { 'Zanshin IV', 75 } },
    [13] = { { 'Stealth', 5 }, { 'Dual Wield', 10 }, { 'Resist Bind', 10 }, { 'Subtle Blow', 15 }, { 'Dual Wield II', 25 },
        { 'Resist Bind II', 30 }, { 'Subtle Blow II', 30 }, { 'Ninja Tool Expertise', 40 }, { 'Dual Wield III', 45 },
        { 'Subtle Blow III', 45 }, { 'Resist Bind III', 50 }, { 'Subtle Blow IV', 60 }, { 'Ninja Tool Expertise II', 60 },
        { 'Dual Wield IV', 65 }, { 'Resist Bind IV', 70 }, { 'Subtle Blow V', 75 }, { 'Ninja Tool Expertise III', 75 } },
    [14] = { { 'Attack Bonus', 10 }, { 'Strafe', 20 }, { 'Dragon Killer', 25 }, { 'Accuracy Bonus', 30 }, { 'Strafe II', 40 },
        { 'Strafe III', 60 }, { 'Empathy', 75, 'merit' } },
    [15] = { { 'Max MP Boost', 10 }, { 'Clear Mind', 15 }, { 'Resist Slow', 20 }, { 'Auto Refresh', 25 }, { 'Clear Mind II', 30 },
        { 'Max MP Boost II', 30 }, { 'Resist Slow II', 40 }, { 'Clear Mind III', 45 }, { 'Max MP Boost III', 50 },
        { 'Clear Mind IV', 60 }, { 'Resist Slow III', 60 }, { 'Clear Mind V', 70 }, { 'Max MP Boost IV', 70 },
        { 'Resist Slow IV', 75 } },
    [17] = { { 'Resist Paralyze', 5 }, { 'Rapid Shot', 15 }, { 'Resist Paralyze II', 25 }, { 'Resist Paralyze III', 45 },
        { 'Resist Paralyze IV', 65 }, { 'Winning Streak', 75, 'merit' }, { 'Loaded Deck', 75, 'merit' } },
};

-- ============================================================================
-- Spell levels Horizon changed (the game's own data still has retail levels).
-- [spell name] = { [job id] = level }
-- ============================================================================
SPELL_LEVEL_FIX = {
    ['Reraise'] = { [3] = 25 },
    ['Enlight'] = { [7] = 40 },
    ['Katon: Ichi'] = { [13] = 15 }, ['Hyoton: Ichi'] = { [13] = 15 }, ['Huton: Ichi'] = { [13] = 15 },
    ['Doton: Ichi'] = { [13] = 15 }, ['Raiton: Ichi'] = { [13] = 15 }, ['Suiton: Ichi'] = { [13] = 15 },
    ['Occultation'] = { [16] = 38 },
    ['Empty Thrash'] = { [16] = 34 },
};

-- ============================================================================
-- What Horizon changed, shown as an "H" mark with this text on hover.
-- Keyed by name (abilities, traits, spells, weapon skills, blood pacts).
-- Source: horizonffxi.wiki "Horizon Changes" and the job pages (2026-10-16).
-- ============================================================================
HORIZON_NOTES = {
    -- Job abilities
    ['Defender'] = 'Enmity loss from damage reduced 25%; +10% shield block (WAR main).',
    ['Provoke'] = '+250 enmity with Defender up on WAR main (+180 as support).',
    ['Retaliation'] = 'Level 50 (was 60).',
    ['Boost'] = '+20% attack for one attack / weapon skill, 30s recast.',
    ['Focus'] = 'Level 15 (was 25), 3 min.',
    ['Dodge'] = 'Level 25, 3 min.',
    ['Chakra'] = '2 min recast (was 3); also removes several ailments.',
    ['Chi Blast'] = 'Also removes one buff from the target.',
    ['Devotion'] = 'Level 45 job ability (was a merit).',
    ['Convert'] = 'Recast 13 min (was 10).',
    ['Perfect Dodge'] = 'Also Accuracy / Ranged Accuracy +999.',
    ['Mug'] = 'Recast 10 min (was 15); +5% crit rate on the target for 30s.',
    ['Bully'] = 'Level 40 (was 93), 1 min recast; status bolt effect on mobs.',
    ['Accomplice'] = 'Level 45 (was 65); works on alliance; own recast.',
    ['Collaborator'] = 'Level 45 (was 65); alliance; 5 min recast; moves 50% of your enmity.',
    ['Holy Circle'] = 'More damage vs undead for the party; 10 min recast.',
    ['Cover'] = 'Usable on alliance members.',
    ['Chivalry'] = 'Level 45 job ability (was a merit); 15 min recast.',
    ['Rampart'] = 'Changed on Horizon (see wiki).',
    ['Arcane Circle'] = 'More damage vs arcana, magic aggro protection; 10 min recast.',
    ['Last Resort'] = 'Lasts 60s (was 30).',
    ['Souleater'] = 'Recast 5 min (was 6).',
    ['Call Beast'] = 'NQ familiars last 30 min, HQ 60 min; pets stay through zoning.',
    ['Ready'] = 'Charges every 45s (was 60).',
    ['Eagle Eye Shot'] = 'Always hits.',
    ['Scavenge'] = 'Recovers spent ammo (2013 version).',
    ['Camouflage'] = 'Enmity reduction on your next attack.',
    ['Velocity Shot'] = 'Available on Horizon (was Wings of the Goddess).',
    ['Hasso'] = 'Available on Horizon (was Treasures of Aht Urhgan).',
    ['Seigan'] = 'Available on Horizon (was Treasures of Aht Urhgan).',
    ['Warding Circle'] = 'More damage vs demons for the party.',
    ['Shuuren'] = 'Horizon merit ability.',
    ['Mikage'] = 'Replaces Mijin Gakure.',
    ['Yonin'] = 'Level 20 (was 40); -15% attack, +enmity, Utsusemi recast -10s.',
    ['Ancient Circle'] = 'More damage vs dragons; 10 min recast.',
    ['Steady Wing'] = 'Level 30 (was 95).',
    ['Convergence'] = 'Level 45 job ability (was a merit).',
    ['Quick Draw'] = '2 charges (was 1).',
    ['Double-Up'] = 'Phantom Roll +1 gear must be worn during Double-Up for the bonus.',
    ['Ninja Roll'] = 'Level 5 on Horizon.', ["Hunter's Roll"] = 'Horizon roll level.', ['Chaos Roll'] = 'Flat attack (not %).',
    ["Magus's Roll"] = 'Horizon roll level.', ["Healer's Roll"] = 'Boosts MP recovered while healing (not Cure potency).',
    ['Puppet Roll'] = 'Horizon roll level.', ['Choral Roll'] = 'Horizon roll level.', ["Monk's Roll"] = 'Horizon roll level.',
    ['Beast Roll'] = 'Horizon roll level.', ['Samurai Roll'] = 'Horizon roll level.', ["Gallant's Roll"] = 'Flat defense (not %).',
    ['Drachen Roll'] = 'Horizon roll level.', ["Wizard's Roll"] = 'Horizon roll level.', ["Corsair's Roll"] = 'Level 75 (was 5).',
    -- Spells
    ['Reraise'] = 'WHM level 25 (was 33).',
    ['Enlight'] = 'Paladins learn it at level 40.',
    ['Protectra V'] = 'From a scroll (not merits).', ['Shellra V'] = 'From a scroll (not merits).',
    ['Slow II'] = 'Learnable from a scroll.', ['Paralyze II'] = 'Learnable from a scroll.', ['Dia III'] = 'Learnable from a scroll.',
    ['Bio III'] = 'Learnable from a scroll.', ['Haste'] = 'Recast 18s (was 20).', ['Refresh'] = '50 MP (was 40), recast 16s.',
    ['Katon: Ichi'] = 'Usable from level 15.', ['Hyoton: Ichi'] = 'Usable from level 15.', ['Huton: Ichi'] = 'Usable from level 15.',
    ['Doton: Ichi'] = 'Usable from level 15.', ['Raiton: Ichi'] = 'Usable from level 15.', ['Suiton: Ichi'] = 'Usable from level 15.',
    ['Utsusemi: Ichi'] = 'Recast +15s.', ['Utsusemi: Ni'] = 'Recast +15s.',
    ['Occultation'] = 'Level 38 (was 88), needs 86 Blue Magic skill.',
    ['Empty Thrash'] = 'Level 34 (was 87); trait Max HP Boost.',
    ['Refueling'] = '15% Haste (was 10%).', ['Blood Saber'] = '3 set points; Auto Refresh trait points.',
    ['Digest'] = 'Conserve MP trait points.', ['Metallic Body'] = '3 set points; Conserve MP trait points.',
    ['Blank Gaze'] = 'Magic Attack Bonus trait points.', ['Magic Hammer'] = 'No MAB trait; restores MP equal to damage.',
    -- Weapon skills
    ['Flaming Arrow'] = 'Skill 5 (was 10); hybrid.', ['Blast Arrow'] = 'Chance to stun.', ['Empyreal Arrow'] = '2.0x attack.',
    ['Piercing Arrow'] = 'Skillchain: Induration.', ['Namas Arrow'] = 'Aftermath: no ammo cost.',
    ['Avalanche Axe'] = 'Skillchain: Induration.', ['Calamity'] = 'fTP changed.', ['Decimation'] = 'Ignores defense with TP.',
    ['Gale Axe'] = 'Can inflict Weight.', ['Onslaught'] = '5 hits, STR.', ['Raging Axe'] = 'Skill 5 (was 10).',
    ['Randgrith'] = '2 hits; aftermath +5% Haste.', ['Seraph Strike'] = 'Skill 100 (was 40); Scission; hybrid.',
    ['Shining Strike'] = 'Skill 5 (was 10); Transfixion; hybrid.', ['Starlight'] = 'Skill 40 (was 100); Paladins can use it.',
    ['Energy Drain'] = 'Drains haste and deals damage.', ['Evisceration'] = '+30% CHR.', ['Gust Slash'] = 'Hybrid.',
    ['Shadowstitch'] = 'Skillchain: Reverberation.', ['Shark Bite'] = '30% AGI.', ['Wasp Sting'] = 'Much more damage.',
    ['Metatron Torment'] = 'Defense Down 120s.', ['Raging Rush'] = 'Can crit.', ['Shield Break'] = 'Skill 5 (was 10).',
    ['Tachi: Enpi'] = 'Skill 5 (was 10).', ['Tachi: Gekko'] = 'Higher fTP.', ['Tachi: Kasha'] = 'Higher fTP.',
    ['Tachi: Yukikaze'] = 'Higher fTP.', ['Tachi: Goten'] = 'Hybrid.', ['Tachi: Jinpu'] = 'Hybrid.',
    ['Tachi: Kagero'] = 'Hybrid.', ['Tachi: Koki'] = 'Hybrid.',
    ['Freezebite'] = '2 hits, hybrid.', ['Frostbite'] = 'Hybrid.', ['Hard Slash'] = 'Skill 5 (was 10).',
    ['Scourge'] = 'STR / MND; can crit; aftermath +crit damage.',
    ['Dragon Kick'] = '2 hits; VIT.', ['Final Heaven'] = 'VIT 40% + STR 40%.', ['Howling Fist'] = '2 hits; 50% STR; 1.5x attack.',
    ['Blade: Chi'] = 'Hybrid.', ['Blade: Ei'] = 'Hybrid.', ['Blade: Teki'] = 'Hybrid.', ['Blade: To'] = 'Hybrid.',
    ['Blast Shot'] = 'Chance to stun.', ['Hot Shot'] = 'Skill 5 (was 10); hybrid.',
    ['Double Thrust'] = 'Skill 5 (was 10).', ['Geirskogul'] = '2 hits; aftermath heals wyvern.',
    ['Impulse Drive'] = 'Higher fTP.', ['Raiden Thrust'] = 'Hybrid.', ['Skewer'] = 'Stronger; Induration.',
    ['Thunder Thrust'] = 'Hybrid.', ['Wheeling Thrust'] = 'Higher TP multiplier.',
    ['Catastrophe'] = 'STR (not AGI).', ['Dark Harvest'] = 'Hybrid; Compression.', ['Nightmare Scythe'] = 'Chance of Terror.',
    ['Shadow of Death'] = 'Hybrid.', ['Slice'] = 'Skill 5 (was 10).', ['Spiral Hell'] = 'Gravitation / Compression.',
    ['Vorpal Scythe'] = 'Buffed.',
    ['Gate of Tartarus'] = 'Dark magical; INT.', ['Heavy Swing'] = 'Skill 5 (was 10).', ['Retribution'] = '1.5x attack.',
    ['Starburst'] = 'Skillchain: Transfixion.', ['Sunburst'] = 'Skillchain: Transfixion.',
    ['Burning Blade'] = 'Hybrid.', ['Red Lotus Blade'] = 'Hybrid.', ['Seraph Blade'] = 'Hybrid.', ['Shining Blade'] = 'Hybrid.',
    ['Swift Blade'] = 'Crit / accuracy effects swapped.',
    -- Blood pacts
    ['Crimson Howl'] = 'Level 39; lasts 3 min.', ['Whispering Wind'] = 'Level 38; also removes ailments.',
    ['Hastega'] = 'Same strength as Haste (they overwrite); 129 MP.', ['Spring Water'] = 'Horizon pact: AoE 2 MP/tick refresh.',
    ['Spinning Dive'] = 'Level 70 on Horizon.', ['Shining Ruby'] = 'Can overwrite itself.',
    ['Ecliptic Growl'] = 'Level 54 (swapped with Howl).', ['Ecliptic Howl'] = 'Level 43 (swapped with Growl).',
    ['Meteor Strike'] = 'From a level 75 solo avatar trial (not merits).', ['Geocrush'] = 'From a level 75 solo avatar trial (not merits).',
    ['Grand Fall'] = 'From a level 75 solo avatar trial (not merits).', ['Wind Blade'] = 'From a level 75 solo avatar trial (not merits).',
    ['Heavenly Strike'] = 'From a level 75 solo avatar trial (not merits).', ['Thunderstorm'] = 'From a level 75 solo avatar trial (not merits).',
};

-- Trait notes per job (trait names repeat across jobs).
HORIZON_TRAIT_NOTES = {
    [1] = { ['Shield Mastery'] = 'Warrior gets Shield Mastery at 75 on Horizon.' },
    [3] = { ['Magic Defense Bonus II'] = 'Horizon level.', ['Clear Mind III'] = 'Higher tiers earlier on Horizon.',
        ['Clear Mind IV'] = 'Higher tiers earlier on Horizon.', ['Clear Mind V'] = 'Higher tiers earlier on Horizon.',
        ['Clear Mind VI'] = 'Higher tiers earlier on Horizon.', ['Divine Veil'] = 'With Divine Seal, can double the next Regen.' },
    [5] = { ['Magic Attack Bonus III'] = 'Horizon level.' },
    [6] = { ['Triple Attack'] = 'Level 30 (was 55).', ['Assassin'] = 'Level 50 (was 60).' },
    [7] = { ['Shield Mastery'] = 'Available early on Horizon (was Treasures of Aht Urhgan).', ['Auto Refresh'] = 'Level 25 (was 35).' },
    [8] = { ['Desperate Blows'] = 'Available on Horizon.', ['Desperate Blows II'] = 'Available on Horizon.',
        ['Desperate Blows III'] = 'Available on Horizon.' },
    [9] = { ['Tandem Strike'] = 'Horizon merit.' },
    [11] = { ['Dead Aim'] = 'Level 75 trait on Horizon.' },
    [12] = { ['Zanshin'] = 'No Hasso / Seigan bonus.' },
    [13] = { ['Ninja Tool Expertise'] = 'Trait at level 40.', ['Ninja Tool Expertise II'] = 'Horizon trait.',
        ['Ninja Tool Expertise III'] = 'Horizon trait.' },
};

function horizon_note(row)
    if row == nil then return nil; end
    if row.k == 'trait' then
        local t = HORIZON_TRAIT_NOTES[row.job or 0];
        return t and t[row.name] or nil;
    end
    return HORIZON_NOTES[row.name];
end

-- ============================================================================
-- 1.6.9: what each job trait does, for the hover / details.
-- desc = what it does; v = the value per tier (I, II, III ...), fmt = how a
-- tier's value reads ('%d' = that tier's value). Values are LandSandBoat's
-- (the server HorizonXI is built on); Horizon can differ.
-- ============================================================================
local T4 = { 10, 22, 35, 48 };
TRAIT_INFO = {
    ['Accuracy Bonus'] = { desc = 'Raises your Accuracy and Ranged Accuracy.', v = T4, fmt = '+%d Accuracy and Ranged Accuracy' },
    ['Attack Bonus'] = { desc = 'Raises your Attack and Ranged Attack.', v = T4, fmt = '+%d Attack and Ranged Attack' },
    ['Defense Bonus'] = { desc = 'Raises your Defense.', v = T4, fmt = '+%d Defense' },
    ['Evasion Bonus'] = { desc = 'Raises your Evasion.', v = T4, fmt = '+%d Evasion' },
    ['Magic Attack Bonus'] = { desc = 'Your offensive spells hit harder.', v = { 20, 24, 28, 32 }, fmt = '+%d Magic Attack Bonus' },
    ['Magic Defense Bonus'] = { desc = 'You take less damage from enemy spells.', v = { 10, 12, 14, 16 }, fmt = '+%d Magic Defense Bonus' },
    ['Double Attack'] = { desc = 'Sometimes you swing twice in one attack round.', v = { 10 }, fmt = '%d%% chance to attack twice' },
    ['Triple Attack'] = { desc = 'Sometimes you swing three times in one attack round.', v = { 5 }, fmt = '%d%% chance to attack three times' },
    ['Martial Arts'] = { desc = 'Your hand-to-hand attacks come faster (lower attack delay).', v = { 80, 100, 120, 140, 160, 180 }, fmt = 'Hand-to-hand delay -%d' },
    ['Subtle Blow'] = { desc = 'The enemy gains less TP when you hit it, so it uses its TP moves less often.', v = { 5, 10, 15, 20, 25 }, fmt = 'Subtle Blow +%d: the enemy gains %d%% less TP from your hits' },
    ['Counter'] = { desc = 'Sometimes you counterattack when an enemy attacks you.', v = { 10 }, fmt = '%d%% chance to counter' },
    ['Kick Attacks'] = { desc = 'Sometimes you add a kick to your attack round.', v = { 10, 12 }, fmt = '%d%% chance of a kick attack' },
    ['Max HP Boost'] = { desc = 'Raises your maximum HP.', v = { 30, 60, 120, 180, 240, 280 }, fmt = '+%d max HP' },
    ['Max MP Boost'] = { desc = 'Raises your maximum MP.', v = { 10, 20, 40, 60 }, fmt = '+%d max MP' },
    ['Clear Mind'] = { desc = 'You recover more MP while resting (/heal).', v = { 3, 6, 9, 12, 15 }, fmt = '+%d MP per tick while resting' },
    ['Auto Regen'] = { desc = 'You slowly regain HP all the time.', v = { 1 }, fmt = '+%d HP every 3 seconds' },
    ['Auto Refresh'] = { desc = 'You slowly regain MP all the time.', v = { 1 }, fmt = '+%d MP every 3 seconds' },
    ['Conserve MP'] = { desc = 'Sometimes a spell costs less MP.', v = { 25 }, fmt = 'About a %d%% chance to save MP on a spell' },
    ['Fast Cast'] = { desc = 'Your spells take less time to cast.', v = { 10, 15, 20 }, fmt = 'Casting time -%d%%' },
    ['Store TP'] = { desc = 'You gain more TP from each of your hits.', v = { 10, 15, 20, 25 }, fmt = '+%d%% TP per hit' },
    ['Zanshin'] = { desc = 'When you miss, you sometimes get another attack right away.', v = { 15, 25, 35, 45 }, fmt = '%d%% chance of another attack after a miss' },
    ['Dual Wield'] = { desc = 'Lets you hold a weapon in each hand, and lowers the delay while you do.', v = { 10, 15, 25, 30 }, fmt = 'Dual-wield delay -%d%%' },
    ['Rapid Shot'] = { desc = 'Sometimes a ranged attack is aimed much faster (2-50% shorter), and it can do extra damage.', v = { 25 }, fmt = 'About a %d%% chance per shot' },
    ['Shield Mastery'] = { desc = 'You gain TP when you block an attack with your shield.', v = { 10, 20, 30 }, fmt = '+%d TP per block' },
    ['Desperate Blows'] = { desc = 'While Last Resort is up, your two-handed weapon attacks faster.', v = { 5, 10, 15 }, fmt = 'Delay -%d%% under Last Resort' },
    ['Treasure Hunter'] = { desc = 'Raises the chance of rare drops from monsters you attack.', v = { 1, 2 }, fmt = 'Treasure Hunter %d' },
    ['Gilfinder'] = { desc = 'You get more gil from monsters.' },
    ['Wide Scan'] = { desc = 'Lets you use Wide Scan to see monsters and people around you; each tier reaches farther.', v = { 1, 2, 3, 4 }, fmt = 'Wide Scan range tier %d' },
    ['Alertness'] = { desc = 'A minor Ranger trait; the game does not show what it changes and no numbers are documented.' },
    ['Dead Aim'] = { desc = 'Your ranged critical hits do more damage.' },
    ['Stealth'] = { desc = 'Monsters are less likely to notice you.' },
    ['Ninja Tool Expertise'] = { desc = 'Sometimes casting ninjutsu doesn\'t use up the ninja tool.' },
    ['Assassin'] = { desc = 'Strengthens Trick Attack.' },
    ['Divine Veil'] = { desc = 'With Divine Seal, your status-removal spells (-na, Erase) reach your whole party.' },
    ['Strafe'] = { desc = 'Your wyvern\'s breath attacks are more accurate.' },
    ['Empathy'] = { desc = 'Spirit Link also copies your good status effects onto your wyvern (more per merit).' },
    ['Muted Soul'] = { desc = 'You build less enmity while Souleater is up (more per merit).' },
    ['Tandem Strike'] = { desc = 'You and your pet are more accurate when you both attack the same target.' },
    ['Beast Healer'] = { desc = 'Your pet slowly regains HP.' },
    ['Winning Streak'] = { desc = 'Phantom Roll effects last longer (more per merit).' },
    ['Loaded Deck'] = { desc = 'Random Deal can reset up to 2 abilities.' },
};

local ROMAN = { I = 1, II = 2, III = 3, IV = 4, V = 5, VI = 6, VII = 7, VIII = 8 };
local RESIST_OF = { Virus = 'Virus (disease)', Petrify = 'Petrification', Gravity = 'Weight (Gravity)', Sleep = 'Sleep',
    Paralyze = 'Paralysis', Silence = 'Silence', Poison = 'Poison', Blind = 'Blindness', Bind = 'Bind', Slow = 'Slow' };
local KILLER_OF = { Vermin = 'vermin', Bird = 'birds', Amorph = 'amorphs', Lizard = 'lizards', Aquan = 'aquans',
    Plantoid = 'plantoids', Beast = 'beasts', Demon = 'demons', Dragon = 'dragons', Undead = 'undead', Arcana = 'arcana' };

-- What a trait row does: { desc, tier } (tier = this tier's value text or nil).
function trait_info(row)
    if row == nil or row.k ~= 'trait' then return nil; end
    local name = tostring(row.name or '');
    local base, num = name:match('^(.-)%s+([IVX]+)$');
    local rank = 1;
    if base ~= nil and ROMAN[num] ~= nil then rank = ROMAN[num]; else base = name; end

    local r = base:match('^Resist (.+)$');
    if r ~= nil then
        local v = ({ 10, 15, 20, 25 })[rank];
        return { desc = ('Makes you more resistant to %s.'):format(RESIST_OF[r] or r:lower()),
                 tier = v and ('+%d resistance'):format(v) or nil };
    end
    local k = base:match('^(.+) Killer$');
    if k ~= nil then
        local fam = KILLER_OF[k] or k:lower();
        return { desc = ('%s sometimes freeze up in fear (intimidated) and lose their action when they attack you, and they intimidate you less.'):format(fam:sub(1, 1):upper() .. fam:sub(2)),
                 tier = 'About an 8% chance' };
    end

    local t = TRAIT_INFO[base];
    if t == nil then return nil; end
    local tier = nil;
    if t.v ~= nil and t.fmt ~= nil then
        local v = t.v[rank];
        if v ~= nil then
            local ok, s = pcall(string.format, t.fmt, v, v);
            tier = ok and s or nil;
        end
    end
    return { desc = t.desc, tier = tier };
end

SUB_MAX_LEVEL = 37;   -- support job cap at 75
LEVEL_CAP = 75;
