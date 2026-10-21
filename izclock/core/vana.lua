--[[
    IzClock - core/vana.lua

    Vana'diel time from the computer clock (no packet needed):
      1 Vana'diel day  = 3456 Earth seconds (24 x 144)
      1 Vana'diel hour = 144 Earth seconds
      1 Vana'diel min  = 2.4 Earth seconds
    Elemental days rotate every Vana'diel day (8-day week); the moon runs an
    84-day cycle.

    vana.now() is cached for the current Earth second, so calling it every
    frame costs nothing.
]]

local vana = {};

-- Unix time + this offset = Earth seconds on the Vana'diel calendar used by
-- established FFXI clocks (same constants as IzClock 2.x).
local EPOCH_OFFSET = 92514960;
local DAY_SECS = 3456;
local HOUR_SECS = 144;
local MOON_CYCLE = 84;

vana.DAYS = {
    [0] = 'Firesday', [1] = 'Earthsday', [2] = 'Watersday', [3] = 'Windsday',
    [4] = 'Iceday', [5] = 'Lightningday', [6] = 'Lightsday', [7] = 'Darksday',
};

-- Short tags for the optional element markers.
vana.TAGS = {
    [0] = 'Fi', [1] = 'Ea', [2] = 'Wa', [3] = 'Wi', [4] = 'Ic', [5] = 'Li', [6] = 'Ls', [7] = 'Da',
};

-- Element-inspired default colors (bright enough for a dark background).
vana.DAY_COLORS = {
    [0] = { 1.00, 0.34, 0.22, 1.00 }, -- Firesday
    [1] = { 0.78, 0.62, 0.30, 1.00 }, -- Earthsday
    [2] = { 0.30, 0.68, 1.00, 1.00 }, -- Watersday
    [3] = { 0.38, 0.92, 0.58, 1.00 }, -- Windsday
    [4] = { 0.58, 0.90, 1.00, 1.00 }, -- Iceday
    [5] = { 0.78, 0.52, 1.00, 1.00 }, -- Lightningday
    [6] = { 1.00, 0.92, 0.55, 1.00 }, -- Lightsday
    [7] = { 0.72, 0.58, 0.86, 1.00 }, -- Darksday
};

vana.MOON_PHASES = {
    [0] = 'New Moon', [1] = 'Waxing Crescent', [2] = 'First Quarter Moon', [3] = 'Waxing Gibbous',
    [4] = 'Full Moon', [5] = 'Waning Gibbous', [6] = 'Last Quarter Moon', [7] = 'Waning Crescent',
};

-- Moon for a Vana'diel day number: phase name and illumination %.
-- The signed value runs -100..100; the game shows its absolute value.
local function moon(total_days)
    local signed = ((((total_days + 26) % MOON_CYCLE) - (MOON_CYCLE / 2)) / (MOON_CYCLE / 2)) * 100;
    local phase;
    if signed >= 7 and signed <= 38 then phase = 1;
    elseif signed >= 40 and signed <= 55 then phase = 2;
    elseif signed >= 57 and signed <= 88 then phase = 3;
    elseif signed >= 90 or signed <= -95 then phase = 4;
    elseif signed >= -93 and signed <= -62 then phase = 5;
    elseif signed >= -60 and signed <= -45 then phase = 6;
    elseif signed >= -43 and signed <= -12 then phase = 7;
    else phase = 0; end
    return vana.MOON_PHASES[phase], math.floor(math.abs(signed) + 0.5), phase, signed;
end
vana.moon = moon;
vana.DAY_SECS = DAY_SECS;
vana.HOUR_SECS = HOUR_SECS;

-- Earth seconds on the same clock (lines up with the game's ship schedules).
function vana.raw() return os.time() + EPOCH_OFFSET; end

local cache_t, cache = nil, nil;

-- Everything for the current second:
--   hour, minute, day (0-7), next_day, total_days, to_next (Earth seconds
--   until the next Vana'diel day), into_day (Earth seconds since it began),
--   moon_name, moon_pct, moon_phase, moon_waxing.
function vana.now()
    local t = os.time();
    if cache_t == t and cache ~= nil then return cache; end
    local raw = t + EPOCH_OFFSET;
    local total_days = math.floor(raw / DAY_SECS);
    local day = total_days % 8;
    local into_day = raw % DAY_SECS;
    local name, pct, phase, signed = moon(total_days);
    cache = {
        hour = math.floor(raw / HOUR_SECS) % 24,
        minute = math.floor((raw % HOUR_SECS) / 2.4),
        day = day,
        next_day = (day + 1) % 8,
        total_days = total_days,
        to_next = DAY_SECS - into_day,
        moon_name = name,
        moon_pct = pct,
        moon_phase = phase,
        moon_waxing = signed >= 0,
        into_day = into_day,
    };
    cache_t = t;
    return cache;
end

return vana;
