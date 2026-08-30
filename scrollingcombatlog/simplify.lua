-- simplify.lua
-- Turns raw battle / casting lines into compact, colorized token arrays.
-- Falls back cleanly if a line doesn't match known patterns.

local M = {}

-- Colors (RGBA, 0..1). Tweak to taste.
local COLORS = {
    you        = {0.65, 0.85, 1.00, 1.00},
    party      = {0.55, 1.00, 0.55, 1.00},
    other      = {0.90, 0.90, 0.90, 1.00},
    mob        = {1.00, 0.60, 0.60, 1.00},
    verb       = {0.95, 0.85, 0.55, 1.00},
    dmg        = {1.00, 0.75, 0.40, 1.00},
    crit       = {1.00, 0.35, 0.35, 1.00},
    miss      = {0.70, 0.70, 0.85, 1.00},
    parry      = {0.70, 0.85, 1.00, 1.00},
    resist     = {0.85, 0.70, 1.00, 1.00},
    status     = {0.80, 0.90, 1.00, 1.00},
    default    = {0.85, 0.85, 0.85, 1.00},
}

-- Helpers ---------------------------------------------------------------------

local function token(text, color)
    return { text = text, color = color }
end

-- name type guess (very light; we’ll color mobs reddish if they’re bracketed or capitalized multi-word)
local function is_mob_name(s)
    if not s then return false end
    if s:find('%[.*%]') then return true end
    -- crude heuristic: title-cased 2+ words often mobs in retail/Horizon logs, but keep loose
    local wc = 0
    for w in s:gmatch('%S+') do wc = wc + 1 end
    return wc >= 2
end

local function color_for_name(name, player_me, party_lookup)
    if not name then return COLORS.default end
    if player_me and name == player_me then return COLORS.you end
    if party_lookup and party_lookup[name] then return COLORS.party end
    if is_mob_name(name) then return COLORS.mob end
    return COLORS.other
end

-- Build a friendly party lookup from table of names (optional, we’ll allow nil)
local function build_party_lookup(party_names)
    local t = {}
    if type(party_names) == 'table' then
        for _, n in ipairs(party_names) do t[n] = true end
    end
    return t
end

-- Patterns (English client). Keep minimal & robust.
-- We’ll cover the most common lines. Unknowns fall back to plain.
local PATTERNS = {
    -- Crit first (strongest signal)
    {
        name = 'crit',
        re = '^([%w\'%-_]+)%s+scores a critical hit!?%s*([%w\'%-_ ]*)%s*takes%s+(%d+)%s+points? of damage%.?$',
        build = function(src, tgt, dmg, ctx)
            local srcC = color_for_name(src, ctx.me, ctx.party)
            local tgtC = color_for_name(tgt ~= '' and tgt or nil, ctx.me, ctx.party)
            local out = {
                token(src, srcC), token(' → ', COLORS.default),
                token((tgt ~= '' and tgt or 'target'), tgtC),
                token('  ', COLORS.default),
                token('CRIT ', COLORS.crit),
                token(dmg, COLORS.dmg)
            }
            return 'hit', out
        end
    },
    -- Normal hit
    {
        name = 'hit',
        re = '^([%w\'%-_]+)%s+hits%s+([%w\'%-_ ]+)%s+for%s+(%d+)%s+points? of damage%.?$',
        build = function(src, tgt, dmg, ctx)
            local srcC = color_for_name(src, ctx.me, ctx.party)
            local tgtC = color_for_name(tgt, ctx.me, ctx.party)
            local out = {
                token(src, srcC), token(' → ', COLORS.default),
                token(tgt, tgtC), token('  ', COLORS.default),
                token(dmg, COLORS.dmg)
            }
            return 'hit', out
        end
    },
    -- Miss
    {
        name = 'miss',
        re = '^([%w\'%-_]+)%s+misses%s+([%w\'%-_ ]+)%.?$',
        build = function(src, tgt, ctx)
            local srcC = color_for_name(src, ctx.me, ctx.party)
            local tgtC = color_for_name(tgt, ctx.me, ctx.party)
            local out = {
                token(src, srcC), token(' → ', COLORS.default),
                token(tgt, tgtC), token('  ', COLORS.default),
                token('MISS', COLORS.miss),
            }
            return 'miss', out
        end
    },
    -- Parry / evasion style
    {
        name = 'parry',
        re = '^([%w\'%-_ ]+)%s+parries%S*%s+([%w\'%-_]+)\'s?%s+attack',
        build = function(tgt, src, ctx)
            local srcC = color_for_name(src, ctx.me, ctx.party)
            local tgtC = color_for_name(tgt, ctx.me, ctx.party)
            local out = {
                token(src, srcC), token(' → ', COLORS.default),
                token(tgt, tgtC), token('  ', COLORS.default),
                token('PARRY', COLORS.parry),
            }
            return 'parry', out
        end
    },
    -- Weapon Skill / Monster TP “readies …”
    {
        name = 'readies',
        re = '^([%w\'%-_ ]+)%s+readies%s+([%w\'%-_ ]+)%.?$',
        build = function(src, ws, ctx)
            local srcC = color_for_name(src, ctx.me, ctx.party)
            local out = {
                token(src, srcC), token('  ', COLORS.default),
                token('WS: ', COLORS.verb), token(ws, COLORS.status)
            }
            return 'ws', out
        end
    },
    -- Uses ability/WS
    {
        name = 'uses',
        re = '^([%w\'%-_ ]+)%s+uses%s+([%w\'%-_ ]+)%.?$',
        build = function(src, ws, ctx)
            local srcC = color_for_name(src, ctx.me, ctx.party)
            local out = {
                token(src, srcC), token('  ', COLORS.default),
                token('WS: ', COLORS.verb), token(ws, COLORS.status)
            }
            return 'ws', out
        end
    },
    -- Casting start
    {
        name = 'casts_start',
        re = '^([%w\'%-_ ]+)%s+starts? casting%s+([%w\'%-_ ]+)%.?$',
        build = function(src, sp, ctx)
            local srcC = color_for_name(src, ctx.me, ctx.party)
            local out = {
                token(src, srcC), token('  ', COLORS.default),
                token('Cast: ', COLORS.verb), token(sp, COLORS.status)
            }
            return 'cast', out
        end
    },
    -- Casting (complete) that deals damage
    {
        name = 'casts_damage',
        re = '^([%w\'%-_ ]+)%s+casts%s+([%w\'%-_ ]+)%.%s*([%w\'%-_ ]+)%s+takes%s+(%d+)%s+points? of damage%.?$',
        build = function(src, sp, tgt, dmg, ctx)
            local srcC = color_for_name(src, ctx.me, ctx.party)
            local tgtC = color_for_name(tgt, ctx.me, ctx.party)
            local out = {
                token(src, srcC), token(' → ', COLORS.default),
                token(tgt, tgtC), token('  ', COLORS.default),
                token('Cast: ', COLORS.verb), token(sp, COLORS.status),
                token('  ', COLORS.default),
                token(dmg, COLORS.dmg),
            }
            return 'cast', out
        end
    },
    -- “is defeated” (kill)
    {
        name = 'defeat',
        re = '^([%w\'%-_ ]+)%s+defeats%s+([%w\'%-_ ]+)%.?$',
        build = function(src, tgt, ctx)
            local srcC = color_for_name(src, ctx.me, ctx.party)
            local tgtC = color_for_name(tgt, ctx.me, ctx.party)
            local out = {
                token(src, srcC), token(' ✖ ', COLORS.default),
                token(tgt, tgtC)
            }
            return 'defeat', out
        end
    },
}

-- Public: simplify one line -> {category, tokens} or nil
-- ctx = { me = "PlayerName", party = {name1,name2,...} }
function M.simplify(line, ctx)
    local s = line
    for _, p in ipairs(PATTERNS) do
        local m = { s:match(p.re) }
        if #m > 0 then
            -- Add ctx as last param
            local ok, cat, toks = pcall(function()
                return p.build(table.unpack(m), ctx)
            end)
            if ok and cat and toks then
                return cat, toks
            end
        end
    end
    return nil, nil
end

M.colors = COLORS
M.party_lookup = build_party_lookup

return M
