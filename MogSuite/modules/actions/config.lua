--[[
    MogSuite - Actions settings (drawn inside the MogSuite config window).
]]

-- default_on: true = on unless turned off; false = off unless turned on.
local function checkbox(label, key, default_on, tooltip)
    local v = { (default_on and config[key] ~= false) or (not default_on and config[key] == true) };
    if imgui.Checkbox(label, v) then config[key] = v[1]; mark_dirty(); end
    if tooltip then tip(tooltip); end
end

local function config_window()
    section_header('Window');
    checkbox('Lock position and size##ab_lock', 'locked', false, 'Stops the Actions window from being moved or resized.');
    checkbox('Show title bar##ab_tb', 'title_bar', false, 'Shows the window title bar. Without it, the window has its own X button.');
    if imgui.Button('Reset window position##ab_resetpos') then module_reset_position(); end
    tip('Moves the Actions window back to its default place and size.');

    imgui.Spacing();
    section_header('Layout');
    imgui.PushItemWidth(220);
    local fs = { tonumber(config.font_scale) or 1.0 };
    if imgui.SliderFloat('Size##ab_fs', fs, 0.75, 2.50, '%.2fx', ImGuiSliderFlags_AlwaysClamp) then config.font_scale = fs[1]; mark_dirty(); end
    tip('Scales the text and rows together.');
    local rs = { tonumber(config.row_spacing) or 3 };
    if imgui.SliderInt('Row spacing##ab_rs', rs, 0, 10, '%d px', ImGuiSliderFlags_AlwaysClamp) then config.row_spacing = rs[1]; mark_dirty(); end
    tip('Extra space above and below each row.');
    imgui.PopItemWidth();

    imgui.Spacing();
    section_header('Show');
    checkbox('HP / MP / TP bars##ab_bars', 'show_bars', true, 'Your HP, MP and TP under the job line. The TP bar has a mark at 1000.');
    checkbox('Pinned actions at the top##ab_pins', 'show_pinned', true, 'Right-click any row > Pin to the top. Click a pinned action to use it, right-click it to unpin.');
    checkbox('Details pane at the bottom##ab_det', 'show_details', true, 'Off: the details show as a tooltip when you hover a row instead.');
end

local function config_colors()
    section_header('Colors');
    if color_edit('Names##ab_namec', config.name_color, true) then mark_dirty(); end
    tip('Color of ability, weapon skill and spell names.');
    if color_edit('MP cost and macro text##ab_valc', config.value_color, true) then mark_dirty(); end
    tip('Color of MP costs and the macro line in the details pane.');
    imgui.TextDisabled('The text effect is set for every window in Global > Text.');

    imgui.Spacing();
    section_header('Preview');
    local dl = imgui.GetWindowDrawList();
    local sx, sy = imgui.GetCursorScreenPos();
    dl:AddRectFilled({ sx, sy }, { sx + 300, sy + imgui.GetTextLineHeight() + 12 }, imgui.GetColorU32({ 0.42, 0.40, 0.50, 1.0 }), 4.0);
    draw_orb(dl, sx + 14, sy + 6 + imgui.GetTextLineHeight() * 0.5, 5, ELEMENTS[6][2], false);
    draw_fx_text(dl, sx + 28, sy + 6, config.name_color, 'Cure IV');
    draw_fx_text(dl, sx + 300 - text_w('88 MP') - 8, sy + 6, config.value_color, '88 MP');
    imgui.Dummy({ 300, imgui.GetTextLineHeight() + 14 });
end

local function config_lists()
    section_header('Abilities');
    checkbox('Show support job abilities you have not reached yet##ab_sublock', 'show_sub_locked', true,
        'Lists support job abilities above your support level, greyed out with the level you get them.');

    imgui.Spacing();
    section_header('Weapon skills');
    checkbox('Show relic / mythic weapon skills you do not have##ab_special', 'show_special_ws', false,
        'Relic and mythic weapon skills are hidden unless you have them.');

    imgui.Spacing();
    section_header('Magic');
    checkbox('Hide spells you cannot cast yet##ab_hidespells', 'hide_unknown_spells', false,
        'Only spells you know and have the level for are listed.');
    checkbox('Show ninja tool counts on Ninjutsu##ab_tools', 'show_tools', true,
        'Shows how many of each ninja tool you carry (Shihei 87), red at 0.');
    align_label();
    imgui.Text('Sort spells by:');
    imgui.SameLine();
    if imgui.RadioButton('Level##ab_ms_lvl', config.magic_sort ~= 'name') then config.magic_sort = 'level'; mark_dirty(); end
    imgui.SameLine();
    if imgui.RadioButton('Name##ab_ms_name', config.magic_sort == 'name') then config.magic_sort = 'name'; mark_dirty(); end

    imgui.Spacing();
    section_header('Sections');
    if imgui.Button('Reset sections##ab_expand') then config.collapsed = T{}; mark_dirty(); end
    tip('Opens every section again, with Unusable magic collapsed.');
    imgui.SameLine();
    local armed = state.clear_pins_armed ~= nil and os.clock() - state.clear_pins_armed < 3.0;
    if armed then imgui.PushStyleColor(ImGuiCol_Button, { 0.72, 0.16, 0.16, 1.0 }); end
    local clicked = imgui.Button((armed and 'Click again to clear' or 'Clear pinned actions') .. '##ab_clearpins');
    if armed then imgui.PopStyleColor(1); end
    tip('Removes every pinned action (click twice).');
    if clicked then
        if armed then
            config.pinned = T{};
            state.clear_pins_armed = nil;
            mark_dirty();
        else
            state.clear_pins_armed = os.clock();
        end
    end
end

module_config_sections = {
    { key = 'window', label = 'Window', draw = config_window },
    { key = 'colors', label = 'Colors', draw = config_colors },
    { key = 'lists', label = 'Lists', draw = config_lists },
};
