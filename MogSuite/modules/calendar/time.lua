--[[
    MogSuite - modules/calendar/time.lua

    Vana'diel time from the computer clock (the same math IzClock uses;
    IzClock stays its own addon):
      1 Vana'diel day  = 3456 Earth seconds (24 x 144), 1 hour = 144 s
      8-day week (Firesday ... Darksday), 30-day month, 360-day year
      the moon runs an 84-day cycle
    Plus crafting guild hours and the ship / airship timetables
    (LandSandBoat, which HorizonXI is built on).
]]

VANA_OFFSET = 92514960;     -- unix + this = Earth seconds on the Vana'diel clock (Vana'diel year 0)
VDAY = 3456;
VHOUR = 144;

VDAYS = {
    [0] = 'Firesday', [1] = 'Earthsday', [2] = 'Watersday', [3] = 'Windsday',
    [4] = 'Iceday', [5] = 'Lightningday', [6] = 'Lightsday', [7] = 'Darksday',
};
VDAY_SHORT = { [0] = 'Fire', [1] = 'Earth', [2] = 'Water', [3] = 'Wind', [4] = 'Ice', [5] = 'Lightning', [6] = 'Light', [7] = 'Dark' };
VDAY_COLORS = {
    [0] = COLORS.fire, [1] = COLORS.earth, [2] = COLORS.water, [3] = COLORS.wind,
    [4] = COLORS.ice, [5] = COLORS.thunder, [6] = COLORS.light, [7] = COLORS.dark,
};
-- The element each day's element is strong against.
VDAY_BEATS = { [0] = 'Ice', [1] = 'Lightning', [2] = 'Fire', [3] = 'Earth', [4] = 'Wind', [5] = 'Water', [6] = 'Dark', [7] = 'Light' };

MOON_PHASES = {
    [0] = 'New Moon', [1] = 'Waxing Crescent', [2] = 'First Quarter', [3] = 'Waxing Gibbous',
    [4] = 'Full Moon', [5] = 'Waning Gibbous', [6] = 'Last Quarter', [7] = 'Waning Crescent',
};

-- Moon of a Vana'diel day number: name, % (0-100), phase (0-7), waxing.
function moon_of(total_days)
    local signed = ((((total_days + 26) % 84) - 42) / 42) * 100;
    local phase;
    if signed >= 7 and signed <= 38 then phase = 1;
    elseif signed >= 40 and signed <= 55 then phase = 2;
    elseif signed >= 57 and signed <= 88 then phase = 3;
    elseif signed >= 90 or signed <= -95 then phase = 4;
    elseif signed >= -93 and signed <= -62 then phase = 5;
    elseif signed >= -60 and signed <= -45 then phase = 6;
    elseif signed >= -43 and signed <= -12 then phase = 7;
    else phase = 0; end
    return MOON_PHASES[phase], math.floor(math.abs(signed) + 0.5), phase, signed >= 0;
end

function vraw(t) return (t or os.time()) + VANA_OFFSET; end

-- Vana'diel day number -> unix time it starts.
function vday_start(total_days) return total_days * VDAY - VANA_OFFSET; end

-- Everything about a moment (default: now).
function vana_at(t)
    local raw = vraw(t);
    local td = math.floor(raw / VDAY);
    local name, pct, phase, waxing = moon_of(td);
    return {
        total_days = td,
        weekday = td % 8,
        year = math.floor(td / 360),
        month = math.floor((td % 360) / 30) + 1,
        day = td % 30 + 1,
        hour = math.floor(raw / VHOUR) % 24,
        minute = math.floor((raw % VHOUR) / 2.4),
        into_day = raw % VDAY,
        to_next = VDAY - raw % VDAY,
        moon_name = name, moon_pct = pct, moon_phase = phase, moon_waxing = waxing,
    };
end

-- ============================================================================
-- Formatting
-- ============================================================================

-- "2d 03h", "1h 02m", "14m 05s", "35s"
function span(secs)
    secs = math.max(0, math.floor(secs or 0));
    local h, m, s = math.floor(secs / 3600), math.floor(secs % 3600 / 60), secs % 60;
    if h >= 24 then return ('%dd %02dh'):format(math.floor(h / 24), h % 24); end
    if h > 0 then return ('%dh %02dm'):format(h, m); end
    if m > 0 then return ('%dm %02ds'):format(m, s); end
    return ('%ds'):format(s);
end

-- Local clock time of a unix time: "1:20 PM" / "13:20".
function clock_at(t)
    if config.time24 then return os.date('%H:%M', t); end
    return (os.date('%I:%M %p', t):gsub('^0', ''));
end

-- "Sat Oct 24, 1:20 PM" (day name only when it is not today).
function when_at(t)
    local today = os.date('%Y%m%d');
    local d = os.date('%Y%m%d', t);
    if d == today then return 'today ' .. clock_at(t); end
    if d == os.date('%Y%m%d', os.time() + 86400) then return 'tomorrow ' .. clock_at(t); end
    return os.date('%a %b ', t) .. tonumber(os.date('%d', t)) .. ', ' .. clock_at(t);
end

-- ============================================================================
-- Conquest
-- ============================================================================

-- The next conquest results (weekday / hour / minute in local time).
function next_conquest(from)
    local C = config.conquest;
    from = from or os.time();
    local now = os.date('*t', from);
    for ahead = 0, 8 do
        local t = os.time({ year = now.year, month = now.month, day = now.day + ahead,
            hour = tonumber(C.hour) or 11, min = tonumber(C.minute) or 0, sec = 0 });
        if t > from and tonumber(os.date('%w', t)) == (tonumber(C.weekday) or 0) then return t; end
    end
    return from + 7 * 86400;
end

-- ============================================================================
-- Crafting guilds and ships (LandSandBoat; the same tables as IzClock)
-- ============================================================================

GUILDS = {
    { name = 'Alchemy',      where = 'Bastok Mines',          open = 8, close = 23, holiday = 6 },
    { name = 'Bonecraft',    where = 'Windurst Woods',        open = 8, close = 23, holiday = 3 },
    { name = 'Clothcraft',   where = 'Windurst Woods',        open = 6, close = 21, holiday = 0 },
    { name = 'Cooking',      where = 'Windurst Waters',       open = 5, close = 20, holiday = 7 },
    { name = 'Fishing',      where = 'Port Windurst',         open = 3, close = 18, holiday = 5 },
    { name = 'Goldsmithing', where = 'Bastok Markets',        open = 8, close = 23, holiday = 4 },
    { name = 'Leathercraft', where = "S. San d'Oria",         open = 3, close = 18, holiday = 4 },
    { name = 'Smithing',     where = "N. San d'Oria / Metalworks", open = 8, close = 23, holiday = 2 },
    { name = 'Woodworking',  where = "N. San d'Oria",         open = 6, close = 21, holiday = 0 },
};

-- open (bool), Earth seconds until that changes, 'holiday' | 'hours' | nil
function guild_status(g, v)
    local now_min = v.hour * 60 + v.minute;
    local into_min = v.into_day / 2.4;
    local open_min, close_min = g.open * 60, g.close * 60;
    if v.weekday ~= g.holiday and now_min >= open_min and now_min < close_min then
        return true, math.max(0, (close_min - into_min) * 2.4), nil;
    end
    local reason = (v.weekday == g.holiday) and 'holiday' or 'hours';
    for ahead = 0, 8 do
        local d = (v.weekday + ahead) % 8;
        if d ~= g.holiday then
            local at = ahead * 1440 + open_min;
            if at > into_min then return false, (at - into_min) * 2.4, reason; end
        end
    end
    return false, 0, reason;
end

function holiday_guilds(weekday)
    local out = {};
    for _, g in ipairs(GUILDS) do if g.holiday == weekday then out[#out + 1] = g.name; end end
    return out;
end

ROUTES = {
    { group = 'Airships', name = "Jeuno > San d'Oria", every = 864, runs = { { 2, 182 } } },
    { group = 'Airships', name = 'Jeuno > Bastok',      every = 864, runs = { { 434, 614 } } },
    { group = 'Airships', name = 'Jeuno > Windurst',    every = 864, runs = { { 218, 398 } } },
    { group = 'Airships', name = 'Jeuno > Kazham',      every = 864, runs = { { 650, 816 } } },
    { group = 'Airships', name = "San d'Oria > Jeuno", every = 864, runs = { { 434, 612 } } },
    { group = 'Airships', name = 'Bastok > Jeuno',      every = 864, runs = { { 2, 178 } } },
    { group = 'Airships', name = 'Windurst > Jeuno',    every = 864, runs = { { 650, 833 } } },
    { group = 'Airships', name = 'Kazham > Jeuno',      every = 864, runs = { { 218, 393 } } },
    { group = 'Ferry',    name = 'Selbina > Mhaura',    every = 1152, runs = { { 920, 2 } } },
    { group = 'Ferry',    name = 'Mhaura > Selbina',    every = 1152, runs = { { 920, 2 } } },
    { group = 'Manaclipper', name = 'Bibiki Bay > Purgonorgo Isle', every = 1728, runs = { { 675, 798 } } },
    { group = 'Manaclipper', name = 'Purgonorgo Isle > Bibiki Bay', every = 1728, runs = { { 1203, 1338 } } },
    { group = 'Manaclipper', name = 'Bibiki Bay tour',  every = 1728, runs = { { 2, 120 } } },
    { group = 'Barge',    name = 'South > Central Landing', every = 3456, runs = { { 7, 129 } } },
    { group = 'Barge',    name = 'Central > South Landing', every = 3456, runs = { { 647, 752 }, { 2759, 2864 } } },
    { group = 'Barge',    name = 'South > North Landing',   every = 3456, runs = { { 1351, 1472 } } },
    { group = 'Barge',    name = 'North > Central Landing', every = 3456, runs = { { 2375, 2514 } } },
};
ROUTE_GROUPS = { 'Airships', 'Ferry', 'Manaclipper', 'Barge' };

local function ahead(a, b, every) return (b - a) % every; end

-- { boarding, leaves, arrives } (Earth seconds)
function route_status(r, raw)
    raw = raw or vraw();
    local pos = raw % r.every;
    local best = nil;
    for _, run in ipairs(r.runs) do
        local arrive, depart = run[1], run[2];
        local docked = ahead(arrive, pos, r.every) < ahead(arrive, depart, r.every);
        local st = { boarding = docked, leaves = ahead(pos, depart, r.every), arrives = docked and 0 or ahead(pos, arrive, r.every) };
        if best == nil or st.leaves < best.leaves then best = st; end
    end
    return best;
end

-- ============================================================================
-- Moon picture (draw list): a disc lit by the moon %, on the right side
-- while waxing, the left while waning.
-- ============================================================================

function draw_moon(dl, cx, cy, r, pct, waxing)
    local dark = imgui.GetColorU32({ 0.16, 0.16, 0.20, 1.0 });
    local lit = imgui.GetColorU32({ 0.96, 0.94, 0.80, 1.0 });
    dl:AddCircleFilled({ cx, cy }, r, dark, 20);
    pct = math.max(0, math.min(100, tonumber(pct) or 0)) / 100;
    if pct >= 0.98 then
        dl:AddCircleFilled({ cx, cy }, r, lit, 20);
    elseif pct > 0.02 then
        -- Lit part as horizontal slices: an ellipse edge for the terminator.
        local steps = math.max(6, math.floor(r * 2));
        local k = 1 - 2 * pct;   -- terminator position: 1 (none lit) .. -1 (all lit)
        for i = 0, steps - 1 do
            local y0 = -r + (2 * r) * i / steps;
            local y1 = -r + (2 * r) * (i + 1) / steps;
            local ym = (y0 + y1) / 2;
            local half = math.sqrt(math.max(0, r * r - ym * ym));
            local term = k * half;
            local x0, x1;
            if waxing then x0, x1 = cx + term, cx + half; else x0, x1 = cx - half, cx - term; end
            if x1 > x0 then dl:AddRectFilled({ x0, cy + y0 }, { x1, cy + y1 }, lit, 0); end
        end
    end
    dl:AddCircle({ cx, cy }, r, imgui.GetColorU32({ 0, 0, 0, 0.6 }), 20, 1.0);
end
