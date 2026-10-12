--[[
    MogSuite skill data - HorizonXI / level 75 era
    Job ids: WAR=1 MNK=2 WHM=3 BLM=4 RDM=5 THF=6 PLD=7 DRK=8 BST=9
             BRD=10 RNG=11 SAM=12 NIN=13 DRG=14 SMN=15 BLU=16 COR=17 PUP=18
]]--

local M = {};

M.jobs = {
    [1]  = 'WAR', [2]  = 'MNK', [3]  = 'WHM', [4]  = 'BLM', [5]  = 'RDM', [6]  = 'THF',
    [7]  = 'PLD', [8]  = 'DRK', [9]  = 'BST', [10] = 'BRD', [11] = 'RNG', [12] = 'SAM',
    [13] = 'NIN', [14] = 'DRG', [15] = 'SMN', [16] = 'BLU', [17] = 'COR', [18] = 'PUP',
};

M.weapon_skills = {
    { name = 'Hand-to-Hand',  index = 1  },
    { name = 'Dagger',        index = 2  },
    { name = 'Sword',         index = 3  },
    { name = 'Great Sword',   index = 4  },
    { name = 'Axe',           index = 5  },
    { name = 'Great Axe',     index = 6  },
    { name = 'Scythe',        index = 7  },
    { name = 'Polearm',       index = 8  },
    { name = 'Katana',        index = 9  },
    { name = 'Great Katana',  index = 10 },
    { name = 'Club',          index = 11 },
    { name = 'Staff',         index = 12 },
    { name = 'Archery',       index = 25 },
    { name = 'Marksmanship',  index = 26 },
    { name = 'Throwing',      index = 27 },
    { name = 'Guarding',      index = 28 },
    { name = 'Evasion',       index = 29 },
    { name = 'Shield',        index = 30 },
    { name = 'Parrying',      index = 31 },
};

M.magic_skills = {
    { name = 'Divine Magic',     index = 32 },
    { name = 'Healing Magic',    index = 33 },
    { name = 'Enhancing Magic',  index = 34 },
    { name = 'Enfeebling Magic', index = 35 },
    { name = 'Elemental Magic',  index = 36 },
    { name = 'Dark Magic',       index = 37 },
    { name = 'Summoning Magic',  index = 38 },
    { name = 'Ninjutsu',         index = 39 },
    { name = 'Singing',          index = 40 },
    { name = 'String Instrument',index = 41 },
    { name = 'Wind Instrument',  index = 42 },
    { name = 'Blue Magic',       index = 43 },
};

M.craft_skills = {
    { name = 'Fishing',       index = 0, cap = 100 },
    { name = 'Woodworking',   index = 1, cap = 100 },
    { name = 'Smithing',      index = 2, cap = 100 },
    { name = 'Goldsmithing',  index = 3, cap = 100 },
    { name = 'Clothcraft',    index = 4, cap = 100 },
    { name = 'Leathercraft',  index = 5, cap = 100 },
    { name = 'Bonecraft',     index = 6, cap = 100 },
    { name = 'Alchemy',       index = 7, cap = 100 },
    { name = 'Cooking',       index = 8, cap = 100 },
};

-- Horizon-era skill ranks. Nil means the current job has no innate skill.
-- Values for the original/Zilart jobs follow the classic level-75 tables.
-- ToAU jobs use Horizon's current BLU/COR/PUP skill tables.
M.ranks = {
    ['Hand-to-Hand'] = {
        [1]='D',[2]='A+',[6]='E',[13]='E',[18]='B+',
    },
    ['Dagger'] = {
        [1]='B-',[4]='D',[5]='B',[6]='A-',[7]='C-',[8]='C',[9]='C+',[10]='B-',
        [11]='B-',[12]='E',[13]='C+',[14]='E',[15]='E',[17]='B+',[18]='C-',
    },
    ['Sword'] = {
        [1]='B',[5]='B',[6]='D',[7]='A+',[8]='B-',[9]='E',[10]='C-',[11]='D',
        [12]='C+',[13]='C',[14]='C-',[16]='A+',[17]='B-',
    },
    ['Great Sword'] = {
        [1]='B+',[7]='B',[8]='A-',
    },
    ['Axe'] = {
        [1]='A-',[8]='C-',[9]='A-',[11]='B-',
    },
    ['Great Axe'] = {
        [1]='A+',[8]='C+',
    },
    ['Scythe'] = {
        [1]='B+',[3]='E',[8]='A+',[9]='B-',
    },
    ['Polearm'] = {
        [1]='B-',[7]='E',[12]='B-',[14]='A+',
    },
    ['Katana'] = {
        [13]='A-',
    },
    ['Great Katana'] = {
        [12]='A+',[13]='C-',
    },
    ['Club'] = {
        [1]='B-',[2]='C+',[3]='B+',[4]='E',[5]='D',[6]='E',[7]='A-',[8]='C-',
        [9]='D',[10]='D',[11]='E',[12]='E',[13]='E',[14]='E',[15]='E',[16]='B-',
        [18]='D',
    },
    ['Staff'] = {
        [1]='B',[2]='B',[3]='C+',[4]='B-',[7]='A-',[9]='C+',[10]='C+',[14]='B-',
        [15]='B-',
    },
    ['Archery'] = {
        [1]='D',[5]='D',[6]='C-',[11]='A-',[12]='C+',[13]='E',
    },
    ['Marksmanship'] = {
        [1]='D',[6]='C+',[8]='E',[11]='A-',[13]='C',[17]='B',
    },
    ['Throwing'] = {
        [1]='D',[2]='E',[4]='D',[5]='F',[6]='D',[10]='E',[11]='C-',[12]='C',
        [13]='A-',[17]='C+',
    },
    ['Guarding'] = {
        [2]='A-',[18]='B-',
    },
    ['Evasion'] = {
        [1]='C',[2]='B+',[3]='E',[4]='E',[5]='D',[6]='A+',[7]='C',[8]='C',
        [9]='C',[10]='D',[11]='E',[12]='B+',[13]='A-',[14]='C-',[15]='E',
        [16]='C-',[17]='D',[18]='B',
    },
    ['Shield'] = {
        [1]='C+',[3]='D',[5]='F',[6]='F',[7]='A+',[9]='E',
    },
    ['Parrying'] = {
        [1]='C-',[2]='E',[5]='E',[6]='A-',[7]='C',[8]='E',[9]='C',[10]='E',
        [12]='A-',[13]='A-',[14]='C',[16]='D',[17]='A-',[18]='D',
    },

    ['Divine Magic'] = {
        [3]='A-',[5]='E',[7]='B+',
    },
    ['Healing Magic'] = {
        [3]='A+',[5]='C-',[7]='C',
    },
    ['Enhancing Magic'] = {
        [3]='C+',[4]='E',[5]='B+',[7]='D',
    },
    ['Enfeebling Magic'] = {
        [3]='C',[4]='C+',[5]='A+',[8]='C',
    },
    ['Elemental Magic'] = {
        [4]='A+',[5]='C+',[8]='B+',
    },
    ['Dark Magic'] = {
        [4]='A-',[5]='E',[8]='A-',
    },
    ['Summoning Magic'] = {
        [15]='A-',
    },
    ['Ninjutsu'] = {
        [13]='A-',
    },
    ['Singing'] = {
        [10]='C',
    },
    ['String Instrument'] = {
        [10]='C',
    },
    ['Wind Instrument'] = {
        [10]='C',
    },
    ['Blue Magic'] = {
        [16]='A+',
    },
};

-- Exact classic level-75 caps. 1-60 use grouped rank rows, then ranks split.
local pre60 = {
    ['A'] = {
        6,9,12,15,18,21,24,27,30,33,36,39,42,45,48,51,54,57,60,63,
        66,69,72,75,78,81,84,87,90,93,96,99,102,105,108,111,114,117,120,123,
        126,129,132,135,138,141,144,147,150,153,158,163,168,173,178,183,188,193,198,203,
    },
    ['B'] = {
        5,7,10,13,16,19,22,25,28,31,34,36,39,42,45,48,51,54,57,60,
        63,65,68,71,74,77,80,83,86,89,92,94,97,100,103,106,109,112,115,118,
        121,123,126,129,132,135,138,141,144,147,151,156,161,166,171,176,181,186,191,196,
    },
    ['C'] = {
        5,7,10,13,16,19,21,24,27,30,33,35,38,41,44,47,49,52,55,58,
        61,63,66,69,72,75,77,80,83,86,89,91,94,97,100,103,105,108,111,114,
        117,119,122,125,128,131,133,136,139,142,146,151,156,161,166,170,175,180,185,190,
    },
    ['D'] = {
        4,6,9,12,14,17,20,22,25,28,31,33,36,39,41,44,47,49,52,55,
        58,60,63,66,68,71,74,76,79,82,85,87,90,93,95,98,101,103,106,109,
        112,114,117,120,122,125,128,130,133,136,140,145,150,154,159,164,168,173,178,183,
    },
    ['E'] = {
        4,6,9,11,14,16,19,21,24,26,29,31,34,36,39,41,44,46,49,51,
        54,56,59,61,64,66,69,71,74,76,79,81,84,86,89,91,94,96,99,101,
        104,106,109,111,114,116,119,121,124,126,130,135,139,144,148,153,157,162,166,171,
    },
    ['F'] = {
        4,6,8,10,13,15,17,20,22,24,27,29,31,33,36,38,40,43,45,47,
        50,52,54,56,59,61,63,66,68,70,73,75,77,79,82,84,86,89,91,93,
        96,98,100,102,105,107,109,112,114,116,120,124,128,133,137,141,146,150,154,159,
    },
};

local post60 = {
    ['A+']={207,212,217,222,227,232,236,241,246,251,256,261,266,271,276},
    ['A-']={207,211,215,219,223,227,231,235,239,244,249,254,259,264,269},
    ['B+']={199,203,207,210,214,218,221,225,229,233,237,241,246,251,256},
    ['B'] ={199,202,205,208,212,215,218,221,225,228,232,236,240,245,250},
    ['B-']={198,201,204,206,209,212,214,217,220,223,226,229,232,236,240},
    ['C+']={192,195,197,200,202,205,207,210,212,215,218,221,224,227,230},
    ['C'] ={192,194,196,199,201,203,205,208,210,212,214,217,219,222,225},
    ['C-']={192,194,196,198,200,202,204,206,208,210,212,214,216,218,220},
    ['D'] ={184,186,188,190,192,194,195,197,199,201,203,205,207,208,210},
    ['E'] ={172,174,176,178,180,182,184,186,188,190,192,194,196,198,200},
    ['F'] ={161,163,165,167,169,171,173,175,177,179,181,183,185,187,189},
};

function M.get_rank(job_id, skill_name)
    local row = M.ranks[skill_name];
    if row == nil then return nil; end
    return row[job_id];
end

function M.get_cap(rank, level)
    level = math.floor(tonumber(level) or 0);
    if rank == nil or level < 1 then return nil; end
    if level > 75 then level = 75; end

    if level <= 60 then
        local group = rank:sub(1, 1);
        local row = pre60[group];
        return row and row[level] or nil;
    end

    local row = post60[rank];
    return row and row[level - 60] or nil;
end

return M;
