--[[
    MobHunt - Ashita v4 / HorizonXI
    Version 1.7.0

    Tracks monsters by Zone + Mob Name:
      * Fights / encounters
      * Kills (your kills, plus party/alliance kills near you; optional)
      * Deaths to the mob
      * Lifetime and current-session statistics
      * Treasure-pool drops, quantities, and observed drop percentages
      * Searchable history with per-mob details
      * Mob abilities (1.6.0): every TP move / spell a mob STARTS is counted
        (even if it gets interrupted), plus how many it finished. Nothing is
        shown until the mob is dead: the fight's list is added to the mob's
        record only when it dies.

    Commands:
      /mobhunt
      /mhunt
      /mhunt history
      /mhunt config
      /mhunt timers
      /mhunt session
      /mhunt debug

    Notes:
      * Merely targeting a monster never increments a fight.
      * Drawing your weapon does not start a fight. An encounter starts at
        the first real action: you acting on the monster, the monster acting
        on you, or (for a monster you engaged) a party member acting on it /
        it acting on a party member. If someone outside your party claims it
        first, nothing is counted.
      * Treasure-pool drops are read from Ashita's treasure-pool memory and
        credited to your most recent kill, unless a party member killed a
        different mob more recently (then the drop is not credited).
      * The addon uses per-character Ashita settings for persistent lifetime data.
]]--

addon.name      = 'MobHunt';
addon.author    = 'Izumi (ShiroIzumi)';
addon.version   = '1.7.0';
addon.desc      = 'Tracks mob encounters, kills, deaths, and observed drops by zone.';
addon.link      = '';

require 'common';

local imgui    = require 'imgui';
local settings = require 'settings';
local uifont   = require 'uifont';
local ui       = require 'cfgui';   -- 1.7.0: settings window kit (MogSuite layout)
uifont.addon = 'mobhunt';

-- ============================================================================
-- UI theme (black base + accent), shared look with ScrollingCombatLog
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

-- Values are 0-255 RGB.
--   accent      : fills, underlines, checkmarks, slider grabs
--   text        : headers and selected-tab text
--   title_active: focused title bar
--   border      : window / separator border
local UI_THEMES = {
    forest = {
        label = 'Forest',
        accent = { 111, 175, 79 }, text = { 164, 212, 136 },
        title_active = { 20, 32, 18 }, border = { 44, 68, 38 },
    },
    rust = {
        label = 'Rust',
        accent = { 181, 82, 59 }, text = { 226, 140, 118 },
        title_active = { 34, 20, 16 }, border = { 72, 40, 32 },
    },
    bone = {
        label = 'Bone',
        accent = { 207, 198, 176 }, text = { 232, 226, 210 },
        title_active = { 28, 27, 25 }, border = { 64, 62, 56 },
    },
    -- 1.7.0: MogSuite's six themes too. bg = the theme's own background
    -- (used when "Use the theme's background" is on); control / title /
    -- popup are optional (neutral when absent; Midnight tints them).
    copper   = { label = 'Copper',   accent = { 196, 128, 80 },  text = { 224, 166, 120 }, title_active = { 24, 15, 9 },  border = { 72, 48, 32 },  bg = { 9, 9, 10 } },
    garnet   = { label = 'Garnet',   accent = { 168, 52, 62 },   text = { 214, 112, 120 }, title_active = { 24, 9, 11 },  border = { 70, 30, 34 },  bg = { 9, 9, 10 } },
    silver   = { label = 'Silver',   accent = { 176, 188, 204 }, text = { 226, 232, 240 }, title_active = { 28, 30, 34 }, border = { 66, 72, 82 },  bg = { 9, 9, 10 } },
    amethyst = { label = 'Amethyst', accent = { 150, 118, 214 }, text = { 184, 160, 236 }, title_active = { 16, 11, 26 }, border = { 52, 42, 78 },  bg = { 9, 8, 12 } },
    emerald  = { label = 'Emerald',  accent = { 60, 180, 110 },  text = { 132, 222, 166 }, title_active = { 10, 28, 18 }, border = { 30, 70, 46 },  bg = { 8, 10, 9 } },
    midnight = { label = 'Midnight', accent = { 104, 148, 226 }, text = { 168, 196, 242 }, title_active = { 14, 22, 44 }, border = { 42, 60, 100 }, bg = { 9, 14, 28 },
                 control = { 20, 28, 48 }, control_hover = { 30, 42, 70 }, control_active = { 40, 56, 92 }, title = { 6, 10, 22 }, popup = { 10, 16, 32 } },
};
UI_THEMES.forest.bg = { 8, 10, 8 };
UI_THEMES.rust.bg = { 10, 8, 8 };
UI_THEMES.bone.bg = { 10, 10, 9 };

local UI_THEME_ORDER = { 'forest', 'rust', 'bone', 'copper', 'garnet', 'silver', 'amethyst', 'emerald', 'midnight' };
-- MobHunt's own neutral control / title / popup colors (0-255), for themes
-- that don't tint them.
local UI_NEUTRAL = {
    control = { 25.5, 25.5, 28.05 }, control_hover = { 40.8, 40.8, 45.9 }, control_active = { 56.1, 56.1, 63.75 },
    title = { 5.1, 5.1, 5.61 }, popup = { 12.75, 12.75, 14.28 },
};
local UI_THEME_DEFAULT = 'forest';
local applied_ui_theme = nil;

local function ui_set_rgb(dst, rgb)
    dst[1] = rgb[1] / 255;
    dst[2] = rgb[2] / 255;
    dst[3] = rgb[3] / 255;
end

local function normalize_theme_key(key)
    key = tostring(key or UI_THEME_DEFAULT):lower();
    if UI_THEMES[key] == nil then
        key = UI_THEME_DEFAULT;
    end
    return key;
end

-- Updates the shared UI color tables in place for the selected theme.
local function apply_ui_theme(key)
    key = normalize_theme_key(key);
    if applied_ui_theme == key then
        return;
    end

    local theme = UI_THEMES[key];
    ui_set_rgb(UI_ACCENT, theme.accent);
    ui_set_rgb(UI_ACCENT_TEXT, theme.text);
    ui_set_rgb(UI_TITLE_ACTIVE, theme.title_active);
    ui_set_rgb(UI_BORDER, theme.border);
    ui_set_rgb(UI_CONTROL, theme.control or UI_NEUTRAL.control);
    ui_set_rgb(UI_CONTROL_HOVER, theme.control_hover or UI_NEUTRAL.control_hover);
    ui_set_rgb(UI_CONTROL_ACTIVE, theme.control_active or UI_NEUTRAL.control_active);
    ui_set_rgb(UI_TITLE, theme.title or UI_NEUTRAL.title);
    ui_set_rgb(UI_POPUP, theme.popup or UI_NEUTRAL.popup);
    applied_ui_theme = key;
end

local function ui_accent(alpha_mul)
    return { UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], UI_ACCENT[4] * (alpha_mul or 1.0) };
end

-- Each push records how many colors / vars were pushed so the matching pop
-- stays balanced even if a constant is missing on an older Ashita build.
local ui_theme_stack = {};

-- bg: window background color { r, g, b, a } (the user's configured color).
-- theme_key: selected theme. scale: optional spacing multiplier.
local function push_theme(bg, theme_key, scale)
    apply_ui_theme(theme_key);
    scale = tonumber(scale) or 1.0;

    local color_count = 0;
    local var_count = 0;

    local function color(index, value)
        if index ~= nil then
            imgui.PushStyleColor(index, value);
            color_count = color_count + 1;
        end
    end

    local function var(index, value)
        if index ~= nil then
            imgui.PushStyleVar(index, value);
            var_count = var_count + 1;
        end
    end

    color(ImGuiCol_WindowBg, { bg[1], bg[2], bg[3], bg[4] });
    color(ImGuiCol_ChildBg, UI_TRANSPARENT);
    color(ImGuiCol_PopupBg, UI_POPUP);
    color(ImGuiCol_TitleBg, UI_TITLE);
    color(ImGuiCol_TitleBgActive, UI_TITLE_ACTIVE);
    color(ImGuiCol_TitleBgCollapsed, UI_TITLE);
    color(ImGuiCol_Border, UI_BORDER);
    color(ImGuiCol_BorderShadow, UI_TRANSPARENT);

    color(ImGuiCol_Text, UI_TEXT);
    color(ImGuiCol_TextDisabled, UI_MUTED);
    color(ImGuiCol_TextSelectedBg, ui_accent(0.35));

    color(ImGuiCol_FrameBg, UI_CONTROL);
    color(ImGuiCol_FrameBgHovered, UI_CONTROL_HOVER);
    color(ImGuiCol_FrameBgActive, UI_CONTROL_ACTIVE);
    color(ImGuiCol_CheckMark, UI_ACCENT);
    color(ImGuiCol_SliderGrab, ui_accent(0.80));
    color(ImGuiCol_SliderGrabActive, UI_ACCENT);

    color(ImGuiCol_Button, UI_CONTROL);
    color(ImGuiCol_ButtonHovered, UI_CONTROL_HOVER);
    color(ImGuiCol_ButtonActive, UI_CONTROL_ACTIVE);

    color(ImGuiCol_Header, ui_accent(0.22));
    color(ImGuiCol_HeaderHovered, ui_accent(0.30));
    color(ImGuiCol_HeaderActive, ui_accent(0.40));

    color(ImGuiCol_Separator, UI_BORDER);
    color(ImGuiCol_SeparatorHovered, ui_accent(0.60));
    color(ImGuiCol_SeparatorActive, UI_ACCENT);

    color(ImGuiCol_ScrollbarBg, { 0.00, 0.00, 0.00, 0.20 });
    color(ImGuiCol_ScrollbarGrab, UI_CONTROL_HOVER);
    color(ImGuiCol_ScrollbarGrabHovered, UI_CONTROL_ACTIVE);
    color(ImGuiCol_ScrollbarGrabActive, ui_accent(0.80));

    color(ImGuiCol_ResizeGrip, ui_accent(0.20));
    color(ImGuiCol_ResizeGripHovered, ui_accent(0.45));
    color(ImGuiCol_ResizeGripActive, ui_accent(0.70));

    color(ImGuiCol_Tab, UI_CONTROL);
    color(ImGuiCol_TabHovered, UI_CONTROL_HOVER);
    color(ImGuiCol_TabActive, ui_accent(0.35));

    color(ImGuiCol_TableHeaderBg, { UI_CONTROL[1], UI_CONTROL[2], UI_CONTROL[3], 1.0 });
    color(ImGuiCol_TableBorderStrong, UI_BORDER);
    color(ImGuiCol_TableBorderLight, { UI_BORDER[1], UI_BORDER[2], UI_BORDER[3], 0.45 });
    color(ImGuiCol_TableRowBg, UI_TRANSPARENT);
    color(ImGuiCol_TableRowBgAlt, { 1.00, 1.00, 1.00, 0.035 });

    color(ImGuiCol_PlotHistogram, UI_ACCENT);

    var(ImGuiStyleVar_WindowRounding, 6.0);
    var(ImGuiStyleVar_ChildRounding, 4.0);
    var(ImGuiStyleVar_FrameRounding, 4.0);
    var(ImGuiStyleVar_PopupRounding, 4.0);
    var(ImGuiStyleVar_ScrollbarRounding, 6.0);
    var(ImGuiStyleVar_GrabRounding, 4.0);
    var(ImGuiStyleVar_ScrollbarSize, 11.0);
    var(ImGuiStyleVar_WindowPadding, { 12 * scale, 10 * scale });
    var(ImGuiStyleVar_FramePadding, { 8 * scale, 4 * scale });
    var(ImGuiStyleVar_ItemSpacing, { 8 * scale, 5 * scale });
    var(ImGuiStyleVar_ItemInnerSpacing, { 6 * scale, 4 * scale });

    ui_theme_stack[#ui_theme_stack + 1] = { color_count, var_count };
end

local function pop_theme()
    local entry = table.remove(ui_theme_stack);
    if entry == nil then return; end
    if entry[2] > 0 then imgui.PopStyleVar(entry[2]); end
    if entry[1] > 0 then imgui.PopStyleColor(entry[1]); end
end

-- Short accent bar along the bottom edge of the last drawn item.
local function draw_item_underline()
    if imgui.GetItemRectMin == nil or imgui.GetItemRectMax == nil then return; end

    local min_x = imgui.GetItemRectMin();
    local max_x, max_y = imgui.GetItemRectMax();
    min_x = tonumber(min_x); max_x = tonumber(max_x); max_y = tonumber(max_y);
    if min_x == nil or max_x == nil or max_y == nil then return; end

    local draw_list = imgui.GetWindowDrawList();
    if draw_list == nil then return; end

    draw_list:AddRectFilled({ min_x + 4, max_y - 2 }, { max_x - 4, max_y }, imgui.GetColorU32(UI_ACCENT), 1.0);
end

-- On/off button: accent-tinted fill and underline when selected.
local function draw_toggle_button(label, id, selected, size)
    if selected then
        imgui.PushStyleColor(ImGuiCol_Button, ui_accent(0.30));
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, ui_accent(0.36));
        imgui.PushStyleColor(ImGuiCol_ButtonActive, ui_accent(0.44));
        imgui.PushStyleColor(ImGuiCol_Text, UI_WHITE);
    else
        imgui.PushStyleColor(ImGuiCol_Button, UI_CONTROL);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, UI_CONTROL_HOVER);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, UI_CONTROL_ACTIVE);
        imgui.PushStyleColor(ImGuiCol_Text, UI_TEXT);
    end

    local clicked;
    if size then
        clicked = imgui.Button(label .. '##' .. id, size);
    else
        clicked = imgui.Button(label .. '##' .. id);
    end

    if selected then
        draw_item_underline();
    end

    imgui.PopStyleColor(4);
    return clicked;
end

-- Flat tab button: accent text + underline when selected.
local function draw_styled_tab(label, id, selected)
    if selected then
        imgui.PushStyleColor(ImGuiCol_Button, ui_accent(0.14));
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, ui_accent(0.18));
        imgui.PushStyleColor(ImGuiCol_ButtonActive, ui_accent(0.22));
        imgui.PushStyleColor(ImGuiCol_Text, UI_ACCENT_TEXT);
    else
        imgui.PushStyleColor(ImGuiCol_Button, { UI_CONTROL[1], UI_CONTROL[2], UI_CONTROL[3], 0.55 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, UI_CONTROL_HOVER);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, UI_CONTROL_ACTIVE);
        imgui.PushStyleColor(ImGuiCol_Text, UI_MUTED);
    end

    local clicked = imgui.Button(label .. '##' .. id);
    if selected then
        draw_item_underline();
    end

    imgui.PopStyleColor(4);
    return clicked;
end

-- Draws a row of styled tabs; returns the selected index.
local function draw_tab_row(tabs, selected, id_prefix)
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 12, 6 });
    for index, label in ipairs(tabs) do
        if index > 1 then
            imgui.SameLine(0, 4);
        end
        if draw_styled_tab(label, id_prefix .. tostring(index), index == selected) then
            selected = index;
        end
    end
    imgui.PopStyleVar(1);
    imgui.Spacing();
    imgui.Separator();
    imgui.Spacing();
    return selected;
end

local function section_header(title)
    imgui.TextColored(UI_ACCENT_TEXT, title);
    imgui.PushStyleColor(ImGuiCol_Separator, ui_accent(0.35));
    imgui.Separator();
    imgui.PopStyleColor(1);
    imgui.Spacing();
end

local function align_label()
    if imgui.AlignTextToFramePadding ~= nil then
        imgui.AlignTextToFramePadding();
    end
end

local function help_marker(text_value)
    imgui.SameLine();
    imgui.TextDisabled('(?)');
    if imgui.IsItemHovered() then
        imgui.BeginTooltip();
        imgui.PushTextWrapPos(420);
        imgui.TextUnformatted(text_value);
        imgui.PopTextWrapPos();
        imgui.EndTooltip();
    end
end

-- Theme dropdown. Returns the newly chosen key, or nil when unchanged.
local function draw_theme_combo(current_key, id)
    current_key = normalize_theme_key(current_key);
    local index = 0;
    local labels = {};
    for i, key in ipairs(UI_THEME_ORDER) do
        labels[#labels + 1] = UI_THEMES[key].label;
        if key == current_key then
            index = i - 1;
        end
    end

    local value = { index };
    if imgui.Combo('Theme##' .. tostring(id or 'theme'), value, table.concat(labels, '\0') .. '\0\0') then
        local chosen = UI_THEME_ORDER[(tonumber(value[1]) or 0) + 1];
        if chosen and chosen ~= current_key then
            return chosen;
        end
    end
    return nil;
end

-- ============================================================================

local defaults = T{
    visible = true,
    history_visible = false,
    config_visible = false,
    timers_visible = false,

    font_scale = 1.00,

    appearance = T{
        background = T{ 0.00, 0.00, 0.00, 0.45 },
        accent = T{ 0.38, 0.78, 1.00, 1.00 },
        success = T{ 0.30, 1.00, 0.42, 1.00 },
        danger = T{ 1.00, 0.34, 0.38, 1.00 },
        muted = T{ 0.68, 0.70, 0.74, 1.00 },
        border = true,
        title_bar = true,
        theme = 'forest',
        -- 1.6.0
        history_own_alpha = false,          -- History / Mob detail use their own opacity
        history_alpha = 0.85,
        zone_highlight = T{ 1.00, 0.82, 0.35, 1.00 },   -- current-zone mobs in All Zones
    },

    behavior = T{
        target_only = true,
        mini_mode = false,
        history_current_zone = true,
        show_session = true,
        show_drops = true,
        show_kills_per_hour = true,
        show_by_job = true,
        include_zero_drop_rows = false,
        debug = false,
        encounter_timeout = 120,
        credit_party_kills = true,
        -- 1.6.0
        track_abilities = true,     -- count mob TP moves / spells
        abilities_target = true,    -- top abilities in the target window
        abilities_rows = 4,         -- how many (one per row)
        zone_highlight = true,      -- highlight this zone's mobs when All Zones is shown
    },

    locks = T{
        target = false,
        history = false,
        config = false,
        timers = false,     -- 1.7.0
    },

    config_page = 'general',   -- 1.7.0: last settings page

    window = T{
        x = 150,
        y = 150,
        width = 470,
        height = 420,
    },

    mini_window = T{
        x = 150,
        y = 150,
        width = 345,
        height = 118,
    },

    history_window = T{
        x = 650,
        y = 130,
        width = 900,
        height = 700,
    },

    config_window = T{
        x = 1160,
        y = 150,
        width = 470,
        height = 590,
    },

    timers_window = T{
        x = 650,
        y = 150,
        width = 330,
        height = 200,
    },

    records = T{},

    -- Lightweight reload-safe markers. These do NOT add statistics themselves;
    -- they only tell a newly-loaded MobHunt instance that a fight was already
    -- counted before the addon reload.
    active_encounters = T{},
};

uifont.defaults(defaults);   -- window font (Tahoma) and tooltips
local config = settings.load(defaults);

local state = T{
    visible = { config.visible ~= false },
    history_visible = { config.history_visible == true },
    config_visible = { config.config_visible == true },
    timers_visible = { config.timers_visible == true },
    timers_apply_geometry = true,
    timers_geom = {
        tonumber(config.timers_window and config.timers_window.x) or 650,
        tonumber(config.timers_window and config.timers_window.y) or 150,
    },

    font_scale = { tonumber(config.font_scale) or 1.00 },

    background = {
        tonumber(config.appearance and config.appearance.background and config.appearance.background[1]) or defaults.appearance.background[1],
        tonumber(config.appearance and config.appearance.background and config.appearance.background[2]) or defaults.appearance.background[2],
        tonumber(config.appearance and config.appearance.background and config.appearance.background[3]) or defaults.appearance.background[3],
        tonumber(config.appearance and config.appearance.background and config.appearance.background[4]) or defaults.appearance.background[4],
    },
    accent = {
        tonumber(config.appearance and config.appearance.accent and config.appearance.accent[1]) or defaults.appearance.accent[1],
        tonumber(config.appearance and config.appearance.accent and config.appearance.accent[2]) or defaults.appearance.accent[2],
        tonumber(config.appearance and config.appearance.accent and config.appearance.accent[3]) or defaults.appearance.accent[3],
        tonumber(config.appearance and config.appearance.accent and config.appearance.accent[4]) or defaults.appearance.accent[4],
    },
    success = {
        tonumber(config.appearance and config.appearance.success and config.appearance.success[1]) or defaults.appearance.success[1],
        tonumber(config.appearance and config.appearance.success and config.appearance.success[2]) or defaults.appearance.success[2],
        tonumber(config.appearance and config.appearance.success and config.appearance.success[3]) or defaults.appearance.success[3],
        tonumber(config.appearance and config.appearance.success and config.appearance.success[4]) or defaults.appearance.success[4],
    },
    danger = {
        tonumber(config.appearance and config.appearance.danger and config.appearance.danger[1]) or defaults.appearance.danger[1],
        tonumber(config.appearance and config.appearance.danger and config.appearance.danger[2]) or defaults.appearance.danger[2],
        tonumber(config.appearance and config.appearance.danger and config.appearance.danger[3]) or defaults.appearance.danger[3],
        tonumber(config.appearance and config.appearance.danger and config.appearance.danger[4]) or defaults.appearance.danger[4],
    },
    muted = {
        tonumber(config.appearance and config.appearance.muted and config.appearance.muted[1]) or defaults.appearance.muted[1],
        tonumber(config.appearance and config.appearance.muted and config.appearance.muted[2]) or defaults.appearance.muted[2],
        tonumber(config.appearance and config.appearance.muted and config.appearance.muted[3]) or defaults.appearance.muted[3],
        tonumber(config.appearance and config.appearance.muted and config.appearance.muted[4]) or defaults.appearance.muted[4],
    },

    theme = tostring(config.appearance and config.appearance.theme or 'forest'),
    border = { not (config.appearance and config.appearance.border == false) },
    title_bar = { not (config.appearance and config.appearance.title_bar == false) },

    target_only = { not (config.behavior and config.behavior.target_only == false) },
    mini_mode = { config.behavior and config.behavior.mini_mode == true },
    history_current_zone = { not (config.behavior and config.behavior.history_current_zone == false) },
    show_session = { not (config.behavior and config.behavior.show_session == false) },
    show_drops = { not (config.behavior and config.behavior.show_drops == false) },
    show_kills_per_hour = { not (config.behavior and config.behavior.show_kills_per_hour == false) },
    show_by_job = { not (config.behavior and config.behavior.show_by_job == false) },
    debug = { config.behavior and config.behavior.debug == true },
    encounter_timeout = { tonumber(config.behavior and config.behavior.encounter_timeout) or 120 },
    credit_party_kills = { not (config.behavior and config.behavior.credit_party_kills == false) },

    lock_target = { config.locks and config.locks.target == true },
    lock_history = { config.locks and config.locks.history == true },
    lock_config = { config.locks and config.locks.config == true },

    target_apply_geometry = true,
    history_apply_geometry = true,
    config_apply_geometry = true,

    target_geom = {
        tonumber(config.window and config.window.x) or defaults.window.x,
        tonumber(config.window and config.window.y) or defaults.window.y,
        tonumber(config.window and config.window.width) or defaults.window.width,
        tonumber(config.window and config.window.height) or defaults.window.height,
    },
    mini_geom = {
        tonumber(config.mini_window and config.mini_window.x) or defaults.mini_window.x,
        tonumber(config.mini_window and config.mini_window.y) or defaults.mini_window.y,
        tonumber(config.mini_window and config.mini_window.width) or defaults.mini_window.width,
        tonumber(config.mini_window and config.mini_window.height) or defaults.mini_window.height,
    },
    mini_apply_geometry = true,
    history_geom = {
        tonumber(config.history_window and config.history_window.x) or defaults.history_window.x,
        tonumber(config.history_window and config.history_window.y) or defaults.history_window.y,
        tonumber(config.history_window and config.history_window.width) or defaults.history_window.width,
        tonumber(config.history_window and config.history_window.height) or defaults.history_window.height,
    },
    config_geom = {
        tonumber(config.config_window and config.config_window.x) or defaults.config_window.x,
        tonumber(config.config_window and config.config_window.y) or defaults.config_window.y,
        tonumber(config.config_window and config.config_window.width) or defaults.config_window.width,
        tonumber(config.config_window and config.config_window.height) or defaults.config_window.height,
    },

    geometry_dirty = false,
    settings_dirty = false,
    data_dirty = false,
    last_save = 0,
    last_data_save = 0,
    config_tab = 1,

    -- Mobs a party / alliance member killed that were not your tracked kill.
    -- Used so their treasure is not credited to your mob.
    recent_party_kills = T{},   -- [mob_server_id] = os.clock()
    -- Mobs you drew your weapon on. A fight only counts once a real action
    -- happens between that mob and you / your party.
    pending_engage = T{},       -- [mob_server_id] = { info = ..., time = os.clock() }
    zone_name_cache = T{},      -- [zone_id] = name

    session_start = os.time(),
    session = T{},
    encounters = T{},       -- [mob_server_id] = encounter
    recent_dead = T{},      -- [mob_server_id] = { key, time, drop_occurrences }
    recent_kills = T{},     -- [mob_server_id] = os.clock()
    recent_deaths = T{},    -- [mob_server_id] = os.clock()
    last_hostile = nil,     -- most recent tracked mob that acted on the player
    last_player_hp = nil,
    player_dead = false,
    inventory_slots = T{},  -- [bag:index] = { item_id, count } used for direct-drop deltas
    inventory_cache_ready = false,
    treasure_slots = T{},   -- [0..9] = last observed ItemId in Ashita treasure-pool memory
    treasure_cache_ready = false,
    treasure_last_scan = 0,
    entity_cache = T{},     -- [server_id] = { index, name, zone_id, zone_name }
    current_target = nil,

    history_search = { '' },
    history_last_search = '',
    history_selected_key = nil,
    history_sort = 'kills',
    history_sort_desc = true,
    history_delete_key = nil,
    detail_open = false,      -- Mob detail window (docked beside History)
    detail_delete_at = nil,   -- os.clock() of the first Delete click (two-click confirm)
    purge_armed = nil,        -- { id = 'all' | 'drops', at = os.clock() } for Config > Data
    history_frame = nil,      -- { x, y, w, h } of History this frame, for docking

    debug_counters = T{
        actions = 0,
        starts = 0,
        resumes = 0,
        kills = 0,
        deaths = 0,
        drop_packets = 0,
        treasure_memory_scans = 0,
        treasure_memory_drops = 0,
        inventory_packets = 0,
        direct_drops = 0,
        drops = 0,
        ignored_drops = 0,
    },
};

local DEATH_MESSAGES = T{ 6, 20, 113, 406, 605, 646 };

-- MobHunt originally shipped with an opaque blue-black background. 1.0.10
-- moves the stock appearance to the lighter StatusTimers-style black panel.
local LEGACY_DEFAULT_BG = T{ 0.018, 0.024, 0.032, 0.94 };
local STATUSTIMERS_BG = T{ 0.00, 0.00, 0.00, 0.45 };

local function dbg(message)
    if not state.debug[1] then return; end
    print(('[MobHunt] %s'):fmt(tostring(message)));
end

local function ensure_config_tables()
    if config.appearance == nil then config.appearance = T{}; end
    if config.behavior == nil then config.behavior = T{}; end
    if config.locks == nil then config.locks = T{}; end
    if config.window == nil then config.window = T{}; end
    if config.mini_window == nil then config.mini_window = T{}; end
    if config.history_window == nil then config.history_window = T{}; end
    if config.config_window == nil then config.config_window = T{}; end
    if config.timers_window == nil then config.timers_window = T{}; end
    if config.records == nil then config.records = T{}; end
    if config.active_encounters == nil then config.active_encounters = T{}; end

    local names = { 'background', 'accent', 'success', 'danger', 'muted' };
    for _, name in ipairs(names) do
        if config.appearance[name] == nil then config.appearance[name] = T{}; end
    end

    -- 1.6.0 settings.
    for k, v in pairs(defaults.appearance) do
        if config.appearance[k] == nil and type(v) ~= 'table' then config.appearance[k] = v; end
    end
    if config.appearance.zone_highlight == nil or #config.appearance.zone_highlight < 4 then
        config.appearance.zone_highlight = T{ 1.00, 0.82, 0.35, 1.00 };
    end
    for k, v in pairs(defaults.behavior) do
        if config.behavior[k] == nil then config.behavior[k] = v; end
    end
    if config.locks.timers == nil then config.locks.timers = false; end

    -- 1.7.0: every window has its own size and (optional) opacity. A save
    -- from before starts each window at the old shared Font Scale, and
    -- History keeps its old own opacity.
    if config.appearance.win == nil then
        local base = tonumber(config.font_scale) or 1.0;
        config.appearance.win = T{
            target  = T{ scale = base, own_alpha = false, alpha = 0.45 },
            history = T{ scale = base, own_alpha = config.appearance.history_own_alpha == true,
                         alpha = tonumber(config.appearance.history_alpha) or 0.85 },
            timers  = T{ scale = base, own_alpha = false, alpha = 0.45 },
            config  = T{ scale = 1.0, own_alpha = true, alpha = 0.95 },
        };
    end
    for _, k in ipairs({ 'target', 'history', 'timers', 'config' }) do
        if config.appearance.win[k] == nil then config.appearance.win[k] = T{ scale = 1.0, own_alpha = false, alpha = 0.45 }; end
        local w = config.appearance.win[k];
        if tonumber(w.scale) == nil then w.scale = 1.0; end
        if w.own_alpha == nil then w.own_alpha = false; end
        if tonumber(w.alpha) == nil then w.alpha = 0.45; end
    end
    -- 1.7.0: the settings window always has its own opacity.
    config.appearance.win.config.own_alpha = true;
    if config.appearance.win.config.alpha_v2 == nil then
        config.appearance.win.config.alpha = 0.95;
        config.appearance.win.config.alpha_v2 = true;
    end
    if config.appearance.use_theme_bg == nil then config.appearance.use_theme_bg = false; end
    if config.config_page == nil then config.config_page = 'general'; end
    uifont.defaults(config);
end

ensure_config_tables();
uifont.set_global(config);
uifont.install_tooltips();

local function approximately(a, b)
    return math.abs((tonumber(a) or 0) - (tonumber(b) or 0)) < 0.002;
end

local function is_legacy_default_background(bg)
    if bg == nil then return false; end
    for i = 1, 4 do
        if not approximately(bg[i], LEGACY_DEFAULT_BG[i]) then return false; end
    end
    return true;
end

local function normalize_name(value)
    if value == nil then return ''; end
    return tostring(value):lower():gsub('[^%w]', '');
end

local function record_key(zone_id, name)
    return ('z%d_%s'):fmt(tonumber(zone_id) or 0, normalize_name(name));
end

local function safe_zone_name(zone_id)
    local cached = state.zone_name_cache[tonumber(zone_id) or 0];
    if cached ~= nil then return cached; end

    local rm = AshitaCore:GetResourceManager();
    if rm == nil then return ('Zone %d'):fmt(tonumber(zone_id) or 0); end

    local ok, value = pcall(function()
        return rm:GetString('zones.names', tonumber(zone_id) or 0);
    end);

    if ok and value ~= nil and tostring(value) ~= '' then
        state.zone_name_cache[tonumber(zone_id) or 0] = tostring(value);
        return tostring(value);
    end

    return ('Zone %d'):fmt(tonumber(zone_id) or 0);
end

-- True when the server id belongs to the player's party / alliance.
local function is_party_member(server_id)
    server_id = tonumber(server_id);
    if not server_id or server_id == 0 then return false; end

    local found = false;
    pcall(function()
        local party = AshitaCore:GetMemoryManager():GetParty();
        for slot = 0, 17 do
            if party:GetMemberServerId(slot) == server_id then
                found = true;
                return;
            end
        end
    end);
    return found;
end

-- True when the claim id (low 16 bits, as the client stores it) belongs to
-- you or a party / alliance member.
local function claimed_by_party(claim)
    claim = tonumber(claim) or 0;
    local low = bit.band(claim, 0xFFFF);
    if low == 0 then return false; end

    local found = false;
    pcall(function()
        local party = AshitaCore:GetMemoryManager():GetParty();
        for slot = 0, 17 do
            local sid = tonumber(party:GetMemberServerId(slot)) or 0;
            if sid ~= 0 and (sid == claim or bit.band(sid, 0xFFFF) == low) then
                found = true;
                return;
            end
        end
    end);
    return found;
end

-- Live check on a mob: still the same entity, still alive, and claimed by
-- you or your party. Used to keep encounters open while you fight other
-- mobs (slept / bound / waiting adds) and to credit party kills.
local function mob_alive_and_party_claimed(mob_id, index)
    mob_id = tonumber(mob_id) or 0;
    index = tonumber(index) or 0;
    if mob_id == 0 or index <= 0 then return false; end

    local ok, alive, claimed = pcall(function()
        local em = AshitaCore:GetMemoryManager():GetEntity();
        if em == nil then return false, false; end
        if tonumber(em:GetServerId(index)) ~= mob_id then return false, false; end
        local hpp = tonumber(em:GetHPPercent(index)) or 0;
        return hpp > 0, claimed_by_party(em:GetClaimStatus(index));
    end);

    if not ok then return false; end
    return alive == true and claimed == true;
end

local function mob_party_claimed(mob_id, index)
    mob_id = tonumber(mob_id) or 0;
    index = tonumber(index) or 0;
    if mob_id == 0 or index <= 0 then return false; end

    local ok, claimed = pcall(function()
        local em = AshitaCore:GetMemoryManager():GetEntity();
        if em == nil then return false; end
        if tonumber(em:GetServerId(index)) ~= mob_id then return false; end
        return claimed_by_party(em:GetClaimStatus(index));
    end);

    return ok and claimed == true;
end

local function get_zone_id()
    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return 0; end

    local party = mm:GetParty();
    if party == nil then return 0; end

    local ok, zid = pcall(function() return party:GetMemberZone(0); end);
    if not ok then return 0; end

    return tonumber(zid) or 0;
end

local function get_player_id()
    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return 0; end

    local party = mm:GetParty();
    if party ~= nil then
        local ok, pid = pcall(function() return party:GetMemberServerId(0); end);
        if ok and tonumber(pid) and tonumber(pid) ~= 0 then
            return tonumber(pid);
        end
    end

    -- Safe fallback; never call GetServerId through a nil player object.
    local player = mm:GetPlayer();
    if not player then return 0; end

    local ok, pid = pcall(function() return player:GetServerId(); end);
    if ok then return tonumber(pid) or 0; end

    return 0;
end

local function get_entity_manager()
    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return nil; end
    local entity_mgr = mm:GetEntity();
    if not entity_mgr then return nil; end
    return entity_mgr;
end

local function get_entity_info(index, forced_id)
    index = tonumber(index);
    if index == nil or index < 0 then return nil; end

    local entity_mgr = get_entity_manager();
    if not entity_mgr then return nil; end

    local ok_id, sid = pcall(function() return entity_mgr:GetServerId(index); end);
    local ok_name, name = pcall(function() return entity_mgr:GetName(index); end);
    local ok_spawn, spawn_flags = pcall(function() return entity_mgr:GetSpawnFlags(index); end);

    sid = ok_id and tonumber(sid) or tonumber(forced_id);
    name = ok_name and tostring(name or '') or '';
    spawn_flags = ok_spawn and tonumber(spawn_flags) or 0;

    if (sid == nil or sid == 0) and tonumber(forced_id) then
        sid = tonumber(forced_id);
    end

    if sid == nil or sid == 0 or name == '' then
        return nil;
    end

    local zone_id = get_zone_id();
    local info = T{
        id = sid,
        index = index,
        name = name,
        zone_id = zone_id,
        zone_name = safe_zone_name(zone_id),
        spawn_flags = spawn_flags,
        is_mob = bit.band(spawn_flags, 0x0010) == 0x0010,
    };

    state.entity_cache[sid] = info;
    return info;
end

local function resolve_entity(server_id, hinted_index)
    server_id = tonumber(server_id);
    if server_id == nil or server_id == 0 then return nil; end

    if hinted_index ~= nil then
        local info = get_entity_info(hinted_index, server_id);
        if info ~= nil and info.id == server_id then return info; end
    end

    local cached = state.entity_cache[server_id];
    if cached ~= nil then
        local info = get_entity_info(cached.index, server_id);
        if info ~= nil and info.id == server_id then return info; end
        state.entity_cache[server_id] = nil;
    end

    local entity_mgr = get_entity_manager();
    if not entity_mgr then return nil; end

    local map_size = 2303;
    local ok_size, size = pcall(function() return entity_mgr:GetEntityMapSize(); end);
    if ok_size and tonumber(size) and tonumber(size) > 0 then
        map_size = math.min(tonumber(size) - 1, 4095);
    end

    for index = 0, map_size do
        local ok, sid = pcall(function() return entity_mgr:GetServerId(index); end);
        if ok and tonumber(sid) == server_id then
            return get_entity_info(index, server_id);
        end
    end

    return nil;
end

local function get_current_target()
    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return nil; end

    local target_mgr = mm:GetTarget();
    if target_mgr == nil then return nil; end

    local target_index = 0;
    local ok_sub, is_sub = pcall(function() return target_mgr:GetIsSubTargetActive(); end);
    if ok_sub and tonumber(is_sub) ~= 0 then
        local ok_idx, idx = pcall(function() return target_mgr:GetTargetIndex(1); end);
        if ok_idx then target_index = tonumber(idx) or 0; end
    else
        local ok_idx, idx = pcall(function() return target_mgr:GetTargetIndex(0); end);
        if ok_idx then target_index = tonumber(idx) or 0; end
    end

    if target_index <= 0 then return nil; end
    local info = get_entity_info(target_index);
    if info == nil or info.is_mob ~= true then return nil; end
    return info;
end

local function get_or_create_record(info)
    if info == nil or info.name == nil or info.name == '' or info.is_mob ~= true then return nil, nil; end

    local key = record_key(info.zone_id, info.name);
    local rec = config.records[key];

    if rec == nil then
        rec = T{
            name = info.name,
            zone_id = tonumber(info.zone_id) or 0,
            zone_name = info.zone_name or safe_zone_name(info.zone_id),
            fights = 0,
            kills = 0,
            deaths = 0,
            first_seen = os.time(),
            last_seen = os.time(),
            last_kill = 0,
            last_death = 0,
            current_streak = 0,
            best_streak = 0,
            drops = T{},
        };
        config.records[key] = rec;
        state.data_dirty = true;
    end

    if rec.drops == nil then rec.drops = T{}; end
    if rec.zone_name == nil or rec.zone_name == '' then rec.zone_name = info.zone_name; end
    if rec.name == nil or rec.name == '' then rec.name = info.name; end

    return rec, key;
end

local function get_session_record(key)
    if key == nil then return nil; end

    local s = state.session[key];
    if s == nil then
        s = T{
            fights = 0,
            kills = 0,
            deaths = 0,
            drops = T{},
            first_fight = 0,
        };
        state.session[key] = s;
    end
    if s.drops == nil then s.drops = T{}; end
    return s;
end

local function encounter_marker_key(mob_id)
    return tostring(tonumber(mob_id) or 0);
end

local function clear_persisted_encounter(mob_id)
    if config.active_encounters == nil then return; end
    config.active_encounters[encounter_marker_key(mob_id)] = nil;
end

local function persist_encounter(enc)
    if enc == nil or enc.id == nil then return; end
    if config.active_encounters == nil then config.active_encounters = T{}; end

    config.active_encounters[encounter_marker_key(enc.id)] = T{
        id = tonumber(enc.id) or 0,
        index = tonumber(enc.index) or 0,
        name = tostring(enc.name or ''),
        zone_id = tonumber(enc.zone_id) or 0,
        zone_name = tostring(enc.zone_name or ''),
        key = tostring(enc.key or ''),
        started_wall = tonumber(enc.started_wall) or os.time(),
        last_activity_wall = os.time(),
    };
end

local function can_resume_persisted_encounter(info, key, marker)
    if marker == nil then return false; end

    local now = os.time();
    local timeout = math.max(15, tonumber(state.encounter_timeout[1]) or 120);
    local last_wall = tonumber(marker.last_activity_wall) or tonumber(marker.started_wall) or 0;

    if last_wall <= 0 or (now - last_wall) > timeout then return false; end
    if tonumber(marker.id) ~= tonumber(info.id) then return false; end
    if tonumber(marker.zone_id) ~= tonumber(info.zone_id) then return false; end
    if tostring(marker.key or '') ~= tostring(key or '') then return false; end
    if normalize_name(marker.name) ~= normalize_name(info.name) then return false; end

    return true;
end

-- ----------------------------------------------------------------------------
-- Per-job statistics: every fight / kill / death / EXP / fight time is also
-- filed under the main job you were on when the fight started.
-- ----------------------------------------------------------------------------
local JOB_NAMES = {
    'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST',
    'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP',
};

local function current_job_name()
    local ok, id = pcall(function()
        return AshitaCore:GetMemoryManager():GetPlayer():GetMainJob();
    end);
    if not ok then return nil; end
    return JOB_NAMES[tonumber(id) or 0];
end

local function job_stats(rec, job)
    if rec == nil or job == nil then return nil; end
    if rec.by_job == nil then rec.by_job = T{}; end
    local j = rec.by_job[job];
    if j == nil then
        j = T{ fights = 0, kills = 0, deaths = 0, exp_total = 0, exp_kills = 0, fight_seconds = 0, timed_kills = 0 };
        rec.by_job[job] = j;
    end
    return j;
end

local function start_encounter(info, reason)
    if state.player_dead == true then return; end
    if info == nil or info.id == nil or info.name == nil or info.name == '' or info.is_mob ~= true then return; end

    state.pending_engage[info.id] = nil;

    local existing = state.encounters[info.id];
    if existing ~= nil then
        existing.last_activity = os.clock();
        existing.last_activity_wall = os.time();
        persist_encounter(existing);
        return;
    end

    local rec, key = get_or_create_record(info);
    if rec == nil then return; end

    -- A reload wipes state.encounters, but the persistent marker survives.
    -- If this is the same mob/zone fight and it is still fresh, restore the
    -- runtime encounter WITHOUT incrementing the lifetime fight counter again.
    local marker = config.active_encounters and
        config.active_encounters[encounter_marker_key(info.id)] or nil;

    if can_resume_persisted_encounter(info, key, marker) then
        state.encounters[info.id] = T{
            id = info.id,
            index = info.index,
            name = info.name,
            zone_id = info.zone_id,
            zone_name = info.zone_name,
            key = key,
            started = os.clock(),
            last_activity = os.clock(),
            started_wall = tonumber(marker.started_wall) or os.time(),
            last_activity_wall = os.time(),
            resumed = true,
            job = current_job_name(),
        };

        -- Session statistics intentionally restart when the addon reloads.
        -- Count the already-active fight once in this new runtime session so a
        -- subsequent kill/death does not produce Kills > Fights for the session.
        local s = get_session_record(key);
        if (tonumber(s.fights) or 0) == 0 then
            s.fights = 1;
            s.first_fight = os.time();
        end

        persist_encounter(state.encounters[info.id]);
        state.debug_counters.resumes = (tonumber(state.debug_counters.resumes) or 0) + 1;
        dbg(('Resumed existing encounter after reload: %s (%s), reason=%s'):fmt(
            info.name, info.zone_name, tostring(reason)));
        return;
    end

    -- Any stale/recycled marker with this server id must not suppress a truly
    -- new fight.
    clear_persisted_encounter(info.id);

    rec.fights = (tonumber(rec.fights) or 0) + 1;
    rec.last_seen = os.time();

    local job = current_job_name();
    local js = job_stats(rec, job);
    if js then js.fights = (tonumber(js.fights) or 0) + 1; end

    local s = get_session_record(key);
    s.fights = (tonumber(s.fights) or 0) + 1;
    if tonumber(s.first_fight) == 0 then s.first_fight = os.time(); end

    state.encounters[info.id] = T{
        id = info.id,
        index = info.index,
        name = info.name,
        zone_id = info.zone_id,
        zone_name = info.zone_name,
        key = key,
        started = os.clock(),
        last_activity = os.clock(),
        started_wall = os.time(),
        last_activity_wall = os.time(),
        resumed = false,
        reason = tostring(reason or ''),
        job = job,
    };

    persist_encounter(state.encounters[info.id]);

    state.debug_counters.starts = (tonumber(state.debug_counters.starts) or 0) + 1;
    state.data_dirty = true;
    dbg(('Encounter: %s (%s), reason=%s'):fmt(info.name, info.zone_name, tostring(reason)));
end

local function touch_encounter(mob_id)
    mob_id = tonumber(mob_id) or 0;
    local enc = state.encounters[mob_id];
    if enc ~= nil then
        enc.last_activity = os.clock();
        enc.last_activity_wall = os.time();
        persist_encounter(enc);
    end
end

-- ============================================================================
-- Mob abilities (1.6.0)
--
-- 0x028 from a mob you are fighting:
--   category 7  TP move starts      (first action's value = move id; header
--   category 8  spell cast starts    param 28787 instead = interrupted)
--   category 11 TP move finished    (header param = move id)
--   category 4  spell finished      (header param = spell id)
-- A move counts as "started" the moment it starts (interrupted or not). It is
-- kept on the fight and added to the mob's record only when the mob dies, so
-- nothing shows mid-fight.
-- ============================================================================

local INTERRUPTED = 28787;
local ability_names = {};   -- ['m' .. id] / ['s' .. id] = name

local function res_text(arr)
    local out = nil;
    pcall(function()
        for _, i in ipairs({ 1, 0, 2 }) do
            local v = arr[i];
            if type(v) == 'string' and v ~= '' then out = v; return; end
        end
    end);
    return out;
end

local function move_name(id)
    local key = 'm' .. tostring(id);
    if ability_names[key] ~= nil then return ability_names[key]; end
    local rm = AshitaCore:GetResourceManager();
    local n = nil;
    local function str(i)
        local v = nil;
        pcall(function() v = rm:GetString('monsters.abilities', i); end);
        if type(v) == 'string' and v:match('%w') then return v; end
        return nil;
    end
    if id >= 256 then n = str(id - 256); end
    n = n or str(id);
    if n == nil then pcall(function() n = res_text(rm:GetAbilityById(id).Name); end); end
    n = n or ('Move #' .. tostring(id));
    ability_names[key] = n;
    return n;
end

local function spell_name(id)
    local key = 's' .. tostring(id);
    if ability_names[key] ~= nil then return ability_names[key]; end
    local n = nil;
    pcall(function() n = res_text(AshitaCore:GetResourceManager():GetSpellById(id).Name); end);
    n = n or ('Spell #' .. tostring(id));
    ability_names[key] = n;
    return n;
end

local function enc_ability(enc, name, kind)
    enc.abil = enc.abil or T{};
    local a = enc.abil[name];
    if a == nil then
        a = T{ s = 0, f = 0, k = kind };
        enc.abil[name] = a;
    end
    return a;
end

-- Called for every action packet.
local function track_mob_ability(act)
    if config.behavior == nil or config.behavior.track_abilities == false then return; end
    local enc = state.encounters[act.actor_id];
    if enc == nil then return; end
    local cat = tonumber(act.category) or 0;
    -- 1.6.2: MobHunt reads 32 bits there; the move / spell id can sit in
    -- either half (HorizonXI: the low half - finishes were never counted,
    -- so everything read "100% interrupted").
    local p32 = tonumber(act.param) or 0;
    local hi, lo = math.floor(p32 / 65536), p32 % 65536;
    local hparam = (hi ~= 0) and hi or lo;
    local first = act.targets[1];
    if cat == 7 or cat == 8 then
        local kind = (cat == 7) and 'tp' or 'ma';
        if hi == INTERRUPTED or lo == INTERRUPTED then
            enc.casting = nil;
            return;
        end
        local id = first and tonumber(first.first_value) or nil;
        if id == nil or id == 0 then return; end
        local name = (cat == 7) and move_name(id) or spell_name(id);
        enc_ability(enc, name, kind).s = enc_ability(enc, name, kind).s + 1;
        enc.casting = name;
    elseif cat == 11 or cat == 4 then
        local kind = (cat == 11) and 'tp' or 'ma';
        if hparam == 0 then return; end
        local name = (cat == 11) and move_name(hparam) or spell_name(hparam);
        local a = enc_ability(enc, name, kind);
        if enc.casting ~= name then
            -- No start seen (instant move): it started and finished now.
            a.s = a.s + 1;
        end
        a.f = a.f + 1;
        enc.casting = nil;
    end
end

-- The mob died: the fight's abilities go into its record.
local function commit_abilities(rec, enc)
    if enc == nil or enc.abil == nil or next(enc.abil) == nil then return; end
    rec.abilities = rec.abilities or T{};
    for name, a in pairs(enc.abil) do
        local r = rec.abilities[name];
        if r == nil then
            r = T{ s = 0, f = 0, k = a.k };
            rec.abilities[name] = r;
        end
        r.s = (tonumber(r.s) or 0) + a.s;
        r.f = (tonumber(r.f) or 0) + a.f;
        -- Starts counted since 1.6.2, when finishes are read right: the
        -- interrupted % only uses these.
        r.s2 = (tonumber(r.s2) or 0) + a.s;
    end
    rec.ability_kills = (tonumber(rec.ability_kills) or 0) + 1;
end

-- Sorted list: { name, s, f, k, share }.
local function sorted_abilities(rec)
    local list, total = {}, 0;
    for name, a in pairs(rec.abilities or {}) do
        total = total + (tonumber(a.s) or 0);
        list[#list + 1] = { name = name, s = tonumber(a.s) or 0, f = tonumber(a.f) or 0, k = a.k, s2 = tonumber(a.s2) or 0 };
    end
    for _, a in ipairs(list) do a.share = (total > 0) and (a.s * 100 / total) or 0; end
    table.sort(list, function(x, y) if x.s ~= y.s then return x.s > y.s; end return x.name < y.name; end);
    return list, total;
end

local function count_kill(mob_id, hinted_index, source)
    mob_id = tonumber(mob_id);
    if mob_id == nil or mob_id == 0 then return; end

    local last = state.recent_kills[mob_id];
    if last ~= nil and (os.clock() - last) < 2.0 then
        return true;
    end

    local enc = state.encounters[mob_id];
    if enc == nil then
        -- MobHunt only credits kills after the player participated.
        return false;
    end

    local info = resolve_entity(mob_id, hinted_index) or T{
        id = mob_id,
        index = enc.index,
        name = enc.name,
        zone_id = enc.zone_id,
        zone_name = enc.zone_name,
        is_mob = true,
    };

    local rec, key = get_or_create_record(info);
    if rec == nil then return false; end

    rec.kills = (tonumber(rec.kills) or 0) + 1;
    local js = job_stats(rec, enc.job or current_job_name());
    if js then js.kills = (tonumber(js.kills) or 0) + 1; end

    -- Fight length (wall clock from the first real action to the kill).
    -- Party kills you never joined have no real length and are skipped.
    if enc.reason ~= 'party_kill' then
        local seconds = os.time() - (tonumber(enc.started_wall) or os.time());
        if seconds >= 1 and seconds <= 3600 then
            rec.fight_seconds = (tonumber(rec.fight_seconds) or 0) + seconds;
            rec.timed_kills = (tonumber(rec.timed_kills) or 0) + 1;
            if js then
                js.fight_seconds = (tonumber(js.fight_seconds) or 0) + seconds;
                js.timed_kills = (tonumber(js.timed_kills) or 0) + 1;
            end
        end
    end

    commit_abilities(rec, enc);

    rec.last_kill = os.time();
    rec.last_seen = os.time();
    rec.current_streak = (tonumber(rec.current_streak) or 0) + 1;
    rec.best_streak = math.max(tonumber(rec.best_streak) or 0, tonumber(rec.current_streak) or 0);

    local s = get_session_record(key);
    s.kills = (tonumber(s.kills) or 0) + 1;

    state.recent_kills[mob_id] = os.clock();
    state.recent_dead[mob_id] = T{
        key = key,
        job = enc.job or current_job_name(),
        time = os.clock(),
        info = info,
        treasure_seen = false,
        drop_occurrences = T{},
    };
    state.encounters[mob_id] = nil;
    clear_persisted_encounter(mob_id);

    state.debug_counters.kills = (tonumber(state.debug_counters.kills) or 0) + 1;
    state.data_dirty = true;
    dbg(('Kill: %s (%s), source=%s'):fmt(info.name, info.zone_name, tostring(source)));
    return true;
end

-- A mob death that was not one of your tracked kills. When a party member
-- made it, remember it so its treasure is not credited to your last kill.
local function note_party_kill(mob_id, killer_id)
    mob_id = tonumber(mob_id);
    if mob_id == nil or mob_id == 0 then return; end
    if state.recent_dead[mob_id] ~= nil then return; end
    -- Your own killing blow is never a "party kill": marking it as one made
    -- the treasure check refuse the drops of your own kill.
    if killer_id ~= nil and tonumber(killer_id) == tonumber(get_player_id()) then return; end
    if killer_id ~= nil and not is_party_member(killer_id) then return; end
    state.recent_party_kills[mob_id] = os.clock();
end

-- EXP from a kill you were credited for (0x02D addressed to you).
local EXP_MESSAGES = T{ 8, 105, 253 };

local function credit_kill_exp(mob_id, amount)
    mob_id = tonumber(mob_id) or 0;
    amount = tonumber(amount) or 0;
    if mob_id == 0 or amount <= 0 then return; end

    local dead = state.recent_dead[mob_id];
    if dead == nil or dead.exp_credited then return; end

    local rec = config.records[dead.key];
    if rec == nil then return; end

    rec.exp_total = (tonumber(rec.exp_total) or 0) + amount;
    rec.exp_kills = (tonumber(rec.exp_kills) or 0) + 1;

    local js = job_stats(rec, dead.job);
    if js then
        js.exp_total = (tonumber(js.exp_total) or 0) + amount;
        js.exp_kills = (tonumber(js.exp_kills) or 0) + 1;
    end

    local s = get_session_record(dead.key);
    s.exp_total = (tonumber(s.exp_total) or 0) + amount;

    dead.exp_credited = true;
    state.data_dirty = true;
    dbg(('EXP: %d from %s'):fmt(amount, tostring(rec.name)));
end

-- Most recent party kill time (clock) that is not one of your kills.
local function latest_party_kill_time()
    local latest = nil;
    for _, t in pairs(state.recent_party_kills) do
        t = tonumber(t);
        if t and (latest == nil or t > latest) then
            latest = t;
        end
    end
    return latest;
end

-- A party / alliance kill of a mob you never touched. Opens the fight and
-- counts the kill so Kills never exceed Fights; drops then credit normally.
local function credit_party_kill(mob_id, hinted_index, killer_id, source)
    if not state.credit_party_kills[1] then return false; end
    if state.player_dead == true then return false; end

    mob_id = tonumber(mob_id);
    if mob_id == nil or mob_id == 0 then return false; end

    local info = resolve_entity(mob_id, hinted_index);
    if info == nil or info.is_mob ~= true then return false; end

    -- 0x02D (EXP credit) is proof by itself. A death message needs a party
    -- killer or a party claim on the mob.
    if source ~= 'kill_packet' then
        local by_party = killer_id ~= nil and is_party_member(killer_id);
        if not by_party and not mob_party_claimed(mob_id, info.index) then
            return false;
        end
    end

    start_encounter(info, 'party_kill');
    if state.encounters[mob_id] == nil then return false; end
    return count_kill(mob_id, info.index, source .. '_party');
end

local function count_death(mob_id, hinted_index, source)
    mob_id = tonumber(mob_id);
    if mob_id == nil or mob_id == 0 then return; end

    local last = state.recent_deaths[mob_id];
    if last ~= nil and (os.clock() - (tonumber(last) or 0)) < 5.0 then
        return;
    end

    local enc = state.encounters[mob_id];
    local info = resolve_entity(mob_id, hinted_index);

    if info == nil and enc ~= nil then
        info = T{
            id = mob_id,
            index = enc.index,
            name = enc.name,
            zone_id = enc.zone_id,
            zone_name = enc.zone_name,
            is_mob = true,
        };
    end

    if info == nil or info.is_mob ~= true then return; end

    -- A killing blow proves participation even if the initial encounter packet
    -- was missed. Temporarily permit start_encounter for this path.
    if enc == nil then
        local dead_state = state.player_dead;
        state.player_dead = false;
        start_encounter(info, 'death');
        state.player_dead = dead_state;
    end

    local rec, key = get_or_create_record(info);
    if rec == nil then return; end

    rec.deaths = (tonumber(rec.deaths) or 0) + 1;
    local death_job = (enc and enc.job) or current_job_name();
    local djs = job_stats(rec, death_job);
    if djs then djs.deaths = (tonumber(djs.deaths) or 0) + 1; end
    rec.last_death = os.time();
    rec.last_seen = os.time();
    rec.current_streak = 0;

    local s = get_session_record(key);
    s.deaths = (tonumber(s.deaths) or 0) + 1;

    state.recent_deaths[mob_id] = os.clock();
    state.player_dead = true;

    -- A KO ends combat. Clear all currently-open encounters so packets received
    -- while dead cannot create phantom follow-up fights.
    for id, _ in pairs(state.encounters) do
        clear_persisted_encounter(id);
    end
    state.encounters = T{};

    state.debug_counters.deaths = (tonumber(state.debug_counters.deaths) or 0) + 1;
    state.data_dirty = true;

    dbg(('Death to: %s (%s), source=%s'):fmt(
        info.name, info.zone_name, tostring(source or 'unknown')));
end

local function item_name(item_id)
    item_id = tonumber(item_id) or 0;
    if item_id == 65535 then return 'Gil'; end

    local rm = AshitaCore:GetResourceManager();
    if rm == nil then return ('Item %d'):fmt(tonumber(item_id) or 0); end

    local ok, item = pcall(function() return rm:GetItemById(tonumber(item_id) or 0); end);
    if not ok or item == nil then return ('Item %d'):fmt(tonumber(item_id) or 0); end

    local name = nil;
    pcall(function()
        if item.Name ~= nil then
            name = item.Name[0] or item.Name[1];
        end
    end);

    if name == nil or tostring(name) == '' then
        return ('Item %d'):fmt(tonumber(item_id) or 0);
    end
    return tostring(name);
end

local function count_drop(dropper_id, dropper_index, item_id, count)
    dropper_id = tonumber(dropper_id);
    dropper_index = tonumber(dropper_index);
    item_id = tonumber(item_id);
    count = math.max(1, tonumber(count) or 1);

    state.debug_counters.drop_packets = (tonumber(state.debug_counters.drop_packets) or 0) + 1;

    if dropper_id == nil or dropper_id == 0 or item_id == nil or item_id <= 0 then
        state.debug_counters.ignored_drops = (tonumber(state.debug_counters.ignored_drops) or 0) + 1;
        dbg(('Ignored drop packet: dropper=%s index=%s item=%s count=%s'):fmt(
            tostring(dropper_id), tostring(dropper_index), tostring(item_id), tostring(count)));
        return;
    end

    -- IMPORTANT: Treasure can arrive after the monster has died/despawned and its
    -- spawn flags are no longer useful. Prefer the encounter/death record we already
    -- established instead of requiring the dead entity to resolve as a live mob.
    local key = nil;
    local rec = nil;
    local source_name = nil;

    local enc = state.encounters[dropper_id];
    if enc ~= nil then
        key = enc.key;
        rec = key and config.records[key] or nil;
        source_name = enc.name;
    end

    if rec == nil then
        local dead = state.recent_dead[dropper_id];
        if dead ~= nil and (os.clock() - (tonumber(dead.time) or 0)) <= 30.0 then
            key = dead.key;
            rec = key and config.records[key] or nil;
            source_name = dead.info and dead.info.name or nil;
        end
    end

    -- If the treasure packet arrives before our kill path has run, resolving the
    -- still-live entity is a valid fallback. This path still enforces mob filtering.
    if rec == nil then
        local info = resolve_entity(dropper_id, dropper_index);
        if info ~= nil and info.is_mob == true then
            rec, key = get_or_create_record(info);
            source_name = info.name;
        end
    end

    if rec == nil or key == nil then
        state.debug_counters.ignored_drops = (tonumber(state.debug_counters.ignored_drops) or 0) + 1;
        dbg(('Unassociated treasure: dropper=%d index=%s item=%d (%s) count=%d'):fmt(
            dropper_id, tostring(dropper_index), item_id, item_name(item_id), count));
        return;
    end

    if rec.drops == nil then rec.drops = T{}; end

    local ikey = tostring(item_id);
    local drop = rec.drops[ikey];
    if drop == nil then
        drop = T{
            item_id = item_id,
            name = item_name(item_id),
            occurrences = 0,
            quantity = 0,
            first_seen = os.time(),
            last_seen = os.time(),
        };
        rec.drops[ikey] = drop;
    end

    drop.occurrences = (tonumber(drop.occurrences) or 0) + 1;
    drop.quantity = (tonumber(drop.quantity) or 0) + count;
    drop.last_seen = os.time();
    drop.last_kill_count = tonumber(rec.kills) or 0;

    local srec = get_session_record(key);
    local sdrop = srec.drops[ikey];
    if sdrop == nil then
        sdrop = T{ occurrences = 0, quantity = 0 };
        srec.drops[ikey] = sdrop;
    end
    sdrop.occurrences = (tonumber(sdrop.occurrences) or 0) + 1;
    sdrop.quantity = (tonumber(sdrop.quantity) or 0) + count;

    state.debug_counters.drops = (tonumber(state.debug_counters.drops) or 0) + 1;
    state.data_dirty = true;
    dbg(('Drop recorded: %s x%d from %s [dropper=%d index=%s]'):fmt(
        drop.name, count, tostring(source_name or rec.name or 'Unknown'), dropper_id, tostring(dropper_index)));
end

local function inventory_slot_key(bag, index)
    return ('%d:%d'):fmt(tonumber(bag) or 0, tonumber(index) or 0);
end

local function cache_inventory_slot(bag, index, item_id, count)
    bag = tonumber(bag) or 0;
    index = tonumber(index) or 0;
    if index <= 0 then return; end
    state.inventory_slots[inventory_slot_key(bag, index)] = T{
        item_id = tonumber(item_id) or 0,
        count = tonumber(count) or 0,
    };
end

local function initialize_inventory_cache()
    if state.inventory_cache_ready then return; end

    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return; end
    local inv = mm:GetInventory();
    if inv == nil then return; end

    local max_slots = 80;
    local ok_max, value = pcall(function() return inv:GetContainerCountMax(0); end);
    if ok_max and tonumber(value) and tonumber(value) > 0 then
        max_slots = tonumber(value);
    end

    for index = 1, max_slots do
        local ok_item, item = pcall(function() return inv:GetContainerItem(0, index); end);
        if ok_item and item ~= nil then
            cache_inventory_slot(0, index, item.Id, item.Count);
        else
            cache_inventory_slot(0, index, 0, 0);
        end
    end

    state.inventory_cache_ready = true;
end

local function most_recent_direct_drop_source()
    local now = os.clock();
    local best = nil;
    local best_time = -1;

    for _, dead in pairs(state.recent_dead) do
        if dead ~= nil then
            local t = tonumber(dead.time) or 0;
            local age = now - t;
            -- Direct inventory awards normally arrive essentially with the kill.
            -- Keep this deliberately tight to avoid attributing unrelated inventory changes.
            if age >= 0 and age <= 6.0 and dead.treasure_seen ~= true and t > best_time then
                if dead.key ~= nil and config.records[dead.key] ~= nil then
                    best = dead;
                    best_time = t;
                end
            end
        end
    end

    return best;
end

local function most_recent_kill_source(max_age)
    local now = os.clock();
    local best = nil;
    local best_time = -1;
    max_age = tonumber(max_age) or 12.0;

    for _, dead in pairs(state.recent_dead) do
        if dead ~= nil then
            local t = tonumber(dead.time) or 0;
            local age = now - t;
            if age >= 0 and age <= max_age and t > best_time then
                best = dead;
                best_time = t;
            end
        end
    end

    return best;
end

local function record_drop_for_dead(dead, item_id, quantity, source)
    if dead == nil or dead.key == nil then return false; end

    item_id = tonumber(item_id) or 0;
    quantity = math.max(1, tonumber(quantity) or 1);

    -- 0 = invalid; 65535 is gil in the treasure pool and is not treated as an item drop.
    if item_id <= 0 or item_id == 65535 then return false; end

    local rec = config.records[dead.key];
    if rec == nil then
        dbg(('Drop ignored: record no longer exists for key=%s item=%d source=%s'):fmt(
            tostring(dead.key), item_id, tostring(source)));
        return false;
    end

    if rec.drops == nil then rec.drops = T{}; end

    local ikey = tostring(item_id);
    local drop = rec.drops[ikey];
    if drop == nil then
        drop = T{
            item_id = item_id,
            name = item_name(item_id),
            occurrences = 0,
            quantity = 0,
            first_seen = os.time(),
            last_seen = os.time(),
        };
        rec.drops[ikey] = drop;
    end

    -- Occurrence means "this item appeared on this kill", not item quantity.
    -- Three Fire Crystals from one kill = occurrences 1, quantity 3.
    if dead.drop_occurrences == nil then dead.drop_occurrences = T{}; end
    local first_for_kill = dead.drop_occurrences[ikey] ~= true;

    if first_for_kill then
        drop.occurrences = (tonumber(drop.occurrences) or 0) + 1;
        dead.drop_occurrences[ikey] = true;
        -- Kill count when it last dropped (for "kills since last drop").
        drop.last_kill_count = tonumber(rec.kills) or 0;
    end

    drop.quantity = (tonumber(drop.quantity) or 0) + quantity;
    drop.last_seen = os.time();

    local srec = get_session_record(dead.key);
    local sdrop = srec.drops[ikey];
    if sdrop == nil then
        sdrop = T{ occurrences = 0, quantity = 0 };
        srec.drops[ikey] = sdrop;
    end

    if first_for_kill then
        sdrop.occurrences = (tonumber(sdrop.occurrences) or 0) + 1;
    end
    sdrop.quantity = (tonumber(sdrop.quantity) or 0) + quantity;

    state.debug_counters.drops = (tonumber(state.debug_counters.drops) or 0) + 1;
    state.data_dirty = true;

    dbg(('Drop recorded: %s x%d from %s [%s]'):fmt(
        tostring(drop.name or ('Item ' .. tostring(item_id))),
        quantity,
        tostring(rec.name or 'Unknown'),
        tostring(source or 'unknown')
    ));

    return true;
end

-- Pool slot signature: item id plus the slot's drop time when Ashita exposes
-- it. Lets a new drop of the SAME item into a reused slot be detected (with
-- only the item id, a second Honey replacing a Honey was invisible).
local function treasure_signature(item, item_id)
    local drop_time = 0;
    pcall(function() drop_time = tonumber(item.DropTime) or 0; end);
    return ('%d:%d'):fmt(tonumber(item_id) or 0, drop_time);
end

-- Credits an item to a kill from one source ('chat', 'pool' or 'inv').
-- Each source keeps its own count per kill; only the amount above what has
-- already been recorded is added, so the same drop seen by the chat line,
-- the treasure pool and the inventory is counted once.
local function credit_item(dead, item_id, quantity, kind, label)
    if dead == nil then return false; end
    item_id = tonumber(item_id) or 0;
    quantity = math.max(1, tonumber(quantity) or 1);
    if item_id <= 0 or item_id == 65535 then return false; end
    if dead.src_counts == nil then dead.src_counts = T{}; end
    if dead.recorded_counts == nil then dead.recorded_counts = T{}; end
    local ik = tostring(item_id);
    local sc = dead.src_counts[kind];
    if sc == nil then sc = T{}; dead.src_counts[kind] = sc; end
    sc[ik] = (tonumber(sc[ik]) or 0) + quantity;
    local excess = sc[ik] - (tonumber(dead.recorded_counts[ik]) or 0);
    if excess <= 0 then return false; end
    dead.recorded_counts[ik] = sc[ik];
    return record_drop_for_dead(dead, item_id, excess, label);
end

-- ----------------------------------------------------------------------------
-- "You find <item> on the <mob>." chat line: the most reliable drop signal.
-- Shown after the drop happens (allowed on HorizonXI). The item text is the
-- log name ("pot of honey"), matched to an item id through the treasure pool
-- first and a one-time item-name index as fallback.
-- ----------------------------------------------------------------------------
local item_text_cache = T{};          -- [lowercase log/display name] = item id
local item_index_built = false;

local function item_names_lower(item)
    local names = {};
    local function add(arr)
        if arr == nil then return; end
        local v = nil;
        pcall(function() v = arr[1] or arr[0]; end);
        if v ~= nil and tostring(v) ~= '' then names[#names + 1] = tostring(v):lower(); end
    end
    pcall(function() add(item.LogNameSingular); end);
    pcall(function() add(item.LogNamePlural); end);
    pcall(function() add(item.Name); end);
    return names;
end

local function index_item(item_id, item)
    for _, n in ipairs(item_names_lower(item)) do
        if item_text_cache[n] == nil then item_text_cache[n] = item_id; end
    end
end

local function resolve_item_from_text(text)
    text = tostring(text or ''):lower();
    if text == '' then return nil; end
    if item_text_cache[text] ~= nil then return item_text_cache[text]; end

    local rm = AshitaCore:GetResourceManager();
    local mm = AshitaCore:GetMemoryManager();
    if rm == nil then return nil; end

    -- 1) Items currently in the treasure pool.
    local inv = mm and mm:GetInventory() or nil;
    if inv ~= nil then
        for slot = 0, 9 do
            local ok, pool = pcall(function() return inv:GetTreasurePoolItem(slot); end);
            local id = ok and pool ~= nil and tonumber(pool.ItemId) or 0;
            if id ~= nil and id > 0 and id ~= 65535 then
                local ok2, item = pcall(function() return rm:GetItemById(id); end);
                if ok2 and item ~= nil then index_item(id, item); end
            end
        end
        if item_text_cache[text] ~= nil then return item_text_cache[text]; end
    end

    -- 2) One-time full index (a short pause the first time only).
    if not item_index_built then
        item_index_built = true;
        for id = 1, 32000 do
            local ok, item = pcall(function() return rm:GetItemById(id); end);
            if ok and item ~= nil then index_item(id, item); end
        end
    end
    return item_text_cache[text];
end

local function strip_chat_codes(text)
    text = tostring(text or '');
    text = text:gsub('[\30\31].', ''):gsub('\127.', ''):gsub('[\r\n]', '');
    return text;
end

local function find_recent_dead_by_name(mob_name)
    local now = os.clock();
    local best, best_time = nil, -1;
    local wanted = tostring(mob_name or ''):lower();
    for _, dead in pairs(state.recent_dead) do
        if dead ~= nil and dead.info ~= nil then
            local t = tonumber(dead.time) or 0;
            if (now - t) <= 30.0 and t > best_time and tostring(dead.info.name or ''):lower() == wanted then
                best = dead;
                best_time = t;
            end
        end
    end
    return best;
end

local function handle_find_message(message)
    if message == nil or not message:find('find', 1, true) then return; end
    local text = strip_chat_codes(message);
    local item_text, mob_text = text:match('^You find (.-) on the (.-)%.%s*$');
    if item_text == nil then
        item_text, mob_text = text:match('^You find (.-) on (.-)%.%s*$');
    end
    if item_text == nil then return; end

    local quantity = 1;
    local count, rest = item_text:match('^(%d+)%s+(.+)$');
    if count ~= nil then
        quantity = tonumber(count) or 1;
        item_text = rest;
    else
        item_text = item_text:gsub('^an? ', ''):gsub('^the ', '');
    end

    local dead = find_recent_dead_by_name(mob_text);
    if dead == nil then
        dbg(('Find line ignored (not one of your recent kills): %s on %s'):fmt(item_text, tostring(mob_text)));
        return;
    end

    -- Plural log names ("3 pots of honey") resolve through LogNamePlural.
    local item_id = resolve_item_from_text(item_text);
    if item_id == nil then
        dbg(('Find line: could not match item "%s"'):fmt(item_text));
        return;
    end

    dead.treasure_seen = true;
    if credit_item(dead, item_id, quantity, 'chat', 'chat find line') then
        state.debug_counters.chat_drops = (tonumber(state.debug_counters.chat_drops) or 0) + 1;
    end
end

local function initialize_treasure_cache()
    if state.treasure_cache_ready then return; end

    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return; end

    local inventory = mm:GetInventory();
    if inventory == nil then return; end

    -- Baseline the currently-visible pool. This prevents MobHunt from attributing
    -- treasure that was already in the pool when the addon was loaded/reloaded.
    for slot = 0, 9 do
        local ok, item = pcall(function() return inventory:GetTreasurePoolItem(slot); end);
        if ok and item ~= nil and item.ItemId ~= nil then
            local item_id = tonumber(item.ItemId) or 0;
            if item_id > 0 and item_id ~= 65535 then
                state.treasure_slots[slot] = treasure_signature(item, item_id);
            else
                state.treasure_slots[slot] = nil;
            end
        else
            state.treasure_slots[slot] = nil;
        end
    end

    state.treasure_cache_ready = true;
    dbg('Treasure-pool memory baseline initialized.');
end

local function scan_treasure_pool_memory()
    initialize_treasure_cache();
    if not state.treasure_cache_ready then return; end

    local now = os.clock();
    if (now - (tonumber(state.treasure_last_scan) or 0)) < 0.10 then return; end
    state.treasure_last_scan = now;

    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return; end

    local inventory = mm:GetInventory();
    if inventory == nil then return; end

    state.debug_counters.treasure_memory_scans =
        (tonumber(state.debug_counters.treasure_memory_scans) or 0) + 1;

    for slot = 0, 9 do
        local item_id = 0;
        local sig = nil;
        local ok, item = pcall(function() return inventory:GetTreasurePoolItem(slot); end);

        if ok and item ~= nil and item.ItemId ~= nil then
            item_id = tonumber(item.ItemId) or 0;
        end

        if item_id == 65535 then
            -- Gil is intentionally excluded from the item drop table.
            item_id = 0;
        end
        if item_id > 0 then sig = treasure_signature(item, item_id); end

        local previous = state.treasure_slots[slot];

        -- A slot went from empty -> item, changed to a new item, or got a new
        -- drop of the same item (different drop time).
        if item_id > 0 and sig ~= previous then
            local dead = most_recent_kill_source(12.0);
            local party_kill = latest_party_kill_time();
            if dead ~= nil and party_kill ~= nil and party_kill > (tonumber(dead.time) or 0) then
                -- A party member killed a different mob after your kill; this
                -- pool item most likely came from that mob.
                dbg(('Treasure-pool item not credited: slot=%d item=%d (%s); a party kill is more recent than yours.'):fmt(
                    slot, item_id, item_name(item_id)));
                state.debug_counters.ignored_drops = (tonumber(state.debug_counters.ignored_drops) or 0) + 1;
                dead = nil;
                party_kill = -1;
            end
            if party_kill == -1 then
                -- already reported above
            elseif dead ~= nil then
                if credit_item(dead, item_id, 1, 'pool', ('treasure-memory slot %d'):fmt(slot)) then
                    dead.treasure_seen = true;
                    state.debug_counters.treasure_memory_drops =
                        (tonumber(state.debug_counters.treasure_memory_drops) or 0) + 1;
                end
            else
                dbg(('New treasure-pool item ignored: slot=%d item=%d (%s); no recent MobHunt kill.'):fmt(
                    slot, item_id, item_name(item_id)));
            end
        end

        if item_id > 0 then
            state.treasure_slots[slot] = sig;
        else
            state.treasure_slots[slot] = nil;
        end
    end
end

local function record_direct_inventory_drop(item_id, quantity, source_packet)
    item_id = tonumber(item_id) or 0;
    quantity = tonumber(quantity) or 0;
    if item_id <= 0 or quantity <= 0 then return false; end

    local dead = most_recent_direct_drop_source();
    if dead == nil then
        dbg(('Direct inventory candidate ignored: item=%d (%s) qty=%d source=%s; no recent unpooled kill.'):fmt(
            item_id, item_name(item_id), quantity, tostring(source_packet)));
        return false;
    end

    if credit_item(dead, item_id, quantity, 'inv', source_packet) then
        state.debug_counters.direct_drops = (tonumber(state.debug_counters.direct_drops) or 0) + 1;
        return true;
    end

    return false;
end

local function parse_inventory_assign_packet(e)
    if e == nil or e.data_modified == nil then return nil; end
    local ok, p = pcall(function()
        return T{
            count = struct.unpack('I', e.data_modified, 0x04 + 1),
            item = struct.unpack('H', e.data_modified, 0x08 + 1),
            bag = struct.unpack('B', e.data_modified, 0x0A + 1),
            index = struct.unpack('B', e.data_modified, 0x0B + 1),
        };
    end);
    if not ok then return nil; end
    return p;
end

local function parse_inventory_modify_packet(e)
    if e == nil or e.data_modified == nil then return nil; end
    local ok, p = pcall(function()
        return T{
            count = struct.unpack('I', e.data_modified, 0x04 + 1),
            bag = struct.unpack('B', e.data_modified, 0x08 + 1),
            index = struct.unpack('B', e.data_modified, 0x09 + 1),
        };
    end);
    if not ok then return nil; end
    return p;
end

local function parse_action_packet(e)
    if e == nil or e.data_raw == nil then return nil; end

    local ok, result = pcall(function()
        local bit_offset = 40;
        local function read_bits(count)
            local value = ashita.bits.unpack_be(e.data_raw, bit_offset, count);
            bit_offset = bit_offset + count;
            return tonumber(value) or 0;
        end

        local act = T{
            actor_id = read_bits(32),
            target_count = read_bits(6),
            _res = read_bits(4),
            category = read_bits(4),
            param = read_bits(32),
            info = read_bits(32),
            targets = T{},
        };

        for _ = 1, act.target_count do
            local target = T{
                id = read_bits(32),
                action_count = read_bits(4),
                first_value = nil,
                first_message = nil,
            };
            act.targets:append(target);

            for _ = 1, target.action_count do
                read_bits(3);   -- miss
                read_bits(2);   -- kind
                read_bits(12);  -- sub-kind
                read_bits(5);   -- info
                read_bits(5);   -- scale
                local value = read_bits(17);  -- value
                local message = read_bits(10);  -- message
                read_bits(31);  -- bit
                if target.first_value == nil then
                    target.first_value = value;
                    target.first_message = message;
                end

                local has_proc = read_bits(1);
                if has_proc ~= 0 then
                    read_bits(6);
                    read_bits(4);
                    read_bits(17);
                    read_bits(10);
                end

                local has_react = read_bits(1);
                if has_react ~= 0 then
                    read_bits(6);
                    read_bits(4);
                    read_bits(14);
                    read_bits(10);
                end
            end
        end

        return act;
    end);

    if not ok then
        dbg(('Action parse failed: %s'):fmt(tostring(result)));
        return nil;
    end

    return result;
end

local function parse_action_message(e)
    if e == nil or e.data_modified == nil then return nil; end

    local ok, p = pcall(function()
        return T{
            actor = struct.unpack('I', e.data_modified, 0x04 + 1),
            target = struct.unpack('I', e.data_modified, 0x08 + 1),
            param1 = struct.unpack('I', e.data_modified, 0x0C + 1),
            param2 = struct.unpack('I', e.data_modified, 0x10 + 1),
            actor_index = struct.unpack('H', e.data_modified, 0x14 + 1),
            target_index = struct.unpack('H', e.data_modified, 0x16 + 1),
            message = struct.unpack('H', e.data_modified, 0x18 + 1),
        };
    end);

    if not ok then return nil; end
    return p;
end

local function parse_kill_packet(e)
    if e == nil or e.data_modified == nil then return nil; end

    local ok, p = pcall(function()
        return T{
            player = struct.unpack('I', e.data_modified, 0x04 + 1),
            target = struct.unpack('I', e.data_modified, 0x08 + 1),
            player_index = struct.unpack('H', e.data_modified, 0x0C + 1),
            target_index = struct.unpack('H', e.data_modified, 0x0E + 1),
            amount = struct.unpack('I', e.data_modified, 0x10 + 1),
            chain = struct.unpack('I', e.data_modified, 0x14 + 1),
            message = struct.unpack('H', e.data_modified, 0x18 + 1),
        };
    end);

    if not ok then return nil; end
    return p;
end

local function parse_drop_packet(e)
    if e == nil or e.data_modified == nil then return nil; end

    local ok, p = pcall(function()
        return T{
            dropper = struct.unpack('I', e.data_modified, 0x04 + 1),
            count = struct.unpack('I', e.data_modified, 0x08 + 1),
            item = struct.unpack('H', e.data_modified, 0x0C + 1),
            dropper_index = struct.unpack('H', e.data_modified, 0x0E + 1),
            pool_index = struct.unpack('B', e.data_modified, 0x10 + 1),
        };
    end);

    if not ok then return nil; end
    return p;
end

local function get_player_hp()
    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return nil; end

    local party = mm:GetParty();
    if party == nil then return nil; end

    local ok, hp = pcall(function() return party:GetMemberHP(0); end);
    if not ok then return nil; end

    hp = tonumber(hp);
    if hp == nil then return nil; end
    return hp;
end

local function get_single_active_encounter()
    local found = nil;
    for _, enc in pairs(state.encounters) do
        if enc ~= nil then
            if found ~= nil then return nil; end
            found = enc;
        end
    end
    return found;
end

local function monitor_player_death()
    local hp = get_player_hp();
    if hp == nil then return; end

    if state.last_player_hp == nil then
        state.last_player_hp = hp;
        state.player_dead = hp <= 0;
        return;
    end

    if state.last_player_hp > 0 and hp <= 0 then
        state.player_dead = true;

        local source = nil;
        if state.last_hostile ~= nil
            and (os.clock() - (tonumber(state.last_hostile.time) or 0)) <= 10.0
            and state.encounters[tonumber(state.last_hostile.id) or 0] ~= nil then
            source = state.last_hostile;
        else
            local enc = get_single_active_encounter();
            if enc ~= nil then
                source = T{ id = enc.id, index = enc.index, time = os.clock() };
            end
        end

        if source ~= nil then
            count_death(source.id, source.index, 'hp_zero');
        else
            dbg('HP reached 0, but no single safe MobHunt killer could be identified.');
        end
    elseif state.last_player_hp <= 0 and hp > 0 then
        state.player_dead = false;
        dbg('Player revived; new encounters may begin.');
    else
        state.player_dead = hp <= 0;
    end

    state.last_player_hp = hp;
end

local function cleanup_runtime()
    local now = os.clock();
    local timeout = math.max(15, tonumber(state.encounter_timeout[1]) or 120);

    for id, enc in pairs(state.encounters) do
        if enc == nil then
            state.encounters[id] = nil;
        elseif (now - (tonumber(enc.last_activity) or now)) > timeout then
            -- A mob you are not hitting right now (slept, bound, waiting while
            -- you kill another) stays open while it is alive and claimed by
            -- you or your party. Expiring it here made the later kill count
            -- as a brand-new fight and left the first one unfinished.
            if mob_alive_and_party_claimed(id, enc.index) then
                touch_encounter(id);
            else
                state.encounters[id] = nil;
                clear_persisted_encounter(id);
                state.data_dirty = true;
            end
        end
    end

    -- Also remove stale markers that survived a previous unload but were never
    -- restored into runtime state.
    if config.active_encounters ~= nil then
        local wall_now = os.time();
        local current_zone = get_zone_id();
        for marker_id, marker in pairs(config.active_encounters) do
            local last_wall = marker and
                (tonumber(marker.last_activity_wall) or tonumber(marker.started_wall)) or 0;
            local marker_zone = marker and tonumber(marker.zone_id) or -1;

            if last_wall <= 0
                or (wall_now - last_wall) > timeout
                or (current_zone ~= 0 and marker_zone ~= current_zone) then
                config.active_encounters[marker_id] = nil;
                state.data_dirty = true;
            end
        end
    end

    for id, dead in pairs(state.recent_dead) do
        if dead == nil or (now - (tonumber(dead.time) or now)) > 35 then
            state.recent_dead[id] = nil;
        end
    end

    for id, ts in pairs(state.recent_kills) do
        if (now - (tonumber(ts) or now)) > 10 then
            state.recent_kills[id] = nil;
        end
    end

    for id, ts in pairs(state.recent_deaths) do
        if (now - (tonumber(ts) or now)) > 10 then
            state.recent_deaths[id] = nil;
        end
    end

    -- Pending engages expire after 60s, or as soon as someone outside your
    -- party holds the claim (they tagged it first).
    for id, pending in pairs(state.pending_engage) do
        local drop = pending == nil or (now - (tonumber(pending.time) or now)) > 60;
        if not drop and pending.info ~= nil then
            local idx = tonumber(pending.info.index) or 0;
            local ok, claim = pcall(function()
                local em = AshitaCore:GetMemoryManager():GetEntity();
                if tonumber(em:GetServerId(idx)) ~= tonumber(id) then return -1; end
                return tonumber(em:GetClaimStatus(idx)) or 0;
            end);
            if ok and claim ~= nil then
                if claim == -1 then
                    drop = true;
                elseif bit.band(claim, 0xFFFF) ~= 0 and not claimed_by_party(claim) then
                    drop = true;
                end
            end
        end
        if drop then state.pending_engage[id] = nil; end
    end

    for id, ts in pairs(state.recent_party_kills) do
        if (now - (tonumber(ts) or now)) > 35 then
            state.recent_party_kills[id] = nil;
        end
    end

    if state.last_hostile ~= nil
        and (now - (tonumber(state.last_hostile.time) or now)) > 15 then
        state.last_hostile = nil;
    end
end

local function save_all()
    ensure_config_tables();

    config.visible = state.visible[1];
    config.history_visible = state.history_visible[1];
    config.config_visible = state.config_visible[1];
    config.timers_visible = state.timers_visible[1];
    if config.timers_window == nil then config.timers_window = T{}; end
    config.timers_window.x = state.timers_geom[1];
    config.timers_window.y = state.timers_geom[2];
    config.font_scale = state.font_scale[1];

    local colors = {
        background = state.background,
        accent = state.accent,
        success = state.success,
        danger = state.danger,
        muted = state.muted,
    };
    for name, values in pairs(colors) do
        for i = 1, 4 do config.appearance[name][i] = values[i]; end
    end

    config.appearance.border = state.border[1];
    config.appearance.title_bar = state.title_bar[1];
    config.appearance.theme = state.theme;

    config.behavior.target_only = state.target_only[1];
    config.behavior.mini_mode = state.mini_mode[1];
    config.behavior.history_current_zone = state.history_current_zone[1];
    config.behavior.show_session = state.show_session[1];
    config.behavior.show_drops = state.show_drops[1];
    config.behavior.show_kills_per_hour = state.show_kills_per_hour[1];
    config.behavior.show_by_job = state.show_by_job[1];
    config.behavior.debug = state.debug[1];
    config.behavior.encounter_timeout = math.floor(math.max(15, tonumber(state.encounter_timeout[1]) or 120));
    config.behavior.credit_party_kills = state.credit_party_kills[1] == true;

    config.locks.target = state.lock_target[1];
    config.locks.history = state.lock_history[1];
    config.locks.config = state.lock_config[1];

    local function write_geom(dst, src)
        dst.x = src[1]; dst.y = src[2]; dst.width = src[3]; dst.height = src[4];
    end

    write_geom(config.window, state.target_geom);
    write_geom(config.mini_window, state.mini_geom);
    write_geom(config.history_window, state.history_geom);
    write_geom(config.config_window, state.config_geom);

    settings.save();
end

-- Position-only capture for the auto-sized target / mini window. Writing the
-- auto-sized width back into geom fed it into the next frame's content width
-- and made the window widen forever.
local function capture_position(geom)
    local x, y = imgui.GetWindowPos();
    x = tonumber(x); y = tonumber(y);
    if x == nil or y == nil then return; end

    if math.abs(x - geom[1]) >= 1 or math.abs(y - geom[2]) >= 1 then
        geom[1] = x; geom[2] = y;
        state.geometry_dirty = true;
    end
end

local function capture_geometry(geom)
    local x, y = imgui.GetWindowPos();
    local w, h = imgui.GetWindowSize();

    x = tonumber(x); y = tonumber(y); w = tonumber(w); h = tonumber(h);
    if x == nil or y == nil or w == nil or h == nil then return; end

    if math.abs(x - geom[1]) >= 1 or math.abs(y - geom[2]) >= 1
        or math.abs(w - geom[3]) >= 1 or math.abs(h - geom[4]) >= 1 then
        geom[1] = x; geom[2] = y; geom[3] = w; geom[4] = h;
        state.geometry_dirty = true;
    end
end

-- MobHunt theme: the suite theme, then MobHunt's compact StatusTimers-style
-- spacing and the border toggle on top.
-- 1.7.0: each window's own look: size (scale) and opacity (nil = the
-- shared background opacity).
function win_look(name)
    local w = config.appearance and config.appearance.win and config.appearance.win[name];
    return w or { scale = 1.0, own_alpha = false, alpha = 0.45 };
end
function win_scale(name)
    return math.max(0.5, math.min(3.0, tonumber(win_look(name).scale) or 1.0));
end
function win_alpha(name)
    local w = win_look(name);
    if w.own_alpha ~= true then return nil; end
    return math.max(0, math.min(1, tonumber(w.alpha) or 0.45));
end

local function push_mh_theme(alpha, scale)
    local bg = state.background;
    -- 1.7.0: "Use the theme's background" (Look > Theme & colors).
    if config.appearance.use_theme_bg == true then
        local tb = UI_THEMES[normalize_theme_key(state.theme)].bg or { 9, 9, 10 };
        bg = { tb[1] / 255, tb[2] / 255, tb[3] / 255, bg[4] };
    end
    if alpha ~= nil then bg = { bg[1], bg[2], bg[3], alpha }; end
    scale = tonumber(scale) or 1.0;
    push_theme(bg, state.theme);
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 7.0);
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 4.0 * scale, 3.0 * scale });
    -- 1.7.0: TAB never jumps into MobHunt's text fields (search boxes):
    -- every item in MobHunt windows is left out of ImGui's tab order.
    -- Pushed before Begin so the window and its popups inherit it.
    local how = nil;
    if imgui.PushItemFlag ~= nil and ImGuiItemFlags_NoTabStop ~= nil then
        if pcall(imgui.PushItemFlag, ImGuiItemFlags_NoTabStop, true) then how = 'flag'; end
    end
    if how == nil and imgui.PushTabStop ~= nil then
        if pcall(imgui.PushTabStop, false) then how = 'tabstop'; end
    end
    if how == nil and imgui.PushAllowKeyboardFocus ~= nil then
        if pcall(imgui.PushAllowKeyboardFocus, false) then how = 'focus'; end
    end
    MH_TABSTOP_STACK = MH_TABSTOP_STACK or {};
    MH_TABSTOP_STACK[#MH_TABSTOP_STACK + 1] = how or false;
end

-- 1.6.0: History / Mob detail opacity (nil = same as the other windows).
-- 1.7.0: the History window's own opacity setting.
function history_alpha()
    return win_alpha('history');
end

local function pop_mh_theme()
    local how = MH_TABSTOP_STACK and table.remove(MH_TABSTOP_STACK) or false;
    if how == 'flag' then pcall(imgui.PopItemFlag);
    elseif how == 'tabstop' then pcall(imgui.PopTabStop);
    elseif how == 'focus' then pcall(imgui.PopAllowKeyboardFocus); end
    imgui.PopStyleVar(3);
    pop_theme();
end

local function window_flags(locked, auto_resize)
    local flags = ImGuiWindowFlags_NoNav;

    if auto_resize then
        flags = bit.bor(flags, ImGuiWindowFlags_AlwaysAutoResize);
    elseif locked then
        flags = bit.bor(flags, ImGuiWindowFlags_NoResize);
    end

    if locked then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove);
    end

    if not state.title_bar[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar);
    end

    return flags;
end

local function custom_close(id, open_ref)
    if state.title_bar[1] then return; end

    local window_w = select(1, imgui.GetWindowSize());
    window_w = tonumber(window_w) or 300;
    local sx, sy = imgui.GetCursorPos();

    -- Keep the button inside the 12px content padding: placing it past the
    -- content edge made auto-sized windows (Timers) widen every frame.
    imgui.SetCursorPos({ math.max(8, window_w - 34), 6 });
    if imgui.Button('X##' .. id, { 22, 20 }) then
        open_ref[1] = false;
        state.settings_dirty = true;
    end

    imgui.SetCursorPos({ sx, sy });
end

-- "45s", "12m 04s", "2h 05m".
local function format_span(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0));
    if seconds < 60 then return ('%ds'):fmt(seconds); end
    if seconds < 3600 then return ('%dm %02ds'):fmt(math.floor(seconds / 60), seconds % 60); end
    return ('%dh %02dm'):fmt(math.floor(seconds / 3600), math.floor((seconds % 3600) / 60));
end

local function format_age(timestamp)
    timestamp = tonumber(timestamp) or 0;
    if timestamp <= 0 then return nil; end
    return format_span(os.time() - timestamp) .. ' ago';
end

local function pct(part, total)
    part = tonumber(part) or 0;
    total = tonumber(total) or 0;
    if total <= 0 then return 0.0; end
    return (part / total) * 100.0;
end

local function fmt_time(ts)
    ts = tonumber(ts) or 0;
    if ts <= 0 then return '--'; end
    return os.date('%Y-%m-%d %I:%M:%S %p', ts);
end

local function session_kph(s)
    if s == nil or (tonumber(s.first_fight) or 0) <= 0 then return 0.0; end
    local elapsed = math.max(1, os.time() - tonumber(s.first_fight));
    return ((tonumber(s.kills) or 0) * 3600.0) / elapsed;
end

local function sorted_drops(rec)
    local rows = {};
    if rec == nil or rec.drops == nil then return rows; end

    for _, drop in pairs(rec.drops) do
        if drop ~= nil then table.insert(rows, drop); end
    end

    table.sort(rows, function(a, b)
        local ao = tonumber(a.occurrences) or 0;
        local bo = tonumber(b.occurrences) or 0;
        if ao == bo then
            return tostring(a.name or ''):lower() < tostring(b.name or ''):lower();
        end
        return ao > bo;
    end);

    return rows;
end

local function draw_drop_table(rec, key, compact)
    local drops = sorted_drops(rec);
    if #drops == 0 then
        imgui.TextColored(state.muted, 'No recorded drops.');
        return;
    end

    local table_flags = 0;
    if ImGuiTableFlags_RowBg ~= nil then table_flags = bit.bor(table_flags, ImGuiTableFlags_RowBg); end
    if ImGuiTableFlags_BordersInnerH ~= nil then table_flags = bit.bor(table_flags, ImGuiTableFlags_BordersInnerH); end

    if imgui.BeginTable ~= nil and imgui.BeginTable('##mobhunt_drops_' .. tostring(key), compact and 3 or 5, table_flags) then
        if compact then
            imgui.TableSetupColumn('Item', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);
            imgui.TableSetupColumn('Drops', ImGuiTableColumnFlags_WidthFixed or 0, 72.0);
            imgui.TableSetupColumn('Rate', ImGuiTableColumnFlags_WidthFixed or 0, 78.0);
        else
            imgui.TableSetupColumn('Item', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);
            imgui.TableSetupColumn('Drops', ImGuiTableColumnFlags_WidthFixed or 0, 72.0);
            imgui.TableSetupColumn('Rate', ImGuiTableColumnFlags_WidthFixed or 0, 78.0);
            imgui.TableSetupColumn('Qty', ImGuiTableColumnFlags_WidthFixed or 0, 58.0);
            imgui.TableSetupColumn('Session', ImGuiTableColumnFlags_WidthFixed or 0, 88.0);
        end
        imgui.TableHeadersRow();

        local s = state.session[key];

        for _, drop in ipairs(drops) do
            imgui.TableNextRow();
            imgui.TableNextColumn(); imgui.Text(tostring(drop.name or ('Item ' .. tostring(drop.item_id or '?'))));
            imgui.TableNextColumn(); imgui.Text(tostring(tonumber(drop.occurrences) or 0));
            imgui.TableNextColumn(); imgui.Text(('%.1f%%'):fmt(pct(drop.occurrences, rec.kills)));

            if not compact then
                imgui.TableNextColumn(); imgui.Text(tostring(tonumber(drop.quantity) or 0));
                imgui.TableNextColumn();
                local sdrop = s and s.drops and s.drops[tostring(drop.item_id)] or nil;
                if sdrop then
                    imgui.Text(('%d / %d'):fmt(tonumber(sdrop.occurrences) or 0, tonumber(sdrop.quantity) or 0));
                else
                    imgui.TextColored(state.muted, '--');
                end
            end
        end
        imgui.EndTable();
    else
        for _, drop in ipairs(drops) do
            imgui.Text(('%s  %d  %.1f%%'):fmt(
                tostring(drop.name or ('Item ' .. tostring(drop.item_id or '?'))),
                tonumber(drop.occurrences) or 0,
                pct(drop.occurrences, rec.kills)
            ));
        end
    end
end

local function draw_three_stats(id, fights, kills, deaths)
    local flags = 0;
    if imgui.BeginTable ~= nil and imgui.BeginTable('##mobhunt_stats_' .. tostring(id), 3, flags) then
        imgui.TableSetupColumn('##fights', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);
        imgui.TableSetupColumn('##kills', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);
        imgui.TableSetupColumn('##deaths', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);

        imgui.TableNextRow();
        imgui.TableNextColumn(); imgui.Text(('Fights: %d'):fmt(tonumber(fights) or 0));
        imgui.TableNextColumn(); imgui.TextColored(state.success, ('Kills: %d'):fmt(tonumber(kills) or 0));
        imgui.TableNextColumn(); imgui.TextColored(state.danger, ('Deaths: %d'):fmt(tonumber(deaths) or 0));

        imgui.EndTable();
    else
        imgui.Text(('Fights: %d'):fmt(tonumber(fights) or 0));
        imgui.SameLine(0, 26); imgui.TextColored(state.success, ('Kills: %d'):fmt(tonumber(kills) or 0));
        imgui.SameLine(0, 26); imgui.TextColored(state.danger, ('Deaths: %d'):fmt(tonumber(deaths) or 0));
    end
end

local function job_line(job, j)
    local fights = tonumber(j.fights) or 0;
    local kills = tonumber(j.kills) or 0;
    local deaths = tonumber(j.deaths) or 0;
    local exp_kills = tonumber(j.exp_kills) or 0;
    local timed = tonumber(j.timed_kills) or 0;
    local exp_text = (exp_kills > 0) and ('%d'):fmt(math.floor(((tonumber(j.exp_total) or 0) / exp_kills) + 0.5)) or '--';
    local time_text = (timed > 0) and format_span((tonumber(j.fight_seconds) or 0) / timed) or '--';
    return fights, kills, deaths, exp_text, time_text;
end

local function sorted_jobs(rec)
    local list = {};
    if rec.by_job == nil then return list; end
    for job, j in pairs(rec.by_job) do
        if j ~= nil and (tonumber(j.fights) or 0) + (tonumber(j.kills) or 0) + (tonumber(j.deaths) or 0) > 0 then
            list[#list + 1] = { job = job, stats = j };
        end
    end
    table.sort(list, function(a, b)
        return (tonumber(a.stats.fights) or 0) > (tonumber(b.stats.fights) or 0);
    end);
    return list;
end

-- Full per-job table (History detail) or just your current job (target window,
-- only once the mob has been fought on two or more jobs).
local function draw_job_stats(rec, full)
    if not state.show_by_job[1] then return; end
    local jobs = sorted_jobs(rec);
    if #jobs == 0 then return; end

    if not full then
        if #jobs < 2 then return; end
        local job = current_job_name();
        local j = job and rec.by_job[job] or nil;
        if j == nil then return; end
        local f, k, d, exp_text, time_text = job_line(job, j);
        imgui.TextColored(UI_ACCENT_TEXT, ('As %s'):fmt(job));
        imgui.SameLine(0, 8);
        imgui.Text(('F %d  K %d  D %d  Win %.0f%%'):fmt(f, k, d, pct(k, f)));
        imgui.TextColored(state.muted, ('EXP %s  Fight %s'):fmt(exp_text, time_text));
        return;
    end

    imgui.Separator();
    imgui.TextColored(UI_ACCENT_TEXT, 'By Job');

    local function tw(text)
        local w = imgui.CalcTextSize(tostring(text));
        return tonumber(w) or 0;
    end
    local headers = { 'Job', 'Fights', 'Kills', 'Deaths', 'Win %', 'Avg EXP', 'Avg Fight' };
    local samples = { 'WAR', '00000', '00000', '00000', '100.0%', '00000', '00m 00s' };
    local xs = {};
    local x = imgui.GetCursorPosX();
    for i, h in ipairs(headers) do
        xs[i] = x;
        x = x + math.max(tw(h), tw(samples[i])) + 16;
    end

    for i, h in ipairs(headers) do
        if i > 1 then imgui.SameLine(); imgui.SetCursorPosX(xs[i]); end
        imgui.TextColored(state.muted, h);
    end

    local current = current_job_name();
    for _, entry in ipairs(jobs) do
        local f, k, d, exp_text, time_text = job_line(entry.job, entry.stats);
        local cells = { entry.job, tostring(f), tostring(k), tostring(d), ('%.1f%%'):fmt(pct(k, f)), exp_text, time_text };
        for i, c in ipairs(cells) do
            if i > 1 then imgui.SameLine(); imgui.SetCursorPosX(xs[i]); end
            if i == 1 and entry.job == current then
                imgui.TextColored(UI_ACCENT_TEXT, c);
            elseif i == 3 then
                imgui.TextColored(state.success, c);
            elseif i == 4 and d > 0 then
                imgui.TextColored(state.danger, c);
            else
                imgui.Text(c);
            end
        end
    end
end

-- ============================================================================
-- Target window body (1.6.1 restyle): stat tiles, a details line, abilities
-- one per row with a bar, session, drops with rate bars.
-- ============================================================================

local function tw_text(text) return tonumber((imgui.CalcTextSize(tostring(text or '')))) or 0; end

-- Small section title: accent text with a thin line to the right.
local function mini_section(title)
    imgui.Spacing();
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    x, y = tonumber(x) or 0, tonumber(y) or 0;
    local avail = tonumber((imgui.GetContentRegionAvail())) or 300;
    local lh = imgui.GetTextLineHeight();
    imgui.TextColored(UI_ACCENT_TEXT, title);
    local tx = x + tw_text(title) + 8;
    dl:AddLine({ tx, y + lh * 0.55 }, { x + avail, y + lh * 0.55 }, imgui.GetColorU32(ui_accent(0.30)), 1.0);
end

-- Tiles that share the full width: { label, value, color }.
local function wide_tiles(items)
    local dl = imgui.GetWindowDrawList();
    local avail = tonumber((imgui.GetContentRegionAvail())) or 300;
    local gap = 6;
    local n = #items;
    local w = (avail - gap * (n - 1)) / n;
    local lh = imgui.GetTextLineHeight();
    local big = imgui.GetFontSize() * 1.30;
    local h = lh + big + 12;
    local x0, y0 = imgui.GetCursorScreenPos();
    x0, y0 = tonumber(x0) or 0, tonumber(y0) or 0;
    for i, it in ipairs(items) do
        local x = x0 + (i - 1) * (w + gap);
        local col = it[3] or UI_TEXT;
        dl:AddRectFilled({ x, y0 }, { x + w, y0 + h }, imgui.GetColorU32({ UI_CONTROL[1], UI_CONTROL[2], UI_CONTROL[3], 0.80 }), 5.0);
        dl:AddRectFilled({ x, y0 + h - 2 }, { x + w, y0 + h }, imgui.GetColorU32({ col[1], col[2], col[3], 0.85 }), 2.0);
        dl:AddText({ x + 8, y0 + 4 }, imgui.GetColorU32(state.muted), it[1]);
        dl:AddText(imgui.GetFont(), big, { x + 8, y0 + 4 + lh }, imgui.GetColorU32(col), tostring(it[2]));
    end
    imgui.Dummy({ avail, h + 2 });
end

-- One row: name on the left, value on the right, a thin bar under it.
local function bar_row(name, right_text, frac, color, sub)
    local dl = imgui.GetWindowDrawList();
    local avail = tonumber((imgui.GetContentRegionAvail())) or 300;
    local x, y = imgui.GetCursorScreenPos();
    x, y = tonumber(x) or 0, tonumber(y) or 0;
    local lh = imgui.GetTextLineHeight();
    dl:AddText({ x, y }, imgui.GetColorU32(UI_TEXT), name);
    if sub ~= nil and sub ~= '' then
        dl:AddText({ x + tw_text(name) + 8, y }, imgui.GetColorU32(state.muted), sub);
    end
    dl:AddText({ x + avail - tw_text(right_text), y }, imgui.GetColorU32(color or UI_ACCENT_TEXT), right_text);
    local by = y + lh + 2;
    dl:AddRectFilled({ x, by }, { x + avail, by + 3 }, imgui.GetColorU32({ 0.20, 0.20, 0.22, 0.90 }), 1.5);
    local f = math.max(0, math.min(1, tonumber(frac) or 0));
    if f > 0 then
        local c = color or UI_ACCENT;
        dl:AddRectFilled({ x, by }, { x + math.max(2, avail * f), by + 3 }, imgui.GetColorU32({ c[1], c[2], c[3], 0.90 }), 1.5);
    end
    imgui.Dummy({ avail, lh + 7 });
end

-- Muted "label value" pairs on one line.
local function pairs_line(items)
    for i, it in ipairs(items) do
        if i > 1 then imgui.SameLine(0, 14); end
        imgui.TextColored(state.muted, it[1]);
        imgui.SameLine(0, 5);
        if it[3] then imgui.TextColored(it[3], it[2]); else imgui.Text(it[2]); end
    end
end

local function draw_record_summary(rec, key, include_header)
    if rec == nil then return; end
    local s = state.session[key];

    if include_header then
        imgui.TextColored(UI_ACCENT_TEXT, tostring(rec.name or 'Unknown'));
        imgui.TextColored(state.muted, tostring(rec.zone_name or safe_zone_name(rec.zone_id)));
        imgui.Separator();
    end

    local fights = tonumber(rec.fights) or 0;
    local kills = tonumber(rec.kills) or 0;
    local deaths = tonumber(rec.deaths) or 0;

    wide_tiles({
        { 'Fights', fights, UI_ACCENT_TEXT },
        { 'Kills', kills, state.success },
        { 'Deaths', deaths, deaths > 0 and state.danger or state.muted },
        { 'Win', ('%.0f%%'):fmt(pct(kills, fights)), UI_TEXT },
    });

    -- Camp comparison: average EXP per kill, average fight length, last kill.
    local exp_kills = tonumber(rec.exp_kills) or 0;
    local timed = tonumber(rec.timed_kills) or 0;
    local exp_text = (exp_kills > 0)
        and ('%d'):fmt(math.floor(((tonumber(rec.exp_total) or 0) / exp_kills) + 0.5)) or '--';
    local time_text = (timed > 0)
        and format_span((tonumber(rec.fight_seconds) or 0) / timed) or '--';
    pairs_line({
        { 'Avg EXP', exp_text },
        { 'Avg fight', time_text },
        { 'Last kill', format_age(rec.last_kill) or 'never' },
    });

    draw_job_stats(rec, include_header == true);

    -- Its most used abilities, one per row (added when a mob of this kind dies).
    if config.behavior.abilities_target ~= false and config.behavior.track_abilities ~= false and rec.abilities ~= nil then
        local list = sorted_abilities(rec);
        if #list > 0 then
            mini_section('Abilities');
            for i = 1, math.min(tonumber(config.behavior.abilities_rows) or 4, #list) do
                local a = list[i];
                -- Interrupted: started but never finished (Stun, Silence,
                -- the mob died first ...), from 1.6.2 data only.
                local intr = (a.s2 > 0) and math.floor(math.max(0, a.s2 - a.f) * 100 / a.s2 + 0.5) or 0;
                bar_row(a.name, ('%.0f%%'):fmt(a.share), a.share / 100, UI_ACCENT,
                    (a.k == 'ma' and 'spell' or 'TP') .. ((intr > 0) and ('  ' .. intr .. '% interrupted') or ''));
            end
        end
    end

    if state.show_session[1] then
        mini_section('This Session');
        local items = {
            { 'Fights', tostring(s and (tonumber(s.fights) or 0) or 0) },
            { 'Kills', tostring(s and (tonumber(s.kills) or 0) or 0), state.success },
            { 'Deaths', tostring(s and (tonumber(s.deaths) or 0) or 0), (s and (tonumber(s.deaths) or 0) or 0) > 0 and state.danger or nil },
        };
        if state.show_kills_per_hour[1] then
            items[#items + 1] = { 'Kills / hr', ('%.1f'):fmt(session_kph(s)) };
        end
        local session_exp = s and (tonumber(s.exp_total) or 0) or 0;
        if session_exp > 0 then items[#items + 1] = { 'EXP', tostring(session_exp) }; end
        pairs_line(items);
    end

    if state.show_drops[1] then
        mini_section('Observed Drops');
        local drops = sorted_drops(rec);
        if #drops == 0 then
            imgui.TextColored(state.muted, 'No recorded drops.');
        else
            for _, drop in ipairs(drops) do
                local rate = pct(drop.occurrences, rec.kills);
                bar_row(tostring(drop.name or ('Item ' .. tostring(drop.item_id or '?'))),
                    ('%.1f%%'):fmt(rate), rate / 100, state.success,
                    ('x%d'):fmt(tonumber(drop.occurrences) or 0));
            end
        end
    end
end

local function draw_target_window()
    if not state.visible[1] then
        state.target_apply_geometry = true;
        state.mini_apply_geometry = true;
        return;
    end

    -- Resolved once per frame in d3d_present.
    local target = state.current_target;

    if state.target_only[1] and target == nil then
        state.target_apply_geometry = true;
        state.mini_apply_geometry = true;
        return;
    end

    local geom = state.mini_mode[1] and state.mini_geom or state.target_geom;
    local apply_key = state.mini_mode[1] and 'mini_apply_geometry' or 'target_apply_geometry';

    if state[apply_key] then
        imgui.SetNextWindowPos({ geom[1], geom[2] }, { 0, 0 });
        state[apply_key] = false;
    end

    -- StatusTimers-style content-driven sizing. Preserve the selected width,
    -- but never preserve a stale height; new drop rows grow the window and
    -- shorter lists shrink it automatically.
    local min_w = state.mini_mode[1] and 260 or 410;
    local max_w = state.mini_mode[1] and 600 or 700;
    local stored_w = tonumber(geom[3]) or min_w;
    if stored_w < min_w or stored_w > max_w then
        -- Repairs widths saved while 1.1.0's widening bug was active.
        stored_w = min_w;
        geom[3] = min_w;
        state.geometry_dirty = true;
    end
    -- Content width = window width minus the theme's 12px side padding.
    imgui.SetNextWindowContentSize({ stored_w - 24, 0 });

    push_mh_theme(win_alpha('target'), win_scale('target'));
    local title = state.mini_mode[1] and 'MobHunt Mini##target' or 'MobHunt##target';
    if imgui.Begin(title, state.visible, window_flags(state.lock_target[1], true)) then
        custom_close('mobhunt_target_close', state.visible);
        uifont.push(win_scale('target'));

        if target == nil then
            imgui.TextColored(state.muted, state.mini_mode[1]
                and 'No monster targeted.'
                or 'Target a monster to view MobHunt statistics.');
        else
            local key = record_key(target.zone_id, target.name);
            local rec = config.records[key];
            local srec = state.session[key];

            imgui.TextColored(UI_ACCENT_TEXT, tostring(target.name));
            if state.encounters[target.id] ~= nil then
                -- "IN COMBAT" pill.
                imgui.SameLine(0, 10);
                local dl = imgui.GetWindowDrawList();
                local px, py = imgui.GetCursorScreenPos();
                px, py = tonumber(px) or 0, tonumber(py) or 0;
                local t = 'IN COMBAT';
                local lh = imgui.GetTextLineHeight();
                local w = tw_text(t) + 14;
                local pulse = 0.55 + 0.45 * math.abs(math.sin(os.clock() * 3));
                local c = state.success;
                dl:AddRectFilled({ px, py }, { px + w, py + lh + 2 }, imgui.GetColorU32({ c[1], c[2], c[3], 0.18 * pulse + 0.10 }), (lh + 2) / 2);
                dl:AddText({ px + 7, py + 1 }, imgui.GetColorU32(c), t);
                imgui.Dummy({ w, lh + 2 });
            end

            if state.mini_mode[1] then
                if rec == nil then
                    imgui.TextColored(state.muted, ('%s  |  No history'):fmt(tostring(target.zone_name)));
                else
                    imgui.TextColored(state.muted, tostring(target.zone_name));
                    imgui.Text(('F: %d   K: %d   D: %d   Win: %.1f%%'):fmt(
                        tonumber(rec.fights) or 0,
                        tonumber(rec.kills) or 0,
                        tonumber(rec.deaths) or 0,
                        pct(rec.kills, rec.fights)
                    ));
                    local mini_age = format_age(rec.last_kill);
                    if mini_age ~= nil then
                        imgui.TextColored(state.muted, ('Last kill %s'):fmt(mini_age));
                    end
                    if state.show_session[1] then
                        imgui.Text(('Session  F: %d   K: %d   D: %d'):fmt(
                            srec and (tonumber(srec.fights) or 0) or 0,
                            srec and (tonumber(srec.kills) or 0) or 0,
                            srec and (tonumber(srec.deaths) or 0) or 0
                        ));
                    end
                end
            else
                imgui.TextColored(state.muted, tostring(target.zone_name));
                imgui.Separator();

                if rec == nil then
                    imgui.TextColored(state.muted, 'No recorded encounters with this mob in this zone.');
                else
                    draw_record_summary(rec, key, false);
                end

                imgui.Separator();
                if draw_toggle_button('History', 'mh_t_hist', state.history_visible[1] == true) then
                    state.history_visible[1] = not state.history_visible[1];
                    state.settings_dirty = true;
                end
                imgui.SameLine();
                if draw_toggle_button('Config', 'mh_t_cfg', state.config_visible[1] == true) then
                    state.config_visible[1] = not state.config_visible[1];
                    state.settings_dirty = true;
                end
                imgui.SameLine();
                if draw_toggle_button('Timers', 'mh_t_timers', state.timers_visible[1] == true) then
                    state.timers_visible[1] = not state.timers_visible[1];
                    state.settings_dirty = true;
                end
                imgui.SameLine();
                if imgui.Button('Mini') then
                    state.mini_mode[1] = true;
                    state.mini_apply_geometry = true;
                    state.settings_dirty = true;
                end
            end
        end

        if state.mini_mode[1] then
            imgui.Separator();
            if imgui.SmallButton('Full##mh_full') then
                state.mini_mode[1] = false;
                state.target_apply_geometry = true;
                state.settings_dirty = true;
            end
            imgui.SameLine();
            if imgui.SmallButton('History##mh_mini_hist') then
                state.history_visible[1] = not state.history_visible[1];
                state.settings_dirty = true;
            end
            imgui.SameLine();
            if imgui.SmallButton('Config##mh_mini_cfg') then
                state.config_visible[1] = not state.config_visible[1];
                state.settings_dirty = true;
            end
            imgui.SameLine();
            if imgui.SmallButton('Timers##mh_mini_timers') then
                state.timers_visible[1] = not state.timers_visible[1];
                state.settings_dirty = true;
            end
        end

        uifont.pop();
        if not state.lock_target[1] then
            capture_position(geom);
            -- Width and height are controlled by content / AlwaysAutoResize.
            -- The observed height is kept only for settings visibility.
            geom[4] = tonumber(select(2, imgui.GetWindowSize())) or geom[4];
        end
    end
    imgui.End();
    pop_mh_theme();
end

-- Best drop match for an item search (highest rate), or nil.
local function history_drop_match(rec, search)
    if rec == nil or rec.drops == nil or search == '' then return nil; end
    local best = nil;
    for _, drop in pairs(rec.drops) do
        if drop ~= nil and tostring(drop.name or ''):lower():find(search, 1, true) ~= nil then
            if best == nil or (tonumber(drop.occurrences) or 0) > (tonumber(best.occurrences) or 0) then
                best = drop;
            end
        end
    end
    return best;
end

local function filtered_history()
    local search = tostring(state.history_search[1] or ''):lower():gsub('^%s+', ''):gsub('%s+$', '');
    local rows = {};
    local current_zone_id = get_zone_id();

    for key, rec in pairs(config.records) do
        if rec ~= nil then
            local zone_matches = (not state.history_current_zone[1])
                or ((tonumber(rec.zone_id) or 0) == current_zone_id);

            if zone_matches then
                local matches = (search == '');
                local match_drop = nil;
                if not matches then
                    local hay = (tostring(rec.name or '') .. ' ' .. tostring(rec.zone_name or '')):lower();
                    matches = hay:find(search, 1, true) ~= nil;
                    -- Item search: list every mob that dropped it.
                    match_drop = history_drop_match(rec, search);
                    if match_drop ~= nil then matches = true; end
                end

                if matches then
                    table.insert(rows, T{ key = key, rec = rec, drop = match_drop });
                end
            end
        end
    end

    table.sort(rows, function(a, b)
        local av, bv;
        if state.history_sort == 'name' then
            av = tostring(a.rec.name or ''):lower();
            bv = tostring(b.rec.name or ''):lower();
        elseif state.history_sort == 'zone' then
            av = tostring(a.rec.zone_name or ''):lower();
            bv = tostring(b.rec.zone_name or ''):lower();
        elseif state.history_sort == 'fights' then
            av = tonumber(a.rec.fights) or 0;
            bv = tonumber(b.rec.fights) or 0;
        elseif state.history_sort == 'deaths' then
            av = tonumber(a.rec.deaths) or 0;
            bv = tonumber(b.rec.deaths) or 0;
        elseif state.history_sort == 'win' then
            av = pct(a.rec.kills, a.rec.fights);
            bv = pct(b.rec.kills, b.rec.fights);
        elseif state.history_sort == 'match' then
            av = a.drop and pct(a.drop.occurrences, a.rec.kills) or -1;
            bv = b.drop and pct(b.drop.occurrences, b.rec.kills) or -1;
        elseif state.history_sort == 'danger' then
            -- Deaths per fight; deaths break ties so a 1/1 ranks above 0/0.
            av = pct(a.rec.deaths, a.rec.fights) * 100000 + (tonumber(a.rec.deaths) or 0);
            bv = pct(b.rec.deaths, b.rec.fights) * 100000 + (tonumber(b.rec.deaths) or 0);
        else
            av = tonumber(a.rec.kills) or 0;
            bv = tonumber(b.rec.kills) or 0;
        end

        if av == bv then
            return tostring(a.rec.name or ''):lower() < tostring(b.rec.name or ''):lower();
        end

        if state.history_sort_desc then return av > bv; end
        return av < bv;
    end);

    return rows;
end

local function text_w(text)
    return tonumber((imgui.CalcTextSize(tostring(text)))) or 0;
end

-- Text right-aligned inside the current table cell.
local function cell_right(text, color)
    text = tostring(text);
    local avail = tonumber((imgui.GetContentRegionAvail())) or 0;
    local w = text_w(text);
    if avail > w then imgui.SetCursorPosX(imgui.GetCursorPosX() + avail - w); end
    if color then imgui.TextColored(color, text); else imgui.Text(text); end
end

-- Clickable column header (muted, accent when it is the active sort).
local function sort_header(label, mode, right)
    local active = state.history_sort == mode;
    local text = label .. (active and (state.history_sort_desc and ' v' or ' ^') or '');
    local w = text_w(text);
    if right then
        local avail = tonumber((imgui.GetContentRegionAvail())) or 0;
        if avail > w then imgui.SetCursorPosX(imgui.GetCursorPosX() + avail - w); end
    end

    imgui.PushStyleColor(ImGuiCol_Text, active and UI_ACCENT_TEXT or UI_MUTED);
    imgui.PushStyleColor(ImGuiCol_Header, UI_TRANSPARENT);
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, ui_accent(0.18));
    imgui.PushStyleColor(ImGuiCol_HeaderActive, ui_accent(0.26));
    local clicked = imgui.Selectable(text .. '##mh_sort_' .. mode, false, 0, { w, 0 });
    imgui.PopStyleColor(4);

    if clicked then
        if active then
            state.history_sort_desc = not state.history_sort_desc;
        else
            state.history_sort = mode;
            state.history_sort_desc = (mode ~= 'name' and mode ~= 'zone');
        end
    end
end

local function delete_history_record(key)
    if key == nil or config.records[key] == nil then return; end

    config.records[key] = nil;
    state.session[key] = nil;

    for id, enc in pairs(state.encounters) do
        if enc ~= nil and enc.key == key then
            state.encounters[id] = nil;
            clear_persisted_encounter(id);
        end
    end
    if config.active_encounters ~= nil then
        for marker_id, marker in pairs(config.active_encounters) do
            if marker ~= nil and marker.key == key then
                config.active_encounters[marker_id] = nil;
            end
        end
    end
    for id, dead in pairs(state.recent_dead) do
        if dead ~= nil and dead.key == key then state.recent_dead[id] = nil; end
    end

    state.history_selected_key = nil;
    state.history_delete_key = nil;
    state.data_dirty = true;
    settings.save();
end

-- ----------------------------------------------------------------------------
-- Timers: time since the last kill of each mob in the current zone, most
-- recent first. Useful for placeholder / NM camps. Auto-sized; position saved.
-- ----------------------------------------------------------------------------
local TIMER_MAX_ROWS = 15;
local TIMER_MAX_AGE = 3 * 3600;

local function draw_timers_window()
    if not state.timers_visible[1] then
        state.timers_apply_geometry = true;
        return;
    end

    if state.timers_apply_geometry then
        imgui.SetNextWindowPos({ state.timers_geom[1], state.timers_geom[2] }, { 0, 0 });
        state.timers_apply_geometry = false;
    end

    local zone_id = get_zone_id();
    local now = os.time();
    local rows = {};
    for key, rec in pairs(config.records) do
        if rec ~= nil and (tonumber(rec.zone_id) or -1) == zone_id then
            local last = tonumber(rec.last_kill) or 0;
            if last > 0 and (now - last) <= TIMER_MAX_AGE then
                rows[#rows + 1] = { key = key, rec = rec, last = last };
            end
        end
    end
    table.sort(rows, function(a, b) return a.last > b.last; end);

    push_mh_theme(win_alpha('timers'), win_scale('timers'));
    if imgui.Begin('MobHunt Timers##timers', state.timers_visible, window_flags(config.locks.timers == true, true)) then
        uifont.push(win_scale('timers'));

        -- Everything here is sized from the text itself. Nothing may depend
        -- on the window's current width (an auto-sized window would keep
        -- whatever width it had - the old close button sat at "window width
        -- minus 34", which pinned the window at its widest size).
        local function tw(text)
            local w = imgui.CalcTextSize(tostring(text));
            return tonumber(w) or 0;
        end

        local title = ('Last Kills  -  %s'):fmt(safe_zone_name(zone_id));
        local count = math.min(#rows, TIMER_MAX_ROWS);
        local pad = 18;

        local col1 = tw('Mob');
        for k = 1, count do
            col1 = math.max(col1, tw(rows[k].rec.name or '?'));
        end
        local col2 = math.max(tw('Last Kill'), tw('00h 00m'));
        local col3 = tw('Kills');
        local empty_text = 'No kills in this zone in the last 3 hours.';
        local content_w = (count > 0) and (col1 + pad + col2 + pad + col3) or tw(empty_text);
        content_w = math.max(content_w, tw(title));

        local base_x = imgui.GetCursorPosX();
        imgui.TextColored(UI_ACCENT_TEXT, title);

        -- Close button right after the content (only when the title bar,
        -- which has its own X, is hidden).
        if not state.title_bar[1] then
            imgui.SameLine();
            imgui.SetCursorPosX(base_x + content_w + 10);
            if imgui.SmallButton('X##mobhunt_timers_close') then
                state.timers_visible[1] = false;
                state.settings_dirty = true;
            end
        end
        imgui.Separator();

        if count == 0 then
            imgui.TextColored(state.muted, empty_text);
        else
            local target = state.current_target;
            local target_key = target and record_key(target.zone_id, target.name) or nil;
            local x2 = base_x + col1 + pad;
            local x3 = x2 + col2 + pad;

            imgui.TextColored(state.muted, 'Mob');
            imgui.SameLine(); imgui.SetCursorPosX(x2); imgui.TextColored(state.muted, 'Last Kill');
            imgui.SameLine(); imgui.SetCursorPosX(x3); imgui.TextColored(state.muted, 'Kills');

            for k = 1, count do
                local row = rows[k];
                local name = tostring(row.rec.name or '?');
                if row.key == target_key then
                    imgui.TextColored(UI_ACCENT_TEXT, name);
                else
                    imgui.Text(name);
                end
                imgui.SameLine(); imgui.SetCursorPosX(x2); imgui.Text(format_span(now - row.last));
                imgui.SameLine(); imgui.SetCursorPosX(x3); imgui.Text(tostring(tonumber(row.rec.kills) or 0));
            end
        end

        uifont.pop();

        local x, y = imgui.GetWindowPos();
        x = tonumber(x); y = tonumber(y);
        if x and y and (math.abs(x - state.timers_geom[1]) >= 1 or math.abs(y - state.timers_geom[2]) >= 1) then
            state.timers_geom[1] = x;
            state.timers_geom[2] = y;
            state.geometry_dirty = true;
        end
    end
    imgui.End();
    pop_mh_theme();
end

local function draw_history_window()
    if not state.history_visible[1] then
        state.history_apply_geometry = true;
        state.history_frame = nil;
        return;
    end

    if state.history_apply_geometry then
        imgui.SetNextWindowPos({ state.history_geom[1], state.history_geom[2] }, { 0, 0 });
        imgui.SetNextWindowSize({ state.history_geom[3], state.history_geom[4] });
        state.history_apply_geometry = false;
    end

    push_mh_theme(history_alpha(), win_scale('history'));
    if imgui.Begin('MobHunt History##history', state.history_visible, window_flags(state.lock_history[1])) then
        -- Frame for the docked Mob detail window.
        local fx, fy = imgui.GetWindowPos();
        local fw, fh = imgui.GetWindowSize();
        state.history_frame = { tonumber(fx) or 0, tonumber(fy) or 0, tonumber(fw) or 0, tonumber(fh) or 0 };

        custom_close('mobhunt_history_close', state.history_visible);

        uifont.push(win_scale('history'));

        -- Scope: Current Zone | All  +  zone label.
        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 10, 4 });
        if draw_styled_tab('Current Zone', 'mh_history_scope_zone', state.history_current_zone[1] == true) then
            state.history_current_zone[1] = true;
            state.settings_dirty = true;
        end
        imgui.SameLine(0, 4);
        if draw_styled_tab('All Zones', 'mh_history_scope_all', state.history_current_zone[1] ~= true) then
            state.history_current_zone[1] = false;
            state.settings_dirty = true;
        end
        imgui.PopStyleVar(1);
        imgui.SameLine(0, 12);
        align_label();
        imgui.TextColored(state.muted, state.history_current_zone[1] and safe_zone_name(get_zone_id()) or 'All saved zones');

        imgui.Spacing();

        -- Search: mob, zone or item.
        local clear_w = text_w('Clear') + 20;
        local avail_w = tonumber((imgui.GetContentRegionAvail())) or 400;
        imgui.PushItemWidth(math.max(160, math.min(420, avail_w - clear_w - 8)));
        imgui.InputText('##mobhunt_history_search', state.history_search, 128);
        imgui.PopItemWidth();
        imgui.SameLine();
        if imgui.Button('Clear##mh_history_clear') then state.history_search[1] = ''; end
        imgui.SameLine();
        align_label();
        imgui.TextColored(state.muted, 'mob, zone or item');

        local rows = filtered_history();
        local item_search = false;
        local total_kills, total_deaths = 0, 0;
        for _, row in ipairs(rows) do
            total_kills = total_kills + (tonumber(row.rec.kills) or 0);
            total_deaths = total_deaths + (tonumber(row.rec.deaths) or 0);
            if row.drop ~= nil then item_search = true; end
        end
        if not item_search and state.history_sort == 'match' then state.history_sort = 'kills'; end

        -- 1.6.0: totals as chips.
        do
            local dl = imgui.GetWindowDrawList();
            local x0, y0 = imgui.GetCursorScreenPos();
            x0, y0 = tonumber(x0) or 0, tonumber(y0) or 0;
            local lh = imgui.GetTextLineHeight();
            local cx = x0;
            for _, ch in ipairs({ { 'Mobs', tostring(#rows), UI_ACCENT_TEXT }, { 'Kills', tostring(total_kills), state.success },
                { 'Deaths', tostring(total_deaths), total_deaths > 0 and state.danger or state.muted } }) do
                local w = text_w(ch[1]) + text_w(ch[2]) + 22;
                dl:AddRectFilled({ cx, y0 }, { cx + w, y0 + lh + 6 }, imgui.GetColorU32({ UI_CONTROL[1], UI_CONTROL[2], UI_CONTROL[3], 0.9 }), (lh + 6) / 2);
                dl:AddText({ cx + 8, y0 + 3 }, imgui.GetColorU32(state.muted), ch[1]);
                dl:AddText({ cx + 14 + text_w(ch[1]), y0 + 3 }, imgui.GetColorU32(ch[3]), ch[2]);
                cx = cx + w + 6;
            end
            imgui.Dummy({ cx - x0, lh + 6 });
        end
        imgui.SameLine(0, 18);
        if draw_toggle_button('Most Dangerous', 'mh_sort_danger_btn', state.history_sort == 'danger') then
            if state.history_sort == 'danger' then
                state.history_sort = 'kills';
            else
                state.history_sort = 'danger';
            end
            state.history_sort_desc = true;
        end
        help_marker('Sorts by death rate (deaths per fight), highest first. Click a mob for its full details and drops.');

        imgui.Spacing();

        if imgui.BeginTable ~= nil then
            local ncols = item_search and 8 or 7;
            local flags = bit.bor(
                ImGuiTableFlags_RowBg or 0,
                ImGuiTableFlags_BordersInnerH or 0,
                ImGuiTableFlags_ScrollY or 0,
                ImGuiTableFlags_PadOuterX or 0);
            local _, avail_h = imgui.GetContentRegionAvail();
            avail_h = math.max(120, tonumber(avail_h) or 300);

            if imgui.BeginTable('##mobhunt_history_table2', ncols, flags, { 0, avail_h }) then
                local num_w = math.max(text_w('Deaths v'), text_w('00000')) + 10;
                local pct_w = math.max(text_w('Death % v'), text_w('100.0%')) + 10;
                imgui.TableSetupColumn('Mob', ImGuiTableColumnFlags_WidthStretch or 0, 1.35);
                imgui.TableSetupColumn('Zone', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);
                imgui.TableSetupColumn('Fights', ImGuiTableColumnFlags_WidthFixed or 0, num_w);
                imgui.TableSetupColumn('Kills', ImGuiTableColumnFlags_WidthFixed or 0, num_w);
                imgui.TableSetupColumn('Deaths', ImGuiTableColumnFlags_WidthFixed or 0, num_w);
                imgui.TableSetupColumn('Win %', ImGuiTableColumnFlags_WidthFixed or 0, pct_w);
                imgui.TableSetupColumn('Death %', ImGuiTableColumnFlags_WidthFixed or 0, pct_w);
                if item_search then
                    imgui.TableSetupColumn('Item', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);
                end
                if imgui.TableSetupScrollFreeze ~= nil then imgui.TableSetupScrollFreeze(0, 1); end

                imgui.TableNextRow(ImGuiTableRowFlags_Headers or 1);
                imgui.TableNextColumn(); sort_header('Mob', 'name', false);
                imgui.TableNextColumn(); sort_header('Zone', 'zone', false);
                imgui.TableNextColumn(); sort_header('Fights', 'fights', true);
                imgui.TableNextColumn(); sort_header('Kills', 'kills', true);
                imgui.TableNextColumn(); sort_header('Deaths', 'deaths', true);
                imgui.TableNextColumn(); sort_header('Win %', 'win', true);
                imgui.TableNextColumn(); sort_header('Death %', 'danger', true);
                if item_search then
                    imgui.TableNextColumn(); sort_header('Item drop', 'match', false);
                end

                -- 1.6.0: with All Zones, this zone's mobs stand out.
                local hl_zone = nil;
                if state.history_current_zone[1] ~= true and config.behavior.zone_highlight ~= false then
                    hl_zone = get_zone_id();
                end

                for _, row in ipairs(rows) do
                    local rec = row.rec;
                    imgui.TableNextRow();
                    imgui.TableNextColumn();

                    local selected = state.detail_open and state.history_selected_key == row.key;
                    local in_zone = hl_zone ~= nil and tonumber(rec.zone_id) == hl_zone;
                    if in_zone then imgui.PushStyleColor(ImGuiCol_Text, config.appearance.zone_highlight); end
                    local sel_clicked = imgui.Selectable(tostring(rec.name or 'Unknown') .. '##mh_hist_' .. row.key, selected,
                        ImGuiSelectableFlags_SpanAllColumns or 0);
                    if in_zone then imgui.PopStyleColor(1); end
                    if sel_clicked then
                        if selected then
                            state.detail_open = false;
                        else
                            state.history_selected_key = row.key;
                            state.detail_open = true;
                            state.detail_delete_at = nil;
                        end
                    end

                    local here = hl_zone ~= nil and tonumber(rec.zone_id) == hl_zone;
                    if here then
                        -- Current zone's mob: name and zone in the highlight color.
                        local x1, y1 = imgui.GetItemRectMin();
                        if x1 ~= nil then
                            local c = config.appearance.zone_highlight;
                            imgui.GetWindowDrawList():AddRectFilled({ tonumber(x1) - 4, tonumber(y1) + 2 },
                                { tonumber(x1) - 1, tonumber(y1) + imgui.GetTextLineHeight() - 2 }, imgui.GetColorU32(c), 1.0);
                        end
                    end
                    imgui.TableNextColumn(); imgui.TextColored(here and config.appearance.zone_highlight or state.muted, tostring(rec.zone_name or '--'));
                    imgui.TableNextColumn(); cell_right(tonumber(rec.fights) or 0);
                    imgui.TableNextColumn(); cell_right(tonumber(rec.kills) or 0, state.success);
                    imgui.TableNextColumn();
                    local deaths = tonumber(rec.deaths) or 0;
                    cell_right(deaths, deaths > 0 and state.danger or state.muted);
                    imgui.TableNextColumn(); cell_right(('%.1f%%'):fmt(pct(rec.kills, rec.fights)));
                    imgui.TableNextColumn();
                    local death_rate = pct(rec.deaths, rec.fights);
                    cell_right(('%.1f%%'):fmt(death_rate), death_rate > 0 and state.danger or state.muted);
                    if item_search then
                        imgui.TableNextColumn();
                        if row.drop ~= nil then
                            imgui.Text(tostring(row.drop.name or '?'));
                            imgui.SameLine();
                            imgui.TextColored(UI_ACCENT_TEXT, ('%.1f%%'):fmt(pct(row.drop.occurrences, rec.kills)));
                        else
                            imgui.TextColored(state.muted, '--');
                        end
                    end
                end
                imgui.EndTable();
            end
        else
            for _, row in ipairs(rows) do
                local rec = row.rec;
                if imgui.Selectable(('%s - %s##fallback_%s'):fmt(rec.name or 'Unknown', rec.zone_name or '--', row.key),
                    state.history_selected_key == row.key) then
                    state.history_selected_key = row.key;
                    state.detail_open = true;
                end
            end
        end

        uifont.pop();

        if not state.lock_history[1] then capture_geometry(state.history_geom); end
    end
    imgui.End();
    pop_mh_theme();
end

-- Label / value pairs in measured columns (values right-aligned).
local function kv_grid(items, cols)
    local lw, vw = 0, 0;
    for _, it in ipairs(items) do
        lw = math.max(lw, text_w(it[1]));
        vw = math.max(vw, text_w(it[2]));
    end
    local cell = lw + 12 + vw + 26;
    local x0 = imgui.GetCursorPosX();
    for i, it in ipairs(items) do
        local col = (i - 1) % cols;
        if col > 0 then imgui.SameLine(); end
        imgui.SetCursorPosX(x0 + col * cell);
        imgui.TextColored(state.muted, it[1]);
        imgui.SameLine();
        imgui.SetCursorPosX(x0 + col * cell + lw + 12 + (vw - text_w(it[2])));
        if it[3] then imgui.TextColored(it[3], it[2]); else imgui.Text(it[2]); end
    end
end

-- Full drop table with rate bars and kills since last drop. Measured columns,
-- so it is safe inside an auto-sized window.
local function draw_detail_drops(rec, key)
    local drops = sorted_drops(rec);
    if #drops == 0 then
        imgui.TextColored(state.muted, 'No recorded drops yet.');
        return;
    end

    local s = state.session[key];
    local kills = tonumber(rec.kills) or 0;
    local BAR_W = 46;

    local headers = { 'Item', 'Drops', 'Rate', '', 'Qty', 'Since', 'Last seen', 'Session' };
    local right = { false, true, true, false, true, true, false, true };
    local cells = {};
    for i, drop in ipairs(drops) do
        local occ = tonumber(drop.occurrences) or 0;
        local since = '--';
        if drop.last_kill_count ~= nil then
            since = tostring(math.max(0, kills - (tonumber(drop.last_kill_count) or 0)));
        end
        local sdrop = s and s.drops and s.drops[tostring(drop.item_id)] or nil;
        cells[i] = {
            tostring(drop.name or ('Item ' .. tostring(drop.item_id or '?'))),
            tostring(occ),
            ('%.1f%%'):fmt(pct(occ, kills)),
            '',
            tostring(tonumber(drop.quantity) or 0),
            since,
            format_age(drop.last_seen) or '--',
            sdrop and tostring(tonumber(sdrop.occurrences) or 0) or '--',
            rate = pct(occ, kills),
        };
    end

    local widths = {};
    for c, h in ipairs(headers) do
        local w = text_w(h);
        for _, row in ipairs(cells) do w = math.max(w, text_w(row[c])); end
        if c == 4 then w = BAR_W; end
        widths[c] = w;
    end

    local x0 = imgui.GetCursorPosX();
    local xs = {};
    local x = x0;
    for c = 1, #headers do
        xs[c] = x;
        x = x + widths[c] + ((c == 3) and 6 or 14);
    end

    local function put(c, text, color)
        if c > 1 then imgui.SameLine(); end
        local px = xs[c];
        if right[c] then px = px + widths[c] - text_w(text); end
        imgui.SetCursorPosX(px);
        if color then imgui.TextColored(color, text); else imgui.Text(text); end
    end

    for c, h in ipairs(headers) do put(c, h, state.muted); end

    local dl = imgui.GetWindowDrawList();
    for _, row in ipairs(cells) do
        for c = 1, #headers do
            if c == 4 then
                imgui.SameLine();
                imgui.SetCursorPosX(xs[4]);
                local sx, sy = imgui.GetCursorScreenPos();
                local lh = imgui.GetTextLineHeight();
                local by = sy + lh * 0.5 - 2;
                local fill = math.max(0, math.min(1, (row.rate or 0) / 100));
                dl:AddRectFilled({ sx, by }, { sx + BAR_W, by + 4 }, imgui.GetColorU32({ 0.2, 0.2, 0.22, 1.0 }), 2.0);
                if fill > 0 then
                    dl:AddRectFilled({ sx, by }, { sx + math.max(2, BAR_W * fill), by + 4 }, imgui.GetColorU32(UI_ACCENT), 2.0);
                end
                imgui.Dummy({ BAR_W, lh });
            elseif c == 3 then
                put(c, row[c], UI_ACCENT_TEXT);
            elseif c == 1 then
                put(c, row[c]);
            elseif c == 7 or c == 8 then
                put(c, row[c], state.muted);
            else
                put(c, row[c]);
            end
        end
    end
    imgui.Spacing();
    imgui.TextColored(state.muted, 'Since = kills since that item last dropped. Rate = kills with the item / total kills.');
end

-- 1.6.0: abilities table (Mob Details). Measured columns, auto-size safe.
local function draw_detail_abilities(rec)
    local list, total = sorted_abilities(rec);
    if #list == 0 then
        imgui.TextColored(state.muted, (config.behavior.track_abilities == false)
            and 'Ability tracking is off (Config > Content).'
            or 'Nothing yet. Abilities are added when the mob dies.');
        return;
    end
    local kills = math.max(1, tonumber(rec.ability_kills) or 0);
    local BAR_W = 46;
    local headers = { 'Ability', 'Type', 'Used', 'Share', '', 'Finished', 'Interrupted', 'Per fight' };
    local right = { false, false, true, true, false, true, true, true };
    local cells = {};
    for i, a in ipairs(list) do
        local intr = (a.s2 > 0) and math.max(0, (a.s2 - a.f) * 100 / a.s2) or nil;
        cells[i] = {
            a.name, (a.k == 'ma') and 'Spell' or 'TP move', tostring(a.s), ('%.1f%%'):fmt(a.share), '',
            (a.s2 > 0) and tostring(a.f) or '--', intr and ('%.0f%%'):fmt(intr) or '--', ('%.2f'):fmt(a.s / kills),
            share = a.share, intr = intr or 0,
        };
    end
    local widths = {};
    for c, h in ipairs(headers) do
        local w = text_w(h);
        for _, row in ipairs(cells) do w = math.max(w, text_w(row[c])); end
        if c == 5 then w = BAR_W; end
        widths[c] = w;
    end
    local x0 = imgui.GetCursorPosX();
    local xs, x = {}, x0;
    for c = 1, #headers do
        xs[c] = x;
        x = x + widths[c] + ((c == 4) and 6 or 14);
    end
    local function put(c, text, color)
        if c > 1 then imgui.SameLine(); end
        local px = xs[c];
        if right[c] then px = px + widths[c] - text_w(text); end
        imgui.SetCursorPosX(px);
        if color then imgui.TextColored(color, text); else imgui.Text(text); end
    end
    for c, h in ipairs(headers) do put(c, h, state.muted); end
    local dl = imgui.GetWindowDrawList();
    for _, row in ipairs(cells) do
        for c = 1, #headers do
            if c == 5 then
                imgui.SameLine();
                imgui.SetCursorPosX(xs[5]);
                local sx, sy = imgui.GetCursorScreenPos();
                local lh = imgui.GetTextLineHeight();
                local by = sy + lh * 0.5 - 2;
                local fill = math.max(0, math.min(1, (row.share or 0) / 100));
                dl:AddRectFilled({ sx, by }, { sx + BAR_W, by + 4 }, imgui.GetColorU32({ 0.2, 0.2, 0.22, 1.0 }), 2.0);
                if fill > 0 then
                    dl:AddRectFilled({ sx, by }, { sx + math.max(2, BAR_W * fill), by + 4 }, imgui.GetColorU32(UI_ACCENT), 2.0);
                end
                imgui.Dummy({ BAR_W, lh });
            elseif c == 4 then
                put(c, row[c], UI_ACCENT_TEXT);
            elseif c == 2 then
                put(c, row[c], state.muted);
            elseif c == 7 then
                put(c, row[c], (row.intr or 0) >= 25 and state.success or state.muted);
            else
                put(c, row[c]);
            end
        end
    end
    imgui.Spacing();
    imgui.TextColored(state.muted, ('%d uses over %d kills. Used = started (interrupted or not). Share = of all its uses.'):fmt(total, kills));
end

-- 1.6.0: a row of stat tiles (label over a big value) for Mob Details.
local function stat_tiles(items)
    local dl = imgui.GetWindowDrawList();
    local lh = imgui.GetTextLineHeight();
    local pad = 8;
    local w = 0;
    for _, it in ipairs(items) do w = math.max(w, text_w(it[1]), text_w(it[2]) * 1.25); end
    w = w + pad * 2;
    local h = lh * 2.4 + pad;
    local x0, y0 = imgui.GetCursorScreenPos();
    x0, y0 = tonumber(x0) or 0, tonumber(y0) or 0;
    for i, it in ipairs(items) do
        local x = x0 + (i - 1) * (w + 6);
        dl:AddRectFilled({ x, y0 }, { x + w, y0 + h }, imgui.GetColorU32({ UI_CONTROL[1], UI_CONTROL[2], UI_CONTROL[3], 0.85 }), 5.0);
        dl:AddRectFilled({ x, y0 + h - 2 }, { x + w, y0 + h }, imgui.GetColorU32(it[3] or UI_ACCENT), 2.0);
        dl:AddText({ x + pad, y0 + pad * 0.6 }, imgui.GetColorU32(state.muted), it[1]);
        local fs = imgui.GetFontSize() * 1.25;
        dl:AddText(imgui.GetFont(), fs, { x + pad, y0 + pad * 0.6 + lh }, imgui.GetColorU32(it[3] or UI_TEXT), it[2]);
    end
    imgui.Dummy({ #items * (w + 6) - 6, h + 4 });
end

-- Mob detail window, docked beside History. Opens when a mob is clicked.
local function draw_detail_window()
    if not state.history_visible[1] or not state.detail_open then return; end
    local key = state.history_selected_key;
    local rec = key and config.records[key] or nil;
    if rec == nil or state.history_frame == nil then
        state.detail_open = false;
        return;
    end

    local hx, hy, hw = state.history_frame[1], state.history_frame[2], state.history_frame[3];
    local dsize = imgui.GetIO().DisplaySize;
    local dw = tonumber(state.detail_last_w) or 420;
    local x = hx + hw + 6;
    if x + dw > (tonumber(dsize.x) or 1920) then
        x = math.max(0, hx - dw - 6);
    end
    imgui.SetNextWindowPos({ x, hy });

    local flags = bit.bor(
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoMove,
        ImGuiWindowFlags_NoTitleBar,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing or 0);

    push_mh_theme(history_alpha(), win_scale('history'));
    if imgui.Begin('MobHunt Mob Detail##mh_detail', nil, flags) then
        uifont.push(win_scale('history'));

        -- Title row: name, zone, close.
        align_label();
        imgui.TextColored(UI_ACCENT_TEXT, tostring(rec.name or 'Unknown'));
        imgui.SameLine(0, 10);
        align_label();
        imgui.TextColored(state.muted, tostring(rec.zone_name or safe_zone_name(rec.zone_id)));
        imgui.SameLine(0, 18);
        if imgui.SmallButton('X##mh_detail_close') then
            state.detail_open = false;
        end
        imgui.Spacing();

        local fights = tonumber(rec.fights) or 0;
        local kills = tonumber(rec.kills) or 0;
        local deaths = tonumber(rec.deaths) or 0;
        local exp_kills = tonumber(rec.exp_kills) or 0;
        local timed = tonumber(rec.timed_kills) or 0;
        local exp_text = (exp_kills > 0) and ('%d'):fmt(math.floor(((tonumber(rec.exp_total) or 0) / exp_kills) + 0.5)) or '--';
        local time_text = (timed > 0) and format_span((tonumber(rec.fight_seconds) or 0) / timed) or '--';

        stat_tiles({
            { 'Kills', tostring(kills), state.success },
            { 'Deaths', tostring(deaths), deaths > 0 and state.danger or nil },
            { 'Win rate', ('%.0f%%'):fmt(pct(kills, fights)) },
            { 'Avg fight', time_text },
        });

        section_header('Lifetime');
        kv_grid({
            { 'Fights', tostring(fights) },
            { 'Kills', tostring(kills), state.success },
            { 'Deaths', tostring(deaths), deaths > 0 and state.danger or nil },
            { 'Win rate', ('%.1f%%'):fmt(pct(kills, fights)) },
            { 'Death rate', ('%.1f%%'):fmt(pct(deaths, fights)), deaths > 0 and state.danger or nil },
            { 'Avg EXP', exp_text },
            { 'Avg fight', time_text },
            { 'Total EXP', tostring(math.floor(tonumber(rec.exp_total) or 0)) },
            { 'Streak', ('%d (best %d)'):fmt(tonumber(rec.current_streak) or 0, tonumber(rec.best_streak) or 0) },
        }, 3);

        imgui.Spacing();
        section_header('Times');
        local last_kill_age = format_age(rec.last_kill);
        kv_grid({
            { 'First seen', fmt_time(rec.first_seen) },
            { 'Last kill', fmt_time(rec.last_kill) .. (last_kill_age and ('  (' .. last_kill_age .. ')') or '') },
            { 'Last death', fmt_time(rec.last_death) },
        }, 1);

        if state.show_session[1] then
            local s = state.session[key];
            imgui.Spacing();
            section_header('This Session');
            local items = {
                { 'Fights', tostring(s and (tonumber(s.fights) or 0) or 0) },
                { 'Kills', tostring(s and (tonumber(s.kills) or 0) or 0), state.success },
                { 'Deaths', tostring(s and (tonumber(s.deaths) or 0) or 0) },
            };
            if state.show_kills_per_hour[1] then
                items[#items + 1] = { 'Kills / hr', ('%.1f'):fmt(session_kph(s)) };
            end
            items[#items + 1] = { 'EXP', tostring(s and (tonumber(s.exp_total) or 0) or 0) };
            kv_grid(items, 3);
        end

        draw_job_stats(rec, true);

        imgui.Spacing();
        section_header('Abilities');
        draw_detail_abilities(rec);

        imgui.Spacing();
        section_header('Drops');
        draw_detail_drops(rec, key);

        imgui.Spacing();
        imgui.Separator();
        imgui.Spacing();
        -- Two-click delete (second click within 3s).
        local armed = state.detail_delete_at ~= nil and (os.clock() - state.detail_delete_at) < 3.0;
        imgui.PushStyleColor(ImGuiCol_Button, armed and { 0.62, 0.14, 0.14, 1.0 } or UI_CONTROL);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.70, 0.18, 0.18, 1.0 });
        imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.80, 0.22, 0.22, 1.0 });
        local clicked = imgui.Button((armed and 'Click again to delete' or 'Delete record') .. '##mh_detail_delete');
        imgui.PopStyleColor(3);
        if clicked then
            if armed then
                delete_history_record(key);
                state.detail_open = false;
                state.detail_delete_at = nil;
            else
                state.detail_delete_at = os.clock();
            end
        end
        imgui.SameLine();
        align_label();
        imgui.TextColored(state.muted, 'Removes this mob + zone record and its drops.');

        uifont.pop();

        local ww = imgui.GetWindowSize();
        state.detail_last_w = tonumber(ww) or state.detail_last_w;
    end
    imgui.End();
    pop_mh_theme();
end

-- Red two-click button: the first click arms it for 3 seconds, the second
-- click within that time confirms. Returns true on the confirming click.
-- Clears every mob record (fights, kills, deaths, EXP, drops) plus session
-- and in-flight tracking. Settings and window layout are kept.
local function purge_all_records()
    config.records = T{};
    config.active_encounters = T{};
    state.session = T{};
    state.session_start = os.time();
    state.encounters = T{};
    state.recent_dead = T{};
    state.recent_kills = T{};
    state.recent_deaths = T{};
    state.recent_party_kills = T{};
    state.pending_engage = T{};
    state.history_selected_key = nil;
    state.detail_open = false;
    state.data_dirty = true;
    settings.save();
    print('[MobHunt] All mob records purged.');
end

-- Clears only the drop tables; fights / kills / deaths stay.
local function purge_drop_records()
    for _, rec in pairs(config.records) do
        if rec ~= nil then rec.drops = T{}; end
    end
    for _, s in pairs(state.session) do
        if s ~= nil then s.drops = T{}; end
    end
    state.data_dirty = true;
    settings.save();
    print('[MobHunt] All drop records purged.');
end

-- ============================================================================
-- Settings window (1.7.0): the MogSuite layout. A search box finds any
-- setting by name or help text; the sidebar groups the pages; every page has
-- a title, one line about it, and settings in two columns. Each window has
-- its own page with its size, opacity and lock.
-- ============================================================================

ui.theme = {
    text = UI_TEXT, muted = UI_MUTED, accent = UI_ACCENT, accent_text = UI_ACCENT_TEXT,
    control = UI_CONTROL, danger = { 1.00, 0.40, 0.40, 1.00 },
    section_header = section_header,
    help_marker = help_marker,
    align_label = align_label,
    toggle_button = draw_toggle_button,
    tip = function(text_value)
        if imgui.IsItemHovered() then
            imgui.BeginTooltip();
            imgui.PushTextWrapPos(420);
            imgui.TextUnformatted(text_value);
            imgui.PopTextWrapPos();
            imgui.EndTooltip();
        end
    end,
};

local CFG = { armed = {} };   -- pages and their helpers (one table: the main chunk is near LuaJIT's local limit)

function CFG.dirty() state.settings_dirty = true; end

function CFG.reset_geometry()
    state.target_geom = { defaults.window.x, defaults.window.y, defaults.window.width, defaults.window.height };
    state.mini_geom = { defaults.mini_window.x, defaults.mini_window.y, defaults.mini_window.width, defaults.mini_window.height };
    state.history_geom = { defaults.history_window.x, defaults.history_window.y, defaults.history_window.width, defaults.history_window.height };
    state.config_geom = { defaults.config_window.x, defaults.config_window.y, math.max(defaults.config_window.width, 860), math.max(defaults.config_window.height, 620) };
    state.timers_geom = { defaults.timers_window.x, defaults.timers_window.y };
    state.target_apply_geometry = true;
    state.mini_apply_geometry = true;
    state.history_apply_geometry = true;
    state.config_apply_geometry = true;
    state.timers_apply_geometry = true;
    state.geometry_dirty = true;
end

-- Size + opacity of one window (same controls on every window page).
function CFG.window_look(name, what)
    local w = win_look(name);
    ui.scale_presets('Size', w, 'scale', 'Scales the text, spacing and icons of the ' .. what .. '.', {
        on_change = function()
            if name == 'target' then state.target_apply_geometry = true; state.mini_apply_geometry = true; end
        end,
    });
    if name == 'config' then
        ui.slider_f('Opacity', w, 'alpha', 0, 100, '%.0f%%', 'How see-through this settings window is. It has its own opacity, separate from the other windows.', { mul = 100 });
    else
        ui.check('Own opacity', w, 'own_alpha', 'Off: the ' .. what .. ' uses the background opacity from Look > Theme & colors. On: set it here.');
        if w.own_alpha == true or ui.searching() then
            ui.sub(function()
                ui.slider_f('Opacity', w, 'alpha', 0, 100, '%.0f%%', 'How see-through the background of the ' .. what .. ' is. Text stays solid.', { mul = 100 });
            end);
        end
    end
end

-- ----------------------------------------------------------------------------
-- GENERAL
-- ----------------------------------------------------------------------------

function CFG.page_general()
    ui.section('WINDOWS');
    ui.check('Show the target window', state.visible, 1, 'The window with the stats of your current target. Closing it with X turns this off; /mhunt target toggles it.', {
        on_change = function() state.target_apply_geometry = true; state.mini_apply_geometry = true; end,
    });
    ui.check('Show the History window', state.history_visible, 1, 'Every mob you have fought, with search, sorting and Mob Details. /mhunt history');
    ui.check('Show the Timers window', state.timers_visible, 1, 'Time since your last kill of each mob in this zone. /mhunt timers');

    ui.section('FRAME');
    ui.check('Title bars', state.title_bar, 1, 'Off: the windows have no title bar and get a small X button instead.');
    ui.check('Borders', state.border, 1, 'A thin border around every MobHunt window.');

    ui.section('POSITIONS');
    if ui.button('Lock all windows', 'mh_lock_all', 'Stops every MobHunt window from moving and resizing.') then
        state.lock_target[1] = true; state.lock_history[1] = true; state.lock_config[1] = true;
        config.locks.timers = true;
        CFG.dirty();
    end
    if not ui.searching() then
        imgui.SameLine();
        if imgui.Button('Unlock all##mh_unlock_all') then
            state.lock_target[1] = false; state.lock_history[1] = false; state.lock_config[1] = false;
            config.locks.timers = false;
            CFG.dirty();
        end
    end
    if ui.danger('Reset window positions', 'mh_reset_pos', CFG.armed, 'Puts every window back in its starting place and size. Click twice.') then
        CFG.reset_geometry();
    end
end

-- ----------------------------------------------------------------------------
-- WINDOWS
-- ----------------------------------------------------------------------------

function CFG.page_target()
    ui.section('WINDOW');
    ui.check('Show the target window', state.visible, 1, 'Closing it with X turns this off; /mhunt target toggles it.', {
        on_change = function() state.target_apply_geometry = true; state.mini_apply_geometry = true; end,
    });
    ui.check('Only with a target', state.target_only, 1, 'Hides the window while you have no monster targeted.');
    ui.check('Mini view', state.mini_mode, 1, 'A small window with just the key numbers. The Mini / Full button on the window and /mhunt mini switch too. Each view keeps its own place.', {
        on_change = function() state.target_apply_geometry = true; state.mini_apply_geometry = true; end,
    });
    ui.check('Lock position', state.lock_target, 1, 'Stops the target window from moving.');

    ui.section('LOOK');
    CFG.window_look('target', 'target window');

    ui.section('CONTENT');
    ui.check('This session', state.show_session, 1, 'Fights, kills, deaths and kills per hour since you logged in (or reset the session).');
    ui.check('Observed drops', state.show_drops, 1, 'The drops you have seen from this mob, with their drop rate.');
    ui.check('Kills per hour', state.show_kills_per_hour, 1, 'Kills per hour for this session.');
    ui.check('Per-job stats', state.show_by_job, 1, 'Your kills and deaths on this mob for each job you fought it as.');
    ui.check('Top abilities', config.behavior, 'abilities_target', 'The abilities your target uses most, one per row with their share and how often they get interrupted. The full list is in History > Mob Details.', { default_on = true });
    if config.behavior.abilities_target ~= false or ui.searching() then
        ui.sub(function()
            ui.slider_i('Ability rows', config.behavior, 'abilities_rows', 1, 10, '%d abilities', 'How many abilities the target window lists.');
        end);
    end
end

function CFG.page_history()
    ui.section('WINDOW');
    ui.check('Show the History window', state.history_visible, 1, '/mhunt history');
    ui.check('Lock position and size', state.lock_history, 1, 'Stops the History window from moving and resizing.');
    ui.choice('Opens on', state.history_current_zone, 1, {
        { key = true, label = 'Current zone', tip = 'Only the mobs of the zone you are in.' },
        { key = false, label = 'All zones', tip = 'Every mob you have fought.' },
    }, 'Which list History shows (the tabs at the top of the window switch it too).');

    ui.section('LOOK');
    CFG.window_look('history', 'History and Mob Details windows');

    ui.section('THIS ZONE');
    ui.check('Highlight this zone\'s mobs', config.behavior, 'zone_highlight', 'With All Zones shown, the mobs of the zone you are in are written in the color below.', { default_on = true });
    if config.behavior.zone_highlight ~= false or ui.searching() then
        ui.sub(function()
            ui.color('Highlight color', config.appearance.zone_highlight, 'The color of this zone\'s mobs in All Zones.', true);
        end);
    end
end

function CFG.page_timers()
    ui.section('WINDOW');
    ui.check('Show the Timers window', state.timers_visible, 1, 'Time since your last kill of each mob in this zone (up to 3 hours). /mhunt timers');
    ui.check('Lock position', config.locks, 'timers', 'Stops the Timers window from moving.');

    ui.section('LOOK');
    CFG.window_look('timers', 'Timers window');
end

function CFG.page_settings_window()
    ui.section('WINDOW');
    ui.check('Lock position and size', state.lock_config, 1, 'Stops this window from moving and resizing.');

    ui.section('LOOK');
    CFG.window_look('config', 'settings window');
end

-- ----------------------------------------------------------------------------
-- LOOK
-- ----------------------------------------------------------------------------

function CFG.page_theme()
    ui.section('THEME');
    if ui.want('Theme', 'Colors every MobHunt window: accents, tabs, borders and title bars. Forest Rust Bone Copper Garnet Silver Amethyst Emerald Midnight') then
        ui.label('Theme', 'Colors every MobHunt window: accents, tabs, borders and title bars.');
        local current = normalize_theme_key(state.theme);
        -- One button per theme with its color chip; wraps onto the next line
        -- (under the control column) when the row is full.
        local col_x = ui.LABEL_W * ui.scale;
        local avail = imgui.GetContentRegionAvail();
        if type(avail) == 'table' then avail = avail.x or avail[1]; end
        local right = col_x + (tonumber(avail) or 500);
        local chip = 9 * ui.scale;
        for i, key in ipairs(UI_THEME_ORDER) do
            local th = UI_THEMES[key];
            local label = '      ' .. th.label;
            local bw = text_w(label) + 16 * ui.scale;
            if i > 1 then
                imgui.SameLine(0, 4);
                if imgui.GetCursorPosX() + bw > right then
                    imgui.NewLine();
                    imgui.SetCursorPosX(col_x);
                end
            end
            if draw_toggle_button(label, 'mh_theme_' .. key, key == current) then
                state.theme = key;
                CFG.dirty();
            end
            pcall(function()
                local x1, y1 = imgui.GetItemRectMin();
                local _, y2 = imgui.GetItemRectMax();
                x1, y1, y2 = tonumber(x1), tonumber(y1), tonumber(y2);
                local cy = (y1 + y2) / 2;
                local a = th.accent;
                imgui.GetWindowDrawList():AddRectFilled({ x1 + 8 * ui.scale, cy - chip / 2 }, { x1 + 8 * ui.scale + chip, cy + chip / 2 },
                    imgui.GetColorU32({ a[1] / 255, a[2] / 255, a[3] / 255, 1 }), 2);
            end);
        end
        imgui.Dummy({ 1, 4 * ui.scale });
    end

    ui.section('BACKGROUND');
    ui.check("Use the theme's background", config.appearance, 'use_theme_bg', 'Each theme has its own dark background (Midnight is deep navy). Off: pick your own color below.');
    if config.appearance.use_theme_bg ~= true or ui.searching() then
        ui.sub(function()
            ui.color('Background color', state.background, 'The background of every MobHunt window (a window with its own opacity keeps this color).', false);
        end);
    end
    ui.slider_f('Opacity', state.background, 4, 0, 100, '%.0f%%', 'How see-through the target, History and Timers windows are (unless one has its own opacity on its page). The settings window has its own.', { mul = 100 });

    ui.section('STAT COLORS');
    ui.color('Kills / good', state.success, 'Kills, wins, streaks and other good numbers.', true);
    ui.color('Deaths / bad', state.danger, 'Deaths, interrupted abilities and other bad numbers.', true);
    ui.color('Muted text', state.muted, 'Labels, times and other secondary text in the windows.', true);
end

function CFG.page_fonts()
    uifont.settings_page(config, {
        header = function(title) ui.section(title); end,
        label = function(text_value, help_text) ui.label(text_value, help_text); end,
        dirty = CFG.dirty,
        want = function(text_value, help_text) return ui.want(text_value, help_text); end,
        ctrl_w = ui.SLIDER_W * ui.scale,
        accent = UI_ACCENT_TEXT,
        muted = UI_MUTED,
    });
end

-- ----------------------------------------------------------------------------
-- TRACKING
-- ----------------------------------------------------------------------------

function CFG.page_tracking()
    ui.section('FIGHTS');
    ui.info('A fight begins only after you engage or act on a mob, or that mob acts on you. Merely targeting a mob does not count.');
    ui.slider_i('Encounter timeout', state.encounter_timeout, 1, 15, 600, '%d sec', 'A fight with no action for this long is dropped (not counted as a kill or a death).');
    ui.check('Count party kills you did not join', state.credit_party_kills, 1, 'When a party / alliance member kills a mob near you that you never touched, count it as a fight and a kill and record its drops.');

    ui.section('MOB ABILITIES');
    ui.check('Track mob abilities', config.behavior, 'track_abilities', 'Every TP move and spell a mob STARTS is counted, even when it gets interrupted, plus how many it finished. Nothing is added or shown until the mob is dead.', { default_on = true });

    ui.section('DEBUG');
    ui.check('Debug messages in chat', state.debug, 1, 'Prints what MobHunt sees (packets, kills, drops) to the chat log. /mhunt debug');
end

function CFG.page_data()
    local mobs, kills, items = 0, 0, 0;
    for _, rec in pairs(config.records) do
        if rec ~= nil then
            mobs = mobs + 1;
            kills = kills + (tonumber(rec.kills) or 0);
            if rec.drops ~= nil then
                for _ in pairs(rec.drops) do items = items + 1; end
            end
        end
    end

    ui.section('SAVED DATA');
    ui.value('Mob / zone records', mobs);
    ui.value('Kills recorded', kills);
    ui.value('Drop entries', items);
    ui.info('Saved per character in Game\\config\\addons\\MobHunt\\<Character>_<id>\\settings.lua');

    ui.section('SESSION');
    if ui.button('Reset this session', 'mh_reset_session', 'Clears the This Session numbers only. Lifetime records stay. /mhunt session') then
        state.session = T{};
        state.session_start = os.time();
        dbg('Session statistics reset.');
    end

    ui.section('PURGE');
    ui.info('Purging cannot be undone. Settings, colors and window positions are kept.');
    if ui.danger('Purge drop data only', 'mh_purge_drops', CFG.armed, 'Clears every drop table. Fights, kills, deaths, EXP and times stay. Click twice.') then
        purge_drop_records();
    end
    if ui.danger('Purge all mob data', 'mh_purge_all', CFG.armed, 'Clears every mob record (fights, kills, deaths, EXP, drops) and this session. Click twice.') then
        purge_all_records();
    end
end

-- ----------------------------------------------------------------------------
-- HELP
-- ----------------------------------------------------------------------------

CFG.COMMANDS = {
    { '/mhunt', 'Open History and Settings (and turn the target window back on)' },
    { '/mhunt target', 'Show / hide the target window' },
    { '/mhunt mini', 'Switch the target window between Full and Mini' },
    { '/mhunt history', 'Show / hide the History window' },
    { '/mhunt timers', 'Show / hide the Timers window' },
    { '/mhunt config', 'Show / hide this settings window' },
    { '/mhunt session', 'Reset this session\'s numbers' },
    { '/mhunt debug', 'Debug messages on / off' },
    { '/mhunt help', 'List the commands in chat' },
};

function CFG.page_commands()
    ui.section('COMMANDS');
    ui.info('/mobhunt works the same as /mhunt.');
    for _, c in ipairs(CFG.COMMANDS) do
        if ui.want(c[1], c[2]) then
            ui.label(c[1]);
            imgui.TextColored(UI_TEXT, c[2]);
        end
    end

    ui.section('MOUSE');
    if ui.want('Mouse', 'drag click double right') then
        ui.info('Drag a window by its title bar (or anywhere when title bars are off). In History, click a mob to open its Mob Details beside it; click a column title to sort.');
    end

    ui.section('ABOUT');
    ui.value('Version', addon.version);
    ui.value('Author', addon.author);
    ui.info('Written for HorizonXI. It only reads what the game already shows you and never sends anything.');
end

function CFG.page_diagnostics()
    local c = state.debug_counters;
    local function n(v) return tostring(tonumber(v) or 0); end
    ui.section('COUNTERS');
    ui.value('Action packets', n(c.actions));
    ui.value('Encounters started', n(c.starts));
    ui.value('Encounters resumed', n(c.resumes));
    ui.value('Kills counted', n(c.kills));
    ui.value('Deaths counted', n(c.deaths));
    ui.value('Player HP', state.last_player_hp == nil and '--' or tostring(state.last_player_hp));
    ui.value('Player dead', state.player_dead and 'YES' or 'NO');
    ui.section('DROPS');
    ui.value('Treasure packets seen', n(c.drop_packets));
    ui.value('Treasure memory scans', n(c.treasure_memory_scans));
    ui.value('Treasure memory drops', n(c.treasure_memory_drops));
    ui.value('Inventory packets seen', n(c.inventory_packets));
    ui.value('Direct inventory drops', n(c.direct_drops));
    ui.value('Drops counted', n(c.drops));
    ui.value('Drops from find lines', n(c.chat_drops));
    ui.value('Drops not credited', n(c.ignored_drops));
end

CFG.GROUPS = {
    { label = 'General', pages = {
        { key = 'general', label = 'General', desc = 'Which MobHunt windows are shown, their frame, and their positions.', draw = CFG.page_general },
    } },
    { label = 'Windows', pages = {
        { key = 'target', label = 'Target window', desc = 'The window with your target\'s stats: when it shows, its size and opacity, and what it lists.', draw = CFG.page_target },
        { key = 'history', label = 'History', desc = 'Every mob you have fought, and the Mob Details window beside it.', draw = CFG.page_history },
        { key = 'timers', label = 'Timers', desc = 'Time since your last kill of each mob in this zone.', draw = CFG.page_timers },
        { key = 'settings', label = 'Settings window', desc = 'This window.', draw = CFG.page_settings_window },
    } },
    { label = 'Look', pages = {
        { key = 'theme', label = 'Theme & colors', desc = 'The theme, the window background and the colors of the numbers.', draw = CFG.page_theme },
        { key = 'fonts', label = 'Fonts & Tooltips', desc = 'The font of every MobHunt window, and how tooltips look.', draw = CFG.page_fonts },
    } },
    { label = 'Tracking', pages = {
        { key = 'tracking', label = 'Tracking', desc = 'What counts as a fight, party kills, and mob abilities.', draw = CFG.page_tracking },
        { key = 'data', label = 'Data', desc = 'Your saved records: what is stored, the session, and purging.', draw = CFG.page_data },
    } },
    { label = 'Help', pages = {
        { key = 'commands', label = 'Commands', desc = 'Every command, the mouse, and the version.', draw = CFG.page_commands },
        { key = 'diagnostics', label = 'Diagnostics', desc = 'What MobHunt has seen since it loaded (for tracking down a missed kill or drop).', draw = CFG.page_diagnostics },
    } },
};

CFG.CTX = {
    id = 'mh',
    title = 'MobHunt',
    groups = CFG.GROUPS,
    page = function() return config.config_page or 'general'; end,
    set_page = function(key) config.config_page = key; CFG.dirty(); end,
    dirty = CFG.dirty,
    -- Keep the theme swatches clear of the X button drawn when title bars are off.
    reserve_right = function() return state.title_bar[1] and 0 or 40; end,
    themes = {
        order = UI_THEME_ORDER,
        list = UI_THEMES,
        current = function() return normalize_theme_key(state.theme); end,
        set = function(key) state.theme = key; CFG.dirty(); end,
    },
};

local function draw_config_window()
    if not state.config_visible[1] then
        state.config_apply_geometry = true;
        return;
    end

    local s = win_scale('config');
    if state.config_apply_geometry then
        -- The sidebar layout needs room: older saves were sized for tabs.
        imgui.SetNextWindowPos({ state.config_geom[1], state.config_geom[2] }, { 0, 0 });
        imgui.SetNextWindowSize({ math.max(state.config_geom[3], 860), math.max(state.config_geom[4], 560) });
        state.config_apply_geometry = false;
    end
    if imgui.SetNextWindowSizeConstraints ~= nil then
        imgui.SetNextWindowSizeConstraints({ 600 * s, 380 * s }, { 4000, 4000 });
    end

    push_mh_theme(win_alpha('config'));
    -- The settings window uses the roomier MogSuite spacing.
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 8 * s, 5 * s });
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 8 * s, 4 * s });
    uifont.push(s);
    if imgui.Begin('MobHunt Settings##config', state.config_visible, window_flags(state.lock_config[1])) then
        custom_close('mobhunt_config_close', state.config_visible);
        ui.scale = s;
        local ok, err = pcall(ui.body, CFG.CTX);
        if not ok then imgui.TextColored(ui.theme.danger, tostring(err)); end
        if not state.lock_config[1] then capture_geometry(state.config_geom); end
    end
    imgui.End();
    uifont.pop();
    imgui.PopStyleVar(2);
    pop_mh_theme();
end

local function reset_session()
    state.session = T{};
    state.session_start = os.time();
    dbg('Session statistics reset.');
end

local function apply_loaded_config(s)
    if s == nil then return; end
    config = s;
    ensure_config_tables();
    uifont.set_global(config);

    -- Runtime state is intentionally refreshed after Ashita resolves the active
    -- character settings context.
    state.visible[1] = config.visible ~= false;
    state.history_visible[1] = config.history_visible == true;
    state.config_visible[1] = config.config_visible == true;
    state.timers_visible[1] = config.timers_visible == true;
    if config.timers_window ~= nil then
        state.timers_geom[1] = tonumber(config.timers_window.x) or state.timers_geom[1];
        state.timers_geom[2] = tonumber(config.timers_window.y) or state.timers_geom[2];
    end
    state.timers_apply_geometry = true;
    state.font_scale[1] = tonumber(config.font_scale) or defaults.font_scale;

    local function apply_color(dst, src, def)
        src = src or T{};
        for i = 1, 4 do dst[i] = tonumber(src[i]) or def[i]; end
    end
    apply_color(state.background, config.appearance.background, defaults.appearance.background);

    if is_legacy_default_background(state.background) then
        for i = 1, 4 do state.background[i] = STATUSTIMERS_BG[i]; end
        for i = 1, 4 do config.appearance.background[i] = STATUSTIMERS_BG[i]; end
        state.settings_dirty = true;
    end

    apply_color(state.accent, config.appearance.accent, defaults.appearance.accent);
    apply_color(state.success, config.appearance.success, defaults.appearance.success);
    apply_color(state.danger, config.appearance.danger, defaults.appearance.danger);
    apply_color(state.muted, config.appearance.muted, defaults.appearance.muted);

    state.border[1] = config.appearance.border ~= false;
    state.title_bar[1] = config.appearance.title_bar ~= false;
    state.theme = tostring(config.appearance.theme or 'forest');

    state.target_only[1] = config.behavior.target_only ~= false;
    state.mini_mode[1] = config.behavior.mini_mode == true;
    state.history_current_zone[1] = config.behavior.history_current_zone ~= false;
    state.show_session[1] = config.behavior.show_session ~= false;
    state.show_drops[1] = config.behavior.show_drops ~= false;
    state.show_kills_per_hour[1] = config.behavior.show_kills_per_hour ~= false;
    state.show_by_job[1] = config.behavior.show_by_job ~= false;
    state.debug[1] = config.behavior.debug == true;
    state.encounter_timeout[1] = tonumber(config.behavior.encounter_timeout) or defaults.behavior.encounter_timeout;
    state.credit_party_kills[1] = config.behavior.credit_party_kills ~= false;

    state.lock_target[1] = config.locks.target == true;
    state.lock_history[1] = config.locks.history == true;
    state.lock_config[1] = config.locks.config == true;

    local function load_geom(dst, src, def)
        dst[1] = tonumber(src.x) or def.x;
        dst[2] = tonumber(src.y) or def.y;
        dst[3] = tonumber(src.width) or def.width;
        dst[4] = tonumber(src.height) or def.height;
    end
    load_geom(state.target_geom, config.window, defaults.window);
    load_geom(state.mini_geom, config.mini_window, defaults.mini_window);
    load_geom(state.history_geom, config.history_window, defaults.history_window);
    load_geom(state.config_geom, config.config_window, defaults.config_window);

    state.target_apply_geometry = true;
    state.mini_apply_geometry = true;
    state.history_apply_geometry = true;
    state.config_apply_geometry = true;
end

settings.register('settings', 'mobhunt_settings_update', function(s)
    apply_loaded_config(s);
end);

ashita.events.register('load', 'mobhunt_load_cb', function()
    pcall(uifont.load, config);
end);

ashita.events.register('text_in', 'mobhunt_text_in_cb', function(e)
    if e == nil or e.message == nil then return; end
    -- Skip re-printed lines (e.g. a chat addon replaying its backlog).
    if e.injected == true then return; end
    local ok, err = pcall(handle_find_message, e.message);
    if not ok then dbg('find line error: ' .. tostring(err)); end
end);

ashita.events.register('packet_in', 'mobhunt_packet_in_cb', function(e)
    if e == nil then return; end

    local player_id = get_player_id();
    if player_id == 0 then return; end

    if e.id == 0x028 then
        local act = parse_action_packet(e);
        if act == nil then return; end
        state.debug_counters.actions = (tonumber(state.debug_counters.actions) or 0) + 1;
        -- Mob abilities are tracked after the fight logic below has had a
        -- chance to start the encounter.
        local track_after = act;

        -- Keep any open fight alive while the mob is still involved in combat
        -- (acting, or being acted on) so long party fights where you only
        -- heal / support still credit the kill.
        touch_encounter(act.actor_id);
        for _, target in ipairs(act.targets) do
            touch_encounter(target.id);
        end

        -- A party member (or the mob) acting on a mob you engaged starts
        -- the fight; drawing your weapon alone does not.
        local pending_actor = state.pending_engage[act.actor_id];
        if pending_actor ~= nil then
            for _, target in ipairs(act.targets) do
                if target.id == player_id or is_party_member(target.id) then
                    start_encounter(resolve_entity(act.actor_id) or pending_actor.info, 'engaged_mob_action');
                    break;
                end
            end
        elseif act.actor_id ~= player_id and is_party_member(act.actor_id) then
            for _, target in ipairs(act.targets) do
                local pending = state.pending_engage[target.id];
                if pending ~= nil then
                    start_encounter(resolve_entity(target.id) or pending.info, 'engaged_party_action');
                end
            end
        end

        if act.actor_id == player_id then
            for _, target in ipairs(act.targets) do
                if target.id ~= player_id then
                    local info = resolve_entity(target.id);
                    if info ~= nil then start_encounter(info, 'player_action'); end
                    touch_encounter(target.id);
                end
            end
        else
            for _, target in ipairs(act.targets) do
                if target.id == player_id then
                    local info = resolve_entity(act.actor_id);
                    if info ~= nil and info.is_mob == true then
                        start_encounter(info, 'mob_action');
                        state.last_hostile = T{
                            id = act.actor_id,
                            index = info.index,
                            time = os.clock(),
                        };
                    end
                    touch_encounter(act.actor_id);
                end
            end
        end

        pcall(track_mob_ability, track_after);

    elseif e.id == 0x029 then
        local p = parse_action_message(e);
        if p == nil then return; end

        if DEATH_MESSAGES:contains(p.message) then
            if p.target == player_id and p.actor ~= player_id then
                count_death(p.actor, p.actor_index, 'action_message');
            elseif p.target ~= player_id then
                -- Death messages for a mob are an important no-EXP / NM fallback.
                if not count_kill(p.target, p.target_index, 'death_message')
                    and not credit_party_kill(p.target, p.target_index, p.actor, 'death_message') then
                    note_party_kill(p.target, p.actor);
                end
            end
        end

    elseif e.id == 0x02D then
        local p = parse_kill_packet(e);
        if p == nil then return; end
        if p.target ~= 0 and p.target ~= player_id then
            -- 0x02D only arrives for kills that give your party credit.
            if not count_kill(p.target, p.target_index, 'kill_packet')
                and not credit_party_kill(p.target, p.target_index, nil, 'kill_packet') then
                note_party_kill(p.target, nil);
            end
            if p.player == player_id and EXP_MESSAGES:contains(tonumber(p.message) or 0) then
                credit_kill_exp(p.target, p.amount);
            end
        end

    elseif e.id == 0x01F then
        -- Item assigned directly into inventory. This is how many solo / no-pool
        -- monster drops arrive, so 0x0D2 alone is not sufficient.
        local p = parse_inventory_assign_packet(e);
        if p ~= nil then
            state.debug_counters.inventory_packets = (tonumber(state.debug_counters.inventory_packets) or 0) + 1;
            local old = state.inventory_slots[inventory_slot_key(p.bag, p.index)];
            local old_count = (old ~= nil and tonumber(old.item_id) == tonumber(p.item)) and (tonumber(old.count) or 0) or 0;
            local delta = math.max(0, (tonumber(p.count) or 0) - old_count);
            cache_inventory_slot(p.bag, p.index, p.item, p.count);
            if tonumber(p.bag) == 0 and delta > 0 then
                record_direct_inventory_drop(p.item, delta, '0x01F');
            end
        end

    elseif e.id == 0x01E then
        -- Count-only inventory modification; commonly used when a drop stacks onto
        -- an item already in inventory. Use our pre-packet slot cache to obtain id.
        local p = parse_inventory_modify_packet(e);
        if p ~= nil then
            state.debug_counters.inventory_packets = (tonumber(state.debug_counters.inventory_packets) or 0) + 1;
            local skey = inventory_slot_key(p.bag, p.index);
            local old = state.inventory_slots[skey];
            if old ~= nil then
                local old_count = tonumber(old.count) or 0;
                local new_count = tonumber(p.count) or 0;
                local delta = new_count - old_count;
                if tonumber(p.bag) == 0 and tonumber(old.item_id) and tonumber(old.item_id) > 0 and delta > 0 then
                    record_direct_inventory_drop(old.item_id, delta, '0x01E');
                end
                cache_inventory_slot(p.bag, p.index, old.item_id, new_count);
            end
        end

    elseif e.id == 0x0D2 then
        -- HorizonXI's 0x0D2 layout does not match the retail/Windower field
        -- layout used by earlier MobHunt builds. Keep this packet as a diagnostic
        -- signal only; the authoritative item id now comes from Ashita's live
        -- treasure-pool memory (GetTreasurePoolItem).
        state.debug_counters.drop_packets = (tonumber(state.debug_counters.drop_packets) or 0) + 1;

        if state.debug[1] then
            local p = parse_drop_packet(e);
            if p ~= nil then
                dbg(('0x0D2 seen (diagnostic only): a=%d b=%d c=%d d=%d e=%d'):fmt(
                    tonumber(p.dropper) or 0,
                    tonumber(p.count) or 0,
                    tonumber(p.item) or 0,
                    tonumber(p.dropper_index) or 0,
                    tonumber(p.pool_index) or 0
                ));
            else
                dbg('0x0D2 seen (diagnostic only); parser could not read legacy layout.');
            end
        end
    end
end);

ashita.events.register('packet_out', 'mobhunt_packet_out_cb', function(e)
    if e == nil or e.id ~= 0x01A or e.data_modified == nil then return; end

    local ok, target_id, target_index, category = pcall(function()
        return struct.unpack('I', e.data_modified, 0x04 + 1),
               struct.unpack('H', e.data_modified, 0x08 + 1),
               struct.unpack('H', e.data_modified, 0x0A + 1);
    end);

    if not ok then return; end

    -- 0x02 = Engage monster (weapon drawn). This alone is not a fight: the
    -- mob is only marked pending until a real action happens between it and
    -- you / your party (see the 0x028 handler).
    if tonumber(category) == 0x02 and tonumber(target_id) and tonumber(target_id) ~= 0 then
        local info = resolve_entity(target_id, target_index);
        if info ~= nil and info.is_mob == true and state.encounters[info.id] == nil then
            state.pending_engage[info.id] = T{ info = info, time = os.clock() };
        end
    end
end);

ashita.events.register('command', 'mobhunt_command_cb', function(e)
    if e == nil or e.command == nil then return; end

    local args = e.command:args();
    if #args == 0 or not args[1]:any('/mobhunt', '/mhunt') then return; end

    e.blocked = true;

    if #args >= 2 then
        local sub = tostring(args[2]):lower();

        if sub == 'mini' then
            state.mini_mode[1] = not state.mini_mode[1];
            state.target_apply_geometry = true;
            state.mini_apply_geometry = true;
            state.settings_dirty = true;
            return;
        elseif sub == 'target' or sub == 'show' then
            state.visible[1] = not state.visible[1];
            state.target_apply_geometry = true;
            state.mini_apply_geometry = true;
            state.settings_dirty = true;
            print(('[MobHunt] Target window: %s'):fmt(state.visible[1] and 'ON' or 'OFF'));
            return;
        elseif sub == 'history' or sub == 'hist' then
            state.history_visible[1] = not state.history_visible[1];
            state.settings_dirty = true;
            return;
        elseif sub == 'config' or sub == 'settings' then
            state.config_visible[1] = not state.config_visible[1];
            state.settings_dirty = true;
            return;
        elseif sub == 'timers' or sub == 'timer' then
            state.timers_visible[1] = not state.timers_visible[1];
            state.settings_dirty = true;
            return;
        elseif sub == 'session' or sub == 'resetsession' then
            reset_session();
            print('[MobHunt] Current session statistics reset.');
            return;
        elseif sub == 'debug' then
            state.debug[1] = not state.debug[1];
            state.settings_dirty = true;
            print(('[MobHunt] Debug messages: %s'):fmt(state.debug[1] and 'ON' or 'OFF'));
            return;
        elseif sub == 'help' then
            print('[MobHunt] /mhunt - open History + Config (and turn the target window back on)');
            print('[MobHunt] /mhunt target - show / hide the target window');
            print('[MobHunt] /mhunt mini - toggle Full / Mini target view');
            print('[MobHunt] /mhunt history - toggle searchable history');
            print('[MobHunt] /mhunt config - toggle configuration');
            print('[MobHunt] /mhunt timers - toggle last-kill timers for this zone');
            print('[MobHunt] /mhunt session - reset current-session counters only');
            print('[MobHunt] /mhunt debug - toggle tracking diagnostics');
            return;
        end
    end

    -- Bare /mhunt is the MobHunt control-center shortcut: History + Config, and
    -- the target window is switched back on if it was closed (it still only
    -- appears with a target when "Only Show Target Window With a Target" is on).
    if not state.visible[1] then
        state.visible[1] = true;
        state.target_apply_geometry = true;
        state.mini_apply_geometry = true;
    end
    state.history_visible[1] = true;
    state.config_visible[1] = true;
    state.history_apply_geometry = true;
    state.config_apply_geometry = true;
    state.settings_dirty = true;
end);

ashita.events.register('d3d_present', 'mobhunt_present_cb', function()
    initialize_inventory_cache();
    scan_treasure_pool_memory();
    monitor_player_death();
    cleanup_runtime();

    -- Keep the current target cached so packet-time resolution usually avoids
    -- scanning the full entity map.
    local target = get_current_target();
    state.current_target = target;
    if target ~= nil then
        state.entity_cache[target.id] = target;
    end

    draw_target_window();
    draw_history_window();
    draw_detail_window();
    draw_timers_window();
    draw_config_window();

    -- Window / option changes save quickly. Lifetime statistics are written
    -- at most every 10 seconds during play (and always on unload / zoning),
    -- so a large history file is not rewritten on every fight start or kill.
    local now = os.clock();
    local ui_due = (state.geometry_dirty or state.settings_dirty) and (now - state.last_save) >= 0.75;
    local data_due = state.data_dirty and (now - state.last_data_save) >= 10.0;
    if ui_due or data_due then
        save_all();
        state.geometry_dirty = false;
        state.settings_dirty = false;
        state.data_dirty = false;
        state.last_save = now;
        state.last_data_save = now;
    end
end);

ashita.events.register('unload', 'mobhunt_unload_cb', function()
    save_all();
end);

ashita.events.register('zone_change', 'mobhunt_zone_change_cb', function()
    state.encounters = T{};
    state.pending_engage = T{};
    state.recent_dead = T{};
    state.recent_kills = T{};
    state.recent_deaths = T{};
    state.last_hostile = nil;
    state.last_player_hp = nil;
    state.player_dead = false;
    state.entity_cache = T{};
    state.inventory_slots = T{};
    state.inventory_cache_ready = false;
    state.treasure_slots = T{};
    state.treasure_cache_ready = false;
    state.treasure_last_scan = 0;
    state.current_target = nil;

    if config.active_encounters == nil then config.active_encounters = T{}; end
    config.active_encounters = T{};
    state.recent_party_kills = T{};

    -- Zoning is a natural checkpoint: write pending statistics now.
    save_all();
    state.data_dirty = false;
    state.geometry_dirty = false;
    state.settings_dirty = false;
    state.last_data_save = os.clock();
    state.last_save = os.clock();
end);
