--[[
    MogSuite - core/theme.lua

    The look shared by every MogSuite window: the six themes, the ImGui
    style stack, and the small widgets used everywhere (tabs, chips, toggle
    buttons, section headers, help markers, text with effects).

    The UI_* color tables are updated in place when the theme changes, so
    every module can keep its own reference to them.
]]

require('common');
local imgui = require('imgui');

local theme = {};

-- ============================================================================
-- Colors
-- ============================================================================

theme.UI_TITLE          = { 0.020, 0.020, 0.022, 1.00 };
theme.UI_TITLE_ACTIVE   = { 0.080, 0.080, 0.090, 1.00 };
theme.UI_POPUP          = { 0.050, 0.050, 0.056, 0.98 };
theme.UI_BORDER         = { 0.250, 0.250, 0.280, 0.90 };
theme.UI_CONTROL        = { 0.100, 0.100, 0.110, 1.00 };
theme.UI_CONTROL_HOVER  = { 0.160, 0.160, 0.180, 1.00 };
theme.UI_CONTROL_ACTIVE = { 0.220, 0.220, 0.250, 1.00 };
theme.UI_TEXT           = { 0.93, 0.93, 0.95, 1.00 };
theme.UI_MUTED          = { 0.62, 0.62, 0.66, 1.00 };
theme.UI_ACCENT         = { 0.50, 0.50, 0.50, 1.00 };
theme.UI_ACCENT_TEXT    = { 0.70, 0.70, 0.70, 1.00 };
theme.UI_TRANSPARENT    = { 0.00, 0.00, 0.00, 0.00 };
theme.UI_WHITE          = { 1.00, 1.00, 1.00, 1.00 };
theme.UI_DANGER         = { 0.86, 0.30, 0.30, 1.00 };

-- Tab colors (the same element colors as the Character resistances).
theme.COLORS = {
    fire    = { 1.00, 0.34, 0.24, 1.00 },
    ice     = { 0.55, 0.86, 1.00, 1.00 },
    wind    = { 0.45, 0.95, 0.55, 1.00 },
    earth   = { 0.83, 0.63, 0.32, 1.00 },
    thunder = { 0.76, 0.55, 1.00, 1.00 },
    water   = { 0.32, 0.70, 1.00, 1.00 },
    light   = { 1.00, 0.92, 0.52, 1.00 },
    dark    = { 0.66, 0.48, 0.82, 1.00 },
};

-- Themes, 0-255 RGB.
--   accent      : fills, underlines, checkmarks, slider grabs
--   text        : headers and selected text
--   title_active: focused title bar
--   border      : window and separator borders
--   bg          : window background (when "Use the theme's background" is on)
--   control     : buttons / input boxes (optional; neutral grey when absent)
theme.THEMES = {
    copper   = { label = 'Copper',   accent = { 196, 128, 80 },  text = { 224, 166, 120 }, title_active = { 24, 15, 9 },  border = { 72, 48, 32 },  bg = { 9, 9, 10 } },
    garnet   = { label = 'Garnet',   accent = { 168, 52, 62 },   text = { 214, 112, 120 }, title_active = { 24, 9, 11 },  border = { 70, 30, 34 },  bg = { 9, 9, 10 } },
    silver   = { label = 'Silver',   accent = { 176, 188, 204 }, text = { 226, 232, 240 }, title_active = { 28, 30, 34 }, border = { 66, 72, 82 },  bg = { 9, 9, 10 } },
    amethyst = { label = 'Amethyst', accent = { 150, 118, 214 }, text = { 184, 160, 236 }, title_active = { 16, 11, 26 }, border = { 52, 42, 78 },  bg = { 9, 8, 12 } },
    emerald  = { label = 'Emerald',  accent = { 60, 180, 110 },  text = { 132, 222, 166 }, title_active = { 10, 28, 18 }, border = { 30, 70, 46 },  bg = { 8, 10, 9 } },
    midnight = { label = 'Midnight', accent = { 104, 148, 226 }, text = { 168, 196, 242 }, title_active = { 14, 22, 44 }, border = { 42, 60, 100 }, bg = { 9, 14, 28 },
                 control = { 20, 28, 48 }, control_hover = { 30, 42, 70 }, control_active = { 40, 56, 92 }, title = { 6, 10, 22 }, popup = { 10, 16, 32 } },
};
theme.ORDER = { 'copper', 'garnet', 'silver', 'amethyst', 'emerald', 'midnight' };
theme.DEFAULT = 'silver';

local NEUTRAL = {
    control = { 25.5, 25.5, 28.05 }, control_hover = { 40.8, 40.8, 45.9 }, control_active = { 56.1, 56.1, 63.75 },
    title = { 5.1, 5.1, 5.61 }, popup = { 12.75, 12.75, 14.28 },
};

-- The active global settings (theme, background, text effect). Set by
-- mogsuite.lua and replaced when Ashita reloads the settings.
local G = nil;
function theme.set_global(g) G = g; theme.applied = nil; end

local function set_rgb(dst, rgb)
    dst[1] = rgb[1] / 255; dst[2] = rgb[2] / 255; dst[3] = rgb[3] / 255;
end

function theme.key(key)
    key = tostring(key or theme.DEFAULT):lower();
    if theme.THEMES[key] == nil then key = theme.DEFAULT; end
    return key;
end

function theme.apply(key)
    key = theme.key(key);
    if theme.applied == key then return; end
    local t = theme.THEMES[key];
    set_rgb(theme.UI_ACCENT, t.accent);
    set_rgb(theme.UI_ACCENT_TEXT, t.text);
    set_rgb(theme.UI_TITLE_ACTIVE, t.title_active);
    set_rgb(theme.UI_BORDER, t.border);
    set_rgb(theme.UI_CONTROL, t.control or NEUTRAL.control);
    set_rgb(theme.UI_CONTROL_HOVER, t.control_hover or NEUTRAL.control_hover);
    set_rgb(theme.UI_CONTROL_ACTIVE, t.control_active or NEUTRAL.control_active);
    set_rgb(theme.UI_TITLE, t.title or NEUTRAL.title);
    set_rgb(theme.UI_POPUP, t.popup or NEUTRAL.popup);
    theme.applied = key;
end

function theme.accent(alpha_mul)
    local a = theme.UI_ACCENT;
    return { a[1], a[2], a[3], a[4] * (alpha_mul or 1.0) };
end

-- The window background: the theme's own, or the custom color, at the
-- chosen opacity.
function theme.background()
    local g = G or {};
    local key = theme.key(g.theme);
    local op = tonumber(g.opacity) or 0.94;
    if g.use_theme_bg ~= false then
        local b = theme.THEMES[key].bg;
        return { b[1] / 255, b[2] / 255, b[3] / 255, op };
    end
    local c = g.background or { 0.035, 0.035, 0.040 };
    return { tonumber(c[1]) or 0.035, tonumber(c[2]) or 0.035, tonumber(c[3]) or 0.040, op };
end

-- ============================================================================
-- Style stack
-- ============================================================================

local stack = {};

-- bg: background color (nil = the global one). key: theme (nil = global).
-- scale: optional spacing multiplier (nil = the default compact spacing).
function theme.push(bg, key, scale)
    theme.apply(key or (G and G.theme));
    bg = bg or theme.background();
    local UI = theme;
    local nc, nv = 0, 0;
    local function c(idx, v) if idx ~= nil then imgui.PushStyleColor(idx, v); nc = nc + 1; end end
    local function v(idx, val) if idx ~= nil then imgui.PushStyleVar(idx, val); nv = nv + 1; end end

    c(ImGuiCol_WindowBg, { bg[1], bg[2], bg[3], bg[4] or 0.94 });
    c(ImGuiCol_ChildBg, UI.UI_TRANSPARENT);
    c(ImGuiCol_PopupBg, UI.UI_POPUP);
    c(ImGuiCol_TitleBg, UI.UI_TITLE);
    c(ImGuiCol_TitleBgActive, UI.UI_TITLE_ACTIVE);
    c(ImGuiCol_TitleBgCollapsed, UI.UI_TITLE);
    c(ImGuiCol_Border, UI.UI_BORDER);
    c(ImGuiCol_BorderShadow, UI.UI_TRANSPARENT);
    c(ImGuiCol_Text, UI.UI_TEXT);
    c(ImGuiCol_TextDisabled, UI.UI_MUTED);
    c(ImGuiCol_TextSelectedBg, theme.accent(0.35));
    c(ImGuiCol_FrameBg, UI.UI_CONTROL);
    c(ImGuiCol_FrameBgHovered, UI.UI_CONTROL_HOVER);
    c(ImGuiCol_FrameBgActive, UI.UI_CONTROL_ACTIVE);
    c(ImGuiCol_CheckMark, UI.UI_ACCENT);
    c(ImGuiCol_SliderGrab, theme.accent(0.80));
    c(ImGuiCol_SliderGrabActive, UI.UI_ACCENT);
    c(ImGuiCol_Button, UI.UI_CONTROL);
    c(ImGuiCol_ButtonHovered, UI.UI_CONTROL_HOVER);
    c(ImGuiCol_ButtonActive, UI.UI_CONTROL_ACTIVE);
    c(ImGuiCol_Header, theme.accent(0.22));
    c(ImGuiCol_HeaderHovered, theme.accent(0.30));
    c(ImGuiCol_HeaderActive, theme.accent(0.40));
    c(ImGuiCol_Separator, UI.UI_BORDER);
    c(ImGuiCol_SeparatorHovered, theme.accent(0.60));
    c(ImGuiCol_SeparatorActive, UI.UI_ACCENT);
    c(ImGuiCol_ScrollbarBg, { 0.00, 0.00, 0.00, 0.20 });
    c(ImGuiCol_ScrollbarGrab, UI.UI_CONTROL_HOVER);
    c(ImGuiCol_ScrollbarGrabHovered, UI.UI_CONTROL_ACTIVE);
    c(ImGuiCol_ScrollbarGrabActive, theme.accent(0.80));
    c(ImGuiCol_ResizeGrip, theme.accent(0.20));
    c(ImGuiCol_ResizeGripHovered, theme.accent(0.45));
    c(ImGuiCol_ResizeGripActive, theme.accent(0.70));
    c(ImGuiCol_Tab, UI.UI_CONTROL);
    c(ImGuiCol_TabHovered, theme.accent(0.30));
    c(ImGuiCol_TabActive, theme.accent(0.38));
    c(ImGuiCol_TableHeaderBg, { UI.UI_CONTROL[1], UI.UI_CONTROL[2], UI.UI_CONTROL[3], 1.0 });
    c(ImGuiCol_TableBorderStrong, UI.UI_BORDER);
    c(ImGuiCol_TableBorderLight, { UI.UI_BORDER[1], UI.UI_BORDER[2], UI.UI_BORDER[3], 0.45 });
    c(ImGuiCol_TableRowBg, UI.UI_TRANSPARENT);
    c(ImGuiCol_TableRowBgAlt, { 1.00, 1.00, 1.00, 0.035 });
    c(ImGuiCol_PlotHistogram, UI.UI_ACCENT);

    v(ImGuiStyleVar_WindowRounding, 6.0);
    v(ImGuiStyleVar_ChildRounding, 4.0);
    v(ImGuiStyleVar_FrameRounding, 4.0);
    v(ImGuiStyleVar_PopupRounding, 4.0);
    v(ImGuiStyleVar_ScrollbarRounding, 6.0);
    v(ImGuiStyleVar_GrabRounding, 4.0);
    v(ImGuiStyleVar_ScrollbarSize, 11.0);
    if scale == nil then
        v(ImGuiStyleVar_WindowPadding, { 10, 8 });
        v(ImGuiStyleVar_FramePadding, { 7, 3 });
        v(ImGuiStyleVar_ItemSpacing, { 6, 4 });
    else
        scale = tonumber(scale) or 1.0;
        v(ImGuiStyleVar_WindowPadding, { 12 * scale, 10 * scale });
        v(ImGuiStyleVar_FramePadding, { 8 * scale, 4 * scale });
        v(ImGuiStyleVar_ItemSpacing, { 8 * scale, 5 * scale });
        v(ImGuiStyleVar_ItemInnerSpacing, { 6 * scale, 4 * scale });
    end

    stack[#stack + 1] = { nc, nv };
end

function theme.pop()
    local e = table.remove(stack);
    if e == nil then return; end
    if e[2] > 0 then imgui.PopStyleVar(e[2]); end
    if e[1] > 0 then imgui.PopStyleColor(e[1]); end
end

-- ============================================================================
-- Small helpers
-- ============================================================================

function theme.text_w(s)
    return tonumber((imgui.CalcTextSize(tostring(s)))) or 0;
end

function theme.align_label()
    if imgui.AlignTextToFramePadding ~= nil then imgui.AlignTextToFramePadding(); end
end

-- BeginChild across Ashita builds (new: child_flags int, old: border bool).
function theme.begin_child(id, size, window_flags)
    window_flags = window_flags or 0;
    local ok, result = pcall(imgui.BeginChild, id, size, 0, window_flags);
    if ok then return result; end
    return imgui.BeginChild(id, size, false, window_flags);
end

-- Tooltip for the last item (wrapped).
function theme.tip(text)
    if text == nil or text == '' then return; end
    if imgui.IsItemHovered() then
        imgui.BeginTooltip();
        imgui.PushTextWrapPos(380);
        imgui.TextUnformatted(text);
        imgui.PopTextWrapPos();
        imgui.EndTooltip();
    end
end

function theme.help_marker(text)
    imgui.SameLine();
    imgui.TextDisabled('(?)');
    theme.tip(text);
end

function theme.section_header(title)
    imgui.TextColored(theme.UI_ACCENT_TEXT, title);
    imgui.PushStyleColor(ImGuiCol_Separator, theme.accent(0.35));
    imgui.Separator();
    imgui.PopStyleColor(1);
    imgui.Spacing();
end

-- Short accent bar along the bottom edge of the last drawn item.
function theme.draw_item_underline(color)
    if imgui.GetItemRectMin == nil then return; end
    local min_x = imgui.GetItemRectMin();
    local max_x, max_y = imgui.GetItemRectMax();
    min_x = tonumber(min_x); max_x = tonumber(max_x); max_y = tonumber(max_y);
    if min_x == nil or max_x == nil or max_y == nil then return; end
    imgui.GetWindowDrawList():AddRectFilled({ min_x + 4, max_y - 2 }, { max_x - 4, max_y }, imgui.GetColorU32(color or theme.UI_ACCENT), 1.0);
end

-- Flat tab: accent text + 2px underline when selected.
function theme.styled_tab(label, id, selected)
    local UI = theme;
    if selected then
        imgui.PushStyleColor(ImGuiCol_Button, theme.accent(0.14));
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, theme.accent(0.20));
        imgui.PushStyleColor(ImGuiCol_ButtonActive, theme.accent(0.26));
        imgui.PushStyleColor(ImGuiCol_Text, UI.UI_ACCENT_TEXT);
    else
        imgui.PushStyleColor(ImGuiCol_Button, { UI.UI_CONTROL[1], UI.UI_CONTROL[2], UI.UI_CONTROL[3], 0.55 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, UI.UI_CONTROL_HOVER);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, UI.UI_CONTROL_ACTIVE);
        imgui.PushStyleColor(ImGuiCol_Text, UI.UI_MUTED);
    end
    local clicked = imgui.Button(label .. '##' .. id);
    if selected then theme.draw_item_underline(); end
    imgui.PopStyleColor(4);
    return clicked;
end

-- Colored tab: a colored strip across the top (like the resistance tiles),
-- tinted fill and bright text when selected. color = one of theme.COLORS.
function theme.color_tab(label, id, selected, color, tooltip)
    local UI = theme;
    color = color or UI.UI_ACCENT;
    local r, g, b = color[1], color[2], color[3];
    if selected then
        imgui.PushStyleColor(ImGuiCol_Button, { r, g, b, 0.16 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { r, g, b, 0.22 });
        imgui.PushStyleColor(ImGuiCol_ButtonActive, { r, g, b, 0.28 });
        imgui.PushStyleColor(ImGuiCol_Text, { 0.97, 0.97, 0.98, 1.0 });
    else
        imgui.PushStyleColor(ImGuiCol_Button, { UI.UI_CONTROL[1], UI.UI_CONTROL[2], UI.UI_CONTROL[3], 0.55 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { r, g, b, 0.12 });
        imgui.PushStyleColor(ImGuiCol_ButtonActive, { r, g, b, 0.20 });
        imgui.PushStyleColor(ImGuiCol_Text, UI.UI_MUTED);
    end
    local clicked = imgui.Button(label .. '##' .. id);
    local hovered = imgui.IsItemHovered();
    if imgui.GetItemRectMin ~= nil then
        local x1, y1 = imgui.GetItemRectMin();
        local x2 = imgui.GetItemRectMax();
        x1, y1, x2 = tonumber(x1), tonumber(y1), tonumber(x2);
        if x1 and y1 and x2 then
            local a = selected and 1.0 or (hovered and 0.75 or 0.40);
            imgui.GetWindowDrawList():AddRectFilled({ x1, y1 }, { x2, y1 + 3 }, imgui.GetColorU32({ r, g, b, a }), 3.0);
        end
    end
    imgui.PopStyleColor(4);
    if tooltip ~= nil then theme.tip(tooltip); end
    return clicked;
end

-- Rounded filter chip.
function theme.chip(label, id, selected, tooltip)
    local UI = theme;
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 10.0);
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 9, 2 });
    imgui.PushStyleColor(ImGuiCol_Button, selected and theme.accent(0.28) or UI.UI_CONTROL);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, selected and theme.accent(0.36) or UI.UI_CONTROL_HOVER);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, theme.accent(0.44));
    imgui.PushStyleColor(ImGuiCol_Text, selected and UI.UI_ACCENT_TEXT or UI.UI_MUTED);
    local clicked = imgui.Button(label .. '##' .. id);
    imgui.PopStyleColor(4);
    imgui.PopStyleVar(2);
    if tooltip ~= nil then theme.tip(tooltip); end
    return clicked;
end

-- On / off button: accent fill and underline when selected.
function theme.toggle_button(label, id, selected, size)
    local UI = theme;
    if selected then
        imgui.PushStyleColor(ImGuiCol_Button, theme.accent(0.30));
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, theme.accent(0.36));
        imgui.PushStyleColor(ImGuiCol_ButtonActive, theme.accent(0.44));
        imgui.PushStyleColor(ImGuiCol_Text, UI.UI_WHITE);
    else
        imgui.PushStyleColor(ImGuiCol_Button, UI.UI_CONTROL);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, UI.UI_CONTROL_HOVER);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, UI.UI_CONTROL_ACTIVE);
        imgui.PushStyleColor(ImGuiCol_Text, UI.UI_TEXT);
    end
    local clicked;
    if size then clicked = imgui.Button(label .. '##' .. id, size); else clicked = imgui.Button(label .. '##' .. id); end
    if selected then theme.draw_item_underline(); end
    imgui.PopStyleColor(4);
    return clicked;
end

-- Row of styled tabs; returns the selected index.
function theme.tab_row(tabs, selected, id_prefix)
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 12, 6 });
    for index, label in ipairs(tabs) do
        if index > 1 then imgui.SameLine(0, 4); end
        if theme.styled_tab(label, id_prefix .. tostring(index), index == selected) then selected = index; end
    end
    imgui.PopStyleVar(1);
    imgui.Spacing();
    imgui.Separator();
    imgui.Spacing();
    return selected;
end

-- ColorEdit without the number boxes.
function theme.color_edit(label, tbl, with_alpha)
    if with_alpha then
        return imgui.ColorEdit4(label, tbl, ImGuiColorEditFlags_NoInputs or 0);
    end
    return imgui.ColorEdit3(label, tbl, ImGuiColorEditFlags_NoInputs or 0);
end

-- ============================================================================
-- Text with effects (draw list; a few extra AddText passes)
-- ============================================================================

theme.EFFECTS = {
    { key = 'none', label = 'None' },
    { key = 'shadow', label = 'Shadow' },
    { key = 'outline', label = 'Outline' },
    { key = 'both', label = 'Outline + Shadow' },
    { key = 'glow', label = 'Glow' },
};

function theme.draw_fx_text(dl, x, y, color, text)
    local font, size = imgui.GetFont(), imgui.GetFontSize();
    local g = G or {};
    local eff = g.text_effect or 'shadow';
    if eff ~= 'none' then
        local ec = g.effect_color or { 0, 0, 0 };
        local a = (tonumber(g.effect_opacity) or 0.85) * (color[4] or 1.0);
        local col = imgui.GetColorU32({ ec[1], ec[2], ec[3], a });
        if eff == 'outline' or eff == 'both' then
            dl:AddText(font, size, { x - 1, y }, col, text);
            dl:AddText(font, size, { x + 1, y }, col, text);
            dl:AddText(font, size, { x, y - 1 }, col, text);
            dl:AddText(font, size, { x, y + 1 }, col, text);
        end
        if eff == 'shadow' or eff == 'both' then
            dl:AddText(font, size, { x + 1, y + 1 }, col, text);
            if eff == 'shadow' then
                dl:AddText(font, size, { x + 2, y + 2 }, imgui.GetColorU32({ ec[1], ec[2], ec[3], a * 0.45 }), text);
            end
        end
        if eff == 'glow' then
            local gcol = imgui.GetColorU32({ ec[1], ec[2], ec[3], a * 0.35 });
            for ox = -2, 2 do
                for oy = -2, 2 do
                    if ox ~= 0 or oy ~= 0 then dl:AddText(font, size, { x + ox, y + oy }, gcol, text); end
                end
            end
        end
    end
    dl:AddText(font, size, { x, y }, imgui.GetColorU32(color), text);
end

return theme;
