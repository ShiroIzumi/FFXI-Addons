--[[
    MogSuite - Character settings (pages in the MogSuite settings window).
    Every setting goes through `ui` (core/cfgui.lua) so the search box finds it.
]]

-- How the settings window saves this module's changes.
module_config_dirty = function() state.settings_dirty = true; end

local SCALES = { 1.00, 1.25, 1.50, 1.75, 2.00 };

local function config_window()
    ui.section('WINDOW');
    ui.check('Lock position and size', state.locked, 1, 'Stops the Character window from being moved or resized.');
    ui.check('Show border', state.border, 1, 'A thin border around the Character window.');
    ui.check('Show title bar', state.title_bar, 1, 'Shows the window title bar. Without it, the window has its own X button.');
    if ui.button('Reset window position', 'cs_reset', 'Moves the Character window back to its default place and size.') then module_reset_position(); end

    ui.section('SIZE');
    ui.slider_f('UI scale', state.ui_scale, 1, UI_SCALE_MIN * 100.0, UI_SCALE_MAX * 100.0, '%.0f%%',
        'Sizes the text and spacing of the Character window together. The window never gets narrower than its content needs.', { mul = 100 });
    if ui.want('Scale presets', 'Good for 1440p / 4K screens. 100% 125% 150% 175% 200%') then
        ui.label('Presets', 'Good for 1440p / 4K screens.');
        for i, preset in ipairs(SCALES) do
            if i > 1 then imgui.SameLine(0, 4); end
            local selected = math.abs(state.ui_scale[1] - preset) < 0.01;
            if toggle_button(('%d%%'):fmt(math.floor(preset * 100 + 0.5)), 'cs_preset_' .. tostring(i), selected) then
                state.ui_scale[1] = preset;
                state.settings_dirty = true;
            end
            if preset >= 1.5 then tip('Good for 1440p / 4K screens.'); end
        end
    end
    ui.info('Unlock the window to drag its edges and resize it.');
end

local function config_colors()
    ui.section('COLORS');
    ui.color('Above zero / capped', state.good_color, 'Gear bonuses, positive resistances and capped skills.', true);
    ui.color('Still to go', state.warn_color, 'Skills that are not capped yet.', true);
    ui.color('Below zero', state.bad_color, 'Negative resistances and penalties.', true);
    ui.color('Labels', state.muted_color, 'Labels and secondary text.', true);

    if ui.preview() then
        ui.section('PREVIEW');
        local dl = imgui.GetWindowDrawList();
        local sx, sy = imgui.GetCursorScreenPos();
        local lh = imgui.GetTextLineHeight();
        local w = 340 * ui.scale;
        dl:AddRectFilled({ sx, sy }, { sx + w, sy + lh * 3 + 18 }, imgui.GetColorU32({ 0.06, 0.06, 0.07, 1.0 }), 4.0);
        local function line(y, lbl, val, col)
            local font, size = imgui.GetFont(), imgui.GetFontSize();
            dl:AddText(font, size, { sx + 10, y }, imgui.GetColorU32(state.muted_color), lbl);
            dl:AddText(font, size, { sx + w - text_w(val) - 10, y }, imgui.GetColorU32(col), val);
        end
        line(sy + 6, 'Fire resistance', '+15', state.good_color);
        line(sy + 6 + lh + 3, 'Archery skill', '187 / 225', state.warn_color);
        line(sy + 6 + (lh + 3) * 2, 'Ice resistance', '-10', state.bad_color);
        imgui.Dummy({ w, lh * 3 + 20 });
    end

    if ui.button('Default colors', 'cs_colors_reset', 'Puts these four colors back to their defaults.') then
        local function set(dst, r, g, b) dst[1], dst[2], dst[3], dst[4] = r, g, b, 1.0; end
        set(state.good_color, 0.30, 1.00, 0.42);
        set(state.warn_color, 1.00, 0.82, 0.22);
        set(state.bad_color, 1.00, 0.34, 0.38);
        set(state.muted_color, 0.68, 0.71, 0.75);
        state.settings_dirty = true;
    end
end

local function config_tabs()
    ui.section('SKILLS');
    ui.check('Combat skills', state.skill_combat, 1, 'Show the Combat section on the Skills tab.');
    ui.check('Magic skills', state.skill_magic, 1, 'Show the Magic section on the Skills tab.');
    ui.check('Crafting', state.skill_craft, 1, 'Show the Crafting section on the Skills tab.');
    ui.check('Show skills your jobs cannot use', state.show_unusable, 1, 'Also lists skills your current jobs have no cap for, greyed out.');

    ui.section('GEAR STATS');
    ui.check('Hide stats that are zero', state.hide_zero, 1, 'Only stats your equipped gear actually gives are shown.');

    ui.section('CURRENCIES');
    ui.check('Show currencies you have none of', state.cur_show_zero, 1, 'Lists currencies at zero under "None yet".');
    ui.info('Currencies are read from the game\'s own Currencies list. Open Main Menu > Currencies once and MogSuite remembers them for this character.');
end

module_config_sections = {
    { key = 'window', label = 'Window', draw = config_window, desc = 'Where the Character window sits, its frame, and how big everything in it is.' },
    { key = 'tabs', label = 'Tabs', draw = config_tabs, desc = 'What the Skills, Gear Stats and Currencies tabs list.' },
    { key = 'colors', label = 'Colors', draw = config_colors, desc = 'The colors for good, not-there-yet and bad numbers, and for labels.' },
};
