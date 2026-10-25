--[[
    WhatsMyDamage - ui/config.lua

    The settings window (/wmd config, the gear icon, or right-click a
    meter). 1.1.0: built on cfgui.lua, the same settings kit as MobHunt,
    IzClock and ScrollingCombatLog (MogSuite's layout): a search box at the
    top finds any setting by name or help text, "Saved per character" and
    the theme swatches on the same line, and a sidebar of pages:

      GENERAL   General
      WINDOWS   Meters, Details & hover, Report window, New party,
                Settings window
      LOOK      Theme & colors, Bars, Text, Job colors, Fonts & Tooltips
      CHAT      Report
      HELP      Commands

    Every page starts with "WhatsMyDamage  /  Page" and one line saying what
    it is for. Options that only matter when another one is on sit indented
    under it. Changes are saved shortly after (per character).
]]

require('common');
local imgui = require('imgui');
local ui = require('cfgui');
local uifont = require('uifont');
local theme = require('core.theme');
local data = require('core.data');
local fonts = require('core.fonts');
local icons = require('core.icons');
local tracker = require('core.tracker');
local styles = require('ui.styles');
local report = require('ui.report');
local newparty = require('ui.newparty');

local config = {
    open = { false },
    placed = false,
    message = nil,
    message_time = 0,
    armed = {},
};

local CFG, CTX = nil, nil;

local function dirty() CTX.dirty(); end

local function say(text)
    config.message = text;
    config.message_time = os.clock();
end

-- ============================================================================
-- Kit adapter and small wrappers (same argument order as before)
-- ============================================================================

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
local function slider_f(text, tbl, key, lo, hi, fmt, tip, opts) return ui.slider_f(text, tbl, key, lo, hi, fmt, tip, opts); end
local function slider_i(text, tbl, key, lo, hi, fmt, tip) return ui.slider_i(text, tbl, key, lo, hi, fmt, tip); end
local function choice(text, tbl, key, options, tip) return ui.choice(text, tbl, key, options, tip); end
local function action(text, id, tip) return ui.button(text, id, tip); end

-- Colors are edited in place (other code keeps references to the tables).
local function color(text, tbl, key, tip, no_alpha)
    if tbl[key] == nil then tbl[key] = { 1, 1, 1, 1 }; end
    if tbl[key][4] == nil then tbl[key][4] = 1; end
    return ui.color(text, tbl[key], tip, not no_alpha);
end

-- ============================================================================
-- Option lists
-- ============================================================================

local MODES = {};
for _, m in ipairs(data.MODES) do MODES[#MODES + 1] = { key = m.key, label = m.short }; end
local SIZES = {
    { key = 'grow', label = 'Grow', tip = 'The window gets taller as more players show up.' },
    { key = 'fixed', label = 'Fixed', tip = 'Always the same number of rows; scroll with the mouse wheel.' },
};
local GROWS = {
    { key = 'down', label = 'Down', tip = 'The top edge stays put and new rows are added below.' },
    { key = 'up', label = 'Up', tip = 'The bottom edge stays put and new rows push the top up (good at the bottom of the screen).' },
};
local COLOR_BY = {
    { key = 'job', label = 'Job color' },
    { key = 'single', label = 'One color' },
};
local NAME_COLOR = {
    { key = 'white', label = 'Font color' },
    { key = 'job', label = 'Job color' },
};
local NUMBERS = {
    { key = 'full', label = '12,345' },
    { key = 'short', label = '12.3K' },
};
local ICON_SETS = {
    { key = 'Classic', label = 'Classic' },
    { key = 'FFXI', label = 'FFXI' },
    { key = 'FFXIV-1', label = 'FFXIV' },
    { key = 'badge', label = 'Letters', tip = 'A small colored badge with the job\'s letters (no XIUI needed).' },
};
local NEW_PARTY = {
    { key = 'ask', label = 'Ask', tip = 'Ask whether to reset the meters.' },
    { key = 'reset', label = 'Reset', tip = 'Reset the meters without asking.' },
    { key = 'keep', label = 'Keep', tip = 'Keep counting; never ask.' },
};

-- ============================================================================
-- Shared "look" blocks for one window: size and its own opacity.
-- ============================================================================

local function own_opacity(look, what)
    check('Own opacity', look, 'own_alpha', 'Off: the ' .. what .. ' uses the background opacity from Look > Theme & colors. On: set it here.');
    if look.own_alpha or searching() then
        sub(function()
            slider_f('Opacity##' .. what, look, 'alpha', 0, 100, '%.0f%%', 'How see-through the background of the ' .. what .. ' is. Text stays solid.', { mul = 100 });
        end);
    end
end

-- Size presets for a window whose size is kept as a text size in px
-- (14 px = 100%).
local function px_size_presets(text, tbl, key, tip)
    local proxy = { v = (tonumber(tbl[key]) or 14) / 14 };
    if ui.scale_presets(text, proxy, 'v', tip) then
        tbl[key] = math.max(10, math.min(28, math.floor(proxy.v * 14 + 0.5)));
    end
end

-- ============================================================================
-- Pages
-- ============================================================================

local function page_general()
    section('TRACKING');
    check('Count the alliance too', CFG, 'alliance', 'Off: only your party (and you when solo). On: all three parties of the alliance.');
    check('Pets combined with their owner', CFG, 'combine_pets', 'On: a pet\'s numbers are added to its owner\'s bar (the hover and details windows still list the pet on its own). Off: pets get their own bars.');
    check('Clear the data when you zone', CFG, 'reset_on_zone', 'Starts fresh every time you change area.');
    choice('When you join a new party', CFG, 'new_party', NEW_PARTY,
        'Ask: a small window asks whether to reset the meters (only when they have numbers in them). A new party = you were on your own and now have party members, or you moved to a different party. Someone joining your current party does not count.');
    if action('Show the question', 'wmd_np_test', 'Shows the "reset the meters?" window so you can see it.') then newparty.test(); end

    section('MY ROW');
    check('Always show my row', CFG, 'me_always', 'When there are more players than rows, your row takes the last line so you can always see yourself.');
    check('Outline my row', CFG.bars, 'me_highlight', 'A thin accent-colored frame around your own bar.');

    section('SHOWING');
    check('Hide during cutscenes', CFG, 'hide_events', 'Hides the meters while a cutscene plays or the game interface is hidden.');
    check('Lock windows', CFG, 'lock', 'Stops moving, snapping and resizing of the meters.');

    section('TEST MODE');
    if want('Test mode', 'A made-up party that keeps fighting, to try out the look.') then
        label('Test mode', 'A made-up party that keeps fighting, to try out the look.');
        if theme.toggle_button(tracker.test and 'On - click to stop' or 'Off - click to start', 'wmd_test', tracker.test) then
            tracker.set_test(not tracker.test);
            say(tracker.test and 'Test mode on: made-up numbers.' or 'Test mode off: your real numbers are back.');
        end
        imgui.SameLine();
        imgui.TextColored(theme.UI_MUTED, '/wmd test');
    end

    section('DATA');
    if ui.danger('Clear all data', 'wmd_clear', config.armed, 'Same as the Reset icon on a meter. Click twice.') then
        tracker.reset();
        say('All data cleared.');
    end
end

local function window_block(i)
    local w = CFG.windows[i];
    section(('WINDOW %d'):format(i));
    if i == 1 then
        check('Show window 1', w, 'enabled', 'The first meter.');
    else
        check(('Show window %d'):format(i), w, 'enabled', 'Turn on another meter; it can show any of the three modes.');
    end
    if not w.enabled and not searching() then return; end
    sub(function()
        choice('Shows', w, 'mode', MODES, 'What this window counts. The bars icon in its header changes it too.');
        choice('Size', w, 'size', SIZES, 'Grow: as tall as the list. Fixed: a set number of rows with mouse-wheel scrolling.');
        if w.size == 'fixed' or searching() then
            slider_i('Rows', w, 'rows', 1, 25, '%d', 'How many rows a fixed window shows.');
        end
        if w.size ~= 'fixed' or searching() then
            choice('Grow direction', w, 'grow', GROWS, 'Which way the window grows when players are added.');
            slider_i('Most rows', w, 'max_rows', 0, 25, '%d', 'The window stops growing after this many rows (0 = no limit).');
        end
        slider_i('Width', w, 'w', 140, 800, '%d px', 'Also: drag the bottom-right corner of the window.');
        if (tonumber(w.snap_to) or 0) > 0 and want('Unsnap', 'Pulls this window out of its group (Ctrl + drag does this too).') then
            imgui.SetCursorPosX(ui.LABEL_W * sc());
            imgui.TextColored(theme.UI_GOOD, ('Snapped %s window %d'):format(w.snap_side == 'below' and 'under' or (w.snap_side == 'above' and 'over' or ('to the ' .. tostring(w.snap_side) .. ' of')), w.snap_to));
            imgui.SameLine();
            if imgui.SmallButton('Unsnap##wmd_unsnap' .. i) then
                CTX.unsnap(i);
                say(('Window %d unsnapped.'):format(i));
            end
        end
    end);
end

local function page_meters()
    for i = 1, 3 do window_block(i); end

    section('SNAPPING');
    slider_i('Snap distance', CFG, 'snap_distance', 4, 40, '%d px', 'How close a window has to be dropped to another one to snap to it.');
    slider_i('Gap between snapped', CFG, 'snap_gap', 0, 12, '%d px', 'Space between windows that are snapped together.');
    check('Same width when stacked', CFG, 'snap_match', 'Windows snapped above / below each other share one width (resize any of them).');
    if action('Stack all windows', 'wmd_stack', 'Snaps window 2 under 1 and window 3 under 2.') then
        CTX.stack();
        say('Windows stacked under window 1.');
    end
    if not searching() then
        imgui.SameLine();
        if imgui.Button('Unsnap all##wmd_unsnap_all') then
            for i = 1, 3 do CTX.unsnap(i); end
            say('All windows unsnapped.');
        end
        imgui.SameLine();
        if imgui.Button('Reset positions##wmd_resetpos') then
            CTX.reset_positions();
            say('Windows moved back to the default place.');
        end
    end

    section('LOOK');
    ui.scale_presets('Meter size', CFG, 'scale', 'Scales the bars, header, icons and text of the meters.');
    color('Background', CFG, 'bg', 'The meters\' own background color (they don\'t use the theme background).', true);
    slider_f('Background opacity', CFG, 'bg_alpha', 0, 100, '%.0f%%', '0 = see-through.', { mul = 100 });
    check('Border', CFG, 'border');
    if CFG.border or searching() then sub(function() color('Border color', CFG, 'border_color'); end); end
    slider_f('Corner rounding', CFG, 'rounding', 0, 12, '%.0f px');
    slider_f('Padding', CFG, 'padding', 0, 10, '%.0f px', 'Space between the window edge and the bars.');

    section('HEADER');
    check('Show the header', CFG.header, 'show', 'The title bar with the mode name and icons (mode, reset, report, settings). Without it, right-click a meter for settings and use /wmd for the rest.');
    if CFG.header.show or searching() then
        sub(function()
            slider_i('Header height', CFG.header, 'height', 16, 40, '%d px');
            color('Header color', CFG.header, 'bg', nil, true);
            slider_f('Header opacity', CFG.header, 'bg_alpha', 0, 100, '%.0f%%', nil, { mul = 100 });
            check('Accent line under the header', CFG.header, 'accent_line', 'A thin line in the theme color, like Details.');
        end);
    end
end

local function page_details()
    section('DETAILS WINDOW');
    px_size_presets('Size', CFG.detail, 'size', 'Text and spacing of the details window. The - / + on the window change it too.');
    slider_i('Text size', CFG.detail, 'size', 10, 24, '%d px', 'The same setting as Size, in pixels.');
    own_opacity(CFG.look.detail, 'details window');
    if action('Open the details window', 'wmd_open_detail', 'Same as clicking a bar.') then CTX.open_detail(); end

    section('HOVER BREAKDOWN');
    check('Show the breakdown on hover', CFG.tooltip, 'show', 'Hovering a bar shows every source, accuracy, pets and deaths.');
    if CFG.tooltip.show or searching() then
        sub(function()
            px_size_presets('Hover size', CFG.tooltip, 'size', 'Text and spacing of the hover breakdown.');
            slider_i('Hover text size', CFG.tooltip, 'size', 10, 24, '%d px');
        end);
        ui.info('The hover breakdown is a tooltip: its background, border and padding are set on Look > Fonts & Tooltips.');
    end
end

local function page_report_window()
    section('WINDOW');
    ui.scale_presets('Size', CFG.look.report, 'scale', 'Text and spacing of the report window.');
    own_opacity(CFG.look.report, 'report window');
    if want('Open the report window', 'report send') then
        imgui.SetCursorPosX(ui.LABEL_W * sc());
        for _, m in ipairs(data.MODES) do
            if imgui.Button(m.label .. '##wmd_rep_win_' .. m.key) then report.open(m.key); end
            imgui.SameLine();
        end
        imgui.NewLine();
    end
    ui.info('What the report posts is on the Chat > Report page.');
end

local function page_newparty_window()
    section('WINDOW');
    ui.scale_presets('Size', CFG.look.newparty, 'scale', 'Text and spacing of the "reset the meters?" window.');
    own_opacity(CFG.look.newparty, 'new party window');
    if action('Show the question', 'wmd_np_test2', 'Shows the "reset the meters?" window so you can see it.') then newparty.test(); end
    ui.info('When it is asked (Ask, Reset or Keep) is on the General page.');
end

local function page_settings_window()
    section('WINDOW');
    ui.scale_presets('Settings size', CFG, 'config_scale', 'Size of this window.');
    slider_f('Opacity', CFG.look.config, 'alpha', 10, 100, '%.0f%%', 'How see-through this settings window is. It has its own opacity, separate from the other windows.', { mul = 100 });
    if action('Reset size and position', 'wmd_cfg_reset', 'Puts this window back in its starting place and size.') then
        CFG.config_pos = { x = -1, y = -1, w = -1, h = -1 };
        config.placed = false;
        dirty();
    end
end

local function theme_buttons()
    if not want('Theme', 'Colors of the settings, details, report and new party windows (and the accent line on the meters). Forest Rust Bone Copper Gold Garnet Fuchsia Silver Amethyst Emerald Midnight') then return; end
    label('Theme', 'Colors of the settings, details, report and new party windows (and the accent line on the meters).');
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
        if theme.toggle_button(text, 'wmd_th_' .. key, key == current) then
            CFG.config_theme = key;
            dirty();
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
    check("Use the theme's background", CFG.ui_bg, 'use_theme', 'Each theme has its own dark background (Midnight is deep navy). Off: pick your own color below. The meters keep their own background (Windows > Meters).');
    if not CFG.ui_bg.use_theme or searching() then
        sub(function() color('Background color', CFG.ui_bg, 'color', 'The background of the details, report and new party windows.', true); end);
    end
    slider_f('Opacity', CFG.ui_bg, 'alpha', 10, 100, '%.0f%%', 'How see-through the details, report and new party windows are (unless one has its own opacity on its page).', { mul = 100 });

    section('STAT COLORS');
    color('Good', CFG.colors, 'good', 'Kills, accuracy and other good numbers in the hover and details windows.', true);
    color('Bad / deaths', CFG.colors, 'bad', 'Deaths and other bad numbers.', true);
    color('Warning', CFG.colors, 'warn', 'Magic bursts, test mode and other highlights.', true);
    color('Muted text', CFG.colors, 'muted', 'Labels, times and other secondary text.', true);
    if action('Default stat colors', 'wmd_colors_reset') then
        CTX.reset_colors();
        say('Stat colors back to the defaults.');
    end

    section('MOUSE POINTER');
    check('Show a pointer over WMD windows', CFG.pointer, 'enabled', 'FFXI hides the mouse; this draws one while it is over a WhatsMyDamage window.');
    if CFG.pointer.enabled or searching() then
        sub(function()
            slider_f('Pointer size', CFG.pointer, 'size', 0.8, 3.0, '%.1f');
            color('Pointer color', CFG.pointer, 'color');
        end);
    end
end

-- Little preview of every bar style; click one to use it.
local SAMPLE = { { 'Izumi', 'RNG', 1.0 }, { 'Kotorfan', 'COR', 0.72 }, { 'Thilibant', 'MNK', 0.45 } };
local function style_cards()
    if not want('Bar style', 'Details, Flat, Gradient, Glass, Rounded, Neon, Fade, Pill, Underline') then return; end
    local k = sc();
    local avail = imgui.GetContentRegionAvail();
    if type(avail) == 'table' then avail = avail.x or avail[1]; end
    avail = tonumber(avail) or 520;
    local per = 3;
    local gap = 8 * k;
    local cw = (avail - gap * (per - 1)) / per;
    local ch = 64 * k;
    for i, stl in ipairs(styles.LIST) do
        if (i - 1) % per ~= 0 then imgui.SameLine(0, gap); end
        local x, y = imgui.GetCursorScreenPos();
        x, y = tonumber(x) or 0, tonumber(y) or 0;
        local clicked = imgui.InvisibleButton('##wmd_style_' .. stl.key, { cw, ch });
        local hov = imgui.IsItemHovered();
        local on = CFG.bars.style == stl.key;
        local dl = imgui.GetWindowDrawList();
        dl:AddRectFilled({ x, y }, { x + cw, y + ch }, imgui.GetColorU32({ 0.03, 0.03, 0.035, 1 }), 5);
        dl:AddRect({ x, y }, { x + cw, y + ch }, imgui.GetColorU32(on and theme.accent(1) or (hov and theme.accent(0.5) or theme.UI_BORDER)), 5, 0, on and 2 or 1);
        theme.text(dl, x + 6 * k, y + 3 * k, on and theme.UI_ACCENT_TEXT or theme.UI_MUTED, stl.label, imgui.GetFontSize() * 0.85);
        local bh = 12 * k;
        for j, s in ipairs(SAMPLE) do
            local by = y + 20 * k + (j - 1) * (bh + 2 * k);
            local col = CFG.bars.color_by == 'single' and CFG.bars.single or (CFG.job_colors[s[2]] or data.JOB_COLORS[s[2]]);
            styles.draw(dl, stl.key, x + 6 * k, by, x + cw - 6 * k, by + bh, s[3], col,
                { alpha = CFG.bars.alpha, rounding = (tonumber(CFG.bars.rounding) or 0), track = CFG.bars.track, anim = true });
        end
        if hov then theme.tooltip(stl.tip); end
        if clicked then
            CFG.bars.style = stl.key;
            dirty();
        end
    end
end

local function page_bars()
    section('STYLE');
    style_cards();
    section('SIZE');
    slider_i('Bar height', CFG.bars, 'height', 12, 44, '%d px');
    slider_i('Space between bars', CFG.bars, 'spacing', 0, 10, '%d px');
    slider_f('Bar rounding', CFG.bars, 'rounding', 0, 12, '%.0f px');
    section('COLOR');
    choice('Bar color', CFG.bars, 'color_by', COLOR_BY, 'Job color: each job has its own color (change them on the Job colors page).');
    if CFG.bars.color_by == 'single' or searching() then sub(function() color('Single color', CFG.bars, 'single'); end); end
    slider_f('Bar opacity', CFG.bars, 'alpha', 10, 100, '%.0f%%', nil, { mul = 100 });
    color('Empty part of the bar', CFG.bars, 'track', 'The background behind each bar (set its alpha to 0 to hide it).');
    check('Pets in a darker owner color', CFG.bars, 'pet_owner_color', 'Separate pet bars use a darker shade of their owner\'s job color.');
    if not CFG.bars.pet_owner_color or searching() then sub(function() color('Pet bar color', CFG.bars, 'pet_color'); end); end
    section('MOTION');
    check('Bars slide to their new length', CFG.bars, 'anim', 'Smooth bar growth instead of jumping.');
    check('Rows slide when the order changes', CFG.bars, 'slide', 'Players glide to their new place when they pass each other.');
    section('JOB ICONS');
    check('Show job icons', CFG.icons, 'show', 'A job icon at the start of each bar.');
    if CFG.icons.show or searching() then
        sub(function()
            choice('Icon set', CFG.icons, 'set', ICON_SETS, 'Classic / FFXI / FFXIV use the icons that come with XIUI (addons\\XIUI\\assets\\jobs). Letters works without XIUI.');
            if CFG.icons.set ~= 'badge' and not searching() then
                imgui.SetCursorPosX(ui.LABEL_W * sc());
                if icons.job('WAR', CFG.icons.set) == nil then
                    imgui.TextColored(theme.UI_WARN, 'XIUI icons not found - letters are used instead.');
                else
                    imgui.TextColored(theme.UI_GOOD, 'XIUI icons found.');
                end
            end
        end);
    end
end

-- One font editor (family, size, color, outline, shadow) with a preview.
local function font_block(title, st, sample, tipx)
    section(title);
    if want('Font ' .. title, tipx) then
        label('Font', tipx);
        imgui.PushItemWidth(ui.SLIDER_W * sc());
        if imgui.BeginCombo('##wmd_font_' .. title, fonts.label(st.family)) then
            for _, f in ipairs(fonts.available()) do
                if imgui.Selectable(f.label .. '##wmdf_' .. title .. f.key, st.family == f.key) then
                    st.family = f.key;
                    dirty();
                end
            end
            imgui.EndCombo();
        end
        imgui.PopItemWidth();
    end
    slider_i('Size##' .. title, st, 'size', 8, 36, '%d px');
    color('Color##' .. title, st, 'color');
    slider_i('Outline##' .. title, st, 'outline', 0, 3, '%d px', 'A dark edge around every letter (easier to read on bright bars).');
    if (tonumber(st.outline) or 0) > 0 or searching() then sub(function() color('Outline color##' .. title, st, 'outline_color'); end); end
    check('Shadow##' .. title, st, 'shadow', 'A soft drop shadow behind the text.');
    if st.shadow or searching() then
        sub(function()
            slider_f('Shadow distance##' .. title, st, 'shadow_offset', 0.5, 4, '%.1f px');
            slider_f('Shadow strength##' .. title, st, 'shadow_alpha', 0, 100, '%.0f%%', nil, { mul = 100 });
        end);
    end
    if not searching() then
        -- Preview on a bar.
        local k = sc();
        local x, y = imgui.GetCursorScreenPos();
        x, y = tonumber(x) or 0, tonumber(y) or 0;
        local h = math.max(22 * k, (tonumber(st.size) or 14) + 8);
        local w = 360 * k;
        local dl = imgui.GetWindowDrawList();
        x = x + ui.LABEL_W * k;
        styles.draw(dl, CFG.bars.style, x, y, x + w, y + h, 0.8, CFG.job_colors.RNG or data.JOB_COLORS.RNG, { alpha = CFG.bars.alpha, track = CFG.bars.track });
        fonts.text(dl, x + 6, y + (h - (tonumber(st.size) or 14)) / 2 - 1, sample, st);
        imgui.Dummy({ w, h + 4 * k });
    end
end

local function page_text()
    font_block('NAMES', CFG.fonts.name, '1. Izumi', 'The "1. Name" on the left of each bar.');
    font_block('NUMBERS', CFG.fonts.value, '12,345 (35.2%)', 'The amount and share on the right of each bar.');
    font_block('TITLE', CFG.fonts.title, 'Damage Done', 'The window title in the header.');
    section('NUMBERS & NAMES');
    choice('Number style', CFG, 'numbers', NUMBERS, '12,345 or short numbers like 12.3K / 1.25M.');
    choice('Name color', CFG, 'name_color', NAME_COLOR, 'Names in the font color, or in the player\'s job color.');
    ui.info('The hover breakdown and details window text sizes are on Windows > Details & hover. The font of the settings, details, report and new party windows is on Look > Fonts & Tooltips.');
end

local function page_jobs()
    section('JOBS');
    local k = sc();
    for i, job in ipairs(data.JOBS) do
        if want(job .. ' ' .. (data.JOB_NAMES[job] or ''), nil) then
            local custom = CFG.job_colors[job] ~= nil;
            local c = CFG.job_colors[job] or data.JOB_COLORS[job];
            if not searching() and (i - 1) % 2 == 1 then imgui.SameLine(ui.LABEL_W * k + 160 * k); end
            local v = { c[1], c[2], c[3], c[4] or 1 };
            if imgui.ColorEdit4('##wmd_job_' .. job, v, bit.bor(ImGuiColorEditFlags_NoInputs or 0, ImGuiColorEditFlags_NoAlpha or 0)) then
                CFG.job_colors[job] = { v[1], v[2], v[3], 1 };
                dirty();
            end
            imgui.SameLine();
            imgui.TextColored(custom and theme.UI_TEXT or theme.UI_MUTED, ('%s  %s'):format(job, data.JOB_NAMES[job] or ''));
            if custom then
                imgui.SameLine();
                if imgui.SmallButton('x##wmd_jobr_' .. job) then CFG.job_colors[job] = nil; dirty(); end
                theme.tip('Back to the default color.');
            end
        end
    end
    imgui.Spacing();
    color('Pet color', CFG.bars, 'pet_color', 'Separate pet bars (when not in their owner\'s color).');
    if action('Reset all job colors', 'wmd_jobs_reset') then
        CFG.job_colors = {};
        dirty();
        say('Job colors back to the defaults.');
    end
end

local function page_fonts()
    uifont.settings_page(CFG.ui_font, {
        header = function(title) ui.section(title); end,
        label = function(text_value, help_text) ui.label(text_value, help_text); end,
        dirty = dirty,
        want = function(text_value, help_text) return ui.want(text_value, help_text); end,
        ctrl_w = ui.SLIDER_W * sc(),
        accent = theme.UI_ACCENT_TEXT,
        muted = theme.UI_MUTED,
    });
    ui.info('This is the font of the settings, details, report and new party windows and of the hover breakdown. The meters have their own fonts on Look > Text.');
end

local function page_report()
    section('DEFAULTS');
    choice('Channel', CFG.report, 'channel', report.CHANNELS, 'Where Send posts it (Just me = /echo).');
    slider_i('Lines', CFG.report, 'lines', 1, 18, '%d', 'How many players are listed (plus the title line).');
    check('Include jobs', CFG.report, 'show_job', '1. Izumi [RNG] 12,345 (35.2%)');
    check('Include accuracy (Damage Done)', CFG.report, 'show_acc', 'Each player\'s overall accuracy at the end of their line (1. Izumi 12,345 (35.2%) Acc 91.3%), and the party\'s in the title line. Pets combined with their owner count toward the owner\'s accuracy.');
    check('Close the report window after Send', CFG.report, 'close_after');
    section('SEND');
    if want('Open the report window', nil) then
        imgui.SetCursorPosX(ui.LABEL_W * sc());
        for _, m in ipairs(data.MODES) do
            if imgui.Button(m.label .. '##wmd_rep_open_' .. m.key) then report.open(m.key); end
            imgui.SameLine();
        end
        imgui.NewLine();
    end
end

local CMDS = {
    { '/wmd', 'show / hide the meters' },
    { '/wmd config', 'this window (or the gear icon / right-click a meter)' },
    { '/wmd reset', 'clear all data' },
    { '/wmd test', 'test mode on / off (made-up party)' },
    { '/wmd report [damage|heal|taken] [p|l|l2|s|echo]', 'open the report window, or send right away when a channel is given' },
    { '/wmd details', 'open the details window' },
    { '/wmd window <1-3> [on|off]', 'show or hide one window' },
    { '/wmd mode <1-3> <damage|heal|taken>', 'change what a window shows' },
    { '/wmd stack', 'snap the windows under each other' },
    { '/wmd unsnap', 'pull every window out of its group' },
    { '/wmd lock', 'lock / unlock moving and resizing' },
    { '/wmd resetpos', 'move the windows back to the default place' },
};

local function page_commands()
    section('COMMANDS');
    ui.info('/whatsmydamage works as well as /wmd.');
    for _, c in ipairs(CMDS) do
        if want(c[1], c[2]) then
            imgui.TextColored(theme.UI_ACCENT_TEXT, c[1]);
            imgui.TextColored(theme.UI_MUTED, '    ' .. c[2]);
        end
    end
    section('MOUSE');
    ui.info('Hover a bar for the breakdown, click it for the details window. Drag a header to move; drop next to another window to snap (a glowing line shows where). Snapped windows move together. Ctrl + drag pulls one out. Drag the bottom-right corner to change the width. Mouse wheel scrolls a fixed-size window. Right-click a meter for these settings.');
    section('ABOUT');
    ui.value('Version', tostring(addon and addon.version or ''));
    ui.info('WhatsMyDamage by Izumi. Written for HorizonXI. Counts what the game shows you (action and defeat messages); the only thing it ever sends is a report you ask for.');
end

-- ============================================================================
-- Sidebar and window
-- ============================================================================

local GROUPS = {
    { label = 'GENERAL', pages = {
        { key = 'general', label = 'General', desc = 'Who is counted and how. WhatsMyDamage only reads the combat the game already shows you; it never sends anything except a report you ask for.', draw = page_general },
    } },
    { label = 'WINDOWS', pages = {
        { key = 'windows', label = 'Meters', desc = 'Up to three meters, their look and header. Drag one by its header to move it; drop it next to another one and they snap together and move as one. Ctrl + drag (or the chain icon) pulls it out again.', draw = page_meters },
        { key = 'details', label = 'Details & hover', desc = 'The details window (click a bar) and the breakdown you see when you hover a bar.', draw = page_details },
        { key = 'reportwin', label = 'Report window', desc = 'The window that posts the numbers to chat.', draw = page_report_window },
        { key = 'newparty', label = 'New party', desc = 'The small "reset the meters?" window when you join a new party.', draw = page_newparty_window },
        { key = 'settings', label = 'Settings window', desc = 'This window: its size and its own opacity.', draw = page_settings_window },
    } },
    { label = 'LOOK', pages = {
        { key = 'look', label = 'Theme & colors', desc = 'The theme, the background of the details / report / new party windows, the stat colors and the mouse pointer.', draw = page_theme },
        { key = 'bars', label = 'Bars', desc = 'How each player\'s bar looks. Hover a style to read about it, click to use it.', draw = page_bars },
        { key = 'text', label = 'Text', desc = 'Fonts for the meters. Every Windows font that WhatsMyDamage found is in the lists; Bahnschrift is the closest to the Details! look.', draw = page_text },
        { key = 'jobs', label = 'Job colors', desc = 'The bar color for each job (when Bar color is "Job color"). Every job starts with its own color.', draw = page_jobs },
        { key = 'fonts', label = 'Fonts & Tooltips', desc = 'The font of WhatsMyDamage\'s windows (not the meters), and how tooltips look.', draw = page_fonts },
    } },
    { label = 'CHAT', pages = {
        { key = 'report', label = 'Report', desc = 'Post the numbers to chat. Lines go out one second apart, and only when you press Send.', draw = page_report },
    } },
    { label = 'HELP', pages = {
        { key = 'commands', label = 'Commands', desc = 'Type these in chat.', draw = page_commands },
    } },
};

local UI_CTX = {
    id = 'wmd',
    title = 'WhatsMyDamage',
    groups = GROUPS,
    page = function() return CFG.config_page or 'general'; end,
    set_page = function(key) CFG.config_page = key; dirty(); end,
    dirty = function() dirty(); end,
    themes = {
        order = theme.ORDER,
        list = theme.THEMES,
        current = function() return theme.key(CFG.config_theme); end,
        set = function(key) CFG.config_theme = key; dirty(); end,
    },
    status = function()
        if config.message ~= nil and os.clock() - config.message_time < 4 then return config.message, theme.UI_GOOD; end
        if tracker.test then return 'Test mode is on (made-up numbers)', theme.UI_WARN; end
        return nil;
    end,
};

function config.draw(cfg, ctx)
    if not config.open[1] then return; end
    CFG, CTX = cfg, ctx;
    local k = tonumber(cfg.config_scale) or 1;
    ui.scale = k;
    local pos = cfg.config_pos;
    if not config.placed then
        local x, y = tonumber(pos.x) or -1, tonumber(pos.y) or -1;
        if x < 0 or y < 0 then x, y = 160, 120; end
        local w, h = tonumber(pos.w) or -1, tonumber(pos.h) or -1;
        if w <= 0 or h <= 0 then
            w, h = 860 * k, 660 * k;
            pcall(function()
                local dh = tonumber(imgui.GetIO().DisplaySize.y);
                if dh ~= nil and dh > 300 then h = math.min(h, dh - 100); end
            end);
        end
        imgui.SetNextWindowPos({ x, y });
        imgui.SetNextWindowSize({ w, h });
        config.placed = true;
    end
    imgui.SetNextWindowSizeConstraints({ 700 * k, 460 * k }, { 4000, 4000 });

    theme.push(theme.background(tonumber(cfg.look.config.alpha) or 0.97), k, { border = true });
    uifont.push(k);
    local flags = bit.bor(ImGuiWindowFlags_NoCollapse or 0, ImGuiWindowFlags_NoSavedSettings or 0, ImGuiWindowFlags_NoNav or 0);
    if imgui.Begin('WhatsMyDamage Settings##wmd_config', config.open, flags) then
        local ok, err = pcall(ui.body, UI_CTX);
        if not ok then ctx.error('settings', err); end

        if not imgui.IsMouseDown(0) then
            local x, y = imgui.GetWindowPos();
            local w, h = imgui.GetWindowSize();
            x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h);
            if x and y and w and h then
                x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h);
                if x ~= pos.x or y ~= pos.y or w ~= pos.w or h ~= pos.h then
                    pos.x, pos.y, pos.w, pos.h = x, y, w, h;
                    ctx.dirty();
                end
            end
        end
    end
    imgui.End();
    uifont.pop();
    theme.pop();
end

function config.toggle()
    config.open[1] = not config.open[1];
    config.placed = false;
end

return config;
