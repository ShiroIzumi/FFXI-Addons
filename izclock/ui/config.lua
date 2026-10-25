--[[
    IzClock - ui/config.lua

    The settings window (/ic config, /icconfig, or right-click the clock).
    3.2.0: built on cfgui.lua, the same settings kit as MobHunt,
    WhatsMyDamage and ScrollingCombatLog (MogSuite's layout): a search box
    at the top finds any setting by name or help text, "Saved per
    character" and the theme swatches on the same line, and a sidebar of
    pages:

      CLOCK     Clock, Format, Look        (one clock at a time; with the
                                            second clock on, a switch at
                                            the top picks which)
      WINDOWS   Clock windows, Hover window, Info window, Settings window
      LOOK      Theme & colors, Fonts & Tooltips
      ALERTS    Day change
      HELP      Commands

    Every page starts with "IzClock  /  Page" and one line saying what it
    is for. Options that only matter when another one is on sit indented
    under it.
]]

require('common');
local imgui = require('imgui');
local ui = require('cfgui');
local uifont = require('uifont');
local theme = require('core.theme');
local cursor = require('core.cursor');
local vana = require('core.vana');
local schedule = require('core.schedule');

local config = {
    open = { false },
    placed = false,
    bufs = {},
    edit = 'main',     -- which clock Clock / Format / Look edit
};

function config.toggle()
    config.open[1] = not config.open[1];
    config.placed = false;
end

local CFG, D = nil, nil;   -- the settings and ctx.dirty while drawing
local V = nil;              -- the clock being edited (CFG or CFG.second)

ui.theme = {
    text = theme.UI_TEXT,
    muted = theme.UI_MUTED,
    accent = theme.UI_ACCENT,
    accent_text = theme.UI_ACCENT_TEXT,
    control = theme.UI_CONTROL,
    danger = theme.UI_DANGER,
    section_header = theme.section_header,
    help_marker = theme.help_marker,
    tip = theme.tip,
    toggle_button = theme.toggle_button,
    align_label = theme.align_label,
};

local function sc() return ui.scale or 1; end
local searching = ui.searching;
local want = ui.want;
local sub = ui.sub;
local section = ui.section;
local label = ui.label;

local function check(text, tbl, key, tip) return ui.check(text, tbl, key, tip); end
local function slider_i(text, tbl, key, lo, hi, fmt, tip) return ui.slider_i(text, tbl, key, lo, hi, fmt, tip); end
local function slider_f(text, tbl, key, lo, hi, fmt, tip, opts) return ui.slider_f(text, tbl, key, lo, hi, fmt, tip, opts); end
local function choice(text, tbl, key, options, tip) return ui.choice(text, tbl, key, options, tip); end

-- Colors are edited in place (other code keeps references to the tables).
local function color(text, tbl, key, tip, no_alpha)
    if tbl[key] == nil then tbl[key] = { 1, 1, 1, 1 }; end
    if not no_alpha and tbl[key][4] == nil then tbl[key][4] = 1; end
    return ui.color(text, tbl[key], tip, not no_alpha);
end

local function text_input(id, value, width, max)
    local b = config.bufs[id];
    if b == nil then b = { tostring(value or '') }; config.bufs[id] = b; end
    imgui.PushItemWidth(width);
    local changed = imgui.InputText('##' .. id, b, max or 32);
    imgui.PopItemWidth();
    return changed, b[1];
end

-- With the second clock on: which one the page edits.
local function pick_clock()
    if not CFG.second.enabled then
        config.edit = 'main';
        V = CFG;
        return;
    end
    V = (config.edit == 'second') and CFG.second or CFG;
    if searching() then return; end
    label('Editing', 'The Clock, Format and Look pages edit one clock at a time.');
    local new = theme.choice('ic_edit', config.edit, {
        { key = 'main', label = 'Main clock' }, { key = 'second', label = 'Second clock' },
    });
    if new ~= config.edit then
        config.edit = new;
        config.bufs = {};
    end
    V = (config.edit == 'second') and CFG.second or CFG;
end

local SEG_NAMES = {
    ['local'] = 'Local time', vana = 'Vana\'diel time', jp = 'Japan time',
    day = 'Elemental day', next = 'Next day in', moon = 'Moon',
};

-- Own opacity for one window (look = { own_alpha, alpha }).
local function own_opacity(look, what)
    check('Own opacity##' .. what, look, 'own_alpha', 'Off: the ' .. what .. ' uses the background opacity from Look > Theme & colors. On: set it here.');
    if look.own_alpha or searching() then
        sub(function()
            slider_f('Opacity##' .. what, look, 'alpha', 10, 100, '%.0f%%', 'How see-through the background of the ' .. what .. ' is. Text stays solid.', { mul = 100 });
        end);
    end
end

-- ============================================================================
-- CLOCK
-- ============================================================================

local function page_clock()
    local s = sc();
    pick_clock();

    section('LAYOUT');
    choice('Layout', V, 'layout', {
        { key = 'line', label = 'One line' },
        { key = 'stack', label = 'Stacked', tip = 'One piece per line, labels in a column.' },
        { key = 'full', label = 'Full', tip = 'Stacked, plus the rest of the week\'s days.' },
    });

    section('PIECES');
    if ui.block('Pieces local time vana\'diel time japan time elemental day next day moon label order') then
        imgui.TextColored(theme.UI_MUTED, 'Tick what shows, use the arrows to reorder, type the label (empty = none).');
        imgui.Spacing();
        local list = V.segments;
        local swap = nil;
        for i, sg in ipairs(list) do
            imgui.PushID('icseg' .. i);
            if imgui.Button('^') and i > 1 then swap = { i, i - 1 }; end
            imgui.SameLine(0, 2);
            if imgui.Button('v') and i < #list then swap = { i, i + 1 }; end
            imgui.SameLine();
            local v = { sg.show == true };
            if imgui.Checkbox(SEG_NAMES[sg.id] or sg.id, v) then sg.show = v[1]; D(); end
            imgui.SameLine(ui.LABEL_W * s + 40 * s);
            imgui.TextColored(theme.UI_MUTED, 'Label');
            imgui.SameLine();
            local changed, val = text_input('seglbl_' .. config.edit .. sg.id, sg.label, 110 * s, 24);
            if changed then sg.label = val; D(); end
            imgui.PopID();
        end
        if swap ~= nil then
            list[swap[1]], list[swap[2]] = list[swap[2]], list[swap[1]];
            D();
        end
        imgui.Spacing();
    end
    check('Show the labels', V, 'show_labels', 'Off: values only, e.g. "05:33 | Watersday > Windsday | 44m 15s".');
    if ui.button('Default pieces', 'ic_defsegs', 'Back to this clock\'s starting pieces and labels.') then
        V.segments = config.ctx.view_defaults(config.edit).segments;
        config.bufs = {};
        D();
    end

    section('ELEMENTAL DAY');
    check('Also show the next day ("Watersday > Windsday")', V, 'day_next');
    check('Element tags ("[Wa] Watersday")', V, 'element_tags');
    ui.info('The hover window and the info window are on their own pages under Windows.');
end

local function page_format()
    pick_clock();
    section('LOCAL & JAPAN TIME');
    check('24-hour clock', V, 'time24');
    check('Seconds', V, 'seconds');
    section('NEXT DAY COUNTDOWN');
    choice('Style', V, 'countdown', {
        { key = 'ms', label = '44m 15s' }, { key = 'clock', label = '44:15' },
    });
    section('MOON');
    check('Illumination % ("Full Moon (100%)")', V, 'moon_percent');
    section('SEPARATOR');
    if want('Between pieces', 'separator text between the pieces on the one-line layout') then
        label('Between pieces', 'Text between the pieces on the one-line layout, e.g. |  /  -  (empty = just space).');
        local changed, val = text_input('sep_' .. config.edit, V.separator, 60 * sc(), 8);
        if changed then V.separator = val; D(); end
    end
end

local function page_look()
    pick_clock();
    section('TEXT');
    slider_f('Size', V, 'font_scale', 0.6, 3.0, '%.2fx', 'The size of this clock\'s text.');
    choice('Effect', V, 'text_effect', theme.EFFECTS, 'A shadow or outline keeps the text readable over bright scenery, especially with a see-through background.');

    section('COLORS');
    color('Labels', V, 'label_color');
    color('Values', V, 'value_color', 'Local time, Japan time, countdown and moon.');
    color('Vana\'diel time', V, 'vana_color');
    color('Separators', V, 'sep_color');
    if want('Days', 'day colors firesday earthsday watersday windsday iceday lightningday lightsday darksday') then
        label('Days');
        for i = 0, 7 do
            if i == 4 then imgui.SetCursorPosX(ui.LABEL_W * sc()); end
            local c = V.day_colors[i + 1] or vana.DAY_COLORS[i];
            local v = { c[1], c[2], c[3], c[4] or 1 };
            if imgui.ColorEdit4('##icday' .. i, v, ImGuiColorEditFlags_NoInputs or 0) then
                V.day_colors[i + 1] = { v[1], v[2], v[3], v[4] };
                D();
            end
            theme.tip(vana.DAYS[i]);
            if i ~= 3 and i ~= 7 then imgui.SameLine(); end
        end
    end
    if ui.button('Default colors', 'ic_defcol', 'This clock\'s label, value, time, separator and day colors back to the defaults.') then
        local d = config.ctx.view_defaults(config.edit);
        V.label_color = { unpack(d.label_color) };
        V.value_color = { unpack(d.value_color) };
        V.vana_color = { unpack(d.vana_color) };
        V.sep_color = { unpack(d.sep_color) };
        V.day_colors = config.ctx.day_colors();
        D();
    end

    section('BACKGROUND & BORDER');
    if V.bg == nil then V.bg = { 0.055, 0.070, 0.095 }; end
    ui.color('Background', V.bg, 'The clock\'s own background (the clocks don\'t use the theme background).', false);
    slider_f('Opacity', V, 'bg_alpha', 0, 100, '%.0f%%', '0 = see-through (just the text), 100 = solid.', { mul = 100 });
    check('Border', V, 'border');
    if V.border or searching() then sub(function() color('Border color', V, 'border_color'); end); end
    slider_i('Rounding', V, 'rounding', 0, 12, '%d px');

    section('SPACING & WIDTH');
    slider_i('Padding left / right', V, 'pad_x', 0, 30, '%d px');
    slider_i('Padding top / bottom', V, 'pad_y', 0, 20, '%d px');
    slider_i('Space around separators', V, 'gap', 0, 30, '%d px');
    if V.layout ~= 'line' or searching() then slider_i('Space between lines', V, 'line_gap', 0, 16, '%d px'); end
    choice('Width', V, 'width_mode', {
        { key = 'auto', label = 'Fit the text' },
        { key = 'fixed', label = 'Fixed', tip = 'A set width; the text can be aligned inside it.' },
    });
    if V.width_mode == 'fixed' or searching() then
        sub(function()
            slider_i('Width##clockw', V, 'width', 100, 1600, '%d px');
            choice('Align', V, 'align', {
                { key = 'left', label = 'Left' }, { key = 'center', label = 'Center' }, { key = 'right', label = 'Right' },
            });
        end);
    end
end

-- ============================================================================
-- WINDOWS
-- ============================================================================

local ROUTE_TIP = 'Departure times are the game\'s ship schedules (measured from retail, as used by LandSandBoat, the server HorizonXI is built on).';

local function position_line(text, c, which, tip)
    if not want(text, tip) then return; end
    label(text, tip);
    imgui.TextColored(theme.UI_TEXT, ('%d, %d'):format(tonumber(c.x) or 0, tonumber(c.y) or 0));
    imgui.SameLine();
    if imgui.SmallButton('Reset##ic_resetpos_' .. which) then config.ctx.reset_position(which); end
    theme.tip('Moves the clock back to the top-left corner (/ic reset moves both).');
end

local function page_clock_windows()
    section('MAIN CLOCK');
    check('Lock position', CFG, 'lock', 'Stops the clock from being dragged (also /ic lock, which locks both).');
    position_line('Position', CFG, 'main');

    section('SECOND CLOCK');
    local sc2 = CFG.second;
    check('Show a second clock', sc2, 'enabled', 'Its own pieces, layout and look; pick it at the top of the Clock, Format and Look pages (also /ic second). For example a one-line bar plus a stacked panel.');
    if sc2.enabled or searching() then
        sub(function()
            check('Lock position##second', sc2, 'lock');
            position_line('Position##second', sc2, 'second');
            if ui.button('Edit the second clock', 'ic_edit2', 'Opens the Clock page for the second clock.') then
                config.edit = 'second';
                CFG.config_page = 'clock';
                config.bufs = {};
                D();
            end
        end);
    end

    section('BOTH CLOCKS');
    check('Hide during cutscenes', CFG, 'hide_events', 'Also while the game\'s interface is hidden. The clocks are always hidden before you log in.');
    ui.info('Each clock\'s size, colors, background and border are on Clock > Look.');
end

local function page_hover()
    local h = CFG.hover;
    section('HOVER WINDOW');
    choice('Opens over', h, 'area', {
        { key = 'clock', label = 'The whole clock' },
        { key = 'day', label = 'The day only' },
        { key = 'off', label = 'Off' },
    }, 'Where the mouse has to be for the hover window to open.');
    if h.area ~= 'off' or searching() then
        sub(function()
            ui.scale_presets('Size', h, 'scale', 'Makes everything in the hover window bigger or smaller.');
            slider_f('Size (fine)##hover', h, 'scale', 0.75, 2.0, '%.2fx', 'The same setting as Size, in small steps.');
            check('This week', h, 'week', 'The coming days, when each starts, and the local time it starts at.');
            check('Moon', h, 'moon', 'Phase, %, waxing or waning, and when the next Full and New Moon start.');
            check('Crafting', h, 'craft', 'The crystal element favored today and the one it is strong against, plus which guilds are on holiday. The day bonus is traditional FFXI crafting lore; LandSandBoat (HorizonXI\'s base) does not apply one, so treat it as a guide.');
            check('Guild hours', h, 'guilds', 'Each crafting guild: open or closed, and when that changes. Hours and holidays are LandSandBoat\'s.');
            check('Ships & airships', h, 'travel', ROUTE_TIP);
        end);
        ui.info('The hover window is a tooltip: its background, border and padding are set on Look > Fonts & Tooltips.');
        if h.travel or searching() then
            section('SHIPS IN THE HOVER WINDOW');
            ui.info('The info window lists all of them.');
            for _, grp in ipairs(schedule.GROUPS) do
                local keys = grp;
                for _, r in ipairs(schedule.ROUTES) do if r.group == grp then keys = keys .. ' ' .. r.name; end end
                if ui.block(keys .. ' ship airship route') then
                    imgui.TextColored(theme.UI_ACCENT_TEXT, grp);
                    local n = 0;
                    for _, r in ipairs(schedule.ROUTES) do
                        if r.group == grp then
                            if n % 2 == 1 then imgui.SameLine(250 * sc()); end
                            local v = { h.routes[r.key] == true };
                            if imgui.Checkbox(r.name .. '##icr_' .. r.key, v) then h.routes[r.key] = v[1]; D(); end
                            n = n + 1;
                        end
                    end
                end
            end
        end
    end
end

local function page_info()
    section('WINDOW');
    ui.info('Now, the week, the moon, crafting, every guild and every ship, in three columns. It uses the main clock\'s colors and 12/24h setting, and the theme. It opens where you last left it.');
    ui.scale_presets('Size', CFG, 'info_scale', 'The info window sizes itself to fit; this makes everything in it bigger or smaller.');
    slider_f('Size (fine)##info', CFG, 'info_scale', 0.75, 2.0, '%.2fx', 'The same setting as Size, in small steps.');
    own_opacity(CFG.look.info, 'info window');
    if ui.button('Open the info window', 'ic_openinfo', 'Same as clicking the clock (/ic info).') then config.ctx.info_toggle(); end
end

local function page_settings_window()
    section('WINDOW');
    ui.scale_presets('Settings size', CFG, 'ui_scale', 'Size of this window. Drag its bottom-right corner to change the window itself.');
    slider_f('Size (fine)##settings', CFG, 'ui_scale', 0.75, 2.0, '%.2fx', 'The same setting as Settings size, in small steps.');
    slider_f('Opacity', CFG.look.config, 'alpha', 10, 100, '%.0f%%', 'How see-through this settings window is. It has its own opacity, separate from the other windows.', { mul = 100 });
    if ui.button('Reset size and position', 'ic_cfgreset', 'Puts this window back in its starting place and size.') then
        CFG.config_win = { x = -1, y = -1, w = -1, h = -1 };
        config.placed = false;
        D();
    end
end

-- ============================================================================
-- LOOK
-- ============================================================================

local function theme_buttons()
    if not want('Theme', 'Colors of the settings, hover and info windows. Forest Rust Bone Copper Gold Garnet Fuchsia Silver Amethyst Emerald Midnight') then return; end
    label('Theme', 'Colors of the settings, hover and info windows: accents, tabs, borders and title bars.');
    local s = sc();
    local col_x = ui.LABEL_W * s;
    local avail = imgui.GetContentRegionAvail();
    if type(avail) == 'table' then avail = avail.x or avail[1]; end
    local right = col_x + (tonumber(avail) or 500);
    local chip = 9 * s;
    local current = theme.key(CFG.config_theme);
    for i, key in ipairs(theme.ORDER) do
        local th = theme.THEMES[key];
        local text = '      ' .. th.label;
        local bw = (tonumber((imgui.CalcTextSize(text))) or 60) + 16 * s;
        if i > 1 then
            imgui.SameLine(0, 4);
            if imgui.GetCursorPosX() + bw > right then
                imgui.NewLine();
                imgui.SetCursorPosX(col_x);
            end
        end
        if theme.toggle_button(text, 'ic_theme_' .. key, key == current) then
            CFG.config_theme = key;
            D();
        end
        pcall(function()
            local x1, y1 = imgui.GetItemRectMin();
            local _, y2 = imgui.GetItemRectMax();
            x1, y1, y2 = tonumber(x1), tonumber(y1), tonumber(y2);
            local cy = (y1 + y2) / 2;
            local a = th.accent;
            imgui.GetWindowDrawList():AddRectFilled({ x1 + 8 * s, cy - chip / 2 }, { x1 + 8 * s + chip, cy + chip / 2 },
                imgui.GetColorU32({ a[1] / 255, a[2] / 255, a[3] / 255, 1 }), 2);
        end);
    end
    imgui.Dummy({ 1, 4 * s });
end

local function page_theme()
    section('THEME');
    theme_buttons();

    section('BACKGROUND');
    check("Use the theme's background", CFG.ui_bg, 'use_theme', 'Each theme has its own dark background (Midnight is deep navy). Off: pick your own color below. The clocks keep their own background (Clock > Look).');
    if not CFG.ui_bg.use_theme or searching() then
        sub(function() color('Background color', CFG.ui_bg, 'color', 'The background of the info window.', true); end);
    end
    slider_f('Opacity', CFG.ui_bg, 'alpha', 10, 100, '%.0f%%', 'How see-through the info window is (unless it has its own opacity on its page).', { mul = 100 });

    section('MOUSE POINTER');
    local pt = CFG.pointer;
    check('Mouse pointer over IzClock windows', pt, 'enabled', 'FFXI hides the Windows pointer over addon windows; this draws one (same as MogSuite).');
    if pt.enabled or searching() then
        sub(function()
            slider_f('Pointer size', pt, 'size', 0.8, 3.0, '%.1f');
            color('Pointer color', pt, 'color');
        end);
    end
end

local function page_fonts()
    uifont.settings_page(CFG.ui_font, {
        header = function(title) ui.section(title); end,
        label = function(text_value, help_text) ui.label(text_value, help_text); end,
        dirty = function() D(); end,
        want = function(text_value, help_text) return ui.want(text_value, help_text); end,
        ctrl_w = ui.SLIDER_W * sc(),
        accent = theme.UI_ACCENT_TEXT,
        muted = theme.UI_MUTED,
    });
    ui.info('This is the font of the settings, hover and info windows. The clocks keep their own text (Clock > Look).');
end

-- ============================================================================
-- ALERTS / HELP
-- ============================================================================

local function page_alerts()
    local a = CFG.alert;
    section('DAY CHANGE');
    check('Alert me when the day changes', a, 'enabled');
    if a.enabled or searching() then
        sub(function()
            slider_i('When', a, 'minutes', 0, 30, a.minutes == 0 and 'as it changes' or '%d min before', 'How many minutes before the new day starts. 0 = the moment it starts.');
            check('Message in the chat log', a, 'chat');
            check('Flash the clock in the day\'s color', a, 'flash');
            if a.flash or searching() then sub(function() slider_i('Flash for', a, 'flash_secs', 3, 60, '%d s'); end); end
        end);
        section('WHICH DAYS');
        if ui.block('Which days firesday earthsday watersday windsday iceday lightningday lightsday darksday alert') then
            imgui.TextColored(theme.UI_MUTED, 'Only alert for these days (the day that is starting).');
            for i = 0, 7 do
                if i % 4 ~= 0 then imgui.SameLine(8 * sc() + 120 * sc() * (i % 4)); end
                local v = { a.days[i + 1] ~= false };
                imgui.PushStyleColor(ImGuiCol_Text, CFG.day_colors[i + 1] or vana.DAY_COLORS[i]);
                if imgui.Checkbox(vana.DAYS[i] .. '##icad' .. i, v) then a.days[i + 1] = v[1]; D(); end
                imgui.PopStyleColor(1);
            end
            imgui.Spacing();
            if imgui.SmallButton('All##ic_ad_all') then for i = 1, 8 do a.days[i] = true; end D(); end
            imgui.SameLine();
            if imgui.SmallButton('None##ic_ad_none') then for i = 1, 8 do a.days[i] = false; end D(); end
            imgui.Spacing();
        end
        if ui.button('Test', 'ic_testalert', 'Shows the alert now, for the next day.') then config.ctx.test_alert(); end
    end
end

local function page_commands()
    section('COMMANDS');
    local rows = {
        { '/ic  or  /izclock', 'Show / hide the clock(s)' },
        { '/ic config', 'This window (also /icconfig, or right-click the clock)' },
        { '/ic info', 'The info window (or click the clock)' },
        { '/ic second', 'Show / hide the second clock' },
        { '/ic lock', 'Lock / unlock the clocks\' positions' },
        { '/ic reset', 'Move the clocks back to the top-left corner' },
        { '/ic help', 'List the commands in the chat log' },
    };
    for _, r in ipairs(rows) do
        if want(r[1], r[2]) then
            imgui.TextColored(theme.UI_ACCENT_TEXT, r[1]);
            imgui.SameLine(ui.LABEL_W * sc());
            imgui.TextColored(theme.UI_TEXT, r[2]);
        end
    end
    section('ABOUT');
    ui.value('Version', tostring(addon.version));
    ui.info('IzClock by Izumi. Written for HorizonXI. Vana\'diel time is calculated from your computer\'s clock, so it shows right away; a wrong system clock means a wrong Vana\'diel time.');
end

local GROUPS = {
    { label = 'CLOCK', pages = {
        { key = 'clock', label = 'Clock', desc = 'What the clock shows, in which order, and how it is laid out. Changes show on the clock right away.', draw = page_clock },
        { key = 'format', label = 'Format', desc = 'How times, the countdown and the moon are written.', draw = page_format },
        { key = 'look', label = 'Look', desc = 'Size, colors, background and border of the clock.', draw = page_look },
    } },
    { label = 'WINDOWS', pages = {
        { key = 'window', label = 'Clock windows', desc = 'Where the clocks sit and when they hide, and the second clock.', draw = page_clock_windows },
        { key = 'hover', label = 'Hover window', desc = 'The window that opens while the mouse is over the clock.', draw = page_hover },
        { key = 'info', label = 'Info window', desc = 'Click the clock (without dragging) for the info window, which always shows everything.', draw = page_info },
        { key = 'settings', label = 'Settings window', desc = 'This window: its size and its own opacity.', draw = page_settings_window },
    } },
    { label = 'LOOK', pages = {
        { key = 'theme', label = 'Theme & colors', desc = 'The theme, the background of the info window, and the mouse pointer.', draw = page_theme },
        { key = 'fonts', label = 'Fonts & Tooltips', desc = 'The font of IzClock\'s windows (not the clocks), and how tooltips look.', draw = page_fonts },
    } },
    { label = 'ALERTS', pages = {
        { key = 'alerts', label = 'Day change', desc = 'A heads-up when the elemental day changes.', draw = page_alerts },
    } },
    { label = 'HELP', pages = {
        { key = 'commands', label = 'Commands', desc = 'Type these in the chat line.', draw = page_commands },
    } },
};

local UI_CTX = {
    id = 'ic',
    title = 'IzClock',
    groups = GROUPS,
    page = function() return CFG.config_page or 'clock'; end,
    set_page = function(key) CFG.config_page = key; config.bufs = {}; D(true); end,
    dirty = function() D(); end,
    themes = {
        order = theme.ORDER,
        list = theme.THEMES,
        current = function() return theme.key(CFG.config_theme); end,
        set = function(key) CFG.config_theme = key; D(); end,
    },
};

function config.draw(cfg, ctx)
    if not config.open[1] then return; end
    CFG, D, config.ctx = cfg, ctx.dirty, ctx;
    V = (config.edit == 'second' and cfg.second.enabled) and cfg.second or cfg;
    local s = tonumber(cfg.ui_scale) or 1;
    ui.scale = s;
    local win = cfg.config_win;

    -- Opens where it was left, at the size it was left (resize from the corner).
    if not config.placed then
        local x, y = tonumber(win.x) or -1, tonumber(win.y) or -1;
        if x < 0 or y < 0 then x, y = (tonumber(cfg.x) or 50) + 20, (tonumber(cfg.y) or 50) + 60; end
        local w, h = tonumber(win.w) or -1, tonumber(win.h) or -1;
        if w <= 0 or h <= 0 then
            w, h = 820 * s, 600 * s;
            pcall(function()
                local dh = tonumber(imgui.GetIO().DisplaySize.y);
                if dh ~= nil and dh > 300 then h = math.min(h, dh - 120); end
            end);
        end
        imgui.SetNextWindowPos({ x, y });
        imgui.SetNextWindowSize({ w, h });
        config.placed = true;
    end
    imgui.SetNextWindowSizeConstraints({ 680 * s, 420 * s }, { 4000, 4000 });
    theme.push(theme.background(tonumber(cfg.look.config.alpha) or 0.97), s, { border = true });
    uifont.push(s);
    local flags = bit.bor(ImGuiWindowFlags_NoCollapse or 0, ImGuiWindowFlags_NoSavedSettings or 0,
        ImGuiWindowFlags_NoScrollbar or 0, ImGuiWindowFlags_NoScrollWithMouse or 0, ImGuiWindowFlags_NoNav or 0);
    if imgui.Begin('IzClock Settings##izclock_config', config.open, flags) then
        local ok, err = pcall(ui.body, UI_CTX);
        if not ok then imgui.TextColored(theme.UI_DANGER, tostring(err)); end

        -- Remember where it was moved to and how big it is.
        if not imgui.IsMouseDown(0) then
            local x, y = imgui.GetWindowPos();
            local w, hh = imgui.GetWindowSize();
            x, y, w, hh = tonumber(x), tonumber(y), tonumber(w), tonumber(hh);
            if x ~= nil and y ~= nil and w ~= nil and hh ~= nil then
                x, y, w, hh = math.floor(x), math.floor(y), math.floor(w), math.floor(hh);
                if x ~= win.x or y ~= win.y or w ~= win.w or hh ~= win.h then
                    win.x, win.y, win.w, win.h = x, y, w, hh;
                    ctx.dirty(true);
                end
            end
        end
    end
    imgui.End();
    uifont.pop();
    theme.pop();
end

return config;
