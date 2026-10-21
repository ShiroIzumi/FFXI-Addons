--[[
    IzClock - ui/config.lua

    The settings window (/ic config, /icconfig, or right-click the clock).
    Same layout as Triage's: a sidebar of pages, each starting with what it's
    for; options that depend on another sit indented under it.

      Clock         what shows and in which order, layout
      Format        time formats, countdown, moon, separator
      Look          size, text effect, colors, background, border, width
      Hover & info  the hover window's sections and ships; the info window
      Alerts        the day-change alert
      Window        second clock, position, lock, cutscenes, this window's look
      Commands      the slash commands

    Clock, Format and Look edit one clock at a time; with the second clock
    on, a switch at the top picks which.
]]

require('common');
local imgui = require('imgui');
local theme = require('core.theme');
local cursor = require('core.cursor');
local vana = require('core.vana');
local schedule = require('core.schedule');

local config = {
    open = { false },
    page = 'clock',
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

local LABEL_W, SLIDER_W = 150, 190;

local function sc() return tonumber(CFG.ui_scale) or 1; end

local function sub(fn)
    imgui.Indent(18 * sc());
    fn();
    imgui.Unindent(18 * sc());
end

local function page(title, desc)
    imgui.TextColored(theme.UI_ACCENT_TEXT, title);
    if desc then
        imgui.PushTextWrapPos(0);
        imgui.TextColored(theme.UI_MUTED, desc);
        imgui.PopTextWrapPos();
    end
    imgui.PushStyleColor(ImGuiCol_Separator, theme.accent(0.45));
    imgui.Separator();
    imgui.PopStyleColor(1);
end

local function section(title) theme.section_header(title); end

local function label(text, tip)
    theme.align_label();
    imgui.TextColored(theme.UI_MUTED, text);
    if tip then theme.tip(tip); end
    imgui.SameLine();
    imgui.SetCursorPosX(LABEL_W * sc());
end

local function check(text, tbl, key, tip)
    local v = { tbl[key] == true };
    if imgui.Checkbox(text .. '##icc_' .. tostring(tbl) .. key, v) then tbl[key] = v[1]; D(); end
    if tip then theme.help_marker(tip); end
end

local function slider_i(text, tbl, key, lo, hi, fmt, tip)
    label(text, tip);
    imgui.PushItemWidth(SLIDER_W * sc());
    local v = { math.floor(tonumber(tbl[key]) or lo) };
    if imgui.SliderInt('##ici_' .. tostring(tbl) .. key, v, lo, hi, fmt or '%d') then tbl[key] = v[1]; D(); end
    imgui.PopItemWidth();
end

local function slider_f(text, tbl, key, lo, hi, fmt, tip)
    label(text, tip);
    imgui.PushItemWidth(SLIDER_W * sc());
    local v = { tonumber(tbl[key]) or lo };
    if imgui.SliderFloat('##icf_' .. tostring(tbl) .. key, v, lo, hi, fmt or '%.2f') then tbl[key] = v[1]; D(); end
    imgui.PopItemWidth();
end

local function color(text, tbl, key, tip)
    label(text, tip);
    local c = tbl[key] or { 1, 1, 1, 1 };
    local v = { c[1], c[2], c[3], c[4] or 1 };
    if imgui.ColorEdit4('##iccol_' .. tostring(tbl) .. key, v, ImGuiColorEditFlags_NoInputs or 0) then
        tbl[key] = { v[1], v[2], v[3], v[4] };
        D();
    end
end

local function choice(text, tbl, key, options, tip)
    label(text, tip);
    local new = theme.choice('icch_' .. tostring(tbl) .. key, tbl[key], options);
    if new ~= tbl[key] then tbl[key] = new; D(); end
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
    label('Editing');
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

-- ============================================================================
-- Pages
-- ============================================================================

local function page_clock()
    local s = sc();
    page('Clock', 'What the clock shows, in which order, and how it is laid out. Changes show on the clock right away.');
    pick_clock();

    section('LAYOUT');
    choice('Layout', V, 'layout', {
        { key = 'line', label = 'One line' },
        { key = 'stack', label = 'Stacked', tip = 'One piece per line, labels in a column.' },
        { key = 'full', label = 'Full', tip = 'Stacked, plus the rest of the week\'s days.' },
    });

    section('PIECES');
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
        imgui.SameLine(LABEL_W * s + 40 * s);
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
    check('Show the labels', V, 'show_labels', 'Off: values only, e.g. "05:33 | Watersday > Windsday | 44m 15s".');
    if imgui.Button('Default pieces##ic_defsegs') then
        V.segments = config.ctx.view_defaults(config.edit).segments;
        config.bufs = {};
        D();
    end
    theme.tip('Back to this clock\'s starting pieces and labels.');

    section('ELEMENTAL DAY');
    check('Also show the next day ("Watersday > Windsday")', V, 'day_next');
    check('Element tags ("[Wa] Watersday")', V, 'element_tags');
    imgui.TextColored(theme.UI_MUTED, 'The hover window and the info window are on the Hover & info page.');
end

local function page_format()
    page('Format', 'How times, the countdown and the moon are written.');
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
    label('Between pieces', 'Text between the pieces on the one-line layout, e.g. |  /  •  -  (empty = just space).');
    local changed, val = text_input('sep_' .. config.edit, V.separator, 60 * sc(), 8);
    if changed then V.separator = val; D(); end
end

local function page_look()
    page('Look', 'Size, colors, background and border of the clock.');
    pick_clock();
    section('TEXT');
    slider_f('Size', V, 'font_scale', 0.6, 3.0, '%.2fx');
    choice('Effect', V, 'text_effect', theme.EFFECTS, 'A shadow or outline keeps the text readable over bright scenery, especially with a see-through background.');

    section('COLORS');
    color('Labels', V, 'label_color');
    color('Values', V, 'value_color', 'Local time, Japan time, countdown and moon.');
    color('Vana\'diel time', V, 'vana_color');
    color('Separators', V, 'sep_color');
    label('Days');
    for i = 0, 7 do
        if i == 4 then imgui.SetCursorPosX(LABEL_W * sc()); end
        local c = V.day_colors[i + 1] or vana.DAY_COLORS[i];
        local v = { c[1], c[2], c[3], c[4] or 1 };
        if imgui.ColorEdit4('##icday' .. i, v, ImGuiColorEditFlags_NoInputs or 0) then
            V.day_colors[i + 1] = { v[1], v[2], v[3], v[4] };
            D();
        end
        theme.tip(vana.DAYS[i]);
        if i ~= 3 and i ~= 7 then imgui.SameLine(); end
    end
    imgui.SetCursorPosX(LABEL_W * sc());
    if imgui.Button('Default colors##ic_defcol') then
        local d = config.ctx.view_defaults(config.edit);
        V.label_color = { unpack(d.label_color) };
        V.value_color = { unpack(d.value_color) };
        V.vana_color = { unpack(d.vana_color) };
        V.sep_color = { unpack(d.sep_color) };
        V.day_colors = config.ctx.day_colors();
        D();
    end

    section('BACKGROUND & BORDER');
    label('Background');
    local b = V.bg or { 0.055, 0.070, 0.095 };
    local bv = { b[1], b[2], b[3] };
    if imgui.ColorEdit3('##ic_bg', bv, ImGuiColorEditFlags_NoInputs or 0) then V.bg = { bv[1], bv[2], bv[3] }; D(); end
    slider_f('Opacity', V, 'bg_alpha', 0.0, 1.0, '%.2f', '0 = see-through (just the text), 1 = solid.');
    check('Border', V, 'border');
    if V.border then sub(function() color('Border color', V, 'border_color'); end); end
    slider_i('Rounding', V, 'rounding', 0, 12, '%d px');

    section('SPACING & WIDTH');
    slider_i('Padding left / right', V, 'pad_x', 0, 30, '%d px');
    slider_i('Padding top / bottom', V, 'pad_y', 0, 20, '%d px');
    slider_i('Space around separators', V, 'gap', 0, 30, '%d px');
    if V.layout ~= 'line' then slider_i('Space between lines', V, 'line_gap', 0, 16, '%d px'); end
    choice('Width', V, 'width_mode', {
        { key = 'auto', label = 'Fit the text' },
        { key = 'fixed', label = 'Fixed', tip = 'A set width; the text can be aligned inside it.' },
    });
    if V.width_mode == 'fixed' then
        sub(function()
            slider_i('Width', V, 'width', 100, 1600, '%d px');
            choice('Align', V, 'align', {
                { key = 'left', label = 'Left' }, { key = 'center', label = 'Center' }, { key = 'right', label = 'Right' },
            });
        end);
    end
end

local ROUTE_TIP = 'Departure times are the game\'s ship schedules (measured from retail, as used by LandSandBoat, the server HorizonXI is built on).';

local function page_hover()
    local h = CFG.hover;
    page('Hover & info', 'The hover window opens while the mouse is over the clock. Click the clock (without dragging) for the info window, which always shows everything.');

    section('HOVER WINDOW');
    choice('Opens over', h, 'area', {
        { key = 'clock', label = 'The whole clock' },
        { key = 'day', label = 'The day only' },
        { key = 'off', label = 'Off' },
    });
    if h.area ~= 'off' then
        sub(function()
            slider_f('Text size', h, 'scale', 0.75, 2.0, '%.2fx', 'Makes everything in the hover window bigger or smaller.');
            check('This week', h, 'week', 'The coming days, when each starts, and the local time it starts at.');
            check('Moon', h, 'moon', 'Phase, %, waxing or waning, and when the next Full and New Moon start.');
            check('Crafting', h, 'craft', 'The crystal element favored today and the one it is strong against, plus which guilds are on holiday. The day bonus is traditional FFXI crafting lore; LandSandBoat (HorizonXI\'s base) does not apply one, so treat it as a guide.');
            check('Guild hours', h, 'guilds', 'Each crafting guild: open or closed, and when that changes. Hours and holidays are LandSandBoat\'s.');
            check('Ships & airships', h, 'travel', ROUTE_TIP);
        end);
        if h.travel then
            section('SHIPS IN THE HOVER WINDOW');
            imgui.TextColored(theme.UI_MUTED, 'The info window lists all of them.');
            for _, grp in ipairs(schedule.GROUPS) do
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

    section('INFO WINDOW');
    imgui.PushTextWrapPos(0);
    imgui.TextColored(theme.UI_MUTED, 'Now, the week, the moon, crafting, every guild and every ship, in three columns. It uses the main clock\'s colors and 12/24h setting, and this settings window\'s theme. It opens where you last left it.');
    imgui.PopTextWrapPos();
    slider_f('Text size', CFG, 'info_scale', 0.75, 2.0, '%.2fx', 'The info window sizes itself to fit; this makes everything in it bigger or smaller.');
    if imgui.Button('Open the info window##ic_openinfo') then config.ctx.info_toggle(); end
end

local function page_alerts()
    local a = CFG.alert;
    page('Alerts', 'A heads-up when the elemental day changes.');
    section('DAY CHANGE');
    check('Alert me when the day changes', a, 'enabled');
    if a.enabled then
        sub(function()
            slider_i('When', a, 'minutes', 0, 30, a.minutes == 0 and 'as it changes' or '%d min before', 'How many minutes before the new day starts. 0 = the moment it starts.');
            check('Message in the chat log', a, 'chat');
            check('Flash the clock in the day\'s color', a, 'flash');
            if a.flash then sub(function() slider_i('Flash for', a, 'flash_secs', 3, 60, '%d s'); end); end
        end);
        section('WHICH DAYS');
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
        if imgui.Button('Test##ic_testalert') then config.ctx.test_alert(); end
        theme.tip('Shows the alert now, for the next day.');
    end
end

local function page_window()
    page('Window', 'Where the clocks sit and when they hide, the second clock, plus this settings window.');
    section('MAIN CLOCK');
    check('Lock position', CFG, 'lock', 'Stops the clock from being dragged (also /ic lock, which locks both).');
    label('Position');
    imgui.TextColored(theme.UI_TEXT, ('%d, %d'):format(tonumber(CFG.x) or 0, tonumber(CFG.y) or 0));
    imgui.SameLine();
    if imgui.SmallButton('Reset##ic_resetpos') then config.ctx.reset_position('main'); end
    theme.tip('Moves the clock back to the top-left corner (/ic reset moves both).');

    section('SECOND CLOCK');
    local sc2 = CFG.second;
    check('Show a second clock', sc2, 'enabled', 'Its own pieces, layout and look; pick it at the top of the Clock, Format and Look pages (also /ic second). For example a one-line bar plus a stacked panel.');
    if sc2.enabled then
        sub(function()
            check('Lock position', sc2, 'lock');
            label('Position');
            imgui.TextColored(theme.UI_TEXT, ('%d, %d'):format(tonumber(sc2.x) or 0, tonumber(sc2.y) or 0));
            imgui.SameLine();
            if imgui.SmallButton('Reset##ic_resetpos2') then config.ctx.reset_position('second'); end
            if imgui.SmallButton('Edit the second clock##ic_edit2') then config.edit = 'second'; config.page = 'clock'; config.bufs = {}; end
        end);
    end

    section('BOTH CLOCKS');
    check('Hide during cutscenes', CFG, 'hide_events', 'Also while the game\'s interface is hidden. The clocks are always hidden before you log in.');

    section('THIS SETTINGS WINDOW');
    label('Theme');
    local opts = {};
    for _, k in ipairs(theme.ORDER) do opts[#opts + 1] = { key = k, label = theme.THEMES[k].label }; end
    local new = theme.choice('ic_theme', theme.key(CFG.config_theme), opts);
    if new ~= theme.key(CFG.config_theme) then CFG.config_theme = new; D(); end
    label('Text size', 'Drag the window\'s bottom-right corner to change the window itself.');
    for i, p in ipairs({ 1.00, 1.25, 1.50, 1.75 }) do
        if i > 1 then imgui.SameLine(0, 4); end
        if theme.toggle_button(('%d%%'):format(p * 100), 'icsc' .. i, math.abs((CFG.ui_scale or 1) - p) < 0.01) then
            CFG.ui_scale = p;
            D();
        end
    end
    slider_f(' ', CFG, 'ui_scale', 0.75, 2.0, '%.2fx');
    label('Window');
    if imgui.SmallButton('Reset size and position##ic_cfgreset') then
        CFG.config_win = { x = -1, y = -1, w = -1, h = -1 };
        config.placed = false;
        D();
    end

    section('INFO WINDOW');
    slider_f('Text size', CFG, 'info_scale', 0.75, 2.0, '%.2fx', 'The info window sizes itself to fit; this makes everything in it bigger or smaller.');
    local pt = CFG.pointer;
    check('Mouse pointer over IzClock windows', pt, 'enabled', 'FFXI hides the Windows pointer over addon windows; this draws one (same as Triage / MogSuite).');
    if pt.enabled then
        sub(function()
            slider_f('Pointer size', pt, 'size', 0.8, 3.0, '%.1f');
            color('Pointer color', pt, 'color');
        end);
    end
end

local function page_commands()
    page('Commands', 'Type these in the chat line.');
    local rows = {
        { '/ic  or  /izclock', 'Show / hide the clock(s)' },
        { '/ic config', 'This window (also /icconfig, or right-click the clock)' },
        { '/ic info', 'The info window (or click the clock)' },
        { '/ic second', 'Show / hide the second clock' },
        { '/ic lock', 'Lock / unlock the clocks\' positions' },
        { '/ic reset', 'Move the clocks back to the top-left corner' },
        { '/ic help', 'List the commands in the chat log' },
    };
    imgui.Spacing();
    for _, r in ipairs(rows) do
        imgui.TextColored(theme.UI_ACCENT_TEXT, r[1]);
        imgui.SameLine(LABEL_W * sc());
        imgui.TextColored(theme.UI_TEXT, r[2]);
    end
    section('ABOUT');
    imgui.PushTextWrapPos(0);
    imgui.TextColored(theme.UI_MUTED, 'IzClock ' .. tostring(addon.version) .. ' by Izumi. Vana\'diel time is calculated from your computer\'s clock, so it shows right away; a wrong system clock means a wrong Vana\'diel time.');
    imgui.PopTextWrapPos();
end

local PAGES = {
    { key = 'clock', label = 'Clock', draw = page_clock },
    { key = 'format', label = 'Format', draw = page_format },
    { key = 'look', label = 'Look', draw = page_look },
    { key = 'hover', label = 'Hover & info', draw = page_hover },
    { key = 'alerts', label = 'Alerts', draw = page_alerts },
    { key = 'window', label = 'Window', draw = page_window },
    { key = 'commands', label = 'Commands', draw = page_commands },
};

-- BeginChild differs between Ashita builds (child flags or a border bool).
local child_sig = nil;
local function begin_child(id, size)
    if child_sig == 1 then return imgui.BeginChild(id, size, ImGuiChildFlags_None or 0); end
    if child_sig == 2 then return imgui.BeginChild(id, size, false); end
    if child_sig == 3 then return imgui.BeginChild(id, size); end
    local ok, r = pcall(imgui.BeginChild, id, size, ImGuiChildFlags_None or 0);
    if ok then child_sig = 1; return r; end
    ok, r = pcall(imgui.BeginChild, id, size, false);
    if ok then child_sig = 2; return r; end
    child_sig = 3;
    return imgui.BeginChild(id, size);
end

local function sidebar(w, h)
    local s = sc();
    begin_child('##ic_nav', { w, h });
    pcall(function()
        local x, y = imgui.GetWindowPos();
        imgui.GetWindowDrawList():AddRectFilled({ x, y }, { x + w, y + h }, imgui.GetColorU32(theme.with_alpha(theme.UI_CONTROL, 0.55)), 6 * s);
    end);
    imgui.Dummy({ 1, 6 * s });
    for _, pg in ipairs(PAGES) do
        local on = config.page == pg.key;
        imgui.SetCursorPosX(6 * s);
        imgui.PushStyleColor(ImGuiCol_Text, on and theme.UI_ACCENT_TEXT or theme.UI_TEXT);
        imgui.PushStyleColor(ImGuiCol_Header, theme.accent(0.22));
        imgui.PushStyleColor(ImGuiCol_HeaderHovered, theme.accent(0.16));
        if imgui.Selectable('   ' .. pg.label .. '##ic_nav_' .. pg.key, on, 0, { w - 12 * s, 0 }) then config.page = pg.key; end
        imgui.PopStyleColor(3);
        if on then
            pcall(function()
                local x1, y1 = imgui.GetItemRectMin();
                local _, y2 = imgui.GetItemRectMax();
                imgui.GetWindowDrawList():AddRectFilled({ x1, y1 + 2 * s }, { x1 + 3 * s, y2 - 2 * s }, imgui.GetColorU32(theme.UI_ACCENT), 1);
            end);
        end
    end
    imgui.EndChild();
end

-- GetContentRegionAvail returns two numbers or a table depending on the build.
local function avail()
    local a, b = imgui.GetContentRegionAvail();
    if type(a) == 'table' then return tonumber(a[1] or a.x) or 0, tonumber(a[2] or a.y) or 0; end
    return tonumber(a) or 0, tonumber(b) or 0;
end

function config.draw(cfg, ctx)
    if not config.open[1] then return; end
    CFG, D, config.ctx = cfg, ctx.dirty, ctx;
    V = (config.edit == 'second' and cfg.second.enabled) and cfg.second or cfg;
    local s = sc();
    local win = cfg.config_win;

    -- Opens where it was left, at the size it was left (resize from the corner).
    if not config.placed then
        local x, y = tonumber(win.x) or -1, tonumber(win.y) or -1;
        if x < 0 or y < 0 then x, y = (tonumber(cfg.x) or 50) + 20, (tonumber(cfg.y) or 50) + 60; end
        local w, h = tonumber(win.w) or -1, tonumber(win.h) or -1;
        if w <= 0 or h <= 0 then
            w, h = 640 * s, 540 * s;
            pcall(function()
                local dh = tonumber(imgui.GetIO().DisplaySize.y);
                if dh ~= nil and dh > 300 then h = math.min(h, dh - 120); end
            end);
        end
        imgui.SetNextWindowPos({ x, y });
        imgui.SetNextWindowSize({ w, h });
        config.placed = true;
    end
    theme.push(nil, s, { border = true });
    imgui.PushStyleVar(ImGuiStyleVar_WindowMinSize, { 360 * s, 240 * s });
    imgui.PushFont(nil, imgui.GetFontSize() * s);
    local flags = bit.bor(ImGuiWindowFlags_NoCollapse or 0, ImGuiWindowFlags_NoSavedSettings or 0,
        ImGuiWindowFlags_NoScrollbar or 0, ImGuiWindowFlags_NoScrollWithMouse or 0);
    if imgui.Begin('IzClock Settings##izclock_config', config.open, flags) then
        local aw, ah = avail();
        local nav_w = 130 * s;
        local gap = 10 * s;
        local h = math.max(60, ah);
        sidebar(nav_w, h);
        imgui.SameLine(0, gap);
        begin_child('##ic_body', { math.max(60, aw - nav_w - gap), h });
        for _, pg in ipairs(PAGES) do
            if pg.key == config.page then pg.draw(); end
        end
        imgui.Dummy({ 1, 6 * s });
        imgui.EndChild();

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
    imgui.PopFont();
    imgui.PopStyleVar(1);
    theme.pop();
end

return config;
