--[[
    MogSuite - core/globalconfig.lua

    The Global tab of the config window: theme and background, text effect,
    open keys, all windows at once, and About.
]]

require('common');
local imgui = require('imgui');
local theme = require('core.theme');
local keys = require('core.keys');

local globalconfig = {};

local tip, section_header, align_label = theme.tip, theme.section_header, theme.align_label;

-- ctx: { G = global settings, modules = { env, ... }, dirty = fn, version = '' }
local function appearance(ctx)
    local G = ctx.G;
    section_header('Theme');
    local current = theme.key(G.theme);
    imgui.PushItemWidth(220);
    if imgui.BeginCombo('Theme##ms_theme', theme.THEMES[current].label) then
        for _, key in ipairs(theme.ORDER) do
            local t = theme.THEMES[key];
            if imgui.Selectable(t.label .. '##ms_theme_' .. key, key == current) then
                G.theme = key;
                theme.applied = nil;
                ctx.dirty();
            end
        end
        imgui.EndCombo();
    end
    imgui.PopItemWidth();
    tip('Colors every MogSuite window: accents, tabs, borders and title bars.');

    -- Swatches: click one to pick it.
    for i, key in ipairs(theme.ORDER) do
        local t = theme.THEMES[key];
        if i > 1 then imgui.SameLine(0, 6); end
        local a = t.accent;
        imgui.PushStyleColor(ImGuiCol_Button, { a[1] / 255, a[2] / 255, a[3] / 255, 1.0 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { a[1] / 255, a[2] / 255, a[3] / 255, 0.85 });
        imgui.PushStyleColor(ImGuiCol_ButtonActive, { a[1] / 255, a[2] / 255, a[3] / 255, 0.70 });
        if imgui.Button('##ms_swatch_' .. key, { 26, 18 }) then
            G.theme = key;
            theme.applied = nil;
            ctx.dirty();
        end
        imgui.PopStyleColor(3);
        tip(t.label);
        if key == current then theme.draw_item_underline({ 1, 1, 1, 0.9 }); end
    end

    imgui.Spacing();
    section_header('Background');
    local use = { G.use_theme_bg ~= false };
    if imgui.Checkbox("Use the theme's background##ms_usebg", use) then G.use_theme_bg = use[1]; ctx.dirty(); end
    tip('Each theme has its own dark background (Midnight is deep navy). Turn this off to pick your own color.');
    if G.use_theme_bg == false then
        G.background = G.background or T{ 0.035, 0.035, 0.040 };
        if imgui.ColorEdit3('Background color##ms_bg', G.background, ImGuiColorEditFlags_NoInputs or 0) then ctx.dirty(); end
        tip('Window background color for every MogSuite window.');
    end
    imgui.PushItemWidth(220);
    local op = { tonumber(G.opacity) or 0.94 };
    if imgui.SliderFloat('Opacity##ms_opacity', op, 0.20, 1.00, '%.2f', ImGuiSliderFlags_AlwaysClamp) then G.opacity = op[1]; ctx.dirty(); end
    tip('How see-through the window backgrounds are. Text and icons stay solid.');
    imgui.PopItemWidth();

    imgui.Spacing();
    section_header('Config window');
    imgui.PushItemWidth(220);
    local cs = { tonumber(G.config_scale) or 1.0 };
    if imgui.SliderFloat('Size##ms_cfgscale', cs, 0.80, 2.00, '%.2fx', ImGuiSliderFlags_AlwaysClamp) then G.config_scale = cs[1]; ctx.dirty(); end
    tip('Text size of this config window.');
    imgui.PopItemWidth();
end

local function text(ctx)
    local G = ctx.G;
    section_header('Text effect');
    imgui.TextDisabled('Used by the Inventory and Actions lists.');
    imgui.PushItemWidth(220);
    local cur = 'Shadow';
    for _, e in ipairs(theme.EFFECTS) do if e.key == G.text_effect then cur = e.label; end end
    if imgui.BeginCombo('Effect##ms_fx', cur) then
        for _, e in ipairs(theme.EFFECTS) do
            if imgui.Selectable(e.label, e.key == G.text_effect) then G.text_effect = e.key; ctx.dirty(); end
        end
        imgui.EndCombo();
    end
    tip('Makes names readable on any background: a drop shadow, an outline, both, or a soft glow.');
    local eo = { tonumber(G.effect_opacity) or 0.85 };
    if imgui.SliderFloat('Effect opacity##ms_fxo', eo, 0.0, 1.0, '%.2f', ImGuiSliderFlags_AlwaysClamp) then G.effect_opacity = eo[1]; ctx.dirty(); end
    tip('How strong the effect is.');
    imgui.PopItemWidth();
    G.effect_color = G.effect_color or T{ 0, 0, 0 };
    if imgui.ColorEdit3('Effect color##ms_fxc', G.effect_color, ImGuiColorEditFlags_NoInputs or 0) then ctx.dirty(); end
    tip('Color of the shadow / outline / glow.');

    imgui.Spacing();
    section_header('Preview');
    local dl = imgui.GetWindowDrawList();
    local sx, sy = imgui.GetCursorScreenPos();
    local h = imgui.GetTextLineHeight() + 12;
    dl:AddRectFilled({ sx, sy }, { sx + 300, sy + h }, imgui.GetColorU32({ 0.52, 0.55, 0.46, 1.0 }), 4.0);
    theme.draw_fx_text(dl, sx + 10, sy + 6, { 0.95, 0.95, 0.97, 1.0 }, 'Pot of Honey');
    theme.draw_fx_text(dl, sx + 10 + theme.text_w('Pot of Honey'), sy + 6, { 0.96, 0.80, 0.45, 1.0 }, ' x12');
    imgui.Dummy({ 300, h + 2 });
end

local function keybinds(ctx)
    local G = ctx.G;
    section_header('Open keys');
    imgui.TextWrapped('Each window has its own key. Click a key to change it, then press the new key (hold Ctrl, Alt or Shift for a combination; Esc cancels). Keys do nothing while the chat box is open or you are typing in a text box.');
    imgui.Spacing();
    for _, env in ipairs(ctx.modules) do
        local info = env.module_info;
        local bind = G.keys[info.key];
        if bind ~= nil then
        local en = { bind.enabled ~= false };
        if imgui.Checkbox('##ms_key_en_' .. info.key, en) then bind.enabled = en[1]; ctx.dirty(); end
        tip(('Turn the %s key on / off.'):fmt(info.label));
        imgui.SameLine();
        align_label();
        imgui.TextColored(info.color, info.label);
        imgui.SameLine(150);
        local label;
        if keys.listening == info.key then label = 'Press a key...'; else label = keys.text(bind); end
        if theme.toggle_button(label, 'ms_bind_' .. info.key, keys.listening == info.key, { 170, 0 }) then
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
    imgui.TextDisabled('Defaults: Character C, Inventory B, Actions P.');
    if imgui.Button('Default keys##ms_keys_default') then
        G.keys.character.key, G.keys.inventory.key, G.keys.actions.key = 0x43, 0x42, 0x50;
        for _, b in pairs(G.keys) do b.enabled = true; b.ctrl = false; b.alt = false; b.shift = false; end
        ctx.dirty();
    end
    tip('C, B and P with no Ctrl / Alt / Shift.');
end

local function windows(ctx)
    section_header('Windows');
    local first = true;
    for _, env in ipairs(ctx.modules) do
        local info = env.module_info;
        if not info.no_window then
            if not first then imgui.SameLine(0, 6); end
            first = false;
            if theme.color_tab(info.label, 'ms_open_' .. info.key, false, info.color, 'Open / close the ' .. info.label .. ' window') then
                env.module_toggle();
            end
        end
    end

    imgui.Spacing();
    local all_locked = true;
    for _, env in ipairs(ctx.modules) do
        if not env.module_is_locked() then all_locked = false; end
    end
    if imgui.Button((all_locked and 'Unlock all windows' or 'Lock all windows') .. '##ms_lockall') then
        for _, env in ipairs(ctx.modules) do env.module_set_locked(not all_locked); end
    end
    tip('Locks (or unlocks) the position and size of every MogSuite window.');
    imgui.SameLine();
    local armed = ctx.state.reset_armed ~= nil and os.clock() - ctx.state.reset_armed < 3.0;
    if armed then imgui.PushStyleColor(ImGuiCol_Button, { 0.72, 0.16, 0.16, 1.0 }); end
    local clicked = imgui.Button((armed and 'Click again to reset' or 'Reset all positions') .. '##ms_resetall');
    if armed then imgui.PopStyleColor(1); end
    tip('Moves every MogSuite window back to its default place and size (click twice).');
    if clicked then
        if armed then
            for _, env in ipairs(ctx.modules) do env.module_reset_position(); end
            ctx.state.reset_armed = nil;
        else
            ctx.state.reset_armed = os.clock();
        end
    end
end

local function about(ctx)
    section_header('MogSuite');
    imgui.TextColored(theme.UI_ACCENT_TEXT, 'MogSuite');
    imgui.SameLine();
    imgui.TextDisabled('v' .. ctx.version);
    imgui.Text('by Izumi (ShiroIzumi) and Kyrias (.kyri)');
    imgui.TextWrapped('Your character, your bags and everything you can do, in one place. Made for HorizonXI (level 75 era) on Ashita v4.');

    imgui.Spacing();
    section_header('Commands');
    local cmds = {
        { '/ms', 'Open / close this config window' },
        { '/ms char', 'Open / close the Character window' },
        { '/ms inv', 'Open / close the Inventory window' },
        { '/ms act', 'Open / close the Actions window' },
        { '/ms reset', 'Move every window back to its default place' },
        { '/ms test trade', 'Show a test request popup (party / alliance / trade)' },
        { '/ms help', 'List the commands in chat' },
    };
    for _, c in ipairs(cmds) do
        imgui.TextColored(theme.UI_ACCENT_TEXT, c[1]);
        imgui.SameLine(120);
        imgui.TextDisabled(c[2]);
    end
    imgui.TextDisabled('/mog and /mogsuite work the same as /ms.');

    imgui.Spacing();
    section_header('Good to know');
    imgui.TextWrapped('Nothing is ever done for you: items, abilities and spells are only used when you click them. MogSuite only shows information after the game has sent it.');
    imgui.TextWrapped('Settings are saved per character. Your characters\' bags, learned vendor prices and key item marks are shared, in addons\\MogSuite\\data\\.');
end

globalconfig.sections = {
    { key = 'appearance', label = 'Appearance', draw = appearance },
    { key = 'text', label = 'Text', draw = text },
    { key = 'keys', label = 'Keybinds', draw = keybinds },
    { key = 'windows', label = 'Windows', draw = windows },
    { key = 'about', label = 'About', draw = about },
};

return globalconfig;
