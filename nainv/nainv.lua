--[[
    NAInv (New Age Inventory) - Ashita v4 / HorizonXI
    Version 1.3.4

    A modern, configurable inventory window: every bag in tabs, game icons,
    quantity beside the name, list or grid view, search / sort / filters,
    item tooltips, new-item highlight, and a right-click menu for
    Use / Equip / Drop.

    Commands:
      /nai          open / close the inventory window
      /nai config   open / close the config window
      /nai help     list commands

    Everything acts only when you click it. Use is /item, Equip is /equip;
    Drop sends the game's own drop packet after you confirm.

    1.1.0: item values (LandSandBoat price list + prices learned from vendor
    appraisals), Categories view, favorites, unusable gear greyed out, stack
    info, inventory-full warning, session loot log, gil tracker, other
    characters' inventories, Mog House storage snapshots, Key Items tab.

    1.2.0: Shift+Click any tab to open it in its own window (own size,
    position, view, sort, filter and search). The open key hides / shows
    every window you didn't close with X.

    1.2.1: reads the current LandSandBoat item_basic.sql layout.
    1.2.2: Shift+Click a tab whose window is open to close it.
    1.2.3: the open key reads Ctrl / Alt / Shift from Windows, so it can't
           get stuck ignoring the key (e.g. after Alt+Tab).
    1.3.0: tooltips show what a full stack sells for and the item's
           Auction House category.
    1.3.1: pop-outs reopen with their last size / position / view; tabs
           that are open in their own window get a small mark; gil only
           shows on the Inventory tab, and item value is labeled "Worth".
    1.3.2: Key Items read from the game's key item packets (permanent and
           temporary); Wardrobe 5-8; new tab order.
    1.3.3: right-click a key item to mark it TEMP (shared by all characters).
    1.3.4: temporary key items get the TEMP mark on their own (by key item
           ID); right-click still overrides it. All / Permanent / Temporary /
           Maps & Other chips on the Key Items tab.
]]

addon.name    = 'nainv';
addon.author  = 'Izumi (ShiroIzumi)';
addon.version = '1.3.4';
addon.desc    = 'New Age Inventory: a modern, configurable inventory window.';
addon.link    = '';

require('common');
local imgui    = require('imgui');
local settings = require('settings');
local ffi      = require('ffi');
local d3d      = require('d3d8');
local bit      = require('bit');

local C = ffi.C;

-- ============================================================================
-- Theme (black base + accent), same look as the rest of the suite
-- ============================================================================

local UI_TITLE          = { 0.020, 0.020, 0.022, 1.00 };
local UI_TITLE_ACTIVE   = { 0.080, 0.080, 0.090, 1.00 };
local UI_POPUP          = { 0.050, 0.050, 0.056, 0.98 };
local UI_BORDER         = { 0.250, 0.250, 0.280, 0.90 };
local UI_CONTROL        = { 0.100, 0.100, 0.110, 1.00 };
local UI_CONTROL_HOVER  = { 0.160, 0.160, 0.180, 1.00 };
local UI_CONTROL_ACTIVE = { 0.220, 0.220, 0.250, 1.00 };
local UI_TEXT           = { 0.93, 0.93, 0.95, 1.00 };
local UI_MUTED          = { 0.62, 0.62, 0.66, 1.00 };
local UI_ACCENT         = { 0.50, 0.50, 0.50, 1.00 };
local UI_ACCENT_TEXT    = { 0.70, 0.70, 0.70, 1.00 };
local UI_TRANSPARENT    = { 0.00, 0.00, 0.00, 0.00 };
local UI_WHITE          = { 1.00, 1.00, 1.00, 1.00 };
local UI_DANGER         = { 0.86, 0.30, 0.30, 1.00 };

-- 0-255 RGB. accent: fills / underlines; text: headers and selected tabs;
-- title_active: focused title bar; border: borders.
local UI_THEMES = {
    copper   = { label = 'Copper',   accent = { 196, 128, 80 },  text = { 224, 166, 120 }, title_active = { 24, 15, 9 },  border = { 72, 48, 32 } },
    black    = { label = 'Black',    accent = { 150, 150, 156 }, text = { 214, 214, 220 }, title_active = { 14, 14, 15 }, border = { 52, 52, 56 } },
    garnet   = { label = 'Garnet',   accent = { 168, 52, 62 },   text = { 214, 112, 120 }, title_active = { 24, 9, 11 },  border = { 70, 30, 34 } },
    silver   = { label = 'Silver',   accent = { 176, 188, 204 }, text = { 226, 232, 240 }, title_active = { 28, 30, 34 }, border = { 66, 72, 82 } },
    emerald  = { label = 'Emerald',  accent = { 60, 180, 110 },  text = { 132, 222, 166 }, title_active = { 10, 28, 18 }, border = { 30, 70, 46 } },
    amethyst = { label = 'Amethyst', accent = { 150, 118, 214 }, text = { 184, 160, 236 }, title_active = { 16, 11, 26 }, border = { 52, 42, 78 } },
};
local UI_THEME_ORDER = { 'copper', 'black', 'garnet', 'silver', 'emerald', 'amethyst' };
local UI_THEME_DEFAULT = 'copper';
local applied_theme = nil;

local function set_rgb(dst, rgb)
    dst[1] = rgb[1] / 255; dst[2] = rgb[2] / 255; dst[3] = rgb[3] / 255;
end

local function theme_key(key)
    key = tostring(key or UI_THEME_DEFAULT):lower();
    if UI_THEMES[key] == nil then key = UI_THEME_DEFAULT; end
    return key;
end

local function apply_theme(key)
    key = theme_key(key);
    if applied_theme == key then return; end
    local t = UI_THEMES[key];
    set_rgb(UI_ACCENT, t.accent);
    set_rgb(UI_ACCENT_TEXT, t.text);
    set_rgb(UI_TITLE_ACTIVE, t.title_active);
    set_rgb(UI_BORDER, t.border);
    applied_theme = key;
end

local function accent(alpha_mul)
    return { UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], UI_ACCENT[4] * (alpha_mul or 1.0) };
end

local theme_stack = {};

local function push_theme(bg, key)
    apply_theme(key);
    local nc, nv = 0, 0;
    local function c(idx, v) if idx ~= nil then imgui.PushStyleColor(idx, v); nc = nc + 1; end end
    local function v(idx, val) if idx ~= nil then imgui.PushStyleVar(idx, val); nv = nv + 1; end end

    c(ImGuiCol_WindowBg, { bg[1], bg[2], bg[3], bg[4] });
    c(ImGuiCol_ChildBg, UI_TRANSPARENT);
    c(ImGuiCol_PopupBg, UI_POPUP);
    c(ImGuiCol_TitleBg, UI_TITLE);
    c(ImGuiCol_TitleBgActive, UI_TITLE_ACTIVE);
    c(ImGuiCol_TitleBgCollapsed, UI_TITLE);
    c(ImGuiCol_Border, UI_BORDER);
    c(ImGuiCol_BorderShadow, UI_TRANSPARENT);
    c(ImGuiCol_Text, UI_TEXT);
    c(ImGuiCol_TextDisabled, UI_MUTED);
    c(ImGuiCol_TextSelectedBg, accent(0.35));
    c(ImGuiCol_FrameBg, UI_CONTROL);
    c(ImGuiCol_FrameBgHovered, UI_CONTROL_HOVER);
    c(ImGuiCol_FrameBgActive, UI_CONTROL_ACTIVE);
    c(ImGuiCol_CheckMark, UI_ACCENT);
    c(ImGuiCol_SliderGrab, accent(0.80));
    c(ImGuiCol_SliderGrabActive, UI_ACCENT);
    c(ImGuiCol_Button, UI_CONTROL);
    c(ImGuiCol_ButtonHovered, UI_CONTROL_HOVER);
    c(ImGuiCol_ButtonActive, UI_CONTROL_ACTIVE);
    c(ImGuiCol_Header, accent(0.22));
    c(ImGuiCol_HeaderHovered, accent(0.30));
    c(ImGuiCol_HeaderActive, accent(0.40));
    c(ImGuiCol_Separator, UI_BORDER);
    c(ImGuiCol_SeparatorHovered, accent(0.60));
    c(ImGuiCol_SeparatorActive, UI_ACCENT);
    c(ImGuiCol_ScrollbarBg, { 0.00, 0.00, 0.00, 0.20 });
    c(ImGuiCol_ScrollbarGrab, UI_CONTROL_HOVER);
    c(ImGuiCol_ScrollbarGrabHovered, UI_CONTROL_ACTIVE);
    c(ImGuiCol_ScrollbarGrabActive, accent(0.80));
    c(ImGuiCol_ResizeGrip, accent(0.20));
    c(ImGuiCol_ResizeGripHovered, accent(0.45));
    c(ImGuiCol_ResizeGripActive, accent(0.70));
    c(ImGuiCol_Tab, UI_CONTROL);
    c(ImGuiCol_TabHovered, accent(0.30));
    c(ImGuiCol_TabActive, accent(0.38));
    c(ImGuiCol_PlotHistogram, UI_ACCENT);

    v(ImGuiStyleVar_WindowRounding, 6.0);
    v(ImGuiStyleVar_ChildRounding, 4.0);
    v(ImGuiStyleVar_FrameRounding, 4.0);
    v(ImGuiStyleVar_PopupRounding, 4.0);
    v(ImGuiStyleVar_ScrollbarRounding, 6.0);
    v(ImGuiStyleVar_GrabRounding, 4.0);
    v(ImGuiStyleVar_ScrollbarSize, 11.0);
    v(ImGuiStyleVar_WindowPadding, { 10, 8 });
    v(ImGuiStyleVar_FramePadding, { 7, 3 });
    v(ImGuiStyleVar_ItemSpacing, { 6, 4 });

    theme_stack[#theme_stack + 1] = { nc, nv };
end

local function pop_theme()
    local e = table.remove(theme_stack);
    if e == nil then return; end
    if e[2] > 0 then imgui.PopStyleVar(e[2]); end
    if e[1] > 0 then imgui.PopStyleColor(e[1]); end
end

local function draw_item_underline()
    if imgui.GetItemRectMin == nil then return; end
    local min_x = imgui.GetItemRectMin();
    local max_x, max_y = imgui.GetItemRectMax();
    min_x = tonumber(min_x); max_x = tonumber(max_x); max_y = tonumber(max_y);
    if min_x == nil or max_x == nil or max_y == nil then return; end
    imgui.GetWindowDrawList():AddRectFilled({ min_x + 4, max_y - 2 }, { max_x - 4, max_y }, imgui.GetColorU32(UI_ACCENT), 1.0);
end

-- Flat styled tab: accent text + 2px underline when selected.
local function styled_tab(label, id, selected)
    if selected then
        imgui.PushStyleColor(ImGuiCol_Button, accent(0.14));
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, accent(0.20));
        imgui.PushStyleColor(ImGuiCol_ButtonActive, accent(0.26));
        imgui.PushStyleColor(ImGuiCol_Text, UI_ACCENT_TEXT);
    else
        imgui.PushStyleColor(ImGuiCol_Button, { UI_CONTROL[1], UI_CONTROL[2], UI_CONTROL[3], 0.55 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, UI_CONTROL_HOVER);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, UI_CONTROL_ACTIVE);
        imgui.PushStyleColor(ImGuiCol_Text, UI_MUTED);
    end
    local clicked = imgui.Button(label .. '##' .. id);
    if selected then draw_item_underline(); end
    imgui.PopStyleColor(4);
    return clicked;
end

-- Rounded filter chip.
local function chip(label, id, selected)
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 10.0);
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 9, 2 });
    imgui.PushStyleColor(ImGuiCol_Button, selected and accent(0.28) or UI_CONTROL);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, selected and accent(0.36) or UI_CONTROL_HOVER);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, accent(0.44));
    imgui.PushStyleColor(ImGuiCol_Text, selected and UI_ACCENT_TEXT or UI_MUTED);
    local clicked = imgui.Button(label .. '##' .. id);
    imgui.PopStyleColor(4);
    imgui.PopStyleVar(2);
    return clicked;
end

local function section_header(title)
    imgui.TextColored(UI_ACCENT_TEXT, title);
    imgui.PushStyleColor(ImGuiCol_Separator, accent(0.35));
    imgui.Separator();
    imgui.PopStyleColor(1);
    imgui.Spacing();
end

local function help_marker(text)
    imgui.SameLine();
    imgui.TextDisabled('(?)');
    if imgui.IsItemHovered() then
        imgui.BeginTooltip();
        imgui.PushTextWrapPos(380);
        imgui.TextUnformatted(text);
        imgui.PopTextWrapPos();
        imgui.EndTooltip();
    end
end

local function text_w(s)
    return tonumber((imgui.CalcTextSize(tostring(s)))) or 0;
end

local function align_label()
    if imgui.AlignTextToFramePadding ~= nil then imgui.AlignTextToFramePadding(); end
end

-- BeginChild across Ashita builds (new: child_flags int, old: border bool).
local function begin_child(id, size, window_flags)
    window_flags = window_flags or 0;
    local ok, result = pcall(imgui.BeginChild, id, size, 0, window_flags);
    if ok then return result; end
    return imgui.BeginChild(id, size, false, window_flags);
end

-- ============================================================================
-- Settings
-- ============================================================================

local defaults = T{
    visible = true,
    config_visible = false,
    theme = UI_THEME_DEFAULT,
    background = T{ 0.035, 0.035, 0.040, 0.94 },
    locked = false,
    title_bar = false,
    window = T{ x = 220, y = 180, w = 440, h = 560 },
    config_window = T{ x = 700, y = 180, w = 470, h = 540 },

    view = 'list',             -- 'list' | 'grid' | 'categories'
    font_scale = 1.0,
    icon_size = 24,            -- list view icon (px, before font scale)
    grid_icon = 40,            -- grid view cell (px, before font scale)
    row_spacing = 2,
    show_qty_one = false,
    show_tags = true,          -- [E] / Rare / Ex tags in list view

    text_effect = 'shadow',    -- none | shadow | outline | both | glow
    effect_color = T{ 0.0, 0.0, 0.0 },
    effect_opacity = 0.85,
    name_color = T{ 0.93, 0.93, 0.95, 1.0 },
    qty_color = T{ 0.96, 0.80, 0.45, 1.0 },

    sort = 'slot',             -- slot | name | type | qty | newest
    sort_desc = false,
    bag = 0,                   -- selected tab; -1 = All
    hidden_bags = T{},         -- [bag_id] = true to hide its tab

    new_highlight = true,
    new_seconds = 10,

    keybind = T{ enabled = true, key = 0x49, ctrl = false, alt = false, shift = false },

    -- 1.1.0
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

    -- 1.2.0
    filter = 'all',            -- main window filter chip
    hidden = false,            -- every window hidden with the open key
    popouts = T{},             -- Shift+Click pop-out windows (one per tab)
    popout_saved = T{},        -- [tostring(bag)] = last size / position / view of a closed pop-out
};

local config = settings.load(defaults);

-- ============================================================================
-- State
-- ============================================================================

local state = {
    visible = { config.visible ~= false },
    config_visible = { config.config_visible == true },
    main_rt = { search = { '' }, cache = nil, key = nil, apply_geometry = true },
    pop_rt = {},               -- [bag] = runtime bits of a pop-out window
    hidden = config.hidden == true, -- open key hid every window
    view_gen = 0,              -- bumped when rows / favorites change
    apply_config_geometry = true,
    settings_dirty = false,
    last_save = 0,
    config_tab = 1,

    rows_dirty = true,
    last_scan = 0,
    bags = {},                 -- [bag] = { max, used, rows = {} }
    bag_order = {},            -- visible bag ids in order
    gil = 0,
    equipped = {},             -- ['bag:index'] = slot id

    prev_counts = nil,         -- [bag] = { [item_id] = count }
    baseline_until = 0,        -- ignore count changes until this clock (zoning)
    new_at = {},               -- [bag] = { [item_id] = clock }
    first_seen = {},           -- [item_id] = clock (for "newest" sort)

    -- 1.1.0
    log = {},                  -- session loot log: { time, id, qty }
    log_visible = { false },
    apply_log_geometry = true,
    session_start = os.time(),
    session_gil = nil,         -- gil at session start
    prev_totals = nil,         -- [item_id] = count across carried bags
    warn_until = 0,            -- inventory-full banner shown until (clock)
    last_inv_used = nil,
    key_items = nil,           -- { {id, name} } cache for the Key Items tab
    key_items_at = 0,
    player_name = nil,

    ctx = nil,                 -- row for the right-click menu
    drop = nil,                -- { row, qty, armed_at } for the drop dialog
    listening = false,         -- keybind capture
    mods = { ctrl = false, alt = false, shift = false },
};

local function mark_dirty() state.settings_dirty = true; end

-- Real Ctrl / Alt / Shift state from Windows. Tracking them from key events
-- alone can get stuck (e.g. Alt+Tab: the Alt release goes to another
-- window), which made the open key stop working until a reload.
pcall(ffi.cdef, 'short __stdcall GetAsyncKeyState(int vKey);');

local function mod_down(vk, fallback)
    local ok, v = pcall(function() return ffi.C.GetAsyncKeyState(vk); end);
    if ok and v ~= nil then return bit.band(tonumber(v) or 0, 0x8000) ~= 0; end
    return fallback == true;
end

local function current_mods()
    state.mods.ctrl = mod_down(0x11, state.mods.ctrl);
    state.mods.alt = mod_down(0x12, state.mods.alt);
    state.mods.shift = mod_down(0x10, state.mods.shift);
    return state.mods;
end


-- The window being drawn: V = its settings (config for the main window, a
-- pop-out entry otherwise), VS = its runtime bits (search, row cache).
local V, VS = config, state.main_rt;

-- ============================================================================
-- Bags, items, icons
-- ============================================================================

local BAG_NAMES = {
    [0] = 'Inventory', [1] = 'Safe', [2] = 'Storage', [3] = 'Temporary',
    [4] = 'Locker', [5] = 'Satchel', [6] = 'Sack', [7] = 'Case',
    [8] = 'Wardrobe', [9] = 'Safe 2', [10] = 'Wardrobe 2', [11] = 'Wardrobe 3',
    [12] = 'Wardrobe 4', [13] = 'Wardrobe 5', [14] = 'Wardrobe 6', [15] = 'Wardrobe 7',
    [16] = 'Wardrobe 8',
};
local BAG_MAX_ID = 16;
-- Tab order (bags you don't have are skipped).
local TAB_ORDER = { 0, 1, 5, 9, 8, 10, 11, 12, 13, 14, 15, 16, 2, 4, 6, 7, 3 };
-- Mog House storage: shown for viewing, no actions.
local VIEW_ONLY_BAG = { [1] = true, [2] = true, [4] = true, [9] = true };
local EQUIP_BAG = { [0] = true, [8] = true, [10] = true, [11] = true, [12] = true,
    [13] = true, [14] = true, [15] = true, [16] = true };

local EQUIP_SLOTS = {
    [0] = 'main', [1] = 'sub', [2] = 'range', [3] = 'ammo', [4] = 'head', [5] = 'body',
    [6] = 'hands', [7] = 'legs', [8] = 'feet', [9] = 'neck', [10] = 'waist', [11] = 'ear1',
    [12] = 'ear2', [13] = 'ring1', [14] = 'ring2', [15] = 'back',
};
local SLOT_LABELS = {
    [0] = 'Main', [1] = 'Sub', [2] = 'Range', [3] = 'Ammo', [4] = 'Head', [5] = 'Body',
    [6] = 'Hands', [7] = 'Legs', [8] = 'Feet', [9] = 'Neck', [10] = 'Waist', [11] = 'Ear 1',
    [12] = 'Ear 2', [13] = 'Ring 1', [14] = 'Ring 2', [15] = 'Back',
};
local JOBS = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG',
    'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH' };

local TYPE_WEAPON, TYPE_ARMOR, TYPE_USABLE, TYPE_CRYSTAL = 4, 5, 7, 8;
local FLAG_RARE, FLAG_EX = 0x8000, 0x6040;

local FILTERS = {
    { key = 'all', label = 'All' },
    { key = 'weapon', label = 'Weapons' },
    { key = 'armor', label = 'Armor' },
    { key = 'usable', label = 'Usable' },
    { key = 'crystal', label = 'Crystals' },
    { key = 'material', label = 'Materials' },
    { key = 'rareex', label = 'Rare / Ex' },
    { key = 'favorites', label = 'Favorites' },
};

local item_cache = {};   -- [id] = info table
local icon_cache = {};   -- [id] = { tex = texture, id = imgui id } or false

local function clean_desc(text)
    text = tostring(text or '');
    text = text:gsub('\x81\x60', '~')
        :gsub('\xEF\x1F', 'Fire'):gsub('\xEF\x20', 'Ice'):gsub('\xEF\x21', 'Wind')
        :gsub('\xEF\x22', 'Earth'):gsub('\xEF\x23', 'Lightning'):gsub('\xEF\x24', 'Water')
        :gsub('\xEF\x25', 'Light'):gsub('\xEF\x26', 'Dark');
    return text;
end

local function res_string(arr)
    local v = nil;
    pcall(function() v = arr[1] or arr[0]; end);
    if v == nil then return ''; end
    return tostring(v);
end

local function get_item_info(id)
    id = tonumber(id) or 0;
    if id <= 0 then return nil; end
    local cached = item_cache[id];
    if cached ~= nil then return cached or nil; end

    local rm = AshitaCore:GetResourceManager();
    local ok, res = pcall(function() return rm:GetItemById(id); end);
    if not ok or res == nil then
        item_cache[id] = false;
        return nil;
    end

    local info = { id = id };
    pcall(function() info.name = res_string(res.Name); end);
    pcall(function() info.desc = clean_desc(res_string(res.Description)); end);
    pcall(function() info.type = tonumber(res.Type) or 0; end);
    pcall(function() info.flags = tonumber(res.Flags) or 0; end);
    pcall(function() info.slots = tonumber(res.Slots) or 0; end);
    pcall(function() info.level = tonumber(res.Level) or 0; end);
    pcall(function() info.jobs = tonumber(res.Jobs) or 0; end);
    pcall(function() info.stack = tonumber(res.StackSize) or 1; end);
    pcall(function() info.bitmap = res.Bitmap; info.image_size = tonumber(res.ImageSize) or 0; end);
    info.name = (info.name ~= nil and info.name ~= '') and info.name or ('Item ' .. tostring(id));
    info.name_lower = info.name:lower();
    info.type = info.type or 0;
    info.flags = info.flags or 0;
    info.slots = info.slots or 0;
    info.rare = bit.band(info.flags, FLAG_RARE) ~= 0;
    info.ex = bit.band(info.flags, FLAG_EX) ~= 0;
    item_cache[id] = info;
    return info;
end

local function get_icon(info)
    if info == nil then return nil; end
    local cached = icon_cache[info.id];
    if cached ~= nil then return cached or nil; end
    icon_cache[info.id] = false;
    if info.bitmap == nil or (info.image_size or 0) <= 0 then return nil; end

    local ok, result = pcall(function()
        local ptr = ffi.new('IDirect3DTexture8*[1]');
        local hr = C.D3DXCreateTextureFromFileInMemoryEx(
            d3d.get_device(), info.bitmap, info.image_size, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
            C.D3DFMT_A8R8G8B8, C.D3DPOOL_MANAGED, C.D3DX_DEFAULT, C.D3DX_DEFAULT,
            0xFF000000, nil, nil, ptr);
        if hr ~= C.S_OK then return nil; end
        local tex = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
        return { tex = tex, id = tonumber(ffi.cast('uint32_t', tex)) };
    end);
    if ok and result ~= nil then
        icon_cache[info.id] = result;
        return result;
    end
    return nil;
end

local function get_inventory()
    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return nil; end
    return mm:GetInventory();
end

local function equip_slot_list(info)
    local list = {};
    if info == nil or info.slots == 0 then return list; end
    for s = 0, 15 do
        if bit.band(info.slots, bit.lshift(1, s)) ~= 0 then list[#list + 1] = s; end
    end
    return list;
end

local function jobs_text(mask)
    mask = tonumber(mask) or 0;
    local out, count = {}, 0;
    for i, j in ipairs(JOBS) do
        if bit.band(mask, bit.lshift(1, i)) ~= 0 then
            out[#out + 1] = j;
            count = count + 1;
        end
    end
    if count == 0 then return ''; end
    if count >= #JOBS - 2 then return 'All Jobs'; end
    return table.concat(out, '/');
end

local function fmt_gil(n)
    local s = tostring(math.floor(tonumber(n) or 0));
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse();
    return (out:gsub('^,', ''));
end

-- ============================================================================
-- Data files (shared by all your characters): prices and inventories
--   data\characters.lua      last known bags of every character you play
--   data\prices_learned.lua  exact sell prices seen at vendors (HorizonXI)
--   item_basic.sql           LandSandBoat price list (optional, you add it)
-- ============================================================================

-- Collapses doubled backslashes (addon.path may already end with one).
local function clean_path(p)
    return (tostring(p):gsub('\\\\+', '\\'));
end

local DATA_DIR = clean_path(addon.path .. '\\data\\');

local function ensure_data_dir()
    pcall(function()
        if ashita.fs.exists ~= nil and ashita.fs.exists(DATA_DIR) then return; end
        if ashita.fs.create_directory ~= nil then
            ashita.fs.create_directory(DATA_DIR);
        elseif ashita.fs.create_dir ~= nil then
            ashita.fs.create_dir(DATA_DIR);
        end
    end);
end

local function serialize(value, indent)
    indent = indent or '';
    local t = type(value);
    if t == 'number' then return tostring(value); end
    if t == 'boolean' then return value and 'true' or 'false'; end
    if t == 'string' then return ('%q'):format(value); end
    if t ~= 'table' then return 'nil'; end
    local inner = indent .. '  ';
    local parts = {};
    for k, v in pairs(value) do
        local key;
        if type(k) == 'number' then key = ('[%d]'):format(k);
        else key = ('[%q]'):format(tostring(k)); end
        parts[#parts + 1] = inner .. key .. ' = ' .. serialize(v, inner);
    end
    if #parts == 0 then return '{}'; end
    return '{\n' .. table.concat(parts, ',\n') .. '\n' .. indent .. '}';
end

local function load_lua_file(path)
    local ok, chunk = pcall(loadfile, path);
    if not ok or chunk == nil then return nil; end
    local ok2, data = pcall(chunk);
    if ok2 and type(data) == 'table' then return data; end
    return nil;
end

local function write_lua_file(path, data)
    ensure_data_dir();
    local f = io.open(path, 'w');
    if f == nil then return false; end
    f:write('return ' .. serialize(data) .. '\n');
    f:close();
    return true;
end

local prices = { base = {}, nosale = {}, ah = {}, loaded = false, count = 0, source = nil };
local learned = load_lua_file(DATA_DIR .. 'prices_learned.lua') or {};
local chars = load_lua_file(DATA_DIR .. 'characters.lua') or {};
-- Key item overrides you set with right-click (shared by all characters):
-- true = always TEMP, false = never TEMP. Anything not listed uses the
-- built-in list below.
local ki_temp = load_lua_file(DATA_DIR .. 'key_items_temp.lua') or {};

-- Built-in key item categories, by key item ID. The game doesn't tell addons
-- which key items are temporary, so this list decides:
--   permanent: listed IDs and the job gestures (1738-1757)
--   other:     maps, claim slips, Voidwatch and Abyssea items (never TEMP)
--   temporary: everything else
local KI_PERMANENT = {};
for _, id in ipairs({
    8, 9, 20, 21, 35, 36, 45, 46, 47, 56, 95, 116, 118, 136, 138, 142, 155, 162, 169, 195,
    347, 349, 351, 352, 353, 354, 355, 356, 357, 361, 365, 452, 455, 456, 457, 458, 459,
    595, 596, 604, 606, 619, 739, 740, 741, 742, 767, 771, 774, 781, 811, 812,
    829, 830, 831, 832, 833, 851, 852, 856, 857, 858, 859, 879, 880, 891, 909, 910,
}) do KI_PERMANENT[id] = true; end
for id = 1738, 1757 do KI_PERMANENT[id] = true; end

local function ki_auto_category(id, name_lower)
    id = tonumber(id) or 0;
    if KI_PERMANENT[id] then return 'permanent'; end
    if id == 383 or (id >= 385 and id <= 447) or (id >= 1858 and id <= 1918) then return 'other'; end
    if name_lower ~= nil and name_lower:sub(1, 7) == 'map of ' then return 'other'; end
    if id >= 861 and id <= 875 then return 'other'; end   -- claim slips
    if id >= 366 and id <= 377 then return 'other'; end   -- Voidwatch
    if id >= 1283 and id <= 1737 then return 'other'; end -- Abyssea
    return 'temporary';
end

-- 'permanent', 'temporary' or 'other', with your right-click override applied.
local function ki_category(id, name_lower)
    local auto = ki_auto_category(id, name_lower);
    local o = ki_temp[id];
    if o == true then return 'temporary', auto; end
    if o == false and auto == 'temporary' then return 'permanent', auto; end
    return auto, auto;
end
local chars_dirty = false;
local chars_saved_at = 0;

-- Reads LandSandBoat's item_basic.sql. Done once, the first time a price is
-- needed. Works with the current layout
--   (itemid, subid, 'name', 'sortname', 'name_jp', @TYPE, stackSize, @FLAGS | ..., @AH, BaseSell);
-- where "can't sell" is the @FLAG_NOSALE flag, and the older all-number one
--   (itemid, subid, 'name', 'sortname', stackSize, flags, aH, NoSale, BaseSell).
local FLAG_NOSALE_BIT = 0x1000;

local function trim(s)
    return (tostring(s):gsub('^%s+', ''):gsub('%s+$', ''));
end

-- Auction House categories (LandSandBoat's aH numbers).
local AH_PATHS = {
    [1] = 'Weapons > Hand-to-Hand', [2] = 'Weapons > Dagger', [3] = 'Weapons > Sword', [4] = 'Weapons > Great Sword',
    [5] = 'Weapons > Axe', [6] = 'Weapons > Great Axe', [7] = 'Weapons > Scythe', [8] = 'Weapons > Polearm',
    [9] = 'Weapons > Katana', [10] = 'Weapons > Great Katana', [11] = 'Weapons > Club', [12] = 'Weapons > Staff',
    [13] = 'Weapons > Ranged', [14] = 'Weapons > Instruments', [15] = 'Weapons > Ammo & Misc. > Ammunition',
    [16] = 'Armor > Shields', [17] = 'Armor > Head', [18] = 'Armor > Body', [19] = 'Armor > Hands',
    [20] = 'Armor > Legs', [21] = 'Armor > Feet', [22] = 'Armor > Neck', [23] = 'Armor > Waist',
    [24] = 'Armor > Earrings', [25] = 'Armor > Rings', [26] = 'Armor > Back',
    [28] = 'Scrolls > White Magic', [29] = 'Scrolls > Black Magic', [30] = 'Scrolls > Summoning',
    [31] = 'Scrolls > Ninjutsu', [32] = 'Scrolls > Songs', [33] = 'Medicines', [34] = 'Furnishings',
    [35] = 'Crystals', [36] = 'Others > Cards', [37] = 'Others > Cursed Items', [38] = 'Materials > Smithing',
    [39] = 'Materials > Goldsmithing', [40] = 'Materials > Clothcraft', [41] = 'Materials > Leathercraft',
    [42] = 'Materials > Bonecraft', [43] = 'Materials > Woodworking', [44] = 'Materials > Alchemy',
    [45] = 'Scrolls > Geomancy', [46] = 'Others > Misc.', [47] = 'Weapons > Ammo & Misc. > Fishing Gear',
    [48] = 'Weapons > Ammo & Misc. > Pet Items', [49] = 'Others > Ninja Tools', [50] = 'Others > Beast-made',
    [51] = 'Food > Fish', [52] = 'Food > Meals > Meat & Eggs', [53] = 'Food > Meals > Seafood',
    [54] = 'Food > Meals > Vegetables', [55] = 'Food > Meals > Soups', [56] = 'Food > Meals > Breads & Rice',
    [57] = 'Food > Meals > Sweets', [58] = 'Food > Meals > Drinks', [59] = 'Food > Ingredients',
    [60] = 'Scrolls > Dice', [61] = 'Others > Automaton', [62] = 'Weapons > Ammo & Misc. > Grips',
    [63] = 'Materials > Alchemy 2', [64] = 'Others > Misc. 2', [65] = 'Others > Misc. 3',
};
local ah_vars = {};   -- [@NAME] = number, from the SET lines at the top of the file

local function parse_ah_value(v)
    v = trim(v or '');
    if v:sub(1, 1) == '@' then return ah_vars[v:sub(2)]; end
    return tonumber(v);
end

local function parse_price_line(line)
    if line:find('^INSERT INTO `item_basic` VALUES %(') == nil then return nil; end
    local stop = line:find(');', 1, true);   -- anything after is a comment
    if stop == nil then return nil; end
    local vals = line:sub(1, stop - 1);
    local id = tonumber(vals:match('VALUES %((%d+),'));
    if id == nil then return nil; end

    -- The number fields come after the last quoted name.
    local q, pos = nil, 1;
    while true do
        local s = vals:find("'", pos, true);
        if s == nil then break; end
        q, pos = s, s + 1;
    end
    if q == nil then return nil; end
    local f = {};
    for field in vals:sub(q + 1):gmatch('[^,]+') do f[#f + 1] = trim(field); end
    if #f ~= 5 then return nil; end

    local sell = tonumber(f[5]);
    if sell == nil then return nil; end
    local nosale = false;
    local ah = nil;
    if f[1]:sub(1, 1) == '@' then
        ah = parse_ah_value(f[4]);
        -- Current layout: type, stack, flags, aH, BaseSell.
        local flags = f[3];
        if flags:find('FLAG_NOSALE', 1, true) ~= nil then
            nosale = true;
        elseif tonumber(flags) ~= nil then
            nosale = bit.band(tonumber(flags), FLAG_NOSALE_BIT) ~= 0;
        end
    else
        -- Older layout: stack, flags, aH, NoSale, BaseSell.
        nosale = tonumber(f[4]) == 1;
        ah = tonumber(f[3]);
    end
    return id, sell, nosale, ah;
end

local function load_price_list()
    if prices.loaded then return; end
    prices.loaded = true;
    local candidates = { clean_path(addon.path .. '\\item_basic.sql'), DATA_DIR .. 'item_basic.sql' };
    for _, path in ipairs(candidates) do
        local f = io.open(path, 'r');
        if f ~= nil then
            local count = 0;
            for line in f:lines() do
                local var, num = line:match('^SET @([%w_]+)%s*=%s*(%d+)%s*;');
                if var ~= nil then
                    ah_vars[var] = tonumber(num);
                else
                    local id, sell, nosale, ah = parse_price_line(line);
                    if id ~= nil then
                        prices.base[id] = sell;
                        if nosale then prices.nosale[id] = true; end
                        if ah ~= nil then prices.ah[id] = ah; end
                        count = count + 1;
                    end
                end
            end
            f:close();
            prices.count = count;
            prices.source = path;
            return;
        end
    end
end

-- Sell price per item: value, source ('vendor' exact | 'list' | 'nosale' | nil).
local function price_of(id)
    id = tonumber(id) or 0;
    local l = learned[id];
    if l ~= nil then return tonumber(l), 'vendor'; end
    load_price_list();
    if prices.nosale[id] then return nil, 'nosale'; end
    local b = prices.base[id];
    if b ~= nil then return b, 'list'; end
    return nil, nil;
end

-- Auction House category path, 'none' when it isn't sold there, or nil.
local function ah_of(id)
    load_price_list();
    local n = prices.ah[tonumber(id) or 0];
    if n == nil then return nil; end
    if n == 0 then return 'none'; end
    return AH_PATHS[n];
end

local function learn_price(id, value)
    id = tonumber(id) or 0;
    value = tonumber(value) or -1;
    if id <= 0 or value < 0 then return; end
    if learned[id] == value then return; end
    learned[id] = value;
    write_lua_file(DATA_DIR .. 'prices_learned.lua', learned);
end

local function get_player_name()
    local name = nil;
    pcall(function()
        name = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0);
    end);
    if name == nil or tostring(name) == '' then return nil; end
    return tostring(name);
end

local function save_chars(force)
    if not chars_dirty and not force then return; end
    if not force and os.clock() - chars_saved_at < 20 then return; end
    chars_dirty = false;
    chars_saved_at = os.clock();
    write_lua_file(DATA_DIR .. 'characters.lua', chars);
end

-- Bags you carry (count toward the loot log); Mog House bags do not.
local CARRIED_BAG = { [0] = true, [3] = true, [5] = true, [6] = true, [7] = true, [8] = true,
    [10] = true, [11] = true, [12] = true, [13] = true, [14] = true, [15] = true, [16] = true };

local function rows_from_list(list, bag, source, char)
    local rows = {};
    for k, e in ipairs(list or {}) do
        local id, count = tonumber(e[1]) or 0, tonumber(e[2]) or 0;
        local info = get_item_info(id);
        if info ~= nil and count > 0 then
            rows[#rows + 1] = {
                bag = bag, index = k, id = id, count = count, info = info, source = source, char = char,
                uid = ('%s_%s_%d_%d'):fmt(source or 'live', tostring(char or ''), bag, k),
            };
        end
    end
    return rows;
end

-- Marks partial stacks of the same item in one bag (they could be merged).
local function mark_split(rows)
    local groups = {};
    for _, r in ipairs(rows) do
        local st = tonumber(r.info.stack) or 1;
        if st > 1 and r.count < st then
            groups[r.id] = groups[r.id] or {};
            table.insert(groups[r.id], r);
        end
    end
    for _, g in pairs(groups) do
        if #g >= 2 then
            local total = 0;
            for _, r in ipairs(g) do total = total + r.count; end
            for _, r in ipairs(g) do r.split = #g; r.split_total = total; end
        end
    end
end

local function list_signature(list)
    local parts = {};
    for _, e in ipairs(list) do parts[#parts + 1] = e[1] .. 'x' .. e[2]; end
    return table.concat(parts, ',');
end

-- Reads every bag. Runs on inventory packets, about once a second while the
-- window is open, and every few seconds in the background (loot log / gil).
local function scan_bags()
    local inv = get_inventory();
    if inv == nil then return; end
    local now = os.clock();

    state.player_name = get_player_name() or state.player_name;
    local me = nil;
    if state.player_name ~= nil then
        me = chars[state.player_name];
        if me == nil then
            me = { bags = {}, mh_time = {} };
            chars[state.player_name] = me;
        end
        me.bags = me.bags or {};
        me.mh_time = me.mh_time or {};
        state.bag_sig = state.bag_sig or {};
    end

    -- Equipped items.
    local equipped = {};
    for slot = 0, 15 do
        local ok, e = pcall(function() return inv:GetEquippedItem(slot); end);
        if ok and e ~= nil and tonumber(e.Index) ~= nil and tonumber(e.Index) ~= 0 then
            local idx = tonumber(e.Index);
            local bag = math.floor(bit.band(idx, 0xFF00) / 0x100);
            local pos = idx % 0x100;
            equipped[('%d:%d'):fmt(bag, pos)] = slot;
        end
    end
    state.equipped = equipped;

    local bags, order = {}, {};
    local counts, totals, mh_totals = {}, {}, {};
    for bag = 0, BAG_MAX_ID do
        local ok_max, max = pcall(function() return inv:GetContainerCountMax(bag); end);
        max = ok_max and (tonumber(max) or 0) or 0;
        local rows, used = {}, 0;
        if max > 0 then
            counts[bag] = {};
            for index = 1, max do
                local ok, item = pcall(function() return inv:GetContainerItem(bag, index); end);
                if ok and item ~= nil then
                    local id = tonumber(item.Id) or 0;
                    local count = tonumber(item.Count) or 0;
                    if id > 0 and id ~= 65535 and count > 0 then
                        used = used + 1;
                        local info = get_item_info(id);
                        if info ~= nil then
                            rows[#rows + 1] = {
                                bag = bag, index = index, id = id, count = count, info = info,
                                equipped = equipped[('%d:%d'):fmt(bag, index)],
                                uid = ('live_%d_%d'):fmt(bag, index),
                            };
                            counts[bag][id] = (counts[bag][id] or 0) + count;
                            if CARRIED_BAG[bag] then totals[id] = (totals[id] or 0) + count; end
                            if VIEW_ONLY_BAG[bag] then mh_totals[id] = (mh_totals[id] or 0) + count; end
                            if state.first_seen[id] == nil then state.first_seen[id] = now; end
                        end
                    end
                end
            end
        end

        -- Remember this character's bags (Characters tab, Mog House snapshots).
        if me ~= nil and used > 0 then
            local list = {};
            for _, r in ipairs(rows) do list[#list + 1] = { r.id, r.count }; end
            local sig = list_signature(list);
            if state.bag_sig[bag] ~= sig then
                state.bag_sig[bag] = sig;
                me.bags[bag] = list;
                me.updated = os.time();
                if VIEW_ONLY_BAG[bag] then me.mh_time[bag] = os.time(); end
                chars_dirty = true;
            end
        end

        if VIEW_ONLY_BAG[bag] and used == 0 and me ~= nil and me.bags[bag] ~= nil and #me.bags[bag] > 0 then
            -- Not loaded right now: show the last snapshot (view only).
            local snap = rows_from_list(me.bags[bag], bag, 'snapshot', nil);
            mark_split(snap);
            bags[bag] = { max = math.max(max, #snap), used = #snap, rows = snap, snapshot = me.mh_time[bag] };
        elseif max > 0 then
            mark_split(rows);
            bags[bag] = { max = max, used = used, rows = rows };
        end
    end
    for _, bag in ipairs(TAB_ORDER) do
        if bags[bag] ~= nil and not (config.hidden_bags and config.hidden_bags[bag]) then
            if bag ~= 3 or bags[bag].used > 0 then order[#order + 1] = bag; end
        end
    end

    -- Gil lives in inventory slot 0.
    local inv_loaded = bags[0] ~= nil and bags[0].used > 0;
    local ok_gil, gil = pcall(function() return inv:GetContainerItem(0, 0); end);
    if ok_gil and gil ~= nil and inv_loaded then
        state.gil = tonumber(gil.Count) or state.gil;
        if state.session_gil == nil then state.session_gil = state.gil; end
        local today = os.date('%Y-%m-%d');
        if config.gil_day ~= today or (tonumber(config.gil_day_start) or -1) < 0 then
            config.gil_day = today;
            config.gil_day_start = state.gil;
            mark_dirty();
        end
    end

    local settled = now > state.baseline_until;

    -- New-item highlight: count went up in a bag since the last scan.
    if state.prev_counts ~= nil and settled then
        for bag, ids in pairs(counts) do
            local before = state.prev_counts[bag];
            if before ~= nil then
                for id, count in pairs(ids) do
                    if count > (before[id] or 0) then
                        state.new_at[bag] = state.new_at[bag] or {};
                        state.new_at[bag][id] = now;
                        state.first_seen[id] = now;
                    end
                end
            end
        end
    end

    -- Loot log: items gained across carried bags (moves between them don't
    -- count, and neither does taking things out of Mog House storage).
    if state.prev_totals ~= nil and settled then
        local prev_mh = state.prev_mh or {};
        for id, count in pairs(totals) do
            local gain = count - (state.prev_totals[id] or 0);
            if gain > 0 then
                local from_mh = (prev_mh[id] or 0) - (mh_totals[id] or 0);
                if from_mh > 0 then gain = gain - from_mh; end
                if gain > 0 then
                    table.insert(state.log, 1, { time = os.time(), id = id, qty = gain });
                end
            end
        end
        while #state.log > 300 do table.remove(state.log); end
    end

    -- Inventory-full warning when a new item arrives near the limit.
    local inv0 = bags[0];
    if inv0 ~= nil and inv_loaded then
        local free = inv0.max - inv0.used;
        if config.warn_full and settled and state.last_inv_used ~= nil and inv0.used > state.last_inv_used
            and free <= (tonumber(config.warn_free) or 5) then
            state.warn_until = now + 5.0;
        end
        state.last_inv_used = inv0.used;
    end

    -- An empty inventory usually means zoning / loading: rebase.
    if not inv_loaded then
        state.prev_counts = nil;
        state.prev_totals = nil;
        state.prev_mh = nil;
        state.last_inv_used = nil;
        state.baseline_until = now + 3.0;
    else
        state.prev_counts = counts;
        state.prev_totals = totals;
        state.prev_mh = mh_totals;
    end

    state.bags = bags;
    state.bag_order = order;
    state.view_gen = state.view_gen + 1;
    state.rows_dirty = false;
    state.last_scan = now;
end

-- ============================================================================
-- Filtering / sorting (cached per scan + settings)
-- ============================================================================

local function row_matches_filter(row, filter)
    local info = row.info;
    if filter == 'weapon' then return info.type == TYPE_WEAPON; end
    if filter == 'armor' then return info.type == TYPE_ARMOR; end
    if filter == 'usable' then return info.type == TYPE_USABLE; end
    if filter == 'crystal' then return info.type == TYPE_CRYSTAL; end
    if filter == 'material' then
        return info.type ~= TYPE_WEAPON and info.type ~= TYPE_ARMOR and info.type ~= TYPE_USABLE and info.type ~= TYPE_CRYSTAL;
    end
    if filter == 'rareex' then return info.rare or info.ex; end
    if filter == 'favorites' then return config.favorites ~= nil and config.favorites[row.id] == true; end
    return true;
end

local function get_view_rows()
    local key = table.concat({ tostring(state.view_gen), tostring(V.bag), tostring(V.filter), tostring(VS.search[1] or ''):lower(),
        tostring(V.sort), tostring(V.sort_desc), tostring(V.view), tostring(config.pin_favorites) }, '|');
    if VS.cache ~= nil and VS.key == key then return VS.cache; end

    local query = tostring(VS.search[1] or ''):lower():gsub('^%s+', ''):gsub('%s+$', '');
    local rows = {};
    local function add_bag(bag)
        local b = state.bags[bag];
        if b == nil then return; end
        for _, row in ipairs(b.rows) do
            if row_matches_filter(row, V.filter)
                and (query == '' or row.info.name_lower:find(query, 1, true) ~= nil) then
                rows[#rows + 1] = row;
            end
        end
    end
    local function add_rows(list)
        for _, row in ipairs(list) do
            if row_matches_filter(row, V.filter)
                and (query == '' or row.info.name_lower:find(query, 1, true) ~= nil) then
                rows[#rows + 1] = row;
            end
        end
    end
    if V.bag == -1 then
        for _, bag in ipairs(state.bag_order) do add_bag(bag); end
    elseif V.bag == -2 then
        -- Every character's last known bags (view only).
        for name, rec in pairs(chars) do
            for bag, list in pairs(rec.bags or {}) do
                add_rows(rows_from_list(list, tonumber(bag) or 0, 'alt', name));
            end
        end
    else
        add_bag(V.bag);
    end

    local mode, desc = V.sort, V.sort_desc == true;
    local pin = config.pin_favorites ~= false and V.view ~= 'categories';
    local favs = config.favorites or {};
    table.sort(rows, function(a, b)
        if pin then
            local fa, fb = favs[a.id] == true, favs[b.id] == true;
            if fa ~= fb then return fa; end
        end
        if V.bag == -2 and a.char ~= b.char and mode == 'slot' then
            return tostring(a.char) < tostring(b.char);
        end
        local av, bv;
        if mode == 'name' then av, bv = a.info.name_lower, b.info.name_lower;
        elseif mode == 'type' then av, bv = a.info.type, b.info.type;
        elseif mode == 'qty' then av, bv = a.count, b.count;
        elseif mode == 'newest' then av, bv = -(state.first_seen[a.id] or 0), -(state.first_seen[b.id] or 0);
        else av, bv = a.bag * 1000 + a.index, b.bag * 1000 + b.index; end
        if av == bv then
            if a.info.name_lower == b.info.name_lower then
                if a.char ~= b.char then return tostring(a.char) < tostring(b.char); end
                return (a.bag * 1000 + a.index) < (b.bag * 1000 + b.index);
            end
            return a.info.name_lower < b.info.name_lower;
        end
        if desc then return av > bv; end
        return av < bv;
    end);

    VS.cache = rows;
    VS.key = key;
    return rows;
end

-- ============================================================================
-- Text with effects (draw list, cheap: a few extra AddText passes)
-- ============================================================================

local EFFECTS = {
    { key = 'none', label = 'None' },
    { key = 'shadow', label = 'Shadow' },
    { key = 'outline', label = 'Outline' },
    { key = 'both', label = 'Outline + Shadow' },
    { key = 'glow', label = 'Glow' },
};

local function draw_fx_text(dl, x, y, color, text)
    local font, size = imgui.GetFont(), imgui.GetFontSize();
    local eff = config.text_effect;
    if eff ~= 'none' then
        local ec = config.effect_color;
        local a = (tonumber(config.effect_opacity) or 0.85) * (color[4] or 1.0);
        local col = imgui.GetColorU32({ ec[1], ec[2], ec[3], a });
        if eff == 'outline' or eff == 'both' then
            dl:AddText(font, size, { x - 1, y }, col, text);
            dl:AddText(font, size, { x + 1, y }, col, text);
            dl:AddText(font, size, { x, y - 1 }, col, text);
            dl:AddText(font, size, { x, y + 1 }, col, text);
        end
        if eff == 'shadow' or eff == 'both' then
            dl:AddText(font, size, { x + 1, y + 1 }, col, text);
            if eff == 'shadow' then
                dl:AddText(font, size, { x + 2, y + 2 }, imgui.GetColorU32({ ec[1], ec[2], ec[3], a * 0.45 }), text);
            end
        end
        if eff == 'glow' then
            local gcol = imgui.GetColorU32({ ec[1], ec[2], ec[3], a * 0.35 });
            for ox = -2, 2 do
                for oy = -2, 2 do
                    if ox ~= 0 or oy ~= 0 then dl:AddText(font, size, { x + ox, y + oy }, gcol, text); end
                end
            end
        end
    end
    dl:AddText(font, size, { x, y }, imgui.GetColorU32(color), text);
end

-- ============================================================================
-- Actions (only ever on click)
-- ============================================================================

local function queue(cmd)
    AshitaCore:GetChatManager():QueueCommand(1, cmd);
end

local function do_use(row)
    queue(('/item "%s" <me>'):fmt(row.info.name));
end

local function do_equip(row, slot)
    local s = EQUIP_SLOTS[slot];
    if s == nil then return; end
    queue(('/equip %s "%s"'):fmt(s, row.info.name));
end

-- Drop: the same packet the game's own Drop sends (0x028: quantity, bag, slot).
local function do_drop(row, qty)
    qty = math.max(1, math.min(tonumber(qty) or 1, row.count));
    local data = {
        0x28, 0x06, 0x00, 0x00,
        bit.band(qty, 0xFF), bit.band(bit.rshift(qty, 8), 0xFF), bit.band(bit.rshift(qty, 16), 0xFF), bit.band(bit.rshift(qty, 24), 0xFF),
        row.bag, row.index, 0x00, 0x00,
    };
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x28, data);
    state.rows_dirty = true;
end

local function is_favorite(row)
    return config.favorites ~= nil and config.favorites[row.id] == true;
end

-- Can your current job / level wear this? (true for non-gear)
local function can_wear(info)
    if info.type ~= TYPE_WEAPON and info.type ~= TYPE_ARMOR then return true; end
    local job, lvl = state.job or 0, state.level or 0;
    if job <= 0 then return true; end
    if (info.jobs or 0) ~= 0 and bit.band(info.jobs, bit.lshift(1, job)) == 0 then return false, 'job'; end
    if (info.level or 0) > lvl then return false, 'level'; end
    return true;
end

-- Live rows only (not snapshots or other characters).
local function can_use(row)
    return row.source == nil and row.info.type == TYPE_USABLE and (row.bag == 0 or row.bag == 3);
end

local function can_equip(row)
    return row.source == nil and (row.info.type == TYPE_WEAPON or row.info.type == TYPE_ARMOR) and EQUIP_BAG[row.bag] == true
        and row.equipped == nil and #equip_slot_list(row.info) > 0;
end

local function can_drop(row)
    return row.source == nil and row.bag == 0 and row.equipped == nil;
end

-- "Sells for ..." line and its color.
local function value_line(row)
    local each, src = price_of(row.id);
    if src == 'nosale' then return "Can't be sold to NPCs", UI_MUTED; end
    if each == nil then return 'Sell price unknown (learned when a vendor appraises it)', UI_MUTED; end
    local t = ('Sells for %s gil'):fmt(fmt_gil(each));
    if row.count > 1 then t = t .. (' (%s for %d)'):fmt(fmt_gil(each * row.count), row.count); end
    t = t .. ((src == 'vendor') and '  [vendor]' or '  [price list]');
    return t, config.qty_color;
end

local function rows_value(rows)
    local total, known = 0, 0;
    for _, row in ipairs(rows) do
        local each = price_of(row.id);
        if each ~= nil then
            total = total + each * row.count;
            known = known + 1;
        end
    end
    return total, known;
end

-- ============================================================================
-- Tooltip and context menu
-- ============================================================================

local function draw_tooltip(row)
    local info = row.info;
    imgui.BeginTooltip();
    imgui.PushTextWrapPos(math.floor(340 * (tonumber(config.font_scale) or 1.0)));
    imgui.TextColored(UI_ACCENT_TEXT, info.name);
    if info.rare or info.ex then
        imgui.SameLine();
        imgui.TextColored(UI_MUTED, (info.rare and '[Rare]' or '') .. (info.ex and '[Ex]' or ''));
    end
    if row.equipped ~= nil then
        imgui.TextColored(UI_ACCENT, ('Equipped (%s)'):fmt(SLOT_LABELS[row.equipped] or '?'));
    end
    if info.type == TYPE_WEAPON or info.type == TYPE_ARMOR then
        local slots = {};
        for _, s in ipairs(equip_slot_list(info)) do slots[#slots + 1] = SLOT_LABELS[s]; end
        if #slots > 0 then imgui.TextColored(UI_MUTED, '[' .. table.concat(slots, ' / ') .. ']'); end
    end
    if info.desc ~= nil and info.desc ~= '' then
        imgui.TextWrapped(info.desc);
    end
    if (info.level or 0) > 0 then
        imgui.TextColored(UI_MUTED, ('Lv %d  %s'):fmt(info.level, jobs_text(info.jobs)));
    end
    local wear_ok, why = can_wear(info);
    if not wear_ok then
        imgui.TextColored(UI_DANGER, why == 'level' and ("Your level is too low to equip this.") or "Your job can't equip this.");
    end
    if (info.stack or 1) > 1 then
        imgui.TextColored(UI_MUTED, ('Stack %d / %d'):fmt(row.count, info.stack));
    end
    if row.split ~= nil then
        imgui.TextColored(UI_ACCENT_TEXT, ('%d partial stacks in this bag (%d total) - could be merged'):fmt(row.split, row.split_total or 0));
    end
    if config.show_value ~= false then
        local text, col = value_line(row);
        imgui.TextColored(col, text);
        -- A full stack, owned or not (is buying one on the AH worth it?).
        local each = price_of(row.id);
        local stack = tonumber(info.stack) or 1;
        if each ~= nil and stack > 1 then
            imgui.TextColored(config.qty_color, ('Full stack (%d) sells for %s gil'):fmt(stack, fmt_gil(each * stack)));
        end
    end
    if config.show_ah ~= false then
        local ah = ah_of(row.id);
        if ah == 'none' then
            imgui.TextColored(UI_MUTED, 'Not sold on the Auction House');
        elseif ah ~= nil then
            imgui.TextColored(UI_MUTED, 'AH: ' .. ah);
        end
    end
    if is_favorite(row) then imgui.TextColored(UI_ACCENT_TEXT, 'Favorite'); end
    local where = BAG_NAMES[row.bag] or ('Bag ' .. tostring(row.bag));
    if row.source == 'alt' then
        where = tostring(row.char) .. ' - ' .. where;
    elseif row.source == 'snapshot' then
        local b = state.bags[row.bag];
        where = where .. ((b and b.snapshot) and (' (snapshot ' .. os.date('%Y-%m-%d %H:%M', b.snapshot) .. ')') or ' (snapshot)');
    end
    imgui.TextColored(UI_MUTED, where);
    imgui.PopTextWrapPos();
    imgui.EndTooltip();
end

local function draw_context_menu()
    if not imgui.BeginPopup('##nai_item_ctx') then return; end
    local row = state.ctx;
    if row == nil then
        imgui.EndPopup();
        return;
    end

    imgui.TextColored(UI_ACCENT_TEXT, row.info.name);
    if row.count > 1 then
        imgui.SameLine();
        imgui.TextColored(UI_MUTED, ('x%d'):fmt(row.count));
    end
    imgui.Separator();

    local any = true;
    if row.source == 'alt' then
        imgui.TextDisabled(('%s - %s (view only)'):fmt(tostring(row.char), BAG_NAMES[row.bag] or '?'));
    elseif VIEW_ONLY_BAG[row.bag] then
        imgui.TextDisabled('Mog House storage (view only)');
    end
    if imgui.Selectable((is_favorite(row) and 'Remove from favorites' or 'Add to favorites') .. '##nai_fav') then
        config.favorites = config.favorites or T{};
        config.favorites[row.id] = (not is_favorite(row)) or nil;
        state.view_gen = state.view_gen + 1;
        mark_dirty();
    end
    if can_use(row) then
        any = true;
        if imgui.Selectable('Use##nai_use') then do_use(row); end
    end
    if can_equip(row) then
        any = true;
        local slots = equip_slot_list(row.info);
        if #slots == 1 then
            if imgui.Selectable('Equip##nai_equip') then do_equip(row, slots[1]); end
        else
            for _, s in ipairs(slots) do
                if imgui.Selectable(('Equip to %s##nai_equip_%d'):fmt(SLOT_LABELS[s], s)) then do_equip(row, s); end
            end
        end
    elseif row.equipped ~= nil then
        any = true;
        imgui.TextDisabled(('Equipped (%s)'):fmt(SLOT_LABELS[row.equipped] or '?'));
    end
    if can_drop(row) then
        any = true;
        imgui.Separator();
        if is_favorite(row) then
            imgui.TextDisabled('Drop (remove from favorites first)');
        else
            imgui.PushStyleColor(ImGuiCol_Text, UI_DANGER);
            if imgui.Selectable('Drop...##nai_drop') then
                state.drop = { row = row, qty = { row.count }, armed_at = nil };
            end
            imgui.PopStyleColor(1);
        end
    end
    if not any then
        imgui.TextDisabled('No actions for this item here.');
    end
    imgui.EndPopup();
end

-- Drop dialog: quantity for stacks, second red click for Rare / Ex.
local function draw_drop_dialog()
    local d = state.drop;
    if d == nil then return; end
    local row = d.row;

    local dsize = imgui.GetIO().DisplaySize;
    imgui.SetNextWindowPos({ (tonumber(dsize.x) or 1920) * 0.5 - 170, (tonumber(dsize.y) or 1080) * 0.4 }, { 0, 0 });
    push_theme({ UI_POPUP[1], UI_POPUP[2], UI_POPUP[3], 0.98 }, config.theme);
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoMove);
    if imgui.Begin('NAInv Drop##nai_drop_dialog', nil, flags) then
        imgui.PushFont(nil, imgui.GetFontSize() * (tonumber(config.font_scale) or 1.0));
        imgui.TextColored(UI_DANGER, 'DROP ITEM');
        imgui.Text(row.info.name);
        if row.info.rare or row.info.ex then
            imgui.SameLine();
            imgui.TextColored(UI_MUTED, (row.info.rare and '[Rare]' or '') .. (row.info.ex and '[Ex]' or ''));
        end
        if row.count > 1 then
            imgui.PushItemWidth(220);
            imgui.SliderInt('Quantity##nai_drop_qty', d.qty, 1, row.count, '%d', ImGuiSliderFlags_AlwaysClamp);
            imgui.PopItemWidth();
        end
        if row.info.rare or row.info.ex then
            imgui.TextColored(UI_MUTED, 'Rare / Ex items are gone for good once dropped.');
        end
        imgui.Spacing();

        local needs_second = row.info.rare or row.info.ex;
        local armed = d.armed_at ~= nil and (os.clock() - d.armed_at) < 3.0;
        imgui.PushStyleColor(ImGuiCol_Button, armed and { 0.72, 0.16, 0.16, 1.0 } or { 0.45, 0.12, 0.12, 1.0 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.80, 0.20, 0.20, 1.0 });
        imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.90, 0.24, 0.24, 1.0 });
        imgui.PushStyleColor(ImGuiCol_Text, UI_WHITE);
        local label = (needs_second and not armed) and 'Drop (click twice)' or (armed and 'Click again to drop' or 'Drop');
        local clicked = imgui.Button(label .. '##nai_drop_go');
        imgui.PopStyleColor(4);
        if clicked then
            if needs_second and not armed then
                d.armed_at = os.clock();
            else
                do_drop(row, d.qty[1]);
                state.drop = nil;
            end
        end
        imgui.SameLine();
        if imgui.Button('Cancel##nai_drop_cancel') then state.drop = nil; end
        imgui.PopFont();
    end
    imgui.End();
    pop_theme();
end

-- ============================================================================
-- Main window
-- ============================================================================

local function is_new(row)
    if not config.new_highlight then return false, 0; end
    local t = state.new_at[row.bag] and state.new_at[row.bag][row.id] or nil;
    if t == nil then return false, 0; end
    local age = os.clock() - t;
    local dur = math.max(1, tonumber(config.new_seconds) or 10);
    if age > dur then
        state.new_at[row.bag][row.id] = nil;
        return false, 0;
    end
    return true, 1 - (age / dur);
end

local function open_ctx(row)
    state.ctx = row;
    imgui.OpenPopup('##nai_item_ctx');
end

-- Five-point star (fonts may not have a star glyph).
local function draw_star(dl, cx, cy, r, col)
    local outer, inner = {}, {};
    for i = 0, 4 do
        local a = -math.pi / 2 + i * (2 * math.pi / 5);
        outer[i] = { cx + math.cos(a) * r, cy + math.sin(a) * r };
        local b = a + math.pi / 5;
        inner[i] = { cx + math.cos(b) * r * 0.45, cy + math.sin(b) * r * 0.45 };
    end
    for i = 0, 4 do
        local prev = inner[(i + 4) % 5];
        dl:AddTriangleFilled(prev, outer[i], inner[i], col);
        dl:AddTriangleFilled({ cx, cy }, prev, inner[i], col);
    end
end

local STAR_COLOR = { 1.00, 0.82, 0.30, 1.0 };
local SPLIT_COLOR = { 0.55, 0.85, 0.95, 1.0 };

-- Quantity text: ' x12' / ' 12/99' (list) or '12' / '12/99' (grid).
local function qty_text(row, grid)
    local st = tonumber(row.info.stack) or 1;
    if config.qty_format == 'stack' and st > 1 then
        return grid and ('%d/%d'):fmt(row.count, st) or (' %d/%d'):fmt(row.count, st);
    end
    if row.count > 1 or config.show_qty_one then
        return grid and tostring(row.count) or (' x%d'):fmt(row.count);
    end
    return nil;
end

local function is_dimmed(row)
    return config.grey_unusable ~= false and not can_wear(row.info);
end

local function dim_color(col, dim)
    if not dim then return col; end
    return { col[1] * 0.6, col[2] * 0.6, col[3] * 0.6, (col[4] or 1.0) * 0.55 };
end

-- show_bag: draw the bag (and character) on the right of each row.
local function draw_list_view(rows, show_bag)
    local scale = tonumber(config.font_scale) or 1.0;
    local icon = math.floor((tonumber(config.icon_size) or 24) * scale);
    local line_h = imgui.GetTextLineHeight();
    local row_h = math.max(icon, line_h) + (tonumber(config.row_spacing) or 2) * 2;
    local width = tonumber((imgui.GetContentRegionAvail())) or 300;
    local dl = imgui.GetWindowDrawList();

    for i, row in ipairs(rows) do
        local sx, sy = imgui.GetCursorScreenPos();
        imgui.InvisibleButton('##nai_row_' .. row.uid, { math.max(1, width), row_h });
        local hovered = imgui.IsItemHovered();
        if hovered and imgui.IsMouseClicked(1) then open_ctx(row); end
        -- Rows scrolled out of view are skipped (icons load as you scroll).
        local visible = imgui.IsItemVisible == nil or imgui.IsItemVisible();
        if visible then

        local dim = is_dimmed(row);
        if i % 2 == 0 then
            dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32({ 1, 1, 1, 0.025 }), 3.0);
        end
        local new, strength = is_new(row);
        if new then
            local pulse = 0.55 + 0.45 * math.abs(math.sin(os.clock() * 4));
            dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32(accent(0.30 * strength * pulse)), 3.0);
            dl:AddRectFilled({ sx, sy }, { sx + 3, sy + row_h }, imgui.GetColorU32(accent(strength)), 0.0);
        end
        if hovered then
            dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32(accent(0.16)), 3.0);
        end

        local x = sx + 4;
        local tex = get_icon(row.info);
        local iy = sy + (row_h - icon) * 0.5;
        if tex ~= nil then
            dl:AddImage(tex.id, { x, iy }, { x + icon, iy + icon }, { 0, 0 }, { 1, 1 },
                imgui.GetColorU32(dim and { 1, 1, 1, 0.35 } or UI_WHITE));
        else
            dl:AddRectFilled({ x, iy }, { x + icon, iy + icon }, imgui.GetColorU32(UI_CONTROL), 3.0);
        end
        x = x + icon + 8;

        local ty = sy + (row_h - line_h) * 0.5;
        if is_favorite(row) then
            local r = math.max(4, line_h * 0.36);
            draw_star(dl, x + r, sy + row_h * 0.5, r, imgui.GetColorU32(STAR_COLOR));
            x = x + r * 2 + 5;
        end
        local name_col = row.equipped ~= nil and UI_ACCENT_TEXT or config.name_color;
        draw_fx_text(dl, x, ty, dim_color(name_col, dim), row.info.name);
        x = x + text_w(row.info.name);
        local q = qty_text(row, false);
        if q ~= nil then
            draw_fx_text(dl, x, ty, dim_color(config.qty_color, dim), q);
            x = x + text_w(q);
        end

        -- Right side: tags, split marker and (All / Characters) the bag.
        local right = sx + width - 6;
        local function right_text(s, col)
            local w = text_w(s);
            if right - w > x + 12 then
                draw_fx_text(dl, right - w, ty, col, s);
                right = right - w - 8;
            end
        end
        if show_bag then
            local where = BAG_NAMES[row.bag] or '';
            if row.source == 'alt' then where = tostring(row.char) .. ' - ' .. where; end
            right_text(where, UI_MUTED);
        end
        if config.show_tags then
            if row.info.ex then right_text('Ex', { 0.55, 0.75, 1.0, 1.0 }); end
            if row.info.rare then right_text('Rare', { 0.95, 0.75, 0.35, 1.0 }); end
            if row.equipped ~= nil then right_text('E', UI_ACCENT); end
        end
        if config.show_split ~= false and row.split ~= nil then right_text('Split', SPLIT_COLOR); end

        if hovered and not imgui.IsPopupOpen('##nai_item_ctx') then draw_tooltip(row); end
        end
    end
end

local function draw_grid_view(rows)
    local scale = tonumber(config.font_scale) or 1.0;
    local cell = math.floor((tonumber(config.grid_icon) or 40) * scale);
    local gap = 4;
    local width = tonumber((imgui.GetContentRegionAvail())) or 300;
    local cols = math.max(1, math.floor((width + gap) / (cell + gap)));
    local dl = imgui.GetWindowDrawList();

    for i, row in ipairs(rows) do
        if (i - 1) % cols ~= 0 then imgui.SameLine(0, gap); end
        local sx, sy = imgui.GetCursorScreenPos();
        imgui.InvisibleButton('##nai_cell_' .. row.uid, { cell, cell });
        local hovered = imgui.IsItemHovered();
        if hovered and imgui.IsMouseClicked(1) then open_ctx(row); end
        local visible = imgui.IsItemVisible == nil or imgui.IsItemVisible();
        if visible then

        local dim = is_dimmed(row);
        dl:AddRectFilled({ sx, sy }, { sx + cell, sy + cell }, imgui.GetColorU32({ 1, 1, 1, 0.04 }), 4.0);
        local tex = get_icon(row.info);
        if tex ~= nil then
            local p = math.floor(cell * 0.12);
            dl:AddImage(tex.id, { sx + p, sy + p }, { sx + cell - p, sy + cell - p }, { 0, 0 }, { 1, 1 },
                imgui.GetColorU32(dim and { 1, 1, 1, 0.35 } or UI_WHITE));
        end
        local new, strength = is_new(row);
        if new then
            dl:AddRect({ sx, sy }, { sx + cell, sy + cell }, imgui.GetColorU32(accent(strength)), 4.0, 0, 2.0);
        end
        if row.equipped ~= nil then
            dl:AddCircleFilled({ sx + 6, sy + 6 }, 3.0, imgui.GetColorU32(UI_ACCENT), 10);
        end
        if is_favorite(row) then
            local r = math.max(4, cell * 0.12);
            draw_star(dl, sx + cell - r - 2, sy + r + 2, r, imgui.GetColorU32(STAR_COLOR));
        end
        if config.show_split ~= false and row.split ~= nil then
            local t = math.max(6, cell * 0.2);
            dl:AddTriangleFilled({ sx + 1, sy + cell - 1 - t }, { sx + 1, sy + cell - 1 }, { sx + 1 + t, sy + cell - 1 },
                imgui.GetColorU32(SPLIT_COLOR));
        end
        if hovered then
            dl:AddRect({ sx, sy }, { sx + cell, sy + cell }, imgui.GetColorU32(accent(0.9)), 4.0, 0, 1.5);
        end
        local q = qty_text(row, true);
        if q ~= nil and text_w(q) > cell - 4 then q = tostring(row.count); end
        if q ~= nil then
            draw_fx_text(dl, sx + cell - text_w(q) - 3, sy + cell - imgui.GetTextLineHeight() - 1, dim_color(config.qty_color, dim), q);
        end
        if hovered and not imgui.IsPopupOpen('##nai_item_ctx') then draw_tooltip(row); end
        end
    end
end

-- ----------------------------------------------------------------------------
-- Categories view (AdiBags style): sections in your order, each a list or grid
-- ----------------------------------------------------------------------------

local CATEGORIES = {
    favorites = 'Favorites', new = 'New', equipped = 'Equipped', weapons = 'Weapons', armor = 'Armor',
    ammo = 'Ammo', usable = 'Usable', crystals = 'Crystals', rareex = 'Rare / Ex', materials = 'Materials',
};
local CAT_DEFAULT_ORDER = { 'favorites', 'new', 'equipped', 'weapons', 'armor', 'ammo', 'usable', 'crystals', 'rareex', 'materials' };

-- Your order with any missing / unknown keys fixed.
local function cat_order()
    local out, seen = {}, {};
    for _, k in ipairs(config.cat_order or {}) do
        if CATEGORIES[k] ~= nil and not seen[k] then out[#out + 1] = k; seen[k] = true; end
    end
    for _, k in ipairs(CAT_DEFAULT_ORDER) do
        if not seen[k] then out[#out + 1] = k; seen[k] = true; end
    end
    return out;
end

local SLOT_AMMO_BIT = 8;  -- bit 3

local function category_of(row)
    if is_favorite(row) then return 'favorites'; end
    if (is_new(row)) then return 'new'; end
    if row.equipped ~= nil then return 'equipped'; end
    local info = row.info;
    if (info.type == TYPE_WEAPON or info.type == TYPE_ARMOR) and info.slots == SLOT_AMMO_BIT then return 'ammo'; end
    if info.type == TYPE_WEAPON then return 'weapons'; end
    if info.type == TYPE_ARMOR then return 'armor'; end
    if info.type == TYPE_USABLE then return 'usable'; end
    if info.type == TYPE_CRYSTAL then return 'crystals'; end
    if info.rare or info.ex then return 'rareex'; end
    return 'materials';
end

local function draw_categories_view(rows, show_bag)
    local groups = {};
    for _, row in ipairs(rows) do
        local c = category_of(row);
        groups[c] = groups[c] or {};
        table.insert(groups[c], row);
    end
    config.cat_collapsed = config.cat_collapsed or T{};
    local dl = imgui.GetWindowDrawList();
    local line_h = imgui.GetTextLineHeight();

    for _, key in ipairs(cat_order()) do
        local list = groups[key];
        if list ~= nil and #list > 0 then
            local collapsed = config.cat_collapsed[key] == true;
            local width = tonumber((imgui.GetContentRegionAvail())) or 300;
            local h = line_h + 8;
            local sx, sy = imgui.GetCursorScreenPos();
            if imgui.InvisibleButton('##nai_cat_' .. key, { math.max(1, width), h }) then
                config.cat_collapsed[key] = (not collapsed) or nil;
                collapsed = not collapsed;
                mark_dirty();
            end
            local hovered = imgui.IsItemHovered();
            dl:AddRectFilled({ sx, sy }, { sx + width, sy + h }, imgui.GetColorU32(accent(hovered and 0.26 or 0.13)), 4.0);
            dl:AddRectFilled({ sx, sy + h - 2 }, { sx + width, sy + h }, imgui.GetColorU32(accent(0.55)), 0.0);

            -- Arrow: right when collapsed, down when open.
            local ax, ay, a = sx + 10, sy + h * 0.5, math.max(3, line_h * 0.22);
            local acol = imgui.GetColorU32(UI_ACCENT_TEXT);
            if collapsed then
                dl:AddTriangleFilled({ ax - a * 0.6, ay - a }, { ax + a * 0.8, ay }, { ax - a * 0.6, ay + a }, acol);
            else
                dl:AddTriangleFilled({ ax - a, ay - a * 0.6 }, { ax + a, ay - a * 0.6 }, { ax, ay + a * 0.8 }, acol);
            end

            local label = CATEGORIES[key];
            local ty = sy + 4;
            draw_fx_text(dl, sx + 22, ty, UI_ACCENT_TEXT, label);
            local cnt = ('  %d'):fmt(#list);
            draw_fx_text(dl, sx + 22 + text_w(label), ty, UI_MUTED, cnt);
            if config.show_value ~= false then
                local total = rows_value(list);
                if total > 0 then
                    local vt = fmt_gil(total) .. ' gil';
                    draw_fx_text(dl, sx + width - text_w(vt) - 8, ty, config.qty_color, vt);
                end
            end

            if not collapsed then
                imgui.Dummy({ 1, 2 });
                if config.cat_style == 'grid' then
                    draw_grid_view(list);
                else
                    draw_list_view(list, show_bag);
                end
            end
            imgui.Dummy({ 1, 4 });
        end
    end
end

-- ----------------------------------------------------------------------------
-- Key Items tab
-- ----------------------------------------------------------------------------

local KEY_ITEM_MAX = 3071;

-- Key item names (the resource table name differs between Ashita builds).
local function key_item_name(rm, id)
    local name = nil;
    for _, tbl in ipairs({ 'keyitems.names', 'keyitems' }) do
        pcall(function() name = rm:GetString(tbl, id); end);
        if name ~= nil and tostring(name) ~= '' then return tostring(name); end
    end
    return 'Key Item ' .. id;
end

-- Your key items (permanent and temporary): from the game's own key item
-- list packets (0x055, sent on login / zoning, remembered per character) plus
-- Ashita's HasKeyItem when that works on your build.
local function scan_key_items()
    local have = {};
    local name = state.player_name or get_player_name();
    local rec = name and chars[name] or nil;
    -- Tables seen this session win over the saved copy.
    local tables = {};
    if rec ~= nil and rec.ki ~= nil then
        for tbl, ids in pairs(rec.ki) do tables[tonumber(tbl) or tbl] = ids; end
    end
    for tbl, entry in pairs(state.ki_session or {}) do
        if entry.owner == nil or entry.owner == name then tables[tbl] = entry.ids; end
    end
    for _, ids in pairs(tables) do
        for _, id in ipairs(ids) do have[tonumber(id) or 0] = true; end
    end
    pcall(function()
        local player = AshitaCore:GetMemoryManager():GetPlayer();
        local errors = 0;
        for id = 1, KEY_ITEM_MAX do
            local ok, v = pcall(function() return player:HasKeyItem(id); end);
            if ok then
                if v == true or v == 1 then have[id] = true; end
            else
                errors = errors + 1;
                if errors > 3 then break; end   -- not available on this build
            end
        end
    end);

    local rm = AshitaCore:GetResourceManager();
    local list = {};
    for id in pairs(have) do
        if id > 0 then
            local n = key_item_name(rm, id);
            list[#list + 1] = { id = id, name = n, name_lower = n:lower() };
        end
    end
    table.sort(list, function(a, b) return a.name_lower < b.name_lower; end);
    state.key_items = list;
    state.key_items_at = os.clock();
end

local function draw_key_items_view()
    if state.key_items == nil or os.clock() - state.key_items_at > 5.0 then scan_key_items(); end
    local query = tostring(VS.search[1] or ''):lower():gsub('^%s+', ''):gsub('%s+$', '');
    local line_h = imgui.GetTextLineHeight();
    local row_h = line_h + (tonumber(config.row_spacing) or 2) * 2 + 2;
    local width = tonumber((imgui.GetContentRegionAvail())) or 300;
    local dl = imgui.GetWindowDrawList();
    local kf = state.ki_filter or 'all';
    local shown = 0;
    for _, k in ipairs(state.key_items) do
        local cat, auto = ki_category(k.id, k.name_lower);
        if (query == '' or k.name_lower:find(query, 1, true) ~= nil) and (kf == 'all' or kf == cat) then
            shown = shown + 1;
            local sx, sy = imgui.GetCursorScreenPos();
            imgui.InvisibleButton('##nai_ki_' .. k.id, { math.max(1, width), row_h });
            local hovered = imgui.IsItemHovered();
            local is_temp = cat == 'temporary';
            if hovered and imgui.IsMouseClicked(1) then
                local want = not is_temp;
                if want == (auto == 'temporary') then
                    ki_temp[k.id] = nil;      -- back to the built-in list
                else
                    ki_temp[k.id] = want;     -- your override
                end
                is_temp = want;
                write_lua_file(DATA_DIR .. 'key_items_temp.lua', ki_temp);
            end
            if hovered then
                local tip = is_temp and 'Temporary  -  right-click to mark as permanent' or 'Right-click to mark as temporary';
                if ki_temp[k.id] ~= nil then tip = tip .. '\n(your mark - right-click again to go back to the default)'; end
                imgui.SetTooltip(tip);
            end
            if imgui.IsItemVisible == nil or imgui.IsItemVisible() then
                if shown % 2 == 0 then
                    dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32({ 1, 1, 1, 0.025 }), 3.0);
                end
                if imgui.IsItemHovered() then
                    dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32(accent(0.16)), 3.0);
                end
                local cy = sy + row_h * 0.5;
                dl:AddCircleFilled({ sx + 10, cy }, math.max(2.5, line_h * 0.16), imgui.GetColorU32(accent(0.9)), 12);
                draw_fx_text(dl, sx + 22, sy + (row_h - line_h) * 0.5, config.name_color, k.name);
                if is_temp then
                    local label = 'TEMP';
                    local tw = text_w(label);
                    local bx2 = sx + width - 6;
                    local bx1 = bx2 - tw - 12;
                    local by1, by2 = sy + 2, sy + row_h - 2;
                    dl:AddRectFilled({ bx1, by1 }, { bx2, by2 }, imgui.GetColorU32({ 0.95, 0.70, 0.30, 0.18 }), 4.0);
                    dl:AddRect({ bx1, by1 }, { bx2, by2 }, imgui.GetColorU32({ 0.95, 0.70, 0.30, 0.75 }), 4.0, 0, 1.0);
                    draw_fx_text(dl, bx1 + 6, sy + (row_h - line_h) * 0.5, { 0.98, 0.76, 0.36, 1.0 }, label);
                end
            end
        end
    end
    if shown == 0 then
        imgui.TextDisabled(#state.key_items == 0 and 'No key items found (zone once to load them).' or 'No key items match the search / filter.');
    end
    return shown;
end

local function capture_geometry(geom)
    local x, y = imgui.GetWindowPos();
    local w, h = imgui.GetWindowSize();
    x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h);
    if x == nil or w == nil then return; end
    if math.abs(x - geom.x) >= 1 or math.abs(y - geom.y) >= 1 or math.abs(w - geom.w) >= 1 or math.abs(h - geom.h) >= 1 then
        geom.x, geom.y, geom.w, geom.h = x, y, w, h;
        mark_dirty();
    end
end

local VIEW_LABELS = { list = 'List', grid = 'Grid', categories = 'Categories' };
local VIEW_ORDER = { 'list', 'grid', 'categories' };

local function tab_label(bag)
    if bag == -1 then return 'All'; end
    if bag == -2 then return 'Characters'; end
    if bag == -3 then return 'Key Items'; end
    return BAG_NAMES[bag] or ('Bag ' .. tostring(bag));
end

-- Pop-out windows: config.popouts = list of { bag, view, sort, sort_desc,
-- filter, window }. One per tab. Runtime bits (search text, row cache,
-- geometry flag) live in state.pop_rt[bag].
local function find_popout(bag)
    for i, p in ipairs(config.popouts or {}) do
        if p.bag == bag then return p, i; end
    end
    return nil, nil;
end

local function pop_rt(bag)
    local rt = state.pop_rt[bag];
    if rt == nil then
        rt = { search = { '' }, cache = nil, key = nil, apply_geometry = true };
        state.pop_rt[bag] = rt;
    end
    return rt;
end

local function open_popout(bag)
    config.popouts = config.popouts or T{};
    config.popout_saved = config.popout_saved or T{};
    if find_popout(bag) == nil then
        local saved = config.popout_saved[tostring(bag)];
        if saved ~= nil and saved.window ~= nil then
            -- Reopen where you left it, with the same size and view.
            table.insert(config.popouts, T{
                bag = bag,
                view = saved.view or config.view or 'list',
                sort = saved.sort or config.sort or 'slot',
                sort_desc = saved.sort_desc == true,
                filter = saved.filter or 'all',
                window = T{ x = tonumber(saved.window.x) or 300, y = tonumber(saved.window.y) or 200,
                            w = tonumber(saved.window.w) or 380, h = tonumber(saved.window.h) or 460 },
            });
        else
            local n = #config.popouts;
            table.insert(config.popouts, T{
                bag = bag,
                view = config.view or 'list',
                sort = config.sort or 'slot',
                sort_desc = config.sort_desc == true,
                filter = 'all',
                window = T{ x = config.window.x + config.window.w + 10 + n * 24, y = config.window.y + n * 24, w = 380, h = 460 },
            });
        end
    end
    local rt = pop_rt(bag);
    rt.apply_geometry = true;
    rt.focus = true;
    if bag == -3 then state.key_items = nil; end
    state.hidden = false;
    mark_dirty();
end

local function close_popout(bag)
    local p, i = find_popout(bag);
    if p ~= nil then
        -- Remember its size, position and view for the next time it opens.
        config.popout_saved = config.popout_saved or T{};
        local w = p.window or {};
        config.popout_saved[tostring(bag)] = T{
            view = p.view, sort = p.sort, sort_desc = p.sort_desc == true, filter = p.filter,
            window = T{ x = tonumber(w.x) or 300, y = tonumber(w.y) or 200, w = tonumber(w.w) or 380, h = tonumber(w.h) or 460 },
        };
    end
    if i ~= nil then table.remove(config.popouts, i); end
    state.pop_rt[bag] = nil;
    mark_dirty();
end

-- Draws the main window (popout == nil) or one pop-out window. V is the
-- settings table for the window (config for main, the pop-out entry
-- otherwise); VS holds its runtime bits.
local function draw_inventory_window(popout)
    local open_ref;
    if popout == nil then
        V, VS = config, state.main_rt;
        VS.geom = config.window;
        open_ref = state.visible;
    else
        V, VS = popout, pop_rt(popout.bag);
        popout.window = popout.window or T{ x = 300, y = 200, w = 380, h = 460 };
        VS.geom = popout.window;
        VS.open = VS.open or { true };
        VS.open[1] = true;
        open_ref = VS.open;
    end
    V.filter = V.filter or 'all';

    if VS.apply_geometry ~= false then
        imgui.SetNextWindowPos({ VS.geom.x, VS.geom.y }, { 0, 0 });
        imgui.SetNextWindowSize({ VS.geom.w, VS.geom.h });
        VS.apply_geometry = false;
    end
    if VS.focus and imgui.SetNextWindowFocus ~= nil then
        imgui.SetNextWindowFocus();
    end
    VS.focus = nil;
    if imgui.SetNextWindowSizeConstraints ~= nil then
        imgui.SetNextWindowSizeConstraints({ 260, 220 }, { 4000, 4000 });
    end

    push_theme(config.background, config.theme);
    local flags = ImGuiWindowFlags_NoNav;
    if config.locked then flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoResize); end
    if not config.title_bar then flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar); end

    local title = (popout == nil) and 'NAInv##nai_main'
        or ('NAInv - %s##nai_pop_%s'):fmt(tab_label(popout.bag), tostring(popout.bag));
    if imgui.Begin(title, open_ref, flags) then
        local scale = tonumber(config.font_scale) or 1.0;
        imgui.PushFont(nil, imgui.GetFontSize() * scale);
        local frame_h = imgui.GetFrameHeight();

        if popout == nil then
            -- Header: bag tabs, then Characters and Key Items.
            -- Shift+Click a tab opens it in its own window.
            if V.bag == -2 and next(chars) == nil then V.bag = -1; end
            if state.bag_order[1] ~= nil and V.bag >= 0 and state.bags[V.bag] == nil then
                V.bag = state.bag_order[1];
            end
            imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 9, 4 });
            local avail = tonumber((imgui.GetContentRegionAvail())) or 400;
            local line_x = 0;
            local tab_idx = 0;
            local function tab(value)
                local label = tab_label(value);
                tab_idx = tab_idx + 1;
                local w = text_w(label) + 18;
                if tab_idx > 1 then
                    if line_x + 4 + w <= avail then imgui.SameLine(0, 4); line_x = line_x + 4;
                    else line_x = 0; end
                end
                if styled_tab(label, 'nai_bag_' .. tostring(value), V.bag == value) then
                    local shift = false;
                    pcall(function() shift = imgui.GetIO().KeyShift == true; end);
                    if shift or mod_down(0x10, state.mods.shift) then
                        -- Shift+Click again closes that tab's window.
                        if find_popout(value) ~= nil then close_popout(value); else open_popout(value); end
                    else
                        V.bag = value;
                        if value == -3 then state.key_items = nil; end
                        mark_dirty();
                    end
                end
                local popped = find_popout(value) ~= nil;
                if popped and imgui.GetItemRectMin ~= nil then
                    -- Small "own window" mark in the tab's top-right corner.
                    local x1, y1 = imgui.GetItemRectMin();
                    local x2 = imgui.GetItemRectMax();
                    local dl = imgui.GetWindowDrawList();
                    local s = 5;
                    local bx, by = x2 - s - 4, y1 + 3;
                    dl:AddRect({ bx - 2, by + 2 }, { bx + s - 2, by + s + 2 }, imgui.GetColorU32(accent(0.55)), 1.0, 0, 1.0);
                    dl:AddRectFilled({ bx, by }, { bx + s, by + s }, imgui.GetColorU32(accent(0.95)), 1.0);
                end
                if imgui.IsItemHovered() then
                    imgui.SetTooltip(not popped and 'Shift+Click to open in its own window'
                        or 'Open in its own window  -  Shift+Click to close it');
                end
                line_x = line_x + w;
            end
            tab(-1);
            for _, bag in ipairs(state.bag_order) do tab(bag); end
            if next(chars) ~= nil then tab(-2); end
            tab(-3);
            imgui.PopStyleVar(1);
        elseif not config.title_bar then
            -- Pop-out header: its tab name (no title bar to show it).
            imgui.AlignTextToFramePadding();
            imgui.TextColored(UI_ACCENT_TEXT, tab_label(V.bag));
        end

        local key_items = V.bag == -3;

        -- Toolbar: search, sort, view, log, config, close.
        local sort_w = key_items and 0 or (text_w('Newest v') + 34);
        local view_w = key_items and 0 or (text_w('Categories') + 34);
        local log_w = (popout == nil) and (text_w('Log') + 16) or 0;
        local cfg_w = (popout == nil) and (text_w('Config') + 16) or 0;
        local close_w = config.title_bar and 0 or (frame_h + 6);
        local row_w = tonumber((imgui.GetContentRegionAvail())) or 400;
        imgui.PushItemWidth(math.max(80, row_w - sort_w - view_w - log_w - cfg_w - close_w - 40));
        imgui.InputText('##nai_search', VS.search, 64);
        imgui.PopItemWidth();
        if imgui.IsItemHovered() and not imgui.IsItemActive() then
            imgui.SetTooltip(key_items and 'Search key items' or 'Search item names');
        end

        if not key_items then
            imgui.SameLine();
            imgui.PushItemWidth(sort_w);
            local sort_labels = { slot = 'Slot', name = 'Name', type = 'Type', qty = 'Qty', newest = 'Newest' };
            if imgui.BeginCombo('##nai_sort', (sort_labels[V.sort] or 'Slot') .. (V.sort_desc and ' v' or ' ^')) then
                for _, k in ipairs({ 'slot', 'name', 'type', 'qty', 'newest' }) do
                    if imgui.Selectable(sort_labels[k], V.sort == k) then
                        if V.sort == k then V.sort_desc = not V.sort_desc; else V.sort = k; V.sort_desc = false; end
                        mark_dirty();
                    end
                end
                imgui.EndCombo();
            end
            imgui.PopItemWidth();
            if imgui.IsItemHovered() then imgui.SetTooltip('Sort (pick the same one again to reverse)'); end

            imgui.SameLine();
            imgui.PushItemWidth(view_w);
            if imgui.BeginCombo('##nai_view', VIEW_LABELS[V.view] or 'List') then
                for _, k in ipairs(VIEW_ORDER) do
                    if imgui.Selectable(VIEW_LABELS[k], V.view == k) then
                        V.view = k;
                        mark_dirty();
                    end
                end
                imgui.EndCombo();
            end
            imgui.PopItemWidth();
            if imgui.IsItemHovered() then imgui.SetTooltip('List, Grid or Categories'); end
        end

        if popout == nil then
            imgui.SameLine();
            if imgui.Button('Log##nai_logbtn') then state.log_visible[1] = not state.log_visible[1]; end
            if imgui.IsItemHovered() then imgui.SetTooltip('Session loot log and gil'); end
            imgui.SameLine();
            if imgui.Button('Config##nai_cfg') then state.config_visible[1] = not state.config_visible[1]; end
        end
        if not config.title_bar then
            imgui.SameLine();
            if imgui.Button('X##nai_close', { frame_h, frame_h }) then open_ref[1] = false; end
        end

        -- Key item chips: All / Permanent / Temporary / Maps & Other.
        if key_items then
            local KF = {
                { key = 'all', label = 'All' },
                { key = 'permanent', label = 'Permanent' },
                { key = 'temporary', label = 'Temporary' },
                { key = 'other', label = 'Maps & Other' },
            };
            local cw = tonumber((imgui.GetContentRegionAvail())) or 400;
            local cx = 0;
            for i, f in ipairs(KF) do
                local w = text_w(f.label) + 18;
                if i > 1 then
                    if cx + 4 + w <= cw then imgui.SameLine(0, 4); cx = cx + 4; else cx = 0; end
                end
                if chip(f.label, 'nai_kf_' .. f.key, (state.ki_filter or 'all') == f.key) then
                    state.ki_filter = f.key;
                end
                cx = cx + w;
            end
        end

        -- Filter chips.
        if not key_items then
            local cw = tonumber((imgui.GetContentRegionAvail())) or 400;
            local cx = 0;
            for i, f in ipairs(FILTERS) do
                local w = text_w(f.label) + 18;
                if i > 1 then
                    if cx + 4 + w <= cw then imgui.SameLine(0, 4); cx = cx + 4; else cx = 0; end
                end
                if chip(f.label, 'nai_f_' .. f.key, V.filter == f.key) then
                    V.filter = f.key;
                    mark_dirty();
                end
                cx = cx + w;
            end
        end

        -- Footer reserved at the bottom.
        local footer_h = imgui.GetTextLineHeightWithSpacing() + 6;
        local _, avail_h = imgui.GetContentRegionAvail();
        avail_h = math.max(60, (tonumber(avail_h) or 300) - footer_h);

        local rows = key_items and {} or get_view_rows();
        local show_bag = V.bag == -1 or V.bag == -2;
        local ki_shown = 0;
        begin_child('##nai_items', { 0, avail_h }, 0);
        if key_items then
            ki_shown = draw_key_items_view();
        elseif #rows == 0 then
            local msg = 'Nothing here.';
            if next(state.bags) == nil then msg = 'Waiting for inventory...'; end
            if V.bag == -2 and next(chars) == nil then msg = 'No characters saved yet.'; end
            imgui.TextDisabled(msg);
        elseif V.view == 'categories' then
            draw_categories_view(rows, show_bag);
        elseif V.view == 'grid' then
            draw_grid_view(rows);
        else
            draw_list_view(rows, show_bag);
        end
        draw_context_menu();
        imgui.EndChild();

        -- Footer: slots / value on the left, gil (+ session change) on the right.
        imgui.Separator();
        if key_items then
            imgui.TextColored(UI_MUTED, ('%d key items'):fmt(#(state.key_items or {})));
            if ki_shown ~= #(state.key_items or {}) then
                imgui.SameLine(0, 6);
                imgui.TextDisabled(('(%d shown)'):fmt(ki_shown));
            end
        elseif V.bag == -2 then
            local n = 0;
            for _ in pairs(chars) do n = n + 1; end
            imgui.TextColored(UI_MUTED, ('%d character%s  -  view only'):fmt(n, n == 1 and '' or 's'));
        else
            local used, max = 0, 0;
            if V.bag == -1 then
                for _, bag in ipairs(state.bag_order) do
                    local b = state.bags[bag];
                    if b then used = used + b.used; max = max + b.max; end
                end
            elseif state.bags[V.bag] ~= nil then
                used, max = state.bags[V.bag].used, state.bags[V.bag].max;
            end
            local full = max > 0 and used >= max;
            imgui.TextColored(full and UI_DANGER or UI_MUTED, ('%d / %d'):fmt(used, max));
            imgui.SameLine(0, 6);
            imgui.TextColored(UI_MUTED, (V.bag == -1) and 'slots (all bags)' or 'slots');
            local b = state.bags[V.bag];
            if V.bag >= 0 and VIEW_ONLY_BAG[V.bag] then
                imgui.SameLine(0, 10);
                if b ~= nil and b.snapshot ~= nil then
                    imgui.TextDisabled('(snapshot)');
                    if imgui.IsItemHovered() then
                        imgui.SetTooltip(('Saved %s - visit your Mog House to refresh it.'):fmt(os.date('%Y-%m-%d %H:%M', b.snapshot)));
                    end
                else
                    imgui.TextDisabled('(view only)');
                end
            end
        end
        if not key_items and config.show_value ~= false and #rows > 0 then
            local total = rows_value(rows);
            if total > 0 then
                imgui.SameLine(0, 12);
                imgui.TextColored(UI_MUTED, 'Worth');
                imgui.SameLine(0, 4);
                imgui.TextColored(config.qty_color, fmt_gil(total));
                if imgui.IsItemHovered() then imgui.SetTooltip('Sell value of the items shown (known prices only)'); end
            end
        end

        -- Gil (and this session's change) only on the Inventory tab / window.
        if V.bag == 0 then
        local gil_label = 'Gil ';
        local gil_text = fmt_gil(state.gil);
        local delta = (state.session_gil ~= nil) and (state.gil - state.session_gil) or 0;
        local delta_text = (delta ~= 0) and ((delta > 0 and ' (+' or ' (-') .. fmt_gil(math.abs(delta)) .. ')') or '';
        imgui.SameLine();
        local gx = (tonumber((imgui.GetWindowContentRegionMax and imgui.GetWindowContentRegionMax())) or 0);
        if gx > 0 then
            imgui.SetCursorPosX(math.max(imgui.GetCursorPosX() + 10, gx - text_w(gil_label) - text_w(gil_text) - text_w(delta_text)));
        end
        imgui.TextColored(UI_MUTED, gil_label);
        imgui.SameLine(0, 0);
        imgui.TextColored(config.qty_color, gil_text);
        if delta_text ~= '' then
            imgui.SameLine(0, 0);
            imgui.TextColored(delta > 0 and { 0.45, 0.85, 0.45, 1.0 } or { 0.90, 0.45, 0.40, 1.0 }, delta_text);
            if imgui.IsItemHovered() then imgui.SetTooltip('Gil gained / spent this session'); end
        end
        end

        imgui.PopFont();
        if not config.locked then capture_geometry(VS.geom); end
    end
    imgui.End();
    pop_theme();
end

local function draw_main_window()
    if state.hidden then return; end
    if state.visible[1] then
        draw_inventory_window(nil);
    else
        state.main_rt.apply_geometry = true;
    end

    -- Pop-outs (copy the list: closing one removes it while we loop).
    local list = {};
    for _, p in ipairs(config.popouts or {}) do list[#list + 1] = p; end
    for _, p in ipairs(list) do
        draw_inventory_window(p);
        local rt = state.pop_rt[p.bag];
        if rt ~= nil and rt.open ~= nil and rt.open[1] == false then close_popout(p.bag); end
    end

    draw_drop_dialog();
end

-- Open key and /nai: hide everything that's showing, or show the main
-- window plus every pop-out you didn't close with X.
local function toggle_all()
    local showing = (not state.hidden) and (state.visible[1] or #(config.popouts or {}) > 0);
    if showing then
        state.hidden = true;
    else
        state.hidden = false;
        state.visible[1] = true;
        state.main_rt.apply_geometry = true;
        for bag, rt in pairs(state.pop_rt) do rt.apply_geometry = true; end
        state.rows_dirty = true;
    end
    mark_dirty();
end

-- ============================================================================
-- Loot log window
-- ============================================================================

local function fmt_duration(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0));
    local h, m = math.floor(sec / 3600), math.floor((sec % 3600) / 60);
    if h > 0 then return ('%dh %02dm'):fmt(h, m); end
    return ('%dm'):fmt(m);
end

local function signed_gil(n)
    n = tonumber(n) or 0;
    return (n >= 0 and '+' or '-') .. fmt_gil(math.abs(n));
end

local function gil_color(n)
    if n > 0 then return { 0.45, 0.85, 0.45, 1.0 }; end
    if n < 0 then return { 0.90, 0.45, 0.40, 1.0 }; end
    return UI_MUTED;
end

local function draw_log_window()
    if not state.log_visible[1] then
        state.apply_log_geometry = true;
        return;
    end
    config.log_window = config.log_window or T{ x = 680, y = 180, w = 420, h = 420 };
    if state.apply_log_geometry then
        imgui.SetNextWindowPos({ config.log_window.x, config.log_window.y }, { 0, 0 });
        imgui.SetNextWindowSize({ config.log_window.w, config.log_window.h });
        state.apply_log_geometry = false;
    end

    push_theme(config.background, config.theme);
    if imgui.Begin('NAInv Loot Log##nai_log', state.log_visible, ImGuiWindowFlags_NoNav) then
        imgui.PushFont(nil, imgui.GetFontSize() * (tonumber(config.font_scale) or 1.0));

        local elapsed = os.time() - state.session_start;
        local gained = (state.session_gil ~= nil) and (state.gil - state.session_gil) or 0;
        local per_hr = gained / math.max(elapsed, 300) * 3600;

        section_header('Session');
        imgui.TextColored(UI_MUTED, 'Time');
        imgui.SameLine(110);
        imgui.Text(fmt_duration(elapsed));

        imgui.TextColored(UI_MUTED, 'Gil');
        imgui.SameLine(110);
        imgui.TextColored(gil_color(gained), signed_gil(gained));
        imgui.SameLine(0, 10);
        imgui.TextColored(UI_MUTED, ('(%s / hr)'):fmt(signed_gil(math.floor(per_hr))));

        local day_start = tonumber(config.gil_day_start) or -1;
        if day_start >= 0 then
            local today = state.gil - day_start;
            imgui.TextColored(UI_MUTED, 'Today');
            imgui.SameLine(110);
            imgui.TextColored(gil_color(today), signed_gil(today));
        end

        local loot_value, loot_count = 0, 0;
        for _, e in ipairs(state.log) do
            loot_count = loot_count + e.qty;
            local each = price_of(e.id);
            if each ~= nil then loot_value = loot_value + each * e.qty; end
        end
        imgui.TextColored(UI_MUTED, 'Loot');
        imgui.SameLine(110);
        imgui.Text(('%d item%s'):fmt(loot_count, loot_count == 1 and '' or 's'));
        if config.show_value ~= false and loot_value > 0 then
            imgui.SameLine(0, 10);
            imgui.TextColored(config.qty_color, ('~%s gil'):fmt(fmt_gil(loot_value)));
        end

        imgui.Spacing();
        if imgui.Button('Clear log##nai_log_clear') then state.log = {}; end
        imgui.SameLine();
        if imgui.Button('New session##nai_log_reset') then
            state.log = {};
            state.session_start = os.time();
            state.session_gil = state.gil;
        end
        if imgui.IsItemHovered() then imgui.SetTooltip('Clears the log and restarts the session time and gil'); end

        imgui.Spacing();
        section_header('Items gained');
        local _, ah = imgui.GetContentRegionAvail();
        begin_child('##nai_log_list', { 0, math.max(60, tonumber(ah) or 200) }, 0);
        if #state.log == 0 then
            imgui.TextDisabled('Nothing yet. Items you gain this session show up here.');
        else
            local dl = imgui.GetWindowDrawList();
            local line_h = imgui.GetTextLineHeight();
            local icon = math.floor(line_h + 2);
            local row_h = icon + 4;
            local width = tonumber((imgui.GetContentRegionAvail())) or 300;
            for i, e in ipairs(state.log) do
                local info = get_item_info(e.id);
                local sx, sy = imgui.GetCursorScreenPos();
                imgui.InvisibleButton(('##nai_log_%d'):fmt(i), { math.max(1, width), row_h });
                if info ~= nil and (imgui.IsItemVisible == nil or imgui.IsItemVisible()) then
                    if i % 2 == 0 then
                        dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32({ 1, 1, 1, 0.025 }), 3.0);
                    end
                    local ty = sy + (row_h - line_h) * 0.5;
                    local tt = os.date('%H:%M', e.time);
                    draw_fx_text(dl, sx + 4, ty, UI_MUTED, tt);
                    local x = sx + 10 + text_w('00:00');
                    local tex = get_icon(info);
                    if tex ~= nil then
                        dl:AddImage(tex.id, { x, sy + 2 }, { x + icon, sy + 2 + icon }, { 0, 0 }, { 1, 1 }, imgui.GetColorU32(UI_WHITE));
                    end
                    x = x + icon + 6;
                    draw_fx_text(dl, x, ty, config.name_color, info.name);
                    x = x + text_w(info.name);
                    if e.qty > 1 then draw_fx_text(dl, x, ty, config.qty_color, (' x%d'):fmt(e.qty)); end
                    if config.show_value ~= false then
                        local each = price_of(e.id);
                        if each ~= nil and each > 0 then
                            local vt = fmt_gil(each * e.qty);
                            draw_fx_text(dl, sx + width - text_w(vt) - 6, ty, UI_MUTED, vt);
                        end
                    end
                end
            end
        end
        imgui.EndChild();

        imgui.PopFont();
        capture_geometry(config.log_window);
    end
    imgui.End();
    pop_theme();
end

-- ============================================================================
-- Inventory-full banner (top of the screen, a few seconds)
-- ============================================================================

local function draw_full_warning()
    if os.clock() >= state.warn_until then return; end
    local b = state.bags[0];
    if b == nil then return; end
    local free = b.max - b.used;
    local text = (free <= 0) and 'INVENTORY FULL'
        or ('INVENTORY: %d SLOT%s LEFT'):fmt(free, free == 1 and '' or 'S');

    local big = 1.5;
    local dsize = imgui.GetIO().DisplaySize;
    local w = text_w(text) * big + 40;
    imgui.SetNextWindowPos({ (tonumber(dsize.x) or 1920) * 0.5 - w * 0.5, 80 }, { 0, 0 });
    local pulse = 0.75 + 0.25 * math.abs(math.sin(os.clock() * 5));
    push_theme({ 0.30 * pulse, 0.05, 0.05, 0.92 }, config.theme);
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoInputs or 0, ImGuiWindowFlags_NoFocusOnAppearing or 0);
    if imgui.Begin('##nai_full_warning', nil, flags) then
        imgui.PushFont(nil, imgui.GetFontSize() * big);
        imgui.TextColored({ 1.0, 0.85, 0.80, 1.0 }, text);
        imgui.PopFont();
    end
    imgui.End();
    pop_theme();
end

-- ============================================================================
-- Keybind
-- ============================================================================

local VK_NAMES = {
    [0x08] = 'Backspace', [0x09] = 'Tab', [0x0D] = 'Enter', [0x13] = 'Pause', [0x14] = 'Caps Lock',
    [0x1B] = 'Esc', [0x20] = 'Space', [0x21] = 'Page Up', [0x22] = 'Page Down', [0x23] = 'End',
    [0x24] = 'Home', [0x25] = 'Left', [0x26] = 'Up', [0x27] = 'Right', [0x28] = 'Down',
    [0x2D] = 'Insert', [0x2E] = 'Delete', [0xBA] = ';', [0xBB] = '=', [0xBC] = ',', [0xBD] = '-',
    [0xBE] = '.', [0xBF] = '/', [0xC0] = '`', [0xDB] = '[', [0xDC] = '\\', [0xDD] = ']', [0xDE] = "'",
};
local function vk_name(vk)
    vk = tonumber(vk) or 0;
    if vk >= 0x41 and vk <= 0x5A then return string.char(vk); end
    if vk >= 0x30 and vk <= 0x39 then return string.char(vk); end
    if vk >= 0x70 and vk <= 0x87 then return 'F' .. tostring(vk - 0x6F); end
    if vk >= 0x60 and vk <= 0x69 then return 'Num ' .. tostring(vk - 0x60); end
    return VK_NAMES[vk] or ('Key 0x%02X'):fmt(vk);
end

local MOD_KEYS = { [0x10] = 'shift', [0xA0] = 'shift', [0xA1] = 'shift', [0x11] = 'ctrl', [0xA2] = 'ctrl',
    [0xA3] = 'ctrl', [0x12] = 'alt', [0xA4] = 'alt', [0xA5] = 'alt' };

local function bind_text()
    local kb = config.keybind;
    local parts = {};
    if kb.ctrl then parts[#parts + 1] = 'Ctrl'; end
    if kb.alt then parts[#parts + 1] = 'Alt'; end
    if kb.shift then parts[#parts + 1] = 'Shift'; end
    parts[#parts + 1] = vk_name(kb.key);
    return table.concat(parts, ' + ');
end

ashita.events.register('key', 'nai_key_cb', function(e)
    if e == nil then return; end
    local vk = tonumber(e.wparam) or 0;
    local lparam = tonumber(e.lparam) or 0;
    local down = bit.band(lparam, 0x80000000) == 0;
    local repeated = bit.band(lparam, 0x40000000) ~= 0;

    local mod = MOD_KEYS[vk];
    if mod ~= nil then
        state.mods[mod] = down;
        return;
    end
    if not down or repeated then return; end

    -- Capturing a new key from Config.
    if state.listening then
        if vk ~= 0x1B then
            config.keybind.key = vk;
            mark_dirty();
        end
        state.listening = false;
        e.blocked = true;
        return;
    end

    local kb = config.keybind;
    if not kb.enabled or vk ~= tonumber(kb.key) then return; end
    -- Never while typing: game chat input, or a text box in any window.
    local chat = AshitaCore:GetChatManager();
    if chat ~= nil and chat:IsInputOpen() ~= 0 then return; end
    local ok, typing = pcall(function() return imgui.GetIO().WantTextInput; end);
    if ok and typing then return; end
    local mods = current_mods();
    if (kb.ctrl == true) ~= mods.ctrl or (kb.alt == true) ~= mods.alt or (kb.shift == true) ~= mods.shift then
        return;
    end

    toggle_all();
    e.blocked = true;
end);

-- ============================================================================
-- Config window
-- ============================================================================

local function color_edit(label, tbl, with_alpha)
    if with_alpha then
        return imgui.ColorEdit4(label, tbl, ImGuiColorEditFlags_NoInputs or 0);
    end
    return imgui.ColorEdit3(label, tbl, ImGuiColorEditFlags_NoInputs or 0);
end

local function draw_config_window()
    if not state.config_visible[1] then
        state.apply_config_geometry = true;
        return;
    end
    if state.apply_config_geometry then
        imgui.SetNextWindowPos({ config.config_window.x, config.config_window.y }, { 0, 0 });
        imgui.SetNextWindowSize({ config.config_window.w, config.config_window.h });
        state.apply_config_geometry = false;
    end

    push_theme(config.background, config.theme);
    if imgui.Begin('NAInv Config##nai_config', state.config_visible, ImGuiWindowFlags_NoNav) then
        imgui.PushFont(nil, imgui.GetFontSize() * (tonumber(config.font_scale) or 1.0));

        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 11, 5 });
        local tabs = { 'Look', 'Text', 'Value', 'Categories', 'Keybind', 'Bags', 'About' };
        local tavail = tonumber((imgui.GetContentRegionAvail())) or 400;
        local tx = 0;
        for i, t in ipairs(tabs) do
            local w = text_w(t) + 22;
            if i > 1 then
                if tx + 4 + w <= tavail then imgui.SameLine(0, 4); tx = tx + 4; else tx = 0; end
            end
            if styled_tab(t, 'nai_cfg_tab_' .. i, state.config_tab == i) then state.config_tab = i; end
            tx = tx + w;
        end
        imgui.PopStyleVar(1);
        imgui.Spacing();
        imgui.Separator();
        imgui.Spacing();

        if state.config_tab == 1 then
            section_header('Theme');
            local idx = 0;
            local labels = {};
            for i, k in ipairs(UI_THEME_ORDER) do
                labels[#labels + 1] = UI_THEMES[k].label;
                if k == theme_key(config.theme) then idx = i - 1; end
            end
            local val = { idx };
            imgui.PushItemWidth(200);
            if imgui.Combo('Theme##nai_theme', val, table.concat(labels, '\0') .. '\0\0') then
                config.theme = UI_THEME_ORDER[(tonumber(val[1]) or 0) + 1] or UI_THEME_DEFAULT;
                applied_theme = nil;
                mark_dirty();
            end
            imgui.PopItemWidth();
            if color_edit('Window color / opacity##nai_bg', config.background, true) then mark_dirty(); end

            imgui.Spacing();
            section_header('Window');
            local locked = { config.locked == true };
            if imgui.Checkbox('Lock position and size##nai_lock', locked) then config.locked = locked[1]; mark_dirty(); end
            local tb = { config.title_bar == true };
            if imgui.Checkbox('Show title bar##nai_tb', tb) then config.title_bar = tb[1]; mark_dirty(); end
            if imgui.Button('Reset window position##nai_resetpos') then
                config.window.x, config.window.y, config.window.w, config.window.h = 220, 180, 440, 560;
                state.main_rt.apply_geometry = true;
                mark_dirty();
            end

            imgui.Spacing();
            section_header('Layout');
            if imgui.RadioButton('List##nai_vlist', config.view ~= 'grid' and config.view ~= 'categories') then config.view = 'list'; state.view_gen = state.view_gen + 1; mark_dirty(); end
            imgui.SameLine();
            if imgui.RadioButton('Grid##nai_vgrid', config.view == 'grid') then config.view = 'grid'; state.view_gen = state.view_gen + 1; mark_dirty(); end
            imgui.SameLine();
            if imgui.RadioButton('Categories##nai_vcat', config.view == 'categories') then config.view = 'categories'; state.view_gen = state.view_gen + 1; mark_dirty(); end
            imgui.TextDisabled('(main window; pop-out windows have their own view menu)');
            imgui.PushItemWidth(200);
            local fs = { tonumber(config.font_scale) or 1.0 };
            if imgui.SliderFloat('Size##nai_fs', fs, 0.75, 2.50, '%.2fx', ImGuiSliderFlags_AlwaysClamp) then config.font_scale = fs[1]; mark_dirty(); end
            help_marker('Scales the text, icons and rows together.');
            local ic = { tonumber(config.icon_size) or 24 };
            if imgui.SliderInt('List icon size##nai_ic', ic, 12, 48, '%d px', ImGuiSliderFlags_AlwaysClamp) then config.icon_size = ic[1]; mark_dirty(); end
            local gi = { tonumber(config.grid_icon) or 40 };
            if imgui.SliderInt('Grid cell size##nai_gi', gi, 24, 80, '%d px', ImGuiSliderFlags_AlwaysClamp) then config.grid_icon = gi[1]; mark_dirty(); end
            local rs = { tonumber(config.row_spacing) or 2 };
            if imgui.SliderInt('Row spacing##nai_rs', rs, 0, 10, '%d px', ImGuiSliderFlags_AlwaysClamp) then config.row_spacing = rs[1]; mark_dirty(); end
            imgui.PopItemWidth();
            local tags = { config.show_tags ~= false };
            if imgui.Checkbox('Show E / Rare / Ex tags in the list##nai_tags', tags) then config.show_tags = tags[1]; mark_dirty(); end

            imgui.Spacing();
            section_header('Items');
            align_label();
            imgui.Text('Quantity:');
            imgui.SameLine();
            if imgui.RadioButton('x12##nai_qf_x', config.qty_format ~= 'stack') then config.qty_format = 'x'; mark_dirty(); end
            imgui.SameLine();
            if imgui.RadioButton('12/99 (stack)##nai_qf_s', config.qty_format == 'stack') then config.qty_format = 'stack'; mark_dirty(); end
            local gu = { config.grey_unusable ~= false };
            if imgui.Checkbox("Grey out gear your job / level can't wear##nai_gu", gu) then config.grey_unusable = gu[1]; mark_dirty(); end
            local pf = { config.pin_favorites ~= false };
            if imgui.Checkbox('Pin favorites to the top (List / Grid)##nai_pf', pf) then config.pin_favorites = pf[1]; state.view_gen = state.view_gen + 1; mark_dirty(); end
            help_marker('Right-click an item > Add to favorites. Favorites get a star and cannot be dropped.');
            local ss = { config.show_split ~= false };
            if imgui.Checkbox('Mark split stacks (could be merged)##nai_ss', ss) then config.show_split = ss[1]; mark_dirty(); end

            imgui.Spacing();
            section_header('Inventory full warning');
            local wf = { config.warn_full ~= false };
            if imgui.Checkbox('Warn at the top of the screen##nai_wf', wf) then config.warn_full = wf[1]; mark_dirty(); end
            imgui.PushItemWidth(200);
            local wn = { tonumber(config.warn_free) or 5 };
            if imgui.SliderInt('Free slots or fewer##nai_wn', wn, 0, 20, '%d', ImGuiSliderFlags_AlwaysClamp) then config.warn_free = wn[1]; mark_dirty(); end
            imgui.PopItemWidth();
            imgui.SameLine();
            if imgui.Button('Test##nai_wtest') then state.warn_until = os.clock() + 5.0; end
            imgui.TextDisabled('Shows for a few seconds when an item comes in near the limit.');

            imgui.Spacing();
            section_header('New items');
            local nh = { config.new_highlight ~= false };
            if imgui.Checkbox('Highlight items you just got##nai_new', nh) then config.new_highlight = nh[1]; mark_dirty(); end
            imgui.PushItemWidth(200);
            local ns = { tonumber(config.new_seconds) or 10 };
            if imgui.SliderInt('Highlight time##nai_newsec', ns, 2, 60, '%d sec', ImGuiSliderFlags_AlwaysClamp) then config.new_seconds = ns[1]; mark_dirty(); end
            imgui.PopItemWidth();

        elseif state.config_tab == 2 then
            section_header('Text effect');
            imgui.PushItemWidth(200);
            local cur = 'Shadow';
            for _, e in ipairs(EFFECTS) do if e.key == config.text_effect then cur = e.label; end end
            if imgui.BeginCombo('Effect##nai_fx', cur) then
                for _, e in ipairs(EFFECTS) do
                    if imgui.Selectable(e.label, e.key == config.text_effect) then config.text_effect = e.key; mark_dirty(); end
                end
                imgui.EndCombo();
            end
            local eo = { tonumber(config.effect_opacity) or 0.85 };
            if imgui.SliderFloat('Effect opacity##nai_fxo', eo, 0.0, 1.0, '%.2f', ImGuiSliderFlags_AlwaysClamp) then config.effect_opacity = eo[1]; mark_dirty(); end
            imgui.PopItemWidth();
            if color_edit('Effect color##nai_fxc', config.effect_color, false) then mark_dirty(); end

            imgui.Spacing();
            section_header('Colors');
            if color_edit('Item name##nai_namec', config.name_color, true) then mark_dirty(); end
            if color_edit('Quantity and gil##nai_qtyc', config.qty_color, true) then mark_dirty(); end
            local q1 = { config.show_qty_one == true };
            if imgui.Checkbox('Show x1 on single items##nai_q1', q1) then config.show_qty_one = q1[1]; mark_dirty(); end

            imgui.Spacing();
            section_header('Preview');
            local dl = imgui.GetWindowDrawList();
            local sx, sy = imgui.GetCursorScreenPos();
            dl:AddRectFilled({ sx, sy }, { sx + 300, sy + imgui.GetTextLineHeight() + 12 }, imgui.GetColorU32({ 0.45, 0.50, 0.40, 1.0 }), 4.0);
            draw_fx_text(dl, sx + 8, sy + 6, config.name_color, 'Pot of Honey');
            draw_fx_text(dl, sx + 8 + text_w('Pot of Honey'), sy + 6, config.qty_color, ' x12');
            imgui.Dummy({ 300, imgui.GetTextLineHeight() + 14 });

        elseif state.config_tab == 3 then
            section_header('Item value');
            local sv = { config.show_value ~= false };
            if imgui.Checkbox('Show sell value (tooltips, footer, categories, log)##nai_sv', sv) then config.show_value = sv[1]; mark_dirty(); end
            local sa = { config.show_ah ~= false };
            if imgui.Checkbox('Show Auction House category in tooltips##nai_sa', sa) then config.show_ah = sa[1]; mark_dirty(); end

            imgui.Spacing();
            section_header('Price list');
            load_price_list();
            if prices.source ~= nil then
                imgui.TextColored(config.qty_color, ('Loaded %s prices'):fmt(fmt_gil(prices.count)));
                imgui.TextDisabled(prices.source);
            else
                imgui.TextColored(UI_DANGER, 'item_basic.sql not found.');
                imgui.TextWrapped('Download sql/item_basic.sql from the LandSandBoat GitHub and put it in the nainv addon folder (next to nainv.lua), then press Reload.');
            end
            if imgui.Button('Reload price list##nai_reload_prices') then
                prices.base, prices.nosale, prices.ah, prices.loaded, prices.count, prices.source = {}, {}, {}, false, 0, nil;
                load_price_list();
            end

            imgui.Spacing();
            section_header('Learned at vendors');
            local n = 0;
            for _ in pairs(learned) do n = n + 1; end
            imgui.Text(('%d exact prices learned'):fmt(n));
            imgui.TextWrapped('When a shop appraises an item (you pick it to sell), NAInv saves the exact price HorizonXI gave you. Learned prices replace the list price and are marked [vendor].');
            local armed = state.forget_armed ~= nil and os.clock() - state.forget_armed < 3.0;
            if armed then imgui.PushStyleColor(ImGuiCol_Button, { 0.72, 0.16, 0.16, 1.0 }); end
            local clicked = imgui.Button((armed and 'Click again to forget' or 'Forget learned prices') .. '##nai_forget');
            if armed then imgui.PopStyleColor(1); end
            if clicked then
                if armed then
                    for k in pairs(learned) do learned[k] = nil; end
                    write_lua_file(DATA_DIR .. 'prices_learned.lua', learned);
                    state.forget_armed = nil;
                else
                    state.forget_armed = os.clock();
                end
            end
            imgui.Spacing();
            imgui.TextDisabled('Fame does not change NPC sell prices.');

        elseif state.config_tab == 4 then
            section_header('Categories view');
            imgui.TextDisabled('Pick Categories in the view menu of the inventory window.');
            align_label();
            imgui.Text('Each section shows as:');
            imgui.SameLine();
            if imgui.RadioButton('List##nai_cs_list', config.cat_style ~= 'grid') then config.cat_style = 'list'; mark_dirty(); end
            imgui.SameLine();
            if imgui.RadioButton('Grid##nai_cs_grid', config.cat_style == 'grid') then config.cat_style = 'grid'; mark_dirty(); end

            imgui.Spacing();
            section_header('Section order');
            imgui.TextDisabled('An item goes in the first section it fits, in this priority:');
            imgui.TextDisabled('Favorites, New, Equipped, Ammo, Weapons, Armor, Usable,');
            imgui.TextDisabled('Crystals, Rare / Ex, Materials. The order below is the display order.');
            local order = cat_order();
            local move_from, move_to = nil, nil;
            for i, k in ipairs(order) do
                if imgui.ArrowButton ~= nil then
                    if imgui.ArrowButton('##nai_cat_up_' .. k, ImGuiDir_Up or 2) and i > 1 then move_from, move_to = i, i - 1; end
                    imgui.SameLine(0, 2);
                    if imgui.ArrowButton('##nai_cat_dn_' .. k, ImGuiDir_Down or 3) and i < #order then move_from, move_to = i, i + 1; end
                else
                    if imgui.Button('^##nai_cat_up_' .. k) and i > 1 then move_from, move_to = i, i - 1; end
                    imgui.SameLine(0, 2);
                    if imgui.Button('v##nai_cat_dn_' .. k) and i < #order then move_from, move_to = i, i + 1; end
                end
                imgui.SameLine(0, 10);
                align_label();
                imgui.Text(('%d.  %s'):fmt(i, CATEGORIES[k]));
                if config.cat_collapsed and config.cat_collapsed[k] then
                    imgui.SameLine(0, 8);
                    imgui.TextDisabled('(collapsed)');
                end
            end
            if move_from ~= nil then
                order[move_from], order[move_to] = order[move_to], order[move_from];
                config.cat_order = T(order);
                mark_dirty();
            end
            imgui.Spacing();
            if imgui.Button('Reset order##nai_cat_reset') then
                config.cat_order = T{ 'favorites', 'new', 'equipped', 'weapons', 'armor', 'ammo', 'usable', 'crystals', 'rareex', 'materials' };
                mark_dirty();
            end
            imgui.SameLine();
            if imgui.Button('Expand all sections##nai_cat_expand') then
                config.cat_collapsed = T{};
                mark_dirty();
            end
            imgui.TextDisabled('Click a section header in the inventory to collapse / expand it.');

        elseif state.config_tab == 5 then
            section_header('Open key');
            local en = { config.keybind.enabled ~= false };
            if imgui.Checkbox('Open / close NAInv with a key##nai_kben', en) then config.keybind.enabled = en[1]; mark_dirty(); end
            align_label();
            imgui.Text('Key:');
            imgui.SameLine();
            if state.listening then
                imgui.PushStyleColor(ImGuiCol_Button, accent(0.45));
                imgui.Button('Press a key...  (Esc cancels)##nai_kbset');
                imgui.PopStyleColor(1);
            elseif imgui.Button(bind_text() .. '##nai_kbset') then
                state.listening = true;
            end
            local c1 = { config.keybind.ctrl == true };
            if imgui.Checkbox('Ctrl##nai_kbc', c1) then config.keybind.ctrl = c1[1]; mark_dirty(); end
            imgui.SameLine();
            local a1 = { config.keybind.alt == true };
            if imgui.Checkbox('Alt##nai_kba', a1) then config.keybind.alt = a1[1]; mark_dirty(); end
            imgui.SameLine();
            local s1 = { config.keybind.shift == true };
            if imgui.Checkbox('Shift##nai_kbs', s1) then config.keybind.shift = s1[1]; mark_dirty(); end
            imgui.Spacing();
            imgui.TextDisabled('The key does nothing while the chat box is open or you are');
            imgui.TextDisabled('typing in a text box. /nai also opens the window.');

        elseif state.config_tab == 6 then
            section_header('Bag tabs');
            imgui.TextDisabled('Bags your character does not have are not listed.');
            config.hidden_bags = config.hidden_bags or T{};
            for _, bag in ipairs(TAB_ORDER) do
                local b = state.bags[bag];
                if b ~= nil and bag ~= 3 then
                    local shown = { not config.hidden_bags[bag] };
                    local label = ('%s  (%d / %d)%s##nai_bag_show_%d'):fmt(BAG_NAMES[bag] or ('Bag ' .. bag), b.used, b.max,
                        VIEW_ONLY_BAG[bag] and '  view only' or '', bag);
                    if imgui.Checkbox(label, shown) then
                        config.hidden_bags[bag] = (not shown[1]) or nil;
                        state.rows_dirty = true;
                        mark_dirty();
                    end
                end
            end

        else
            section_header('NAInv');
            imgui.Text(('New Age Inventory  v%s'):fmt(addon.version));
            imgui.TextColored(UI_MUTED, 'by Izumi (ShiroIzumi)');
            imgui.Spacing();
            imgui.TextDisabled('/nai          open / close the inventory');
            imgui.TextDisabled('/nai config   open / close this window');
            imgui.Spacing();
            imgui.TextDisabled('Right-click an item for Use / Equip / Drop / Favorite.');
            imgui.TextDisabled('Shift+Click a tab to open it in its own window.');
            imgui.TextDisabled('Data (all characters): addons\\nainv\\data\\');
        end

        imgui.PopFont();
        capture_geometry(config.config_window);
    end
    imgui.End();
    pop_theme();
end

-- ============================================================================
-- Events
-- ============================================================================

local function save_config()
    config.visible = state.visible[1];
    config.hidden = state.hidden == true;
    config.config_visible = state.config_visible[1];
    settings.save();
end

settings.register('settings', 'nai_settings_update', function(s)
    if s ~= nil then config = s; end
    applied_theme = nil;
    state.visible[1] = config.visible ~= false;
    state.hidden = config.hidden == true;
    state.config_visible[1] = config.config_visible == true;
    state.main_rt = { search = { '' }, cache = nil, key = nil, apply_geometry = true };
    state.pop_rt = {};
    V, VS = config, state.main_rt;
    state.apply_config_geometry = true;
    state.rows_dirty = true;
    state.prev_counts = nil;
    state.prev_totals = nil;
    state.prev_mh = nil;
    state.new_at = {};
    -- Possibly a different character: start fresh.
    save_chars(true);
    state.player_name = nil;
    state.bag_sig = nil;
    state.session_gil = nil;
    state.session_start = os.time();
    state.key_items = nil;
end);

ashita.events.register('packet_in', 'nai_packet_in_cb', function(e)
    if e == nil then return; end
    local id = e.id;
    -- Inventory changes: refresh soon.
    if id == 0x01E or id == 0x01F or id == 0x020 or id == 0x01D or id == 0x050 then
        state.rows_dirty = true;
    elseif id == 0x00A or id == 0x00B then
        -- Zoning reloads the inventory; do not flag everything as new.
        state.prev_counts = nil;
        state.baseline_until = os.clock() + 8.0;
        state.rows_dirty = true;
        if id == 0x00B then save_chars(true); end
    elseif id == 0x055 then
        -- Key item list: 64 bytes of "have" bits for one table of 512 ids.
        pcall(function()
            local d = e.data;
            if d == nil or #d < 0x85 then return; end
            local tbl = d:byte(0x84 + 1);
            local ids = {};
            for i = 0, 0x3F do
                local byte = d:byte(0x04 + i + 1);
                if byte ~= 0 then
                    for bitn = 0, 7 do
                        if bit.band(byte, bit.lshift(1, bitn)) ~= 0 then
                            ids[#ids + 1] = tbl * 512 + i * 8 + bitn;
                        end
                    end
                end
            end
            -- Kept for this session even if your name isn't known yet (login).
            local name = state.player_name or get_player_name();
            state.ki_session = state.ki_session or {};
            state.ki_session[tbl] = { owner = name, ids = ids };
            if name ~= nil then
                chars[name] = chars[name] or { bags = {}, mh_time = {} };
                chars[name].ki = chars[name].ki or {};
                chars[name].ki[tbl] = ids;
                chars_dirty = true;
            end
            state.key_items = nil;
        end);
    elseif id == 0x03D then
        -- Shop appraisal: the exact sell price (per item) for an inventory slot.
        pcall(function()
            local d = e.data;
            if d == nil or #d < 9 then return; end
            local price = d:byte(5) + d:byte(6) * 0x100 + d:byte(7) * 0x10000 + d:byte(8) * 0x1000000;
            local slot = d:byte(9);
            local item = get_inventory():GetContainerItem(0, slot);
            if item ~= nil and (tonumber(item.Id) or 0) > 0 then
                learn_price(tonumber(item.Id), price);
            end
        end);
    end
end);

ashita.events.register('command', 'nai_command_cb', function(e)
    local args = e.command:args();
    if #args == 0 or not args[1]:any('/nai', '/nainv') then return; end
    e.blocked = true;
    local sub = args[2] and tostring(args[2]):lower() or '';
    if sub == 'config' or sub == 'settings' then
        state.config_visible[1] = not state.config_visible[1];
    elseif sub == 'help' then
        print('[NAInv] /nai - open / close the inventory window');
        print('[NAInv] /nai config - open / close the config window');
        print(('[NAInv] Open key: %s (change it in /nai config > Keybind)'):fmt(bind_text()));
        return;
    else
        toggle_all();
        return;
    end
    mark_dirty();
end);

ashita.events.register('d3d_present', 'nai_present_cb', function()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if player == nil then return; end

    pcall(function()
        state.job = tonumber(player:GetMainJob()) or 0;
        state.level = tonumber(player:GetMainJobLevel()) or 0;
    end);

    -- Scans: right after inventory packets, every second while the window
    -- is open, every few seconds otherwise (loot log, gil, full warning).
    local now = os.clock();
    local shown = not state.hidden and (state.visible[1] or #(config.popouts or {}) > 0);
    local interval = shown and 1.0 or 5.0;
    if (state.rows_dirty and now - state.last_scan >= 0.25) or now - state.last_scan >= interval then
        scan_bags();
    end
    save_chars(false);

    draw_main_window();
    draw_log_window();
    draw_config_window();
    if config.warn_full ~= false then draw_full_warning(); end

    if state.settings_dirty and (os.clock() - state.last_save) > 0.6 and not imgui.IsAnyItemActive() then
        state.settings_dirty = false;
        state.last_save = os.clock();
        save_config();
    end
end);

ashita.events.register('unload', 'nai_unload_cb', function()
    save_config();
    save_chars(true);
end);
