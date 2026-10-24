--[[
    MogSuite - Actions settings (pages in the MogSuite settings window).
    Every setting goes through `ui` (core/cfgui.lua) so the search box finds it.
]]

-- How the settings window saves this module's changes.
module_config_dirty = function() mark_dirty(); end

local ARMED = {};
local ON = { default_on = true };

local function config_window()
    ui.section('WINDOW');
    ui.check('Lock position and size', config, 'locked', 'Stops the Actions window from being moved or resized.');
    ui.check('Show title bar', config, 'title_bar', 'Shows the window title bar. Without it, the window has its own X button.');
    if ui.button('Reset window position', 'ab_resetpos', 'Moves the Actions window back to its default place and size.') then module_reset_position(); end

    ui.section('LAYOUT');
    ui.slider_f('Size', config, 'font_scale', 0.75, 2.50, '%.2fx', 'Scales the text and rows together.');
    ui.slider_i('Row spacing', config, 'row_spacing', 0, 10, '%d px', 'Extra space above and below each row.');

    ui.section('SHOW');
    ui.check('HP / MP / TP bars', config, 'show_bars', 'Your HP, MP and TP under the job line. The TP bar has a mark at 1000.', ON);
    ui.check('Pinned actions at the top', config, 'show_pinned', 'Right-click any row > Pin to the top. Click a pinned action to use it, right-click it to unpin.', ON);
    ui.check('Details pane at the bottom', config, 'show_details', 'Off (default): the details show as a tooltip when you hover a row, styled by Settings > Global > Fonts & Tooltips.');
end

local function config_colors()
    ui.section('COLORS');
    ui.color('Names', config.name_color, 'Color of ability, weapon skill and spell names.', true);
    ui.color('MP cost and macro text', config.value_color, 'Color of MP costs and the macro line in the details pane.', true);
    ui.info('The text effect is set for every window in Global > Text.');

    if ui.preview() then
        ui.section('PREVIEW');
        local dl = imgui.GetWindowDrawList();
        local sx, sy = imgui.GetCursorScreenPos();
        local w = 320 * ui.scale;
        local lh = imgui.GetTextLineHeight();
        dl:AddRectFilled({ sx, sy }, { sx + w, sy + lh + 12 }, imgui.GetColorU32({ 0.42, 0.40, 0.50, 1.0 }), 4.0);
        draw_orb(dl, sx + 14, sy + 6 + lh * 0.5, 5, ELEMENTS[6][2], false);
        draw_fx_text(dl, sx + 28, sy + 6, config.name_color, 'Cure IV');
        draw_fx_text(dl, sx + w - text_w('88 MP') - 8, sy + 6, config.value_color, '88 MP');
        imgui.Dummy({ w, lh + 14 });
    end
end

local SORTS = {
    { key = 'level', label = 'Level', tip = 'Lowest level first.' },
    { key = 'name', label = 'Name', tip = 'A to Z.' },
};

local function config_lists()
    ui.section('ABILITIES');
    ui.check('Show support job abilities you have not reached yet', config, 'show_sub_locked',
        'Lists support job abilities above your support level, greyed out with the level you get them.', ON);
    ui.check('Show job traits', config, 'show_traits',
        'Lists your main and support job traits (HorizonXI levels) after the abilities.', ON);
    ui.check('Show the "H" mark on HorizonXI changes', config, 'show_horizon_marks',
        'Abilities, traits, spells, weapon skills and blood pacts that HorizonXI changed get a small gold H. Hover it to see what changed (from the HorizonXI wiki).', ON);

    ui.section('WEAPON SKILLS');
    ui.check('Show relic weapon skills you do not have', config, 'show_special_ws',
        'Relic weapon skills are hidden unless you have them. (HorizonXI has no mythic weapons.)');
    ui.check('Skillchains panel', config, 'show_sc_panel',
        'A section at the bottom of the Weapon Skills tab listing every skillchain your ready weapon skills make, with magic burst elements.', ON);
    ui.check('Chains in weapon skill tooltips', config, 'show_sc_combos',
        'Weapon skill tooltips list which of your other weapon skills it opens into or closes after.', ON);
    ui.check('Range and area in tooltips', config, 'show_range',
        'Spell and ability tooltips show the range and whether it hits an area.', ON);

    ui.section('MAGIC');
    ui.check('Hide spells you cannot cast yet', config, 'hide_unknown_spells',
        'Only spells you know and have the level for are listed.');
    ui.check('Show ninja tool counts on Ninjutsu', config, 'show_tools',
        'Shows how many of each ninja tool you carry (Shihei 87), red at 0.', ON);
    ui.choice('Sort spells by', config, 'magic_sort', SORTS, 'The order spells are listed in.', { default = 'level' });

    ui.section('SECTIONS');
    if ui.button('Reset sections', 'ab_expand', 'Opens every section again, with Unusable magic collapsed.') then
        config.collapsed = T{};
        mark_dirty();
    end
    if ui.danger('Clear pinned actions', 'ab_clearpins', ARMED, 'Removes every pinned action (click twice).') then
        config.pinned = T{};
        mark_dirty();
    end
end

module_config_sections = {
    { key = 'window', label = 'Window', draw = config_window, desc = 'Where the Actions window sits, how big its rows are, and what shows above and below the list.' },
    { key = 'lists', label = 'Lists', draw = config_lists, desc = 'What the Abilities, Weapon Skills and Magic tabs list, and in what order.' },
    { key = 'colors', label = 'Colors', draw = config_colors, desc = 'Colors for action names and MP costs.' },
};
