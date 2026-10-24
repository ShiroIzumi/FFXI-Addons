--[[
    MogSuite - modules/calendar/events.lua

    Your events and timers.

    Events (shared by all your characters) are kept outside the addon
    folder, in config\addons\mogsuite\calendar_events.lua:
      { id, title, at (unix), rep ('none' | 'daily' | 'weekly' | 'monthly'),
        note, color (element key) }

    Timers belong to the character (Calendar settings): a name and a length
    in hours; Start when you do the thing (enter Dynamis, get the key item)
    and it counts down to "ready".
]]

-- Ready-made timers. Lengths from horizonffxi.wiki (Dynamis, Cosmo-Cleanse);
-- change any of them after adding.
TIMER_PRESETS = {
    { name = 'Dynamis', hours = 72, note = '72 Earth hours from when you entered (HorizonXI).' },
    { name = 'Limbus (Cosmo-Cleanse)', hours = 72, note = 'Cosmo-Cleanse again 72 Earth hours after you entered (HorizonXI).' },
    { name = 'ENM key item', hours = 120, note = 'Key item for an ENM; set the hours your ENM uses.' },
    { name = 'BCNM / KSNM orb', hours = 24, note = 'Change the hours to what you need.' },
    { name = 'Weekly', hours = 168, note = 'Something you do once a week.' },
    { name = 'Daily', hours = 24, note = 'Something you do once a day.' },
    { name = 'Custom', hours = 1, note = '' },
};

EVENT_COLORS = { 'water', 'fire', 'wind', 'earth', 'thunder', 'ice', 'light', 'dark' };
REPEATS = {
    { key = 'none', label = 'Once' }, { key = 'daily', label = 'Daily' },
    { key = 'weekly', label = 'Weekly' }, { key = 'monthly', label = 'Monthly' },
};

cal_events = nil;     -- loaded on first use

local function events_path()
    local p = '';
    pcall(function() p = AshitaCore:GetInstallPath(); end);
    p = tostring(p or ''):gsub('[\\/]+$', '');
    return p .. '\\config\\addons\\mogsuite', p .. '\\config\\addons\\mogsuite\\calendar_events.lua';
end

local function q(s) return (('%q'):format(tostring(s or '')):gsub('\\\n', '\\n')); end

function save_events()
    local dir, path = events_path();
    pcall(function() if not ashita.fs.exists(dir) then ashita.fs.create_directory(dir); end end);
    local f = io.open(path, 'w');
    if f == nil then return; end
    f:write('-- MogSuite Calendar: your events (all characters). Written by MogSuite.\nreturn {\n');
    for _, e in ipairs(cal_events or {}) do
        f:write(('  { id = %d, title = %s, at = %d, rep = %s, note = %s, color = %s },\n'):format(
            tonumber(e.id) or 0, q(e.title), math.floor(tonumber(e.at) or 0), q(e.rep or 'none'), q(e.note), q(e.color or 'water')));
    end
    f:write('}\n');
    f:close();
end

function load_events()
    if cal_events ~= nil then return cal_events; end
    cal_events = {};
    local _, path = events_path();
    local chunk = loadfile(path);
    if chunk ~= nil then
        local ok, t = pcall(chunk);
        if ok and type(t) == 'table' then cal_events = t; end
    end
    return cal_events;
end

function new_event_id()
    local m = 0;
    for _, e in ipairs(load_events()) do m = math.max(m, tonumber(e.id) or 0); end
    return m + 1;
end

-- Every time an event happens between a and b (repeats expanded).
function event_times(e, a, b)
    local out = {};
    local at = tonumber(e.at) or 0;
    local rep = e.rep or 'none';
    if rep == 'none' then
        if at >= a and at < b then out[1] = at; end
        return out;
    end
    local base = os.date('*t', at);
    local function nth(n)
        if rep == 'daily' then
            return os.time({ year = base.year, month = base.month, day = base.day + n, hour = base.hour, min = base.min, sec = 0 });
        elseif rep == 'weekly' then
            return os.time({ year = base.year, month = base.month, day = base.day + 7 * n, hour = base.hour, min = base.min, sec = 0 });
        end
        return os.time({ year = base.year, month = base.month + n, day = base.day, hour = base.hour, min = base.min, sec = 0 });
    end
    -- Start just before the window (old repeating events).
    local n = 0;
    if a > at then
        local step = (rep == 'daily') and 86400 or ((rep == 'weekly') and 7 * 86400 or 28 * 86400);
        n = math.max(0, math.floor((a - at) / step) - 2);
    end
    local guard = 0;
    while guard < 400 do
        guard = guard + 1;
        local t = nth(n);
        if t >= b then break; end
        if t >= a then out[#out + 1] = t; end
        n = n + 1;
    end
    return out;
end

-- Everything on the calendar between a and b, sorted:
-- { t, kind ('event' | 'timer' | 'conquest'), title, color, ref }
function items_between(a, b)
    local out = {};
    if config.show.events ~= false then
        for _, e in ipairs(load_events()) do
            for _, t in ipairs(event_times(e, a, b)) do
                out[#out + 1] = { t = t, kind = 'event', title = e.title, color = COLORS[e.color] or COLORS.water, ref = e };
            end
        end
    end
    if config.show.timers ~= false then
        for _, tm in ipairs(config.timers or {}) do
            local ready = timer_ready_at(tm);
            if ready ~= nil and ready >= a and ready < b then
                out[#out + 1] = { t = ready, kind = 'timer', title = tm.name .. ' ready', color = COLORS.wind, ref = tm };
            end
        end
    end
    if config.conquest.enabled ~= false and config.show.conquest ~= false then
        local t = next_conquest(a - 1);
        local guard = 0;
        while t < b and guard < 10 do
            guard = guard + 1;
            out[#out + 1] = { t = t, kind = 'conquest', title = 'Conquest results', color = COLORS.earth };
            t = next_conquest(t + 60);
        end
    end
    table.sort(out, function(x, y) return x.t < y.t; end);
    return out;
end

-- ============================================================================
-- Timers
-- ============================================================================

function timer_ready_at(tm)
    local s = tonumber(tm.started);
    if s == nil or s <= 0 then return nil; end
    return s + math.floor((tonumber(tm.hours) or 0) * 3600);
end

-- 'ready' | 'waiting' | 'idle', seconds left
function timer_status(tm)
    local r = timer_ready_at(tm);
    if r == nil then return 'idle', 0; end
    local left = r - os.time();
    if left <= 0 then return 'ready', 0; end
    return 'waiting', left;
end

function add_timer(preset)
    config.timers = config.timers or T{};
    local id = tonumber(config.next_id) or 1;
    config.next_id = id + 1;
    config.timers[#config.timers + 1] = T{ id = id, name = preset.name, hours = preset.hours, started = 0, note = preset.note or '' };
    mark_dirty();
    return config.timers[#config.timers];
end

function start_timer(tm)
    tm.started = os.time();
    state.ready_seen[tm.id] = nil;
    mark_dirty();
end

-- ============================================================================
-- Notices (timer ready, event starting) and the login summary
-- ============================================================================

local function chat(text)
    print(('\30\81[MogSuite]\30\01 %s'):fmt(text));
end

function toast(lines, secs)
    state.toast = { lines = lines, until_t = os.clock() + (tonumber(secs) or 12) };
end

local last_check = 0;
function check_notices()
    local N = config.notify;
    if N.enabled == false then return; end
    if os.clock() - last_check < 1.0 then return; end
    last_check = os.clock();
    local now = os.time();
    local lines = {};
    for _, tm in ipairs(config.timers or {}) do
        local st = timer_status(tm);
        if st == 'ready' and not state.ready_seen[tm.id] then
            state.ready_seen[tm.id] = true;
            -- Only announce what became ready this session (not on login).
            local r = timer_ready_at(tm) or 0;
            if now - r < 120 then lines[#lines + 1] = tm.name .. ' is ready.'; end
        end
    end
    local before = math.max(0, tonumber(N.before) or 15) * 60;
    for _, it in ipairs(items_between(now - 60, now + before + 1)) do
        if it.kind == 'event' then
            local key = tostring(it.ref.id) .. '@' .. it.t;
            local soon = it.t - now;
            if soon <= before and soon > 0 and not state.event_seen[key .. 'b'] and before > 0 then
                state.event_seen[key .. 'b'] = true;
                lines[#lines + 1] = ('%s in %s (%s).'):fmt(it.title, span(soon), clock_at(it.t));
            elseif soon <= 0 and not state.event_seen[key] then
                state.event_seen[key] = true;
                lines[#lines + 1] = it.title .. ' is starting now.';
            end
        end
    end
    if #lines > 0 then
        if N.chat ~= false then for _, l in ipairs(lines) do chat(l); end end
        if N.popup ~= false then toast(lines, 12); end
        if N.sound == true then
            pcall(function() ashita.misc.play_sound(((addon.path .. '\\sounds\\notice.wav'):gsub('[\\/]+', '\\'))); end);
        end
    end
end

-- Lines for the login summary.
function login_lines()
    local L = config.login;
    local v = vana_at();
    local now = os.time();
    local out = {};
    if L.day ~= false then
        out[#out + 1] = { ('%s (%s, strong vs %s)'):fmt(VDAYS[v.weekday], VDAY_SHORT[v.weekday], VDAY_BEATS[v.weekday]), VDAY_COLORS[v.weekday] };
    end
    if L.moon ~= false then
        out[#out + 1] = { ('%s %d%%'):fmt(v.moon_name, v.moon_pct), { 0.96, 0.94, 0.80, 1 } };
    end
    if L.conquest ~= false and config.conquest.enabled ~= false then
        local t = next_conquest(now);
        out[#out + 1] = { ('Conquest results in %s (%s)'):fmt(span(t - now), when_at(t)), COLORS.earth };
    end
    if L.timers ~= false then
        for _, tm in ipairs(config.timers or {}) do
            local st, left = timer_status(tm);
            if st == 'ready' then
                out[#out + 1] = { tm.name .. ' is ready', COLORS.wind };
            elseif st == 'waiting' and left < 24 * 3600 then
                out[#out + 1] = { ('%s ready in %s'):fmt(tm.name, span(left)), UI_MUTED };
            end
        end
    end
    if L.events ~= false then
        for _, it in ipairs(items_between(now, now + 24 * 3600)) do
            if it.kind == 'event' then out[#out + 1] = { ('%s: %s'):fmt(when_at(it.t), it.title), it.color }; end
        end
    end
    if L.guilds ~= false then
        local hol = holiday_guilds(v.weekday);
        if #hol > 0 then out[#out + 1] = { 'Guild holiday today: ' .. table.concat(hol, ', '), UI_MUTED }; end
    end
    return out;
end

function show_login()
    local L = config.login;
    if L.enabled == false then return; end
    local lines = login_lines();
    if L.chat == true then
        for _, l in ipairs(lines) do chat(l[1]); end
    end
    if L.popup ~= false then
        state.login_lines = lines;
        state.login_until = os.clock() + math.max(3, tonumber(L.seconds) or 20);
    end
end
