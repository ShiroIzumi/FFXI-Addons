--[[
    MogSuite - modules/character/state.lua

    Runtime state of the Character window. The window works from these
    copies (ImGui needs { value } tables) and writes them back to the saved
    settings in save_config().
]]

-- Fills in anything an older settings file is missing.
function ensure_config()
    if config.appearance == nil then config.appearance = T{}; end
    if config.ui == nil then config.ui = T{}; end
    if config.window == nil then config.window = T{}; end

    local a = config.appearance;
    if a.locked == nil then a.locked = false; end
    if a.border == nil then a.border = true; end
    if a.title_bar == nil then a.title_bar = false; end
    if a.good_color == nil then a.good_color = T{ 0.30, 1.00, 0.42, 1.00 }; end
    if a.warn_color == nil then a.warn_color = T{ 1.00, 0.82, 0.22, 1.00 }; end
    if a.bad_color == nil then a.bad_color = T{ 1.00, 0.34, 0.38, 1.00 }; end
    if a.muted_color == nil then a.muted_color = T{ 0.68, 0.71, 0.75, 1.00 }; end

    if config.ui.ui_scale == nil then config.ui.ui_scale = 1.00; end
    if config.ui.tab == nil then config.ui.tab = 1; end
    if config.ui.skill_combat == nil then config.ui.skill_combat = true; end
    if config.ui.skill_magic == nil then config.ui.skill_magic = true; end
    if config.ui.skill_craft == nil then config.ui.skill_craft = true; end
    if config.ui.show_unusable == nil then config.ui.show_unusable = false; end
    if config.ui.hide_zero == nil then config.ui.hide_zero = true; end
    if config.ui.cur_show_zero == nil then config.ui.cur_show_zero = true; end
    if config.currencies == nil then config.currencies = T{ at = 0, values = T{} }; end
    if config.currencies.values == nil then config.currencies.values = T{}; end

    config.window.x = tonumber(config.window.x) or 120;
    config.window.y = tonumber(config.window.y) or 100;
    config.window.width = tonumber(config.window.width) or 600;
    config.window.height = tonumber(config.window.height) or 660;
end
ensure_config();

local function color4(src, d1, d2, d3)
    return T{ tonumber(src and src[1]) or d1, tonumber(src and src[2]) or d2, tonumber(src and src[3]) or d3, tonumber(src and src[4]) or 1.00 };
end

-- UI Scale limits (one slider sizes text and spacing together).
UI_SCALE_MIN = 0.75;
UI_SCALE_MAX = 2.50;
function initial_ui_scale(ui)
    local v = tonumber(ui and ui.ui_scale) or 1.0;
    return math.max(UI_SCALE_MIN, math.min(UI_SCALE_MAX, v));
end

state = T{
    open = T{ config.visible == true },
    locked = T{ config.appearance.locked == true },
    border = T{ config.appearance.border ~= false },
    title_bar = T{ config.appearance.title_bar == true },
    good_color = color4(config.appearance.good_color, 0.30, 1.00, 0.42),
    warn_color = color4(config.appearance.warn_color, 1.00, 0.82, 0.22),
    bad_color = color4(config.appearance.bad_color, 1.00, 0.34, 0.38),
    muted_color = color4(config.appearance.muted_color, 0.68, 0.71, 0.75),

    -- One UI Scale drives text size and spacing. overall_scale / font_scale
    -- are the same table, so all layout code stays in step.
    ui_scale = T{ initial_ui_scale(config.ui) },
    req_w = 0,
    frame_req_w = 0,

    tab = T{ math.max(1, math.min(6, tonumber(config.ui.tab) or 1)) },
    skill_combat = T{ config.ui.skill_combat ~= false },
    skill_magic = T{ config.ui.skill_magic ~= false },
    skill_craft = T{ config.ui.skill_craft ~= false },
    show_unusable = T{ config.ui.show_unusable == true },
    hide_zero = T{ config.ui.hide_zero ~= false },

    cur_search = T{ '' },
    cur_show_zero = T{ config.ui.cur_show_zero ~= false },

    apply_saved_geometry = true,
    last_x = config.window.x,
    last_y = config.window.y,
    last_w = config.window.width,
    last_h = config.window.height,
    geometry_dirty = false,
    settings_dirty = false,
    last_save = 0,

    -- Gear stats are re-parsed only when your gear changes.
    gear_signature = nil,
    gear_stats = nil,
    gear_checked = -1,
};
state.overall_scale = state.ui_scale;
state.font_scale = state.ui_scale;

ELEMENT_COLORS = {
    { 1.00, 0.34, 0.24, 1.00 }, -- Fire
    { 0.55, 0.86, 1.00, 1.00 }, -- Ice
    { 0.45, 0.95, 0.55, 1.00 }, -- Wind
    { 0.83, 0.63, 0.32, 1.00 }, -- Earth
    { 0.76, 0.55, 1.00, 1.00 }, -- Lightning
    { 0.32, 0.70, 1.00, 1.00 }, -- Water
    { 1.00, 0.92, 0.52, 1.00 }, -- Light
    { 0.66, 0.48, 0.82, 1.00 }, -- Dark
};

local function copy4(c)
    return T{ c[1], c[2], c[3], c[4] };
end

function save_config()
    config.visible = state.open[1] == true;
    config.appearance.locked = state.locked[1];
    config.appearance.border = state.border[1];
    config.appearance.title_bar = state.title_bar[1];
    config.appearance.good_color = copy4(state.good_color);
    config.appearance.warn_color = copy4(state.warn_color);
    config.appearance.bad_color = copy4(state.bad_color);
    config.appearance.muted_color = copy4(state.muted_color);

    config.ui.ui_scale = state.ui_scale[1];
    config.ui.tab = state.tab[1];
    config.ui.skill_combat = state.skill_combat[1] == true;
    config.ui.skill_magic = state.skill_magic[1] == true;
    config.ui.skill_craft = state.skill_craft[1] == true;
    config.ui.show_unusable = state.show_unusable[1] == true;
    config.ui.hide_zero = state.hide_zero[1] == true;
    config.ui.cur_show_zero = state.cur_show_zero[1] == true;

    config.window.x = state.last_x;
    config.window.y = state.last_y;
    config.window.width = state.last_w;
    config.window.height = state.last_h;

    settings.save();
end

-- Ashita replaced the settings table (login / character change): re-read
-- everything from it.
function apply_loaded_config()
    ensure_config();
    local a = config.appearance;
    state.open[1] = config.visible == true;
    state.locked[1] = a.locked == true;
    state.border[1] = a.border ~= false;
    state.title_bar[1] = a.title_bar == true;

    local function load_color(dst, src)
        for i = 1, 4 do dst[i] = tonumber(src and src[i]) or dst[i]; end
    end
    load_color(state.good_color, a.good_color);
    load_color(state.warn_color, a.warn_color);
    load_color(state.bad_color, a.bad_color);
    load_color(state.muted_color, a.muted_color);

    state.ui_scale[1] = initial_ui_scale(config.ui);
    state.tab[1] = math.max(1, math.min(6, tonumber(config.ui.tab) or 1));
    state.skill_combat[1] = config.ui.skill_combat ~= false;
    state.skill_magic[1] = config.ui.skill_magic ~= false;
    state.skill_craft[1] = config.ui.skill_craft ~= false;
    state.show_unusable[1] = config.ui.show_unusable == true;
    state.hide_zero[1] = config.ui.hide_zero ~= false;
    state.cur_show_zero[1] = config.ui.cur_show_zero ~= false;
    state.cur_search[1] = '';

    state.last_x = config.window.x;
    state.last_y = config.window.y;
    state.last_w = config.window.width;
    state.last_h = config.window.height;

    state.apply_saved_geometry = true;
    state.geometry_dirty = false;
    state.settings_dirty = false;
    state.gear_signature = nil;
    state.equip_list = nil;
end
