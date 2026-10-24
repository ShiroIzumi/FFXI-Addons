--[[
    MogSuite - core/globalconfig.lua

    The Global pages of the settings window: Appearance (theme, background,
    settings window size, mouse pointer), Text (the text effect every list
    uses), Keybinds (open keys, Esc), Windows (open / lock / reset every
    window) and About (commands).

    Every setting goes through core/cfgui.lua so the search box finds it.
]]

require('common');
local imgui = require('imgui');
local theme = require('core.theme');
local keys = require('core.keys');
local ui = require('core.cfgui');
local fonts = require('core.fonts');

local globalconfig = {};

local tip = theme.tip;
local ARMED = {};

local SCALES = { 0.85, 1.00, 1.25, 1.50, 1.75, 2.00 };

-- ctx: { G = global settings, modules = { env, ... }, dirty = fn, version = '', state = {} }
local function appearance(ctx)
    local G = ctx.G;

    ui.section('THEME');
    if ui.want('Theme', 'Colors every MogSuite window: accents, tabs, borders and title bars. Copper Garnet Silver Amethyst Emerald Midnight') then
        ui.label('Theme', 'Colors every MogSuite window: accents, tabs, borders and title bars.');
        local current = theme.key(G.theme);
        for i, key in ipairs(theme.ORDER) do
            local t = theme.THEMES[key];
            if i > 1 then imgui.SameLine(0, 4); end
            if theme.toggle_button(t.label, 'ms_theme_' .. key, key == current) then
                G.theme = key;
                theme.applied = nil;
                ctx.dirty();
            end
        end
        -- Swatches under the names.
        imgui.SetCursorPosX(ui.LABEL_W * ui.scale);
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetCursorScreenPos();
        x, y = tonumber(x) or 0, tonumber(y) or 0;
        for i, key in ipairs(theme.ORDER) do
            local a = theme.THEMES[key].accent;
            local bx = x + (i - 1) * 30 * ui.scale;
            dl:AddRectFilled({ bx, y }, { bx + 24 * ui.scale, y + 6 * ui.scale }, imgui.GetColorU32({ a[1] / 255, a[2] / 255, a[3] / 255, 1 }), 2);
        end
        imgui.Dummy({ 1, 8 * ui.scale });
    end

    ui.section('BACKGROUND');
    ui.check("Use the theme's background", G, 'use_theme_bg', 'Each theme has its own dark background (Midnight is deep navy). Turn this off to pick your own color.', { default_on = true });
    if G.use_theme_bg == false or ui.searching() then
        ui.sub(function()
            G.background = G.background or T{ 0.035, 0.035, 0.040 };
            ui.color('Background color', G.background, 'Window background color for every MogSuite window.', false);
        end);
    end
    ui.slider_f('Opacity', G, 'opacity', 0.20, 1.00, '%.2f', 'How see-through the window backgrounds are. Text and icons stay solid.');

    ui.section('SETTINGS WINDOW');
    if ui.want('Settings window size', 'Text size of this settings window. scale') then
        ui.label('Size', 'Text size of this settings window.');
        local cur = tonumber(G.config_scale) or 1.0;
        for i, v in ipairs(SCALES) do
            if i > 1 then imgui.SameLine(0, 4); end
            if theme.toggle_button(('%d%%'):format(math.floor(v * 100 + 0.5)), 'ms_cfgscale_' .. i, math.abs(cur - v) < 0.01) then
                G.config_scale = v;
                ctx.dirty();
            end
        end
    end

    ui.section('MOUSE POINTER');
    ui.check('Show a mouse pointer over MogSuite windows', G, 'mouse_cursor',
        'FFXI hides the Windows mouse pointer. This draws one while the mouse is over any MogSuite window. Turn it off if you already use a pointer tool (such as YoloMouse).',
        { default_on = true });
    if G.mouse_cursor ~= false or ui.searching() then
        ui.sub(function()
            ui.slider_f('Pointer size', G, 'mouse_cursor_size', 0.60, 3.00, '%.2fx', 'How big the pointer is (1.00 is about the size of the Windows pointer).');
            G.mouse_cursor_color = G.mouse_cursor_color or T{ 1.00, 0.10, 0.75, 1.00 };
            G.mouse_cursor_outline = G.mouse_cursor_outline or T{ 0.05, 0.00, 0.05, 1.00 };
            ui.color('Pointer color', G.mouse_cursor_color, 'Fill color of the pointer (with transparency).', true);
            ui.color('Pointer outline', G.mouse_cursor_outline, 'Edge color of the pointer.', true);
            ui.check('Pointer drop shadow', G, 'mouse_cursor_shadow', 'A soft shadow under the pointer so it stands out on bright backgrounds.', { default_on = true });
            if ui.button('Default pointer', 'ms_cursor_reset', 'Back to the fuchsia pointer at 1.40x.') then
                G.mouse_cursor_size = 1.4;
                G.mouse_cursor_color = T{ 1.00, 0.10, 0.75, 1.00 };
                G.mouse_cursor_outline = T{ 0.05, 0.00, 0.05, 1.00 };
                G.mouse_cursor_shadow = true;
                ctx.dirty();
            end
        end);
    end
end

local function text(ctx)
    local G = ctx.G;
    ui.section('TEXT EFFECT');
    ui.info('Used by the Inventory and Actions lists.');
    ui.choice('Effect', G, 'text_effect', theme.EFFECTS,
        'Makes names readable on any background: a drop shadow, an outline, both, or a soft glow.', { default = 'shadow' });
    ui.slider_f('Effect opacity', G, 'effect_opacity', 0.0, 1.0, '%.2f', 'How strong the effect is.');
    G.effect_color = G.effect_color or T{ 0, 0, 0 };
    ui.color('Effect color', G.effect_color, 'Color of the shadow / outline / glow.', false);

    if ui.preview() then
        ui.section('PREVIEW');
        local dl = imgui.GetWindowDrawList();
        local sx, sy = imgui.GetCursorScreenPos();
        local h = imgui.GetTextLineHeight() + 12;
        local w = 320 * ui.scale;
        dl:AddRectFilled({ sx, sy }, { sx + w, sy + h }, imgui.GetColorU32({ 0.52, 0.55, 0.46, 1.0 }), 4.0);
        theme.draw_fx_text(dl, sx + 10, sy + 6, { 0.95, 0.95, 0.97, 1.0 }, 'Pot of Honey');
        theme.draw_fx_text(dl, sx + 10 + theme.text_w('Pot of Honey'), sy + 6, { 0.96, 0.80, 0.45, 1.0 }, ' x12');
        local bx = sx + w + 8;
        dl:AddRectFilled({ bx, sy }, { bx + w * 0.6, sy + h }, imgui.GetColorU32({ 0.10, 0.10, 0.12, 1.0 }), 4.0);
        theme.draw_fx_text(dl, bx + 10, sy + 6, { 0.95, 0.95, 0.97, 1.0 }, 'Cure IV');
        imgui.Dummy({ w, h + 2 });
    end
end

-- Fonts & Tooltips (1.5.0).
local function font_combo(id, G, key, list, extra)
    local cur = G[key] or 'default';
    local label = cur;
    for _, f in ipairs(extra or {}) do if f.key == cur then label = f.label; end end
    for _, f in ipairs(list) do if f.key == cur then label = f.label; end end
    if cur == 'custom' then label = 'Custom file...'; end
    local changed = false;
    imgui.PushItemWidth(ui.SLIDER_W * ui.scale);
    if imgui.BeginCombo('##' .. id, label) then
        for _, f in ipairs(extra or {}) do
            if imgui.Selectable(f.label .. '##' .. id .. f.key, cur == f.key) then G[key] = f.key; changed = true; end
        end
        for _, f in ipairs(list) do
            if imgui.Selectable(f.label .. '##' .. id .. f.key, cur == f.key) then G[key] = f.key; changed = true; end
        end
        if imgui.Selectable('Custom file...##' .. id .. 'custom', cur == 'custom') then G[key] = 'custom'; changed = true; end
        imgui.EndCombo();
    end
    imgui.PopItemWidth();
    if changed then ui.dirty(); end
    return changed;
end

local function fonts_page(ctx)
    local G = ctx.G;
    local list = fonts.available();
    ui.section('WINDOW FONT');
    ui.info("Ashita's own font is a small pixel font, which looks sharp and jagged once it is scaled up. A Windows font (Tahoma is what XIUI's bars use) is drawn at its real size and stays smooth at any UI scale.");
    if ui.want('Font', 'Window font Tahoma Segoe Verdana Arial') then
        ui.label('Font', 'The font of every MogSuite window. Only the fonts installed on this PC are listed.');
        font_combo('ms_font', G, 'font_family', list);
    end
    if G.font_family == 'custom' and ui.want('Font file', 'custom ttf') then
        ui.label('Font file', 'A .ttf / .otf file name in C:\\Windows\\Fonts (e.g. "seguisb.ttf"), or a full path.');
        local buf = { tostring(G.font_custom or '') };
        imgui.PushItemWidth(ui.SLIDER_W * ui.scale);
        if imgui.InputText('##ms_font_custom', buf, 260) then G.font_custom = buf[1]; ui.dirty(); end
        imgui.PopItemWidth();
    end
    ui.slider_i('Text size', G, 'font_size', 10, 28, '%d px', 'Base size of the Windows font at 100%. Each window\'s own UI scale still applies on top. (Not used with Ashita\'s pixel font.)');
    if fonts.needs_reload(G) and ui.want('Reload to apply', 'font reload') then
        ui.label('Apply');
        imgui.TextColored({ 0.95, 0.75, 0.30, 1.0 }, 'A new font loads when MogSuite reloads.');
        imgui.SameLine();
        if imgui.Button('Reload MogSuite##ms_font_reload') then
            AshitaCore:GetChatManager():QueueCommand(1, '/addon reload mogsuite');
        end
        tip('Same as typing /addon reload mogsuite. Your settings are saved first.');
    end

    ui.section('TEXT COLORS');
    ui.check('Use my own text colors', G, 'text_color_on', 'Instead of the theme\'s text colors.');
    if G.text_color_on then
        ui.sub(function()
            G.text_color = G.text_color or T{ 0.93, 0.93, 0.95, 1.00 };
            G.muted_color = G.muted_color or T{ 0.62, 0.62, 0.66, 1.00 };
            ui.color('Text', G.text_color, 'Names, values and most text.', true);
            ui.color('Labels', G.muted_color, 'Labels, hints and secondary text.', true);
        end);
    end

    ui.section('TOOLTIPS');
    ui.check('Customize tooltips', G, 'tooltip_custom', 'Off: tooltips look like the window they come from.', { default_on = true });
    if G.tooltip_custom ~= false then
        ui.sub(function()
            if ui.want('Tooltip font', 'tooltip font') then
                ui.label('Font', 'The font of tooltips. "Same as windows" follows the window font.');
                font_combo('ms_tip_font', G, 'tooltip_font', list, { { key = 'same', label = 'Same as windows' } });
            end
            ui.slider_i('Text size', G, 'tooltip_size', 0, 32, function(v) return v == 0 and 'Same as the window' or '%d px'; end,
                'Tooltip text size. Bigger is easier to read on 4K screens.');
            ui.slider_i('Width', G, 'tooltip_wrap', 0, 900, function(v) return v == 0 and 'Each tooltip\'s own' or '%d px'; end,
                'Long lines wrap at this width.');
            ui.slider_i('Padding', G, 'tooltip_padding', 2, 24, '%d px', 'Space between the border and the text.');
            ui.check('Border', G, 'tooltip_border', nil, { default_on = true });
            G.tooltip_text_color = G.tooltip_text_color or T{ 0.95, 0.95, 0.97, 1.00 };
            G.tooltip_bg = G.tooltip_bg or T{ 0.04, 0.04, 0.05, 0.97 };
            ui.color('Text color', G.tooltip_text_color, 'Plain tooltip text (colored lines keep their colors).', true);
            ui.color('Background', G.tooltip_bg, 'Use the alpha to make it see-through.', true);
        end);
    end
    if ui.preview() and ui.want('Preview', 'tooltip preview') then
        ui.label('Preview');
        imgui.TextColored(theme.UI_ACCENT_TEXT, 'Hover me');
        if imgui.IsItemHovered() then
            imgui.BeginTooltip();
            imgui.TextColored(theme.UI_ACCENT_TEXT, 'Scorpion Harness');
            imgui.TextUnformatted('DEF:30 HP+10 STR+5 DEX+5 Accuracy+10 Attack+10');
            imgui.TextColored(theme.UI_MUTED, 'Lv 57  WAR/RDM/THF/PLD/DRK/BST/BRD/RNG/SAM/NIN/DRG/BLU/COR');
            imgui.EndTooltip();
        end
    end
end

local function keybinds(ctx)
    local G = ctx.G;
    ui.section('OPEN KEYS');
    ui.info('Each window has its own key. Click a key to change it, then press the new key (hold Ctrl, Alt or Shift for a combination; Esc cancels). Keys do nothing while the chat box is open or you are typing in a text box.');
    imgui.Spacing();
    for _, env in ipairs(ctx.modules) do
        local info = env.module_info;
        local bind = G.keys[info.key];
        if bind ~= nil and ui.want(info.label .. ' key', 'keybind open key shortcut ' .. info.label) then
            theme.align_label();
            imgui.TextColored(info.color, info.label);
            imgui.SameLine();
            imgui.SetCursorPosX(ui.LABEL_W * ui.scale);
            local en = { bind.enabled ~= false };
            if imgui.Checkbox('##ms_key_en_' .. info.key, en) then bind.enabled = en[1]; ctx.dirty(); end
            tip(('Turn the %s key on / off.'):format(info.label));
            imgui.SameLine();
            local label;
            if keys.listening == info.key then label = 'Press a key...'; else label = keys.text(bind); end
            if theme.toggle_button(label, 'ms_bind_' .. info.key, keys.listening == info.key, { 150 * ui.scale, 0 }) then
                if keys.listening == info.key then keys.listening = nil; else keys.listening = info.key; end
            end
            tip('Click, then press the key you want.');
            imgui.SameLine();
            if imgui.Button('Clear##ms_key_clear_' .. info.key) then
                bind.key = 0; bind.ctrl = false; bind.alt = false; bind.shift = false;
                ctx.dirty();
            end
            tip('No key for this window (the command still works).');
        end
    end
    imgui.Spacing();
    if ui.button('Default keys', 'ms_keys_default', 'C, B and P with no Ctrl / Alt / Shift.') then
        G.keys.character.key, G.keys.inventory.key, G.keys.actions.key = 0x43, 0x42, 0x50;
        for _, b in pairs(G.keys) do b.enabled = true; b.ctrl = false; b.alt = false; b.shift = false; end
        ctx.dirty();
    end
    if not ui.searching() then
        imgui.SameLine();
        imgui.TextColored(theme.UI_MUTED, 'Character C, Inventory B, Actions P');
    end

    ui.section('ESC KEY');
    ui.check('Esc closes all MogSuite windows', G, 'esc_close',
        'Pressing Esc closes every open MogSuite window, including this one. The game still gets Esc too, so its own menus close as usual. Ignored while you are typing.',
        { default_on = true });
end

local function windows(ctx)
    ui.section('OPEN / CLOSE');
    if ui.want('Open or close windows', 'Character Inventory Actions window open close toggle') then
        ui.label('Windows', 'Open / close a window. The dot next to each module in the sidebar does the same.');
        local first = true;
        for _, env in ipairs(ctx.modules) do
            local info = env.module_info;
            if not info.no_window then
                if not first then imgui.SameLine(0, 6); end
                first = false;
                local open = false;
                if type(env.module_is_open) == 'function' then
                    local ok, r = pcall(env.module_is_open);
                    open = ok and r == true;
                end
                if theme.color_tab(info.label, 'ms_open_' .. info.key, open, info.color, (open and 'Close' or 'Open') .. ' the ' .. info.label .. ' window') then
                    env.module_toggle();
                end
            end
        end
    end

    ui.section('POSITION');
    if ui.want('Lock all windows', 'Locks (or unlocks) the position and size of every MogSuite window.') then
        local all_locked = true;
        for _, env in ipairs(ctx.modules) do
            if not env.module_is_locked() then all_locked = false; end
        end
        ui.label('Lock', 'Locks (or unlocks) the position and size of every MogSuite window.');
        if theme.toggle_button(all_locked and 'All locked - click to unlock' or 'Lock all windows', 'ms_lockall', all_locked) then
            for _, env in ipairs(ctx.modules) do env.module_set_locked(not all_locked); end
        end
    end
    if ui.danger('Reset all positions', 'ms_resetall', ARMED,
        'Moves every MogSuite window back to its default place and size (click twice).') then
        for _, env in ipairs(ctx.modules) do env.module_reset_position(); end
    end
end

local function about(ctx)
    ui.section('MOGSUITE');
    if ui.want('About MogSuite', 'version authors') then
        imgui.TextColored(theme.UI_ACCENT_TEXT, 'MogSuite');
        imgui.SameLine();
        imgui.TextDisabled('v' .. ctx.version);
        imgui.Text('by Izumi (ShiroIzumi) and Kyrias (.kyri)');
        imgui.PushTextWrapPos(0);
        imgui.TextColored(theme.UI_MUTED, 'Your character, your bags and everything you can do, in one place. Made for HorizonXI (level 75 era) on Ashita v4.');
        imgui.PopTextWrapPos();
    end

    ui.section('COMMANDS');
    local cmds = {
        { '/ms', 'Open / close this settings window' },
        { '/ms char', 'Open / close the Character window' },
        { '/ms inv', 'Open / close the Inventory window' },
        { '/ms act', 'Open / close the Actions window' },
        { '/ms reset', 'Move every window back to its default place' },
        { '/ms test trade', 'Show a test request popup (party / alliance / trade)' },
        { '/ms help', 'List the commands in chat' },
    };
    for _, c in ipairs(cmds) do
        if ui.want(c[1], c[2] .. ' command') then
            imgui.TextColored(theme.UI_ACCENT_TEXT, c[1]);
            imgui.SameLine(130 * ui.scale);
            imgui.TextDisabled(c[2]);
        end
    end
    ui.info('/mog and /mogsuite work the same as /ms.');

    ui.section('GOOD TO KNOW');
    ui.info('Nothing is ever done for you: items, abilities and spells are only used when you click them. MogSuite only shows information after the game has sent it.');
    ui.info('Settings are saved per character. Your characters\' bags, learned vendor prices and key item marks are shared, in addons\\MogSuite\\data\\.');
end

globalconfig.sections = {
    { key = 'appearance', label = 'Appearance', draw = appearance, desc = 'The theme and background of every MogSuite window, the size of this window, and the mouse pointer.' },
    { key = 'text', label = 'Text', draw = text, desc = 'The effect behind names in the Inventory and Actions lists, so they read on any background.' },
    { key = 'fonts', label = 'Fonts & Tooltips', draw = fonts_page, desc = 'The font and text size of every MogSuite window (smooth Windows fonts), text colors, and how tooltips look.' },
    { key = 'keys', label = 'Keybinds', draw = keybinds, desc = 'The key that opens each window, and what Esc does.' },
    { key = 'windows', label = 'Windows', draw = windows, desc = 'Open, lock or reset every MogSuite window at once.' },
    { key = 'about', label = 'About', draw = about, desc = 'Who made MogSuite, the chat commands, and good to know.' },
};

return globalconfig;
