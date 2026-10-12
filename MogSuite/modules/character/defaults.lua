-- Character settings (saved per character).
return T{
    visible = false,
    appearance = T{
        locked = false,
        border = true,
        title_bar = false,
        good_color = T{ 0.30, 1.00, 0.42, 1.00 },
        warn_color = T{ 1.00, 0.82, 0.22, 1.00 },
        bad_color = T{ 1.00, 0.34, 0.38, 1.00 },
        muted_color = T{ 0.68, 0.71, 0.75, 1.00 },
    },
    ui = T{
        ui_scale = 1.00,
        tab = 1,
        skill_combat = true,
        skill_magic = true,
        skill_craft = true,
        show_unusable = false,
        hide_zero = true,
        cur_show_zero = true,
    },
    window = T{ x = 120, y = 100, width = 600, height = 660 },
    -- Last Currencies list the game sent (Main Menu > Currencies).
    currencies = T{ at = 0, values = T{} },
};
