--[[
    Azure Codex (orig BLUSpells) - Ashita v4 / HorizonXI
    Version 1.12.1

    Commands:
      /azurecodex
      /ac
      /bluspells   (legacy alias)
      /bsp         (legacy alias)
      /bsl         (legacy alias)
      /azurecodex config
      /ac config
      /acz          (Zone Info)
      /ac farm      (Farm Zones)
      /ac log       (Learned Log)

    Main goals:
      * Clean IzClock-style dark presentation.
      * Learned / missing / level-ready filtering.
      * Search across every visible data field with "|" OR searches.
      * Clickable sortable/resizable table headers.
      * Persistent filters/sort/search when desired.
      * Completion percentage/progress and missing count.
      * Selectable rows and newly-learned highlighting.
      * Configurable columns, colors, paging, spacing, font, window appearance.
]]--

addon.name      = 'azurecodex';
addon.author    = 'Izumi (ShiroIzumi) / Kyrias (.kyri)';
addon.version   = '1.12.1';
addon.desc      = 'Azure Codex (orig BLUSpells) - HorizonXI Blue Magic learning, location, build, trait, and spell-set toolkit.';
addon.link      = '';

require 'common';
local ffi = require 'ffi';
local ok_blu, blu = pcall(require, 'blu');
if not ok_blu then blu = nil; end
local ok_chat, chat = pcall(require, 'chat');
if not ok_chat then chat = nil; end

local imgui = require 'imgui';
local settings = require 'settings';
local spells = require 'spells';
local locations = require 'locations';

local function log_message(text)
    if chat ~= nil and chat.header ~= nil and chat.message ~= nil then
        print(chat.header(addon.name):append(chat.message(text)));
    else
        print('[Azure Codex] ' .. tostring(text));
    end
end

-- Optional external blu helper.
-- Some Ashita setups do not expose addons/blusets/blu.lua as a Lua module.
-- In that case, provide the equip subset locally using the same packet format
-- and behavior as Ashita's official blusets blu.lua helper.
if blu == nil then
    local ok_fallback, fallback_blu = pcall(function()
        ffi.cdef[[
            typedef uint8_t (__cdecl *bluspells_equipex_t)(uint8_t isSubJob, uint16_t jobType, uint16_t index, uint8_t id);

            typedef struct {
                uint16_t IdSize;
                uint16_t Sync;
                uint8_t SpellId;
                uint8_t Unknown0000;
                uint16_t Unknown0001;
                uint8_t JobId;
                uint8_t IsSubJob;
                uint16_t Unknown0002;
                uint8_t Spells[20];
                uint8_t Unknown0003[132];
            } bluspells_packet_equipex_t;
        ]]

        local helper = T{
            -- The official helper defaults to safe mode, but the packet path
            -- is more reliable for this embedded fallback on this client.
            mode = 'fast',
            delay = 1.0,
            offset = ffi.cast('uint32_t*', ashita.memory.find(0, 0, 'C1E1032BC8B0018D????????????B9????????F3A55F5E5B', 10, 0)),
            points = ffi.cast('uint8_t***', ashita.memory.find(0, 0, 'A1????????33C98A4E5E33D28A565D5F5E8950148948185B83C414C20400', 1, 0)),
            equipex = ffi.cast('bluspells_equipex_t', ashita.memory.find(0, 0, '8B0D????????81EC9C00000085C95356570F??????????8B', 0, 0)),
        }

        if helper.offset == nil or helper.points == nil or helper.equipex == nil then
            return nil
        end

        function helper.is_blu_main()
            local mm = AshitaCore:GetMemoryManager()
            if not mm then return false end
            local player = mm:GetPlayer()
            if not player then return false end
            return player:GetMainJob() == 16
        end

        function helper.is_blu_sub()
            local mm = AshitaCore:GetMemoryManager()
            if not mm then return false end
            local player = mm:GetPlayer()
            if not player then return false end
            return player:GetSubJob() == 16
        end

        function helper.get_blu_buffer_ptr()
            local ptr = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('inventory'))
            if ptr == 0 then return 0 end
            ptr = ashita.memory.read_uint32(ptr)
            if ptr == 0 then return 0 end
            return ptr + helper.offset[0] + (helper.is_blu_main() and 0x00 or 0x9C)
        end

        function helper.get_spells()
            local ptr = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('inventory'))
            if ptr == 0 then return T{} end
            ptr = ashita.memory.read_uint32(ptr)
            if ptr == 0 then return T{} end
            return T(ashita.memory.read_array((ptr + helper.offset[0]) + (helper.is_blu_main() and 0x04 or 0xA0), 0x14))
        end

        local function safe_reset_all_spells()
            AshitaCore:GetPacketManager():QueuePacket(0x102, 0xA4, 0x00, 0x00, 0x00, function(ptr)
                local p = ffi.cast('uint8_t*', ptr)
                ffi.fill(p + 0x04, 0xA0)
                ffi.copy(p + 0x08, ffi.cast('uint8_t*', helper.get_blu_buffer_ptr()), 0x9C)
            end)
        end

        local function unsafe_reset_all_spells()
            local eqex = ffi.new('bluspells_packet_equipex_t', {
                0x5302, 0x0000,
                0,
                0, 0,
                0x10, helper.is_blu_sub() and 1 or 0,
                0
            })

            local current = helper.get_spells()
            for x = 1, #current do
                eqex.Spells[x - 1] = current[x]
            end

            local packet = ffi.string(eqex, ffi.sizeof('bluspells_packet_equipex_t')):totable()
            AshitaCore:GetPacketManager():AddOutgoingPacket(0x102, packet)
        end

        local function safe_set_spell(index, id)
            return helper.equipex(helper.is_blu_main() and 0 or 1, 0x1000, index - 1, id)
        end

        local function unsafe_set_spell(index, id)
            local eqex = ffi.new('bluspells_packet_equipex_t', {
                0x5302, 0x0000,
                0,
                0, 0,
                0x10, helper.is_blu_sub() and 1 or 0,
                0
            })

            if id == 0 then
                eqex.SpellId = 0
                eqex.Spells[index - 1] = helper.get_spells()[index]
            else
                eqex.SpellId = id
                eqex.Spells[index - 1] = id
            end

            local packet = ffi.string(eqex, ffi.sizeof('bluspells_packet_equipex_t')):totable()
            AshitaCore:GetPacketManager():AddOutgoingPacket(0x102, packet)
        end

        function helper.reset_all_spells()
            if helper.mode == 'fast' then
                unsafe_reset_all_spells()
            else
                safe_reset_all_spells()
            end
            return true
        end

        function helper.set_spell(index, id)
            index = tonumber(index) or 0
            id = tonumber(id) or 0
            if index <= 0 or index > 20 then return false end

            local current = helper.get_spells()
            if id ~= 0 then
                for _, value in ipairs(current) do
                    if tonumber(value) == id then
                        return false
                    end
                end
            elseif current[index] == nil or tonumber(current[index]) == 0 then
                return true
            end

            if helper.mode == 'fast' then
                unsafe_set_spell(index, id)
            else
                safe_set_spell(index, id)
            end
            return true
        end

        function helper.set_spell_by_name(index, name)
            if name == nil or tostring(name) == '' then
                return helper.set_spell(index, 0)
            end

            local resource = AshitaCore:GetResourceManager():GetSpellByName(tostring(name), 0)
            if resource == nil then return false end
            if resource.Index < 512 or resource.Index > 1024 then return false end
            return helper.set_spell(index, resource.Index - 512)
        end

        return helper
    end)

    if ok_fallback and fallback_blu ~= nil then
        blu = fallback_blu
    end
end

local defaults = T{
    font_scale = 1.00,

    appearance = T{
        -- Midnight blue (#010022) window base.
        background = T{ 0.004, 0.000, 0.133, 1.00 },
        border = true,
        title_bar = true,
        locked = false,
        zone_locked = false,
        location_locked = false,
        known_color = T{ 0.30, 1.00, 0.42, 1.00 },
        learnable_color = T{ 1.00, 0.82, 0.20, 1.00 },
        -- Kept as unknown_color internally for backward-compatible settings.
        -- This now represents Unknown / Unlearnable.
        unknown_color = T{ 1.00, 0.34, 0.38, 1.00 },
        header_color = T{ 0.38, 0.78, 1.00, 1.00 },
        paging_color = T{ 0.62, 0.12, 0.14, 1.00 },
        -- Window surface theme: 'midnight' (default), 'abyss', 'twilight'.
        theme = 'midnight',
    },

    display = T{
        row_spacing = 'compact',
        rows_mode = 'auto',
        rows_per_page = 30,
        columns = T{
            level = true,
            points = true,
            learn_skill = true,
            type = true,
            trait = true,
            mob_family = true,
        },
    },

    behavior = T{
        remember_filters = true,
        auto_highlight_learned = true,
        location_interaction = 'click',
        -- "Teaches:" tag for a targeted mob that teaches a spell you are
        -- missing (current zone, BLU main only).
        target_tag = true,
        target_tag_locked = false,
        assimilation = 0,
    },

    target_tag_window = T{ x = 900, y = 260 },
    farm_window = T{ x = 1040, y = 160, width = 520, height = 560 },
    log_window = T{ x = 1060, y = 180, width = 560, height = 460 },

    -- Per-character history of newly learned spells.
    learned_log = T{},

    ui_state = T{
        search = '',
        filter_mode = 'all',
        sort_mode = 'level',
        sort_desc = false,
    },

    window = T{
        x = 100,
        y = 100,
        width = 900,
        height = 860,
    },

    config_window = T{
        x = 1020,
        y = 140,
        width = 430,
        height = 560,
    },

    zone_window = T{
        x = 1020,
        y = 220,
        width = 760,
        height = 520,
    },
};

local config = settings.load(defaults);

-- Previous default window colors. Saved settings that still use one exactly
-- are moved to the current midnight blue default; custom colors are left untouched.
local LEGACY_BACKGROUNDS = {
    { 0.018, 0.024, 0.032 },
    { 0.008, 0.000, 0.208 },
};

local function ensure_tables()
    if config.appearance == nil then config.appearance = T{}; end
    if config.appearance.background == nil then config.appearance.background = T{}; end
    if config.appearance.known_color == nil then config.appearance.known_color = T{}; end
    if config.appearance.learnable_color == nil then config.appearance.learnable_color = T{}; end
    if config.appearance.unknown_color == nil then config.appearance.unknown_color = T{}; end
    if config.appearance.header_color == nil then config.appearance.header_color = T{}; end
    if config.appearance.paging_color == nil then config.appearance.paging_color = T{}; end

    if config.display == nil then config.display = T{}; end
    if config.display.columns == nil then config.display.columns = T{}; end

    if config.behavior == nil then config.behavior = T{}; end
    if config.ui_state == nil then config.ui_state = T{}; end
    if config.window == nil then config.window = T{}; end
    if config.config_window == nil then config.config_window = T{}; end
    if config.zone_window == nil then config.zone_window = T{}; end
    if config.target_tag_window == nil then config.target_tag_window = T{}; end
    if config.farm_window == nil then config.farm_window = T{}; end
    if config.log_window == nil then config.log_window = T{}; end
    if config.learned_log == nil then config.learned_log = T{}; end
    if config.appearance.theme == nil then config.appearance.theme = 'midnight'; end
    if config.behavior.target_tag == nil then config.behavior.target_tag = true; end
    if config.behavior.target_tag_locked == nil then config.behavior.target_tag_locked = false; end
    if config.behavior.assimilation == nil then config.behavior.assimilation = 0; end
    for key, value in pairs(defaults.target_tag_window) do
        if config.target_tag_window[key] == nil then config.target_tag_window[key] = value; end
    end
    for key, value in pairs(defaults.farm_window) do
        if config.farm_window[key] == nil then config.farm_window[key] = value; end
    end
    for key, value in pairs(defaults.log_window) do
        if config.log_window[key] == nil then config.log_window[key] = value; end
    end

    local function fill_color(dst, src)
        for i = 1, 4 do
            if dst[i] == nil then dst[i] = src[i]; end
        end
    end

    fill_color(config.appearance.background, defaults.appearance.background);
    fill_color(config.appearance.known_color, defaults.appearance.known_color);
    fill_color(config.appearance.learnable_color, defaults.appearance.learnable_color);
    fill_color(config.appearance.unknown_color, defaults.appearance.unknown_color);
    fill_color(config.appearance.header_color, defaults.appearance.header_color);
    fill_color(config.appearance.paging_color, defaults.appearance.paging_color);

    local uses_legacy_background = false;
    for _, legacy in ipairs(LEGACY_BACKGROUNDS) do
        local matches = true;
        for i = 1, 3 do
            local value = tonumber(config.appearance.background[i]);
            if value == nil or math.abs(value - legacy[i]) > 0.001 then
                matches = false;
            end
        end
        if matches then
            uses_legacy_background = true;
        end
    end
    if uses_legacy_background then
        for i = 1, 3 do
            config.appearance.background[i] = defaults.appearance.background[i];
        end
    end

    if config.appearance.border == nil then config.appearance.border = defaults.appearance.border; end
    if config.appearance.title_bar == nil then config.appearance.title_bar = defaults.appearance.title_bar; end
    if config.appearance.locked == nil then config.appearance.locked = defaults.appearance.locked; end

    if config.display.row_spacing == nil then config.display.row_spacing = defaults.display.row_spacing; end
    if config.display.rows_mode == nil then config.display.rows_mode = defaults.display.rows_mode; end
    if config.display.rows_per_page == nil then config.display.rows_per_page = defaults.display.rows_per_page; end

    for key, value in pairs(defaults.display.columns) do
        if config.display.columns[key] == nil then
            config.display.columns[key] = value;
        end
    end

    if config.behavior.remember_filters == nil then
        config.behavior.remember_filters = defaults.behavior.remember_filters;
    end
    if config.behavior.auto_highlight_learned == nil then
        config.behavior.auto_highlight_learned = defaults.behavior.auto_highlight_learned;
    end
    if config.behavior.location_interaction == nil then
        config.behavior.location_interaction = defaults.behavior.location_interaction;
    end
    if config.behavior.location_interaction ~= 'hover' then
        config.behavior.location_interaction = 'click';
    end

    if config.ui_state.search == nil then config.ui_state.search = ''; end
    if config.ui_state.filter_mode == nil then config.ui_state.filter_mode = 'all'; end
    if config.ui_state.sort_mode == nil then config.ui_state.sort_mode = 'level'; end
    if config.ui_state.sort_desc == nil then config.ui_state.sort_desc = false; end

    for key, value in pairs(defaults.window) do
        if config.window[key] == nil then config.window[key] = value; end
    end

    for key, value in pairs(defaults.config_window) do
        if config.config_window[key] == nil then config.config_window[key] = value; end
    end

    for key, value in pairs(defaults.zone_window) do
        if config.zone_window[key] == nil then config.zone_window[key] = value; end
    end
end

ensure_tables();

local remember = config.behavior.remember_filters == true;

local state = T{
    open = { false },
    config_open = { false },

    search = { remember and tostring(config.ui_state.search or '') or '' },
    last_search = remember and tostring(config.ui_state.search or '') or '',
    filter_mode = remember and tostring(config.ui_state.filter_mode or 'all') or 'all',
    sort_mode = remember and tostring(config.ui_state.sort_mode or 'level') or 'level',
    sort_desc = remember and config.ui_state.sort_desc == true or false,

    page = 1,
    per_page = tonumber(config.display.rows_per_page) or 30,

    font_scale = { tonumber(config.font_scale) or 1.00 },

    background = {
        tonumber(config.appearance.background[1]) or defaults.appearance.background[1],
        tonumber(config.appearance.background[2]) or defaults.appearance.background[2],
        tonumber(config.appearance.background[3]) or defaults.appearance.background[3],
        tonumber(config.appearance.background[4]) or defaults.appearance.background[4],
    },

    known_color = {
        tonumber(config.appearance.known_color[1]) or defaults.appearance.known_color[1],
        tonumber(config.appearance.known_color[2]) or defaults.appearance.known_color[2],
        tonumber(config.appearance.known_color[3]) or defaults.appearance.known_color[3],
        tonumber(config.appearance.known_color[4]) or defaults.appearance.known_color[4],
    },

    learnable_color = {
        tonumber(config.appearance.learnable_color[1]) or defaults.appearance.learnable_color[1],
        tonumber(config.appearance.learnable_color[2]) or defaults.appearance.learnable_color[2],
        tonumber(config.appearance.learnable_color[3]) or defaults.appearance.learnable_color[3],
        tonumber(config.appearance.learnable_color[4]) or defaults.appearance.learnable_color[4],
    },

    unknown_color = {
        tonumber(config.appearance.unknown_color[1]) or defaults.appearance.unknown_color[1],
        tonumber(config.appearance.unknown_color[2]) or defaults.appearance.unknown_color[2],
        tonumber(config.appearance.unknown_color[3]) or defaults.appearance.unknown_color[3],
        tonumber(config.appearance.unknown_color[4]) or defaults.appearance.unknown_color[4],
    },

    header_color = {
        tonumber(config.appearance.header_color[1]) or defaults.appearance.header_color[1],
        tonumber(config.appearance.header_color[2]) or defaults.appearance.header_color[2],
        tonumber(config.appearance.header_color[3]) or defaults.appearance.header_color[3],
        tonumber(config.appearance.header_color[4]) or defaults.appearance.header_color[4],
    },

    paging_color = {
        tonumber(config.appearance.paging_color[1]) or defaults.appearance.paging_color[1],
        tonumber(config.appearance.paging_color[2]) or defaults.appearance.paging_color[2],
        tonumber(config.appearance.paging_color[3]) or defaults.appearance.paging_color[3],
        tonumber(config.appearance.paging_color[4]) or defaults.appearance.paging_color[4],
    },

    border = { config.appearance.border ~= false },
    title_bar = { config.appearance.title_bar ~= false },
    locked = { config.appearance.locked == true },
    zone_locked = { config.appearance.zone_locked == true },
    location_locked = { config.appearance.location_locked == true },

    row_spacing = tostring(config.display.row_spacing or 'compact'),
    rows_mode = tostring(config.display.rows_mode or 'auto'),
    rows_per_page = { tonumber(config.display.rows_per_page) or 30 },

    columns = {
        level = { config.display.columns.level ~= false },
        points = { config.display.columns.points ~= false },
        learn_skill = { config.display.columns.learn_skill ~= false },
        type = { config.display.columns.type ~= false },
        trait = { config.display.columns.trait ~= false },
        mob_family = { config.display.columns.mob_family ~= false },
    },

    remember_filters = { config.behavior.remember_filters == true },
    auto_highlight_learned = { config.behavior.auto_highlight_learned ~= false },
    location_interaction = tostring(config.behavior.location_interaction or 'click'),

    location_open = { false },
    location_spell = nil,
    location_apply_default_size = false,
    location_size_initialized = false,
    location_reset_scroll = false,

    zone_info_open = { false },
    zone_hide_known = { false },
    zone_apply_saved_geometry = true,
    zone_reset_scroll = false,
    zone_last_id = nil,
    zone_last_x = tonumber(config.zone_window.x) or defaults.zone_window.x,
    zone_last_y = tonumber(config.zone_window.y) or defaults.zone_window.y,
    zone_last_w = tonumber(config.zone_window.width) or defaults.zone_window.width,
    zone_last_h = tonumber(config.zone_window.height) or defaults.zone_window.height,

    selected_spell = nil,
    learned_flash_until = 0,
    jump_to_selected = false,
    known_snapshot = {},
    known_snapshot_initialized = false,

    apply_saved_geometry = true,
    last_x = tonumber(config.window.x) or defaults.window.x,
    last_y = tonumber(config.window.y) or defaults.window.y,
    last_w = tonumber(config.window.width) or defaults.window.width,
    last_h = tonumber(config.window.height) or defaults.window.height,

    apply_saved_config_geometry = true,
    config_last_x = tonumber(config.config_window.x) or defaults.config_window.x,
    config_last_y = tonumber(config.config_window.y) or defaults.config_window.y,
    config_last_w = tonumber(config.config_window.width) or defaults.config_window.width,
    config_last_h = tonumber(config.config_window.height) or defaults.config_window.height,

    geometry_dirty = false,
    config_geometry_dirty = false,
    zone_geometry_dirty = false,
    settings_dirty = false,
    last_save = 0,

    resource_ids = T{},
    resource_cache_ready = false,

    -- Current main-window geometry used to anchor the BLUPrint companion.
    main_frame_x = nil,
    main_frame_y = nil,
    main_frame_w = nil,
    main_frame_h = nil,

    -- Spell Build calculator state (session-only).
    build_search = { '' },
    build_name = { '' },
    build_selected = {},
    build_page = { false },
    build_equipping = { false },
    build_load_open = { false },
    build_load_files = {},
    spellsets_page = { false },
    bluprint_view_page = { false },
    bluprint_view_files = {},
    bluprint_view_selected = { '' },
    bluprint_view_spells = {},
    bluprint_view_delete_confirm = { false },
    spellsets_files = {},
    spellset_selected = { '' },

    -- 1.12.0
    theme = tostring(config.appearance.theme or 'midnight'),
    target_tag = { config.behavior.target_tag ~= false },
    target_tag_locked = { config.behavior.target_tag_locked == true },
    assimilation = { math.floor(tonumber(config.behavior.assimilation) or 0) },
    target_tag_apply_pos = true,
    target_tag_x = tonumber(config.target_tag_window.x) or 900,
    target_tag_y = tonumber(config.target_tag_window.y) or 260,
    farm_open = { false },
    farm_apply_geometry = true,
    farm_expanded = {},
    farm_learnable_only = { false },
    log_open = { false },
    log_apply_geometry = true,
    log_clear_confirm = false,
    loadout_pending = nil,
    planner_all = { false },
    last_defeat = nil,
};

-- Synchronize runtime state when Ashita switches from the startup/default
-- settings context to the active character's per-character settings file.
-- Ashita's official v4 addons register this callback for exactly this reason.
local ZONE_MIN_WIDTH = 430;
local ZONE_MAX_WIDTH = 900;

-- Spell Mob / Learned From window:
-- 500px is narrow enough to be useful on smaller screens while still
-- leaving long mob names readable in the single-column layout.
local LOCATION_MIN_WIDTH = 500;
local LOCATION_MAX_WIDTH = 900;
local LOCATION_TWO_COLUMN_WIDTH = 620;

local function clamp(value, low, high)
    value = tonumber(value) or low;
    if value < low then return low; end
    if value > high then return high; end
    return value;
end

local function apply_loaded_config(s)
    if s == nil then
        return
    end

    config = s
    ensure_tables()

    state.font_scale[1] = tonumber(config.font_scale) or defaults.font_scale

    for i = 1, 4 do
        state.background[i] = tonumber(config.appearance.background[i]) or defaults.appearance.background[i]
        state.known_color[i] = tonumber(config.appearance.known_color[i]) or defaults.appearance.known_color[i]
        state.learnable_color[i] = tonumber(config.appearance.learnable_color[i]) or defaults.appearance.learnable_color[i]
        state.unknown_color[i] = tonumber(config.appearance.unknown_color[i]) or defaults.appearance.unknown_color[i]
        state.header_color[i] = tonumber(config.appearance.header_color[i]) or defaults.appearance.header_color[i]
        state.paging_color[i] = tonumber(config.appearance.paging_color[i]) or defaults.appearance.paging_color[i]
    end

    state.border[1] = config.appearance.border ~= false
    state.title_bar[1] = config.appearance.title_bar ~= false
    state.locked[1] = config.appearance.locked == true
    state.zone_locked[1] = config.appearance.zone_locked == true
    state.location_locked[1] = config.appearance.location_locked == true

    state.row_spacing = tostring(config.display.row_spacing or defaults.display.row_spacing)
    state.rows_mode = tostring(config.display.rows_mode or defaults.display.rows_mode)
    state.rows_per_page[1] = tonumber(config.display.rows_per_page) or defaults.display.rows_per_page

    state.columns.level[1] = config.display.columns.level ~= false
    state.columns.points[1] = config.display.columns.points ~= false
    state.columns.learn_skill[1] = config.display.columns.learn_skill ~= false
    state.columns.type[1] = config.display.columns.type ~= false
    state.columns.trait[1] = config.display.columns.trait ~= false
    state.columns.mob_family[1] = config.display.columns.mob_family ~= false

    state.remember_filters[1] = config.behavior.remember_filters == true
    state.auto_highlight_learned[1] = config.behavior.auto_highlight_learned ~= false
    state.location_interaction = config.behavior.location_interaction == 'hover' and 'hover' or 'click'
    state.theme = tostring(config.appearance.theme or 'midnight')
    state.target_tag[1] = config.behavior.target_tag ~= false
    state.target_tag_locked[1] = config.behavior.target_tag_locked == true
    state.assimilation[1] = math.floor(tonumber(config.behavior.assimilation) or 0)
    state.target_tag_x = tonumber(config.target_tag_window.x) or 900
    state.target_tag_y = tonumber(config.target_tag_window.y) or 260
    state.target_tag_apply_pos = true
    state.farm_apply_geometry = true
    state.log_apply_geometry = true
    if state.apply_theme_surfaces ~= nil then state.apply_theme_surfaces(state.theme) end

    if state.remember_filters[1] then
        state.search[1] = tostring(config.ui_state.search or '')
        state.last_search = state.search[1]
        state.filter_mode = tostring(config.ui_state.filter_mode or 'all')
        state.sort_mode = tostring(config.ui_state.sort_mode or 'level')
        state.sort_desc = config.ui_state.sort_desc == true
    else
        state.search[1] = ''
        state.last_search = ''
        state.filter_mode = 'all'
        state.sort_mode = 'level'
        state.sort_desc = false
    end

    state.page = 1

    state.last_x = tonumber(config.window.x) or defaults.window.x
    state.last_y = tonumber(config.window.y) or defaults.window.y
    state.last_w = tonumber(config.window.width) or defaults.window.width
    state.last_h = tonumber(config.window.height) or defaults.window.height

    state.config_last_x = tonumber(config.config_window.x) or defaults.config_window.x
    state.config_last_y = tonumber(config.config_window.y) or defaults.config_window.y
    state.config_last_w = tonumber(config.config_window.width) or defaults.config_window.width
    state.config_last_h = tonumber(config.config_window.height) or defaults.config_window.height

    state.zone_last_x = tonumber(config.zone_window.x) or defaults.zone_window.x
    state.zone_last_y = tonumber(config.zone_window.y) or defaults.zone_window.y
    state.zone_last_w = clamp(tonumber(config.zone_window.width) or defaults.zone_window.width, ZONE_MIN_WIDTH, ZONE_MAX_WIDTH)
    state.zone_last_h = tonumber(config.zone_window.height) or defaults.zone_window.height

    state.apply_saved_geometry = true
    state.apply_saved_config_geometry = true
    state.zone_apply_saved_geometry = true
    state.geometry_dirty = false
    state.config_geometry_dirty = false
    state.zone_geometry_dirty = false
    state.settings_dirty = false
end

settings.register('settings', 'bluspells_settings_update', function(s)
    apply_loaded_config(s)
end)

-- Azure Codex theme palette: midnight blue (#020035) base with the
-- configurable Header / Accent color used for highlights.
local MUTED = { 0.60, 0.62, 0.78, 1.00 };
local TEXT = { 0.92, 0.93, 0.98, 1.00 };
local TITLE = { 0.004, 0.000, 0.125, 1.00 };
local TITLE_ACTIVE = { 0.022, 0.012, 0.270, 1.00 };
local BORDER = { 0.20, 0.19, 0.50, 0.85 };
local CONTROL = { 0.045, 0.035, 0.310, 1.00 };
local CONTROL_HOVER = { 0.085, 0.075, 0.420, 1.00 };
local CONTROL_ACTIVE = { 0.120, 0.110, 0.520, 1.00 };
local POPUP = { 0.012, 0.006, 0.165, 0.98 };
local TABLE_HEADER = { 0.030, 0.022, 0.290, 1.00 };
local TRANSPARENT = { 0.00, 0.00, 0.00, 0.00 };
local WHITE = { 1.00, 1.00, 1.00, 1.00 };

-- Window surface themes (1.12.0). Midnight is the original look. Picking a
-- theme also sets the Window Color and Header / Accent color, which stay
-- editable afterwards in Config.
local AC_THEMES = {
    midnight = {
        label = 'Midnight',
        background = { 0.004, 0.000, 0.133 },
        header = { 0.38, 0.78, 1.00 },
        muted = { 0.60, 0.62, 0.78 },
        title = { 0.004, 0.000, 0.125 },
        title_active = { 0.022, 0.012, 0.270 },
        border = { 0.20, 0.19, 0.50 },
        control = { 0.045, 0.035, 0.310 },
        control_hover = { 0.085, 0.075, 0.420 },
        control_active = { 0.120, 0.110, 0.520 },
        popup = { 0.012, 0.006, 0.165 },
        table_header = { 0.030, 0.022, 0.290 },
    },
    abyss = {
        label = 'Abyss',
        background = { 0.000, 0.040, 0.060 },
        header = { 0.36, 0.86, 0.86 },
        muted = { 0.58, 0.72, 0.76 },
        title = { 0.000, 0.035, 0.055 },
        title_active = { 0.000, 0.090, 0.130 },
        border = { 0.12, 0.36, 0.42 },
        control = { 0.020, 0.140, 0.190 },
        control_hover = { 0.040, 0.210, 0.270 },
        control_active = { 0.060, 0.280, 0.350 },
        popup = { 0.000, 0.050, 0.075 },
        table_header = { 0.010, 0.110, 0.150 },
    },
    twilight = {
        label = 'Twilight',
        background = { 0.055, 0.012, 0.085 },
        header = { 0.80, 0.62, 1.00 },
        muted = { 0.74, 0.64, 0.80 },
        title = { 0.050, 0.010, 0.080 },
        title_active = { 0.130, 0.040, 0.200 },
        border = { 0.40, 0.22, 0.52 },
        control = { 0.170, 0.060, 0.250 },
        control_hover = { 0.240, 0.100, 0.340 },
        control_active = { 0.300, 0.140, 0.420 },
        popup = { 0.070, 0.020, 0.100 },
        table_header = { 0.140, 0.050, 0.210 },
    },
};
AC_THEMES.golden = {
    -- XIUI-style black with warm gold.
    label = 'Golden',
    background = { 0.051, 0.051, 0.051 },
    header = { 0.957, 0.855, 0.592 },
    muted = { 0.60, 0.58, 0.54 },
    title = { 0.035, 0.033, 0.030 },
    title_active = { 0.137, 0.125, 0.106 },
    border = { 0.300, 0.275, 0.235 },
    control = { 0.098, 0.090, 0.075 },
    control_hover = { 0.137, 0.125, 0.106 },
    control_active = { 0.176, 0.161, 0.137 },
    popup = { 0.070, 0.065, 0.055 },
    table_header = { 0.120, 0.110, 0.090 },
};
AC_THEMES.garnet = {
    -- ScrollingCombatLog's subtle Garnet red on graphite.
    label = 'Garnet',
    background = { 0.035, 0.035, 0.040 },
    header = { 0.800, 0.380, 0.430 },
    muted = { 0.62, 0.62, 0.66 },
    title = { 0.020, 0.020, 0.022 },
    title_active = { 0.094, 0.035, 0.043 },
    border = { 0.275, 0.118, 0.133 },
    control = { 0.100, 0.100, 0.110 },
    control_hover = { 0.160, 0.160, 0.180 },
    control_active = { 0.220, 0.220, 0.250 },
    popup = { 0.050, 0.050, 0.056 },
    table_header = { 0.130, 0.060, 0.070 },
};
AC_THEMES.silver = {
    -- Cool graphite with silver.
    label = 'Silver',
    background = { 0.045, 0.048, 0.055 },
    header = { 0.800, 0.830, 0.880 },
    muted = { 0.60, 0.62, 0.66 },
    title = { 0.030, 0.032, 0.036 },
    title_active = { 0.130, 0.140, 0.160 },
    border = { 0.360, 0.380, 0.420 },
    control = { 0.110, 0.115, 0.130 },
    control_hover = { 0.170, 0.180, 0.200 },
    control_active = { 0.230, 0.240, 0.270 },
    popup = { 0.060, 0.065, 0.075 },
    table_header = { 0.140, 0.150, 0.170 },
};

local AC_THEME_ORDER = { 'midnight', 'abyss', 'twilight', 'golden', 'garnet', 'silver' };

local function set_rgb(dst, rgb)
    dst[1] = rgb[1]; dst[2] = rgb[2]; dst[3] = rgb[3];
end

-- Updates the surface color tables in place (they are shared by push_theme).
local function apply_theme_surfaces(key)
    local theme = AC_THEMES[tostring(key or 'midnight')] or AC_THEMES.midnight;
    set_rgb(MUTED, theme.muted);
    set_rgb(TITLE, theme.title);
    set_rgb(TITLE_ACTIVE, theme.title_active);
    set_rgb(BORDER, theme.border);
    set_rgb(CONTROL, theme.control);
    set_rgb(CONTROL_HOVER, theme.control_hover);
    set_rgb(CONTROL_ACTIVE, theme.control_active);
    set_rgb(POPUP, theme.popup);
    set_rgb(TABLE_HEADER, theme.table_header);
end
state.apply_theme_surfaces = apply_theme_surfaces;
apply_theme_surfaces(state.theme);

-- Switching theme: surfaces plus the theme's window / accent colors.
local function select_theme(key)
    local theme = AC_THEMES[tostring(key or '')];
    if theme == nil then return; end
    state.theme = key;
    apply_theme_surfaces(key);
    set_rgb(state.background, theme.background);
    set_rgb(state.header_color, theme.header);
    state.settings_dirty = true;
end

-- Returns the configured accent color with an optional alpha multiplier.
local function accent(alpha_mul)
    local c = state.header_color;
    return { c[1], c[2], c[3], (c[4] or 1.0) * (alpha_mul or 1.0) };
end

-- Draws a short accent bar along the bottom edge of the last drawn item.
local function draw_item_underline()
    if imgui.GetItemRectMin == nil or imgui.GetItemRectMax == nil then return; end

    local min_x = imgui.GetItemRectMin();
    local max_x, max_y = imgui.GetItemRectMax();
    min_x = tonumber(min_x); max_x = tonumber(max_x); max_y = tonumber(max_y);
    if min_x == nil or max_x == nil or max_y == nil then return; end

    local draw_list = imgui.GetWindowDrawList();
    if draw_list == nil then return; end

    draw_list:AddRectFilled(
        { min_x + 4, max_y - 2 },
        { max_x - 4, max_y },
        imgui.GetColorU32(accent()),
        1.0
    );
end

-- Button that shows an on/off state: accent-tinted fill and underline when
-- selected, standard midnight control when not. Returns true when clicked.
local function draw_toggle_button(label, id, selected, disabled)
    if selected then
        imgui.PushStyleColor(ImGuiCol_Button, accent(0.26));
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, accent(0.32));
        imgui.PushStyleColor(ImGuiCol_ButtonActive, accent(0.40));
        imgui.PushStyleColor(ImGuiCol_Text, WHITE);
    else
        imgui.PushStyleColor(ImGuiCol_Button, CONTROL);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, CONTROL_HOVER);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, CONTROL_ACTIVE);
        imgui.PushStyleColor(ImGuiCol_Text, TEXT);
    end

    local clicked = false;
    if disabled then
        imgui.BeginDisabled();
        imgui.Button(label .. '##' .. id);
        imgui.EndDisabled();
    else
        clicked = imgui.Button(label .. '##' .. id);
    end

    if selected and not disabled then
        draw_item_underline();
    end

    imgui.PopStyleColor(4);
    return clicked;
end

-- Flat tab button for the Config window: transparent with accent text and
-- underline when selected, subdued when not. Returns true when clicked.
local function draw_styled_tab(label, id, selected)
    if selected then
        imgui.PushStyleColor(ImGuiCol_Button, accent(0.12));
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, accent(0.16));
        imgui.PushStyleColor(ImGuiCol_ButtonActive, accent(0.20));
        imgui.PushStyleColor(ImGuiCol_Text, accent());
    else
        imgui.PushStyleColor(ImGuiCol_Button, { CONTROL[1], CONTROL[2], CONTROL[3], 0.55 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, CONTROL_HOVER);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, CONTROL_ACTIVE);
        imgui.PushStyleColor(ImGuiCol_Text, MUTED);
    end

    local clicked = imgui.Button(label .. '##' .. id);

    if selected then
        draw_item_underline();
    end

    imgui.PopStyleColor(4);
    return clicked;
end

-- Aligns a plain text label with the frame padding of the controls beside it.
local function align_label()
    if imgui.AlignTextToFramePadding ~= nil then
        imgui.AlignTextToFramePadding();
    end
end

-- Memoized: names are normalized thousands of times per frame otherwise.
local normalize_cache = {};
local function normalize_name(value)
    if value == nil then return ''; end
    local raw = tostring(value);
    local cached = normalize_cache[raw];
    if cached == nil then
        cached = raw:lower():gsub('[^%w]', '');
        normalize_cache[raw] = cached;
    end
    return cached;
end

-- Static per-spell values computed once.
for _, spell in ipairs(spells) do
    spell._key = normalize_name(spell.name);
end


local function get_spell_trait_display(spell)
    return tostring(spell and spell.trait or 'None')
end



-- ----------------------------------------------------------------------------
-- Blue Magic traits, HorizonXI / LandSandBoat 75-era rules.
--
-- Each set spell adds its weight (1 for almost every spell) to the trait
-- named in spells.lua. A trait tier unlocks at the thresholds below, in
-- weight units. Shown x4 so a normal tier reads as 8 trait points.
--   * most traits: a tier every 2 spells (8 pts)
--   * Auto Refresh: one tier at 8 weight (32 pts)
--   * Resist Gravity: 2 / 3 / 4 weight
-- Heavier spells (LandSandBoat weights): Self-Destruct, Frightful Roar,
-- Light of Penance x2; Voracious Trunk x3; Actinic Burst, Plasma Charge,
-- Winds of Promyvion x4. HorizonXI may differ for a few spells.
-- ----------------------------------------------------------------------------
local TRAIT_POINT_SCALE = 4;

local TRAIT_TIERS = {
    beastkiller = { 2, 4, 6 },
    autoregen = { 2, 4, 6 },
    lizardkiller = { 2, 4, 6 },
    clearmind = { 2, 4, 6, 8, 10, 12 },
    resistsleep = { 2, 4, 6, 8 },
    magicattackbonus = { 2, 4, 6, 8, 10, 12 },
    undeadkiller = { 2, 4, 6 },
    attackbonus = { 2, 4, 6, 8, 10, 12 },
    rapidshot = { 2, 4, 6 },
    maxmpboost = { 2, 4 },
    defensebonus = { 2, 4, 6, 8, 10, 12 },
    plantoidkiller = { 2, 4, 6 },
    magicdefensebonus = { 2, 4, 6, 8, 10 },
    autorefresh = { 8 },
    maxhpboost = { 2, 4, 6, 8, 10, 12 },
    accuracybonus = { 2, 4, 6, 8, 10, 12 },
    conservemp = { 2, 4, 6, 8, 10 },
    evasionbonus = { 2, 4, 6, 8, 10 },
    resistgravity = { 2, 3, 4 },
    storetp = { 2, 4, 6, 8, 10 },
    counter = { 2, 4, 6, 8 },
    fastcast = { 2, 4, 6, 8, 10 },
    -- HorizonXI-only trait (Bomb Toss and others in spells.lua); tiers
    -- assumed to follow the common 2 / 4 / 6 pattern.
    magicaccuracy = { 2, 4, 6 },
};

local TRAIT_WEIGHTS = {
    selfdestruct = 2,
    frightfulroar = 2,
    lightofpenance = 2,
    voracioustrunk = 3,
    actinicburst = 4,
    plasmacharge = 4,
    windsofpromy = 4,
    windsofpromyvion = 4,
};

local ROMAN = { 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII' };

local function get_spell_trait_name(spell)
    local text = tostring(spell and spell.trait or '');
    if text == '' or text:lower() == 'none' then return nil; end
    return text;
end

local function get_trait_weight(spell)
    return TRAIT_WEIGHTS[spell._key or normalize_name(spell.name)] or 1;
end

local function trait_tiers_for(trait_name)
    return TRAIT_TIERS[normalize_name(trait_name)] or { 2, 4, 6 };
end

-- Totals for a list of spells. Each entry:
--   name, key, weight, points, tier, max_tier, next_points, prev_points, maxed
local function compute_traits(spell_list)
    local totals = {};
    for _, spell in ipairs(spell_list or {}) do
        local trait_name = get_spell_trait_name(spell);
        if trait_name ~= nil then
            local key = normalize_name(trait_name);
            if totals[key] == nil then
                totals[key] = { name = trait_name, key = key, weight = 0 };
            end
            totals[key].weight = totals[key].weight + get_trait_weight(spell);
        end
    end

    local result = {};
    for _, entry in pairs(totals) do
        local tiers = trait_tiers_for(entry.name);
        local tier = 0;
        for index, need in ipairs(tiers) do
            if entry.weight >= need then tier = index; end
        end
        entry.tier = tier;
        entry.max_tier = #tiers;
        entry.maxed = tier >= #tiers;
        entry.points = entry.weight * TRAIT_POINT_SCALE;
        entry.next_need = tiers[tier + 1];
        entry.next_points = entry.next_need and (entry.next_need * TRAIT_POINT_SCALE) or nil;
        entry.prev_points = (tier > 0) and (tiers[tier] * TRAIT_POINT_SCALE) or 0;
        result[#result + 1] = entry;
    end

    table.sort(result, function(a, b)
        if a.tier ~= b.tier then return a.tier > b.tier; end
        if a.points ~= b.points then return a.points > b.points; end
        return a.name:lower() < b.name:lower();
    end);

    return result;
end

local function trait_label(entry)
    if entry.tier > 0 then
        return ('%s %s'):fmt(entry.name, ROMAN[entry.tier] or tostring(entry.tier));
    end
    return entry.name;
end

local function get_trait_totals()
    local selected_spells = {};
    for _, spell in ipairs(spells) do
        if state.build_selected[spell._key] == true then
            selected_spells[#selected_spells + 1] = spell;
        end
    end
    return compute_traits(selected_spells), selected_spells;
end

-- Weighted spells show their weight next to the trait, e.g. "Auto Refresh x2".
local function get_spell_trait_badge(spell)
    local name = tostring(spell and spell.trait or 'None');
    if name:lower() == 'none' then return name; end
    local weight = TRAIT_WEIGHTS[spell._key or ''] or 1;
    if weight > 1 then return ('%s x%d'):fmt(name, weight); end
    return name;
end

local resource_aliases = T{
    -- spells.lua intentionally keeps the full display names. Horizon/Ashita's
    -- spell resources abbreviate these names, so learned-status checks use
    -- the normalized resource aliases below.
    ['windsofpromyvion'] = 'windsofpromy',
    ['quadraticcontinnuum'] = 'quadcontinuum',
};

local function build_resource_cache()
    if state.resource_cache_ready then return; end

    local rm = AshitaCore:GetResourceManager();
    if not rm then return; end

    local wanted = T{};
    for _, spell in ipairs(spells) do
        local key = normalize_name(spell.name);
        wanted[key] = true;
        if resource_aliases[key] ~= nil then
            wanted[resource_aliases[key]] = true;
        end
    end

    for id = 0, 2048 do
        local res = rm:GetSpellById(id);
        if res ~= nil and res.Name ~= nil and res.Name[1] ~= nil then
            local key = normalize_name(res.Name[1]);
            if wanted[key] then
                state.resource_ids[key] = id;
            end
        end
    end

    for source_key, resource_key in pairs(resource_aliases) do
        if state.resource_ids[source_key] == nil and state.resource_ids[resource_key] ~= nil then
            state.resource_ids[source_key] = state.resource_ids[resource_key];
        end
    end

    state.resource_cache_ready = true;
end

local function safe_player()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then return nil; end
    local player = mm:GetPlayer();
    if not player then return nil; end
    return player;
end

-- Known-spell cache. Refreshed at most twice a second; every view reads
-- from it. version changes whenever any spell's known state changes, which
-- invalidates the list / zone / farm caches below.
local known_cache = { by_key = {}, count = 0, version = 0, checked = -1 };

local function refresh_known_cache(force)
    local now = os.clock();
    if not force and known_cache.checked >= 0 and (now - known_cache.checked) < 0.5 then
        return;
    end
    known_cache.checked = now;

    local player = safe_player();
    if not player then return; end

    if not state.resource_cache_ready then
        build_resource_cache();
    end

    local changed = false;
    local count = 0;
    for _, spell in ipairs(spells) do
        local key = spell._key;
        local id = state.resource_ids[key];
        local known = false;
        if id ~= nil then
            local ok, value = pcall(function() return player:HasSpell(id); end);
            known = ok and value == true;
        end
        if known then count = count + 1; end
        if known_cache.by_key[key] ~= known then
            known_cache.by_key[key] = known;
            changed = true;
        end
    end

    known_cache.count = count;
    if changed then
        known_cache.version = known_cache.version + 1;
    end
end

local function is_known(spell_name)
    refresh_known_cache(false);
    return known_cache.by_key[normalize_name(spell_name)] == true;
end

local function get_learned_count()
    refresh_known_cache(false);
    return known_cache.count;
end

local function safe_current_zone_id()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then return nil; end

    local party = mm:GetParty();
    if not party then return nil; end

    local zone_id = nil;

    if party.GetMemberZone ~= nil then
        local ok, value = pcall(function()
            return party:GetMemberZone(0);
        end);
        if ok then
            zone_id = tonumber(value);
        end
    end

    if (zone_id == nil or zone_id <= 0) and party.GetMemberZone2 ~= nil then
        local ok, value = pcall(function()
            return party:GetMemberZone2(0);
        end);
        if ok then
            zone_id = tonumber(value);
        end
    end

    if zone_id == nil or zone_id <= 0 then
        return nil;
    end

    return zone_id;
end

local function get_zone_spell_rows(zone_id)
    zone_id = tonumber(zone_id);
    if not zone_id then
        return {};
    end

    local rows = {};

    for _, spell in ipairs(spells) do
        local entries = locations.get(spell.name) or {};
        local mob_lookup = {};
        local mobs = {};

        for _, entry in ipairs(entries) do
            if tonumber(entry.zone) == zone_id then
                for _, mob in ipairs(entry.mobs or {}) do
                    local mob_name = tostring(mob or '');
                    local key = mob_name:lower();
                    if mob_name ~= '' and not mob_lookup[key] then
                        mob_lookup[key] = true;
                        mobs[#mobs + 1] = mob_name;
                    end
                end
            end
        end

        if #mobs > 0 then
            table.sort(mobs, function(a, b)
                return tostring(a):lower() < tostring(b):lower();
            end);

            rows[#rows + 1] = {
                spell = spell,
                mobs = mobs,
                known = is_known(spell.name),
            };
        end
    end

    table.sort(rows, function(a, b)
        return tostring(a.spell.name):lower() < tostring(b.spell.name):lower();
    end);

    return rows;
end

local zone_rows_cache = { key = nil, rows = {} };

local function get_zone_progress(zone_id)
    refresh_known_cache(false);
    local cache_key = tostring(zone_id) .. '|' .. tostring(known_cache.version);
    if zone_rows_cache.key ~= cache_key then
        zone_rows_cache.rows = get_zone_spell_rows(zone_id);
        zone_rows_cache.key = cache_key;
    end
    local rows = zone_rows_cache.rows;
    local known = 0;

    for _, row in ipairs(rows) do
        if row.known then
            known = known + 1;
        end
    end

    return known, #rows, rows;
end

local function safe_blu_level()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then return nil; end

    -- Prefer IPlayer because it is the local player's authoritative job/level
    -- structure and does not depend on party-member data being populated.
    local player = mm:GetPlayer();
    if player then
        local main_job = nil;
        local main_level = nil;

        if player.GetMainJob ~= nil then
            local ok, value = pcall(function()
                return player:GetMainJob();
            end);
            if ok then main_job = tonumber(value); end
        end

        if player.GetMainJobLevel ~= nil then
            local ok, value = pcall(function()
                return player:GetMainJobLevel();
            end);
            if ok then main_level = tonumber(value); end
        end

        -- Blue Mage job id is 16.
        if main_job == 16 and main_level and main_level > 0 then
            return main_level;
        end
    end

    -- Fallback for clients / moments where IPlayer has not populated yet.
    local party = mm:GetParty();
    if not party then return nil; end

    local main_job = nil;
    local main_level = nil;

    if party.GetMemberMainJob ~= nil then
        local ok, value = pcall(function()
            return party:GetMemberMainJob(0);
        end);
        if ok then main_job = tonumber(value); end
    end

    if party.GetMemberMainJobLevel ~= nil then
        local ok, value = pcall(function()
            return party:GetMemberMainJobLevel(0);
        end);
        if ok then main_level = tonumber(value); end
    end

    if main_job == 16 and main_level and main_level > 0 then
        return main_level;
    end

    return nil;
end

local read_blue_magic_skill;
local skill_cache = { value = nil, at = -1 };

-- Cached for a quarter second (it was read once per table row per frame).
local function safe_blue_magic_skill()
    local now = os.clock();
    if skill_cache.at >= 0 and (now - skill_cache.at) < 0.25 then
        return skill_cache.value;
    end
    skill_cache.value = read_blue_magic_skill();
    skill_cache.at = now;
    return skill_cache.value;
end

read_blue_magic_skill = function()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then return nil; end

    local player = mm:GetPlayer();
    if not player then return nil; end

    if player.GetCombatSkill == nil then
        return nil;
    end

    -- Ashita combat-skill index 43 is Blue Magic.
    local ok, skill = pcall(function()
        return player:GetCombatSkill(43);
    end);

    if not ok or skill == nil then
        return nil;
    end

    if skill.GetSkill == nil then
        return nil;
    end

    local ok_value, value = pcall(function()
        return skill:GetSkill();
    end);

    if not ok_value then
        return nil;
    end

    value = tonumber(value);
    if value == nil or value < 0 then
        return nil;
    end

    return value;
end

-- Reads the player's current BLU set points from Ashita's BLU state.
local blu_points_ptr = nil;
local function get_blu_points()
    if blu_points_ptr == nil then
        local ok, ptr = pcall(function()
            return ffi.cast('uint8_t***', ashita.memory.find(0, 0, 'A1????????33C98A4E5E33D28A565D5F5E8950148948185B83C414C20400', 1, 0));
        end);
        if not ok or ptr == nil then return nil, nil; end
        blu_points_ptr = ptr;
    end

    -- Guard every link of the pointer chain (NULL compares equal to nil in
    -- LuaJIT); reading through a NULL pointer would crash the client.
    local ok, spent, max = pcall(function()
        if blu_points_ptr == nil or blu_points_ptr[0] == nil or blu_points_ptr[0][0] == nil then
            return nil, nil;
        end
        return tonumber(blu_points_ptr[0][0][0x14]), tonumber(blu_points_ptr[0][0][0x18]);
    end);
    if not ok or spent == nil or max == nil or max <= 0 then return nil, nil; end
    return spent, max;
end

-- HorizonXI BLU has A+ Blue Magic skill.
-- A spell's learning skill is its A+ cap at the spell's usable level.
-- HorizonXI documents a maximum learning gap of 31 skill points, so the
-- minimum skill shown here is: A+ cap at spell level - 31.
local function blue_magic_cap_for_level(level)
    level = math.floor(tonumber(level) or 1);
    if level < 1 then level = 1; end
    if level > 75 then level = 75; end

    if level <= 50 then
        return (level * 3) + 3;
    elseif level <= 60 then
        return 153 + ((level - 50) * 5);
    elseif level <= 67 then
        -- HorizonXI A+ caps: 61=207, 62=212, 63=217, 64=222,
        -- 65=227, 66=232, 67=236.
        if level == 67 then return 236; end
        return 207 + ((level - 61) * 5);
    end

    return 236 + ((level - 67) * 5);
end

local function blue_magic_learn_skill(spell)
    local cap = blue_magic_cap_for_level(spell and spell.level or 1);
    return math.max(0, cap - 31);
end

-- HorizonXI BLU set limits by level (Blue Magic Points, spells you can set).
local HORIZON_BLU_CAPS = {
    { 10, 10, 6 },
    { 20, 15, 8 },
    { 30, 20, 10 },
    { 40, 25, 12 },
    { 50, 30, 14 },
    { 60, 35, 16 },
    { 70, 40, 18 },
    { 75, 45, 20 },
};

local function horizon_blu_caps(level)
    level = math.floor(tonumber(level) or 75);
    -- Assimilation merits (+1 Blue Magic Point each, Lv75) from Config.
    local merits = math.max(0, math.min(5, math.floor(tonumber(state.assimilation and state.assimilation[1]) or 0)));
    for _, row in ipairs(HORIZON_BLU_CAPS) do
        if level <= row[1] then
            if row[1] == 75 then return row[2] + merits, row[3]; end
            return row[2], row[3];
        end
    end
    return 45 + merits, 20;
end

-- Point cap, slot cap, whether the point cap is an estimate, live spent.
-- Live points are used when the client exposes them; otherwise the HorizonXI
-- level table. Not on BLU: Lv75 limits (planning mode).
local function get_build_caps()
    local spent, live_max = get_blu_points();
    local level = safe_blu_level();
    local points, slots = horizon_blu_caps(level or 75);
    local estimated = true;
    if live_max ~= nil and live_max > 0 then
        points = live_max;
        estimated = false;
    end
    return points, slots, estimated, spent;
end

-- Returns the display state for a spell:
--   Known       = already learned
--   Learnable   = not learned, current BLU level is high enough, and current
--                 Blue Magic skill meets the minimum learning threshold
--   Unlearnable = not currently learnable by the local player
local function get_spell_display_state(spell)
    if spell == nil then
        return 'unlearnable', state.unknown_color;
    end

    if is_known(spell.name) then
        return 'known', state.known_color;
    end

    local blu_skill = safe_blue_magic_skill();
    local learn_skill = blue_magic_learn_skill(spell);

    -- Learning availability is based on the player's current Blue Magic skill,
    -- not the spell's listed job level. A BLU can learn a spell above its
    -- current job level when its Blue Magic skill meets the learning threshold.
    if blu_skill ~= nil and blu_skill >= learn_skill then
        return 'learnable', state.learnable_color;
    end

    return 'unlearnable', state.unknown_color;
end

local function spell_state_text(spell)
    local display_state = get_spell_display_state(spell);
    if display_state == 'known' then return 'Known'; end
    if display_state == 'learnable' then return 'Learnable'; end
    return 'Unlearnable';
end

local function split_search_terms(value)
    local terms = {};
    value = tostring(value or ''):lower();

    for term in value:gmatch('[^|]+') do
        term = term:gsub('^%s+', ''):gsub('%s+$', '');
        if term ~= '' then
            terms[#terms + 1] = term;
        end
    end

    return terms;
end

-- Built once per spell (all of these fields are static).
local function spell_haystack(spell)
    if spell._haystack == nil then
        spell._haystack = table.concat({
            tostring(spell.name or ''),
            tostring(spell.level or ''),
            tostring(spell.points or ''),
            tostring(blue_magic_learn_skill(spell)),
            tostring(spell.type or ''),
            tostring(spell.trait or ''),
            tostring(spell.mob_family or ''),
        }, ' '):lower();
    end
    return spell._haystack;
end

local function spell_matches_search(spell, terms)
    if #terms == 0 then return true; end

    local haystack = spell_haystack(spell);

    -- "|" searches are OR matches, matching FancyChat behavior.
    for _, term in ipairs(terms) do
        if haystack:find(term, 1, true) ~= nil then
            return true;
        end
    end

    return false;
end

local function filter_accepts(spell, known, blu_level)
    if state.filter_mode == 'known' then
        return known;
    elseif state.filter_mode == 'missing' then
        return not known;
    elseif state.filter_mode == 'ready' then
        return (not known) and blu_level ~= nil and tonumber(spell.level) <= blu_level;
    end
    return true;
end

local function compare_spells(a, b)
    local key = state.sort_mode;
    local av, bv;

    if key == 'name' then
        av, bv = a.name:lower(), b.name:lower();
    elseif key == 'points' then
        av, bv = tonumber(a.points) or 0, tonumber(b.points) or 0;
    elseif key == 'learn_skill' then
        av, bv = blue_magic_learn_skill(a), blue_magic_learn_skill(b);
    elseif key == 'type' then
        av, bv = tostring(a.type or ''):lower(), tostring(b.type or ''):lower();
    elseif key == 'trait' then
        av, bv = tostring(a.trait or ''):lower(), tostring(b.trait or ''):lower();
    elseif key == 'mob_family' then
        av, bv = tostring(a.mob_family or ''):lower(), tostring(b.mob_family or ''):lower();
    else
        av, bv = tonumber(a.level) or 0, tonumber(b.level) or 0;
    end

    if av == bv then
        local an = a.name:lower();
        local bn = b.name:lower();
        if an == bn then
            return (tonumber(a.level) or 0) < (tonumber(b.level) or 0);
        end
        return an < bn;
    end

    if state.sort_desc then
        return av > bv;
    end
    return av < bv;
end

local filtered_cache = { key = nil, result = {}, blu_level = nil };

-- Rebuilt only when search / filter / sort / known spells / level change.
local function get_filtered_spells()
    refresh_known_cache(false);
    local blu_level = safe_blu_level();
    local cache_key = table.concat({
        tostring(state.search[1] or ''), state.filter_mode, state.sort_mode,
        tostring(state.sort_desc), tostring(known_cache.version), tostring(blu_level),
    }, '\1');
    if filtered_cache.key == cache_key then
        return filtered_cache.result, filtered_cache.blu_level;
    end

    local terms = split_search_terms(state.search[1]);
    local result = {};

    for _, spell in ipairs(spells) do
        local known = is_known(spell.name);
        if filter_accepts(spell, known, blu_level) and spell_matches_search(spell, terms) then
            result[#result + 1] = spell;
        end
    end

    table.sort(result, compare_spells);
    filtered_cache.key = cache_key;
    filtered_cache.result = result;
    filtered_cache.blu_level = blu_level;
    return result, blu_level;
end

local function clamp_page(total_rows)
    local pages = math.max(1, math.ceil(total_rows / math.max(1, state.per_page)));
    if state.page < 1 then
        state.page = 1;
    elseif state.page > pages then
        state.page = pages;
    end
    return pages;
end

local function mark_ui_state_changed(reset_page)
    if reset_page then
        state.page = 1;
    end
    state.settings_dirty = true;
end

local function set_filter(mode)
    if state.filter_mode ~= mode then
        state.filter_mode = mode;
        state.build_page[1] = false;
        state.spellsets_page[1] = false;
        state.bluprint_view_page[1] = false;
        mark_ui_state_changed(true);
    elseif state.build_page[1] or state.spellsets_page[1] or state.bluprint_view_page[1] then
        -- Clicking any main filter returns to the spell list, even when
        -- that filter was already active (BLUPrint-View included).
        state.build_page[1] = false;
        state.spellsets_page[1] = false;
        state.bluprint_view_page[1] = false;
        mark_ui_state_changed(true);
    end
end

local function set_sort(mode)
    if state.sort_mode == mode then
        state.sort_desc = not state.sort_desc;
    else
        state.sort_mode = mode;
        state.sort_desc = false;
    end
    mark_ui_state_changed(true);
end

local function sort_label(label, mode)
    if state.sort_mode ~= mode then
        return label;
    end
    return label .. (state.sort_desc and ' v' or ' ^');
end

local function draw_sort_header(label, mode)
    local active = state.sort_mode == mode;

    imgui.PushStyleColor(ImGuiCol_Button, TRANSPARENT);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, accent(0.14));
    imgui.PushStyleColor(ImGuiCol_ButtonActive, accent(0.24));
    imgui.PushStyleColor(ImGuiCol_Text, active and accent() or accent(0.78));
    if imgui.Button(sort_label(label, mode) .. '##sort_' .. mode) then
        set_sort(mode);
    end
    if active then
        draw_item_underline();
    end
    imgui.PopStyleColor(4);
end

-- Learned log (per character, newest last; capped).
local LEARNED_LOG_MAX = 500;

local function add_learned_log_entry(spell)
    if config.learned_log == nil then config.learned_log = T{}; end

    local zone_id = safe_current_zone_id();
    local mob = nil;
    local defeat = state.last_defeat;
    if defeat ~= nil and (os.time() - (tonumber(defeat.time) or 0)) <= 90
        and (zone_id == nil or tonumber(defeat.zone) == zone_id) then
        mob = defeat.name;
    end

    config.learned_log[#config.learned_log + 1] = T{
        spell = tostring(spell.name),
        time = os.time(),
        zone = zone_id or 0,
        mob = mob or '',
    };
    while #config.learned_log > LEARNED_LOG_MAX do
        table.remove(config.learned_log, 1);
    end
    state.settings_dirty = true;
end

local function update_known_snapshot()
    refresh_known_cache(false);
    if state.known_snapshot_initialized and state.snapshot_version == known_cache.version then
        return;
    end
    state.snapshot_version = known_cache.version;

    local now = os.clock();

    if not state.known_snapshot_initialized then
        for _, spell in ipairs(spells) do
            state.known_snapshot[spell._key] = is_known(spell.name);
        end
        state.known_snapshot_initialized = true;
        return;
    end

    -- Collect newly learned spells first. More than 3 at once is the
    -- client loading the spell list (login / job change), not learning.
    local newly = {};
    for _, spell in ipairs(spells) do
        local key = spell._key;
        local known = is_known(spell.name);
        if known and state.known_snapshot[key] ~= true then
            newly[#newly + 1] = spell;
        end
        state.known_snapshot[key] = known;
    end

    if #newly == 0 or #newly > 3 then
        return;
    end

    for _, spell in ipairs(newly) do
        add_learned_log_entry(spell);
        if state.auto_highlight_learned[1] then
            state.selected_spell = spell.name;
            state.learned_flash_until = now + 5.0;
            state.jump_to_selected = true;
        end
    end
end

local function maybe_jump_to_selected(filtered)
    if not state.jump_to_selected or not state.selected_spell then
        return;
    end

    for index, spell in ipairs(filtered) do
        if spell.name == state.selected_spell then
            state.page = math.floor((index - 1) / math.max(1, state.per_page)) + 1;
            break;
        end
    end

    state.jump_to_selected = false;
end

local function active_column_count()
    local count = 1;
    if state.columns.level[1] then count = count + 1; end
    if state.columns.points[1] then count = count + 1; end
    if state.columns.learn_skill[1] then count = count + 1; end
    if state.columns.type[1] then count = count + 1; end
    if state.columns.trait[1] then count = count + 1; end
    if state.columns.mob_family[1] then count = count + 1; end
    return count;
end

local function setup_table_columns()
    imgui.TableSetupColumn('Spell');
    if state.columns.level[1] then imgui.TableSetupColumn('Lvl'); end
    if state.columns.points[1] then imgui.TableSetupColumn('Points'); end
    if state.columns.learn_skill[1] then imgui.TableSetupColumn('Learn Skill'); end
    if state.columns.type[1] then imgui.TableSetupColumn('Type'); end
    if state.columns.trait[1] then imgui.TableSetupColumn('Trait'); end
    if state.columns.mob_family[1] then imgui.TableSetupColumn('Mob Family'); end
end

local function draw_table_headers()
    imgui.TableNextRow();

    -- Solid header strip so the sortable column titles read as a header row.
    if imgui.TableSetBgColor ~= nil and ImGuiTableBgTarget_RowBg0 ~= nil then
        imgui.TableSetBgColor(ImGuiTableBgTarget_RowBg0, imgui.GetColorU32(TABLE_HEADER));
    end

    imgui.TableNextColumn();
    draw_sort_header('Spell', 'name');

    if state.columns.level[1] then
        imgui.TableNextColumn();
        draw_sort_header('Lvl', 'level');
    end

    if state.columns.points[1] then
        imgui.TableNextColumn();
        draw_sort_header('Points', 'points');
    end

    if state.columns.learn_skill[1] then
        imgui.TableNextColumn();
        draw_sort_header('Learn Skill', 'learn_skill');
    end

    if state.columns.type[1] then
        imgui.TableNextColumn();
        draw_sort_header('Type', 'type');
    end

    if state.columns.trait[1] then
        imgui.TableNextColumn();
        draw_sort_header('Trait', 'trait');
    end

    if state.columns.mob_family[1] then
        imgui.TableNextColumn();
        draw_sort_header('Mob Family', 'mob_family');
    end
end

local function draw_learning_tooltip(spell)
    if state.location_interaction ~= 'hover' then return; end
    if not imgui.IsItemHovered() then return; end

    local entries = locations.get(spell.name);
    if not entries then return; end

    imgui.BeginTooltip();
    imgui.TextColored(state.header_color, spell.name);
    imgui.Separator();

    imgui.TextColored(MUTED, 'Mob Family:');
    imgui.SameLine();
    imgui.Text(tostring(spell.mob_family or '--'));

    imgui.Spacing();
    imgui.TextColored(state.header_color, 'Learned From');
    imgui.Separator();

    if #entries == 0 then
        imgui.TextColored(MUTED, 'No learning locations available.');
    else
        -- Keep large learning lists readable by flowing them into additional
        -- columns instead of allowing a tooltip to grow beyond the screen.
        -- A zone and its mobs are kept together whenever possible.
        local max_rows_per_column = 50;
        local columns = { {} };
        local current_column = columns[1];
        local current_rows = 0;

        for _, entry in ipairs(entries) do
            local mobs = entry.mobs or {};
            local block_rows = 1 + #mobs;

            if current_rows > 0 and (current_rows + block_rows) > max_rows_per_column then
                current_column = {};
                table.insert(columns, current_column);
                current_rows = 0;
            end

            table.insert(current_column, {
                kind = 'zone',
                text = locations.get_zone_name(entry.zone),
            });
            current_rows = current_rows + 1;

            for _, mob in ipairs(mobs) do
                table.insert(current_column, {
                    kind = 'mob',
                    text = tostring(mob),
                });
                current_rows = current_rows + 1;
            end
        end

        if #columns == 1 or imgui.BeginTable == nil then
            for column_index, column in ipairs(columns) do
                if column_index > 1 then
                    imgui.Spacing();
                    imgui.Separator();
                end
                for _, line in ipairs(column) do
                    if line.kind == 'zone' then
                        imgui.TextColored(state.header_color, line.text);
                    else
                        imgui.Text('  - ' .. line.text);
                    end
                end
            end
        else
            local flags = 0;
            if ImGuiTableFlags_SizingFixedFit ~= nil then
                flags = bit.bor(flags, ImGuiTableFlags_SizingFixedFit);
            end

            if imgui.BeginTable('##bluspells_learning_locations', #columns, flags) then
                local tallest = 0;
                for _, column in ipairs(columns) do
                    if #column > tallest then tallest = #column; end
                end

                for row = 1, tallest do
                    imgui.TableNextRow();
                    for column_index, column in ipairs(columns) do
                        imgui.TableNextColumn();
                        local line = column[row];
                        if line then
                            if line.kind == 'zone' then
                                imgui.TextColored(state.header_color, line.text);
                            else
                                imgui.Text('  - ' .. line.text);
                            end
                        end
                    end
                end

                imgui.EndTable();
            end
        end
    end

    imgui.EndTooltip();
end

local function draw_spell_table_row(spell)
    local known = is_known(spell.name);
    local selected = state.selected_spell == spell.name;
    local _, color = get_spell_display_state(spell);

    local line_h = imgui.GetTextLineHeightWithSpacing();
    local row_h = state.row_spacing == 'normal' and (line_h + 5) or (line_h + 1);

    imgui.TableNextRow(0, row_h);
    imgui.TableNextColumn();

    local selectable_flags = ImGuiSelectableFlags_SpanAllColumns or 0;

    if selected and os.clock() <= state.learned_flash_until then
        imgui.PushStyleColor(ImGuiCol_Header, { 0.18, 0.38, 0.20, 0.90 });
        imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 0.20, 0.46, 0.23, 0.95 });
        imgui.PushStyleColor(ImGuiCol_HeaderActive, { 0.22, 0.54, 0.26, 1.00 });
    end

    imgui.PushStyleColor(ImGuiCol_Text, color);
    if imgui.Selectable(spell.name .. '##spell_' .. normalize_name(spell.name), selected, selectable_flags) then
        state.selected_spell = spell.name;
        if state.location_interaction == 'click' then
            if state.location_open[1] and state.location_spell and state.location_spell.name == spell.name then
                state.location_open[1] = false;
                state.location_spell = nil;
            else
                state.location_spell = spell;
        state.location_reset_scroll = true;
                state.location_open[1] = true;
                state.location_apply_default_size = not state.location_size_initialized;
            end
        end
    end
    draw_learning_tooltip(spell);
    imgui.PopStyleColor(1);

    if selected and os.clock() <= state.learned_flash_until then
        imgui.PopStyleColor(3);
    end

    if state.columns.level[1] then
        imgui.TableNextColumn();
        imgui.Text(tostring(spell.level));
    end

    if state.columns.points[1] then
        imgui.TableNextColumn();
        imgui.Text(tostring(spell.points or '--'));
    end

    if state.columns.learn_skill[1] then
        imgui.TableNextColumn();
        imgui.Text(tostring(blue_magic_learn_skill(spell)));
    end

    if state.columns.type[1] then
        imgui.TableNextColumn();
        imgui.Text(tostring(spell.type or '--'));
    end

    if state.columns.trait[1] then
        imgui.TableNextColumn();
        if spell.trait == nil or spell.trait == '' or spell.trait == 'None' then
            imgui.TextColored(MUTED, 'None');
        else
            imgui.Text(spell.trait);
        end
    end

    if state.columns.mob_family[1] then
        imgui.TableNextColumn();
        if spell.mob_family == nil or spell.mob_family == '' then
            imgui.TextColored(MUTED, '--');
        else
            imgui.Text(spell.mob_family);
        end
    end
end

-- Fallback for an Ashita build without ImGui tables.
local function draw_fallback_rows(filtered, first, last)
    local x = 300;

    imgui.TextColored(state.header_color, 'Spell');

    if state.columns.level[1] then
        imgui.SameLine(); imgui.SetCursorPosX(x); imgui.TextColored(state.header_color, 'Lvl');
        x = x + 55;
    end
    if state.columns.points[1] then
        imgui.SameLine(); imgui.SetCursorPosX(x); imgui.TextColored(state.header_color, 'Points');
        x = x + 65;
    end
    if state.columns.learn_skill[1] then
        imgui.SameLine(); imgui.SetCursorPosX(x); imgui.TextColored(state.header_color, 'Learn Skill');
        x = x + 95;
    end
    if state.columns.type[1] then
        imgui.SameLine(); imgui.SetCursorPosX(x); imgui.TextColored(state.header_color, 'Type');
        x = x + 155;
    end
    if state.columns.trait[1] then
        imgui.SameLine(); imgui.SetCursorPosX(x); imgui.TextColored(state.header_color, 'Trait');
        x = x + 215;
    end
    if state.columns.mob_family[1] then
        imgui.SameLine(); imgui.SetCursorPosX(x); imgui.TextColored(state.header_color, 'Mob Family');
    end
    imgui.Separator();

    for i = first, last do
        local spell = filtered[i];
        local known = is_known(spell.name);
        local selected = state.selected_spell == spell.name;
        local _, color = get_spell_display_state(spell);

        imgui.PushStyleColor(ImGuiCol_Text, color);
        if imgui.Selectable(spell.name .. '##fallback_' .. normalize_name(spell.name), selected) then
            state.selected_spell = spell.name;
            if state.location_interaction == 'click' then
                if state.location_open[1] and state.location_spell and state.location_spell.name == spell.name then
                    state.location_open[1] = false;
                    state.location_spell = nil;
                else
                    state.location_spell = spell;
                    state.location_reset_scroll = true;
                    state.location_open[1] = true;
                    state.location_apply_default_size = not state.location_size_initialized;
                end
            end
        end
        draw_learning_tooltip(spell);
        imgui.PopStyleColor(1);

        x = 300;
        if state.columns.level[1] then
            imgui.SameLine(); imgui.SetCursorPosX(x); imgui.Text(tostring(spell.level));
            x = x + 55;
        end
        if state.columns.points[1] then
            imgui.SameLine(); imgui.SetCursorPosX(x); imgui.Text(tostring(spell.points or '--'));
            x = x + 65;
        end
        if state.columns.learn_skill[1] then
            imgui.SameLine(); imgui.SetCursorPosX(x); imgui.Text(tostring(blue_magic_learn_skill(spell)));
            x = x + 95;
        end
        if state.columns.type[1] then
            imgui.SameLine(); imgui.SetCursorPosX(x); imgui.Text(tostring(spell.type or '--'));
            x = x + 155;
        end
        if state.columns.trait[1] then
            imgui.SameLine(); imgui.SetCursorPosX(x); imgui.Text(tostring(spell.trait or 'None'));
            x = x + 215;
        end
        if state.columns.mob_family[1] then
            imgui.SameLine(); imgui.SetCursorPosX(x); imgui.Text(tostring(spell.mob_family or '--'));
        end
    end
end

local function save_config()
    ensure_tables();

    config.font_scale = state.font_scale[1];

    for i = 1, 4 do
        config.appearance.background[i] = state.background[i];
        config.appearance.known_color[i] = state.known_color[i];
        config.appearance.learnable_color[i] = state.learnable_color[i];
        config.appearance.unknown_color[i] = state.unknown_color[i];
        config.appearance.header_color[i] = state.header_color[i];
        config.appearance.paging_color[i] = state.paging_color[i];
    end

    config.appearance.border = state.border[1];
    config.appearance.title_bar = state.title_bar[1];
    config.appearance.locked = state.locked[1];
    config.appearance.zone_locked = state.zone_locked[1];
    config.appearance.location_locked = state.location_locked[1];

    config.display.row_spacing = state.row_spacing;
    config.display.rows_mode = state.rows_mode;
    config.display.rows_per_page = math.floor(clamp(state.rows_per_page[1], 8, 60));

    config.display.columns.level = state.columns.level[1];
    config.display.columns.points = state.columns.points[1];
    config.display.columns.learn_skill = state.columns.learn_skill[1];
    config.display.columns.type = state.columns.type[1];
    config.display.columns.trait = state.columns.trait[1];
    config.display.columns.mob_family = state.columns.mob_family[1];

    config.behavior.remember_filters = state.remember_filters[1];
    config.behavior.auto_highlight_learned = state.auto_highlight_learned[1];
    config.behavior.location_interaction = state.location_interaction == 'hover' and 'hover' or 'click';
    config.behavior.target_tag = state.target_tag[1] == true;
    config.behavior.target_tag_locked = state.target_tag_locked[1] == true;
    config.behavior.assimilation = math.max(0, math.min(5, math.floor(tonumber(state.assimilation[1]) or 0)));
    config.appearance.theme = state.theme;
    config.target_tag_window.x = state.target_tag_x;
    config.target_tag_window.y = state.target_tag_y;

    if state.remember_filters[1] then
        config.ui_state.search = tostring(state.search[1] or '');
        config.ui_state.filter_mode = state.filter_mode;
        config.ui_state.sort_mode = state.sort_mode;
        config.ui_state.sort_desc = state.sort_desc == true;
    else
        config.ui_state.search = '';
        config.ui_state.filter_mode = 'all';
        config.ui_state.sort_mode = 'level';
        config.ui_state.sort_desc = false;
    end

    config.window.x = state.last_x;
    config.window.y = state.last_y;
    config.window.width = state.last_w;
    config.window.height = state.last_h;

    config.config_window.x = state.config_last_x;
    config.config_window.y = state.config_last_y;
    config.config_window.width = state.config_last_w;
    config.config_window.height = state.config_last_h;

    config.zone_window.x = state.zone_last_x;
    config.zone_window.y = state.zone_last_y;
    config.zone_window.width = clamp(state.zone_last_w, ZONE_MIN_WIDTH, ZONE_MAX_WIDTH);
    config.zone_window.height = state.zone_last_h;

    settings.save();
end

local function capture_main_geometry()
    local x, y = imgui.GetWindowPos();
    local w, h = imgui.GetWindowSize();

    x = tonumber(x); y = tonumber(y);
    w = tonumber(w); h = tonumber(h);

    if x == nil or y == nil or w == nil or h == nil then return; end

    if math.abs(x - state.last_x) >= 1
        or math.abs(y - state.last_y) >= 1
        or math.abs(w - state.last_w) >= 1
        or math.abs(h - state.last_h) >= 1 then
        state.last_x = x;
        state.last_y = y;
        state.last_w = w;
        state.last_h = h;
        state.geometry_dirty = true;
    end
end

local function capture_config_geometry()
    local x, y = imgui.GetWindowPos();
    local w, h = imgui.GetWindowSize();

    x = tonumber(x); y = tonumber(y);
    w = tonumber(w); h = tonumber(h);

    if x == nil or y == nil or w == nil or h == nil then return; end

    if math.abs(x - state.config_last_x) >= 1
        or math.abs(y - state.config_last_y) >= 1
        or math.abs(w - state.config_last_w) >= 1
        or math.abs(h - state.config_last_h) >= 1 then
        state.config_last_x = x;
        state.config_last_y = y;
        state.config_last_w = w;
        state.config_last_h = h;
        state.config_geometry_dirty = true;
    end
end

local function capture_zone_geometry()
    local x, y = imgui.GetWindowPos();
    local w, h = imgui.GetWindowSize();

    x = tonumber(x); y = tonumber(y);
    w = tonumber(w); h = tonumber(h);

    if x == nil or y == nil or w == nil or h == nil then return; end

    if math.abs(x - state.zone_last_x) >= 1
        or math.abs(y - state.zone_last_y) >= 1
        or math.abs(w - state.zone_last_w) >= 1
        or math.abs(h - state.zone_last_h) >= 1 then
        state.zone_last_x = x;
        state.zone_last_y = y;
        state.zone_last_w = clamp(w, ZONE_MIN_WIDTH, ZONE_MAX_WIDTH);
        state.zone_last_h = h;
        state.zone_geometry_dirty = true;
    end
end

-- Each push_theme records how many colors / vars it actually pushed so the
-- matching pop_theme stays balanced even if a constant is missing on an
-- older Ashita build.
local theme_stack = {};

local function push_theme()
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

    -- Window surfaces.
    color(ImGuiCol_WindowBg, {
        state.background[1], state.background[2], state.background[3], state.background[4]
    });
    color(ImGuiCol_ChildBg, TRANSPARENT);
    color(ImGuiCol_PopupBg, POPUP);
    color(ImGuiCol_TitleBg, TITLE);
    color(ImGuiCol_TitleBgActive, TITLE_ACTIVE);
    color(ImGuiCol_TitleBgCollapsed, TITLE);
    color(ImGuiCol_Border, BORDER);
    color(ImGuiCol_BorderShadow, TRANSPARENT);

    -- Text.
    color(ImGuiCol_Text, TEXT);
    color(ImGuiCol_TextDisabled, MUTED);
    color(ImGuiCol_TextSelectedBg, accent(0.35));

    -- Inputs, sliders, combos.
    color(ImGuiCol_FrameBg, CONTROL);
    color(ImGuiCol_FrameBgHovered, CONTROL_HOVER);
    color(ImGuiCol_FrameBgActive, CONTROL_ACTIVE);
    color(ImGuiCol_CheckMark, accent());
    color(ImGuiCol_SliderGrab, accent(0.75));
    color(ImGuiCol_SliderGrabActive, accent());

    -- Buttons.
    color(ImGuiCol_Button, CONTROL);
    color(ImGuiCol_ButtonHovered, CONTROL_HOVER);
    color(ImGuiCol_ButtonActive, CONTROL_ACTIVE);

    -- Selectable rows / headers.
    color(ImGuiCol_Header, accent(0.22));
    color(ImGuiCol_HeaderHovered, accent(0.30));
    color(ImGuiCol_HeaderActive, accent(0.40));

    -- Separators.
    color(ImGuiCol_Separator, BORDER);
    color(ImGuiCol_SeparatorHovered, accent(0.60));
    color(ImGuiCol_SeparatorActive, accent());

    -- Scrollbars.
    color(ImGuiCol_ScrollbarBg, { 0.00, 0.00, 0.00, 0.12 });
    color(ImGuiCol_ScrollbarGrab, CONTROL_HOVER);
    color(ImGuiCol_ScrollbarGrabHovered, CONTROL_ACTIVE);
    color(ImGuiCol_ScrollbarGrabActive, accent(0.80));

    -- Progress bars.
    color(ImGuiCol_PlotHistogram, accent());
    color(ImGuiCol_PlotHistogramHovered, accent());

    -- Resize grip.
    color(ImGuiCol_ResizeGrip, accent(0.20));
    color(ImGuiCol_ResizeGripHovered, accent(0.45));
    color(ImGuiCol_ResizeGripActive, accent(0.70));

    -- Tables.
    color(ImGuiCol_TableHeaderBg, TABLE_HEADER);
    color(ImGuiCol_TableBorderStrong, BORDER);
    color(ImGuiCol_TableBorderLight, { BORDER[1], BORDER[2], BORDER[3], 0.45 });
    color(ImGuiCol_TableRowBg, TRANSPARENT);
    color(ImGuiCol_TableRowBgAlt, { 1.00, 1.00, 1.00, 0.035 });

    -- Shape and spacing: rounded corners and roomier padding.
    var(ImGuiStyleVar_WindowRounding, 6.0);
    var(ImGuiStyleVar_ChildRounding, 4.0);
    var(ImGuiStyleVar_FrameRounding, 4.0);
    var(ImGuiStyleVar_PopupRounding, 4.0);
    var(ImGuiStyleVar_ScrollbarRounding, 6.0);
    var(ImGuiStyleVar_GrabRounding, 4.0);
    var(ImGuiStyleVar_ScrollbarSize, 11.0);
    var(ImGuiStyleVar_WindowPadding, { 12, 10 });
    var(ImGuiStyleVar_FramePadding, { 8, 4 });
    var(ImGuiStyleVar_ItemSpacing, { 8, 4 });
    var(ImGuiStyleVar_ItemInnerSpacing, { 6, 4 });

    theme_stack[#theme_stack + 1] = { color_count, var_count };
end

local function pop_theme()
    local entry = table.remove(theme_stack);
    if entry == nil then return; end

    if entry[2] > 0 then imgui.PopStyleVar(entry[2]); end
    if entry[1] > 0 then imgui.PopStyleColor(entry[1]); end
end

local function reset_appearance()
    state.font_scale[1] = defaults.font_scale;
    state.theme = 'midnight';
    apply_theme_surfaces('midnight');

    for i = 1, 4 do
        state.background[i] = defaults.appearance.background[i];
        state.known_color[i] = defaults.appearance.known_color[i];
        state.learnable_color[i] = defaults.appearance.learnable_color[i];
        state.unknown_color[i] = defaults.appearance.unknown_color[i];
        state.header_color[i] = defaults.appearance.header_color[i];
        state.paging_color[i] = defaults.appearance.paging_color[i];
    end

    state.border[1] = defaults.appearance.border;
    state.title_bar[1] = defaults.appearance.title_bar;
    state.locked[1] = defaults.appearance.locked;
    state.zone_locked[1] = defaults.appearance.zone_locked;
    state.location_locked[1] = defaults.appearance.location_locked;
    state.settings_dirty = true;
end

local function reset_window()
    state.last_x = defaults.window.x;
    state.last_y = defaults.window.y;
    state.last_w = defaults.window.width;
    state.last_h = defaults.window.height;
    state.apply_saved_geometry = true;
    state.geometry_dirty = true;
end

local function reset_all()
    reset_appearance();
    reset_window();

    state.row_spacing = defaults.display.row_spacing;
    state.rows_mode = defaults.display.rows_mode;
    state.rows_per_page[1] = defaults.display.rows_per_page;

    state.columns.level[1] = defaults.display.columns.level;
    state.columns.points[1] = defaults.display.columns.points;
    state.columns.learn_skill[1] = defaults.display.columns.learn_skill;
    state.columns.type[1] = defaults.display.columns.type;
    state.columns.trait[1] = defaults.display.columns.trait;
    state.columns.mob_family[1] = defaults.display.columns.mob_family;

    state.remember_filters[1] = defaults.behavior.remember_filters;
    state.auto_highlight_learned[1] = defaults.behavior.auto_highlight_learned;
    state.location_interaction = defaults.behavior.location_interaction;
    state.location_open[1] = false;
    state.location_spell = nil;
    state.zone_info_open[1] = false;

    state.search[1] = '';
    state.last_search = '';
    state.filter_mode = 'all';
    state.sort_mode = 'level';
    state.sort_desc = false;
    state.page = 1;
    state.selected_spell = nil;

    state.config_last_x = defaults.config_window.x;
    state.config_last_y = defaults.config_window.y;
    state.config_last_w = defaults.config_window.width;
    state.config_last_h = defaults.config_window.height;
    state.apply_saved_config_geometry = true;
    state.config_geometry_dirty = true;

    state.zone_last_x = defaults.zone_window.x;
    state.zone_last_y = defaults.zone_window.y;
    state.zone_last_w = clamp(defaults.zone_window.width, ZONE_MIN_WIDTH, ZONE_MAX_WIDTH);
    state.zone_last_h = defaults.zone_window.height;
    state.zone_apply_saved_geometry = true;
    state.zone_geometry_dirty = true;

    state.settings_dirty = true;
end

local function section_title(value)
    imgui.TextColored(state.header_color, value);
    imgui.PushStyleColor(ImGuiCol_Separator, accent(0.35));
    imgui.Separator();
    imgui.PopStyleColor(1);
    imgui.Spacing();
end

local function draw_window_tab()
    section_title('WINDOW');

    local locked = { state.locked[1] };
    if imgui.Checkbox('Lock Window Position / Size', locked) then
        state.locked[1] = locked[1];
        state.settings_dirty = true;
    end

    local zone_locked = { state.zone_locked[1] };
    if imgui.Checkbox('Lock Zone Info Position / Size', zone_locked) then
        state.zone_locked[1] = zone_locked[1];
        state.settings_dirty = true;
    end

    local location_locked = { state.location_locked[1] };
    if imgui.Checkbox('Lock Spell Location Position / Size', location_locked) then
        state.location_locked[1] = location_locked[1];
        state.settings_dirty = true;
    end

    local title_bar = { state.title_bar[1] };
    if imgui.Checkbox('Show Title Bar', title_bar) then
        state.title_bar[1] = title_bar[1];
        state.settings_dirty = true;
    end

    local border = { state.border[1] };
    if imgui.Checkbox('Show Border', border) then
        state.border[1] = border[1];
        state.settings_dirty = true;
    end

    imgui.Spacing();
    section_title('BACKGROUND');

    imgui.PushItemWidth(260);
    if imgui.ColorEdit4('Window Color##blu_bg', state.background) then
        state.settings_dirty = true;
    end

    local opacity = { state.background[4] };
    if imgui.SliderFloat('Background Opacity##blu_opacity', opacity, 0.05, 1.00, '%.2f') then
        state.background[4] = opacity[1];
        state.settings_dirty = true;
    end
    imgui.PopItemWidth();

    imgui.Spacing();
    if imgui.Button('Reset Window Position / Size') then
        reset_window();
    end
end

local function draw_font_colors_tab()
    section_title('THEME');

    local theme_index = 0;
    local theme_labels = {};
    for index, key in ipairs(AC_THEME_ORDER) do
        theme_labels[#theme_labels + 1] = AC_THEMES[key].label;
        if key == state.theme then theme_index = index - 1; end
    end
    local theme_value = { theme_index };
    imgui.PushItemWidth(260);
    if imgui.Combo('Theme##azure_theme', theme_value, table.concat(theme_labels, '\0') .. '\0\0') then
        local chosen = AC_THEME_ORDER[(tonumber(theme_value[1]) or 0) + 1];
        if chosen and chosen ~= state.theme then
            select_theme(chosen);
        end
    end
    imgui.PopItemWidth();
    imgui.TextColored(MUTED, 'Sets window surfaces, Window Color and Header / Accent (still editable below).');

    imgui.Spacing();
    section_title('FONT');

    imgui.PushItemWidth(260);
    if imgui.SliderFloat('Font Scale##blu_font', state.font_scale, 0.75, 1.75, '%.2fx') then
        state.settings_dirty = true;
    end
    imgui.PopItemWidth();

    imgui.Spacing();
    section_title('COLORS');

    imgui.PushItemWidth(260);
    if imgui.ColorEdit4('Known Spells##blu_known', state.known_color) then
        state.settings_dirty = true;
    end
    if imgui.ColorEdit4('Unknown - Learnable##blu_learnable', state.learnable_color) then
        state.settings_dirty = true;
    end
    if imgui.ColorEdit4('Unknown - Unlearnable##blu_unknown', state.unknown_color) then
        state.settings_dirty = true;
    end
    if imgui.ColorEdit4('Header / Accent##blu_header', state.header_color) then
        state.settings_dirty = true;
    end
    if imgui.ColorEdit4('Paging Buttons##blu_page', state.paging_color) then
        state.settings_dirty = true;
    end
    imgui.PopItemWidth();

    imgui.Spacing();
    if imgui.Button('Reset Appearance') then
        reset_appearance();
    end
end

local function draw_display_tab()
    section_title('ROW SPACING');

    if draw_toggle_button('Compact', 'row_spacing_compact', state.row_spacing == 'compact')
        and state.row_spacing ~= 'compact' then
        state.row_spacing = 'compact';
        state.settings_dirty = true;
    end

    imgui.SameLine();

    if draw_toggle_button('Normal', 'row_spacing_normal', state.row_spacing == 'normal')
        and state.row_spacing ~= 'normal' then
        state.row_spacing = 'normal';
        state.settings_dirty = true;
    end

    imgui.Spacing();
    section_title('ROWS PER PAGE');

    if draw_toggle_button('Auto', 'rows_mode_auto', state.rows_mode == 'auto')
        and state.rows_mode ~= 'auto' then
        state.rows_mode = 'auto';
        state.page = 1;
        state.settings_dirty = true;
    end

    imgui.SameLine();

    if draw_toggle_button('Fixed', 'rows_mode_fixed', state.rows_mode == 'fixed')
        and state.rows_mode ~= 'fixed' then
        state.rows_mode = 'fixed';
        state.page = 1;
        state.settings_dirty = true;
    end

    if state.rows_mode == 'fixed' then
        imgui.PushItemWidth(240);
        if imgui.SliderInt('Rows##blu_rows', state.rows_per_page, 8, 60) then
            state.page = 1;
            state.settings_dirty = true;
        end
        imgui.PopItemWidth();
    else
        imgui.TextColored(MUTED, 'Auto uses the current window height and font size.');
    end

    imgui.Spacing();
    section_title('VISIBLE COLUMNS');

    imgui.TextColored(MUTED, 'Spell is always visible.');

    for _, entry in ipairs({
        { 'Level', state.columns.level },
        { 'Points', state.columns.points },
        { 'Learn Skill', state.columns.learn_skill },
        { 'Type', state.columns.type },
        { 'Trait', state.columns.trait },
        { 'Mob Family', state.columns.mob_family },
    }) do
        local value = { entry[2][1] };
        if imgui.Checkbox(entry[1], value) then
            entry[2][1] = value[1];
            state.settings_dirty = true;
        end
    end
end

local function draw_behavior_tab()
    section_title('FILTER / SEARCH');

    local remember_filters = { state.remember_filters[1] };
    if imgui.Checkbox('Remember Search / Filter / Sort', remember_filters) then
        state.remember_filters[1] = remember_filters[1];
        state.settings_dirty = true;
    end

    imgui.TextColored(MUTED, 'Search checks Spell, Level, Points, Learn Skill, Type, Trait, and Mob Family.');
    imgui.TextColored(MUTED, 'Use | for OR searches, e.g. refresh|regen|goblin.');

    imgui.Spacing();
    section_title('LEARNING');

    local auto_highlight = { state.auto_highlight_learned[1] };
    if imgui.Checkbox('Auto-highlight Newly Learned Spell', auto_highlight) then
        state.auto_highlight_learned[1] = auto_highlight[1];
        state.settings_dirty = true;
    end

    imgui.TextColored(MUTED, 'Newly learned spells are selected and highlighted for 5 seconds.');

    imgui.Spacing();
    section_title('LEARNING LOCATIONS');

    imgui.TextColored(MUTED, 'Choose how the Learned From information opens.');

    if draw_toggle_button('Click', 'location_mode_click', state.location_interaction == 'click')
        and state.location_interaction ~= 'click' then
        state.location_interaction = 'click';
        state.settings_dirty = true;
    end

    imgui.SameLine();

    if draw_toggle_button('Hover', 'location_mode_hover', state.location_interaction == 'hover')
        and state.location_interaction ~= 'hover' then
        state.location_interaction = 'hover';
        state.location_open[1] = false;
        state.settings_dirty = true;
    end

    if state.location_interaction == 'click' then
        imgui.TextColored(MUTED, 'Click a spell name to open its location window. Recommended for most screens.');
    else
        imgui.TextColored(MUTED, 'Hover a spell name for the large quick-view tooltip. Best for high-resolution screens.');
    end

    imgui.Spacing();
    section_title('BLU LIMITS');

    imgui.PushItemWidth(200);
    if imgui.SliderInt('Assimilation merits##azure_assimilation', state.assimilation, 0, 5) then
        state.settings_dirty = true;
    end
    imgui.PopItemWidth();
    imgui.TextColored(MUTED, 'Adds +1 Blue Magic Point each at Lv75 when the client does not report live points.');

    imgui.Spacing();
    section_title('TARGET TAG');

    local tag = { state.target_tag[1] };
    if imgui.Checkbox('Show "Teaches" tag for targeted mobs', tag) then
        state.target_tag[1] = tag[1];
        state.settings_dirty = true;
    end
    local tag_locked = { state.target_tag_locked[1] };
    if imgui.Checkbox('Lock tag position', tag_locked) then
        state.target_tag_locked[1] = tag_locked[1];
        state.settings_dirty = true;
    end
    imgui.TextColored(MUTED, 'While BLU is your main job: a small tag shows when your target teaches a spell you are missing in this zone.');

    imgui.Spacing();
    section_title('RESET');

    if imgui.Button('Reset All Settings') then
        reset_all();
    end
end

local function get_build_points_used()
    local total = 0;
    local count = 0;
    for _, spell in ipairs(spells) do
        if state.build_selected[normalize_name(spell.name)] == true then
            total = total + (tonumber(spell.points) or 0);
            count = count + 1;
        end
    end
    return total, count;
end

local function enforce_build_cap(point_cap, slot_cap)
    point_cap = tonumber(point_cap) or 45;
    if point_cap < 0 then point_cap = 0; end
    slot_cap = tonumber(slot_cap) or 20;

    local total = 0;
    local slots = 0;

    -- Totals only. Selections are never removed here (1.12.0): new picks are
    -- blocked at the checkbox when they would go over, and Equip refuses a
    -- build that is over your limits, so a plan made for a higher level
    -- (or imported from BLUPrint-View) is kept intact.
    for _, spell in ipairs(spells) do
        local key = spell._key;
        if state.build_selected[key] == true then
            total = total + (tonumber(spell.points) or 0);
            slots = slots + 1;
        end
    end

    return total, slots;
end

-- Equipped-set cache (see get_current_equipped_spell_names); declared here so
-- the equip task can clear it when it finishes.
local equipped_cache = { names = {}, at = -1 };

local function equip_spell_list(selected, used, selected_count, source_label)
    if blu == nil or blu.reset_all_spells == nil or blu.set_spell_by_name == nil then
        log_message('BLU equip functions could not be initialized on this Ashita client.');
        return false;
    end

    selected = selected or {};
    selected_count = tonumber(selected_count) or #selected;
    used = tonumber(used) or 0;

    local point_cap, slot_cap = get_build_caps();

    if selected_count == 0 then
        log_message('No spells selected for the build.');
        return false;
    end

    if selected_count > slot_cap then
        log_message(('Cannot equip %d spells. Your BLU level allows %d set slots.'):fmt(selected_count, slot_cap));
        return false;
    end

    if used > point_cap then
        log_message(('Build exceeds your current BLU point cap by %d points.'):fmt(used - point_cap));
        return false;
    end

    -- Resolve the final spell ids before the equip task starts so the task
    -- only has to send the exact numeric ids used by Ashita's BLU packet.
    local rm = AshitaCore:GetResourceManager();
    local equip_list = {};
    if rm == nil then
        log_message('Unable to access Ashita spell resources.');
        return false;
    end

    for _, spell in ipairs(selected) do
        local resource = rm:GetSpellByName(tostring(spell.name), 0);
        if resource == nil or resource.Index < 512 or resource.Index > 1024 then
            log_message('Unable to resolve BLU spell for equip: ' .. tostring(spell.name));
            return false;
        end
        equip_list[#equip_list + 1] = { name = spell.name, id = resource.Index - 512 };
    end

    local delay = tonumber(blu.delay) or 1.0;
    if delay <= 0 then delay = 1.0; end
    if blu.mode == 'safe' and delay < 1.0 then delay = 1.0; end

    state.build_equipping[1] = true;
    log_message(('Equipping BLU build%s: %d spells, %d points. Please wait..'):fmt(
        source_label and (' from ' .. tostring(source_label)) or '', selected_count, used));

    ashita.tasks.once(1, (function(d, build)
        local ok, err = pcall(function()
            blu.reset_all_spells();
            coroutine.sleep(d);

            for index, spell in ipairs(build) do
                local result = blu.set_spell(index, spell.id);
                if result == false then
                    error(('Failed to queue BLU spell: %s'):format(tostring(spell.name)));
                end
                coroutine.sleep(d);
            end
        end);

        state.build_equipping[1] = false;
        equipped_cache.at = -1;

        if ok then
            log_message('Finished equipping BLU spell build.');
        else
            log_message('BLU equip failed: ' .. tostring(err));
        end
    end):bindn(delay, equip_list));

    return true;
end

local function equip_selected_build()
    local used, selected_count = get_build_points_used();
    local selected = {};

    for _, spell in ipairs(spells) do
        if state.build_selected[normalize_name(spell.name)] == true then
            selected[#selected + 1] = spell;
        end
    end

    return equip_spell_list(selected, used, selected_count, nil);
end


-- The spell-set offset pattern is scanned once (scanning on every click
-- caused a hitch); the equipped list itself is cached for one second.
local equipped_offset_ptr = nil;

local function get_current_equipped_spell_names()
    local now = os.clock();
    if equipped_cache.at >= 0 and (now - equipped_cache.at) < 1.0 then
        return equipped_cache.names;
    end
    equipped_cache.at = now;

    local ok, result = pcall(function()
        -- Read the same BLU spell-set memory used by Ashita's official blu helper.
        if equipped_offset_ptr == nil then
            local found = ashita.memory.find(0, 0, 'C1E1032BC8B0018D????????????B9????????F3A55F5E5B', 10, 0);
            if found == nil or found == 0 then
                return {};
            end
            equipped_offset_ptr = found;
        end

        local offset = ffi.cast('uint32_t*', equipped_offset_ptr);
        local blu_buffer = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('inventory'));
        if blu_buffer == 0 then return {}; end
        blu_buffer = ashita.memory.read_uint32(blu_buffer);
        if blu_buffer == 0 then return {}; end

        local is_blu_main = safe_blu_level() ~= nil;
        local base = blu_buffer + offset[0] + (is_blu_main and 0x04 or 0xA0);
        local ids = ashita.memory.read_array(base, 0x14);
        local names = {};
        local rm = AshitaCore:GetResourceManager();
        if rm == nil then return names; end

        for _, value in ipairs(ids) do
            value = tonumber(value) or 0;
            if value ~= 0 then
                local spell = rm:GetSpellById(value + 512);
                if spell ~= nil and spell.Name ~= nil and spell.Name[1] ~= nil then
                    names[#names + 1] = spell.Name[1];
                end
            end
        end
        return names;
    end);

    if not ok or result == nil then
        result = {};
    end
    equipped_cache.names = result;
    return result;
end

-- Spells currently set in game, as spell rows, plus their point total.
local function get_equipped_spells()
    local lookup = {};
    for _, name in ipairs(get_current_equipped_spell_names()) do
        lookup[normalize_name(name)] = true;
    end
    local list = {};
    local points = 0;
    for _, spell in ipairs(spells) do
        local alias = resource_aliases[spell._key];
        if lookup[spell._key] or (alias ~= nil and lookup[alias]) then
            list[#list + 1] = spell;
            points = points + (tonumber(spell.points) or 0);
        end
    end
    return list, points;
end

-- What equipping `target` would change: spells added, removed, unchanged.
local function equipped_diff(target)
    local equipped = get_equipped_spells();
    local in_target = {};
    for _, spell in ipairs(target or {}) do in_target[spell._key] = true; end
    local in_equipped = {};
    for _, spell in ipairs(equipped) do in_equipped[spell._key] = true; end

    local adds, removes, same = {}, {}, 0;
    for _, spell in ipairs(target or {}) do
        if in_equipped[spell._key] then same = same + 1; else adds[#adds + 1] = spell; end
    end
    for _, spell in ipairs(equipped) do
        if not in_target[spell._key] then removes[#removes + 1] = spell; end
    end
    return adds, removes, same, #equipped;
end

local function ensure_build_folder()
    local folder = ('%s\\addons\\%s\\BLUPrints\\'):fmt(AshitaCore:GetInstallPath(), addon.name);
    if ashita.fs ~= nil and ashita.fs.exists ~= nil and not ashita.fs.exists(folder) then
        if ashita.fs.create_dir ~= nil then
            ashita.fs.create_dir(folder);
        end
    end
    return folder;
end

local function save_build_to_file()
    local used, selected_count = get_build_points_used()
    local point_cap, slot_cap = get_build_caps()

    if selected_count == 0 then
        log_message('No spells selected. Nothing to save.')
        return
    end

    local folder = ensure_build_folder()
    local build_name = tostring(state.build_name[1] or '')
    build_name = build_name:gsub('^%s+', ''):gsub('%s+$', '')
    build_name = build_name:gsub('[<>:\"/\\|%?%*]', '_')
    build_name = build_name:gsub('[%. ]+$', '')

    if build_name == '' then
        build_name = 'AzureCodex_Set_' .. os.date('%Y%m%d_%H%M%S')
    end

    if not build_name:lower():match('%.txt$') then
        build_name = build_name .. '.txt'
    end

    local path = folder .. '\\' .. build_name
    local file = io.open(path, 'w')
    if file == nil then
        log_message('Unable to save build file: ' .. path)
        return
    end

    file:write('BLU Spell Build\n')
    file:write('==============================\n')
    file:write('Generated: ' .. os.date('%Y-%m-%d %H:%M:%S') .. '\n')
    file:write('Point Total: ' .. tostring(used) .. '/' .. tostring(point_cap) .. '\n')
    file:write('Spells: ' .. tostring(selected_count) .. '/' .. tostring(slot_cap) .. '\n')
    file:write('\nSelected Spells\n')
    file:write('------------------------------\n')

    local index = 0
    for _, spell in ipairs(spells) do
        if state.build_selected[normalize_name(spell.name)] == true then
            index = index + 1
            file:write(string.format('%d. %s - Lv %s - %s pt\n',
                index, tostring(spell.name), tostring(spell.level), tostring(spell.points)))
        end
    end

    file:close()
    state.build_files_at = -1
    state.view_cache = nil
    log_message('Saved BLU spell build to ' .. path)
end

local get_saved_build_files_uncached;

-- The folder listing is cached for 3 seconds (it was read from disk every
-- frame on the BLUPrints / BLUPrint-View pages). Save / delete / Refresh
-- clear it immediately.
local function get_saved_build_files()
    local now = os.clock();
    if state.build_files ~= nil and (state.build_files_at or -1) >= 0 and (now - state.build_files_at) < 3.0 then
        return state.build_files;
    end
    state.build_files = get_saved_build_files_uncached();
    state.build_files_at = now;
    return state.build_files;
end

get_saved_build_files_uncached = function()
    local files = {};
    local folder = ensure_build_folder();

    if ashita.fs ~= nil and ashita.fs.get_dir ~= nil then
        local ok, result = pcall(function()
            return ashita.fs.get_dir(folder, '.*.txt', true);
        end);
        if ok and result ~= nil then
            for _, value in ipairs(result) do
                if value ~= nil and tostring(value) ~= '' then
                    local fullpath = tostring(value);
                    local filename = fullpath:match('([^\\/]+)$') or fullpath;
                    if filename:lower():sub(-4) == '.txt' then
                        files[#files + 1] = filename;
                    end
                end
            end
        end
    end

    table.sort(files, function(a, b) return a:lower() > b:lower() end);
    return files;
end

local function load_saved_build_file(filename, equip_in_game)
    local folder = ensure_build_folder()
    local path = folder .. '\\' .. tostring(filename or '')
    local file = io.open(path, 'r')
    if file == nil then
        log_message('Unable to open saved build: ' .. path)
        return false
    end

    local loaded = {}
    for line in file:lines() do
        local name = line:match('^%s*%d+%.%s*(.-)%s+%- %s*Lv%s+%d+%s+%-%s+%d+%s+pt%s*$')
        if name ~= nil then
            loaded[normalize_name(name)] = true
        end
    end
    file:close()

    local point_cap, slot_cap = get_build_caps()
    local selected = {}
    local used = 0
    local count = 0

    for _, spell in ipairs(spells) do
        local key = normalize_name(spell.name)
        local cost = tonumber(spell.points) or 0
        if loaded[key] and count < slot_cap and (used + cost) <= point_cap then
            selected[#selected + 1] = spell
            used = used + cost
            count = count + 1
        end
    end

    if count == 0 then
        log_message('No valid spells were found in saved build: ' .. tostring(filename));
        return false
    end

    if equip_in_game then
        state.build_load_open[1] = false
        return equip_spell_list(selected, used, count, filename);
    end

    -- Calculator loading mode remains available for the loader window.
    state.build_selected = {}
    for _, spell in ipairs(selected) do
        state.build_selected[normalize_name(spell.name)] = true
    end

    state.build_load_open[1] = false
    log_message(('Loaded BLU spell build: %d spells, %d points.'):fmt(count, used))
    return true
end

local function draw_saved_build_loader()
    if not state.build_load_open[1] then
        return
    end

    state.build_load_files = get_saved_build_files()
    push_theme()
    if imgui.Begin('Load BLU Spell Build##bluspells_load_build', state.build_load_open, 0) then
        imgui.TextColored(state.header_color, 'Saved Builds')
        imgui.Separator()

        if #state.build_load_files == 0 then
            imgui.TextColored(MUTED, 'No saved builds found in BLUPrints.')
        else
            for _, filename in ipairs(state.build_load_files) do
                if imgui.Button(filename .. '##saved_build_' .. normalize_name(filename)) then
                    load_saved_build_file(filename)
                    break
                end
            end
        end
    end

    imgui.End()
    pop_theme()
end

-- Trait list with tier, points toward the next tier and a progress bar.
local function draw_trait_list(traits, id_prefix)
    if #traits == 0 then
        imgui.TextColored(MUTED, 'No traits selected.');
        return;
    end

    for index, entry in ipairs(traits) do
        local color = entry.tier > 0 and state.known_color or state.unknown_color;
        imgui.TextColored(color, trait_label(entry));
        imgui.SameLine();
        if entry.maxed then
            imgui.TextColored(MUTED, ('%d pts  MAX'):fmt(entry.points));
        else
            imgui.TextColored(MUTED, ('%d / %d pts'):fmt(entry.points, entry.next_points or 0));
            if entry.tier > 0 then
                imgui.SameLine();
                imgui.TextColored(MUTED, ('(next: %s)'):fmt(ROMAN[entry.tier + 1] or tostring(entry.tier + 1)));
            end
        end
        if imgui.ProgressBar ~= nil then
            local ratio = 1.0;
            if not entry.maxed and entry.next_points ~= nil then
                local span = math.max(1, entry.next_points - entry.prev_points);
                ratio = math.max(0, math.min(1.0, (entry.points - entry.prev_points) / span));
            end
            imgui.ProgressBar(ratio, { 0, 6 }, '');
        end
    end
end

-- "vs Equipped" summary for a planned / saved build.
local function draw_equipped_diff(target)
    local adds, removes, same, equipped_count = equipped_diff(target);
    imgui.TextColored(state.header_color, 'VS EQUIPPED');
    imgui.SameLine();
    if equipped_count == 0 then
        imgui.TextColored(MUTED, '(equipped set not readable - BLU main only)');
        return;
    end
    if #adds == 0 and #removes == 0 then
        imgui.TextColored(state.known_color, 'Same as your equipped set.');
        return;
    end
    imgui.TextColored(MUTED, ('%d unchanged'):fmt(same));

    local function names(list)
        local parts = {};
        for _, spell in ipairs(list) do parts[#parts + 1] = tostring(spell.name); end
        return table.concat(parts, ', ');
    end
    if #adds > 0 then
        imgui.TextColored(state.known_color, '+ ');
        imgui.SameLine(0, 0);
        imgui.TextWrapped(names(adds));
    end
    if #removes > 0 then
        imgui.TextColored(state.unknown_color, '- ');
        imgui.SameLine(0, 0);
        imgui.TextWrapped(names(removes));
    end
end

-- Cheapest known, unselected spells that reach the trait's next tier.
local function plan_next_tier(trait_key, current_weight, next_need)
    local candidates = {};
    for _, spell in ipairs(spells) do
        if state.build_selected[spell._key] ~= true and is_known(spell.name) then
            local trait_name = get_spell_trait_name(spell);
            if trait_name ~= nil and normalize_name(trait_name) == trait_key then
                candidates[#candidates + 1] = spell;
            end
        end
    end
    table.sort(candidates, function(a, b)
        local ar = (tonumber(a.points) or 0) / get_trait_weight(a);
        local br = (tonumber(b.points) or 0) / get_trait_weight(b);
        if ar ~= br then return ar < br; end
        return (tonumber(a.points) or 0) < (tonumber(b.points) or 0);
    end);

    local needed = (tonumber(next_need) or 0) - (tonumber(current_weight) or 0);
    local picks, cost, got = {}, 0, 0;
    for _, spell in ipairs(candidates) do
        if got >= needed then break; end
        picks[#picks + 1] = spell;
        cost = cost + (tonumber(spell.points) or 0);
        got = got + get_trait_weight(spell);
    end
    return picks, cost, got >= needed;
end

local planner_cache = { key = nil, rows = {} };

local function draw_trait_planner(traits, used, selected_count, point_cap, slot_cap)
    imgui.TextColored(state.header_color, 'TRAIT PLANNER');
    imgui.SameLine();
    imgui.Checkbox('All traits##azure_planner_all', state.planner_all);
    imgui.Separator();
    imgui.TextColored(MUTED, 'Cheapest known spells to reach each next tier.');

    -- The plan only changes with the selection, known spells or options.
    local selected_keys = {};
    for _, spell in ipairs(spells) do
        if state.build_selected[spell._key] == true then selected_keys[#selected_keys + 1] = spell._key; end
    end
    local cache_key = table.concat({
        table.concat(selected_keys, ','), tostring(known_cache.version), tostring(state.planner_all[1]),
    }, '|');
    if planner_cache.key ~= cache_key then
        planner_cache.key = cache_key;
        planner_cache.rows = nil;
    end

    -- Traits in the build, or every trait any known spell can give.
    local list = {};
    local seen = {};
    for _, entry in ipairs(traits) do
        list[#list + 1] = entry;
        seen[entry.key] = true;
    end
    if state.planner_all[1] then
        local extra = {};
        for _, spell in ipairs(spells) do
            local trait_name = get_spell_trait_name(spell);
            if trait_name ~= nil then
                local key = normalize_name(trait_name);
                if not seen[key] and is_known(spell.name) then
                    seen[key] = true;
                    local tiers = trait_tiers_for(trait_name);
                    extra[#extra + 1] = {
                        name = trait_name, key = key, weight = 0, tier = 0,
                        max_tier = #tiers, maxed = false, points = 0,
                        next_need = tiers[1], next_points = tiers[1] * TRAIT_POINT_SCALE, prev_points = 0,
                    };
                end
            end
        end
        table.sort(extra, function(a, b) return a.name:lower() < b.name:lower(); end);
        for _, entry in ipairs(extra) do list[#list + 1] = entry; end
    end

    if planner_cache.rows == nil then
        planner_cache.rows = {};
        for _, entry in ipairs(list) do
            if not entry.maxed and entry.next_need ~= nil then
                local picks, cost, complete = plan_next_tier(entry.key, entry.weight, entry.next_need);
                planner_cache.rows[#planner_cache.rows + 1] = {
                    entry = entry, picks = picks, cost = cost, complete = complete,
                };
            end
        end
    end

    local shown = 0;
    for _, plan in ipairs(planner_cache.rows) do
        local entry = plan.entry;
        do
            shown = shown + 1;
            local picks, cost, complete = plan.picks, plan.cost, plan.complete;
            local target_label = ('%s %s'):fmt(entry.name, ROMAN[entry.tier + 1] or tostring(entry.tier + 1));
            imgui.TextColored(state.header_color, target_label);
            imgui.SameLine();
            if #picks == 0 then
                imgui.TextColored(MUTED, 'no known spells left');
            elseif not complete then
                local parts = {};
                for _, spell in ipairs(picks) do parts[#parts + 1] = tostring(spell.name); end
                imgui.TextColored(MUTED, ('not reachable yet (%s)'):fmt(table.concat(parts, ', ')));
            else
                local fits = (used + cost) <= point_cap and (selected_count + #picks) <= slot_cap;
                local parts = {};
                for _, spell in ipairs(picks) do parts[#parts + 1] = tostring(spell.name); end
                imgui.TextColored(fits and TEXT or state.unknown_color,
                    ('+%s  (%d pt, %d slot%s)'):fmt(table.concat(parts, ', '), cost, #picks, #picks == 1 and '' or 's'));
                if fits then
                    imgui.SameLine();
                    if imgui.SmallButton('Add##azure_plan_' .. entry.key) then
                        for _, spell in ipairs(picks) do
                            state.build_selected[spell._key] = true;
                        end
                    end
                else
                    imgui.SameLine();
                    imgui.TextColored(MUTED, '[over cap]');
                end
            end
        end
    end
    if shown == 0 then
        imgui.TextColored(MUTED, #list == 0 and 'Select spells (or tick All traits) to plan.' or 'Every listed trait is maxed.');
    end
end

local function draw_spell_build_tab()
    -- Keep saved loadouts at the top of BLUPrints for quick access.
    section_title('AZURE LOADOUT');

    -- Keep the selector on its own row so the BLUPrint controls stay uncluttered.
    imgui.Spacing();

    state.spellsets_files = get_saved_build_files();
    if #state.spellsets_files == 0 then
        imgui.TextColored(MUTED, 'No saved sets found in BLUPrints.');
    else
        local selected_name = tostring(state.spellset_selected[1] or '')
        local current_index = 0
        local combo_items = { 'Select a BLUPrint...' }

        for index, filename in ipairs(state.spellsets_files) do
            combo_items[#combo_items + 1] = filename
            if filename == selected_name then
                current_index = index
            end
        end

        local item_string = table.concat(combo_items, '\0') .. '\0\0'
        local combo_value = { current_index }

        imgui.PushItemWidth(360)
        if imgui.Combo('##azure_bluprints_loadout_combo', combo_value, item_string, math.min(12, #combo_items)) then
            local chosen_index = tonumber(combo_value[1]) or 0
            local filename = chosen_index > 0 and state.spellsets_files[chosen_index] or nil
            if filename ~= nil then
                state.spellset_selected[1] = filename
                -- Ask first; equipping replaces your whole set.
                state.loadout_pending = filename
            end
        end
        imgui.PopItemWidth()

        imgui.SameLine();
        if imgui.Button('Refresh##azure_bluprints_refresh') then
            state.build_files_at = -1;
            state.spellsets_files = get_saved_build_files();
            local current = tostring(state.spellset_selected[1] or '');
            local found = false;
            for _, filename in ipairs(state.spellsets_files) do
                if filename == current then
                    found = true;
                    break;
                end
            end
            if not found then
                state.spellset_selected[1] = '';
            end
            state.view_cache = nil;
        end

        if state.loadout_pending ~= nil then
            imgui.TextColored(state.learnable_color, ('Equip %s?'):fmt(tostring(state.loadout_pending)));
            imgui.SameLine();
            if imgui.Button('Equip##azure_loadout_confirm') then
                load_saved_build_file(state.loadout_pending, true);
                state.loadout_pending = nil;
            end
            imgui.SameLine();
            if imgui.Button('Cancel##azure_loadout_cancel') then
                state.loadout_pending = nil;
            end
        end
    end

    imgui.Spacing();
    imgui.Spacing();
    section_title('BLUPRINTS');

    local point_cap, slot_cap = get_build_caps();
    local used, selected_count = enforce_build_cap(point_cap, slot_cap);
    local remaining = point_cap - used;

    -- Calculator controls are intentionally stacked for a cleaner layout.
    local equip_label = state.build_equipping[1] and 'Equipping...' or 'Equip This Build';
    local equip_available = selected_count > 0 and not state.build_equipping[1];

    if equip_available then
        if imgui.Button(equip_label .. '##blu_build_equip') then
            equip_selected_build();
        end
    else
        imgui.Button(equip_label .. '##blu_build_equip_disabled');
    end

    imgui.SameLine();
    if imgui.Button('Clear Build##blu_build_clear') then
        state.build_selected = {};
        used, selected_count = 0, 0;
        remaining = point_cap;
    end

    if imgui.Button('Select Currently Equipped##blu_build_equipped') then
        state.build_selected = {};
        used, selected_count = 0, 0;
        local equipped = get_current_equipped_spell_names();
        local equipped_lookup = {};
        for _, name in ipairs(equipped) do
            equipped_lookup[normalize_name(name)] = true;
        end

        for _, spell in ipairs(spells) do
            local key = normalize_name(spell.name);
            local cost = tonumber(spell.points) or 0;
            if equipped_lookup[key] and selected_count < slot_cap and (used + cost) <= point_cap then
                state.build_selected[key] = true;
                used = used + cost;
                selected_count = selected_count + 1;
            end
        end
        remaining = point_cap - used;

        if #equipped == 0 then
            log_message('Unable to read currently equipped BLU spells.');
        end
    end

    if imgui.Button('Save Current Build##blu_build_save') then
        save_build_to_file();
    end
    imgui.SameLine();
    imgui.PushItemWidth(300);
    imgui.InputText('##blu_build_name', state.build_name, 128);
    imgui.PopItemWidth();
    imgui.SameLine();
    imgui.TextColored(MUTED, 'Equipset Name');

    imgui.Spacing();
    imgui.Spacing();
    align_label();
    imgui.Text('Search:');
    imgui.SameLine();
    imgui.PushItemWidth(260);
    imgui.InputText('##blu_build_search', state.build_search, 128);
    imgui.PopItemWidth();

    imgui.Separator();

    -- Spell selection remains in the main Azure Codex window.  The live
    -- Spell Card and Trait Calculator are rendered in a companion window.
    imgui.TextColored(state.header_color, 'SELECT SPELLS');
    imgui.SameLine();
    if imgui.Button('Clear all Checked##azure_codex_clear_checked') then
        state.build_selected = {};
        used, selected_count = 0, 0;
        remaining = point_cap;
    end
    imgui.TextColored(MUTED, ('Choose up to %d spells within %d BLU points (your current limits).'):fmt(slot_cap, point_cap));
    imgui.Spacing();

    -- Keep the BLUPrint controls and SELECT SPELLS header fixed while only
    -- the spell list itself scrolls.
    local list_height = select(2, imgui.GetContentRegionAvail());
    list_height = math.max(120, tonumber(list_height) or 120);
    -- BeginChild uses ImGui's ChildBg color rather than WindowBg. Keep the
    -- scrollable spell list visually consistent with the user-configured
    -- Azure Codex background (including opacity).
    imgui.PushStyleColor(ImGuiCol_ChildBg, {
        state.background[1], state.background[2], state.background[3], state.background[4]
    });
    imgui.BeginChild('##azure_codex_bluprints_spell_list', { 0, list_height });

    local query = tostring(state.build_search[1] or ''):lower();
    for _, spell in ipairs(spells) do
        local haystack = spell_haystack(spell);

        if query == '' or haystack:find(query, 1, true) ~= nil then
            local key = normalize_name(spell.name);
            local checked = state.build_selected[key] == true;
            local cost = tonumber(spell.points) or 0;
            local would_exceed_points = (not checked) and ((used + cost) > point_cap);
            local would_exceed_slots = (not checked) and (selected_count >= slot_cap);
            local blocked = would_exceed_points or would_exceed_slots;
            local known = is_known(spell.name);

            -- Use the exact same configurable Known / Learnable / Unlearnable
            -- colors as the main spell list.  Capacity blocking does not
            -- replace the spell's learning-state color.
            local _, spell_color = get_spell_display_state(spell);
            imgui.PushStyleColor(ImGuiCol_Text, spell_color);

            local value = { checked };
            if not known then
                -- Unknown spells remain visible with their configured learning-state
                -- color, but cannot be selected for a BLUPrint until learned.
                imgui.BeginDisabled();
                imgui.Checkbox(('%s  [%d pt]##build_%s'):fmt(tostring(spell.name), cost, key), value);
                imgui.EndDisabled();
            elseif blocked then
                imgui.BeginDisabled();
                imgui.Checkbox(('%s  [%d pt]##build_%s'):fmt(tostring(spell.name), cost, key), value);
                imgui.EndDisabled();
            else
                if imgui.Checkbox(('%s  [%d pt]##build_%s'):fmt(tostring(spell.name), cost, key), value) then
                    if checked then
                        state.build_selected[key] = false;
                        used, selected_count = get_build_points_used();
                    elseif (used + cost) <= point_cap and selected_count < slot_cap then
                        state.build_selected[key] = true;
                        used = used + cost;
                        selected_count = selected_count + 1;
                    end
                end
            end

            imgui.PopStyleColor(1);

            imgui.SameLine();
            local suffix = blocked and (would_exceed_points and '  [cap]' or ('  [%d slots]'):fmt(slot_cap)) or '';
            imgui.TextColored(MUTED, ('Lv %s  %s%s'):fmt(
                tostring(spell.level or '--'), tostring(get_spell_trait_badge(spell) or 'None'), suffix));
        end
    end

    imgui.EndChild();
    imgui.PopStyleColor();
end

local function draw_bluprints_companion_window()
    if not state.open[1] or not state.build_page[1] then
        return;
    end

    local main_x = tonumber(state.main_frame_x);
    local main_y = tonumber(state.main_frame_y);
    local main_w = tonumber(state.main_frame_w);
    local main_h = tonumber(state.main_frame_h);
    if not main_x or not main_y or not main_w or not main_h then
        return;
    end

    -- This window intentionally follows the main Azure Codex window and has
    -- no close button. It exists only while the BLUPrints tab is active.
    imgui.SetNextWindowPos({ main_x + main_w + 8, main_y });
    imgui.SetNextWindowSize({ 500, main_h });

    push_theme();
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);

    local flags = bit.bor(ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoResize);
    if not state.title_bar[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar);
    end

    if imgui.Begin('Azure Codex - BLUPrint Details##azure_codex_bluprint_details', nil, flags) then
        local base_font_size = imgui.GetFontSize();
        local requested_size = base_font_size * state.font_scale[1];
        imgui.PushFont(nil, requested_size);

        local point_cap, slot_cap, cap_estimated = get_build_caps();
        local used, selected_count = enforce_build_cap(point_cap, slot_cap);
        local trait_totals, selected_spells = get_trait_totals();

        imgui.TextColored(state.header_color, 'SPELL CARD');
        imgui.Separator();
        imgui.TextColored(state.known_color, ('%d / %d SPELLS'):fmt(selected_count, slot_cap));
        imgui.SameLine();
        imgui.Text(('%d / %d POINTS'):fmt(used, point_cap));
        if cap_estimated then
            imgui.SameLine();
            imgui.TextColored(MUTED, '(level limits)');
        end
        imgui.Spacing();

        if #selected_spells == 0 then
            imgui.TextColored(MUTED, 'No spells selected.');
            imgui.TextColored(MUTED, 'Your BLUPrint will appear here.');
        else
            for slot = 1, slot_cap do
                local spell = selected_spells[slot];
                if spell ~= nil then
                    local cost = tonumber(spell.points) or 0;
                    imgui.TextColored(state.header_color, ('%02d'):fmt(slot));
                    imgui.SameLine();
                    imgui.Text(tostring(spell.name));
                    imgui.SameLine();
                    imgui.TextColored(MUTED, ('Lv %s  %d pt'):fmt(tostring(spell.level or '--'), cost));
                    local trait_text = get_spell_trait_badge(spell);
                    if trait_text ~= nil and tostring(trait_text):lower() ~= 'none' then
                        imgui.SameLine();
                        imgui.TextColored(state.header_color, tostring(trait_text));
                    end
                else
                    imgui.TextColored(BORDER, ('%02d  -- empty --'):fmt(slot));
                end
            end
        end

        imgui.Spacing();
        if imgui.ProgressBar ~= nil then
            local ratio = point_cap > 0 and math.min(1.0, used / point_cap) or 0;
            imgui.ProgressBar(ratio, { 0, 8 }, '');
        end

        if #selected_spells > 0 then
            imgui.Spacing();
            draw_equipped_diff(selected_spells);
        end

        imgui.Spacing();
        imgui.Separator();
        imgui.TextColored(state.header_color, 'TRAIT CALCULATOR');
        imgui.SameLine();
        imgui.TextDisabled('(?)');
        if imgui.IsItemHovered() then
            imgui.BeginTooltip();
            imgui.PushTextWrapPos(420);
            imgui.TextUnformatted('HorizonXI / LandSandBoat 75-era rules: each spell gives 4 points to its trait (some give more: '
                .. 'Self-Destruct, Frightful Roar, Light of Penance x2; Voracious Trunk x3; Actinic Burst, Plasma Charge, '
                .. 'Winds of Promyvion x4). Most traits gain a tier every 8 points; Auto Refresh needs 32; Resist Gravity '
                .. 'tiers are 8 / 12 / 16. Each trait has its own maximum tier.');
            imgui.PopTextWrapPos();
            imgui.EndTooltip();
        end
        imgui.Separator();
        draw_trait_list(trait_totals, 'card');

        imgui.Spacing();
        draw_trait_planner(trait_totals, used, selected_count, point_cap, slot_cap);

        imgui.PopFont();
    end

    imgui.End();
    imgui.PopStyleVar(1);
    pop_theme();
end

local function draw_location_window()
    if not state.location_open[1] or state.location_spell == nil then
        return;
    end

    local spell = state.location_spell;
    local entries = locations.get(spell.name) or {};

    if state.location_apply_default_size then
        imgui.SetNextWindowSize({ 760, 650 });
        state.location_apply_default_size = false;
        state.location_size_initialized = true;
    end

    if imgui.SetNextWindowSizeConstraints ~= nil then
        imgui.SetNextWindowSizeConstraints(
            { LOCATION_MIN_WIDTH, 180 },
            { LOCATION_MAX_WIDTH, 1200 }
        );
    end

    local location_flags = 0;
    if state.location_locked[1] then
        location_flags = bit.bor(
            location_flags,
            ImGuiWindowFlags_NoMove,
            ImGuiWindowFlags_NoResize
        );
    end
    if not state.title_bar[1] then
        location_flags = bit.bor(location_flags, ImGuiWindowFlags_NoTitleBar);
    end

    -- push_theme applies the same configured window color / transparency
    -- used by the main BLUSpells window.
    push_theme();
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);

    -- Keep one stable ImGui window identity for every spell so position/size are shared.
    -- The text before ### may change; the ID after ### remains constant.
    local title = 'Azure Codex - Spell Locations - ' .. tostring(spell.name) .. '###bluspells_locations';
    if imgui.Begin(title, state.location_open, location_flags) then
        local base_font_size = imgui.GetFontSize();
        local requested_size = base_font_size * state.font_scale[1];
        imgui.PushFont(nil, requested_size);
        if state.location_reset_scroll and imgui.SetScrollY ~= nil then
            imgui.SetScrollY(0);
            state.location_reset_scroll = false;
        end

        if not state.title_bar[1] then
            local window_w = select(1, imgui.GetWindowSize());
            window_w = tonumber(window_w) or 760;

            local saved_x, saved_y = imgui.GetCursorPos();
            imgui.SetCursorPos({ math.max(8, window_w - 48), 6 });

            if imgui.Button('X##bluspells_locations_close', { 22, 20 }) then
                state.location_open[1] = false;
            end

            imgui.SetCursorPos({ saved_x, saved_y });
        end

        local location_avail_w = select(1, imgui.GetContentRegionAvail());
        location_avail_w = tonumber(location_avail_w) or 760;

        if imgui.BeginTable ~= nil and location_avail_w >= LOCATION_TWO_COLUMN_WIDTH then
            local header_flags = 0;
            if ImGuiTableFlags_SizingStretchProp ~= nil then
                header_flags = bit.bor(header_flags, ImGuiTableFlags_SizingStretchProp);
            end

            if imgui.BeginTable('##bluspells_location_header', 2, header_flags) then
                imgui.TableSetupColumn('##location_spell', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);
                imgui.TableSetupColumn('##location_family', ImGuiTableColumnFlags_WidthFixed or 0, 230);

                imgui.TableNextRow();

                imgui.TableNextColumn();
                imgui.TextColored(state.header_color, tostring(spell.name));

                imgui.TableNextColumn();
                imgui.TextColored(MUTED, 'Mob Family:');
                imgui.SameLine();
                imgui.Text(tostring(spell.mob_family or '--'));

                imgui.EndTable();
            end
        else
            -- On narrow windows stack the family under the spell name instead
            -- of clipping it off the right edge.
            imgui.TextColored(state.header_color, tostring(spell.name));
            imgui.TextColored(MUTED, 'Mob Family:');
            imgui.SameLine();
            imgui.Text(tostring(spell.mob_family or '--'));
        end

        imgui.Separator();

        if #entries == 0 then
            imgui.TextColored(MUTED, 'No learning locations available.');
        else
            for zone_index, entry in ipairs(entries) do
                if zone_index > 1 then
                    imgui.Spacing();
                end

                imgui.TextColored(state.header_color, locations.get_zone_name(entry.zone));
                imgui.Separator();

                local mobs = entry.mobs or {};
                if #mobs == 0 then
                    imgui.TextColored(MUTED, 'No mobs listed.');
                else
                    local current_w = select(1, imgui.GetContentRegionAvail());
                    current_w = tonumber(current_w) or location_avail_w;

                    -- Narrow layout: one column for readability.
                    if current_w < LOCATION_TWO_COLUMN_WIDTH or imgui.BeginTable == nil then
                        for _, mob_name in ipairs(mobs) do
                            imgui.Text('  - ' .. tostring(mob_name));
                        end
                    else
                        -- Wide layout: split the list evenly into two columns.
                        local left_count = math.ceil(#mobs / 2);
                        local table_flags = 0;
                        if ImGuiTableFlags_SizingStretchSame ~= nil then
                            table_flags = bit.bor(table_flags, ImGuiTableFlags_SizingStretchSame);
                        end

                        if imgui.BeginTable(
                            '##location_zone_' .. tostring(zone_index), 2, table_flags
                        ) then
                            imgui.TableSetupColumn('##left', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);
                            imgui.TableSetupColumn('##right', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);

                            for row = 1, left_count do
                                imgui.TableNextRow();

                                imgui.TableNextColumn();
                                local left_mob = mobs[row];
                                if left_mob ~= nil then
                                    imgui.Text('  - ' .. tostring(left_mob));
                                end

                                imgui.TableNextColumn();
                                local right_index = row + left_count;
                                local right_mob = mobs[right_index];
                                if right_mob ~= nil then
                                    imgui.Text('  - ' .. tostring(right_mob));
                                end
                            end

                            imgui.EndTable();
                        end
                    end
                end
            end
        end

        imgui.PopFont();
    end

    imgui.End();
    imgui.PopStyleVar();
    pop_theme();
end

local function draw_zone_info_window()
    if not state.zone_info_open[1] then
        state.zone_apply_saved_geometry = true;
        return;
    end

    if state.zone_apply_saved_geometry then
        imgui.SetNextWindowPos({ state.zone_last_x, state.zone_last_y }, { 0, 0 });
        imgui.SetNextWindowSize({ state.zone_last_w, state.zone_last_h });
        state.zone_apply_saved_geometry = false;
    end

    local zone_id = safe_current_zone_id();

    if zone_id ~= state.zone_last_id then
        state.zone_last_id = zone_id;
        state.zone_reset_scroll = true;
    end

    local zone_name = zone_id and locations.get_zone_name(zone_id) or 'Unknown Zone';
    local known_count, total_count, rows = get_zone_progress(zone_id);

    local zone_flags = 0;
    if state.zone_locked[1] then
        zone_flags = bit.bor(
            zone_flags,
            ImGuiWindowFlags_NoMove,
            ImGuiWindowFlags_NoResize
        );
    end
    if not state.title_bar[1] then
        zone_flags = bit.bor(zone_flags, ImGuiWindowFlags_NoTitleBar);
    end

    -- Keep Zone Info usable on narrow layouts while preventing the window from
    -- collapsing so far that the header/status fields become unreadable.
    if imgui.SetNextWindowSizeConstraints ~= nil then
        imgui.SetNextWindowSizeConstraints(
            { ZONE_MIN_WIDTH, 180 },
            { ZONE_MAX_WIDTH, 1200 }
        );
    end

    -- push_theme applies the same configured window color / transparency
    -- used by the main BLUSpells window.
    push_theme();
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);

    local title = 'Azure Codex - Zone Info - ' .. tostring(zone_name) .. '###bluspells_zone_info';
    if imgui.Begin(title, state.zone_info_open, zone_flags) then
        local base_font_size = imgui.GetFontSize();
        local requested_size = base_font_size * state.font_scale[1];
        imgui.PushFont(nil, requested_size);
        if state.zone_reset_scroll and imgui.SetScrollY ~= nil then
            imgui.SetScrollY(0);
            state.zone_reset_scroll = false;
        end

        if not state.title_bar[1] then
            local window_w = select(1, imgui.GetWindowSize());
            window_w = tonumber(window_w) or state.zone_last_w;

            local saved_x, saved_y = imgui.GetCursorPos();
            imgui.SetCursorPos({ math.max(8, window_w - 48), 6 });

            if imgui.Button('X##bluspells_zone_info_close', { 22, 20 }) then
                state.zone_info_open[1] = false;
            end

            imgui.SetCursorPos({ saved_x, saved_y });
        end

        local header_avail_w = select(1, imgui.GetContentRegionAvail());
        header_avail_w = tonumber(header_avail_w) or state.zone_last_w;

        if imgui.BeginTable ~= nil and header_avail_w >= 560 then
            local header_flags = 0;
            if ImGuiTableFlags_SizingStretchProp ~= nil then
                header_flags = bit.bor(header_flags, ImGuiTableFlags_SizingStretchProp);
            end

            if imgui.BeginTable('##bluspells_zone_header', 4, header_flags) then
                imgui.TableSetupColumn('##zone_name', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);
                imgui.TableSetupColumn('##zone_id', ImGuiTableColumnFlags_WidthFixed or 0, 90);
                imgui.TableSetupColumn('##zone_progress', ImGuiTableColumnFlags_WidthFixed or 0, 130);
                imgui.TableSetupColumn('##zone_hide', ImGuiTableColumnFlags_WidthFixed or 0, 110);

                imgui.TableNextRow();
                imgui.TableNextColumn();
                imgui.TextColored(state.header_color, tostring(zone_name));

                imgui.TableNextColumn();
                if zone_id ~= nil then
                    imgui.TextColored(MUTED, ('Zone ID: %d'):fmt(zone_id));
                else
                    imgui.TextColored(MUTED, 'Zone ID: --');
                end

                imgui.TableNextColumn();
                imgui.Text(('%d of %d learned'):fmt(known_count, total_count));

                imgui.TableNextColumn();
                imgui.Checkbox('Hide Known', state.zone_hide_known);

                imgui.EndTable();
            end
        else
            -- Narrow layout: flow the header to two compact rows rather than
            -- clipping the progress / Hide Known controls off the right edge.
            imgui.TextColored(state.header_color, tostring(zone_name));
            imgui.SameLine();
            if zone_id ~= nil then
                imgui.TextColored(MUTED, ('Zone ID: %d'):fmt(zone_id));
            else
                imgui.TextColored(MUTED, 'Zone ID: --');
            end

            imgui.Text(('%d of %d learned'):fmt(known_count, total_count));
            imgui.SameLine();
            imgui.Checkbox('Hide Known', state.zone_hide_known);
        end

        imgui.Separator();

        if zone_id == nil then
            imgui.TextColored(MUTED, 'Current zone information is not available yet.');
        elseif total_count == 0 then
            imgui.TextColored(MUTED, 'No tracked Blue Magic spells are available from mobs in this zone.');
        else
            local avail_w = select(1, imgui.GetContentRegionAvail());
            avail_w = tonumber(avail_w) or 680;

            local visible_rows = {};

            for _, row in ipairs(rows) do
                if not (state.zone_hide_known[1] and row.known) then
                    visible_rows[#visible_rows + 1] = row;
                end
            end

            if #visible_rows == 0 then
                imgui.TextColored(MUTED, 'No missing Blue Magic spells are tracked in this zone.');
            else
                for row_index, row in ipairs(visible_rows) do
                    local display_state, spell_color = get_spell_display_state(row.spell);
                    local status_text = display_state == 'known' and 'Known'
                        or (display_state == 'learnable' and 'Learnable' or 'Unlearnable');
                    local learn_skill = blue_magic_learn_skill(row.spell);
                    local spell_label = ('%s (BLU:%d)'):fmt(
                        tostring(row.spell.name), learn_skill
                    );

                    -- Responsive Spell (BLU:#) | Lv | Status row.
                    -- The BLU learning threshold stays directly with the spell
                    -- name with exactly one separating space.
                    if imgui.BeginTable ~= nil then
                        local row_flags = 0;
                        if ImGuiTableFlags_SizingStretchProp ~= nil then
                            row_flags = bit.bor(row_flags, ImGuiTableFlags_SizingStretchProp);
                        end

                        if imgui.BeginTable('##zone_spell_row_' .. tostring(row_index), 3, row_flags) then
                            local level_w = avail_w < 620 and 52 or 62;
                            local status_w = avail_w < 620 and 92 or 112;

                            imgui.TableSetupColumn('##spell_name', ImGuiTableColumnFlags_WidthStretch or 0, 1.0);
                            imgui.TableSetupColumn('##spell_level', ImGuiTableColumnFlags_WidthFixed or 0, level_w);
                            imgui.TableSetupColumn('##spell_status', ImGuiTableColumnFlags_WidthFixed or 0, status_w);

                            imgui.TableNextRow();
                            imgui.TableNextColumn();
                            imgui.TextColored(spell_color, spell_label);

                            imgui.TableNextColumn();
                            imgui.TextColored(state.header_color, 'Lv');
                            imgui.SameLine();
                            imgui.Text(tostring(row.spell.level or '--'));

                            imgui.TableNextColumn();
                            imgui.TextColored(spell_color, status_text);

                            imgui.EndTable();
                        end
                    else
                        imgui.TextColored(spell_color, spell_label);
                        imgui.SameLine();
                        imgui.TextColored(state.header_color, ('Lv %s'):fmt(
                            tostring(row.spell.level or '--')
                        ));
                        imgui.SameLine();
                        imgui.TextColored(spell_color, status_text);
                    end

                    -- Mobs that teach this spell in the current zone.
                    for _, mob_name in ipairs(row.mobs) do
                        imgui.Text(('  - %s'):fmt(tostring(mob_name)));
                    end

                    if row_index < #visible_rows then
                        imgui.Separator();
                    end
                end
            end
        end

        if not state.zone_locked[1] then
            capture_zone_geometry();
        end

        imgui.PopFont();
    end

    imgui.End();
    imgui.PopStyleVar();
    pop_theme();
end

-- ----------------------------------------------------------------------------
-- Learning index (missing spells by zone / mob). Rebuilt when known spells or
-- Blue Magic skill change. Era zones only (locations.lua filters them).
-- ----------------------------------------------------------------------------
local learning_index = { key = nil, zones = {}, ranked = {}, by_mob = {} };

local function get_learning_index()
    refresh_known_cache(false);
    local skill = safe_blue_magic_skill();
    local cache_key = tostring(known_cache.version) .. '|' .. tostring(skill);
    if learning_index.key == cache_key then
        return learning_index;
    end

    local zones = {};
    local by_mob = {};

    for _, spell in ipairs(spells) do
        if not is_known(spell.name) then
            local display_state = get_spell_display_state(spell);
            local learnable = display_state == 'learnable';
            for _, entry in ipairs(locations.get(spell.name) or {}) do
                local zone_id = tonumber(entry.zone);
                if zone_id ~= nil then
                    local zone = zones[zone_id];
                    if zone == nil then
                        zone = { id = zone_id, rows = {}, missing = 0, learnable = 0 };
                        zones[zone_id] = zone;
                    end
                    zone.rows[#zone.rows + 1] = { spell = spell, mobs = entry.mobs or {}, learnable = learnable };
                    zone.missing = zone.missing + 1;
                    if learnable then zone.learnable = zone.learnable + 1; end

                    by_mob[zone_id] = by_mob[zone_id] or {};
                    for _, mob in ipairs(entry.mobs or {}) do
                        local mob_key = tostring(mob):lower();
                        by_mob[zone_id][mob_key] = by_mob[zone_id][mob_key] or {};
                        table.insert(by_mob[zone_id][mob_key], { spell = spell, learnable = learnable });
                    end
                end
            end
        end
    end

    local ranked = {};
    for _, zone in pairs(zones) do
        zone.name = locations.get_zone_name(zone.id);
        table.sort(zone.rows, function(a, b)
            if a.learnable ~= b.learnable then return a.learnable; end
            return tostring(a.spell.name):lower() < tostring(b.spell.name):lower();
        end);
        ranked[#ranked + 1] = zone;
    end
    table.sort(ranked, function(a, b)
        if a.learnable ~= b.learnable then return a.learnable > b.learnable; end
        if a.missing ~= b.missing then return a.missing > b.missing; end
        return tostring(a.name):lower() < tostring(b.name):lower();
    end);

    learning_index.key = cache_key;
    learning_index.zones = zones;
    learning_index.ranked = ranked;
    learning_index.by_mob = by_mob;
    return learning_index;
end

local function draw_close_button(id, open_ref)
    if state.title_bar[1] then return; end
    local window_w = tonumber((imgui.GetWindowSize())) or 400;
    local saved_x, saved_y = imgui.GetCursorPos();
    imgui.SetCursorPos({ math.max(8, window_w - 48), 6 });
    if imgui.Button('X##' .. id, { 22, 20 }) then
        open_ref[1] = false;
    end
    imgui.SetCursorPos({ saved_x, saved_y });
end

local function draw_farm_window()
    if not state.farm_open[1] then
        state.farm_apply_geometry = true;
        return;
    end

    if state.farm_apply_geometry then
        imgui.SetNextWindowPos({ tonumber(config.farm_window.x) or 1040, tonumber(config.farm_window.y) or 160 });
        imgui.SetNextWindowSize({ tonumber(config.farm_window.width) or 520, tonumber(config.farm_window.height) or 560 });
        state.farm_apply_geometry = false;
    end

    local flags = 0;
    if not state.title_bar[1] then flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar); end

    push_theme();
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);
    if imgui.Begin('Azure Codex - Farm Zones###azure_farm_zones', state.farm_open, flags) then
        imgui.PushFont(nil, imgui.GetFontSize() * state.font_scale[1]);
        draw_close_button('azure_farm_close', state.farm_open);

        local index = get_learning_index();
        local current_zone = safe_current_zone_id();

        imgui.TextColored(state.header_color, 'BEST ZONES TO FARM');
        imgui.SameLine();
        imgui.Checkbox('Learnable only##azure_farm_learnable', state.farm_learnable_only);
        imgui.TextColored(MUTED, 'Zones ranked by spells you are missing (learnable first). Click a zone to expand.');
        imgui.Separator();

        -- Only the list scrolls; the header (and the close button) stay put.
        imgui.BeginChild('##azure_farm_list', { 0, 0 });

        local shown = 0;
        for _, zone in ipairs(index.ranked) do
            if not state.farm_learnable_only[1] or zone.learnable > 0 then
                shown = shown + 1;
                local expanded = state.farm_expanded[zone.id] == true;
                local label = ('%s %s'):fmt(expanded and 'v' or '>', tostring(zone.name));
                if zone.id == current_zone then label = label .. '  (here)'; end
                imgui.PushStyleColor(ImGuiCol_Text, zone.learnable > 0 and state.learnable_color or TEXT);
                if imgui.Selectable(label .. '##azure_farm_zone_' .. tostring(zone.id), expanded) then
                    state.farm_expanded[zone.id] = not expanded;
                end
                imgui.PopStyleColor(1);
                imgui.SameLine();
                imgui.TextColored(MUTED, ('%d missing, %d learnable'):fmt(zone.missing, zone.learnable));

                if expanded then
                    for _, row in ipairs(zone.rows) do
                        if not state.farm_learnable_only[1] or row.learnable then
                            local _, color = get_spell_display_state(row.spell);
                            imgui.TextColored(color, ('    %s'):fmt(tostring(row.spell.name)));
                            imgui.SameLine();
                            imgui.TextColored(MUTED, ('Lv %s  -  %s'):fmt(tostring(row.spell.level or '--'),
                                table.concat(row.mobs, ', ')));
                        end
                    end
                end
            end
        end
        if shown == 0 then
            imgui.TextColored(MUTED, 'Nothing left to learn from mobs in era zones.');
        end

        imgui.EndChild();

        local x, y = imgui.GetWindowPos();
        local w, h = imgui.GetWindowSize();
        x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h);
        if x and y and w and h then
            local fw = config.farm_window;
            if math.abs(x - (tonumber(fw.x) or 0)) >= 1 or math.abs(y - (tonumber(fw.y) or 0)) >= 1
                or math.abs(w - (tonumber(fw.width) or 0)) >= 1 or math.abs(h - (tonumber(fw.height) or 0)) >= 1 then
                fw.x, fw.y, fw.width, fw.height = x, y, w, h;
                state.settings_dirty = true;
            end
        end

        imgui.PopFont();
    end
    imgui.End();
    imgui.PopStyleVar(1);
    pop_theme();
end

-- Formatted log lines, built once per entry (not saved to settings).
local log_line_cache = setmetatable({}, { __mode = 'k' });

local function log_line(entry)
    local line = log_line_cache[entry];
    if line == nil then
        local where = (tonumber(entry.zone) or 0) > 0 and locations.get_zone_name(entry.zone) or '';
        local mob = tostring(entry.mob or '');
        line = {
            date = os.date('%Y-%m-%d %H:%M', tonumber(entry.time) or 0),
            spell = tostring(entry.spell or '?'),
            detail = ('%s%s%s'):fmt(where, (where ~= '' and mob ~= '') and '  -  ' or '', mob),
        };
        log_line_cache[entry] = line;
    end
    return line;
end

local function draw_log_window()
    if not state.log_open[1] then
        state.log_apply_geometry = true;
        return;
    end

    if state.log_apply_geometry then
        imgui.SetNextWindowPos({ tonumber(config.log_window.x) or 1060, tonumber(config.log_window.y) or 180 });
        imgui.SetNextWindowSize({ tonumber(config.log_window.width) or 560, tonumber(config.log_window.height) or 460 });
        state.log_apply_geometry = false;
    end

    local flags = 0;
    if not state.title_bar[1] then flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar); end

    push_theme();
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);
    if imgui.Begin('Azure Codex - Learned Log###azure_learned_log', state.log_open, flags) then
        imgui.PushFont(nil, imgui.GetFontSize() * state.font_scale[1]);
        draw_close_button('azure_log_close', state.log_open);

        local log = config.learned_log or {};
        imgui.TextColored(state.header_color, 'LEARNED LOG');
        imgui.SameLine();
        imgui.TextColored(MUTED, ('%d entries (this character)'):fmt(#log));

        if #log > 0 then
            imgui.SameLine();
            if not state.log_clear_confirm then
                if imgui.SmallButton('Clear##azure_log_clear') then state.log_clear_confirm = true; end
            else
                imgui.TextColored(state.unknown_color, 'Clear the whole log?');
                imgui.SameLine();
                if imgui.SmallButton('Yes##azure_log_clear_yes') then
                    config.learned_log = T{};
                    state.log_clear_confirm = false;
                    state.settings_dirty = true;
                end
                imgui.SameLine();
                if imgui.SmallButton('No##azure_log_clear_no') then state.log_clear_confirm = false; end
            end
        end
        imgui.Separator();

        imgui.BeginChild('##azure_log_list', { 0, 0 });
        if #log == 0 then
            imgui.TextColored(MUTED, 'Spells you learn from now on are listed here with the time, zone and mob.');
        else
            for i = #log, 1, -1 do
                local line = log_line(log[i]);
                imgui.TextColored(MUTED, line.date);
                imgui.SameLine();
                imgui.TextColored(state.known_color, line.spell);
                if line.detail ~= '' then
                    imgui.SameLine();
                    imgui.TextColored(MUTED, line.detail);
                end
            end
        end
        imgui.EndChild();

        local x, y = imgui.GetWindowPos();
        local w, h = imgui.GetWindowSize();
        x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h);
        if x and y and w and h then
            local lw = config.log_window;
            if math.abs(x - (tonumber(lw.x) or 0)) >= 1 or math.abs(y - (tonumber(lw.y) or 0)) >= 1
                or math.abs(w - (tonumber(lw.width) or 0)) >= 1 or math.abs(h - (tonumber(lw.height) or 0)) >= 1 then
                lw.x, lw.y, lw.width, lw.height = x, y, w, h;
                state.settings_dirty = true;
            end
        end

        imgui.PopFont();
    end
    imgui.End();
    imgui.PopStyleVar(1);
    pop_theme();
end

-- Small tag for the current target: "Teaches: <missing spell>". Reads only
-- your target and the static location data; BLU main only.
local function get_target_mob_name()
    local ok, name = pcall(function()
        local mm = AshitaCore:GetMemoryManager();
        local target = mm:GetTarget();
        local index = 0;
        if target:GetIsSubTargetActive() ~= 0 then
            index = target:GetTargetIndex(1);
        else
            index = target:GetTargetIndex(0);
        end
        index = tonumber(index) or 0;
        if index <= 0 then return nil; end
        local entity = mm:GetEntity();
        local flags = tonumber(entity:GetSpawnFlags(index)) or 0;
        if bit.band(flags, 0x10) == 0 then return nil; end
        return entity:GetName(index);
    end);
    if not ok or name == nil or tostring(name) == '' then return nil; end
    return tostring(name);
end

local function draw_target_tag()
    if not state.target_tag[1] then return; end
    if safe_blu_level() == nil then return; end

    local zone_id = safe_current_zone_id();
    if zone_id == nil then return; end
    local name = get_target_mob_name();
    if name == nil then return; end

    local index = get_learning_index();
    local zone_mobs = index.by_mob[zone_id];
    local list = zone_mobs and zone_mobs[name:lower()] or nil;
    if list == nil or #list == 0 then return; end

    if state.target_tag_apply_pos then
        imgui.SetNextWindowPos({ state.target_tag_x, state.target_tag_y });
        state.target_tag_apply_pos = false;
    end

    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoFocusOnAppearing or 0, ImGuiWindowFlags_NoSavedSettings or 0);
    if state.target_tag_locked[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoInputs or 0);
    end

    push_theme();
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);
    if imgui.Begin('Azure Codex - Target Tag###azure_target_tag', nil, flags) then
        imgui.PushFont(nil, imgui.GetFontSize() * state.font_scale[1]);
        imgui.TextColored(state.header_color, 'Teaches:');
        for _, item in ipairs(list) do
            imgui.SameLine();
            local color = item.learnable and state.learnable_color or state.unknown_color;
            imgui.TextColored(color, tostring(item.spell.name));
        end
        imgui.PopFont();

        local x, y = imgui.GetWindowPos();
        x, y = tonumber(x), tonumber(y);
        if x and y and (math.abs(x - state.target_tag_x) >= 1 or math.abs(y - state.target_tag_y) >= 1) then
            state.target_tag_x, state.target_tag_y = x, y;
            state.settings_dirty = true;
        end
    end
    imgui.End();
    imgui.PopStyleVar(1);
    pop_theme();
end

local function draw_about_tab()
    section_title('ABOUT AZURE CODEX');

    imgui.TextWrapped(
        'Azure Codex (orig BLUSpells) is a HorizonXI-focused Blue Mage companion for learning, tracking, '
        .. 'planning, and managing Blue Magic. It tracks learned, learnable, and currently unlearnable '
        .. 'spells using your live Blue Magic skill, provides HorizonXI-specific monster and zone data '
        .. 'for locating spells, and includes BLUPrints for designing builds with BLU point and trait '
        .. 'calculations plus Azure Loadout for saving, loading, and equipping spell sets. Its spell, '
        .. 'trait, mob, and location data is intentionally tailored to HorizonXI and its current era/content '
        .. 'progression rather than modern retail FFXI.'
    );

    imgui.Spacing();
    imgui.Separator();
    imgui.Spacing();

    imgui.TextColored(state.header_color, 'Version:');
    imgui.SameLine();
    imgui.Text(addon.version);

    imgui.TextColored(state.header_color, 'Author:');
    imgui.SameLine();
    imgui.Text(addon.author);

    imgui.TextColored(state.header_color, 'Collaborator:');
    imgui.SameLine();
    imgui.Text('Kyrias');

    imgui.Spacing();
    imgui.TextColored(state.known_color, 'Special thanks to Demiora for all the testing.');
end

local function get_saved_build_spells_for_view(filename)
    local folder = ensure_build_folder();
    local path = folder .. '\\' .. tostring(filename or '');
    local file = io.open(path, 'r');
    if file == nil then
        return {}, 0, 0;
    end

    local loaded = {};
    for line in file:lines() do
        local name = line:match('^%s*%d+%.%s*(.-)%s+%- %s*Lv%s+%d+%s+%-%s+%d+%s+pt%s*$');
        if name ~= nil then
            loaded[normalize_name(name)] = true;
        end
    end
    file:close();

    local selected = {};
    local used = 0;
    local count = 0;
    for _, spell in ipairs(spells) do
        if loaded[normalize_name(spell.name)] then
            selected[#selected + 1] = spell;
            used = used + (tonumber(spell.points) or 0);
            count = count + 1;
        end
    end

    return selected, used, count;
end

local function draw_bluprint_view_page()
    section_title('BLUPRINT-VIEW');
    imgui.TextColored(MUTED, 'Select a saved BLUPrint to view its spell loadout.');
    imgui.Spacing();

    state.bluprint_view_files = get_saved_build_files();
    if #state.bluprint_view_files == 0 then
        imgui.TextColored(MUTED, 'No saved BLUPrints found.');
        return;
    end

    local selected_name = tostring(state.bluprint_view_selected[1] or '');
    local current_index = 0;
    local combo_items = { 'Select a BLUPrint...' };
    for index, filename in ipairs(state.bluprint_view_files) do
        combo_items[#combo_items + 1] = filename;
        if filename == selected_name then
            current_index = index;
        end
    end

    local item_string = table.concat(combo_items, '\0') .. '\0\0';
    local combo_value = { current_index };
    imgui.PushItemWidth(420);
    if imgui.Combo('##azure_bluprint_view_combo', combo_value, item_string, math.min(12, #combo_items)) then
        local chosen_index = tonumber(combo_value[1]) or 0;
        local filename = chosen_index > 0 and state.bluprint_view_files[chosen_index] or nil;
        if filename ~= nil then
            state.bluprint_view_selected[1] = filename;
        else
            state.bluprint_view_selected[1] = '';
        end
    end
    imgui.PopItemWidth();

    selected_name = tostring(state.bluprint_view_selected[1] or '');
    if selected_name == '' then
        imgui.Spacing();
        imgui.TextColored(MUTED, 'Choose a BLUPrint from the dropdown to view it.');
        return;
    end

    -- Parse the selected file once (it was re-read every frame).
    if state.view_cache == nil or state.view_cache.name ~= selected_name then
        local list, pts, n = get_saved_build_spells_for_view(selected_name);
        state.view_cache = { name = selected_name, spells = list, used = pts, count = n };
    end
    local selected_spells = state.view_cache.spells;
    local used = state.view_cache.used;
    local count = state.view_cache.count;
    state.bluprint_view_spells = selected_spells;
    local view_point_cap, view_slot_cap = get_build_caps();

    imgui.Spacing();
    imgui.TextColored(state.header_color, selected_name);
    imgui.SameLine();
    local over = count > view_slot_cap or used > view_point_cap;
    imgui.TextColored(over and state.unknown_color or MUTED,
        ('%d / %d spells   %d / %d points'):fmt(count, view_slot_cap, used, view_point_cap));
    if over then
        imgui.TextColored(state.unknown_color, 'Over your current limits - equipping would be refused.');
    end

    if count > 0 then
        if imgui.Button('Equip##azure_bluprint_view_equip') then
            equip_spell_list(selected_spells, used, count, selected_name);
        end
        imgui.SameLine();
        if imgui.Button('Import to BLUPrints##azure_bluprint_view_import') then
            state.build_selected = {};
            for _, spell in ipairs(selected_spells) do
                state.build_selected[normalize_name(spell.name)] = true;
            end
            state.build_page[1] = true;
            state.bluprint_view_page[1] = false;
            state.spellsets_page[1] = false;
            log_message(('Imported BLUPrint into BLUPrints: %s (%d spells, %d points).'):fmt(
                tostring(selected_name), count, used));
        end

        imgui.SameLine();
        if imgui.Button('Delete##azure_bluprint_view_delete') then
            state.bluprint_view_delete_confirm[1] = true;
        end
    end

    if state.bluprint_view_delete_confirm[1] and selected_name ~= '' then
        imgui.Spacing();
        imgui.TextColored(state.unknown_color, ('Delete %s?'):fmt(tostring(selected_name)));
        imgui.SameLine();
        if imgui.Button('Confirm##azure_bluprint_view_delete_confirm') then
            local folder = ensure_build_folder();
            local path = folder .. '\\' .. tostring(selected_name);
            local ok, err = os.remove(path);
            if ok then
                log_message('Deleted BLUPrint: ' .. tostring(selected_name));
                state.bluprint_view_selected[1] = '';
                state.bluprint_view_spells = {};
                state.view_cache = nil;
                state.build_files_at = -1;
            else
                log_message('Unable to delete BLUPrint: ' .. tostring(err or path));
            end
            state.bluprint_view_delete_confirm[1] = false;
        end
        imgui.SameLine();
        if imgui.Button('Cancel##azure_bluprint_view_delete_cancel') then
            state.bluprint_view_delete_confirm[1] = false;
        end
    end

    if count > 0 then
        imgui.Spacing();
        draw_equipped_diff(selected_spells);
    end

    imgui.Separator();

    local trait_totals = compute_traits(selected_spells);

    imgui.TextColored(state.header_color, 'SPELLS');
    imgui.Spacing();
    if #selected_spells == 0 then
        imgui.TextColored(MUTED, 'No valid spells found in this BLUPrint.');
    else
        for index, spell in ipairs(selected_spells) do
            local trait_text = get_spell_trait_badge(spell);
            imgui.TextColored(state.header_color, ('%02d'):fmt(index));
            imgui.SameLine();
            imgui.Text(tostring(spell.name));
            imgui.SameLine();
            imgui.TextColored(MUTED, ('Lv %s   %d pt'):fmt(tostring(spell.level or '--'), tonumber(spell.points) or 0));
            if trait_text ~= nil and tostring(trait_text):lower() ~= 'none' then
                imgui.SameLine();
                imgui.TextColored(state.header_color, tostring(trait_text));
            end
        end
    end

    imgui.Spacing();
    imgui.Separator();
    imgui.TextColored(state.header_color, 'TRAITS');
    imgui.Spacing();

    if #trait_totals == 0 then
        imgui.TextColored(MUTED, 'No trait contributions in this BLUPrint.');
    else
        draw_trait_list(trait_totals, 'view');
    end
end

local function draw_spellsets_page()
    section_title('AZURE LOADOUT');

    imgui.TextColored(MUTED, 'Saved BLU sets from the BLUPrints folder.');
    imgui.TextColored(MUTED, 'Select a set below to equip it in game.');
    imgui.Spacing();

    state.spellsets_files = get_saved_build_files();
    if #state.spellsets_files == 0 then
        imgui.TextColored(MUTED, 'No saved sets found in BLUPrints.');
    else
        for _, filename in ipairs(state.spellsets_files) do
            if imgui.Button('Equip ' .. filename .. '##main_spellset_' .. normalize_name(filename)) then
                load_saved_build_file(filename, true);
            end
        end
    end
end

local function draw_config_window()
    if not state.config_open[1] then
        state.apply_saved_config_geometry = true;
        return;
    end

    if state.apply_saved_config_geometry then
        imgui.SetNextWindowPos({ state.config_last_x, state.config_last_y }, { 0, 0 });
        imgui.SetNextWindowSize({ state.config_last_w, state.config_last_h });
        state.apply_saved_config_geometry = false;
    end

    push_theme();

    if imgui.Begin('Azure Codex - Config##bluspells_config', state.config_open, 0) then
        local config_tabs = {
            { label = 'Window', id = 'cfg_tab_window', draw = draw_window_tab },
            { label = 'Font & Colors', id = 'cfg_tab_font_colors', draw = draw_font_colors_tab },
            { label = 'Display', id = 'cfg_tab_display', draw = draw_display_tab },
            { label = 'Behavior', id = 'cfg_tab_behavior', draw = draw_behavior_tab },
            { label = 'About', id = 'cfg_tab_about', draw = draw_about_tab },
        };

        local selected_tab = tonumber(state.config_tab) or 1;
        if selected_tab < 1 or selected_tab > #config_tabs then
            selected_tab = 1;
        end

        -- Flat styled tab row with an accent underline on the active tab.
        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 12, 6 });
        for index, tab in ipairs(config_tabs) do
            if index > 1 then
                imgui.SameLine(0, 4);
            end
            if draw_styled_tab(tab.label, tab.id, index == selected_tab) then
                selected_tab = index;
            end
        end
        imgui.PopStyleVar(1);
        state.config_tab = selected_tab;

        imgui.Spacing();
        imgui.Separator();
        imgui.Spacing();

        -- Only the tab content scrolls; the tab row stays in place.
        imgui.BeginChild('##bluspells_config_content', { 0, 0 });
        config_tabs[selected_tab].draw();
        imgui.EndChild();

        capture_config_geometry();
    end

    imgui.End();
    pop_theme();
end

local function draw_filter_button(label, mode, enabled)
    if enabled == false then
        draw_toggle_button(label, 'filter_' .. mode, false, true);
        return;
    end

    local selected = state.filter_mode == mode and not state.build_page[1]
        and not state.spellsets_page[1] and not state.bluprint_view_page[1];
    if draw_toggle_button(label, 'filter_' .. mode, selected) then
        set_filter(mode);
    end
end

local function calculate_per_page()
    if state.rows_mode == 'fixed' then
        state.per_page = math.floor(clamp(state.rows_per_page[1], 8, 60));
        return;
    end

    local _, avail_h = imgui.GetContentRegionAvail();
    avail_h = tonumber(avail_h) or 650;

    local row_h = imgui.GetTextLineHeightWithSpacing();
    if state.row_spacing == 'normal' then row_h = row_h + 5; else row_h = row_h + 1; end

    -- Reserve space for header and bottom pager/status line.
    local rows = math.floor((avail_h - (row_h * 2.4)) / math.max(1, row_h));
    state.per_page = math.floor(clamp(rows, 8, 60));
end

local function draw_main_table(filtered, first, last)
    if imgui.BeginTable ~= nil and imgui.TableSetupColumn ~= nil then
        local flags = 0;
        if ImGuiTableFlags_Resizable ~= nil then flags = bit.bor(flags, ImGuiTableFlags_Resizable); end
        if ImGuiTableFlags_RowBg ~= nil then flags = bit.bor(flags, ImGuiTableFlags_RowBg); end
        if ImGuiTableFlags_BordersInnerH ~= nil then flags = bit.bor(flags, ImGuiTableFlags_BordersInnerH); end

        if imgui.BeginTable('##bluspells_spell_table', active_column_count(), flags) then
            setup_table_columns();
            draw_table_headers();

            for i = first, last do
                draw_spell_table_row(filtered[i]);
            end

            imgui.EndTable();
        end
    else
        draw_fallback_rows(filtered, first, last);
    end
end

local function draw_window()
    if not state.open[1] then
        state.apply_saved_geometry = true;

        -- Secondary windows must still render independently of the main window.
        -- This is what allows /bsz and /bluspellszone to open Zone Info by itself.
        draw_config_window();
        draw_saved_build_loader();
        draw_location_window();
        draw_zone_info_window();

        if (state.config_geometry_dirty or state.zone_geometry_dirty or state.settings_dirty)
            and (os.clock() - state.last_save) >= 0.50 then
            save_config();
            state.config_geometry_dirty = false;
            state.zone_geometry_dirty = false;
            state.settings_dirty = false;
            state.last_save = os.clock();
        end

        return;
    end

    if state.apply_saved_geometry then
        imgui.SetNextWindowPos({ state.last_x, state.last_y }, { 0, 0 });
        imgui.SetNextWindowSize({ state.last_w, state.last_h });
        state.apply_saved_geometry = false;
    end

    local flags = 0;

    if state.locked[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoResize);
    end
    if not state.title_bar[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar);
    end

    push_theme();

    -- Border visibility is independent from the window background.
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);

    if imgui.Begin('Azure Codex##bluspells', state.open, flags) then
        build_resource_cache();
        update_known_snapshot();

        if not state.title_bar[1] then
            local window_w = select(1, imgui.GetWindowSize());
            window_w = tonumber(window_w) or state.last_w;

            local saved_x, saved_y = imgui.GetCursorPos();
            imgui.SetCursorPos({ math.max(8, window_w - 48), 6 });

            if imgui.Button('X##bluspells_custom_close', { 22, 20 }) then
                state.open[1] = false;
                state.config_open[1] = false;
            end

            imgui.SetCursorPos({ saved_x, saved_y });
        end

        -- Search + config toolbar.
        align_label();
        imgui.Text('Search:');
        imgui.SameLine();

        imgui.PushItemWidth(300);
        imgui.InputText('##bluspells_search', state.search, 128);
        imgui.PopItemWidth();

        local current_search = tostring(state.search[1] or '');
        if current_search ~= state.last_search then
            state.last_search = current_search;
            mark_ui_state_changed(true);
        end

        imgui.SameLine();
        if imgui.Button('Clear') then
            state.search[1] = '';
            state.last_search = '';
            mark_ui_state_changed(true);
        end

        imgui.SameLine();
        if imgui.Button('Config') then
            state.config_open[1] = not state.config_open[1];
        end

        -- Filter toolbar.
        local blu_level = safe_blu_level();

        draw_filter_button('All', 'all', true);
        imgui.SameLine();
        draw_filter_button('Known', 'known', true);
        imgui.SameLine();
        draw_filter_button('Missing', 'missing', true);
        imgui.SameLine();
        draw_filter_button(
            blu_level and ('Up to Lv ' .. tostring(blu_level)) or 'Up to My Level',
            'ready',
            blu_level ~= nil
        );

        imgui.SameLine();
        if draw_toggle_button('BLUPrints', 'blu_main_spell_build', state.build_page[1]) then
            state.build_page[1] = true;
            state.spellsets_page[1] = false;
            state.bluprint_view_page[1] = false;
        end

        imgui.SameLine();
        if draw_toggle_button('BLUPrint-View', 'blu_main_spell_build_view', state.bluprint_view_page[1]) then
            state.bluprint_view_page[1] = true;
            state.build_page[1] = false;
            state.spellsets_page[1] = false;
        end

        imgui.SameLine();
        align_label();
        imgui.TextColored(MUTED, 'Search all columns | OR with "|"');

        local blu_skill = safe_blue_magic_skill();
        local blu_skill_level = safe_blu_level();
        local blu_skill_cap = nil;
        local blu_spent, blu_max = get_blu_points();

        if blu_skill_level ~= nil then
            blu_skill_cap = blue_magic_cap_for_level(blu_skill_level);
        end
        imgui.TextColored(state.header_color, 'BLU Skill:');
        imgui.SameLine();

        if blu_skill ~= nil and blu_skill_cap ~= nil then
            imgui.Text(('%d/%d'):fmt(
                math.floor(blu_skill),
                math.floor(blu_skill_cap)
            ));
        elseif blu_skill ~= nil then
            imgui.Text(('%d/--'):fmt(math.floor(blu_skill)));
        else
            imgui.TextColored(MUTED, '--/--');
        end
        imgui.SameLine();
        imgui.TextColored(state.header_color, 'BLU Points:');
        imgui.SameLine();
        if blu_spent ~= nil and blu_max ~= nil then
            imgui.Text(('%d/%d'):fmt(blu_spent, blu_max));
        elseif blu_skill_level ~= nil then
            -- Client does not expose live points: equipped total vs the
            -- HorizonXI level limit.
            local cap_points, cap_slots = horizon_blu_caps(blu_skill_level);
            local equipped_list, equipped_points = get_equipped_spells();
            imgui.Text(('%d/%d'):fmt(equipped_points, cap_points));
            imgui.SameLine();
            imgui.TextColored(MUTED, ('Spells: %d/%d'):fmt(#equipped_list, cap_slots));
        else
            imgui.TextColored(MUTED, '--/--');
        end

        -- Completion status.
        local learned_count = get_learned_count();
        local missing_count = math.max(0, #spells - learned_count);
        local pct = (#spells > 0) and ((learned_count / #spells) * 100.0) or 0.0;

        local current_zone_id = safe_current_zone_id();
        local zone_known_count, zone_total_count = get_zone_progress(current_zone_id);

        -- Align both text segments to the button's frame baseline.
        -- This is more reliable than manually adjusting cursor Y positions.
        if imgui.AlignTextToFramePadding ~= nil then
            imgui.AlignTextToFramePadding();
        end

        imgui.Text(('Learned %d / %d (%.1f%%)   Missing %d'):fmt(
            learned_count, #spells, pct, missing_count
        ));

        imgui.SameLine();

        if imgui.Button('Zone Info') then
            state.zone_info_open[1] = not state.zone_info_open[1];
            state.zone_apply_saved_geometry = true;
            if state.zone_info_open[1] then
                state.zone_reset_scroll = true;
            end
        end

        imgui.SameLine();

        if imgui.AlignTextToFramePadding ~= nil then
            imgui.AlignTextToFramePadding();
        end

        imgui.Text(('%d of %d learned from this Zone'):fmt(zone_known_count, zone_total_count));

        imgui.SameLine();
        if draw_toggle_button('Farm Zones', 'azure_farm_btn', state.farm_open[1] == true) then
            state.farm_open[1] = not state.farm_open[1];
            state.farm_apply_geometry = true;
        end
        imgui.SameLine();
        if draw_toggle_button('Learned Log', 'azure_log_btn', state.log_open[1] == true) then
            state.log_open[1] = not state.log_open[1];
            state.log_apply_geometry = true;
        end

        if imgui.ProgressBar ~= nil then
            local avail_w = select(1, imgui.GetContentRegionAvail());
            avail_w = tonumber(avail_w) or 500;

            imgui.ProgressBar(
                #spells > 0 and (learned_count / #spells) or 0,
                { math.min(avail_w, 520), 8 },
                ''
            );
        end

        imgui.Separator();

        local base_font_size = imgui.GetFontSize();
        local requested_size = base_font_size * state.font_scale[1];
        imgui.PushFont(nil, requested_size);

        if state.build_page[1] then
            draw_spell_build_tab();
        elseif state.bluprint_view_page[1] then
            draw_bluprint_view_page();
        else
            calculate_per_page();

            local filtered = get_filtered_spells();
            maybe_jump_to_selected(filtered);

            local pages = clamp_page(#filtered);
            local first = ((state.page - 1) * state.per_page) + 1;
            local last = math.min(first + state.per_page - 1, #filtered);

            if #filtered == 0 then
                imgui.TextColored(MUTED, 'No spells match the current search/filter.');
            else
                draw_main_table(filtered, first, last);
            end

            imgui.Separator();

            local page_color = state.paging_color;
        local hover = {
            clamp(page_color[1] + 0.14, 0, 1),
            clamp(page_color[2] + 0.08, 0, 1),
            clamp(page_color[3] + 0.08, 0, 1),
            page_color[4],
        };
        local active = {
            clamp(page_color[1] + 0.22, 0, 1),
            clamp(page_color[2] + 0.12, 0, 1),
            clamp(page_color[3] + 0.12, 0, 1),
            page_color[4],
        };

        imgui.PushStyleColor(ImGuiCol_Button, page_color);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, hover);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, active);

        if state.page > 1 then
            if imgui.Button('< Previous') then state.page = state.page - 1; end
        else
            imgui.BeginDisabled();
            imgui.Button('< Previous');
            imgui.EndDisabled();
        end

        imgui.SameLine();
        imgui.Text(('Page %d / %d   Showing %d of %d'):fmt(
            state.page, pages, #filtered, #spells
        ));
        imgui.SameLine();

        if state.page < pages then
            if imgui.Button('Next >') then state.page = state.page + 1; end
        else
            imgui.BeginDisabled();
            imgui.Button('Next >');
            imgui.EndDisabled();
        end

            imgui.PopStyleColor(3);

            imgui.SameLine();
            imgui.TextColored(state.known_color, 'Known');
            imgui.SameLine();
            imgui.TextColored(state.learnable_color, 'Learnable');
            imgui.SameLine();
            imgui.TextColored(state.unknown_color, 'Unlearnable');
        end

        imgui.PopFont();

        -- Capture live geometry every frame so the BLUPrint details window
        -- stays directly beside Azure Codex even while the main window moves.
        local frame_x, frame_y = imgui.GetWindowPos();
        local frame_w, frame_h = imgui.GetWindowSize();
        state.main_frame_x = tonumber(frame_x);
        state.main_frame_y = tonumber(frame_y);
        state.main_frame_w = tonumber(frame_w);
        state.main_frame_h = tonumber(frame_h);

        if not state.locked[1] then
            capture_main_geometry();
        end
    end

    imgui.End();
    imgui.PopStyleVar(1);
    pop_theme();

    draw_config_window();
    draw_saved_build_loader();
    draw_bluprints_companion_window();
    draw_location_window();
    draw_zone_info_window();

    if (state.geometry_dirty or state.config_geometry_dirty or state.zone_geometry_dirty or state.settings_dirty)
        and (os.clock() - state.last_save) >= 0.50 then
        save_config();
        state.geometry_dirty = false;
        state.config_geometry_dirty = false;
        state.zone_geometry_dirty = false;
        state.settings_dirty = false;
        state.last_save = os.clock();
    end
end

ashita.events.register('command', 'bluspells_command_cb', function(e)
    if e == nil or e.command == nil then return; end

    local args = e.command:args();
    if #args == 0 then return; end

    local command = tostring(args[1] or ''):lower();

    -- Direct Zone Info aliases. These do not toggle the main BLUSpells window.
    if command == '/acz' or command == '/azurecodexzone' or command == '/bsz' or command == '/bluspellszone' then
        e.blocked = true;

        state.zone_info_open[1] = not state.zone_info_open[1];
        state.zone_apply_saved_geometry = true;

        if state.zone_info_open[1] then
            state.zone_reset_scroll = true;
        end

        return;
    end

    if command ~= '/azurecodex' and command ~= '/ac'
        and command ~= '/bluspells' and command ~= '/bsp' and command ~= '/bsl' then return; end

    e.blocked = true;

    if #args >= 2 and tostring(args[2]):lower() == 'config' then
        state.config_open[1] = not state.config_open[1];
        return;
    end
    if #args >= 2 and tostring(args[2]):lower() == 'farm' then
        state.farm_open[1] = not state.farm_open[1];
        state.farm_apply_geometry = true;
        return;
    end
    if #args >= 2 and tostring(args[2]):lower() == 'log' then
        state.log_open[1] = not state.log_open[1];
        state.log_apply_geometry = true;
        return;
    end

    state.open[1] = not state.open[1];

    if not state.open[1] then
        state.config_open[1] = false;
        state.location_open[1] = false;
        state.location_spell = nil;
        state.zone_info_open[1] = false;
        state.build_page[1] = false;
        state.spellsets_page[1] = false;
        state.bluprint_view_page[1] = false;
    end
end);

ashita.events.register('unload', 'bluspells_unload_cb', function()
    save_config();
end);

ashita.events.register('d3d_present', 'bluspells_present_cb', function()
    -- Runs every frame (cheap unless a spell was just learned) so the
    -- Learned Log records the right time / zone / mob even with the main
    -- window closed.
    update_known_snapshot();
    draw_window();
    draw_farm_window();
    draw_log_window();
    draw_target_tag();
end);

-- Remember the last mob you (or your party) defeated, so the Learned Log
-- can say which mob taught a spell. 0x029 messages 6 / 20 = defeated.
ashita.events.register('packet_in', 'azurecodex_packet_in_cb', function(e)
    if e == nil or e.id ~= 0x029 or e.data_modified == nil then return; end
    local ok, target_index, message = pcall(function()
        return struct.unpack('H', e.data_modified, 0x16 + 1), struct.unpack('H', e.data_modified, 0x18 + 1);
    end);
    if not ok then return; end
    message = bit.band(tonumber(message) or 0, 0x7FFF);
    if message ~= 6 and message ~= 20 then return; end

    local ok_name, name = pcall(function()
        local entity = AshitaCore:GetMemoryManager():GetEntity();
        local flags = tonumber(entity:GetSpawnFlags(target_index)) or 0;
        if bit.band(flags, 0x10) == 0 then return nil; end
        return entity:GetName(target_index);
    end);
    if ok_name and name ~= nil and tostring(name) ~= '' then
        state.last_defeat = { name = tostring(name), time = os.time(), zone = safe_current_zone_id() };
    end
end);
