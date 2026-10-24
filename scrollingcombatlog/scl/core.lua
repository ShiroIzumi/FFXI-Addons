require('common');
local imgui = require('imgui');
local ashita_settings = require('settings');

local defaults = T{
    enabled = true,
    paused = false,
    duration = 3.5,
    scroll_speed = 70.0,
    font_scale = 1.35,

    -- Per-class font multipliers.
    melee_scale = 1.00,
    ability_scale = 1.00,
    heal_scale = 1.00,
    reward_scale = 1.00,

    show_symbols = true,
    locked = false,

    -- Readability / filtering.
    show_target_names = true,
    show_source_names = true,
    show_zero_damage = false,
    show_misses = true,
    combine_repeated_hits = true,
    combine_window = 0.22,
    max_visible_events = 14,

    config_window = T{
        x = 160,
        y = 120,
        w = 700,
        h = 720,
    },

    config_tools_window = T{
        x = 880,
        y = 120,
        w = 430,
        h = 720,
    },

    -- Combat text font rendering.
    renderer_mode = 'performance',

    -- Config window color theme: 'garnet', 'copper' or 'amethyst'.
    ui_theme = 'garnet',

    font_family = 'Consolas',
    font_bold = false,
    font_italic = false,
    font_outline = false,

    -- Text look (1.2.7). text_effect: none / outline / thick / shadow /
    -- soft_shadow / outline_shadow / glow. effect_color: black / charcoal /
    -- tinted / white. text_plate: off / subtle / dark / tinted.
    text_effect = 'none',
    effect_color = 'black',
    effect_opacity = 0.85,
    shadow_offset = 2,
    text_plate = 'off',
    plate_opacity = 0.45,
    plate_rounding = 4.0,
    text_opacity = 1.00,
    all_caps = false,

    -- Lane motion: 'scroll' (straight), 'arc' (curves sideways) or 'fade'
    -- (fades in and drifts slowly).
    outgoing = T{ x = 1180.0, y = 620.0, orientation = 'right', growth = 'up', motion = 'scroll' },
    incoming = T{ x = 580.0, y = 620.0, orientation = 'right', growth = 'up', motion = 'scroll' },

    -- Center Notifications lane (static, text centered on the anchor).
    notification = T{ x = 960.0, y = 300.0 },
    notify_scale = 1.30,
    notify = T{
        level_up = true,
        skillchains = true,
        magic_bursts = true,
        zone_change = true,
        wear_warning = true,
        big_hits = true,
        low_hp = true,
        -- 1.3.3: buffs / statuses wearing off, and food about to run out.
        status_removed = true,
        food_warning = true,
    },
    -- Low HP warning when your HP drops to this percent or below.
    low_hp_percent = 25,
    -- Outgoing damage at or above this value is also shown in Notifications.
    big_hit_threshold = 500,

    -- Display extras.
    crit_pop = true,
    element_colors = true,
    combine_aoe = true,

    -- Session window text size multiplier.
    session_font_scale = 1.00,

    -- Items Obtained panel attached to the Session window:
    -- 'right', 'left', 'below', or 'inside' (old in-window list).
    session_items_side = 'right',

    -- [REGEN] / [REFRESH] tick lines also when not resting.
    regen_ticks_always = false,

    session_window = T{
        x = 1320,
        y = 120,
        w = 360,
        h = 420,
    },

    event_options = T{
        melee_damage       = T{ show = true, color = { 1.00, 0.88, 0.32, 1.00 } },
        ranged_damage      = T{ show = true, color = { 0.96, 0.78, 0.34, 1.00 } },
        criticals          = T{ show = true, color = { 1.00, 0.48, 0.18, 1.00 } },
        weapon_skills      = T{ show = true, color = { 1.00, 0.72, 0.26, 1.00 } },
        spells             = T{ show = true, color = { 0.42, 0.82, 1.00, 1.00 } },
        magic_bursts       = T{ show = true, color = { 0.72, 0.58, 1.00, 1.00 } },
        skillchains        = T{ show = true, color = { 1.00, 0.54, 0.94, 1.00 } },
        outgoing_abilities = T{ show = true, color = { 0.46, 0.90, 0.92, 1.00 } },
        pet_damage         = T{ show = true, color = { 0.64, 0.90, 0.52, 1.00 } },
        additional_effects = T{ show = true, color = { 0.82, 0.76, 0.48, 1.00 } },
        counters           = T{ show = true, color = { 1.00, 0.64, 0.30, 1.00 } },
        healing_received   = T{ show = true, color = { 0.36, 1.00, 0.50, 1.00 } },
        mp_recovery        = T{ show = true, color = { 0.36, 0.72, 1.00, 1.00 } },
        resting            = T{ show = true, color = { 0.55, 0.92, 0.78, 1.00 } },
        regen_ticks        = T{ show = true, color = { 0.62, 0.86, 0.56, 1.00 } },
        refresh_ticks      = T{ show = true, color = { 0.52, 0.70, 0.95, 1.00 } },
        drain_aspir        = T{ show = true, color = { 0.56, 0.90, 0.86, 1.00 } },
        buffs              = T{ show = true, color = { 0.52, 0.82, 1.00, 1.00 } },
        status_positive    = T{ show = true, color = { 0.46, 0.92, 0.64, 1.00 } },
        status_negative    = T{ show = true, color = { 1.00, 0.48, 0.58, 1.00 } },
        status_removed     = T{ show = true, color = { 0.72, 0.82, 0.92, 1.00 } },
        incoming_damage    = T{ show = true, color = { 1.00, 0.36, 0.36, 1.00 } },
        incoming_abilities = T{ show = true, color = { 0.72, 0.58, 1.00, 1.00 } },
        defenses           = T{ show = true, color = { 0.68, 0.84, 1.00, 1.00 } },
        ko                 = T{ show = true, color = { 1.00, 0.30, 0.30, 1.00 } },
        exp                = T{ show = true, color = { 0.72, 0.56, 1.00, 1.00 } },
        gil                = T{ show = true, color = { 1.00, 0.84, 0.28, 1.00 } },
        level_up           = T{ show = true, color = { 1.00, 0.90, 0.34, 1.00 } },
        skill_ups          = T{ show = true, color = { 0.48, 0.94, 0.84, 1.00 } },
        item_drops         = T{ show = true, color = { 0.86, 0.78, 0.52, 1.00 } },
        wear_warning       = T{ show = true, color = { 1.00, 0.76, 0.40, 1.00 } },
        item_obtained      = T{ show = true, color = { 0.98, 0.90, 0.62, 1.00 } },
        zone_change        = T{ show = true, color = { 0.72, 0.84, 1.00, 1.00 } },
        low_hp             = T{ show = true, color = { 1.00, 0.26, 0.26, 1.00 } },
        food_warning       = T{ show = true, color = { 1.00, 0.66, 0.30, 1.00 } },
    },

    -- 1.4.0: the History window (last events of each lane).
    history = T{
        enabled = true,          -- keep the history
        size = 50,               -- events kept per lane
        show_time = true,        -- time of day in front of each line
        newest_first = true,
        opacity = 0.92,
        notify_height = 0.28,    -- share of the window the top (Notifications) part uses
        font_scale = 1.0,        -- 1.4.1: text size of the lines (title bar keeps its size)
        x = -1, y = -1, w = 820, h = 560,
        visible = false,
    },
    -- 1.4.0: font of SCL's windows (config, session, history). The floating
    -- combat text keeps its own font (Font Style).
    ui_font = T{},

    -- Legacy colors are retained so older saved settings migrate cleanly.
    colors = T{
        outgoing = { 1.00, 0.88, 0.32, 1.00 },
        incoming = { 1.00, 0.36, 0.36, 1.00 },
        heal     = { 0.36, 1.00, 0.50, 1.00 },
        xp       = { 0.72, 0.56, 1.00, 1.00 },
        gil      = { 1.00, 0.84, 0.28, 1.00 },
        miss     = { 0.72, 0.76, 0.84, 1.00 },
        ability  = { 0.50, 0.82, 1.00, 1.00 },
        critical = { 1.00, 0.48, 0.18, 1.00 },
    },
};

-- The active per-character settings table. Ashita can replace it after login
-- or a character switch (see set_settings), so every module reads settings
-- through the proxy below instead of holding the table directly.
local settings_table = ashita_settings.load(defaults);

local settings = setmetatable({}, {
    __index = function(_, key) return settings_table[key]; end,
    __newindex = function(_, key, value) settings_table[key] = value; end,
});

local function ensure_event_option(key)
    if not settings.event_options then
        settings.event_options = T{};
    end

    if not settings.event_options[key] then
        settings.event_options[key] = T{};
    end

    local dst = settings.event_options[key];
    local src = defaults.event_options[key];

    if dst.show == nil then
        dst.show = src.show;
    end

    if not dst.color then
        dst.color = { src.color[1], src.color[2], src.color[3], src.color[4] };
    end
end


-- Settings added in 1.2.0. Filled in for older saved settings.
local function fill_new_defaults()
    local function fill(dst_key, src)
        if type(settings[dst_key]) ~= 'table' then
            settings[dst_key] = T{};
        end
        for k, v in pairs(src) do
            if settings[dst_key][k] == nil then
                settings[dst_key][k] = v;
            end
        end
    end

    fill('notification', defaults.notification);
    fill('notify', defaults.notify);
    fill('session_window', defaults.session_window);
    fill('history', defaults.history);
    if type(settings.ui_font) ~= 'table' then settings.ui_font = T{}; end

    for _, lane in ipairs({ 'outgoing', 'incoming' }) do
        if type(settings[lane]) == 'table' and settings[lane].motion == nil then
            settings[lane].motion = 'scroll';
        end
    end

    for _, key in ipairs({ 'notify_scale', 'big_hit_threshold', 'crit_pop', 'element_colors', 'combine_aoe', 'session_font_scale', 'session_items_side', 'regen_ticks_always', 'low_hp_percent' }) do
        if settings[key] == nil then
            settings[key] = defaults[key];
        end
    end
end

for _, key in ipairs({
    'melee_damage', 'ranged_damage', 'criticals', 'weapon_skills', 'spells',
    'magic_bursts', 'skillchains', 'outgoing_abilities', 'pet_damage',
    'additional_effects', 'counters', 'healing_received', 'mp_recovery', 'resting', 'regen_ticks', 'refresh_ticks',
    'drain_aspir', 'buffs', 'status_positive', 'status_negative',
    'status_removed', 'incoming_damage', 'incoming_abilities', 'defenses',
    'ko', 'exp', 'gil', 'level_up', 'skill_ups', 'item_drops', 'item_obtained',
    'zone_change', 'wear_warning', 'low_hp', 'food_warning'
}) do
    ensure_event_option(key);
end

if settings.melee_scale == nil then settings.melee_scale = defaults.melee_scale; end
if settings.ability_scale == nil then settings.ability_scale = defaults.ability_scale; end
if settings.heal_scale == nil then settings.heal_scale = defaults.heal_scale; end
if settings.reward_scale == nil then settings.reward_scale = defaults.reward_scale; end
if settings.show_symbols == nil then settings.show_symbols = defaults.show_symbols; end
if settings.locked == nil then settings.locked = defaults.locked; end
if settings.renderer_mode == nil then settings.renderer_mode = defaults.renderer_mode; end
if settings.ui_theme == nil then settings.ui_theme = defaults.ui_theme; end
if settings.font_family == nil then settings.font_family = defaults.font_family; end
if settings.font_bold == nil then settings.font_bold = defaults.font_bold; end
if settings.font_italic == nil then settings.font_italic = defaults.font_italic; end
if settings.font_outline == nil then settings.font_outline = defaults.font_outline; end
-- 1.2.7: the Outline checkbox became the Text Effect setting.
if settings.text_effect == nil then settings.text_effect = (settings.font_outline == true) and 'outline' or 'none'; end
for _, fx_key in ipairs({ 'effect_color', 'effect_opacity', 'shadow_offset', 'text_plate', 'plate_opacity', 'plate_rounding', 'text_opacity', 'all_caps' }) do
    if settings[fx_key] == nil then settings[fx_key] = defaults[fx_key]; end
end
if settings.show_target_names == nil then settings.show_target_names = defaults.show_target_names; end
if settings.show_source_names == nil then settings.show_source_names = defaults.show_source_names; end
if settings.show_zero_damage == nil then settings.show_zero_damage = defaults.show_zero_damage; end
if settings.show_misses == nil then settings.show_misses = defaults.show_misses; end
if settings.combine_repeated_hits == nil then settings.combine_repeated_hits = defaults.combine_repeated_hits; end
if settings.combine_window == nil then settings.combine_window = defaults.combine_window; end
if settings.max_visible_events == nil then settings.max_visible_events = defaults.max_visible_events; end
if settings.config_window == nil then settings.config_window = T{}; end
if settings.config_window.x == nil then settings.config_window.x = defaults.config_window.x; end
if settings.config_window.y == nil then settings.config_window.y = defaults.config_window.y; end
if settings.config_window.w == nil then settings.config_window.w = defaults.config_window.w; end
if settings.config_window.h == nil then settings.config_window.h = defaults.config_window.h; end

if settings.config_tools_window == nil then settings.config_tools_window = T{}; end
if settings.config_tools_window.x == nil then settings.config_tools_window.x = defaults.config_tools_window.x; end
if settings.config_tools_window.y == nil then settings.config_tools_window.y = defaults.config_tools_window.y; end
if settings.config_tools_window.w == nil then settings.config_tools_window.w = defaults.config_tools_window.w; end
if settings.config_tools_window.h == nil then settings.config_tools_window.h = defaults.config_tools_window.h; end
fill_new_defaults();


local function normalize_loaded_settings()
    for _, key in ipairs({
        'melee_damage', 'ranged_damage', 'criticals', 'weapon_skills', 'spells',
        'magic_bursts', 'skillchains', 'outgoing_abilities', 'pet_damage',
        'additional_effects', 'counters', 'healing_received', 'mp_recovery', 'resting', 'regen_ticks', 'refresh_ticks',
        'drain_aspir', 'buffs', 'status_positive', 'status_negative',
        'status_removed', 'incoming_damage', 'incoming_abilities', 'defenses',
        'ko', 'exp', 'gil', 'level_up', 'skill_ups', 'item_drops', 'item_obtained',
        'zone_change', 'wear_warning', 'low_hp', 'food_warning'
    }) do
        ensure_event_option(key);
    end

    if settings.melee_scale == nil then settings.melee_scale = defaults.melee_scale; end
    if settings.ability_scale == nil then settings.ability_scale = defaults.ability_scale; end
    if settings.heal_scale == nil then settings.heal_scale = defaults.heal_scale; end
    if settings.reward_scale == nil then settings.reward_scale = defaults.reward_scale; end
    if settings.show_symbols == nil then settings.show_symbols = defaults.show_symbols; end
    if settings.locked == nil then settings.locked = defaults.locked; end
    if settings.renderer_mode == nil then settings.renderer_mode = defaults.renderer_mode; end
    if settings.ui_theme == nil then settings.ui_theme = defaults.ui_theme; end
    if settings.font_family == nil then settings.font_family = defaults.font_family; end
    if settings.font_bold == nil then settings.font_bold = defaults.font_bold; end
    if settings.font_italic == nil then settings.font_italic = defaults.font_italic; end
    if settings.font_outline == nil then settings.font_outline = defaults.font_outline; end
    if settings.text_effect == nil then settings.text_effect = (settings.font_outline == true) and 'outline' or 'none'; end
    for _, fx_key in ipairs({ 'effect_color', 'effect_opacity', 'shadow_offset', 'text_plate', 'plate_opacity', 'plate_rounding', 'text_opacity', 'all_caps' }) do
        if settings[fx_key] == nil then settings[fx_key] = defaults[fx_key]; end
    end
    if settings.show_target_names == nil then settings.show_target_names = defaults.show_target_names; end
    if settings.show_source_names == nil then settings.show_source_names = defaults.show_source_names; end
    if settings.show_zero_damage == nil then settings.show_zero_damage = defaults.show_zero_damage; end
    if settings.show_misses == nil then settings.show_misses = defaults.show_misses; end
    if settings.combine_repeated_hits == nil then settings.combine_repeated_hits = defaults.combine_repeated_hits; end
    if settings.combine_window == nil then settings.combine_window = defaults.combine_window; end
    if settings.max_visible_events == nil then settings.max_visible_events = defaults.max_visible_events; end

    if settings.config_window == nil then settings.config_window = T{}; end
    if settings.config_window.x == nil then settings.config_window.x = defaults.config_window.x; end
    if settings.config_window.y == nil then settings.config_window.y = defaults.config_window.y; end
    if settings.config_window.w == nil then settings.config_window.w = defaults.config_window.w; end
    if settings.config_window.h == nil then settings.config_window.h = defaults.config_window.h; end

    if settings.config_tools_window == nil then settings.config_tools_window = T{}; end
    if settings.config_tools_window.x == nil then settings.config_tools_window.x = defaults.config_tools_window.x; end
    if settings.config_tools_window.y == nil then settings.config_tools_window.y = defaults.config_tools_window.y; end
    if settings.config_tools_window.w == nil then settings.config_tools_window.w = defaults.config_tools_window.w; end
    if settings.config_tools_window.h == nil then settings.config_tools_window.h = defaults.config_tools_window.h; end
    fill_new_defaults();
end


local state = {
    events = {},
    next_id = 1,
    config_open = { false },
    move_mode = false,
    confirm_reset_all = false,
    config_size_initialized = false,
    move_initialized = {
        incoming = false,
        outgoing = false,
        notification = false,
    },

    -- Session summary window.
    session_open = { false },
    session_geometry_initialized = false,

    -- /scl debug: log unmapped action messages to a file.
    debug = false,
    last_kill_time = 0,
    progression_seen = {},
    xp_watch = {
        initialized = false,
        suspended_until = 0,
        current = nil,
        needed = nil,
        last_check = 0,
    },

    -- Reusable FontManager object pools. Creating/destroying fonts during
    -- combat is expensive and caused a frame hitch on every new event.
    font_pool = {},
    font_pool_size = 0,
    font_styles = {},       -- style key -> { objs = { {main, shadow} }, used }
    fonts_visible_last = false,
    font_generation = 1,

    -- Dedicated FontManager objects used only by the Config Live Preview.
    -- Keeping these separate prevents preview rendering from stealing or
    -- reconfiguring active combat-text font objects.
    preview_font_pool = {},

    me_cached = nil,

    -- Combat feature state.
    sata = { sneak = false, trick = false },
    combine = {},

    config_geometry = {
        main_initialized = false,
        tools_initialized = false,
        last_main = nil,
        last_tools = nil,
        last_save_clock = 0,
    },

    skillup_packet_at = {},

    -- Status name (lowercase) -> time a 0x029 wear-off packet reported it.
    status_removed_at = {},

    -- EXP-type reward sources: packet first, chat text / memory as fallback.
    exp_tracking = {
        last_packet = -100,
        last_text = -100,
        pending = nil,
    },

    -- Selected Config tab (session only).
    config_tab = 1,

    -- Zone banner waiting for the zone to finish loading.
    pending_zone = nil,

    -- Width the live preview needs (measured last frame).
    preview_needed_w = 0,
};

local MAX_EVENTS = 80;

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function strip_control_codes(s)
    if not s then return '' end
    s = s:gsub('[\x1E\x1F\x7F].', '');
    s = s:gsub('[\x00-\x1D\x7F]', '');
    s = s:gsub('  +', ' ');
    s = s:gsub('^%s+', ''):gsub('%s+$', '');
    return s;
end

local function normalize_line(s)
    if not s or s == '' then return '' end
    s = s:gsub('^%b[]%s*', '');
    s = s:gsub('^%b[]%s*', '');
    s = s:gsub('  +', ' ');
    s = s:gsub('^%s+', ''):gsub('%s+$', '');
    return s;
end

-- Local player name, read from party slot 0 (always the local player).
local function read_player_name()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then return nil end

    local party = mm:GetParty();
    if not party then return nil end

    local ok, name = pcall(function()
        return party:GetMemberName(0);
    end);

    if ok and type(name) == 'string' and name ~= '' then
        return name;
    end
    return nil;
end

local function safe_me()
    local name = read_player_name();
    if name and name ~= '' then
        state.me_cached = name;
        return name;
    end
    return state.me_cached;
end

-- True when a chat line is about the local player: it either starts with the
-- player's name ("Izumi gains ...", "Izumi's Protect effect wears off") or is
-- written in the first person ("You ...").
local function line_is_about_me(line, me)
    if not line or line == '' or not me or me == '' then
        return false;
    end

    local lower = line:lower();
    local me_lower = me:lower();

    if lower:sub(1, #me_lower) == me_lower then
        local next_char = lower:sub(#me_lower + 1, #me_lower + 1);
        return next_char == '' or next_char == ' ' or next_char == "'";
    end

    return lower:sub(1, 4) == 'you ' or lower:sub(1, 5) == "your ";
end

-- Forward declaration:
-- cycle_font_family() is defined before the FontManager pool implementation.
-- Declaring the local here ensures the function closes over the correct local

local function save_settings()
    ashita_settings.save();
end

local function copy_defaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == 'table' then
            if type(dst[k]) ~= 'table' then
                dst[k] = T{};
            end
            copy_defaults(dst[k], v);
        else
            dst[k] = v;
        end
    end
end

-- Called by Ashita's settings_update callback.
local function set_settings(s)
    if s == nil then return; end
    settings_table = s;
    normalize_loaded_settings();
end

return {
    defaults = defaults,
    settings = settings,
    state = state,
    MAX_EVENTS = MAX_EVENTS,
    clamp = clamp,
    strip_control_codes = strip_control_codes,
    normalize_line = normalize_line,
    read_player_name = read_player_name,
    safe_me = safe_me,
    line_is_about_me = line_is_about_me,
    save_settings = save_settings,
    copy_defaults = copy_defaults,
    ensure_event_option = ensure_event_option,
    normalize_loaded_settings = normalize_loaded_settings,
    set_settings = set_settings,
};
