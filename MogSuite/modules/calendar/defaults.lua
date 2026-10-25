-- Calendar settings (saved per character).
return T{
    visible = false,
    locked = false,
    font_scale = 1.0,
    window = T{ x = -1, y = -1, w = 820, h = 600 },
    tab = 'today',              -- today | vana | earth | timers | events | travel
    time24 = false,

    -- Conquest results (HorizonXI: Sunday 11:00 Eastern, per John). Your
    -- computer's local time: change it here if yours differs.
    conquest = T{ enabled = true, weekday = 0, hour = 11, minute = 0 },   -- weekday 0 = Sunday

    -- The summary a few seconds after you log in.
    login = T{
        enabled = true, popup = true, chat = false, seconds = 20,
        day = true, moon = true, conquest = true, timers = true, events = true, guilds = true,
    },
    -- Where the login summary / notice box sits (drag it; -1 = top centre).
    popup_pos = T{ x = -1, y = -1 },

    -- When a timer is ready / an event starts.
    notify = T{ enabled = true, chat = true, popup = true, sound = false, before = 15 },

    -- What the month views show.
    show = T{ moon = true, holidays = true, conquest = true, events = true, timers = true },

    -- Your timers on this character: { id, name, hours, started, note, kind }.
    timers = T{},
    next_id = 1,
};
