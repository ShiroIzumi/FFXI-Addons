--[[
    MogSuite - Requests settings (a page in the MogSuite settings window).
    Every setting goes through `ui` (core/cfgui.lua) so the search box finds it.
]]

-- How the settings window saves this module's changes.
module_config_dirty = function() mark_dirty(); end

local ON = { default_on = true };

local function config_popups()
    ui.section('SHOW A POPUP FOR');
    ui.check('Party and alliance invites', config, 'party', '"<name> is inviting you to join the party / alliance." with Join and Decline buttons.', ON);
    ui.check('Trade requests', config, 'trade', '"<name> wants to trade with you." with Accept and Decline buttons.', ON);

    ui.section('POPUP');
    ui.slider_i('Auto-close', config, 'auto_close', 0, 120, function(v) return (v == 0) and 'never' or '%d sec'; end,
        'Closes an unanswered popup after this long (0 = never). It also closes when you answer from the game\'s own menu or chat.');
    ui.slider_f('Size', config, 'font_scale', 0.80, 2.00, '%.2fx', 'Text and button size of the popup.');
    ui.check('Lock position and size', config, 'locked', 'Stops the popup from being moved or resized.');
    ui.check('Show title bar', config, 'title_bar', 'Shows the window title bar on the popup.');
    ui.check('Show border', config, 'border', 'A thin border around the popup.', ON);
    if ui.button('Center on screen', 'rq_center', 'Puts the popup back in the middle of the screen (the next time it shows).') then module_reset_position(); end

    ui.section('TEST');
    ui.info('Shows the popup with a sample name so you can place and size it. Its buttons only close it.');
    if ui.want('Test popup', 'test party alliance trade sample') then
        ui.label('Show a test', 'Shows the popup with a sample name.');
        if imgui.Button('Party##rq_test_party') then show_test('party'); end
        imgui.SameLine();
        if imgui.Button('Alliance##rq_test_alliance') then show_test('alliance'); end
        imgui.SameLine();
        if imgui.Button('Trade##rq_test_trade') then show_test('trade'); end
    end
end

module_config_sections = {
    { key = 'popups', label = 'Popups', draw = config_popups, desc = 'Which requests get a popup, how it looks, and a test to place it.' },
};
