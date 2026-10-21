-- Actions settings (saved per character).
return T{
    visible = false,
    locked = false,
    title_bar = false,
    window = T{ x = 260, y = 160, w = 470, h = 620 },

    font_scale = 1.0,
    row_spacing = 3,
    tab = 'abilities',          -- abilities | ws | magic | summons | wyvern | automaton | beast

    name_color = T{ 0.93, 0.93, 0.95, 1.0 },
    value_color = T{ 0.80, 0.72, 1.00, 1.0 },

    show_bars = true,           -- HP / MP / TP bars in the header
    show_details = true,        -- details pane at the bottom
    show_pinned = true,         -- pinned strip at the top
    show_sub_locked = true,     -- support job abilities you haven't reached
    show_special_ws = false,    -- relic weapon skills you don't have
    show_traits = true,         -- job traits after the abilities (HorizonXI levels)
    show_horizon_marks = true,  -- "H" mark on things HorizonXI changed
    show_tools = true,          -- ninja tool counts on Ninjutsu
    hide_unknown_spells = false,-- hide spells you can't use yet
    magic_sort = 'level',       -- level | name

    filter = T{ abilities = 'all', ws = 'all', magic = 'all', summons = 'all', wyvern = 'all', automaton = 'all', beast = 'all' },
    collapsed = T{},            -- [section key] = true
    pinned = T{},               -- list of { k = 'ja'|'pet'|'bp'|'ws'|'ma', n = name }
};
