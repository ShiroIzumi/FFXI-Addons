-- Inventory settings (saved per character).
return T{
    visible = false,
    locked = false,
    title_bar = false,
    window = T{ x = 220, y = 180, w = 440, h = 560 },

    view = 'list',             -- 'list' | 'grid' | 'categories'
    font_scale = 1.0,
    icon_size = 24,            -- list view icon (px, before font scale)
    grid_icon = 40,            -- grid view cell (px, before font scale)
    row_spacing = 2,
    show_qty_one = false,
    show_tags = true,          -- E / Rare / Ex tags in list view

    name_color = T{ 0.93, 0.93, 0.95, 1.0 },
    qty_color = T{ 0.96, 0.80, 0.45, 1.0 },

    sort = 'slot',             -- slot | name | type | qty | newest
    sort_desc = false,
    bag = 0,                   -- selected tab; -1 = All, -2 = Characters, -3 = Key Items
    hidden_bags = T{},         -- [bag_id] = true to hide its tab

    new_highlight = true,
    new_seconds = 10,
    new_sticky = true,         -- keep the highlight until hovered / window closed

    qty_format = 'x',          -- 'x' = x12 | 'stack' = 12/99
    show_value = true,         -- sell value in tooltips and footer
    favorites = T{},           -- [item_id] = true
    pin_favorites = true,      -- favorites first in List / Grid
    grey_unusable = true,      -- dim gear your job / level can't equip
    show_split = true,         -- mark split (mergeable) stacks
    warn_full = true,          -- inventory-full warning
    warn_free = 5,             -- warn when this many free slots or fewer
    cat_style = 'list',        -- Categories view: 'list' | 'grid'
    cat_order = T{ 'favorites', 'new', 'equipped', 'weapons', 'armor', 'ammo', 'usable', 'crystals', 'rareex', 'materials' },
    cat_collapsed = T{},       -- [category key] = true
    gil_day = '',              -- date of gil_day_start
    gil_day_start = -1,        -- gil at the start of gil_day
    log_window = T{ x = 680, y = 180, w = 420, h = 420 },
    show_ah = true,            -- Auction House category in tooltips

    filter = 'all',            -- main window filter chip
    hidden = false,            -- every window hidden with the open key
    popouts = T{},             -- Shift+Click pop-out windows (one per tab)
    popout_saved = T{},        -- [tostring(bag)] = last size / position / view of a closed pop-out
};
