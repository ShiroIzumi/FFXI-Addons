--[[
    MogSuite - Requests settings (drawn inside the MogSuite config window).
]]

local function checkbox(label, key, default_on, tooltip)
    local v = { (default_on and config[key] ~= false) or (not default_on and config[key] == true) };
    if imgui.Checkbox(label, v) then config[key] = v[1]; mark_dirty(); end
    if tooltip then tip(tooltip); end
end

local function config_popups()
    section_header('Show a popup for');
    checkbox('Party and alliance invites##rq_party', 'party', true, '"<name> is inviting you to join the party / alliance." with Join and Decline buttons.');
    checkbox('Trade requests##rq_trade', 'trade', true, '"<name> wants to trade with you." with Accept and Decline buttons.');

    imgui.Spacing();
    section_header('Popup');
    imgui.PushItemWidth(220);
    local ac = { tonumber(config.auto_close) or 60 };
    if imgui.SliderInt('Auto-close##rq_auto', ac, 0, 120, (ac[1] == 0) and 'never' or '%d sec', ImGuiSliderFlags_AlwaysClamp) then
        config.auto_close = ac[1];
        mark_dirty();
    end
    tip('Closes an unanswered popup after this long (0 = never). It also closes when you answer from the game\'s own menu or chat.');
    local fs = { tonumber(config.font_scale) or 1.2 };
    if imgui.SliderFloat('Size##rq_size', fs, 0.80, 2.00, '%.2fx', ImGuiSliderFlags_AlwaysClamp) then
        config.font_scale = fs[1];
        mark_dirty();
    end
    tip('Text and button size of the popup.');
    imgui.PopItemWidth();
    checkbox('Lock position and size##rq_lock', 'locked', false, 'Stops the popup from being moved or resized.');
    checkbox('Show title bar##rq_title', 'title_bar', false, 'Shows the window title bar on the popup.');
    checkbox('Show border##rq_border', 'border', true, 'A thin border around the popup.');
    if imgui.Button('Center on screen##rq_center') then module_reset_position(); end
    tip('Puts the popup back in the middle of the screen (the next time it shows).');

    imgui.Spacing();
    section_header('Test');
    imgui.TextDisabled('Shows the popup with a sample name so you can place and size it. Its buttons only close it.');
    if imgui.Button('Party##rq_test_party') then show_test('party'); end
    imgui.SameLine();
    if imgui.Button('Alliance##rq_test_alliance') then show_test('alliance'); end
    imgui.SameLine();
    if imgui.Button('Trade##rq_test_trade') then show_test('trade'); end
end

module_config_sections = {
    { key = 'popups', label = 'Popups', draw = config_popups },
};
