--[[
    Azure Codex - ac/core.lua

    Settings: optional helpers (blu, chat), defaults, loading / repairing the saved
    settings, the shared runtime state, and the settings-update callback.
]]

ffi = require 'ffi';
ok_blu, blu = pcall(require, 'blu');
if not ok_blu then blu = nil; end
ok_chat, chat = pcall(require, 'chat');
if not ok_chat then chat = nil; end

imgui = require 'imgui';
settings = require 'settings';

spells = require 'spells';
locations = require 'locations';

function log_message(text)
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

defaults = T{
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
        visible_tabs = T{ all = true, known = true, missing = true, ready = true, bluprints = true, view = true },
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
        -- "Teaches:" / "Already Know:" tag for a targeted mob that teaches a
        -- blue spell (current zone, BLU main only).
        target_tag = true,
        target_tag_locked = false,
        assimilation = 0,
    },

    target_tag_window = T{ x = 900, y = 260 },

    -- Visible mouse pointer over Azure Codex windows. Default: fuchsia, 1.4x.
    cursor = T{
        enabled = true,
        size = 1.4,
        color = T{ 1.00, 0.10, 0.75, 1.00 },
        outline = T{ 0.05, 0.00, 0.05, 1.00 },
        shadow = true,
    },
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

config = settings.load(defaults);

-- Previous default window colors. Saved settings that still use one exactly
-- are moved to the current midnight blue default; custom colors are left untouched.
LEGACY_BACKGROUNDS = {
    { 0.018, 0.024, 0.032 },
    { 0.008, 0.000, 0.208 },
};

function ensure_tables()
    if config.appearance == nil then config.appearance = T{}; end
    if config.appearance.background == nil then config.appearance.background = T{}; end
    if config.appearance.known_color == nil then config.appearance.known_color = T{}; end
    if config.appearance.learnable_color == nil then config.appearance.learnable_color = T{}; end
    if config.appearance.unknown_color == nil then config.appearance.unknown_color = T{}; end
    if config.appearance.header_color == nil then config.appearance.header_color = T{}; end
    if config.appearance.paging_color == nil then config.appearance.paging_color = T{}; end

    if config.display == nil then config.display = T{}; end
    if config.display.columns == nil then config.display.columns = T{}; end
    if config.display.visible_tabs == nil then config.display.visible_tabs = T{}; end
    for _, key in ipairs({ 'all', 'known', 'missing', 'ready', 'bluprints', 'view' }) do
        if config.display.visible_tabs[key] == nil then config.display.visible_tabs[key] = true; end
    end

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

    if config.cursor == nil then config.cursor = T{}; end
    if config.cursor.enabled == nil then config.cursor.enabled = true; end
    if config.cursor.size == nil then config.cursor.size = defaults.cursor.size; end
    if config.cursor.shadow == nil then config.cursor.shadow = true; end
    if config.cursor.color == nil then config.cursor.color = T{}; end
    if config.cursor.outline == nil then config.cursor.outline = T{}; end
    fill_color(config.cursor.color, defaults.cursor.color);
    fill_color(config.cursor.outline, defaults.cursor.outline);

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

remember = config.behavior.remember_filters == true;

state = T{
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

    visible_tabs = {
        all = { config.display.visible_tabs.all ~= false },
        known = { config.display.visible_tabs.known ~= false },
        missing = { config.display.visible_tabs.missing ~= false },
        ready = { config.display.visible_tabs.ready ~= false },
        bluprints = { config.display.visible_tabs.bluprints ~= false },
        view = { config.display.visible_tabs.view ~= false },
    },
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
ZONE_MIN_WIDTH = 430;
ZONE_MAX_WIDTH = 900;

-- Spell Mob / Learned From window:
-- 500px is narrow enough to be useful on smaller screens while still
-- leaving long mob names readable in the single-column layout.
LOCATION_MIN_WIDTH = 500;
LOCATION_MAX_WIDTH = 900;
LOCATION_TWO_COLUMN_WIDTH = 620;

function clamp(value, low, high)
    value = tonumber(value) or low;
    if value < low then return low; end
    if value > high then return high; end
    return value;
end

function apply_loaded_config(s)
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

    for key, value in pairs(state.visible_tabs) do
        value[1] = config.display.visible_tabs[key] ~= false;
    end
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
