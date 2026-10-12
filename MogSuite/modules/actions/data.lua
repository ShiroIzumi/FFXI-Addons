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
JOB_ABILITIES = {
    [1] = { -- WAR
        { 'Mighty Strikes', 1, 'sp' }, { 'Provoke', 5 }, { 'Berserk', 15 }, { 'Defender', 25 },
        { 'Warcry', 35 }, { 'Aggressor', 45 }, { 'Retaliation', 60 },
        { "Warrior's Charge", 75, 'merit' }, { 'Tomahawk', 75, 'merit' },
    },
    [2] = { -- MNK
        { 'Hundred Fists', 1, 'sp' }, { 'Boost', 5 }, { 'Dodge', 15 }, { 'Focus', 25 }, { 'Chakra', 35 },
        { 'Chi Blast', 41 }, { 'Counterstance', 45 }, { 'Footwork', 65 },
        { 'Mantra', 75, 'merit' }, { 'Formless Strikes', 75, 'merit' },
    },
    [3] = { -- WHM
        { 'Benediction', 1, 'sp' }, { 'Divine Seal', 15 }, { 'Afflatus Solace', 40 }, { 'Afflatus Misery', 45 },
        { 'Martyr', 75, 'merit' }, { 'Devotion', 75, 'merit' },
    },
    [4] = { -- BLM
        { 'Manafont', 1, 'sp' }, { 'Elemental Seal', 15 },
    },
    [5] = { -- RDM
        { 'Chainspell', 1, 'sp' }, { 'Convert', 40 }, { 'Composure', 50 },
    },
    [6] = { -- THF
        { 'Perfect Dodge', 1, 'sp' }, { 'Steal', 5 }, { 'Sneak Attack', 15 }, { 'Flee', 25 },
        { 'Trick Attack', 30 }, { 'Mug', 35 }, { 'Hide', 45 }, { 'Accomplice', 65 },
        { "Assassin's Charge", 75, 'merit' }, { 'Feint', 75, 'merit' },
    },
    [7] = { -- PLD
        { 'Invincible', 1, 'sp' }, { 'Holy Circle', 5 }, { 'Shield Bash', 15 }, { 'Sentinel', 30 },
        { 'Cover', 35 }, { 'Rampart', 62 },
        { 'Fealty', 75, 'merit' }, { 'Chivalry', 75, 'merit' },
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
        { 'Leave', 35, 'pet' }, { 'Snarl', 45, 'pet' },
        { 'Feral Howl', 75, 'merit' }, { 'Killer Instinct', 75, 'merit' },
    },
    [10] = { -- BRD
        { 'Soul Voice', 1, 'sp' },
        { 'Nightingale', 75, 'merit' }, { 'Troubadour', 75, 'merit' },
    },
    [11] = { -- RNG
        { 'Eagle Eye Shot', 1, 'sp' }, { 'Sharpshot', 1 }, { 'Scavenge', 10 }, { 'Camouflage', 20 },
        { 'Barrage', 30 }, { 'Shadowbind', 40 }, { 'Unlimited Shot', 51 },
        { 'Stealth Shot', 75, 'merit' }, { 'Flashy Shot', 75, 'merit' },
    },
    [12] = { -- SAM
        { 'Meikyo Shisui', 1, 'sp' }, { 'Warding Circle', 5 }, { 'Third Eye', 15 }, { 'Hasso', 25 },
        { 'Meditate', 30 }, { 'Seigan', 35 },
        { 'Shikikoyo', 75, 'merit' }, { 'Blade Bash', 75, 'merit' },
    },
    [13] = { -- NIN
        { 'Mijin Gakure', 1, 'sp' }, { 'Yonin', 40 }, { 'Innin', 40 },
        { 'Sange', 75, 'merit' },
    },
    [14] = { -- DRG
        { 'Spirit Surge', 1, 'sp' }, { 'Call Wyvern', 1 }, { 'Ancient Circle', 5 }, { 'Jump', 10 },
        { 'Spirit Link', 25 }, { 'High Jump', 35 }, { 'Super Jump', 50 },
        { 'Deep Breathing', 75, 'merit' }, { 'Angon', 75, 'merit' },
    },
    [15] = { -- SMN
        { 'Astral Flow', 1, 'sp' }, { 'Elemental Siphon', 50 }, { "Avatar's Favor", 55 },
        { 'Assault', 1, 'pet' }, { 'Retreat', 1, 'pet' }, { 'Release', 1, 'pet' },
    },
    [16] = { -- BLU
        { 'Azure Lore', 1, 'sp' }, { 'Burst Affinity', 25 }, { 'Chain Affinity', 40 },
        { 'Convergence', 75, 'merit' }, { 'Diffusion', 75, 'merit' },
    },
    [17] = { -- COR
        { 'Wild Card', 1, 'sp' }, { 'Double-Up', 5 }, { 'Random Deal', 50 },
        { "Corsair's Roll", 5, 'roll' }, { 'Ninja Roll', 8, 'roll' }, { "Hunter's Roll", 11, 'roll' },
        { 'Chaos Roll', 14, 'roll' }, { "Magus's Roll", 17, 'roll' }, { "Healer's Roll", 20, 'roll' },
        { 'Drachen Roll', 23, 'roll' }, { 'Choral Roll', 26, 'roll' }, { "Monk's Roll", 31, 'roll' },
        { 'Beast Roll', 34, 'roll' }, { 'Samurai Roll', 34, 'roll' }, { "Evoker's Roll", 40, 'roll' },
        { "Rogue's Roll", 43, 'roll' }, { "Warlock's Roll", 46, 'roll' }, { "Fighter's Roll", 49, 'roll' },
        { 'Puppet Roll', 52, 'roll' }, { "Gallant's Roll", 55, 'roll' }, { "Wizard's Roll", 58, 'roll' },
        { "Dancer's Roll", 61, 'roll' }, { "Scholar's Roll", 64, 'roll' },
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
};

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
-- 'quest' = weapon skill quest, 'relic' / 'mythic' = special weapon only.
WS_DATA = {
    [1] = { { 'Combo', 5 }, { 'Shoulder Tackle', 40 }, { 'One Inch Punch', 75 }, { 'Backhand Blow', 100 },
        { 'Raging Fists', 125 }, { 'Spinning Attack', 150 }, { 'Howling Fist', 200 }, { 'Dragon Kick', 225 },
        { 'Asuran Fists', 250, 'quest' }, { 'Final Heaven', 0, 'relic' }, { 'Stringing Pummel', 0, 'mythic' } },
    [2] = { { 'Wasp Sting', 5 }, { 'Gust Slash', 40 }, { 'Shadowstitch', 70 }, { 'Viper Bite', 100 },
        { 'Cyclone', 125 }, { 'Energy Steal', 150 }, { 'Energy Drain', 175 }, { 'Dancing Edge', 200 },
        { 'Shark Bite', 225 }, { 'Evisceration', 230, 'quest' }, { 'Mercy Stroke', 0, 'relic' },
        { 'Mandalic Stab', 0, 'mythic' }, { 'Mordant Rime', 0, 'mythic' } },
    [3] = { { 'Fast Blade', 5 }, { 'Burning Blade', 30 }, { 'Red Lotus Blade', 50 }, { 'Flat Blade', 75 },
        { 'Shining Blade', 100 }, { 'Seraph Blade', 125 }, { 'Circle Blade', 150 }, { 'Spirits Within', 175 },
        { 'Vorpal Blade', 200 }, { 'Swift Blade', 225 }, { 'Savage Blade', 240, 'quest' },
        { 'Knights of Round', 0, 'relic' }, { 'Death Blossom', 0, 'mythic' }, { 'Atonement', 0, 'mythic' },
        { 'Expiacion', 0, 'mythic' } },
    [4] = { { 'Hard Slash', 5 }, { 'Power Slash', 30 }, { 'Frostbite', 70 }, { 'Freezebite', 100 },
        { 'Shockwave', 150 }, { 'Crescent Moon', 175 }, { 'Sickle Moon', 200 }, { 'Spinning Slash', 225 },
        { 'Ground Strike', 250, 'quest' }, { 'Scourge', 0, 'relic' } },
    [5] = { { 'Raging Axe', 5 }, { 'Smash Axe', 40 }, { 'Gale Axe', 70 }, { 'Avalanche Axe', 100 },
        { 'Spinning Axe', 150 }, { 'Rampage', 175 }, { 'Calamity', 200 }, { 'Mistral Axe', 225 },
        { 'Decimation', 240, 'quest' }, { 'Onslaught', 0, 'relic' }, { 'Primal Rend', 0, 'mythic' } },
    [6] = { { 'Shield Break', 5 }, { 'Iron Tempest', 40 }, { 'Sturmwind', 70 }, { 'Armor Break', 100 },
        { 'Keen Edge', 150 }, { 'Weapon Break', 175 }, { 'Raging Rush', 200 }, { 'Full Break', 225 },
        { 'Steel Cyclone', 240, 'quest' }, { 'Metatron Torment', 0, 'relic' }, { "King's Justice", 0, 'mythic' } },
    [7] = { { 'Slice', 5 }, { 'Dark Harvest', 30 }, { 'Shadow of Death', 70 }, { 'Nightmare Scythe', 100 },
        { 'Spinning Scythe', 125 }, { 'Vorpal Scythe', 150 }, { 'Guillotine', 200 }, { 'Cross Reaper', 225 },
        { 'Spiral Hell', 240, 'quest' }, { 'Catastrophe', 0, 'relic' }, { 'Insurgency', 0, 'mythic' } },
    [8] = { { 'Double Thrust', 5 }, { 'Thunder Thrust', 30 }, { 'Raiden Thrust', 70 }, { 'Leg Sweep', 100 },
        { 'Penta Thrust', 150 }, { 'Vorpal Thrust', 175 }, { 'Skewer', 200 }, { 'Wheeling Thrust', 225 },
        { 'Impulse Drive', 240, 'quest' }, { 'Geirskogul', 0, 'relic' }, { 'Drakesbane', 0, 'mythic' } },
    [9] = { { 'Blade: Rin', 5 }, { 'Blade: Retsu', 30 }, { 'Blade: Teki', 70 }, { 'Blade: To', 100 },
        { 'Blade: Chi', 150 }, { 'Blade: Ei', 175 }, { 'Blade: Jin', 200 }, { 'Blade: Ten', 225 },
        { 'Blade: Ku', 250, 'quest' }, { 'Blade: Metsu', 0, 'relic' }, { 'Blade: Kamu', 0, 'mythic' } },
    [10] = { { 'Tachi: Enpi', 5 }, { 'Tachi: Hobaku', 30 }, { 'Tachi: Goten', 70 }, { 'Tachi: Kagero', 100 },
        { 'Tachi: Jinpu', 150 }, { 'Tachi: Koki', 175 }, { 'Tachi: Yukikaze', 200 }, { 'Tachi: Gekko', 225 },
        { 'Tachi: Kasha', 250, 'quest' }, { 'Tachi: Kaiten', 0, 'relic' }, { 'Tachi: Rana', 0, 'mythic' } },
    [11] = { { 'Shining Strike', 5 }, { 'Seraph Strike', 40 }, { 'Brainshaker', 70 }, { 'Starlight', 100 },
        { 'Moonlight', 125 }, { 'Skullbreaker', 150 }, { 'True Strike', 175 }, { 'Judgment', 200 },
        { 'Hexa Strike', 220 }, { 'Black Halo', 230, 'quest' }, { 'Randgrith', 0, 'relic' },
        { 'Mystic Boon', 0, 'mythic' } },
    [12] = { { 'Heavy Swing', 5 }, { 'Rock Crusher', 40 }, { 'Earth Crusher', 70 }, { 'Starburst', 100 },
        { 'Sunburst', 150 }, { 'Shell Crusher', 175 }, { 'Full Swing', 200 }, { 'Spirit Taker', 215 },
        { 'Retribution', 230, 'quest' }, { 'Gate of Tartarus', 0, 'relic' }, { 'Vidohunir', 0, 'mythic' },
        { 'Garland of Bliss', 0, 'mythic' } },
    [25] = { { 'Flaming Arrow', 5 }, { 'Piercing Arrow', 40 }, { 'Dulling Arrow', 80 }, { 'Sidewinder', 175 },
        { 'Blast Arrow', 200 }, { 'Arching Arrow', 225 }, { 'Empyreal Arrow', 250, 'quest' },
        { 'Namas Arrow', 0, 'relic' } },
    [26] = { { 'Hot Shot', 5 }, { 'Split Shot', 40 }, { 'Sniper Shot', 80 }, { 'Slug Shot', 175 },
        { 'Blast Shot', 200 }, { 'Heavy Shot', 225 }, { 'Detonator', 250, 'quest' }, { 'Coronach', 0, 'relic' },
        { 'Leaden Salute', 0, 'mythic' }, { 'Trueflight', 0, 'mythic' } },
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
    Carbuncle = {
        { 'Healing Ruby', 1, 'ward' }, { 'Poison Nails', 5, 'rage' }, { 'Shining Ruby', 24, 'ward' },
        { 'Glittering Ruby', 44, 'ward' }, { 'Meteorite', 55, 'rage' }, { 'Healing Ruby II', 65, 'ward' },
        { 'Searing Light', 1, 'rage', 'af' },
    },
    Fenrir = {
        { 'Moonlit Charge', 5, 'rage' }, { 'Crescent Fang', 10, 'rage' }, { 'Lunar Cry', 21, 'ward' },
        { 'Lunar Roar', 32, 'ward' }, { 'Ecliptic Growl', 43, 'ward' }, { 'Ecliptic Howl', 54, 'ward' },
        { 'Eclipse Bite', 65, 'rage' }, { 'Howling Moon', 1, 'rage', 'af' },
    },
    Ifrit = {
        { 'Punch', 1, 'rage' }, { 'Fire II', 10, 'rage' }, { 'Burning Strike', 23, 'rage' },
        { 'Double Punch', 30, 'rage' }, { 'Crimson Howl', 38, 'ward' }, { 'Fire IV', 60, 'rage' },
        { 'Flaming Crush', 70, 'rage' }, { 'Meteor Strike', 75, 'rage', 'merit' }, { 'Inferno', 1, 'rage', 'af' },
    },
    Titan = {
        { 'Rock Throw', 1, 'rage' }, { 'Stone II', 10, 'rage' }, { 'Rock Buster', 21, 'rage' },
        { 'Megalith Throw', 35, 'rage' }, { 'Earthen Ward', 46, 'ward' }, { 'Stone IV', 60, 'rage' },
        { 'Mountain Buster', 70, 'rage' }, { 'Geocrush', 75, 'rage', 'merit' }, { 'Earthen Fury', 1, 'rage', 'af' },
    },
    Leviathan = {
        { 'Barracuda Dive', 1, 'rage' }, { 'Water II', 10, 'rage' }, { 'Tail Whip', 26, 'rage' },
        { 'Slowga', 33, 'ward' }, { 'Spinning Dive', 45, 'rage' }, { 'Water IV', 60, 'rage' },
        { 'Tidal Roar', 70, 'ward' }, { 'Grand Fall', 75, 'rage', 'merit' }, { 'Tidal Wave', 1, 'rage', 'af' },
    },
    Garuda = {
        { 'Claw', 1, 'rage' }, { 'Wind II', 10, 'rage' }, { 'Aerial Armor', 25, 'ward' },
        { 'Whispering Wind', 36, 'ward' }, { 'Hastega', 48, 'ward' }, { 'Aero IV', 60, 'rage' },
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
        abilities = { ['Spirit Surge'] = true, ['Call Wyvern'] = true, ['Spirit Link'] = true, ['Deep Breathing'] = true } },
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

SUB_MAX_LEVEL = 37;   -- support job cap at 75
LEVEL_CAP = 75;
