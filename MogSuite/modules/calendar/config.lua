--[[
    MogSuite - Calendar settings (pages in the MogSuite settings window).
]]

module_config_dirty = function() mark_dirty(); end

local ON = { default_on = true };
local WEEKDAYS = {
    { key = 0, label = 'Sun' }, { key = 1, label = 'Mon' }, { key = 2, label = 'Tue' }, { key = 3, label = 'Wed' },
    { key = 4, label = 'Thu' }, { key = 5, label = 'Fri' }, { key = 6, label = 'Sat' },
};

local function config_window()
    ui.section('WINDOW');
    ui.check('Lock position and size', config, 'locked', 'Stops the Calendar window from being moved or resized.');
    ui.slider_f('Size', config, 'font_scale', 0.80, 2.00, '%.2fx', 'Text size of the Calendar window, the login summary and notices.');
    ui.check('24-hour clock', config, 'time24', 'Earth times as 13:20 instead of 1:20 PM.');
    if ui.button('Reset window position', 'cal_resetpos', 'Puts the Calendar window back in the middle of the screen.') then module_reset_position(); end

    ui.section('MONTH VIEWS SHOW');
    ui.check('Moon phases', config.show, 'moon', 'The moon on each Vana\'diel day, and full / new moons on Earth days.', ON);
    ui.check('Guild holidays', config.show, 'holidays', 'A dot on Vana\'diel days when a crafting guild is closed.', ON);
    ui.check('Conquest results', config.show, 'conquest', 'The weekly conquest results.', ON);
    ui.check('Your events', config.show, 'events', nil, ON);
    ui.check('When your timers are ready', config.show, 'timers', nil, ON);
end

local function config_conquest()
    ui.section('CONQUEST RESULTS');
    ui.info('When the weekly conquest results come in, in your computer\'s local time. HorizonXI: Sunday 11:00 AM Eastern.');
    ui.check('Show conquest results', config.conquest, 'enabled', nil, ON);
    ui.choice('Day', config.conquest, 'weekday', WEEKDAYS, 'The day of the week (your local time).');
    ui.slider_i('Hour', config.conquest, 'hour', 0, 23, '%d:00', 'The hour, 24-hour clock (11 = 11 AM).');
    ui.slider_i('Minute', config.conquest, 'minute', 0, 59, ':%02d');
    if ui.want('next conquest') then
        ui.label('Next results');
        imgui.TextColored(UI_ACCENT_TEXT, when_at(next_conquest()));
    end
end

local function config_login()
    ui.section('LOGIN SUMMARY');
    ui.info('A few seconds after you log in: the day, the moon, conquest, your timers and today\'s events.');
    ui.check('Show a summary when I log in', config.login, 'enabled', nil, ON);
    ui.check('As a popup', config.login, 'popup', 'A small box at the top of the screen.', ON);
    ui.check('In the chat log', config.login, 'chat', 'The same lines in the chat log.');
    ui.slider_i('Popup stays for', config.login, 'seconds', 5, 120, '%d sec');
    ui.info('Drag the popup to move it; it stays open while the mouse is over it.');
    if ui.button('Reset popup position', 'cal_popup_reset', 'Puts the login summary and notices back at the top centre.') then
        config.popup_pos = T{ x = -1, y = -1 };
        state.popup_moved = false;
        mark_dirty();
    end
    ui.section('IT SHOWS');
    ui.check('Day and element', config.login, 'day', nil, ON);
    ui.check('Moon', config.login, 'moon', nil, ON);
    ui.check('Conquest results', config.login, 'conquest', nil, ON);
    ui.check('Timers (ready, or ready within a day)', config.login, 'timers', nil, ON);
    ui.check('Events in the next 24 hours', config.login, 'events', nil, ON);
    ui.check('Guild holidays', config.login, 'guilds', nil, ON);
    if ui.button('Show it now', 'cal_login_test', 'Shows the login summary now.') then show_login(); end
end

local function config_notify()
    ui.section('NOTICES');
    ui.info('When a timer is ready or one of your events starts.');
    ui.check('Notices', config.notify, 'enabled', nil, ON);
    ui.check('In the chat log', config.notify, 'chat', nil, ON);
    ui.check('As a popup', config.notify, 'popup', nil, ON);
    ui.check('With a sound', config.notify, 'sound', 'sounds\\notice.wav in the MogSuite folder (swap it for any short .wav).');
    ui.slider_i('Warn before an event', config.notify, 'before', 0, 120, function(v) return v == 0 and 'no early warning' or '%d min'; end);
end

module_config_sections = {
    { key = 'window', label = 'Window', draw = config_window, desc = 'The Calendar window and what its month views show.' },
    { key = 'conquest', label = 'Conquest', draw = config_conquest, desc = 'When the weekly conquest results come in.' },
    { key = 'login', label = 'Login summary', draw = config_login, desc = 'The summary when you log in.' },
    { key = 'notify', label = 'Notices', draw = config_notify, desc = 'Timers that are ready and events that start.' },
};
