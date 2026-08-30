--[[
    bluspells - Documented source for GitHub

    This file keeps the original runtime behavior intact while adding
    section-level comments that explain the major systems, persistence,
    rendering, commands, and Ashita v4 integration points.

    Comments are documentation only.
]]--

--[[
    BLUSpells - Ashita v4 / HorizonXI
    Version 1.6.0

    Commands:
      /bluspells
      /bsp
      /bluspells config
      /bsp config

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

addon.name      = 'bluspells';
addon.author    = 'Izumi (ShiroIzumi)';
addon.version   = '1.6.0';
addon.desc      = 'HorizonXI Blue Magic spell list with learned-status tracking.';
addon.link      = '';

require 'common';

local imgui = require 'imgui';
local settings = require 'settings';
local spells = require 'spells';

-- ============================================================================
-- Default configuration
-- ============================================================================
local defaults = T{
    font_scale = 1.00,

    appearance = T{
        background = T{ 0.018, 0.024, 0.032, 0.94 },
        border = true,
        title_bar = true,
        locked = false,
        known_color = T{ 0.30, 1.00, 0.42, 1.00 },
        unknown_color = T{ 1.00, 0.34, 0.38, 1.00 },
        header_color = T{ 0.38, 0.78, 1.00, 1.00 },
        paging_color = T{ 0.62, 0.12, 0.14, 1.00 },
    },

    display = T{
        row_spacing = 'compact',
        rows_mode = 'auto',
        rows_per_page = 30,
        columns = T{
            level = true,
            type = true,
            trait = true,
            mob_family = true,
        },
    },

    behavior = T{
        remember_filters = true,
        auto_highlight_learned = true,
    },

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
};

local config = settings.load(defaults);

-- ============================================================================
-- Backward-compatible config migration
-- ============================================================================
local function ensure_tables()
    if config.appearance == nil then config.appearance = T{}; end
    if config.appearance.background == nil then config.appearance.background = T{}; end
    if config.appearance.known_color == nil then config.appearance.known_color = T{}; end
    if config.appearance.unknown_color == nil then config.appearance.unknown_color = T{}; end
    if config.appearance.header_color == nil then config.appearance.header_color = T{}; end
    if config.appearance.paging_color == nil then config.appearance.paging_color = T{}; end

    if config.display == nil then config.display = T{}; end
    if config.display.columns == nil then config.display.columns = T{}; end

    if config.behavior == nil then config.behavior = T{}; end
    if config.ui_state == nil then config.ui_state = T{}; end
    if config.window == nil then config.window = T{}; end
    if config.config_window == nil then config.config_window = T{}; end

    local function fill_color(dst, src)
        for i = 1, 4 do
            if dst[i] == nil then dst[i] = src[i]; end
        end
    end

    fill_color(config.appearance.background, defaults.appearance.background);
    fill_color(config.appearance.known_color, defaults.appearance.known_color);
    fill_color(config.appearance.unknown_color, defaults.appearance.unknown_color);
    fill_color(config.appearance.header_color, defaults.appearance.header_color);
    fill_color(config.appearance.paging_color, defaults.appearance.paging_color);

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
end

ensure_tables();

local remember = config.behavior.remember_filters == true;

-- ============================================================================
-- Runtime UI/filter/learning state
-- ============================================================================
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

    row_spacing = tostring(config.display.row_spacing or 'compact'),
    rows_mode = tostring(config.display.rows_mode or 'auto'),
    rows_per_page = { tonumber(config.display.rows_per_page) or 30 },

    columns = {
        level = { config.display.columns.level ~= false },
        type = { config.display.columns.type ~= false },
        trait = { config.display.columns.trait ~= false },
        mob_family = { config.display.columns.mob_family ~= false },
    },

    remember_filters = { config.behavior.remember_filters == true },
    auto_highlight_learned = { config.behavior.auto_highlight_learned ~= false },

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
    settings_dirty = false,
    last_save = 0,

    resource_ids = T{},
    resource_cache_ready = false,
};

local MUTED = { 0.56, 0.61, 0.68, 1.00 };
local TEXT = { 0.92, 0.94, 0.97, 1.00 };
local TITLE = { 0.030, 0.045, 0.060, 1.00 };
local BORDER = { 0.16, 0.23, 0.31, 1.00 };
local CONTROL = { 0.055, 0.075, 0.100, 1.00 };
local CONTROL_HOVER = { 0.090, 0.145, 0.200, 1.00 };
local CONTROL_ACTIVE = { 0.110, 0.200, 0.285, 1.00 };

local function clamp(value, low, high)
    value = tonumber(value) or low;
    if value < low then return low; end
    if value > high then return high; end
    return value;
end

local function normalize_name(value)
    if value == nil then return ''; end
    return tostring(value):lower():gsub('[^%w]', '');
end

local resource_aliases = T{
    ['quadraticcontinnuum'] = 'quadraticcontinuum',
};

-- ============================================================================
-- Ashita resource cache and learned-spell lookup
-- ============================================================================
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

local function is_known(spell_name)
    local player = safe_player();
    if not player then return false; end

    if not state.resource_cache_ready then
        build_resource_cache();
    end

    local id = state.resource_ids[normalize_name(spell_name)];
    if id == nil then return false; end

    return player:HasSpell(id);
end

local function get_learned_count()
    local player = safe_player();
    if not player then return 0; end

    if not state.resource_cache_ready then
        build_resource_cache();
    end

    local count = 0;
    for _, spell in ipairs(spells) do
        local id = state.resource_ids[normalize_name(spell.name)];
        if id ~= nil and player:HasSpell(id) then
            count = count + 1;
        end
    end
    return count;
end

-- ============================================================================
-- Current BLU level detection for the Ready filter
-- ============================================================================
local function safe_blu_level()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then return nil; end

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

    -- Blue Mage job id is 16.
    if main_job == 16 and main_level and main_level > 0 then
        return main_level;
    end

    return nil;
end

-- ============================================================================
-- Search/filter pipeline
-- ============================================================================
-- Search checks all spell metadata and supports | as an OR separator.
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

local function spell_matches_search(spell, terms)
    if #terms == 0 then return true; end

    local haystack = table.concat({
        tostring(spell.name or ''),
        tostring(spell.level or ''),
        tostring(spell.type or ''),
        tostring(spell.trait or ''),
        tostring(spell.mob_family or ''),
    }, ' '):lower();

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

-- ============================================================================
-- Sorting
-- ============================================================================
local function compare_spells(a, b)
    local key = state.sort_mode;
    local av, bv;

    if key == 'name' then
        av, bv = a.name:lower(), b.name:lower();
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

local function get_filtered_spells()
    local terms = split_search_terms(state.search[1]);
    local blu_level = safe_blu_level();
    local result = {};

    for _, spell in ipairs(spells) do
        local known = is_known(spell.name);
        if filter_accepts(spell, known, blu_level) and spell_matches_search(spell, terms) then
            result[#result + 1] = spell;
        end
    end

    table.sort(result, compare_spells);
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
    imgui.PushStyleColor(ImGuiCol_Text, state.header_color);
    if imgui.Button(sort_label(label, mode) .. '##sort_' .. mode) then
        set_sort(mode);
    end
    imgui.PopStyleColor(1);
end

-- ============================================================================
-- Newly learned spell detection/highlighting
-- ============================================================================
local function update_known_snapshot()
    local now = os.clock();

    if not state.known_snapshot_initialized then
        for _, spell in ipairs(spells) do
            state.known_snapshot[normalize_name(spell.name)] = is_known(spell.name);
        end
        state.known_snapshot_initialized = true;
        return;
    end

    for _, spell in ipairs(spells) do
        local key = normalize_name(spell.name);
        local known = is_known(spell.name);
        local previous = state.known_snapshot[key] == true;

        if known and not previous and state.auto_highlight_learned[1] then
            state.selected_spell = spell.name;
            state.learned_flash_until = now + 5.0;
            state.jump_to_selected = true;
        end

        state.known_snapshot[key] = known;
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

-- ============================================================================
-- Table/column rendering
-- ============================================================================
local function active_column_count()
    local count = 1;
    if state.columns.level[1] then count = count + 1; end
    if state.columns.type[1] then count = count + 1; end
    if state.columns.trait[1] then count = count + 1; end
    if state.columns.mob_family[1] then count = count + 1; end
    return count;
end

local function setup_table_columns()
    imgui.TableSetupColumn('Spell');
    if state.columns.level[1] then imgui.TableSetupColumn('Lvl'); end
    if state.columns.type[1] then imgui.TableSetupColumn('Type'); end
    if state.columns.trait[1] then imgui.TableSetupColumn('Trait'); end
    if state.columns.mob_family[1] then imgui.TableSetupColumn('Mob Family'); end
end

local function draw_table_headers()
    imgui.TableNextRow();

    imgui.TableNextColumn();
    draw_sort_header('Spell', 'name');

    if state.columns.level[1] then
        imgui.TableNextColumn();
        draw_sort_header('Lvl', 'level');
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

local function draw_spell_table_row(spell)
    local known = is_known(spell.name);
    local selected = state.selected_spell == spell.name;
    local color = known and state.known_color or state.unknown_color;

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
    end
    imgui.PopStyleColor(1);

    if selected and os.clock() <= state.learned_flash_until then
        imgui.PopStyleColor(3);
    end

    if state.columns.level[1] then
        imgui.TableNextColumn();
        imgui.Text(tostring(spell.level));
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
    imgui.TextColored(state.header_color, 'Spell');
    imgui.SameLine(); imgui.SetCursorPosX(300); imgui.TextColored(state.header_color, 'Lvl');
    imgui.SameLine(); imgui.SetCursorPosX(350); imgui.TextColored(state.header_color, 'Type');
    imgui.SameLine(); imgui.SetCursorPosX(505); imgui.TextColored(state.header_color, 'Trait');
    imgui.SameLine(); imgui.SetCursorPosX(720); imgui.TextColored(state.header_color, 'Mob Family');
    imgui.Separator();

    for i = first, last do
        local spell = filtered[i];
        local known = is_known(spell.name);
        local selected = state.selected_spell == spell.name;
        local color = known and state.known_color or state.unknown_color;

        imgui.PushStyleColor(ImGuiCol_Text, color);
        if imgui.Selectable(spell.name .. '##fallback_' .. normalize_name(spell.name), selected) then
            state.selected_spell = spell.name;
        end
        imgui.PopStyleColor(1);

        imgui.SameLine(); imgui.SetCursorPosX(300); imgui.Text(tostring(spell.level));
        imgui.SameLine(); imgui.SetCursorPosX(350); imgui.Text(tostring(spell.type or '--'));
        imgui.SameLine(); imgui.SetCursorPosX(505); imgui.Text(tostring(spell.trait or 'None'));
        imgui.SameLine(); imgui.SetCursorPosX(720); imgui.Text(tostring(spell.mob_family or '--'));
    end
end

-- ============================================================================
-- Settings persistence
-- ============================================================================
local function save_config()
    ensure_tables();

    config.font_scale = state.font_scale[1];

    for i = 1, 4 do
        config.appearance.background[i] = state.background[i];
        config.appearance.known_color[i] = state.known_color[i];
        config.appearance.unknown_color[i] = state.unknown_color[i];
        config.appearance.header_color[i] = state.header_color[i];
        config.appearance.paging_color[i] = state.paging_color[i];
    end

    config.appearance.border = state.border[1];
    config.appearance.title_bar = state.title_bar[1];
    config.appearance.locked = state.locked[1];

    config.display.row_spacing = state.row_spacing;
    config.display.rows_mode = state.rows_mode;
    config.display.rows_per_page = math.floor(clamp(state.rows_per_page[1], 8, 60));

    config.display.columns.level = state.columns.level[1];
    config.display.columns.type = state.columns.type[1];
    config.display.columns.trait = state.columns.trait[1];
    config.display.columns.mob_family = state.columns.mob_family[1];

    config.behavior.remember_filters = state.remember_filters[1];
    config.behavior.auto_highlight_learned = state.auto_highlight_learned[1];

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

    settings.save();
end

-- ============================================================================
-- Main/config geometry persistence
-- ============================================================================
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

-- ============================================================================
-- Local ImGui theme
-- ============================================================================
local function push_theme()
    imgui.PushStyleColor(ImGuiCol_WindowBg, {
        state.background[1], state.background[2], state.background[3], state.background[4]
    });
    imgui.PushStyleColor(ImGuiCol_TitleBg, TITLE);
    imgui.PushStyleColor(ImGuiCol_TitleBgActive, TITLE);
    imgui.PushStyleColor(ImGuiCol_Border, BORDER);
    imgui.PushStyleColor(ImGuiCol_Text, TEXT);
    imgui.PushStyleColor(ImGuiCol_FrameBg, CONTROL);
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, CONTROL_HOVER);
    imgui.PushStyleColor(ImGuiCol_FrameBgActive, CONTROL_ACTIVE);
    imgui.PushStyleColor(ImGuiCol_Button, CONTROL);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, CONTROL_HOVER);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, CONTROL_ACTIVE);
    imgui.PushStyleColor(ImGuiCol_Separator, BORDER);
end

local function pop_theme()
    imgui.PopStyleColor(12);
end

-- ============================================================================
-- Reset helpers
-- ============================================================================
local function reset_appearance()
    state.font_scale[1] = defaults.font_scale;

    for i = 1, 4 do
        state.background[i] = defaults.appearance.background[i];
        state.known_color[i] = defaults.appearance.known_color[i];
        state.unknown_color[i] = defaults.appearance.unknown_color[i];
        state.header_color[i] = defaults.appearance.header_color[i];
        state.paging_color[i] = defaults.appearance.paging_color[i];
    end

    state.border[1] = defaults.appearance.border;
    state.title_bar[1] = defaults.appearance.title_bar;
    state.locked[1] = defaults.appearance.locked;
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
    state.columns.type[1] = defaults.display.columns.type;
    state.columns.trait[1] = defaults.display.columns.trait;
    state.columns.mob_family[1] = defaults.display.columns.mob_family;

    state.remember_filters[1] = defaults.behavior.remember_filters;
    state.auto_highlight_learned[1] = defaults.behavior.auto_highlight_learned;

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
    state.settings_dirty = true;
end

local function section_title(value)
    imgui.TextColored(state.header_color, value);
    imgui.Separator();
end

-- ============================================================================
-- Config tabs
-- ============================================================================
local function draw_window_tab()
    section_title('WINDOW');

    local locked = { state.locked[1] };
    if imgui.Checkbox('Lock Window Position / Size', locked) then
        state.locked[1] = locked[1];
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
    if imgui.ColorEdit4('Unknown Spells##blu_unknown', state.unknown_color) then
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

    if state.row_spacing == 'compact' then
        imgui.TextColored(state.header_color, 'Compact');
    elseif imgui.Button('Compact##row_spacing') then
        state.row_spacing = 'compact';
        state.settings_dirty = true;
    end

    imgui.SameLine();

    if state.row_spacing == 'normal' then
        imgui.TextColored(state.header_color, 'Normal');
    elseif imgui.Button('Normal##row_spacing') then
        state.row_spacing = 'normal';
        state.settings_dirty = true;
    end

    imgui.Spacing();
    section_title('ROWS PER PAGE');

    if state.rows_mode == 'auto' then
        imgui.TextColored(state.header_color, 'Auto');
    elseif imgui.Button('Auto##rows_mode') then
        state.rows_mode = 'auto';
        state.page = 1;
        state.settings_dirty = true;
    end

    imgui.SameLine();

    if state.rows_mode == 'fixed' then
        imgui.TextColored(state.header_color, 'Fixed');
    elseif imgui.Button('Fixed##rows_mode') then
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

    imgui.TextColored(MUTED, 'Search checks Spell, Level, Type, Trait, and Mob Family.');
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
    section_title('RESET');

    if imgui.Button('Reset All Settings') then
        reset_all();
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

    if imgui.Begin('BLU Spells - Config##bluspells_config', state.config_open, ImGuiWindowFlags_NoNav) then
        if imgui.BeginTabBar ~= nil and imgui.BeginTabBar('##bluspells_config_tabs') then
            if imgui.BeginTabItem('Window') then
                draw_window_tab();
                imgui.EndTabItem();
            end
            if imgui.BeginTabItem('Font & Colors') then
                draw_font_colors_tab();
                imgui.EndTabItem();
            end
            if imgui.BeginTabItem('Display') then
                draw_display_tab();
                imgui.EndTabItem();
            end
            if imgui.BeginTabItem('Behavior') then
                draw_behavior_tab();
                imgui.EndTabItem();
            end
            imgui.EndTabBar();
        else
            draw_window_tab();
            imgui.Spacing();
            draw_font_colors_tab();
            imgui.Spacing();
            draw_display_tab();
            imgui.Spacing();
            draw_behavior_tab();
        end

        capture_config_geometry();
    end

    imgui.End();
    pop_theme();
end

-- ============================================================================
-- Filter toolbar
-- ============================================================================
local function draw_filter_button(label, mode, enabled)
    if enabled == false then
        imgui.BeginDisabled();
        imgui.Button(label .. '##filter_' .. mode);
        imgui.EndDisabled();
        return;
    end

    if state.filter_mode == mode then
        imgui.PushStyleColor(ImGuiCol_Button, state.header_color);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, state.header_color);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, state.header_color);
        if imgui.Button(label .. '##filter_' .. mode) then
            set_filter(mode);
        end
        imgui.PopStyleColor(3);
    elseif imgui.Button(label .. '##filter_' .. mode) then
        set_filter(mode);
    end
end

-- ============================================================================
-- Auto/fixed paging
-- ============================================================================
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

-- ============================================================================
-- Main spell table
-- ============================================================================
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

-- ============================================================================
-- Main window renderer
-- ============================================================================
local function draw_window()
    if not state.open[1] then
        state.apply_saved_geometry = true;
        return;
    end

    if state.apply_saved_geometry then
        imgui.SetNextWindowPos({ state.last_x, state.last_y }, { 0, 0 });
        imgui.SetNextWindowSize({ state.last_w, state.last_h });
        state.apply_saved_geometry = false;
    end

    local flags = ImGuiWindowFlags_NoNav;

    if state.locked[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoResize);
    end
    if not state.title_bar[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar);
    end

    push_theme();

    -- Border visibility is independent from the window background.
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);

    if imgui.Begin('BLU Spells##bluspells', state.open, flags) then
        build_resource_cache();
        update_known_snapshot();

        if not state.title_bar[1] then
            local window_w = select(1, imgui.GetWindowSize());
            window_w = tonumber(window_w) or state.last_w;

            local saved_x, saved_y = imgui.GetCursorPos();
            imgui.SetCursorPos({ math.max(8, window_w - 30), 6 });

            if imgui.Button('X##bluspells_custom_close', { 22, 20 }) then
                state.open[1] = false;
                state.config_open[1] = false;
            end

            imgui.SetCursorPos({ saved_x, saved_y });
        end

        -- Search + config toolbar.
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
        draw_filter_button(blu_level and ('Ready Lv' .. tostring(blu_level)) or 'Ready', 'ready', blu_level ~= nil);

        imgui.SameLine();
        imgui.TextColored(MUTED, 'Search all columns | OR with "|"');

        -- Completion status.
        local learned_count = get_learned_count();
        local missing_count = math.max(0, #spells - learned_count);
        local pct = (#spells > 0) and ((learned_count / #spells) * 100.0) or 0.0;

        imgui.Text(('Learned %d / %d (%.1f%%)   Missing %d'):fmt(
            learned_count, #spells, pct, missing_count
        ));

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
        imgui.TextColored(state.known_color, 'Green = Known');
        imgui.SameLine();
        imgui.TextColored(state.unknown_color, 'Red = Unknown');

        imgui.PopFont();

        if not state.locked[1] then
            capture_main_geometry();
        end
    end

    imgui.End();
    imgui.PopStyleVar(1);
    pop_theme();

    draw_config_window();

    if (state.geometry_dirty or state.config_geometry_dirty or state.settings_dirty)
        and (os.clock() - state.last_save) >= 0.50 then
        save_config();
        state.geometry_dirty = false;
        state.config_geometry_dirty = false;
        state.settings_dirty = false;
        state.last_save = os.clock();
    end
end

-- ============================================================================
-- Commands and Ashita event registrations
-- ============================================================================
ashita.events.register('command', 'bluspells_command_cb', function(e)
    if e == nil or e.command == nil then return; end

    local args = e.command:args();
    if #args == 0 then return; end

    if not args[1]:any('/bluspells', '/bsp') then return; end

    e.blocked = true;

    if #args >= 2 and tostring(args[2]):lower() == 'config' then
        state.config_open[1] = not state.config_open[1];
        return;
    end

    state.open[1] = not state.open[1];

    if not state.open[1] then
        state.config_open[1] = false;
    end
end);

ashita.events.register('unload', 'bluspells_unload_cb', function()
    save_config();
end);

ashita.events.register('d3d_present', 'bluspells_present_cb', function()
    draw_window();
end);
