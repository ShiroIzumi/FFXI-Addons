--[[
    IzClock - core/schedule.lua

    Things that run on the Vana'diel clock: crafting guild hours, ships and
    airships, the moon forecast and the day's crafting element.

    Guild hours and holidays and the ship timetables are LandSandBoat's (the
    server HorizonXI is built on); the ship times there were measured from
    retail. Everything is worked out from the clock, nothing is read from the
    game.
]]

local vana = require('core.vana');

local schedule = {};

-- ============================================================================
-- Crafting guilds
-- ============================================================================

-- open / close are Vana'diel hours (open from open:00 until close:00);
-- holiday is the weekday the guild shop stays shut (0 = Firesday).
schedule.GUILDS = {
    { key = 'alchemy',  name = 'Alchemy',      where = 'Bastok Mines',         open = 8, close = 23, holiday = 6 },
    { key = 'bone',     name = 'Bonecraft',    where = 'Windurst Woods',       open = 8, close = 23, holiday = 3 },
    { key = 'cloth',    name = 'Clothcraft',   where = 'Windurst Woods',       open = 6, close = 21, holiday = 0 },
    { key = 'cooking',  name = 'Cooking',      where = 'Windurst Waters',      open = 5, close = 20, holiday = 7 },
    { key = 'fishing',  name = 'Fishing',      where = 'Port Windurst',        open = 3, close = 18, holiday = 5 },
    { key = 'gold',     name = 'Goldsmithing', where = 'Bastok Markets',       open = 8, close = 23, holiday = 4 },
    { key = 'leather',  name = 'Leathercraft', where = 'S. San d\'Oria',       open = 3, close = 18, holiday = 4 },
    { key = 'smith',    name = 'Smithing',     where = 'N. San d\'Oria / Metalworks', open = 8, close = 23, holiday = 2 },
    { key = 'wood',     name = 'Woodworking',  where = 'N. San d\'Oria',       open = 6, close = 21, holiday = 0 },
};

local VMIN = 2.4;   -- Earth seconds per Vana'diel minute

-- Is the guild open right now, and how many Earth seconds until that changes.
-- Returns open, secs, reason ('holiday' | 'hours' | nil).
function schedule.guild_status(g, v)
    local now_min = v.hour * 60 + v.minute;
    local open_min, close_min = g.open * 60, g.close * 60;
    local into_min = (v.into_day or 0) / VMIN;   -- exact minutes into the day
    if v.day ~= g.holiday and now_min >= open_min and now_min < close_min then
        return true, math.max(0, (close_min - into_min) * VMIN), nil;
    end
    -- Closed: find the next opening (today if it hasn't opened yet, else a later day that isn't the holiday).
    local reason = (v.day == g.holiday) and 'holiday' or 'hours';
    for ahead = 0, 8 do
        local d = (v.day + ahead) % 8;
        if d ~= g.holiday then
            local at = ahead * 1440 + open_min;
            if at > into_min then
                return false, (at - into_min) * VMIN, reason;
            end
        end
    end
    return false, 0, reason;
end

-- Guilds whose holiday is the given weekday.
function schedule.holiday_guilds(day)
    local out = {};
    for _, g in ipairs(schedule.GUILDS) do
        if g.holiday == day then out[#out + 1] = g.name; end
    end
    return out;
end

-- ============================================================================
-- Ships, airships, the manaclipper and the barge
-- ============================================================================

-- every: cycle length (Earth seconds). runs: { arrive, depart } seconds into
-- the cycle: when the ship docks and when it leaves.
schedule.ROUTES = {
    { key = 'jeu_san', group = 'Airships', name = 'Jeuno > San d\'Oria', every = 864, runs = { { 2, 182 } } },
    { key = 'jeu_bas', group = 'Airships', name = 'Jeuno > Bastok',      every = 864, runs = { { 434, 614 } } },
    { key = 'jeu_win', group = 'Airships', name = 'Jeuno > Windurst',    every = 864, runs = { { 218, 398 } } },
    { key = 'jeu_kaz', group = 'Airships', name = 'Jeuno > Kazham',      every = 864, runs = { { 650, 816 } } },
    { key = 'san_jeu', group = 'Airships', name = 'San d\'Oria > Jeuno', every = 864, runs = { { 434, 612 } } },
    { key = 'bas_jeu', group = 'Airships', name = 'Bastok > Jeuno',      every = 864, runs = { { 2, 178 } } },
    { key = 'win_jeu', group = 'Airships', name = 'Windurst > Jeuno',    every = 864, runs = { { 650, 833 } } },
    { key = 'kaz_jeu', group = 'Airships', name = 'Kazham > Jeuno',      every = 864, runs = { { 218, 393 } } },
    { key = 'sel_mha', group = 'Ferry',    name = 'Selbina > Mhaura',    every = 1152, runs = { { 920, 2 } } },
    { key = 'mha_sel', group = 'Ferry',    name = 'Mhaura > Selbina',    every = 1152, runs = { { 920, 2 } } },
    { key = 'bib_pur', group = 'Manaclipper', name = 'Bibiki Bay > Purgonorgo Isle', every = 1728, runs = { { 675, 798 } } },
    { key = 'pur_bib', group = 'Manaclipper', name = 'Purgonorgo Isle > Bibiki Bay', every = 1728, runs = { { 1203, 1338 } } },
    { key = 'bib_tour', group = 'Manaclipper', name = 'Bibiki Bay tour',  every = 1728, runs = { { 2, 120 } } },
    { key = 'brg_s_c', group = 'Barge',    name = 'South > Central Landing', every = 3456, runs = { { 7, 129 } } },
    { key = 'brg_c_s', group = 'Barge',    name = 'Central > South Landing', every = 3456, runs = { { 647, 752 }, { 2759, 2864 } } },
    { key = 'brg_s_n', group = 'Barge',    name = 'South > North Landing',   every = 3456, runs = { { 1351, 1472 } } },
    { key = 'brg_n_c', group = 'Barge',    name = 'North > Central Landing', every = 3456, runs = { { 2375, 2514 } } },
};
schedule.GROUPS = { 'Airships', 'Ferry', 'Manaclipper', 'Barge' };

-- Routes shown in the hover window unless changed.
schedule.DEFAULT_HOVER_ROUTES = {
    jeu_san = true, jeu_bas = true, jeu_win = true, jeu_kaz = true,
    san_jeu = true, bas_jeu = true, win_jeu = true, kaz_jeu = true,
    sel_mha = true, mha_sel = true,
};

-- Seconds from a to b going forward round a cycle.
local function ahead(a, b, every) return (b - a) % every; end

-- Where a route is right now:
--   boarding = true while docked (leaves in `leaves` seconds)
--   otherwise arrives in `arrives`, leaves in `leaves`
function schedule.route_status(r, raw)
    raw = raw or vana.raw();
    local pos = raw % r.every;
    local best = nil;
    for _, run in ipairs(r.runs) do
        local arrive, depart = run[1], run[2];
        local docked = ahead(arrive, pos, r.every) < ahead(arrive, depart, r.every);
        local st = {
            boarding = docked,
            leaves = ahead(pos, depart, r.every),
            arrives = docked and 0 or ahead(pos, arrive, r.every),
        };
        if best == nil or st.leaves < best.leaves then best = st; end
    end
    return best;
end

-- ============================================================================
-- Moon
-- ============================================================================

-- Earth seconds until the next day that is the given moon phase (and how long
-- the current one lasts if it is that phase now).
-- Returns: now (bool), secs (until it starts, or until it ends when now).
function schedule.moon_next(v, phase)
    local function phase_of(k) local _, _, p = vana.moon(v.total_days + k); return p; end
    if phase_of(0) == phase then
        for k = 1, 84 do
            if phase_of(k) ~= phase then return true, v.to_next + (k - 1) * vana.DAY_SECS; end
        end
        return true, 0;
    end
    for k = 1, 84 do
        if phase_of(k) == phase then return false, v.to_next + (k - 1) * vana.DAY_SECS; end
    end
    return false, 0;
end

-- ============================================================================
-- Crafting element of the day
-- ============================================================================

-- Day (0-7) -> element name and the element that element is strong against.
schedule.ELEMENTS = {
    [0] = { name = 'Fire',      beats = 'Ice' },
    [1] = { name = 'Earth',     beats = 'Lightning' },
    [2] = { name = 'Water',     beats = 'Fire' },
    [3] = { name = 'Wind',      beats = 'Earth' },
    [4] = { name = 'Ice',       beats = 'Wind' },
    [5] = { name = 'Lightning', beats = 'Water' },
    [6] = { name = 'Light',     beats = 'Dark' },
    [7] = { name = 'Dark',      beats = 'Light' },
};

-- ============================================================================
-- Formatting
-- ============================================================================

-- "2d 03h", "1h 02m", "14m 05s", "35s"
function schedule.span(secs)
    secs = math.max(0, math.floor(secs or 0));
    local h, m, s = math.floor(secs / 3600), math.floor(secs % 3600 / 60), secs % 60;
    if h >= 24 then return ('%dd %02dh'):format(math.floor(h / 24), h % 24); end
    if h > 0 then return ('%dh %02dm'):format(h, m); end
    if m > 0 then return ('%dm %02ds'):format(m, s); end
    return ('%ds'):format(s);
end

-- Local clock time a number of seconds from now ("13:20" / "1:20 PM").
function schedule.at_local(secs, time24)
    local t = os.time() + math.floor(secs or 0);
    if time24 then return os.date('%H:%M', t); end
    local s = os.date('%I:%M %p', t);
    if s:sub(1, 1) == '0' then s = s:sub(2); end
    return s;
end

return schedule;
