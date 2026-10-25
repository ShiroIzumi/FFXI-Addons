--[[
    WhatsMyDamage - core/theme.lua (same as Triage)

    House look: black base with one accent color. Eleven themes, the same
    in every Izumi addon (Silver is the default here), the ImGui style stack, small widgets (tabs, toggles, section
    headers, help markers) and draw-list text with an optional shadow or
    outline at any size.

    The UI_* color tables are updated in place when the theme changes, so
    other files can keep references to them.
]]

require('common');
local imgui = require('imgui');

local theme = {};

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
theme.UI_DANGER         = { 0.90, 0.36, 0.36, 1.00 };
theme.UI_GOOD           = { 0.43, 0.80, 0.50, 1.00 };
theme.UI_WARN           = { 0.92, 0.70, 0.32, 1.00 };

-- 0-255 RGB.
--   accent      : fills, underlines, checkmarks, slider grabs, markers
--   text        : headers and selected text
--   title_active: focused title bar
--   border      : window and separator borders
--   bg          : window background (when "Use the theme's background" is on)
--   control...  : optional tinted controls (Midnight)
theme.THEMES = {
    forest   = { label = 'Forest',   accent = { 111, 175, 79 },  text = { 164, 212, 136 }, title_active = { 20, 32, 18 },  border = { 44, 68, 38 },   bg = { 8, 10, 8 } },
    rust     = { label = 'Rust',     accent = { 181, 82, 59 },   text = { 226, 140, 118 }, title_active = { 34, 20, 16 },  border = { 72, 40, 32 },   bg = { 10, 8, 8 } },
    bone     = { label = 'Bone',     accent = { 207, 198, 176 }, text = { 232, 226, 210 }, title_active = { 28, 27, 25 },  border = { 64, 62, 56 },   bg = { 10, 10, 9 } },
    copper   = { label = 'Copper',   accent = { 196, 128, 80 },  text = { 224, 166, 120 }, title_active = { 24, 15, 9 },   border = { 72, 48, 32 },   bg = { 9, 9, 10 } },
    gold     = { label = 'Gold',     accent = { 214, 178, 92 },  text = { 240, 212, 148 }, title_active = { 34, 28, 14 },  border = { 76, 64, 36 },   bg = { 10, 9, 8 } },
    garnet   = { label = 'Garnet',   accent = { 168, 52, 62 },   text = { 214, 112, 120 }, title_active = { 24, 9, 11 },   border = { 70, 30, 34 },   bg = { 9, 9, 10 } },
    fuchsia  = { label = 'Fuchsia',  accent = { 214, 72, 170 },  text = { 240, 150, 214 }, title_active = { 30, 8, 24 },   border = { 82, 30, 66 },   bg = { 10, 8, 10 } },
    silver   = { label = 'Silver',   accent = { 176, 188, 204 }, text = { 226, 232, 240 }, title_active = { 28, 30, 34 },  border = { 66, 72, 82 },   bg = { 9, 9, 10 } },
    amethyst = { label = 'Amethyst', accent = { 150, 118, 214 }, text = { 184, 160, 236 }, title_active = { 16, 11, 26 },  border = { 52, 42, 78 },   bg = { 9, 8, 12 } },
    emerald  = { label = 'Emerald',  accent = { 60, 180, 110 },  text = { 132, 222, 166 }, title_active = { 10, 28, 18 },  border = { 30, 70, 46 },   bg = { 8, 10, 9 } },
    midnight = { label = 'Midnight', accent = { 104, 148, 226 }, text = { 168, 196, 242 }, title_active = { 14, 22, 44 },  border = { 42, 60, 100 },  bg = { 9, 14, 28 },
                 control = { 20, 28, 48 }, control_hover = { 30, 42, 70 }, control_active = { 40, 56, 92 }, title = { 6, 10, 22 }, popup = { 10, 16, 32 } },
};
theme.ORDER = { 'forest', 'rust', 'bone', 'copper', 'gold', 'garnet', 'fuchsia', 'silver', 'amethyst', 'emerald', 'midnight' };
theme.DEFAULT = 'silver';

local NEUTRAL = {
    control = { 25.5, 25.5, 28.05 }, control_hover = { 40.8, 40.8, 45.9 }, control_active = { 56.1, 56.1, 63.75 },
    title = { 5.1, 5.1, 5.61 }, popup = { 12.75, 12.75, 14.28 },
};

-- Active profile (theme, background, opacity, text effect). Set by izclock.lua.
local P = nil;
function theme.set_profile(p) P = p; theme.applied = nil; end

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

function theme.with_alpha(c, a)
    return { c[1], c[2], c[3], (c[4] or 1.0) * a };
end

-- Window background: the theme's own or the custom color, at the chosen
-- opacity (opacity_override lets a window use its own value).
function theme.background(opacity_override)
    local p = P or {};
    local key = theme.key(p.theme);
    local op = tonumber(opacity_override) or tonumber(p.opacity) or 0.90;
    if p.use_theme_bg ~= false then
        local b = theme.THEMES[key].bg;
        return { b[1] / 255, b[2] / 255, b[3] / 255, op };
    end
    local c = p.background or { 0.035, 0.035, 0.040 };
    return { tonumber(c[1]) or 0.035, tonumber(c[2]) or 0.035, tonumber(c[3]) or 0.040, op };
end

-- ============================================================================
-- TAB never moves the keyboard focus into this addon's text fields: every
-- window is drawn with "no tab stop" pushed (pushed before Begin, popped
-- after End, so it covers the whole window).
-- ============================================================================

local notab_stack = {};

function theme.notab_push()
    local kind = 0;
    if imgui.PushItemFlag ~= nil and ImGuiItemFlags_NoTabStop ~= nil then
        if pcall(imgui.PushItemFlag, ImGuiItemFlags_NoTabStop, true) then kind = 1; end
    end
    if kind == 0 and imgui.PushTabStop ~= nil then
        if pcall(imgui.PushTabStop, false) then kind = 2; end
    end
    if kind == 0 and imgui.PushAllowKeyboardFocus ~= nil then
        if pcall(imgui.PushAllowKeyboardFocus, false) then kind = 3; end
    end
    notab_stack[#notab_stack + 1] = kind;
end

function theme.notab_pop()
    local kind = table.remove(notab_stack);
    if kind == 1 then pcall(imgui.PopItemFlag);
    elseif kind == 2 then pcall(imgui.PopTabStop);
    elseif kind == 3 then pcall(imgui.PopAllowKeyboardFocus); end
end

-- ============================================================================
-- Style stack
-- ============================================================================

local stack = {};

-- bg: background color (nil = profile background). scale: spacing multiplier.
-- opts: { border = bool, rounding = number, padding = number }
function theme.push(bg, scale, opts)
    theme.apply(P and P.theme);
    bg = bg or theme.background();
    scale = tonumber(scale) or 1.0;
    opts = opts or {};
    local UI = theme;
    local nc, nv = 0, 0;
    local function c(idx, v) if idx ~= nil then imgui.PushStyleColor(idx, v); nc = nc + 1; end end
    local function v(idx, val) if idx ~= nil then imgui.PushStyleVar(idx, val); nv = nv + 1; end end

    c(ImGuiCol_WindowBg, { bg[1], bg[2], bg[3], bg[4] or 0.90 });
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
    c(ImGuiCol_PlotHistogram, UI.UI_ACCENT);

    v(ImGuiStyleVar_WindowRounding, tonumber(opts.rounding) or 6.0);
    v(ImGuiStyleVar_ChildRounding, 4.0);
    v(ImGuiStyleVar_FrameRounding, 4.0);
    v(ImGuiStyleVar_PopupRounding, 4.0);
    v(ImGuiStyleVar_ScrollbarRounding, 6.0);
    v(ImGuiStyleVar_GrabRounding, 4.0);
    v(ImGuiStyleVar_ScrollbarSize, 11.0);
    local pad = tonumber(opts.padding);
    if pad ~= nil then
        v(ImGuiStyleVar_WindowPadding, { pad * scale, pad * scale });
    else
        v(ImGuiStyleVar_WindowPadding, { 12 * scale, 10 * scale });
    end
    v(ImGuiStyleVar_FramePadding, { 8 * scale, 4 * scale });
    v(ImGuiStyleVar_ItemSpacing, { 8 * scale, 5 * scale });
    v(ImGuiStyleVar_ItemInnerSpacing, { 6 * scale, 4 * scale });
    if opts.border ~= nil then
        v(ImGuiStyleVar_WindowBorderSize, opts.border and 1.0 or 0.0);
    end
    v(ImGuiStyleVar_WindowMinSize, { 8, 8 });

    stack[#stack + 1] = { nc, nv };
    theme.notab_push();
end

function theme.pop()
    local e = table.remove(stack);
    if e == nil then return; end
    theme.notab_pop();
    if e[2] > 0 then imgui.PopStyleVar(e[2]); end
    if e[1] > 0 then imgui.PopStyleColor(e[1]); end
end

-- ============================================================================
-- Text on the draw list, at any size, with the profile's text effect
-- ============================================================================

-- Width / height of text at a given pixel size (current font).
function theme.measure(text, size)
    text = tostring(text or '');
    local cur = imgui.GetFontSize();
    local w, h = imgui.CalcTextSize(text);
    w = tonumber(w) or 0; h = tonumber(h) or cur;
    if size == nil or cur == nil or cur <= 0 then return w, h; end
    local k = size / cur;
    return w * k, h * k;
end

theme.EFFECTS = {
    { key = 'none', label = 'None' },
    { key = 'shadow', label = 'Shadow' },
    { key = 'outline', label = 'Outline' },
    { key = 'both', label = 'Outline + Shadow' },
};

-- Set by a window that has its own text effect (not used by WhatsMyDamage), cleared after.
theme.effect = nil;

function theme.text(dl, x, y, color, text, size)
    text = tostring(text or '');
    if text == '' or dl == nil then return; end
    local font = imgui.GetFont();
    size = size or imgui.GetFontSize();
    local eff = theme.effect or (P and P.text_effect) or 'shadow';
    local a = (color[4] or 1.0) * 0.85;
    if eff == 'outline' or eff == 'both' then
        local col = imgui.GetColorU32({ 0, 0, 0, a });
        dl:AddText(font, size, { x - 1, y }, col, text);
        dl:AddText(font, size, { x + 1, y }, col, text);
        dl:AddText(font, size, { x, y - 1 }, col, text);
        dl:AddText(font, size, { x, y + 1 }, col, text);
    end
    if eff == 'shadow' or eff == 'both' then
        dl:AddText(font, size, { x + 1, y + 1 }, imgui.GetColorU32({ 0, 0, 0, a }), text);
    end
    dl:AddText(font, size, { x, y }, imgui.GetColorU32(color), text);
end

-- ============================================================================
-- Widgets
-- ============================================================================

function theme.align_label()
    if imgui.AlignTextToFramePadding ~= nil then imgui.AlignTextToFramePadding(); end
end

function theme.tooltip(text)
    if text == nil or text == '' then return; end
    imgui.BeginTooltip();
    imgui.PushTextWrapPos(380);
    imgui.TextUnformatted(text);
    imgui.PopTextWrapPos();
    imgui.EndTooltip();
end

function theme.tip(text)
    if imgui.IsItemHovered() then theme.tooltip(text); end
end

function theme.help_marker(text)
    imgui.SameLine();
    imgui.TextDisabled('(?)');
    theme.tip(text);
end

function theme.section_header(title)
    imgui.Spacing();
    imgui.TextColored(theme.UI_ACCENT_TEXT, title);
    imgui.PushStyleColor(ImGuiCol_Separator, theme.accent(0.35));
    imgui.Separator();
    imgui.PopStyleColor(1);
    imgui.Spacing();
end

function theme.draw_item_underline()
    if imgui.GetItemRectMin == nil then return; end
    local min_x = imgui.GetItemRectMin();
    local max_x, max_y = imgui.GetItemRectMax();
    min_x = tonumber(min_x); max_x = tonumber(max_x); max_y = tonumber(max_y);
    if min_x == nil or max_x == nil or max_y == nil then return; end
    imgui.GetWindowDrawList():AddRectFilled({ min_x + 4, max_y - 2 }, { max_x - 4, max_y }, imgui.GetColorU32(theme.UI_ACCENT), 1.0);
end

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
function theme.tab_row(tabs, selected, id_prefix, scale)
    scale = scale or 1.0;
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 11 * scale, 5 * scale });
    for index, label in ipairs(tabs) do
        if index > 1 then imgui.SameLine(0, 4 * scale); end
        if theme.styled_tab(label, id_prefix .. tostring(index), index == selected) then selected = index; end
    end
    imgui.PopStyleVar(1);
    imgui.Spacing();
    imgui.Separator();
    imgui.Spacing();
    return selected;
end

-- A choice between a few options shown as toggle buttons. Returns the new
-- value (or the old one when nothing was clicked).
function theme.choice(id, value, options)
    for i, opt in ipairs(options) do
        if i > 1 then imgui.SameLine(0, 4); end
        if theme.toggle_button(opt.label, id .. '_' .. tostring(opt.key), value == opt.key) then
            value = opt.key;
        end
        if opt.tip then theme.tip(opt.tip); end
    end
    return value;
end

return theme;
