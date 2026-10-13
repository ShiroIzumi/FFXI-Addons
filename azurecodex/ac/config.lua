--[[
    Azure Codex - ac/config.lua

    Saving settings, window geometry, theme push / pop, resets, and the
    Config window tabs (Window, Font & Colors, Display, Tabs, Behavior).
]]

function save_config()
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

    for key, value in pairs(state.visible_tabs) do
        config.display.visible_tabs[key] = value[1];
    end
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

function capture_main_geometry()
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

function capture_config_geometry()
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

function capture_zone_geometry()
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
theme_stack = {};

function push_theme()
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

function pop_theme()
    local entry = table.remove(theme_stack);
    if entry == nil then return; end

    if entry[2] > 0 then imgui.PopStyleVar(entry[2]); end
    if entry[1] > 0 then imgui.PopStyleColor(entry[1]); end
end

function reset_appearance()
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

function reset_window()
    state.last_x = defaults.window.x;
    state.last_y = defaults.window.y;
    state.last_w = defaults.window.width;
    state.last_h = defaults.window.height;
    state.apply_saved_geometry = true;
    state.geometry_dirty = true;
end

function reset_cursor()
    config.cursor = T{
        enabled = true,
        size = defaults.cursor.size,
        color = T{ defaults.cursor.color[1], defaults.cursor.color[2], defaults.cursor.color[3], defaults.cursor.color[4] },
        outline = T{ defaults.cursor.outline[1], defaults.cursor.outline[2], defaults.cursor.outline[3], defaults.cursor.outline[4] },
        shadow = true,
    };
    state.settings_dirty = true;
end

function reset_all()
    reset_appearance();
    reset_window();
    reset_cursor();

    state.row_spacing = defaults.display.row_spacing;
    state.rows_mode = defaults.display.rows_mode;
    state.rows_per_page[1] = defaults.display.rows_per_page;

    for _, value in pairs(state.visible_tabs) do value[1] = true; end
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

function section_title(value)
    imgui.TextColored(state.header_color, value);
    imgui.PushStyleColor(ImGuiCol_Separator, accent(0.35));
    imgui.Separator();
    imgui.PopStyleColor(1);
    imgui.Spacing();
end

function draw_window_tab()
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

    imgui.Spacing();
    section_title('MOUSE POINTER');

    local cur = config.cursor;
    local enabled = { cur.enabled ~= false };
    if imgui.Checkbox('Show a mouse pointer over Azure Codex windows', enabled) then
        cur.enabled = enabled[1];
        state.settings_dirty = true;
    end
    imgui.TextColored(MUTED, 'FFXI hides the Windows pointer. Turn this off if you already use a pointer tool (such as YoloMouse).');

    if cur.enabled ~= false then
        imgui.PushItemWidth(260);
        local size = { tonumber(cur.size) or defaults.cursor.size };
        if imgui.SliderFloat('Pointer Size##azure_cursor_size', size, 0.60, 3.00, '%.2fx') then
            cur.size = size[1];
            state.settings_dirty = true;
        end
        if imgui.ColorEdit4('Pointer Color##azure_cursor_color', cur.color) then
            state.settings_dirty = true;
        end
        if imgui.ColorEdit4('Pointer Outline##azure_cursor_outline', cur.outline) then
            state.settings_dirty = true;
        end
        imgui.PopItemWidth();

        local shadow = { cur.shadow ~= false };
        if imgui.Checkbox('Drop Shadow##azure_cursor_shadow', shadow) then
            cur.shadow = shadow[1];
            state.settings_dirty = true;
        end
        imgui.SameLine();
        if imgui.Button('Default Pointer##azure_cursor_reset') then
            reset_cursor();
        end
    end
end

function draw_font_colors_tab()
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

function draw_display_tab()
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

function draw_tabs_config_tab()
    section_title('MAIN TABS');
    imgui.TextColored(MUTED, 'Choose which navigation tabs appear in the main window.');
    for _, item in ipairs({
        { 'All', 'all' },
        { 'Known', 'known' },
        { 'Missing', 'missing' },
        { 'Up to My Level', 'ready' },
        { 'BLUPrints', 'bluprints' },
        { 'BLUPrint-View', 'view' },
    }) do
        if imgui.Checkbox(item[1] .. '##azure_visible_tab_' .. item[2], state.visible_tabs[item[2]]) then
            state.settings_dirty = true;
        end
    end
    imgui.Spacing();
    imgui.TextColored(MUTED, 'Hiding a tab does not close its current page.');
    imgui.TextColored(MUTED, 'The Spells navigation and Config remain accessible.');
end

function draw_behavior_tab()
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
    imgui.TextColored(MUTED, 'While BLU is your main job: a small tag shows when your target teaches a blue spell in this zone. Spells you already know show as "Already Know:" on green.');

    imgui.Spacing();
    section_title('RESET');

    if imgui.Button('Reset All Settings') then
        reset_all();
    end
end
