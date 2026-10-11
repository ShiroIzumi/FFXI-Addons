require('common');
local imgui = require('imgui');
local core_mod = require('scl.core');
local settings = core_mod.settings;

-- ============================================================================
-- UI theme: black base, red accent
-- ============================================================================

local UI_BG             = { 0.035, 0.035, 0.040, 0.97 };
local UI_TITLE          = { 0.020, 0.020, 0.022, 1.00 };
local UI_TITLE_ACTIVE   = { 0.094, 0.035, 0.043, 1.00 };
local UI_POPUP          = { 0.050, 0.050, 0.056, 0.98 };
local UI_BORDER         = { 0.275, 0.118, 0.133, 0.90 };
local UI_CONTROL        = { 0.100, 0.100, 0.110, 1.00 };
local UI_CONTROL_HOVER  = { 0.160, 0.160, 0.180, 1.00 };
local UI_CONTROL_ACTIVE = { 0.220, 0.220, 0.250, 1.00 };
local UI_TEXT           = { 0.93, 0.93, 0.95, 1.00 };
local UI_ACCENT         = { 0.659, 0.204, 0.243, 1.00 };
local UI_ACCENT_TEXT    = { 0.839, 0.439, 0.471, 1.00 };
local UI_RED            = { 1.00, 0.42, 0.42, 1.00 };
local UI_GOLD           = { 1.00, 0.80, 0.28, 1.00 };
local UI_MUTED          = { 0.62, 0.62, 0.66, 1.00 };
local UI_TRANSPARENT    = { 0.00, 0.00, 0.00, 0.00 };
local UI_WHITE          = { 1.00, 1.00, 1.00, 1.00 };

-- Config window themes. Values are 0-255 RGB.
--   accent      : fills, underlines, checkmarks, slider grabs
--   text        : headers and selected-tab text (lighter, easier to read)
--   title_active: focused title bar
--   border      : window / separator border
local UI_THEMES = {
    garnet = {
        label = 'Garnet',
        accent = { 168, 52, 62 }, text = { 214, 112, 120 },
        title_active = { 24, 9, 11 }, border = { 70, 30, 34 },
    },
    copper = {
        label = 'Copper',
        accent = { 196, 128, 80 }, text = { 224, 166, 120 },
        title_active = { 24, 15, 9 }, border = { 72, 48, 32 },
    },
    amethyst = {
        label = 'Amethyst',
        accent = { 150, 118, 214 }, text = { 184, 160, 236 },
        title_active = { 16, 11, 26 }, border = { 52, 42, 78 },
    },
};

local UI_THEME_ORDER = { 'garnet', 'copper', 'amethyst' };
local applied_theme = nil;

local function set_rgb(dst, rgb)
    dst[1] = rgb[1] / 255;
    dst[2] = rgb[2] / 255;
    dst[3] = rgb[3] / 255;
end

-- Updates the shared UI color tables in place for the selected theme.
local function apply_ui_theme()
    local key = tostring(settings.ui_theme or 'garnet'):lower();
    if not UI_THEMES[key] then
        key = 'garnet';
    end
    if applied_theme == key then
        return;
    end

    local theme = UI_THEMES[key];
    set_rgb(UI_ACCENT, theme.accent);
    set_rgb(UI_ACCENT_TEXT, theme.text);
    set_rgb(UI_TITLE_ACTIVE, theme.title_active);
    set_rgb(UI_BORDER, theme.border);
    applied_theme = key;
end

local function ui_accent(alpha_mul)
    return { UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], UI_ACCENT[4] * (alpha_mul or 1.0) };
end

-- Each push records how many colors / vars were actually pushed so the
-- matching pop stays balanced even if a constant is missing on an older
-- Ashita build.
local theme_stack = {};

local function push_theme()
    apply_ui_theme();

    local color_count = 0;
    local var_count = 0;

    local function color(index, value)
        if index ~= nil then
            imgui.PushStyleColor(index, value);
            color_count = color_count + 1;
        end
    end

    local function var(index, value)
        if index ~= nil then
            imgui.PushStyleVar(index, value);
            var_count = var_count + 1;
        end
    end

    -- Window surfaces.
    color(ImGuiCol_WindowBg, UI_BG);
    color(ImGuiCol_ChildBg, UI_TRANSPARENT);
    color(ImGuiCol_PopupBg, UI_POPUP);
    color(ImGuiCol_TitleBg, UI_TITLE);
    color(ImGuiCol_TitleBgActive, UI_TITLE_ACTIVE);
    color(ImGuiCol_TitleBgCollapsed, UI_TITLE);
    color(ImGuiCol_Border, UI_BORDER);
    color(ImGuiCol_BorderShadow, UI_TRANSPARENT);

    -- Text.
    color(ImGuiCol_Text, UI_TEXT);
    color(ImGuiCol_TextDisabled, UI_MUTED);
    color(ImGuiCol_TextSelectedBg, ui_accent(0.35));

    -- Inputs, sliders, checkboxes.
    color(ImGuiCol_FrameBg, UI_CONTROL);
    color(ImGuiCol_FrameBgHovered, UI_CONTROL_HOVER);
    color(ImGuiCol_FrameBgActive, UI_CONTROL_ACTIVE);
    color(ImGuiCol_CheckMark, UI_ACCENT);
    color(ImGuiCol_SliderGrab, ui_accent(0.80));
    color(ImGuiCol_SliderGrabActive, UI_ACCENT);

    -- Buttons.
    color(ImGuiCol_Button, UI_CONTROL);
    color(ImGuiCol_ButtonHovered, UI_CONTROL_HOVER);
    color(ImGuiCol_ButtonActive, UI_CONTROL_ACTIVE);

    -- Headers / selectables.
    color(ImGuiCol_Header, ui_accent(0.22));
    color(ImGuiCol_HeaderHovered, ui_accent(0.30));
    color(ImGuiCol_HeaderActive, ui_accent(0.40));

    -- Separators.
    color(ImGuiCol_Separator, UI_BORDER);
    color(ImGuiCol_SeparatorHovered, ui_accent(0.60));
    color(ImGuiCol_SeparatorActive, UI_ACCENT);

    -- Scrollbars.
    color(ImGuiCol_ScrollbarBg, { 0.00, 0.00, 0.00, 0.20 });
    color(ImGuiCol_ScrollbarGrab, UI_CONTROL_HOVER);
    color(ImGuiCol_ScrollbarGrabHovered, UI_CONTROL_ACTIVE);
    color(ImGuiCol_ScrollbarGrabActive, ui_accent(0.80));

    -- Resize grip.
    color(ImGuiCol_ResizeGrip, ui_accent(0.20));
    color(ImGuiCol_ResizeGripHovered, ui_accent(0.45));
    color(ImGuiCol_ResizeGripActive, ui_accent(0.70));

    -- Shape and spacing: rounded corners and roomier padding.
    var(ImGuiStyleVar_WindowRounding, 6.0);
    var(ImGuiStyleVar_ChildRounding, 4.0);
    var(ImGuiStyleVar_FrameRounding, 4.0);
    var(ImGuiStyleVar_PopupRounding, 4.0);
    var(ImGuiStyleVar_ScrollbarRounding, 6.0);
    var(ImGuiStyleVar_GrabRounding, 4.0);
    var(ImGuiStyleVar_ScrollbarSize, 11.0);
    var(ImGuiStyleVar_WindowPadding, { 12, 10 });
    var(ImGuiStyleVar_FramePadding, { 8, 4 });
    var(ImGuiStyleVar_ItemSpacing, { 8, 5 });
    var(ImGuiStyleVar_ItemInnerSpacing, { 6, 4 });

    theme_stack[#theme_stack + 1] = { color_count, var_count };
end

local function pop_theme()
    local entry = table.remove(theme_stack);
    if entry == nil then return; end

    if entry[2] > 0 then imgui.PopStyleVar(entry[2]); end
    if entry[1] > 0 then imgui.PopStyleColor(entry[1]); end
end

-- Draws a short accent bar along the bottom edge of the last drawn item.
local function draw_item_underline()
    if imgui.GetItemRectMin == nil or imgui.GetItemRectMax == nil then return; end

    local min_x = imgui.GetItemRectMin();
    local max_x, max_y = imgui.GetItemRectMax();
    min_x = tonumber(min_x); max_x = tonumber(max_x); max_y = tonumber(max_y);
    if min_x == nil or max_x == nil or max_y == nil then return; end

    local draw_list = imgui.GetWindowDrawList();
    if draw_list == nil then return; end

    draw_list:AddRectFilled(
        { min_x + 4, max_y - 2 },
        { max_x - 4, max_y },
        imgui.GetColorU32(UI_ACCENT),
        1.0
    );
end

-- Button with an on/off look: red-tinted fill and underline when selected.
-- Returns true when clicked.
local function draw_toggle_button(label, id, selected)
    if selected then
        imgui.PushStyleColor(ImGuiCol_Button, ui_accent(0.30));
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, ui_accent(0.36));
        imgui.PushStyleColor(ImGuiCol_ButtonActive, ui_accent(0.44));
        imgui.PushStyleColor(ImGuiCol_Text, UI_WHITE);
    else
        imgui.PushStyleColor(ImGuiCol_Button, UI_CONTROL);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, UI_CONTROL_HOVER);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, UI_CONTROL_ACTIVE);
        imgui.PushStyleColor(ImGuiCol_Text, UI_TEXT);
    end

    local clicked = imgui.Button(label .. '##' .. id);

    if selected then
        draw_item_underline();
    end

    imgui.PopStyleColor(4);
    return clicked;
end

-- Flat tab button: red text and underline when selected, subdued otherwise.
local function draw_styled_tab(label, id, selected)
    if selected then
        imgui.PushStyleColor(ImGuiCol_Button, ui_accent(0.14));
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, ui_accent(0.18));
        imgui.PushStyleColor(ImGuiCol_ButtonActive, ui_accent(0.22));
        imgui.PushStyleColor(ImGuiCol_Text, UI_ACCENT_TEXT);
    else
        imgui.PushStyleColor(ImGuiCol_Button, { UI_CONTROL[1], UI_CONTROL[2], UI_CONTROL[3], 0.55 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, UI_CONTROL_HOVER);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, UI_CONTROL_ACTIVE);
        imgui.PushStyleColor(ImGuiCol_Text, UI_MUTED);
    end

    local clicked = imgui.Button(label .. '##' .. id);

    if selected then
        draw_item_underline();
    end

    imgui.PopStyleColor(4);
    return clicked;
end

local function align_label()
    if imgui.AlignTextToFramePadding ~= nil then
        imgui.AlignTextToFramePadding();
    end
end

local function help_marker(text_value)
    imgui.SameLine();
    imgui.TextDisabled('(?)');
    if imgui.IsItemHovered() then
        imgui.BeginTooltip();
        imgui.PushTextWrapPos(420);
        imgui.TextUnformatted(text_value);
        imgui.PopTextWrapPos();
        imgui.EndTooltip();
    end
end

local function section_header(title, color)
    imgui.Spacing();
    imgui.TextColored(color or UI_ACCENT_TEXT, title);
    imgui.PushStyleColor(ImGuiCol_Separator, ui_accent(0.35));
    imgui.Separator();
    imgui.PopStyleColor(1);
    imgui.Spacing();
end

return {
    UI_BG = UI_BG,
    UI_TITLE = UI_TITLE,
    UI_TITLE_ACTIVE = UI_TITLE_ACTIVE,
    UI_POPUP = UI_POPUP,
    UI_BORDER = UI_BORDER,
    UI_CONTROL = UI_CONTROL,
    UI_CONTROL_HOVER = UI_CONTROL_HOVER,
    UI_CONTROL_ACTIVE = UI_CONTROL_ACTIVE,
    UI_TEXT = UI_TEXT,
    UI_ACCENT = UI_ACCENT,
    UI_ACCENT_TEXT = UI_ACCENT_TEXT,
    UI_RED = UI_RED,
    UI_GOLD = UI_GOLD,
    UI_MUTED = UI_MUTED,
    UI_TRANSPARENT = UI_TRANSPARENT,
    UI_WHITE = UI_WHITE,
    UI_THEMES = UI_THEMES,
    UI_THEME_ORDER = UI_THEME_ORDER,
    ui_accent = ui_accent,
    push_theme = push_theme,
    pop_theme = pop_theme,
    draw_item_underline = draw_item_underline,
    draw_toggle_button = draw_toggle_button,
    draw_styled_tab = draw_styled_tab,
    align_label = align_label,
    help_marker = help_marker,
    section_header = section_header,
};
