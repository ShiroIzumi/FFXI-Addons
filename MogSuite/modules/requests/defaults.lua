-- Requests settings (saved per character).
return T{
    party = true,               -- popup for party / alliance invites
    trade = true,               -- popup for trade requests
    auto_close = 60,            -- close an unanswered popup after this many seconds (0 = never)
    font_scale = 1.2,
    locked = false,
    title_bar = false,
    border = true,
    -- x / y = -1: center it on the screen the first time it shows.
    window = T{ x = -1, y = -1, w = 470, h = 160 },
};
