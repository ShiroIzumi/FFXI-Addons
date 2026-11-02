--[[
    Azure Codex - ac/pages.lua

    About tab, BLUPrint-View page, Azure Loadout page, the Config window, and
    the main spell table helpers (filters, rows per page).
]]

function draw_about_tab()
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

function get_saved_build_spells_for_view(filename)
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

function draw_bluprint_view_page()
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
                imgui.TextColored(info_color(), tostring(trait_text));
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

function draw_spellsets_page()
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

-- 1.20.0: the Config window in MogSuite's layout (cfgkit.lua).
local kit = require('cfgkit');
local CONFIG_GROUPS = nil;
local function config_groups()
    if CONFIG_GROUPS ~= nil then return CONFIG_GROUPS; end
    CONFIG_GROUPS = {
        { label = 'Window', color = { 0.45, 0.65, 1.00, 1 }, pages = {
            { key = 'window', label = 'Window', draw = draw_window_tab, desc = 'Locks, title bar, border, background and the mouse pointer.', keywords = 'lock title border background opacity pointer cursor reset' },
            { key = 'display', label = 'Display', draw = draw_display_tab, desc = 'Row spacing, rows per page and the visible columns.', keywords = 'rows spacing columns compact' },
            { key = 'tabs', label = 'Tabs', draw = draw_tabs_config_tab, desc = 'Which navigation tabs appear in the main window.', keywords = 'tabs navigation bluprints' },
        } },
        { label = 'Look', color = { 0.45, 0.90, 0.50, 1 }, pages = {
            { key = 'fonts', label = 'Font & Colors', draw = draw_font_colors_tab, desc = 'Theme, font scale and the spell colors.', keywords = 'theme font scale color colors known learnable' },
        } },
        { label = 'Behavior', color = { 1.00, 0.60, 0.30, 1 }, pages = {
            { key = 'behavior', label = 'Behavior', draw = draw_behavior_tab, desc = 'Search / filter, learning, learning locations, BLU limits, the Target Tag and Reset All.', keywords = 'filter search learning location merits assimilation target tag reset' },
        } },
        { label = 'Global', color = { 0.70, 0.80, 0.95, 1 }, pages = {
            { key = 'about', label = 'About', draw = draw_about_tab, desc = 'What Azure Codex is, version and credits.', keywords = 'version author credits' },
        } },
    };
    return CONFIG_GROUPS;
end

-- What cfgkit needs from the theme: the theme list (swatches) and colors.
local KIT_THEME = { THEMES = {}, ORDER = {} };
local function kit_theme()
    local th = KIT_THEME;
    th.ORDER = AC_THEME_ORDER;
    for _, key in ipairs(AC_THEME_ORDER) do
        local t = AC_THEMES[key];
        th.THEMES[key] = { label = t.label, accent = t.header };
    end
    th.UI_ACCENT_TEXT = state.header_color;
    th.UI_ACCENT = state.header_color;
    th.UI_MUTED = MUTED;
    return th;
end

function draw_config_window()
    if not state.config_open[1] then
        state.apply_saved_config_geometry = true;
        return;
    end

    if state.apply_saved_config_geometry then
        kit.replace('ac');
        state.apply_saved_config_geometry = false;
    end

    local pos = { x = state.config_last_x, y = state.config_last_y, w = state.config_last_w, h = state.config_last_h };
    kit.draw({
        id = 'ac', title = 'Azure Codex - Config', open = state.config_open, pos = pos, scale = 1.0,
        dirty = function() state.config_geometry_dirty = true; end,
        groups = config_groups(), page = state.config_page or 'window',
        set_page = function(k) state.config_page = k; end,
        theme = kit_theme(), theme_key = state.theme,
        set_theme = function(k) select_theme(k); end,
        push = push_theme, pop = pop_theme,
        flags = ImGuiWindowFlags_NoNav,
        status = 'v' .. tostring(addon.version or ''),
        default_pos = { 200, 140 }, default_size = { 760, 560 },
    });
    state.config_last_x, state.config_last_y = pos.x, pos.y;
    state.config_last_w, state.config_last_h = pos.w, pos.h;
end

function draw_filter_button(label, mode, enabled)
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

function calculate_per_page()
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

function draw_main_table(filtered, first, last)
    if imgui.BeginTable ~= nil and imgui.TableSetupColumn ~= nil then
        local flags = 0;
        if ImGuiTableFlags_Resizable ~= nil then flags = bit.bor(flags, ImGuiTableFlags_Resizable); end
        if ImGuiTableFlags_RowBg ~= nil then flags = bit.bor(flags, ImGuiTableFlags_RowBg); end
        if ImGuiTableFlags_BordersInnerH ~= nil then flags = bit.bor(flags, ImGuiTableFlags_BordersInnerH); end

        -- New table id so widths saved by the old (all equal) layout are not reused.
        if imgui.BeginTable('##bluspells_spell_table_v2', active_column_count(), flags) then
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
