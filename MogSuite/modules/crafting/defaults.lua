-- Crafting settings (saved per character).
return T{
    visible = false,
    locked = false,
    font_scale = 1.0,
    window = T{ x = -1, y = -1, w = 900, h = 620 },
    tab = 'recipes',            -- skills | recipes | canmake | ledger
    craft = 'all',              -- recipe filter: 'all' or a craft name
    only_skill = false,         -- only recipes within your skill
    only_have = false,          -- only recipes you have every material for
    show_desynth = false,
    skillup_range = 10,         -- "good for skill-ups": up to this many levels over your skill
    ledger = T{ enabled = true, chat = false },
};
