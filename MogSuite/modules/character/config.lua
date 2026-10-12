--[[
    MogSuite - Character settings (drawn inside the MogSuite config window).
]]

local function toggle(label, ref, tooltip)
    local v = T{ ref[1] == true };
    if imgui.Checkbox(label, v) then
        ref[1] = v[1];
        state.settings_dirty = true;
    end
    if tooltip then tip(tooltip); end
end

local function config_window()
    section_header('Window');
    toggle('Lock position and size##cs_lock', state.locked, 'Stops the Character window from being moved or resized.');
    toggle('Show border##cs_border', state.border, 'A thin border around the Character window.');
    toggle('Show title bar##cs_title', state.title_bar, 'Shows the window title bar. Without it, the window has its own X button.');
    if imgui.Button('Reset window position##cs_reset') then module_reset_position(); end
    tip('Moves the Character window back to its default place and size.');

    imgui.Spacing();
    section_header('Size');
    imgui.PushItemWidth(220);
    local size_percent = T{ state.ui_scale[1] * 100.0 };
    if imgui.SliderFloat('UI scale##cs_scale', size_percent, UI_SCALE_MIN * 100.0, UI_SCALE_MAX * 100.0, '%.0f%%') then
        state.ui_scale[1] = math.max(UI_SCALE_MIN, math.min(UI_SCALE_MAX, size_percent[1] / 100.0));
        state.settings_dirty = true;
    end
    tip('Sizes the text and spacing of the Character window together. The window never gets narrower than its content needs.');
    imgui.PopItemWidth();
    for i, preset in ipairs({ 1.00, 1.25, 1.50, 1.75, 2.00 }) do
        if i > 1 then imgui.SameLine(0, 4); end
        local selected = math.abs(state.ui_scale[1] - preset) < 0.01;
        if toggle_button(('%d%%'):fmt(math.floor(preset * 100 + 0.5)), 'cs_preset_' .. tostring(i), selected) then
            state.ui_scale[1] = preset;
            state.settings_dirty = true;
        end
        if preset >= 1.5 then tip('Good for 1440p / 4K screens.'); end
    end
    imgui.TextDisabled('Unlock the window to drag its edges and resize it.');
end

local function config_colors()
    section_header('Colors');
    if color_edit('Above zero / capped##cs_good', state.good_color, true) then state.settings_dirty = true; end
    tip('Gear bonuses, positive resistances and capped skills.');
    if color_edit('Still to go##cs_warn', state.warn_color, true) then state.settings_dirty = true; end
    tip('Skills that are not capped yet.');
    if color_edit('Below zero##cs_bad', state.bad_color, true) then state.settings_dirty = true; end
    tip('Negative resistances and penalties.');
    if color_edit('Labels##cs_muted', state.muted_color, true) then state.settings_dirty = true; end
    tip('Labels and secondary text.');
    imgui.Spacing();
    if imgui.Button('Default colors##cs_colors_reset') then
        local function set(dst, r, g, b) dst[1], dst[2], dst[3], dst[4] = r, g, b, 1.0; end
        set(state.good_color, 0.30, 1.00, 0.42);
        set(state.warn_color, 1.00, 0.82, 0.22);
        set(state.bad_color, 1.00, 0.34, 0.38);
        set(state.muted_color, 0.68, 0.71, 0.75);
        state.settings_dirty = true;
    end
    tip('Puts these four colors back to their defaults.');
end

local function config_tabs()
    section_header('Skills');
    toggle('Combat skills##cs_cfg_combat', state.skill_combat, 'Show the Combat section on the Skills tab.');
    toggle('Magic skills##cs_cfg_magic', state.skill_magic, 'Show the Magic section on the Skills tab.');
    toggle('Crafting##cs_cfg_craft', state.skill_craft, 'Show the Crafting section on the Skills tab.');
    toggle('Show skills your jobs cannot use##cs_cfg_unusable', state.show_unusable, 'Also lists skills your current jobs have no cap for, greyed out.');

    imgui.Spacing();
    section_header('Gear Stats');
    toggle('Hide stats that are zero##cs_cfg_zero', state.hide_zero, 'Only stats your equipped gear actually gives are shown.');

    imgui.Spacing();
    section_header('Currencies');
    toggle('Show currencies you have none of##cs_cfg_curzero', state.cur_show_zero, 'Lists currencies at zero under "None yet".');
    imgui.TextWrapped('Currencies are read from the game\'s own Currencies list. Open Main Menu > Currencies once and MogSuite remembers them for this character.');
end

module_config_sections = {
    { key = 'window', label = 'Window', draw = config_window },
    { key = 'tabs', label = 'Tabs', draw = config_tabs },
    { key = 'colors', label = 'Colors', draw = config_colors },
};
