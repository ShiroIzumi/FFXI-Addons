addon.name    = 'scrollingcombatlog';
addon.author  = 'Izumi (ShiroIzumi)';
addon.version = '1.0.10';
addon.desc    = 'Self-only packet-driven Ashita v4 scrolling combat text inspired by MSBT.';
addon.link    = '';

require('common');

local imgui           = require('imgui');
local helpers         = require('helpers');
local ashita_settings = require('settings');
local fonts           = require('fonts');

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

    font_family = 'Consolas',
    font_bold = false,
    font_italic = false,
    font_outline = false,

    outgoing = T{ x = 1180.0, y = 620.0, orientation = 'right', growth = 'up' },
    incoming = T{ x = 580.0, y = 620.0, orientation = 'right', growth = 'up' },

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
    },

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

local settings = ashita_settings.load(defaults);

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

for _, key in ipairs({
    'melee_damage', 'ranged_damage', 'criticals', 'weapon_skills', 'spells',
    'magic_bursts', 'skillchains', 'outgoing_abilities', 'pet_damage',
    'additional_effects', 'counters', 'healing_received', 'mp_recovery',
    'drain_aspir', 'buffs', 'status_positive', 'status_negative',
    'status_removed', 'incoming_damage', 'incoming_abilities', 'defenses',
    'ko', 'exp', 'gil', 'level_up', 'skill_ups', 'item_drops'
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
if settings.font_family == nil then settings.font_family = defaults.font_family; end
if settings.font_bold == nil then settings.font_bold = defaults.font_bold; end
if settings.font_italic == nil then settings.font_italic = defaults.font_italic; end
if settings.font_outline == nil then settings.font_outline = defaults.font_outline; end
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


local function normalize_loaded_settings()
    for _, key in ipairs({
        'melee_damage', 'ranged_damage', 'criticals', 'weapon_skills', 'spells',
        'magic_bursts', 'skillchains', 'outgoing_abilities', 'pet_damage',
        'additional_effects', 'counters', 'healing_received', 'mp_recovery',
        'drain_aspir', 'buffs', 'status_positive', 'status_negative',
        'status_removed', 'incoming_damage', 'incoming_abilities', 'defenses',
        'ko', 'exp', 'gil', 'level_up', 'skill_ups', 'item_drops'
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
    if settings.font_family == nil then settings.font_family = defaults.font_family; end
    if settings.font_bold == nil then settings.font_bold = defaults.font_bold; end
    if settings.font_italic == nil then settings.font_italic = defaults.font_italic; end
    if settings.font_outline == nil then settings.font_outline = defaults.font_outline; end
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
    },
    last_kill_time = 0,
    progression_seen = {},
    xp_watch = {
        initialized = false,
        current = nil,
        needed = nil,
        last_check = 0,
    },

    -- Reusable FontManager object pools. Creating/destroying fonts during
    -- combat is expensive and caused a frame hitch on every new event.
    font_pool = {},
    font_pool_size = 0,
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
};

local MAX_EVENTS = 80;

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function strip_control_codes(s)
    if not s then return '' end
    s = s:gsub('[\x1E\x1F].', '');
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

local function safe_me()
    local name = helpers.safe_player_name();
    if name and name ~= '' then
        state.me_cached = name;
        return name;
    end
    return state.me_cached;
end

local function infer_me(line)
    if not line or line == '' then return nil end
    local name = line:match("^([%w%'%-_]+)%s+hits?%f[%W]");
    if name then return name end
    name = line:match("^([%w%'%-_]+)%s+misses%f[%W]");
    if name then return name end
    name = line:match("^([%w%'%-_]+)%s+casts?%f[%W]");
    if name then return name end
    name = line:match("^([%w%'%-_]+)%s+uses?%f[%W]");
    if name then return name end
    name = line:match("^([%w%'%-_]+)%s+readies%f[%W]");
    return name;
end

local function is_combat_line(line)
    if not line or line == '' then return false end
    local l = line:lower();
    local terms = {
        ' hits ', ' hit ', ' misses ', ' missed ',
        ' takes ', ' damage', ' recovers ', ' hp',
        ' casts ', ' starts casting ', ' readies ', ' uses ',
        ' critical', ' parries', ' evades', ' dodges',
        ' defeats ', ' is defeated', ' absorbs ',
    };
    for _, term in ipairs(terms) do
        if l:find(term, 1, true) then return true end
    end
    return false;
end

local function classify(line, me)
    local lower = line:lower();
    local me_lower = me and me:lower() or nil;

    if lower:find(' recovers ', 1, true) or lower:find(' hp', 1, true) then
        if me_lower and lower:find(me_lower, 1, true) then
            return 'incoming', 'heal';
        end
        return 'outgoing', 'heal';
    end

    if lower:find('miss', 1, true) or lower:find('evad', 1, true)
        or lower:find('parr', 1, true) or lower:find('dodg', 1, true) then
        if me_lower and lower:find(me_lower, 1, true)
            and not lower:find('^' .. me_lower) then
            return 'incoming', 'miss';
        end
        return 'outgoing', 'miss';
    end

    if lower:find('casts ', 1, true) or lower:find('casting ', 1, true)
        or lower:find('readies ', 1, true) or lower:find('uses ', 1, true) then
        if me_lower and lower:find(me_lower, 1, true)
            and not lower:find('^' .. me_lower) then
            return 'incoming', 'ability';
        end
        return 'outgoing', 'ability';
    end

    if me_lower then
        if lower:find('^' .. me_lower) then
            return 'outgoing', lower:find('critical', 1, true) and 'critical' or 'outgoing';
        end
        if lower:find(me_lower, 1, true) then
            return 'incoming', lower:find('critical', 1, true) and 'critical' or 'incoming';
        end
    end

    return 'outgoing', lower:find('critical', 1, true) and 'critical' or 'outgoing';
end

local function simplify_text(line, me)
    local src, target, dmg = line:match("^([%w%'%-_]+)%s+hits%s+(.+)%s+for%s+(%d+)%s+points? of damage%.?$");
    if src and target and dmg then
        if me and src:lower() == me:lower() then
            return dmg .. '  ->  ' .. target;
        end
        if me and target:lower() == me:lower() then
            return '-' .. dmg .. '  <-  ' .. src;
        end
        return dmg .. '  ' .. src .. ' -> ' .. target;
    end

    src, dmg, target = line:match("^([%w%'%-_]+)%s+(%d+)%s+hit%s*[%-%>]+%s*(.+)$");
    if src and dmg and target then
        if me and src:lower() == me:lower() then
            return dmg .. '  ->  ' .. target;
        end
        return dmg .. '  ' .. src .. ' -> ' .. target;
    end

    src, target = line:match("^([%w%'%-_]+)%s+misses%s+(.+)%.?$");
    if src and target then
        if me and src:lower() == me:lower() then
            return 'MISS  ->  ' .. target;
        elseif me and target:lower() == me:lower() then
            return 'MISS  <-  ' .. src;
        end
    end

    local who, hp = line:match("^(.+)%s+recovers%s+(%d+)%s+HP%.?$");
    if who and hp then
        return '+' .. hp .. ' HP';
    end

    local actor, action = line:match("^(.+)%s+readies%s+(.+)%.?$");
    if actor and action then return action .. '  READY' end

    actor, action = line:match("^(.+)%s+starts? casting%s+(.+)%.?$");
    if actor and action then return action .. '  CAST' end

    actor, action = line:match("^(.+)%s+uses%s+(.+)%.?$");
    if actor and action then return action end

    return line;
end

-- Forward declaration:
-- cycle_font_family() is defined before the FontManager pool implementation.
-- Declaring the local here ensures the function closes over the correct local
-- instead of resolving rebuild_font_pool as a missing global.
local rebuild_font_pool;

local FONT_FAMILIES = T{
    'Consolas',
    'Segoe UI',
    'Arial',
    'Tahoma',
    'Verdana',
    'Trebuchet MS',
    'Courier New',
};

local function rgba_to_argb(color, alpha_mul)
    local r = math.floor(clamp((tonumber(color[1]) or 1.0), 0.0, 1.0) * 255);
    local g = math.floor(clamp((tonumber(color[2]) or 1.0), 0.0, 1.0) * 255);
    local b = math.floor(clamp((tonumber(color[3]) or 1.0), 0.0, 1.0) * 255);
    local a = math.floor(clamp((tonumber(color[4]) or 1.0) * (alpha_mul or 1.0), 0.0, 1.0) * 255);

    return bit.bor(
        bit.lshift(a, 24),
        bit.lshift(r, 16),
        bit.lshift(g, 8),
        b
    );
end

local function cycle_font_family(direction)
    local current = tostring(settings.font_family or 'Consolas');
    local index = 1;

    for i, family in ipairs(FONT_FAMILIES) do
        if family == current then
            index = i;
            break;
        end
    end

    index = index + direction;
    if index < 1 then index = #FONT_FAMILIES; end
    if index > #FONT_FAMILIES then index = 1; end

    settings.font_family = FONT_FAMILIES[index];
    ashita_settings.save();
    rebuild_font_pool();
end

local function default_event_type(direction, kind)
    if kind == 'critical' then return 'criticals'; end
    if kind == 'heal' then return 'healing_received'; end
    if kind == 'xp' then return 'exp'; end
    if kind == 'gil' then return 'gil'; end
    if direction == 'incoming' then return 'incoming_damage'; end
    return 'melee_damage';
end

local function get_event_option(event_type)
    if settings.event_options and settings.event_options[event_type] then
        return settings.event_options[event_type];
    end
    return nil;
end

local function event_visible(event_type)
    local opt = get_event_option(event_type);
    return not opt or opt.show ~= false;
end

local function event_color(ev)
    local opt = get_event_option(ev.event_type);
    if opt and opt.color then
        return opt.color;
    end

    -- Legacy fallback.
    if ev.kind == 'heal' then return settings.colors.heal; end
    if ev.kind == 'xp' then return settings.colors.xp; end
    if ev.kind == 'gil' then return settings.colors.gil; end
    if ev.kind == 'miss' then return settings.colors.miss; end
    if ev.kind == 'ability' then return settings.colors.ability; end
    if ev.kind == 'critical' then return settings.colors.critical; end
    if ev.direction == 'incoming' then return settings.colors.incoming; end
    return settings.colors.outgoing;
end

local function event_symbol(ev)
    if settings.show_symbols ~= true then
        return '';
    end

    if ev.event_type == 'criticals' then return '* '; end
    if ev.event_type == 'ranged_damage' then return '[R] '; end
    if ev.event_type == 'weapon_skills' then return '[WS] '; end
    if ev.event_type == 'spells' then return '[SP] '; end
    if ev.event_type == 'magic_bursts' then return '[SP] '; end
    if ev.event_type == 'skillchains' then return '[SC] '; end
    if ev.event_type == 'outgoing_abilities' then return '[JA] '; end
    if ev.event_type == 'pet_damage' then return '[PET] '; end
    if ev.event_type == 'additional_effects' then return '[+] '; end
    if ev.event_type == 'counters' then return '[COUNTER] '; end
    if ev.event_type == 'healing_received' then return '+ '; end
    if ev.event_type == 'mp_recovery' then return '[MP] '; end
    if ev.event_type == 'drain_aspir' then return '[DRAIN] '; end
    if ev.event_type == 'buffs' then return '[+] '; end
    if ev.event_type == 'status_positive' then return '[+] '; end
    if ev.event_type == 'status_negative' then return '[!] '; end
    if ev.event_type == 'status_removed' then return '[-] '; end
    if ev.event_type == 'incoming_damage' then return '- '; end
    if ev.event_type == 'incoming_abilities' then return '[!] '; end
    if ev.event_type == 'defenses' then return '[DEF] '; end
    if ev.event_type == 'ko' then return '[KO] '; end
    if ev.event_type == 'exp' then return '[XP] '; end
    if ev.event_type == 'gil' then return '$ '; end
    if ev.event_type == 'level_up' then return '[LEVEL] '; end
    if ev.event_type == 'skill_ups' then return '[SKILL] '; end
    if ev.event_type == 'item_drops' then return '[DROP] '; end
    return '';
end

local function rendered_event_text(ev)
    return event_symbol(ev) .. tostring(ev.text or '');
end

local function event_scale(ev, age)
    local global_scale = tonumber(settings.font_scale) or 1.35;
    local mult = tonumber(settings.melee_scale) or 1.00;

    if ev.event_type == 'criticals' then
        -- Criticals intentionally use the exact same font size as normal melee.
        -- They are distinguished by the leading * symbol and their own color.
        mult = tonumber(settings.melee_scale) or 1.00;

    elseif ev.event_type == 'weapon_skills'
        or ev.event_type == 'spells'
        or ev.event_type == 'magic_bursts'
        or ev.event_type == 'skillchains'
        or ev.event_type == 'outgoing_abilities'
        or ev.event_type == 'pet_damage'
        or ev.event_type == 'additional_effects'
        or ev.event_type == 'counters'
        or ev.event_type == 'buffs'
        or ev.event_type == 'status_positive'
        or ev.event_type == 'status_negative'
        or ev.event_type == 'status_removed'
        or ev.event_type == 'incoming_abilities'
        or ev.event_type == 'defenses'
        or ev.event_type == 'ko' then
        mult = tonumber(settings.ability_scale) or 1.00;

    elseif ev.event_type == 'healing_received'
        or ev.event_type == 'mp_recovery'
        or ev.event_type == 'drain_aspir' then
        mult = tonumber(settings.heal_scale) or 1.00;

    elseif ev.event_type == 'exp'
        or ev.event_type == 'gil'
        or ev.event_type == 'level_up'
        or ev.event_type == 'skill_ups'
        or ev.event_type == 'item_drops' then
        mult = tonumber(settings.reward_scale) or 1.00;
    end

    return global_scale * mult;
end

local recent_events = {};

local function should_suppress_event(direction, kind, value)
    if value == nil or value == '' then
        return true;
    end

    local lower = tostring(value):lower();

    -- Never display Lua userdata / debug-like garbage.
    if lower:find('userdata:', 1, true) or lower:find('0x', 1, true) then
        return true;
    end

    -- Progression rewards often repeat exactly from kill to kill.
    -- Never use the normal combat-event debounce for EXP/gil.
    if kind == 'xp' or kind == 'gil' then
        return false;
    end

    -- Short debounce for the same rendered combat event.
    local key = direction .. '|' .. kind .. '|' .. tostring(value);
    local now = os.clock();
    local last = recent_events[key];

    recent_events[key] = now;

    if last and (now - last) < 0.20 then
        return true;
    end

    -- Opportunistic cleanup.
    for k, ts in pairs(recent_events) do
        if (now - ts) > 2.0 then
            recent_events[k] = nil;
        end
    end

    return false;
end

local function add_event(direction, kind, text, event_type)
    if state.paused or not settings.enabled then return end

    event_type = event_type or default_event_type(direction, kind);
    if not event_visible(event_type) then return end
    if should_suppress_event(direction, kind, text) then return end

    state.events[#state.events + 1] = {
        id = state.next_id,
        direction = direction,
        kind = kind,
        event_type = event_type,
        text = text,
        created = os.clock(),
    };
    state.next_id = state.next_id + 1;
    local cap = math.floor(clamp(tonumber(settings.max_visible_events) or 14, 4, MAX_EVENTS));
    while #state.events > cap do
        table.remove(state.events, 1);
    end
end


local function add_progression_event(kind, value)
    if not value or value == '' then
        return;
    end

    -- Packet 0x02D and Horizon's text line can both report the same reward.
    -- Only suppress an identical reward during the same wall-clock second.
    -- This still allows identical EXP/gil amounts from later kills.
    local key = kind .. '|' .. tostring(value);
    local now = os.time();
    local last = state.progression_seen[key];

    if last == now then
        return;
    end

    state.progression_seen[key] = now;

    for k, stamp in pairs(state.progression_seen) do
        if (now - stamp) > 3 then
            state.progression_seen[k] = nil;
        end
    end

    add_event('incoming', kind, value, kind == 'gil' and 'gil' or 'exp');
end


local safe_resource_name;

local function target_suffix(name)
    if settings.show_target_names == false then
        return '';
    end
    return '  ->  ' .. tostring(name or 'Unknown');
end

local function source_suffix(name)
    if settings.show_source_names == false then
        return '';
    end
    return '  <-  ' .. tostring(name or 'Unknown');
end

local function add_combat_number(direction, kind, amount, other_name, event_type, prefix, combine_key)
    amount = tonumber(amount) or 0;
    if amount == 0 and settings.show_zero_damage ~= true then
        return;
    end

    local text_value = (prefix or '') .. tostring(amount);
    if direction == 'incoming' then
        text_value = text_value .. source_suffix(other_name);
    else
        text_value = text_value .. target_suffix(other_name);
    end

    if settings.combine_repeated_hits == true and combine_key and amount > 0 then
        local now = os.clock();
        local key = direction .. '|' .. tostring(event_type) .. '|' .. tostring(combine_key);
        local slot = state.combine[key];
        local window = clamp(tonumber(settings.combine_window) or 0.22, 0.08, 0.60);

        if slot and (now - slot.time) <= window and slot.event then
            local still_active = false;
            for _, active_event in ipairs(state.events) do
                if active_event == slot.event then
                    still_active = true;
                    break;
                end
            end

            if still_active then
                slot.total = slot.total + amount;
                slot.hits = slot.hits + 1;
                slot.time = now;
                slot.event.created = now;

                local combined = (prefix or '') .. tostring(slot.total) .. ' (' .. tostring(slot.hits) .. ' hits)';
                if direction == 'incoming' then
                    slot.event.text = combined .. source_suffix(other_name);
                else
                    slot.event.text = combined .. target_suffix(other_name);
                end
                return;
            end

            state.combine[key] = nil;
        end

        add_event(direction, kind, text_value, event_type);
        local ev = state.events[#state.events];
        if ev then
            state.combine[key] = {
                event = ev,
                total = amount,
                hits = 1,
                time = now,
            };
        end
        return;
    end

    add_event(direction, kind, text_value, event_type);
end

local function is_magic_burst_message(message)
    message = tonumber(message) or -1;
    return message == 252 or message == 265 or message == 268
        or message == 269 or message == 271 or message == 272
        or message == 274 or message == 275 or message == 379
        or message == 650;
end

local SKILLCHAIN_NAMES = T{
    [1] = 'Light',
    [2] = 'Darkness',
    [3] = 'Gravitation',
    [4] = 'Fragmentation',
    [5] = 'Distortion',
    [6] = 'Fusion',
    [7] = 'Compression',
    [8] = 'Liquefaction',
    [9] = 'Induration',
    [10] = 'Reverberation',
    [11] = 'Transfixion',
    [12] = 'Scission',
    [13] = 'Detonation',
    [14] = 'Impaction',
};

local ADDITIONAL_NAMES = T{
    [1] = 'Fire',
    [2] = 'Blizzard',
    [3] = 'Aero',
    [4] = 'Stone',
    [5] = 'Thunder',
    [6] = 'Water',
    [7] = 'Light',
    [8] = 'Dark',
    [12] = 'Blind',
    [14] = 'Petrify',
    [21] = 'Drain',
    [22] = 'Aspir',
    [23] = 'Haste',
};

local function likely_beneficial_status(name)
    local n = tostring(name or ''):lower();
    if n == '' then return false end
    local prefixes = {
        'protect', 'shell', 'haste', 'refresh', 'regen', 'stoneskin',
        'phalanx', 'blink', 'aquaveil', 'reraise', 'sneak', 'invisible',
        'bar', 'boost', 'gain', 'enfire', 'enblizzard', 'enaero',
        'enstone', 'enthunder', 'enwater', 'enlight', 'endark',
    };
    for _, p in ipairs(prefixes) do
        if n:sub(1, #p) == p then
            return true;
        end
    end
    return false;
end

local function resist_suffix(action)
    if not action then return '' end
    local message = tonumber(action.message) or -1;
    local amount = tonumber(action.param) or 0;

    -- Full resist / no effect families.
    if amount == 0 and (
        message == 85 or message == 284 or message == 653 or message == 654
        or message == 655 or message == 656 or message == 658 or message == 659
    ) then
        return '  [RESIST]';
    end

    -- FFXI does not expose a universal explicit 1/2, 1/4, 1/8 ratio in a
    -- single action field. Keep the label conservative instead of guessing.
    return '';
end

local function sata_suffix()
    local tags = {};
    if state.sata.sneak then tags[#tags + 1] = 'SA'; end
    if state.sata.trick then tags[#tags + 1] = 'TA'; end
    if #tags == 0 then return '' end
    return ' [' .. table.concat(tags, '+') .. ']';
end

local function consume_sata()
    state.sata.sneak = false;
    state.sata.trick = false;
end

local function defensive_result(action)
    if not action then return nil end
    local reaction = tonumber(action.reaction) or -1;
    local message = tonumber(action.message) or -1;

    if reaction == 11 or reaction == 2 then return 'PARRY' end
    if reaction == 12 then return 'BLOCK' end
    if reaction == 4 then return 'BLOCK/GUARD' end
    if reaction == 1 or message == 282 or message == 32 then return 'EVADE' end
    if message == 30 then return 'ANTICIPATE' end
    return nil;
end

local function safe_status_name(status_id)
    local rm = AshitaCore:GetResourceManager();
    if not rm then return nil end

    status_id = tonumber(status_id);
    if not status_id then return nil end

    -- Ashita v4 exposes status-effect names through the ResourceManager
    -- string tables. GetStatusById is not available/reliable on current v4
    -- builds, which caused valid effects to fall back to "Status #<id>".
    local ok, name = pcall(function()
        return rm:GetString('buffs.names', status_id);
    end);

    if ok and name ~= nil then
        name = tostring(name);
        if name ~= '' then
            return name;
        end
    end

    -- Secondary log-name table fallback for resources whose normal name is
    -- absent on a particular client/resource build.
    ok, name = pcall(function()
        return rm:GetString('buffs.names_log', status_id, 2);
    end);

    if ok and name ~= nil then
        name = tostring(name);
        if name ~= '' then
            return name;
        end
    end

    return nil;
end

local function emit_additional_effect(action, target_name, actor_is_me, actor_name)
    if not action or not action.additional then return end

    local add = action.additional;
    local animation = tonumber(add.animation) or 0;
    local amount = tonumber(add.param) or 0;

    if actor_is_me then
        if animation == 21 and amount > 0 then
            add_event('outgoing', 'ability',
                'Drain +' .. tostring(amount) .. ' HP' .. target_suffix(target_name),
                'drain_aspir');
        elseif animation == 22 and amount > 0 then
            add_event('outgoing', 'ability',
                'Aspir +' .. tostring(amount) .. ' MP' .. target_suffix(target_name),
                'drain_aspir');
        else
            local name = ADDITIONAL_NAMES[animation] or ('Effect #' .. tostring(animation));
            local suffix = amount > 0 and (' +' .. tostring(amount)) or '';
            add_event('outgoing', 'ability',
                name .. suffix .. target_suffix(target_name),
                'additional_effects');
        end
    end
end

local function emit_spike_effect(action, target_name, target_is_me, actor_name)
    if not action or not action.spikes then return end
    local msg = tonumber(action.spikes.message) or -1;
    local amount = tonumber(action.spikes.param) or 0;

    if msg == 14 or msg == 33 or msg == 606 or msg == 592 then
        if target_is_me then
            add_event('outgoing', 'ability',
                tostring(amount) .. target_suffix(actor_name),
                'counters');
        end
    elseif msg == 535 or msg == 536 then
        if target_is_me then
            add_event('outgoing', 'ability',
                'Retaliation ' .. tostring(amount) .. target_suffix(actor_name),
                'counters');
        end
    end
end

local function emit_skillchain(action, target_name)
    if not action or not action.additional then return end
    local animation = tonumber(action.additional.animation) or 0;
    local sc_name = SKILLCHAIN_NAMES[animation];
    if not sc_name then return end

    local amount = tonumber(action.additional.param) or 0;
    local text_value = sc_name;
    if amount > 0 then
        text_value = text_value .. '  ' .. tostring(amount);
    end
    text_value = text_value .. target_suffix(target_name);
    add_event('outgoing', 'ability', text_value, 'skillchains');
end

-- ============================================================================
-- Packet-driven live combat capture
-- ============================================================================
-- 0.6.0 corrects the 0x28 bit layout.  The previous parser treated TargetCount
-- as 10 bits and shifted every subsequent field, which is why real hits were
-- appearing as MISS and spell actions were not decoding.

local entity_name_cache = {};

-- FFXI action messages whose Param explicitly means HP recovered.
local HEAL_MESSAGES = T{
    [7] = true,
    [24] = true,
    [102] = true,
    [103] = true,
    [122] = true,
    [167] = true,
};

local DAMAGE_SPELL_MESSAGES = T{
    [2] = true,
    [227] = true,
    [252] = true,
    [265] = true,
    [274] = true,
    [379] = true,
    [747] = true,
    [748] = true,
};

local function action_is_heal(action)
    if not action then
        return false;
    end
    return HEAL_MESSAGES[tonumber(action.message) or -1] == true;
end


local function safe_player_server_id()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then
        return nil;
    end

    local party = mm:GetParty();
    if not party then
        return nil;
    end

    local server_id = party:GetMemberServerId(0);
    if not server_id or server_id == 0 then
        return nil;
    end

    return server_id;
end

local function safe_pet_server_id()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then return nil end

    local party = mm:GetParty();
    if not party then return nil end

    -- Ashita builds differ in pet helper availability. Probe safely.
    if party.GetMemberPetServerId ~= nil then
        local ok, pet_id = pcall(function()
            return party:GetMemberPetServerId(0);
        end);
        if ok and pet_id and pet_id ~= 0 then
            return pet_id;
        end
    end

    return nil;
end

local function safe_entity_name(server_id)
    if server_id == nil or server_id == 0 then
        return 'Unknown';
    end

    if entity_name_cache[server_id] then
        return entity_name_cache[server_id];
    end

    local mm = AshitaCore:GetMemoryManager();
    if not mm then
        return 'Unknown';
    end

    local entity_mgr = mm:GetEntity();
    if not entity_mgr then
        return 'Unknown';
    end

    if entity_mgr.GetServerId ~= nil and entity_mgr.GetName ~= nil then
        for index = 0, 2303 do
            local ok_id, entity_server_id = pcall(function()
                return entity_mgr:GetServerId(index);
            end);

            if ok_id and entity_server_id == server_id then
                local ok_name, name = pcall(function()
                    return entity_mgr:GetName(index);
                end);

                if ok_name and type(name) == 'string' and name ~= '' then
                    entity_name_cache[server_id] = name;
                    return name;
                end

                return 'Unknown';
            end
        end
    end

    return 'Unknown';
end

safe_resource_name = function(resource)
    if resource == nil then
        return nil;
    end

    -- Current Ashita v4 resources expose Name as an indexable object/userdata.
    -- This is the same access pattern already proven in BLUSpells.
    local ok, name = pcall(function()
        if resource.Name ~= nil then
            local n = resource.Name[1];
            if type(n) == 'string' and n ~= '' then
                return n;
            end

            n = resource.Name[0];
            if type(n) == 'string' and n ~= '' then
                return n;
            end
        end

        return nil;
    end);

    if ok and type(name) == 'string' and name ~= '' then
        return name;
    end

    return nil;
end;

local function safe_spell_name(spell_id)
    local rm = AshitaCore:GetResourceManager();
    if not rm or not spell_id then
        return nil;
    end

    local ok, resource = pcall(function()
        return rm:GetSpellById(spell_id);
    end);

    if not ok then
        return nil;
    end

    return safe_resource_name(resource);
end

local function safe_ability_name(ability_id)
    local rm = AshitaCore:GetResourceManager();
    if not rm or ability_id == nil then
        return nil;
    end

    local id = tonumber(ability_id);
    if not id then
        return nil;
    end

    local ok, resource = pcall(function()
        return rm:GetAbilityById(id);
    end);

    if not ok or not resource then
        return nil;
    end

    return safe_resource_name(resource);
end

local function safe_monster_ability_name(ability_id)
    local id = tonumber(ability_id);
    if not id then
        return nil;
    end

    local rm = AshitaCore:GetResourceManager();
    if not rm then
        return nil;
    end

    -- Monster skills are not normal player Ability resources.
    -- For monster skills, the action packet argument uses a +256 offset.
    -- Resolve through the dedicated monsters.abilities string table.
    if id >= 256 then
        local ok, name = pcall(function()
            return rm:GetString('monsters.abilities', id - 256);
        end);

        if ok and type(name) == 'string' and name ~= '' then
            return name;
        end
    end

    -- Some pet/trust skill cases can use an ordinary ability id.
    local name = safe_ability_name(id);
    if name and name ~= '' then
        return name;
    end

    return nil;
end

local function parse_action_packet(e)
    if not e or not e.data_raw then
        return nil;
    end

    local bit_data = e.data_raw;
    local bit_offset = 40;

    local function unpack_bits(length)
        local value = ashita.bits.unpack_be(bit_data, 0, bit_offset, length);
        bit_offset = bit_offset + length;
        return value;
    end

    local act = {
        actor_id = unpack_bits(32),
        targets = {},
    };

    -- Correct modern Ashita/FFXI 0x28 layout:
    -- target count = 6 bits, 4 unknown bits, category = 4 bits,
    -- action id/param = 17 bits, 15 unknown bits, recast = 32 bits.
    local target_count = unpack_bits(6);
    bit_offset = bit_offset + 4;

    act.category = unpack_bits(4);
    act.param = unpack_bits(17);

    bit_offset = bit_offset + 15;
    act.recast = unpack_bits(32);

    if not target_count or target_count < 0 or target_count > 32 then
        return nil;
    end

    for _ = 1, target_count do
        local target = {
            server_id = unpack_bits(32),
            actions = {},
        };

        local action_count = unpack_bits(4);
        if not action_count or action_count < 0 or action_count > 16 then
            return nil;
        end

        for _ = 1, action_count do
            local action = {
                reaction = unpack_bits(5),
                animation = unpack_bits(12),
                special_effect = unpack_bits(7),
                knockback = unpack_bits(3),
                param = unpack_bits(17),
                message = unpack_bits(10),
                flags = unpack_bits(31),
            };

            local has_additional = unpack_bits(1) == 1;
            if has_additional then
                action.additional = {
                    animation = unpack_bits(6),
                    effect = unpack_bits(4),
                    param = unpack_bits(17),
                    message = unpack_bits(10),
                };
            end

            local has_spikes = unpack_bits(1) == 1;
            if has_spikes then
                action.spikes = {
                    animation = unpack_bits(6),
                    param = unpack_bits(14),
                    message = unpack_bits(10),
                };
            end

            target.actions[#target.actions + 1] = action;
        end

        act.targets[#act.targets + 1] = target;
    end

    return act;
end

local function action_is_miss(action)
    if not action then
        return false;
    end

    -- Use the action-message id as the authoritative miss indicator.
    -- 15  = melee miss
    -- 354 = ranged attack miss
    -- This is more reliable than inferring from Param == 0, because many
    -- legitimate non-damaging actions also have a zero Param.
    local message = tonumber(action.message) or -1;
    return message == 15 or message == 354;
end

local function action_is_critical(action)
    if not action then
        return false;
    end

    -- FFXI action message IDs are authoritative here:
    -- 67  = critical melee hit
    -- 353 = critical ranged attack
    local message = tonumber(action.message) or -1;
    return message == 67 or message == 353;
end

local function action_name(act)
    if not act then
        return nil;
    end

    -- Magic finish.
    if act.category == 4 then
        return safe_spell_name(act.param);
    end

    -- Weapon skill finish: packet id maps directly.
    if act.category == 3 then
        return safe_ability_name(act.param);
    end

    -- Player job abilities use the +512 resource offset in Ashita.
    if act.category == 6 or act.category == 14 or act.category == 15 then
        return safe_ability_name((tonumber(act.param) or 0) + 512);
    end

    -- Monster / pet TP moves need their own lookup path. Do not hardcode
    -- individual move ids; try the supported ability resource conventions.
    if act.category == 11 or act.category == 13 then
        return safe_monster_ability_name(act.param);
    end

    return nil;
end

local function is_spell_or_ability_category(category)
    -- Finish categories only. Start categories 7/8 are intentionally ignored
    -- to prevent duplicate READY/CAST and completed-action entries.
    return category == 3 or category == 4 or category == 6
        or category == 11 or category == 13
        or category == 14 or category == 15;
end

local function emit_self_action(act)
    local self_id = safe_player_server_id();
    if not self_id or not act then
        return;
    end

    local actor_is_me = act.actor_id == self_id;
    local pet_id = safe_pet_server_id();
    local actor_is_pet = pet_id ~= nil and tonumber(act.actor_id) == tonumber(pet_id);
    local actor_name = actor_is_me and (safe_me() or 'You') or safe_entity_name(act.actor_id);
    local resolved_action_name = action_name(act);

    if actor_is_pet then
        for _, target in ipairs(act.targets or {}) do
            local target_name = safe_entity_name(target.server_id);
            for _, action in ipairs(target.actions or {}) do
                local amount = tonumber(action.param) or 0;
                if act.category == 1 or act.category == 2 then
                    if not action_is_miss(action) and (amount > 0 or settings.show_zero_damage == true) then
                        add_event('outgoing', 'ability',
                            tostring(amount) .. target_suffix(target_name),
                            'pet_damage');
                    elseif action_is_miss(action) and settings.show_misses == true then
                        add_event('outgoing', 'miss',
                            'MISS' .. target_suffix(target_name),
                            'pet_damage');
                    end
                elseif is_spell_or_ability_category(act.category) then
                    local pet_action = resolved_action_name or action_name(act) or 'Pet Ability';
                    local pet_text = pet_action;
                    if amount > 0 or settings.show_zero_damage == true then
                        pet_text = pet_text .. '  ' .. tostring(amount);
                    end
                    add_event('outgoing', 'ability',
                        pet_text .. target_suffix(target_name),
                        'pet_damage');
                end
            end
        end
        return;
    end

    -- Track SA/TA after the player activates the JA. The tag is consumed by the
    -- next outgoing damaging melee/WS action.
    if actor_is_me and resolved_action_name then
        if resolved_action_name == 'Sneak Attack' then
            state.sata.sneak = true;
        elseif resolved_action_name == 'Trick Attack' then
            state.sata.trick = true;
        end
    end

    for _, target in ipairs(act.targets or {}) do
        local target_is_me = target.server_id == self_id;

        -- Strict self-only rule: either we performed the action or it targeted us.
        if actor_is_me or target_is_me then
            local target_name = target_is_me and (safe_me() or 'You') or safe_entity_name(target.server_id);

            for _, action in ipairs(target.actions or {}) do
                local amount = tonumber(action.param) or 0;
                local defense = defensive_result(action);

                -- Melee / ranged finishes.
                if act.category == 1 or act.category == 2 then
                    if actor_is_me then
                        if action_is_miss(action) then
                            if settings.show_misses == true then
                                local prefix = act.category == 2 and '[R] MISS' or 'MISS';
                                add_event('outgoing', 'miss', prefix .. target_suffix(target_name),
                                    act.category == 2 and 'ranged_damage' or 'melee_damage');
                            end
                        else
                            local is_crit = action_is_critical(action);
                            local event_type = is_crit and 'criticals'
                                or (act.category == 2 and 'ranged_damage' or 'melee_damage');
                            local prefix = '';
                            if act.category == 2 and is_crit then prefix = '[R] '; end

                            add_combat_number(
                                'outgoing',
                                is_crit and 'critical' or 'outgoing',
                                amount,
                                target_name,
                                event_type,
                                prefix,
                                tostring(target.server_id) .. ':' .. tostring(act.category)
                            );

                            emit_additional_effect(action, target_name, true, actor_name);
                            emit_spike_effect(action, target_name, target_is_me, actor_name);

                            if (state.sata.sneak or state.sata.trick) and #state.events > 0 then
                                local ev = state.events[#state.events];
                                if ev and (ev.event_type == 'melee_damage' or ev.event_type == 'criticals') then
                                    ev.text = ev.text .. sata_suffix();
                                    consume_sata();
                                end
                            end
                        end
                    elseif target_is_me then
                        if defense then
                            add_event('incoming', 'miss', defense .. source_suffix(actor_name), 'defenses');
                        elseif action_is_miss(action) then
                            if settings.show_misses == true then
                                add_event('incoming', 'miss', 'MISS' .. source_suffix(actor_name), 'defenses');
                            end
                        else
                            local prefix = act.category == 2 and '[R] -' or '-';
                            add_combat_number(
                                'incoming',
                                action_is_critical(action) and 'critical' or 'incoming',
                                amount,
                                actor_name,
                                'incoming_damage',
                                prefix,
                                tostring(act.actor_id) .. ':' .. tostring(act.category)
                            );
                            emit_spike_effect(action, target_name, target_is_me, actor_name);
                        end
                    end

                -- Category 12 is ranged START; do not show it as damage.
                elseif act.category == 12 then
                    -- intentionally ignored

                elseif is_spell_or_ability_category(act.category) then
                    local display_name = resolved_action_name;

                    if not display_name or display_name == '' then
                        if act.category == 4 then
                            display_name = 'Spell #' .. tostring(act.param);
                        elseif act.category == 3 then
                            display_name = 'Weapon Skill #' .. tostring(act.param);
                        elseif act.category == 11 or act.category == 13 then
                            display_name = 'Mob Ability #' .. tostring(act.param);
                        else
                            display_name = 'Ability #' .. tostring(act.param);
                        end
                    end

                    if actor_is_me then
                        if act.category == 3 then
                            local ws_text = display_name;
                            if amount > 0 or settings.show_zero_damage == true then
                                ws_text = ws_text .. '  ' .. tostring(amount);
                            end
                            ws_text = ws_text .. target_suffix(target_name) .. sata_suffix();
                            add_event('outgoing', 'ability', ws_text, 'weapon_skills');
                            if state.sata.sneak or state.sata.trick then
                                consume_sata();
                            end
                            emit_skillchain(action, target_name);
                            emit_additional_effect(action, target_name, true, actor_name);

                        elseif act.category == 4 then
                            local lower_name = display_name:lower();

                            if action_is_heal(action) then
                                add_event('outgoing', 'ability',
                                    display_name .. target_suffix(target_name),
                                    'spells');

                                if target_is_me and amount > 0 then
                                    add_event('incoming', 'heal',
                                        '+' .. tostring(amount) .. ' HP  <-  ' .. display_name,
                                        'healing_received');
                                end

                            elseif lower_name:find('drain', 1, true) and amount > 0 then
                                add_event('outgoing', 'ability',
                                    display_name .. ' +' .. tostring(amount) .. ' HP' .. target_suffix(target_name),
                                    'drain_aspir');

                            elseif lower_name:find('aspir', 1, true) and amount > 0 then
                                add_event('outgoing', 'ability',
                                    display_name .. ' +' .. tostring(amount) .. ' MP' .. target_suffix(target_name),
                                    'drain_aspir');

                            elseif DAMAGE_SPELL_MESSAGES[tonumber(action.message) or -1] and (amount > 0 or settings.show_zero_damage == true) then
                                local mb = is_magic_burst_message(action.message);
                                local spell_text = display_name .. '  ' .. tostring(amount) .. target_suffix(target_name);
                                if mb then
                                    spell_text = spell_text .. ' [MB]';
                                end
                                add_event('outgoing', 'ability', spell_text,
                                    mb and 'magic_bursts' or 'spells');

                            elseif target_is_me then
                                add_event('outgoing', 'ability',
                                    display_name .. '  ->  You',
                                    'buffs');
                            else
                                add_event('outgoing', 'ability',
                                    display_name .. target_suffix(target_name) .. resist_suffix(action),
                                    'spells');
                            end

                        else
                            local ability_text = display_name;
                            if amount > 0 or settings.show_zero_damage == true then
                                ability_text = ability_text .. '  ' .. tostring(amount);
                            end
                            add_event('outgoing', 'ability',
                                ability_text .. target_suffix(target_name),
                                'outgoing_abilities');
                        end

                    elseif target_is_me then
                        if action_is_heal(action) and amount > 0 then
                            add_event('incoming', 'heal',
                                '+' .. tostring(amount) .. ' HP  <-  ' .. display_name,
                                'healing_received');

                        elseif act.category == 4
                            and display_name:lower():find('refresh', 1, true)
                            and amount > 0 then
                            add_event('incoming', 'heal',
                                '+' .. tostring(amount) .. ' MP  <-  ' .. display_name,
                                'mp_recovery');

                        elseif amount > 0 and (
                            act.category == 3
                            or act.category == 11
                            or act.category == 13
                            or DAMAGE_SPELL_MESSAGES[tonumber(action.message) or -1]
                            or action.message == 110
                            or action.message == 185
                            or action.message == 197
                            or action.message == 522
                            or action.message == 802
                        ) then
                            local prefix = '';
                            if act.category == 4 then prefix = '[SP] '; end
                            add_event('incoming', 'ability',
                                prefix .. display_name .. '  ' .. tostring(amount) .. source_suffix(actor_name),
                                'incoming_abilities');
                        else
                            local positive = act.category == 4 and likely_beneficial_status(display_name);
                            add_event('incoming', 'ability',
                                display_name .. source_suffix(actor_name) .. resist_suffix(action),
                                positive and 'status_positive' or 'status_negative');
                        end
                    else
                        -- Pet / avatar action belonging to another actor is only
                        -- surfaced when it directly targets the player; strict
                        -- self-only behavior is preserved.
                    end
                end
            end
        end
    end
end

local function parse_message_packet(e)
    if not e or not e.data then
        return nil;
    end

    local data = e.data;

    -- 0x029 is byte-aligned / little-endian. Ashita addons parse this with
    -- struct.unpack at these exact offsets:
    -- 0x04 actor, 0x08 target, 0x0C param1, 0x10 param2,
    -- 0x14 actor index, 0x16 target index, 0x18 message.
    local ok, parsed = pcall(function()
        return {
            actor = struct.unpack('I', data, 0x04 + 1),
            target = struct.unpack('I', data, 0x08 + 1),
            param1 = struct.unpack('I', data, 0x0C + 1),
            param2 = struct.unpack('I', data, 0x10 + 1),
            actor_index = struct.unpack('H', data, 0x14 + 1),
            target_index = struct.unpack('H', data, 0x16 + 1),
            message = struct.unpack('H', data, 0x18 + 1),
            unknown = struct.unpack('H', data, 0x1A + 1),
        };
    end);

    if not ok then
        return nil;
    end

    return parsed;
end

local SKILL_NAMES = T{
    [1] = 'Hand-to-Hand',
    [2] = 'Dagger',
    [3] = 'Sword',
    [4] = 'Great Sword',
    [5] = 'Axe',
    [6] = 'Great Axe',
    [7] = 'Scythe',
    [8] = 'Polearm',
    [9] = 'Katana',
    [10] = 'Great Katana',
    [11] = 'Club',
    [12] = 'Staff',

    [25] = 'Archery',
    [26] = 'Marksmanship',
    [27] = 'Throwing',

    [28] = 'Guard',
    [29] = 'Evasion',
    [30] = 'Shield',
    [31] = 'Parry',

    [32] = 'Divine Magic',
    [33] = 'Healing Magic',
    [34] = 'Enhancing Magic',
    [35] = 'Enfeebling Magic',
    [36] = 'Elemental Magic',
    [37] = 'Dark Magic',
    [38] = 'Summoning Magic',
    [39] = 'Ninjutsu',
    [40] = 'Singing',
    [41] = 'Stringed Instrument',
    [42] = 'Wind Instrument',
    [43] = 'Blue Magic',
    [44] = 'Geomancy',
    [45] = 'Handbell',

    [48] = 'Fishing',
    [49] = 'Woodworking',
    [50] = 'Smithing',
    [51] = 'Goldsmithing',
    [52] = 'Clothcraft',
    [53] = 'Leathercraft',
    [54] = 'Bonecraft',
    [55] = 'Alchemy',
    [56] = 'Cooking',
};

local function skill_name_from_id(skill_id)
    skill_id = tonumber(skill_id);
    if not skill_id then
        return nil;
    end
    return SKILL_NAMES[skill_id] or ('Skill #' .. tostring(skill_id));
end

local function emit_progression_message(msg)
    if not msg then
        return;
    end

    local amount = tonumber(msg.param1) or 0;
    local chain = tonumber(msg.param2) or 0;
    local message = bit.band(tonumber(msg.message) or -1, 0x7FFF);
    local self_id = safe_player_server_id();

    -- Skill-up packets are authoritative on HorizonXI.
    -- Message 38: Param1 = skill ID, Param2 = delta in tenths.
    -- Message 53: Param1 = skill ID, Param2 = new integer skill level.
    if message == 38 then
        local skill_id = tonumber(msg.param1) or 0;
        local tenths = tonumber(msg.param2) or 0;

        if skill_id > 0 and tenths > 0 then
            local name = skill_name_from_id(skill_id);
            state.skillup_packet_at[skill_id] = os.clock();

            add_event(
                'incoming',
                'xp',
                name .. ' +' .. string.format('%.1f', tenths / 10),
                'skill_ups'
            );
        end
        return;
    elseif message == 53 then
        local skill_id = tonumber(msg.param1) or 0;
        local new_level = tonumber(msg.param2) or 0;

        if skill_id > 0 and new_level >= 0 then
            local name = skill_name_from_id(skill_id);
            state.skillup_packet_at[skill_id] = os.clock();

            add_event(
                'incoming',
                'xp',
                name .. ' -> ' .. tostring(new_level),
                'skill_ups'
            );
        end
        return;
    end

    -- Status effect wears off. Param1 is the status/buff id.
    if message == 206 and self_id and tonumber(msg.target) == tonumber(self_id) then
        local status_name = safe_status_name(amount) or ('Status #' .. tostring(amount));
        add_event('incoming', 'ability', status_name .. ' removed', 'status_removed');
        return;
    end

    -- KO / defeat messages. Keep them self-relevant only.
    if message == 6 or message == 20 then
        if self_id and tonumber(msg.actor) == tonumber(self_id) then
            local target_name = safe_entity_name(msg.target);
            add_event('outgoing', 'ability', target_name .. ' defeated', 'ko');
        elseif self_id and tonumber(msg.target) == tonumber(self_id) then
            local actor_name = safe_entity_name(msg.actor);
            add_event('incoming', 'ability', 'You were defeated' .. source_suffix(actor_name), 'ko');
        end
        return;
    end

    if amount <= 0 then
        return;
    end

    if message == 8 or message == 105 then
        local suffix = '';
        if chain > 0 and chain < 100 then
            suffix = '  (Chain #' .. tostring(chain) .. ')';
        end
        add_progression_event('xp', '+' .. tostring(amount) .. ' EXP' .. suffix);

    elseif message == 371 or message == 372 then
        add_progression_event('xp', '+' .. tostring(amount) .. ' Limit Points');

    elseif message == 718 or message == 735 then
        add_progression_event('xp', '+' .. tostring(amount) .. ' Capacity Points');

    elseif message == 809 or message == 810 then
        add_progression_event('xp', '+' .. tostring(amount) .. ' Exemplar Points');

    elseif message == 565 or message == 582 then
        add_progression_event('gil', '+' .. tostring(amount) .. ' gil');
    end
end

local function parse_exp_packet(e)
    if not e or not e.data then
        return nil;
    end

    -- 0x02D is a normal byte-aligned packet, not a bit-packed 0x28 action.
    -- Ashita v4 exposes e.data as the packet string specifically for
    -- struct.unpack. The previous build used unpack_be on e.data_raw, which
    -- decoded the little-endian fields incorrectly.
    local data = e.data;

    local ok, parsed = pcall(function()
        return {
            player_id = struct.unpack('I', data, 0x04 + 1),
            target_id = struct.unpack('I', data, 0x08 + 1),
            player_index = struct.unpack('H', data, 0x0C + 1),
            target_index = struct.unpack('H', data, 0x0E + 1),
            amount = struct.unpack('I', data, 0x10 + 1),
            chain = struct.unpack('I', data, 0x14 + 1),
            message = struct.unpack('H', data, 0x18 + 1),
        };
    end);

    if not ok then
        return nil;
    end

    return parsed;
end

local function emit_exp_gain(exp)
    if not exp then
        return;
    end

    local self_id = safe_player_server_id();
    if not self_id then
        return;
    end

    -- Retail-style 0x02D identifies the recipient in Player. Horizon builds
    -- should follow that layout, but keep the comparison numeric and safe.
    if tonumber(exp.player_id) ~= tonumber(self_id) then
        return;
    end

    local amount = tonumber(exp.amount) or 0;
    local raw_message = tonumber(exp.message) or -1;
    local message = bit.band(raw_message, 0x7FFF);

    if amount <= 0 then
        return;
    end

    if message == 8 or message == 105 then
        local suffix = '';
        local chain = tonumber(exp.chain) or 0;
        if chain > 0 then
            suffix = '  (Chain #' .. tostring(chain) .. ')';
        end
        add_progression_event('xp', '+' .. tostring(amount) .. ' EXP' .. suffix);

    elseif message == 371 or message == 372 then
        add_progression_event('xp', '+' .. tostring(amount) .. ' Limit Points');

    elseif message == 718 or message == 735 then
        add_progression_event('xp', '+' .. tostring(amount) .. ' Capacity Points');

    elseif message == 809 or message == 810 then
        add_progression_event('xp', '+' .. tostring(amount) .. ' Exemplar Points');
    end
end

ashita.events.register('packet_in', 'scl_scroll_packet_in_cb', function(e)
    if not e or state.paused or not settings.enabled then
        return;
    end

    if e.id == 0x28 then
        local ok, act = pcall(parse_action_packet, e);
        if not ok or not act then
            return;
        end

        -- Never allow one unexpected combat packet to unload the addon.
        pcall(emit_self_action, act);
        return;
    end

    if e.id == 0x29 then
        local ok, msg = pcall(parse_message_packet, e);
        if ok and msg then
            pcall(emit_progression_message, msg);
        end
        return;
    end

    if e.id == 0x2D then
        local ok, exp = pcall(parse_exp_packet, e);
        if not ok or not exp then
            return;
        end

        pcall(emit_exp_gain, exp);
        return;
    end
end);

-- HorizonXI fallback:
-- Some private-server builds can deliver progression text differently even
-- when the normal retail 0x02D packet is absent or modified. Unlike combat
-- capture, these system gain lines are reliable through text_in, so use them
-- as a narrow fallback for EXP/point gains only.
ashita.events.register('text_in', 'scl_scroll_exp_text_in_cb', function(e)
    if not e or state.paused or not settings.enabled or e.injected then
        return;
    end

    local raw = e.message;
    if type(raw) ~= 'string' or raw == '' then
        return;
    end

    local line = normalize_line(strip_control_codes(raw));
    if line == '' then
        return;
    end

    local me = safe_me();
    if not me or me == '' then
        return;
    end

    local lower = line:lower();
    local me_lower = me:lower();

    -- Remember nearby kill completion briefly. Gil awarded from a normal mob
    -- kill is printed immediately after the defeat line, including when a
    -- party member lands the killing blow.
    if lower:find(' defeats ', 1, true) then
        state.last_kill_time = os.clock();
    end

    -- Gil from a kill:
    --   Izumi obtains 9 gil.
    -- Only surface it when it follows a recent defeat line so ordinary gil
    -- changes from unrelated sources do not become combat text.
    local gil = line:match('[Oo]btains%s+(%d+)%s+[Gg]il');
    if gil then
        local since_kill = os.clock() - (tonumber(state.last_kill_time) or 0);
        if since_kill >= 0 and since_kill <= 6.0 then
            add_progression_event('gil', '+' .. tostring(gil) .. ' gil');
        end
        return;
    end

    -- Horizon commonly prints "Name gains N experience points."  Some chat
    -- pipelines insert formatting bytes into the name portion, so do not make
    -- progression capture depend on an exact player-name substring here.
    local amount = nil;
    local kind = nil;

    amount = line:match('[Gg]ains%s+(%d+)%s+[Ee]xperience%s+[Pp]oints?')
    if amount then
        kind = 'EXP'
    end

    if not amount then
        amount = line:match('[Gg]ains%s+(%d+)%s+[Ll]imit%s+[Pp]oints?')
        if amount then kind = 'Limit Points' end
    end

    if not amount then
        amount = line:match('[Gg]ains%s+(%d+)%s+[Cc]apacity%s+[Pp]oints?')
        if amount then kind = 'Capacity Points' end
    end

    if not amount then
        amount = line:match('[Gg]ains%s+(%d+)%s+[Ee]xemplar%s+[Pp]oints?')
        if amount then kind = 'Exemplar Points' end
    end

    -- Also support first-person forms if the server uses them.
    if not amount and (lower:find('you gain ', 1, true) or lower:find('you obtain ', 1, true)) then
        amount = line:match('[Yy]ou%s+[Gg]ain%s+(%d+)%s+[Ee]xperience%s+[Pp]oints?')
        if amount then kind = 'EXP' end
    end

    if amount and kind then
        add_progression_event('xp', '+' .. tostring(amount) .. ' ' .. kind);
        return;
    end

    -- Skill-up chat fallback. Packet 0x29 Message 38/53 normally emits first.
    -- Patterns are intentionally not anchored at column 1 because FancyChat can
    -- prepend timestamps / channel decoration.
    local skill_name, rise = line:match("([%a][%a%s%-']-)%s+[Ss]kill%s+[Rr]ises%s+(%d+%.?%d*)%s+[Pp]oints?");
    if skill_name and rise then
        skill_name = skill_name:gsub("^.-'s%s+", ''):gsub("^%s+", ''):gsub("%s+$", '');

        local matched_id = nil;
        local normalized = skill_name:lower();
        for sid, known_name in pairs(SKILL_NAMES) do
            if known_name:lower() == normalized
                or known_name:lower():gsub('%s+[Mm]agic$', '') == normalized:gsub('%s+[Mm]agic$', '') then
                matched_id = sid;
                break;
            end
        end

        local fresh_packet = matched_id
            and state.skillup_packet_at[matched_id]
            and (os.clock() - state.skillup_packet_at[matched_id]) < 1.5;

        if not fresh_packet then
            add_event('incoming', 'xp', skill_name .. ' +' .. tostring(rise), 'skill_ups');
        end
        return;
    end

    local skill_name2, new_value = line:match("([%a][%a%s%-']-)%s+[Ss]kill%s+[Rr]eaches%s+[Ll]evel%s+(%d+)");
    if skill_name2 and new_value then
        skill_name2 = skill_name2:gsub("^.-'s%s+", ''):gsub("^%s+", ''):gsub("%s+$", '');

        local matched_id = nil;
        local normalized = skill_name2:lower();
        for sid, known_name in pairs(SKILL_NAMES) do
            if known_name:lower() == normalized
                or known_name:lower():gsub('%s+[Mm]agic$', '') == normalized:gsub('%s+[Mm]agic$', '') then
                matched_id = sid;
                break;
            end
        end

        local fresh_packet = matched_id
            and state.skillup_packet_at[matched_id]
            and (os.clock() - state.skillup_packet_at[matched_id]) < 1.5;

        if not fresh_packet then
            add_event('incoming', 'xp', skill_name2 .. ' -> ' .. tostring(new_value), 'skill_ups');
        end
        return;
    end

    local skill_name3, new_value2 = line:match("([%a][%a%s%-']-)%s+[Ss]kill%s+[Rr]ises%s+to%s+(%d+%.?%d*)");
    if skill_name3 and new_value2 then
        skill_name3 = skill_name3:gsub("^.-'s%s+", ''):gsub("^%s+", ''):gsub("%s+$", '');
        add_event('incoming', 'xp', skill_name3 .. ' -> ' .. tostring(new_value2), 'skill_ups');
        return;
    end

    -- Character level-up. Deliberately evaluated after skill-level messages so
    -- "Blue magic skill reaches level 99" cannot be misclassified as character level 99.
    local level = line:match('[Ll]evel%s+increases%s+to%s+(%d+)')
        or line:match('[Aa]ttains%s+[Ll]evel%s+(%d+)')
        or line:match('[Yy]ou%s+attain%s+[Ll]evel%s+(%d+)');
    if level then
        add_event('incoming', 'xp', 'Level ' .. tostring(level), 'level_up');
        return;
    end

    -- Merit / Job Point style gains where the exact server text is available.
    local merit = line:match('[Oo]btains%s+(%d+)%s+[Mm]erit%s+[Pp]oints?')
        or line:match('[Gg]ains%s+(%d+)%s+[Mm]erit%s+[Pp]oints?');
    if merit then
        add_progression_event('xp', '+' .. tostring(merit) .. ' Merit Points');
        return;
    end

    local jp = line:match('[Oo]btains%s+(%d+)%s+[Jj]ob%s+[Pp]oints?')
        or line:match('[Gg]ains%s+(%d+)%s+[Jj]ob%s+[Pp]oints?');
    if jp then
        add_progression_event('xp', '+' .. tostring(jp) .. ' Job Points');
        return;
    end

    -- Personal loot/item drops. Keep this narrow to obtain/lot/treasure lines.
    local item = line:match('[Oo]btains%s+an?%s+(.+)%.?$')
        or line:match('[Oo]btains%s+the%s+(.+)%.?$')
        or line:match('[Yy]ou%s+find%s+an?%s+(.+)%s+[Oo]n%s+the%s+.+%.?$')
        or line:match('[Yy]ou%s+find%s+(.+)%s+[Oo]n%s+the%s+.+%.?$')
        or line:match('[Yy]ou%s+find%s+an?%s+(.+)%.?$');
    if item and not item:lower():find('gil', 1, true) then
        item = item:gsub('%.$', '');
        add_event('incoming', 'xp', item, 'item_drops');
        return;
    end

    -- Explicit MP recovery text fallback.
    local mp = line:match('[Rr]ecovers%s+(%d+)%s+[Mm][Pp]');
    if mp and (lower:find(me_lower, 1, true) or lower:find('you ', 1, true)) then
        add_event('incoming', 'heal', '+' .. tostring(mp) .. ' MP', 'mp_recovery');
        return;
    end

    -- Status removal text fallback when 0x29/206 is unavailable.
    local removed = line:match("^.-'s%s+(.+)%s+[Ee]ffect%s+[Ww]ears%s+[Oo]ff")
        or line:match('[Ee]ffect%s+of%s+(.+)%s+[Ww]ears%s+[Oo]ff')
        or line:match("^(.+)%s+[Ww]ears%s+[Oo]ff");
    if removed and (lower:find(me_lower, 1, true) or lower:find('you', 1, true)) then
        add_event('incoming', 'ability', removed:gsub('%.$', '') .. ' removed', 'status_removed');
        return;
    end
end);

local function safe_player_exp()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then
        return nil, nil;
    end

    local player = mm:GetPlayer();
    if not player then
        return nil, nil;
    end

    if player.GetExpCurrent == nil or player.GetExpNeeded == nil then
        return nil, nil;
    end

    local ok_current, current = pcall(function()
        return player:GetExpCurrent();
    end);

    local ok_needed, needed = pcall(function()
        return player:GetExpNeeded();
    end);

    if not ok_current or not ok_needed then
        return nil, nil;
    end

    current = tonumber(current);
    needed = tonumber(needed);

    if not current or not needed then
        return nil, nil;
    end

    return current, needed;
end

local function update_exp_memory_watch()
    -- Memory-backed EXP detection is the authoritative fallback for HorizonXI.
    -- It does not depend on 0x029 / 0x02D / text_in ordering, so FancyChat or
    -- server-side packet differences cannot hide a normal EXP gain.
    local now = os.clock();
    if (now - (state.xp_watch.last_check or 0)) < 0.10 then
        return;
    end
    state.xp_watch.last_check = now;

    local current, needed = safe_player_exp();
    if current == nil or needed == nil then
        return;
    end

    if not state.xp_watch.initialized then
        state.xp_watch.current = current;
        state.xp_watch.needed = needed;
        state.xp_watch.initialized = true;
        return;
    end

    local old_current = tonumber(state.xp_watch.current) or current;
    local old_needed = tonumber(state.xp_watch.needed) or needed;
    local gained = 0;

    if current > old_current then
        -- Normal EXP gain within the same level.
        gained = current - old_current;

    elseif current < old_current and needed ~= old_needed then
        -- Level-up rollover:
        -- gain = remaining EXP to old level + EXP already earned into new level.
        local remaining = old_needed - old_current;
        if remaining >= 0 then
            gained = remaining + current;
        end
    end

    state.xp_watch.current = current;
    state.xp_watch.needed = needed;

    if gained > 0 and gained < 100000 then
        add_progression_event('xp', '+' .. tostring(gained) .. ' EXP');
    end
end

local MAX_FONT_POOL = 96;

local function create_font_object()
    local ok, obj = pcall(function()
        return fonts.new({
            visible = false,
            can_focus = false,
            locked = true,
            lockedz = true,
            font_family = tostring(settings.font_family or 'Consolas'),
            font_height = 16,
            bold = settings.font_bold == true,
            italic = settings.font_italic == true,
            right_justified = false,

            -- Ashita FontManager requires BOTH an outline color and the
            -- FontDrawFlags.Outlined flag. Setting color_outline by itself
            -- does not actually render an outline.
            draw_flags = settings.font_outline == true
                and FontDrawFlags.Outlined
                or FontDrawFlags.None,

            color = 0xFFFFFFFF,
            color_outline = settings.font_outline == true and 0xFF000000 or 0x00000000,
            position_x = 0,
            position_y = 0,
            text = '',
            background = {
                visible = false,
            },
        });
    end);

    if ok then
        return obj;
    end

    return nil;
end

local function ensure_font_pool(count)
    count = math.min(math.max(count or 0, 0), MAX_FONT_POOL);

    while #state.font_pool < count do
        local obj = create_font_object();
        if not obj then
            break;
        end
        state.font_pool[#state.font_pool + 1] = obj;
    end

    state.font_pool_size = #state.font_pool;
end

local function hide_unused_fonts(from_index)
    for i = from_index, #state.font_pool do
        local obj = state.font_pool[i];
        if obj then
            obj.visible = false;
        end
    end
end

local function destroy_font_pool()
    for _, obj in ipairs(state.font_pool) do
        if obj then
            pcall(function() obj:destroy(); end);
        end
    end

    state.font_pool = {};
    state.font_pool_size = 0;
end

local function ensure_preview_font_pool(count)
    count = math.max(0, tonumber(count) or 0);

    while #state.preview_font_pool < count do
        local obj = create_font_object();
        if not obj then
            break;
        end
        state.preview_font_pool[#state.preview_font_pool + 1] = obj;
    end
end

local function hide_preview_fonts()
    for _, obj in ipairs(state.preview_font_pool) do
        if obj then
            obj.visible = false;
        end
    end
end

local function destroy_preview_font_pool()
    for _, obj in ipairs(state.preview_font_pool) do
        if obj then
            pcall(function() obj:destroy(); end);
        end
    end
    state.preview_font_pool = {};
end

rebuild_font_pool = function()
    destroy_font_pool();
    destroy_preview_font_pool();
    state.font_generation = state.font_generation + 1;
end

local function apply_font_style(obj, ev, text_value, x, y, color, alpha)
    if not obj then
        return;
    end

    local scale = event_scale(ev, os.clock() - ev.created);
    local height = math.max(8, math.floor(16 * scale + 0.5));
    local anchor = ev.direction == 'incoming' and settings.incoming or settings.outgoing;

    local family = tostring(settings.font_family or 'Consolas');
    if obj.font_family ~= family then obj.font_family = family; end
    if obj.font_height ~= height then obj.font_height = height; end

    local bold = settings.font_bold == true;
    local italic = settings.font_italic == true;
    local justified = (anchor.orientation or 'right') == 'left';

    if obj.bold ~= bold then obj.bold = bold; end
    if obj.italic ~= italic then obj.italic = italic; end

    -- Draw flags are what actually enable FontManager outlines. Build the
    -- complete flag set each frame so changing Outline is immediately visible
    -- and left-oriented/right-justified lanes continue to work.
    local draw_flags = FontDrawFlags.None;
    if justified then
        draw_flags = bit.bor(draw_flags, FontDrawFlags.RightJustified);
    end
    if settings.font_outline == true then
        draw_flags = bit.bor(draw_flags, FontDrawFlags.Outlined);
    end

    if obj.draw_flags ~= draw_flags then obj.draw_flags = draw_flags; end

    if obj.text ~= text_value then obj.text = text_value; end
    if obj.position_x ~= x then obj.position_x = x; end
    if obj.position_y ~= y then obj.position_y = y; end

    local new_color = rgba_to_argb(color, alpha);
    local new_outline = settings.font_outline == true
        and rgba_to_argb({ 0.0, 0.0, 0.0, 1.0 }, alpha)
        or 0x00000000;

    if obj.color ~= new_color then obj.color = new_color; end
    if obj.color_outline ~= new_outline then obj.color_outline = new_outline; end
    if obj.visible ~= true then obj.visible = true; end
end

-- Lightweight Performance-renderer outline.
--
-- This is intentionally NOT the old drop-shadow implementation. A shadow adds
-- a separate displaced copy of the text, while this draws four 1px black edge
-- passes around the same glyph position and then the normal text on top.
--
-- Four passes were chosen instead of an 8-direction outline to keep the
-- Performance renderer inexpensive even with several simultaneous events.
local function draw_imgui_text_with_outline(color, text_value)
    if settings.font_outline ~= true then
        imgui.TextColored(color, text_value);
        return;
    end

    local x, y = imgui.GetCursorPos();
    x = tonumber(x) or 0;
    y = tonumber(y) or 0;

    local alpha = tonumber(color[4]) or 1.0;
    local outline_color = { 0.0, 0.0, 0.0, alpha };

    local offsets = {
        { -1,  0 },
        {  1,  0 },
        {  0, -1 },
        {  0,  1 },
    };

    for _, offset in ipairs(offsets) do
        imgui.SetCursorPos({ x + offset[1], y + offset[2] });
        imgui.TextColored(outline_color, text_value);
    end

    imgui.SetCursorPos({ x, y });
    imgui.TextColored(color, text_value);
end

local function draw_scrolling_event_performance(ev, age, y)
    local duration = math.max(0.5, tonumber(settings.duration) or 3.5);
    local t = clamp(age / duration, 0.0, 1.0);

    local anchor = ev.direction == 'incoming' and settings.incoming or settings.outgoing;
    local x = tonumber(anchor.x) or 500;

    local fade = 1.0;
    if t > 0.62 then
        fade = 1.0 - ((t - 0.62) / 0.38);
    end
    fade = clamp(fade, 0.0, 1.0);

    local color = event_color(ev);
    local display_text = rendered_event_text(ev);
    local scale = event_scale(ev, age);

    imgui.PushFont(nil, imgui.GetFontSize() * scale);

    -- In performance mode, left/right orientation is handled by a lightweight
    -- text-width calculation rather than FontManager justification.
    if (anchor.orientation or 'right') == 'left' then
        local width = imgui.CalcTextSize(display_text);
        width = tonumber(width) or 0;
        x = x - width;
    end

    imgui.SetNextWindowPos({ x, y });

    local flags = bit.bor(
        ImGuiWindowFlags_NoTitleBar,
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoMove,
        ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoInputs,
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_AlwaysAutoResize
    );

    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.0, 0.0, 0.0, 0.0 });
    imgui.PushStyleColor(ImGuiCol_Border, { 0.0, 0.0, 0.0, 0.0 });

    if imgui.Begin(('##scl_perf_%d'):fmt(ev.id), nil, flags) then
        draw_imgui_text_with_outline(
            { color[1], color[2], color[3], (color[4] or 1.0) * fade },
            display_text
        );
    end

    imgui.End();
    imgui.PopStyleColor(2);
    imgui.PopFont();
end

local function draw_scrolling_event(ev, age, y, font_obj)
    local duration = math.max(0.5, tonumber(settings.duration) or 3.5);
    local t = clamp(age / duration, 0.0, 1.0);

    local anchor = ev.direction == 'incoming' and settings.incoming or settings.outgoing;
    local x = tonumber(anchor.x) or 500;

    local fade = 1.0;
    if t > 0.62 then
        fade = 1.0 - ((t - 0.62) / 0.38);
    end
    fade = clamp(fade, 0.0, 1.0);

    local color = event_color(ev);
    local display_text = rendered_event_text(ev);

    apply_font_style(font_obj, ev, display_text, x, y, color, fade);
end

local function draw_lane(events, anchor, now, pool_index)
    if #events == 0 then
        return pool_index;
    end

    table.sort(events, function(a, b)
        return a.created > b.created;
    end);

    local speed = math.max(0.0, tonumber(settings.scroll_speed) or 70.0);
    local anchor_y = tonumber(anchor.y) or 500;
    local growth_up = (anchor.growth or 'up') ~= 'down';

    local previous_y = nil;
    local previous_height = nil;

    for _, ev in ipairs(events) do
        pool_index = pool_index + 1;
        if pool_index > MAX_FONT_POOL then
            break;
        end

        local age = math.max(0.0, now - ev.created);
        local travel = age * speed;
        local candidate_y = growth_up and (anchor_y - travel) or (anchor_y + travel);
        local y = candidate_y;

        local current_height = math.max(
            20.0,
            imgui.GetFontSize() * event_scale(ev, age) * 1.45
        );

        if previous_y ~= nil then
            local spacing = math.max(current_height, previous_height or current_height) + 3.0;
            if growth_up then
                y = math.min(candidate_y, previous_y - spacing);
            else
                y = math.max(candidate_y, previous_y + spacing);
            end
        end

        if (settings.renderer_mode or 'performance') == 'performance' then
            draw_scrolling_event_performance(ev, age, y);
        else
            local font_obj = state.font_pool[pool_index];

            if font_obj then
                draw_scrolling_event(ev, age, y, font_obj);
            end
        end

        previous_y = y;
        previous_height = current_height;
    end

    return pool_index;
end

local function draw_events()
    if not settings.enabled then
        hide_unused_fonts(1);
        return;
    end

    local now = os.clock();
    local duration = math.max(0.5, tonumber(settings.duration) or 3.5);
    local keep = {};
    local outgoing = {};
    local incoming = {};

    for _, ev in ipairs(state.events) do
        local age = now - ev.created;
        if age < duration then
            keep[#keep + 1] = ev;

            if ev.direction == 'incoming' then
                incoming[#incoming + 1] = ev;
            else
                outgoing[#outgoing + 1] = ev;
            end
        end
    end

    state.events = keep;

    local cap = math.floor(clamp(tonumber(settings.max_visible_events) or 14, 4, MAX_EVENTS));
    while (#outgoing + #incoming) > cap do
        local oldest_out = outgoing[#outgoing];
        local oldest_in = incoming[#incoming];

        if oldest_out and oldest_in then
            if oldest_out.created <= oldest_in.created then
                table.remove(outgoing, #outgoing);
            else
                table.remove(incoming, #incoming);
            end
        elseif oldest_out then
            table.remove(outgoing, #outgoing);
        elseif oldest_in then
            table.remove(incoming, #incoming);
        else
            break;
        end
    end

    local used = 0;

    if (settings.renderer_mode or 'performance') == 'performance' then
        -- Completely bypass FontManager while fighting.
        hide_unused_fonts(1);
        used = draw_lane(outgoing, settings.outgoing, now, used);
        used = draw_lane(incoming, settings.incoming, now, used);
    else
        local required = math.min(#outgoing + #incoming, MAX_FONT_POOL);
        ensure_font_pool(required);

        used = draw_lane(outgoing, settings.outgoing, now, used);
        used = draw_lane(incoming, settings.incoming, now, used);

        hide_unused_fonts(used + 1);
    end
end

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

local function reset_anchor(key)
    if key ~= 'incoming' and key ~= 'outgoing' then
        return;
    end

    settings[key].x = defaults[key].x;
    settings[key].y = defaults[key].y;
    state.move_initialized[key] = false;
    save_settings();
end

local function reset_all_settings()
    copy_defaults(settings, defaults);
    state.events = {};
    hide_unused_fonts(1);
    rebuild_font_pool();
    state.move_mode = false;
    state.move_initialized.incoming = false;
    state.move_initialized.outgoing = false;
    state.confirm_reset_all = false;
    save_settings();
end


local function draw_move_anchor(title, key, color)
    local anchor = settings[key];
    if not anchor then
        return;
    end

    -- IMPORTANT: only apply the saved position ONCE when move mode is opened.
    -- Calling SetNextWindowPos every frame pins the ImGui window in place and
    -- makes dragging impossible. We deliberately avoid ImGuiCond_* and use
    -- static state instead for Ashita v4 compatibility.
    if not state.move_initialized[key] then
        imgui.SetNextWindowPos({
            tonumber(anchor.x) or 500,
            tonumber(anchor.y) or 500
        });
        state.move_initialized[key] = true;
    end

    local flags = bit.bor(
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_NoNav
    );

    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.055, 0.070, 0.095, 0.92 });
    imgui.PushStyleColor(ImGuiCol_Border, color);

    if imgui.Begin(title .. '##scl_move_' .. key, nil, flags) then
        imgui.TextColored(color, title);
        imgui.TextDisabled('Drag this window to position the lane.');

        -- Current Ashita v4 returns x, y as separate numeric values.
        local x, y = imgui.GetWindowPos();
        x = tonumber(x);
        y = tonumber(y);

        if x and y then
            local old_x = tonumber(anchor.x) or x;
            local old_y = tonumber(anchor.y) or y;

            if math.abs(x - old_x) >= 1 or math.abs(y - old_y) >= 1 then
                anchor.x = x;
                anchor.y = y;
                save_settings();
            end
        end
    end

    imgui.End();
    imgui.PopStyleColor(2);
end

local function draw_move_mode()
    if not state.move_mode or settings.locked == true then
        return;
    end

    draw_move_anchor(
        'Incoming Combat Text',
        'incoming',
        { 1.00, 0.36, 0.36, 1.00 }
    );

    draw_move_anchor(
        'Outgoing Combat Text',
        'outgoing',
        { 1.00, 0.88, 0.32, 1.00 }
    );
end

local UI_BG      = { 0.040, 0.052, 0.070, 0.985 };
local UI_TITLE   = { 0.055, 0.095, 0.135, 1.000 };
local UI_BORDER  = { 0.18, 0.36, 0.50, 0.95 };
local UI_ACCENT  = { 0.34, 0.76, 1.00, 1.00 };
local UI_GREEN   = { 0.40, 0.88, 0.48, 1.00 };
local UI_RED     = { 1.00, 0.42, 0.42, 1.00 };
local UI_GOLD    = { 1.00, 0.80, 0.28, 1.00 };
local UI_MUTED   = { 0.60, 0.68, 0.76, 1.00 };

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

local function draw_live_preview()
    imgui.TextColored(UI_ACCENT, 'LIVE PREVIEW');

    local custom = (settings.renderer_mode or 'performance') == 'custom';
    if custom then
        imgui.TextDisabled('Custom Font preview: family, bold, italic, outline, colors and size are live.');
    else
        imgui.TextDisabled('Performance preview: colors, prefixes, names and size are live.');
    end

    local samples = {
        { 'outgoing', 'critical', '148' .. target_suffix('Goblin'), 'criticals' },
        { 'outgoing', 'ability', 'Vorpal Blade  722' .. target_suffix('Goblin'), 'weapon_skills' },
        { 'outgoing', 'ability', 'Thunder II  843' .. target_suffix('Goblin') .. ' [MB]', 'magic_bursts' },
        { 'outgoing', 'ability', 'Light  486' .. target_suffix('Goblin'), 'skillchains' },
        { 'incoming', 'incoming', '-63' .. source_suffix('Goblin'), 'incoming_damage' },
        { 'incoming', 'miss', 'PARRY' .. source_suffix('Goblin'), 'defenses' },
        { 'incoming', 'heal', '+93 HP  <-  Cure II', 'healing_received' },
        { 'incoming', 'xp', '+189 EXP', 'exp' },
    };

    if not custom then
        hide_preview_fonts();

        for i, sample in ipairs(samples) do
            local ev = {
                direction = sample[1],
                kind = sample[2],
                text = sample[3],
                event_type = sample[4],
                created = os.clock(),
            };

            local c = event_color(ev);
            local scale = event_scale(ev, 0);
            imgui.PushFont(nil, imgui.GetFontSize() * scale);
            draw_imgui_text_with_outline(c, rendered_event_text(ev));
            imgui.PopFont();

            if i == 4 then
                imgui.Separator();
            end
        end

        return;
    end

    -- Custom Font renderer:
    -- ImGui cannot preview arbitrary Windows FontManager families, so use a
    -- dedicated set of actual FontManager objects positioned over the Preview
    -- area. This makes the preview match the selected family/style instead of
    -- always looking like the ImGui UI font.
    ensure_preview_font_pool(#samples);

    local start_x, start_y = imgui.GetCursorScreenPos();
    start_x = tonumber(start_x) or 0;
    start_y = tonumber(start_y) or 0;

    local y = start_y;
    local used_height = 0;

    for i, sample in ipairs(samples) do
        local ev = {
            direction = sample[1],
            kind = sample[2],
            text = sample[3],
            event_type = sample[4],
            created = os.clock(),
        };

        local obj = state.preview_font_pool[i];
        local scale = event_scale(ev, 0);
        local height = math.max(8, math.floor(16 * scale + 0.5));
        local line_height = math.max(20, height + 5);

        if i == 5 then
            y = y + 8;
            used_height = used_height + 8;
        end

        if obj then
            local family = tostring(settings.font_family or 'Consolas');
            if obj.font_family ~= family then obj.font_family = family; end
            if obj.font_height ~= height then obj.font_height = height; end

            local bold = settings.font_bold == true;
            local italic = settings.font_italic == true;
            if obj.bold ~= bold then obj.bold = bold; end
            if obj.italic ~= italic then obj.italic = italic; end

            local preview_draw_flags = FontDrawFlags.None;
            if settings.font_outline == true then
                preview_draw_flags = bit.bor(preview_draw_flags, FontDrawFlags.Outlined);
            end
            if obj.draw_flags ~= preview_draw_flags then
                obj.draw_flags = preview_draw_flags;
            end

            local display_text = rendered_event_text(ev);
            if obj.text ~= display_text then obj.text = display_text; end
            if obj.position_x ~= start_x then obj.position_x = start_x; end
            if obj.position_y ~= y then obj.position_y = y; end

            local c = event_color(ev);
            local new_color = rgba_to_argb(c, 1.0);
            local new_outline = settings.font_outline == true
                and rgba_to_argb({ 0.0, 0.0, 0.0, 1.0 }, 1.0)
                or 0x00000000;

            if obj.color ~= new_color then obj.color = new_color; end
            if obj.color_outline ~= new_outline then obj.color_outline = new_outline; end
            if obj.visible ~= true then obj.visible = true; end
        end

        y = y + line_height;
        used_height = used_height + line_height;
    end

    -- Reserve the physical space occupied by FontManager text so the Tools
    -- section begins below the live preview instead of underneath it.
    imgui.Dummy({ 1, used_height });

    -- Hide any extra preview objects left from a future/older larger sample set.
    for i = #samples + 1, #state.preview_font_pool do
        local obj = state.preview_font_pool[i];
        if obj then obj.visible = false; end
    end
end

local function section_header(title, color)
    imgui.Spacing();
    imgui.TextColored(color or UI_ACCENT, title);
    imgui.Separator();
end

local function draw_bool_setting(label, current, key)
    local value = { current == true };
    if imgui.Checkbox(label, value) then
        settings[key] = value[1];
        save_settings();
    end
end

local function draw_event_option(label, key)
    ensure_event_option(key);

    local opt = settings.event_options[key];
    local shown = { opt.show ~= false };

    if imgui.Checkbox('##show_' .. key, shown) then
        opt.show = shown[1];
        save_settings();
    end

    imgui.SameLine();
    imgui.Text(label);
    imgui.SameLine();

    local c = {
        tonumber(opt.color[1]) or 1.0,
        tonumber(opt.color[2]) or 1.0,
        tonumber(opt.color[3]) or 1.0
    };

    if imgui.ColorEdit3('##color_' .. key, c, ImGuiColorEditFlags_NoInputs) then
        opt.color[1] = c[1];
        opt.color[2] = c[2];
        opt.color[3] = c[3];
        opt.color[4] = 1.0;
        save_settings();
    end
end

local function draw_lane_direction(key, title, accent)
    local lane = settings[key];

    imgui.TextColored(accent, title);

    imgui.Text('Text Direction');
    imgui.SameLine();
    if (lane.orientation or 'right') == 'left' then
        imgui.TextColored(UI_ACCENT, 'Left');
    elseif imgui.Button('Left##' .. key .. '_orient') then
        lane.orientation = 'left';
        save_settings();
    end

    imgui.SameLine();
    if (lane.orientation or 'right') == 'right' then
        imgui.TextColored(UI_ACCENT, 'Right');
    elseif imgui.Button('Right##' .. key .. '_orient') then
        lane.orientation = 'right';
        save_settings();
    end

    imgui.TextDisabled('Left = text extends left from anchor; Right = extends right.');
    imgui.Text('Growth');
    imgui.SameLine();
    if (lane.growth or 'up') == 'up' then
        imgui.TextColored(UI_ACCENT, 'Up');
    elseif imgui.Button('Up##' .. key .. '_growth') then
        lane.growth = 'up';
        save_settings();
    end

    imgui.SameLine();
    if (lane.growth or 'up') == 'down' then
        imgui.TextColored(UI_ACCENT, 'Down');
    elseif imgui.Button('Down##' .. key .. '_growth') then
        lane.growth = 'down';
        save_settings();
    end

    if settings.locked == true then
        imgui.TextColored(UI_MUTED, ('Position locked at %.0f, %.0f'):fmt(
            tonumber(lane.x) or 0,
            tonumber(lane.y) or 0
        ));
    else
        imgui.PushItemWidth(105);
        local x = { tonumber(lane.x) or 0 };
        local y = { tonumber(lane.y) or 0 };

        if imgui.InputFloat('X##' .. key, x, 5.0, 20.0, '%.0f') then
            lane.x = x[1];
            save_settings();
        end
        imgui.SameLine();
        if imgui.InputFloat('Y##' .. key, y, 5.0, 20.0, '%.0f') then
            lane.y = y[1];
            save_settings();
        end
        imgui.PopItemWidth();
    end
end

local function add_test_events()
    add_event('outgoing', 'outgoing', '34' .. target_suffix('Diving Beetle'), 'melee_damage');
    add_event('outgoing', 'critical', '88' .. target_suffix('Diving Beetle'), 'criticals');
    add_event('outgoing', 'outgoing', '74' .. target_suffix('Diving Beetle'), 'ranged_damage');
    add_event('outgoing', 'ability', 'Fast Blade  156' .. target_suffix('Diving Beetle'), 'weapon_skills');
    add_event('outgoing', 'ability', 'Light  84' .. target_suffix('Diving Beetle'), 'skillchains');
    add_event('outgoing', 'ability', 'Bludgeon  48' .. target_suffix('Diving Beetle') .. ' [MB]', 'magic_bursts');
    add_event('outgoing', 'ability', 'Additional: Fire +12' .. target_suffix('Diving Beetle'), 'additional_effects');
    add_event('outgoing', 'ability', 'Cocoon  ->  You', 'buffs');
    add_event('incoming', 'incoming', '-24' .. source_suffix('Diving Beetle'), 'incoming_damage');
    add_event('incoming', 'miss', 'PARRY' .. source_suffix('Diving Beetle'), 'defenses');
    add_event('incoming', 'ability', 'Slow' .. source_suffix('Diving Beetle'), 'status_negative');
    add_event('incoming', 'heal', '+93 HP  <-  Pollen', 'healing_received');
    add_event('incoming', 'heal', '+24 MP  <-  Refresh', 'mp_recovery');
    add_event('incoming', 'xp', '+189 EXP', 'exp');
    add_event('incoming', 'gil', '+9 gil', 'gil');
    add_event('incoming', 'xp', 'Sword +0.3', 'skill_ups');
    add_event('incoming', 'xp', 'Beastman Seal', 'item_drops');
end

local function draw_general_config_tab()
    section_header('DISPLAY & BEHAVIOR', UI_ACCENT);

    imgui.PushItemWidth(235);

    local duration = { tonumber(settings.duration) or 3.5 };
    if imgui.SliderFloat('Display Time##scl', duration, 0.5, 12.0, '%.1f sec') then
        settings.duration = duration[1];
        save_settings();
    end

    local speed = { tonumber(settings.scroll_speed) or 70.0 };
    if imgui.SliderFloat('Scroll Speed##scl', speed, 0.0, 300.0, '%.0f px/s') then
        settings.scroll_speed = speed[1];
        save_settings();
    end

    local global_font = { tonumber(settings.font_scale) or 1.35 };
    if imgui.SliderFloat('Global Font##scl', global_font, 0.75, 3.00, '%.2fx') then
        settings.font_scale = global_font[1];
        save_settings();
    end

    local max_visible = { math.floor(tonumber(settings.max_visible_events) or 14) };
    if imgui.SliderInt('Maximum Visible Events##scl', max_visible, 4, 30) then
        settings.max_visible_events = max_visible[1];
        save_settings();
    end

    imgui.PopItemWidth();
    help_marker('Caps active scrolling rows to keep heavy combat readable and predictable.');

    imgui.Spacing();
    section_header('CONTENT', UI_ACCENT);

    local symbols = { settings.show_symbols == true };
    if imgui.Checkbox('Event Symbols / Prefixes', symbols) then
        settings.show_symbols = symbols[1];
        save_settings();
    end

    local targets = { settings.show_target_names ~= false };
    if imgui.Checkbox('Show Outgoing Target Names', targets) then
        settings.show_target_names = targets[1];
        save_settings();
    end
    help_marker('When disabled, outgoing damage/spells omit the "-> Target" suffix.');

    local sources = { settings.show_source_names ~= false };
    if imgui.Checkbox('Show Incoming Source Names', sources) then
        settings.show_source_names = sources[1];
        save_settings();
    end
    help_marker('When disabled, incoming damage/effects omit the "<- Source" suffix.');

    local zeroes = { settings.show_zero_damage == true };
    if imgui.Checkbox('Show 0 Damage / No-Damage Results', zeroes) then
        settings.show_zero_damage = zeroes[1];
        save_settings();
    end
    help_marker('Shows numeric zero-damage results. Full resists can still appear as [RESIST].');

    local misses = { settings.show_misses ~= false };
    if imgui.Checkbox('Show Misses', misses) then
        settings.show_misses = misses[1];
        save_settings();
    end

    local combine = { settings.combine_repeated_hits ~= false };
    if imgui.Checkbox('Combine Rapid Repeated Hits', combine) then
        settings.combine_repeated_hits = combine[1];
        save_settings();
    end
    help_marker('Merges rapid melee/ranged hits from the same source/target into "total (N hits)".');

    imgui.Spacing();
    section_header('POSITIONING', UI_ACCENT);

    local locked = { settings.locked == true };
    if imgui.Checkbox('Lock Positions', locked) then
        settings.locked = locked[1];

        if settings.locked then
            state.move_mode = false;
        else
            state.move_mode = true;
            state.move_initialized.incoming = false;
            state.move_initialized.outgoing = false;
        end

        save_settings();
    end
    help_marker('Unlocked positions immediately show the draggable Incoming and Outgoing anchor boxes.');
end

local function draw_font_style_config_tab()
    section_header('FONT STYLE', UI_ACCENT);

    imgui.Text('Renderer');
    imgui.SameLine();

    if (settings.renderer_mode or 'performance') == 'performance' then
        imgui.TextColored(UI_GREEN, 'Performance');
    elseif imgui.Button('Performance##renderer') then
        settings.renderer_mode = 'performance';
        hide_unused_fonts(1);
        save_settings();
    end

    imgui.SameLine();

    if (settings.renderer_mode or 'performance') == 'custom' then
        imgui.TextColored(UI_GOLD, 'Custom Font');
    elseif imgui.Button('Custom Font##renderer') then
        settings.renderer_mode = 'custom';
        rebuild_font_pool();
        save_settings();
    end

    if (settings.renderer_mode or 'performance') == 'performance' then
        imgui.TextColored(
            UI_MUTED,
            'Recommended: smooth ImGui renderer. Font family/bold/italic/outline are disabled.'
        );
    else
        imgui.TextColored(
            UI_MUTED,
            'Custom Font uses one FontManager object per visible row. Outline remains supported.'
        );
    end

    imgui.Spacing();

    imgui.Text('Font Family');
    imgui.SameLine();
    if imgui.Button('<##font_family_prev') then
        cycle_font_family(-1);
    end
    imgui.SameLine();
    imgui.TextColored(UI_GOLD, tostring(settings.font_family or 'Consolas'));
    imgui.SameLine();
    if imgui.Button('>##font_family_next') then
        cycle_font_family(1);
    end

    local bold = { settings.font_bold == true };
    if imgui.Checkbox('Bold', bold) then
        settings.font_bold = bold[1];
        save_settings();
    end
    imgui.SameLine();

    local italic = { settings.font_italic == true };
    if imgui.Checkbox('Italic', italic) then
        settings.font_italic = italic[1];
        save_settings();
    end
    imgui.SameLine();

    local outline = { settings.font_outline == true };
    if imgui.Checkbox('Outline', outline) then
        settings.font_outline = outline[1];
        save_settings();
    end

    if (settings.renderer_mode or 'performance') == 'performance' then
        imgui.TextColored(
            UI_MUTED,
            'Outline works in Performance mode. Font Family / Bold / Italic apply only to Custom Font.'
        );
    else
        imgui.TextColored(
            UI_MUTED,
            'Custom Font uses installed Windows fonts; native FontManager Outline is enabled here.'
        );
    end

    imgui.Spacing();
    section_header('TYPOGRAPHY', UI_GOLD);

    imgui.PushItemWidth(235);

    local melee = { tonumber(settings.melee_scale) or 1.00 };
    if imgui.SliderFloat('Normal Damage##scale', melee, 0.60, 2.00, '%.2fx') then
        settings.melee_scale = melee[1];
        save_settings();
    end

    local ability = { tonumber(settings.ability_scale) or 1.00 };
    if imgui.SliderFloat('Abilities / WS##scale', ability, 0.60, 2.00, '%.2fx') then
        settings.ability_scale = ability[1];
        save_settings();
    end

    local heal = { tonumber(settings.heal_scale) or 1.00 };
    if imgui.SliderFloat('Healing##scale', heal, 0.60, 2.00, '%.2fx') then
        settings.heal_scale = heal[1];
        save_settings();
    end

    local reward = { tonumber(settings.reward_scale) or 1.00 };
    if imgui.SliderFloat('Rewards##scale', reward, 0.60, 2.00, '%.2fx') then
        settings.reward_scale = reward[1];
        save_settings();
    end

    imgui.PopItemWidth();

    imgui.TextColored(
        UI_MUTED,
        'Criticals use Normal Damage size; * prefix and Critical color identify them.'
    );
end

local function draw_outgoing_config_tab()
    section_header('OUTGOING EVENTS', UI_GREEN);

    draw_event_option('Melee Damage', 'melee_damage');
    draw_event_option('Ranged Damage', 'ranged_damage');
    draw_event_option('Criticals', 'criticals');
    draw_event_option('Weapon Skills', 'weapon_skills');
    draw_event_option('Spells', 'spells');
    draw_event_option('Magic Bursts', 'magic_bursts');
    draw_event_option('Skillchains', 'skillchains');
    draw_event_option('Abilities', 'outgoing_abilities');
    draw_event_option('Pet Damage', 'pet_damage');
    draw_event_option('Additional Effects', 'additional_effects');
    draw_event_option('Counters / Retaliation', 'counters');
    draw_event_option('Buffs', 'buffs');

    imgui.Spacing();
    section_header('OUTGOING LAYOUT', UI_GREEN);
    draw_lane_direction('outgoing', 'Outgoing Layout', UI_GREEN);
end

local function draw_incoming_config_tab()
    section_header('INCOMING EVENTS', UI_RED);

    draw_event_option('Incoming Damage', 'incoming_damage');
    draw_event_option('Incoming Abilities', 'incoming_abilities');
    draw_event_option('Defenses (Evade/Parry/Block)', 'defenses');
    draw_event_option('Positive Status', 'status_positive');
    draw_event_option('Negative Status', 'status_negative');
    draw_event_option('Status Removed', 'status_removed');
    draw_event_option('Healing Received', 'healing_received');
    draw_event_option('MP Recovery', 'mp_recovery');
    draw_event_option('Drain / Aspir', 'drain_aspir');
    draw_event_option('KO / Defeat', 'ko');

    imgui.Spacing();
    section_header('INCOMING LAYOUT', UI_RED);
    draw_lane_direction('incoming', 'Incoming Layout', UI_RED);

    imgui.Spacing();
    section_header('REWARDS', UI_GOLD);

    draw_event_option('EXP / LP / CP / JP', 'exp');
    draw_event_option('Gil', 'gil');
    draw_event_option('Level Up', 'level_up');
    draw_event_option('Skill Ups', 'skill_ups');
    draw_event_option('Item Drops', 'item_drops');
end


local function geometry_changed(last, x, y, w, h)
    if not last then return true end
    return math.abs((last.x or 0) - x) >= 1
        or math.abs((last.y or 0) - y) >= 1
        or math.abs((last.w or 0) - w) >= 1
        or math.abs((last.h or 0) - h) >= 1;
end

local function persist_window_geometry(which, x, y, w, h)
    local target = which == 'main' and settings.config_window or settings.config_tools_window;
    if not target then return end

    target.x = math.floor(x + 0.5);
    target.y = math.floor(y + 0.5);
    target.w = math.floor(w + 0.5);
    target.h = math.floor(h + 0.5);

    local now = os.clock();
    if (now - (state.config_geometry.last_save_clock or 0)) >= 0.35 then
        state.config_geometry.last_save_clock = now;
        save_settings();
    end
end

local function capture_current_window_geometry(which)
    -- Current Ashita v4 imgui.GetWindowPos() / GetWindowSize() return
    -- TWO numeric values, not an ImVec2/table. Indexing the first return value
    -- triggers the sugar math namespace error seen in 1.0.4.
    local x, y = imgui.GetWindowPos();
    local w, h = imgui.GetWindowSize();

    x = tonumber(x);
    y = tonumber(y);
    w = tonumber(w);
    h = tonumber(h);

    if x == nil or y == nil or w == nil or h == nil then
        return;
    end

    local last_key = which == 'main' and 'last_main' or 'last_tools';
    local last = state.config_geometry[last_key];

    if geometry_changed(last, x, y, w, h) then
        state.config_geometry[last_key] = { x = x, y = y, w = w, h = h };
        persist_window_geometry(which, x, y, w, h);
    end
end

local function draw_config_companion()
    if not state.config_geometry.tools_initialized then
        imgui.SetNextWindowPos({
            tonumber(settings.config_tools_window.x) or defaults.config_tools_window.x,
            tonumber(settings.config_tools_window.y) or defaults.config_tools_window.y
        });
        imgui.SetNextWindowSize({
            tonumber(settings.config_tools_window.w) or defaults.config_tools_window.w,
            tonumber(settings.config_tools_window.h) or defaults.config_tools_window.h
        });
        state.config_geometry.tools_initialized = true;
    end

    if imgui.Begin('SCL Preview & Tools##scl_config_tools', nil, ImGuiWindowFlags_NoNav) then
        capture_current_window_geometry('tools');
        imgui.TextColored(UI_ACCENT, 'LIVE PREVIEW');
        imgui.Separator();
        draw_live_preview();

        imgui.Spacing();
        section_header('TOOLS & RESET', UI_ACCENT);

        if imgui.Button('Test Display') then
            add_test_events();
        end
        imgui.SameLine();
        if imgui.Button('Clear Active Text') then
            state.events = {};
            hide_unused_fonts(1);
        end

        if imgui.Button('Reset Outgoing Position') then
            reset_anchor('outgoing');
        end
        imgui.SameLine();
        if imgui.Button('Reset Incoming Position') then
            reset_anchor('incoming');
        end

        if not state.confirm_reset_all then
            if imgui.Button('Reset All Settings') then
                state.confirm_reset_all = true;
            end
        else
            imgui.TextColored(UI_RED, 'Reset every SCL setting?');
            if imgui.Button('Confirm Reset All') then
                reset_all_settings();
            end
            imgui.SameLine();
            if imgui.Button('Cancel Reset') then
                state.confirm_reset_all = false;
            end
        end

        imgui.Spacing();
        section_header('COMMANDS', UI_ACCENT);
        imgui.TextColored(UI_MUTED, '/scl config  - close/open configuration');
        imgui.TextColored(UI_MUTED, '/scl unlock  - show draggable anchor boxes');
        imgui.TextColored(UI_MUTED, '/scl lock    - save/lock positions');
        imgui.TextColored(UI_MUTED, '/scl test    - show sample events');
        imgui.TextColored(UI_MUTED, '/scl clear   - clear active text');
        imgui.TextColored(UI_MUTED, '/scl pause   - pause/resume capture');
    end
    imgui.End();
end

local function draw_config()
    if not state.config_open[1] then
        hide_preview_fonts();
        state.config_geometry.main_initialized = false;
        state.config_geometry.tools_initialized = false;
        state.config_geometry.last_main = nil;
        state.config_geometry.last_tools = nil;
        return;
    end

    imgui.PushStyleColor(ImGuiCol_WindowBg, UI_BG);
    imgui.PushStyleColor(ImGuiCol_TitleBg, UI_TITLE);
    imgui.PushStyleColor(ImGuiCol_TitleBgActive, UI_TITLE);
    imgui.PushStyleColor(ImGuiCol_Border, UI_BORDER);
    imgui.PushStyleColor(ImGuiCol_Button, { 0.10, 0.18, 0.24, 1.00 });
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.14, 0.28, 0.38, 1.00 });
    imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.16, 0.34, 0.46, 1.00 });

    if not state.config_geometry.main_initialized then
        imgui.SetNextWindowPos({
            tonumber(settings.config_window.x) or defaults.config_window.x,
            tonumber(settings.config_window.y) or defaults.config_window.y
        });
        imgui.SetNextWindowSize({
            tonumber(settings.config_window.w) or defaults.config_window.w,
            tonumber(settings.config_window.h) or defaults.config_window.h
        });
        state.config_geometry.main_initialized = true;
    end

    imgui.SetNextWindowSizeConstraints({ 620, 560 }, { 1200, 1200 });

    if imgui.Begin('Scrolling Combat Text - Config##scl_config', state.config_open, ImGuiWindowFlags_NoNav) then
        capture_current_window_geometry('main');
        imgui.TextColored(UI_ACCENT, 'SELF-ONLY COMBAT DISPLAY');
        imgui.SameLine();
        imgui.TextColored(UI_MUTED, 'v1.0.10');
        imgui.TextDisabled('Outgoing actions, incoming effects, and personal rewards only.');

        imgui.Spacing();

        if imgui.BeginTabBar('##scl_config_tabs') then
            if imgui.BeginTabItem('General') then
                draw_general_config_tab();
                imgui.EndTabItem();
            end

            if imgui.BeginTabItem('Font Style') then
                draw_font_style_config_tab();
                imgui.EndTabItem();
            end

            if imgui.BeginTabItem('Outgoing') then
                draw_outgoing_config_tab();
                imgui.EndTabItem();
            end

            if imgui.BeginTabItem('Incoming') then
                draw_incoming_config_tab();
                imgui.EndTabItem();
            end

            imgui.EndTabBar();
        end
    end
    imgui.End();

    if state.config_open[1] then
        imgui.SetNextWindowSizeConstraints({ 380, 520 }, { 800, 1200 });
        draw_config_companion();
    end

    imgui.PopStyleColor(7);
end

-- Ashita v4 settings are per-character and can be replaced after login or a
-- character switch. Keep SCL's local settings reference pointed at the active
-- character table instead of continuing to use startup defaults.
ashita_settings.register('settings', 'scrollingcombatlog_settings_update', function(s)
    if s == nil then
        return;
    end

    settings = s;
    normalize_loaded_settings();

    state.move_mode = settings.locked == false;
    state.move_initialized.incoming = false;
    state.move_initialized.outgoing = false;

    state.config_geometry.main_initialized = false;
    state.config_geometry.tools_initialized = false;
    state.config_geometry.last_main = nil;
    state.config_geometry.last_tools = nil;

    state.xp_watch.initialized = false;
    state.combine = {};

    rebuild_font_pool();
end);

ashita.events.register('command', 'scl_scroll_command_cb', function(e)
    if not e or not e.command then return end
    local args = e.command:args();
    if #args == 0 or args[1] ~= '/scl' then return end

    e.blocked = true;
    local sub = (args[2] or ''):lower();

    if sub == '' then
        settings.enabled = not settings.enabled; save_settings();
        print(('[SCL] %s'):fmt(settings.enabled and 'Enabled.' or 'Hidden.'));
    elseif sub == 'config' or sub == 'settings' then
        state.config_open[1] = not state.config_open[1];
        if state.config_open[1] then
            state.config_size_initialized = false;
        end
    elseif sub == 'pause' then
        state.paused = not state.paused;
        print(('[SCL] %s'):fmt(state.paused and 'Paused.' or 'Resumed.'));
    elseif sub == 'lock' then
        settings.locked = true;
        state.move_mode = false;
        save_settings();
        print('[SCL] Positions locked. Move handles hidden.');

    elseif sub == 'unlock' then
        settings.locked = false;
        state.move_mode = true;
        state.move_initialized.incoming = false;
        state.move_initialized.outgoing = false;
        save_settings();
        print('[SCL] Positions unlocked. Drag the Incoming / Outgoing anchor windows.');
    elseif sub == 'clear' then
        state.events = {};
        hide_unused_fonts(1);
    elseif sub == 'test' then
        add_test_events();
    elseif sub == 'help' then
        print('[SCL] /scl - toggle display');
        print('[SCL] /scl config - open configuration');
        print('[SCL] /scl test - show sample scrolling events');
        print('[SCL] /scl unlock - unlock positions and show draggable anchors');
        print('[SCL] /scl lock - lock positions and hide draggable anchors');
        print('[SCL] /scl pause - pause/resume capture');
        print('[SCL] /scl clear - clear active events');
    end
end);

ashita.events.register('d3d_present', 'scl_scroll_present_cb', function()
    update_exp_memory_watch();
    draw_events();
    draw_config();
    draw_move_mode();
end);

ashita.events.register('unload', 'scl_scroll_unload_cb', function()
    destroy_font_pool();
    save_settings();
end);

print(('[SCL] Loaded version %s (self-only / packet-driven).'):fmt(addon.version));
