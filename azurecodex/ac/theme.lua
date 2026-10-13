--[[
    Azure Codex - ac/theme.lua

    Colors and themes (Midnight, Abyss, Twilight, Golden, Garnet, Silver) and
    small shared widgets (toggle buttons, styled tabs, manual window drag).
]]

-- Azure Codex theme palette: midnight blue (#020035) base with the
-- configurable Header / Accent color used for highlights.
MUTED = { 0.60, 0.62, 0.78, 1.00 };
TEXT = { 0.92, 0.93, 0.98, 1.00 };
TITLE = { 0.004, 0.000, 0.125, 1.00 };
TITLE_ACTIVE = { 0.022, 0.012, 0.270, 1.00 };
BORDER = { 0.20, 0.19, 0.50, 0.85 };
CONTROL = { 0.045, 0.035, 0.310, 1.00 };
CONTROL_HOVER = { 0.085, 0.075, 0.420, 1.00 };
CONTROL_ACTIVE = { 0.120, 0.110, 0.520, 1.00 };
POPUP = { 0.012, 0.006, 0.165, 0.98 };
TABLE_HEADER = { 0.030, 0.022, 0.290, 1.00 };
TRANSPARENT = { 0.00, 0.00, 0.00, 0.00 };
WHITE = { 1.00, 1.00, 1.00, 1.00 };

-- Window surface themes (1.12.0). Midnight is the original look. Picking a
-- theme also sets the Window Color and Header / Accent color, which stay
-- editable afterwards in Config.
AC_THEMES = {
    midnight = {
        label = 'Midnight',
        background = { 0.004, 0.000, 0.133 },
        header = { 0.38, 0.78, 1.00 },
        muted = { 0.60, 0.62, 0.78 },
        title = { 0.004, 0.000, 0.125 },
        title_active = { 0.022, 0.012, 0.270 },
        border = { 0.20, 0.19, 0.50 },
        control = { 0.045, 0.035, 0.310 },
        control_hover = { 0.085, 0.075, 0.420 },
        control_active = { 0.120, 0.110, 0.520 },
        popup = { 0.012, 0.006, 0.165 },
        table_header = { 0.030, 0.022, 0.290 },
    },
    abyss = {
        label = 'Abyss',
        background = { 0.000, 0.040, 0.060 },
        header = { 0.36, 0.86, 0.86 },
        muted = { 0.58, 0.72, 0.76 },
        title = { 0.000, 0.035, 0.055 },
        title_active = { 0.000, 0.090, 0.130 },
        border = { 0.12, 0.36, 0.42 },
        control = { 0.020, 0.140, 0.190 },
        control_hover = { 0.040, 0.210, 0.270 },
        control_active = { 0.060, 0.280, 0.350 },
        popup = { 0.000, 0.050, 0.075 },
        table_header = { 0.010, 0.110, 0.150 },
    },
    twilight = {
        label = 'Twilight',
        background = { 0.055, 0.012, 0.085 },
        header = { 0.80, 0.62, 1.00 },
        muted = { 0.74, 0.64, 0.80 },
        title = { 0.050, 0.010, 0.080 },
        title_active = { 0.130, 0.040, 0.200 },
        border = { 0.40, 0.22, 0.52 },
        control = { 0.170, 0.060, 0.250 },
        control_hover = { 0.240, 0.100, 0.340 },
        control_active = { 0.300, 0.140, 0.420 },
        popup = { 0.070, 0.020, 0.100 },
        table_header = { 0.140, 0.050, 0.210 },
    },
};
AC_THEMES.golden = {
    -- Near-black with warm gold.
    label = 'Golden',
    background = { 0.051, 0.051, 0.051 },
    header = { 0.957, 0.855, 0.592 },
    muted = { 0.60, 0.58, 0.54 },
    title = { 0.035, 0.033, 0.030 },
    title_active = { 0.137, 0.125, 0.106 },
    border = { 0.300, 0.275, 0.235 },
    control = { 0.098, 0.090, 0.075 },
    control_hover = { 0.137, 0.125, 0.106 },
    control_active = { 0.176, 0.161, 0.137 },
    popup = { 0.070, 0.065, 0.055 },
    table_header = { 0.120, 0.110, 0.090 },
};
AC_THEMES.garnet = {
    -- ScrollingCombatLog's subtle Garnet red on graphite.
    label = 'Garnet',
    background = { 0.035, 0.035, 0.040 },
    header = { 0.800, 0.380, 0.430 },
    -- Garnet only: trait labels and "not reached yet" use sand / amber so
    -- they don't blend into the red accent and the red Unlearnable color.
    info = { 0.880, 0.820, 0.710 },
    partial = { 0.960, 0.690, 0.330 },
    muted = { 0.62, 0.62, 0.66 },
    title = { 0.020, 0.020, 0.022 },
    title_active = { 0.094, 0.035, 0.043 },
    border = { 0.275, 0.118, 0.133 },
    control = { 0.100, 0.100, 0.110 },
    control_hover = { 0.160, 0.160, 0.180 },
    control_active = { 0.220, 0.220, 0.250 },
    popup = { 0.050, 0.050, 0.056 },
    table_header = { 0.130, 0.060, 0.070 },
};
AC_THEMES.silver = {
    -- Cool graphite with silver.
    label = 'Silver',
    background = { 0.045, 0.048, 0.055 },
    header = { 0.800, 0.830, 0.880 },
    muted = { 0.60, 0.62, 0.66 },
    title = { 0.030, 0.032, 0.036 },
    title_active = { 0.130, 0.140, 0.160 },
    border = { 0.360, 0.380, 0.420 },
    control = { 0.110, 0.115, 0.130 },
    control_hover = { 0.170, 0.180, 0.200 },
    control_active = { 0.230, 0.240, 0.270 },
    popup = { 0.060, 0.065, 0.075 },
    table_header = { 0.140, 0.150, 0.170 },
};

AC_THEME_ORDER = { 'midnight', 'abyss', 'twilight', 'golden', 'garnet', 'silver' };

function set_rgb(dst, rgb)
    dst[1] = rgb[1]; dst[2] = rgb[2]; dst[3] = rgb[3];
end

-- Updates the surface color tables in place (they are shared by push_theme).
-- Optional per-theme colors for trait labels (info) and unreached traits /
-- over-limit picks (partial). nil = use the accent / Unlearnable colors.
THEME_INFO = nil;
THEME_PARTIAL = nil;

function apply_theme_surfaces(key)
    local theme = AC_THEMES[tostring(key or 'midnight')] or AC_THEMES.midnight;
    THEME_INFO = theme.info and { theme.info[1], theme.info[2], theme.info[3], 1.0 } or nil;
    THEME_PARTIAL = theme.partial and { theme.partial[1], theme.partial[2], theme.partial[3], 1.0 } or nil;
    set_rgb(MUTED, theme.muted);
    set_rgb(TITLE, theme.title);
    set_rgb(TITLE_ACTIVE, theme.title_active);
    set_rgb(BORDER, theme.border);
    set_rgb(CONTROL, theme.control);
    set_rgb(CONTROL_HOVER, theme.control_hover);
    set_rgb(CONTROL_ACTIVE, theme.control_active);
    set_rgb(POPUP, theme.popup);
    set_rgb(TABLE_HEADER, theme.table_header);
end
state.apply_theme_surfaces = apply_theme_surfaces;
apply_theme_surfaces(state.theme);

-- Switching theme: surfaces plus the theme's window / accent colors.
function select_theme(key)
    local theme = AC_THEMES[tostring(key or '')];
    if theme == nil then return; end
    state.theme = key;
    apply_theme_surfaces(key);
    set_rgb(state.background, theme.background);
    set_rgb(state.header_color, theme.header);
    state.settings_dirty = true;
end

-- Trait label color (BLUPrints side panels).
function info_color()
    return THEME_INFO or state.header_color;
end

-- Unreached trait / over-limit color (BLUPrints side panels).
function partial_color()
    return THEME_PARTIAL or state.unknown_color;
end

-- Returns the configured accent color with an optional alpha multiplier.
function accent(alpha_mul)
    local c = state.header_color;
    return { c[1], c[2], c[3], (c[4] or 1.0) * (alpha_mul or 1.0) };
end

-- Draws a short accent bar along the bottom edge of the last drawn item.

function draw_item_underline()
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
        imgui.GetColorU32(accent()),
        1.0
    );
end

-- Button that shows an on/off state: accent-tinted fill and underline when
-- selected, standard midnight control when not. Returns true when clicked.
function draw_toggle_button(label, id, selected, disabled)
    if selected then
        imgui.PushStyleColor(ImGuiCol_Button, accent(0.26));
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, accent(0.32));
        imgui.PushStyleColor(ImGuiCol_ButtonActive, accent(0.40));
        imgui.PushStyleColor(ImGuiCol_Text, WHITE);
    else
        imgui.PushStyleColor(ImGuiCol_Button, CONTROL);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, CONTROL_HOVER);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, CONTROL_ACTIVE);
        imgui.PushStyleColor(ImGuiCol_Text, TEXT);
    end

    local clicked = false;
    if disabled then
        imgui.BeginDisabled();
        imgui.Button(label .. '##' .. id);
        imgui.EndDisabled();
    else
        clicked = imgui.Button(label .. '##' .. id);
    end

    if selected and not disabled then
        draw_item_underline();
    end

    imgui.PopStyleColor(4);
    return clicked;
end

-- Flat tab button for the Config window: transparent with accent text and
-- underline when selected, subdued when not. Returns true when clicked.
function draw_styled_tab(label, id, selected)
    if selected then
        imgui.PushStyleColor(ImGuiCol_Button, accent(0.12));
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, accent(0.16));
        imgui.PushStyleColor(ImGuiCol_ButtonActive, accent(0.20));
        imgui.PushStyleColor(ImGuiCol_Text, accent());
    else
        imgui.PushStyleColor(ImGuiCol_Button, { CONTROL[1], CONTROL[2], CONTROL[3], 0.55 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, CONTROL_HOVER);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, CONTROL_ACTIVE);
        imgui.PushStyleColor(ImGuiCol_Text, MUTED);
    end

    local clicked = imgui.Button(label .. '##' .. id);

    if selected then
        draw_item_underline();
    end

    imgui.PopStyleColor(4);
    return clicked;
end

-- Drag a window from any empty spot, title bar or not. ImGui's own move
-- did not work for Zone Info / Spell Locations; if ImGui does start its own
-- move, this backs off so the window doesn't move twice as fast.
-- The new position is applied with SetNextWindowPos before the next Begin
-- (call window_drag_apply right before Begin).
window_drag_state = {};

function window_drag_apply(key)
    local st = window_drag_state[key];
    if st ~= nil and st.next ~= nil then
        imgui.SetNextWindowPos(st.next, { 0, 0 });
        st.next = nil;
    end
end

function window_drag(key, locked)
    if locked then
        window_drag_state[key] = nil;
        return;
    end
    local st = window_drag_state[key];
    if st ~= nil then
        if not imgui.IsMouseDown(0) or imgui.IsAnyItemActive() then
            window_drag_state[key] = nil;
            return;
        end
        local delta = imgui.GetIO().MouseDelta;
        local dx = delta and tonumber(delta.x) or 0;
        local dy = delta and tonumber(delta.y) or 0;
        if dx ~= 0 or dy ~= 0 then
            local wx, wy = imgui.GetWindowPos();
            st.next = { (tonumber(wx) or 0) + dx, (tonumber(wy) or 0) + dy };
        end
        return;
    end
    if imgui.IsWindowHovered(0) and imgui.IsMouseClicked(0)
        and not imgui.IsAnyItemHovered() and not imgui.IsAnyItemActive() then
        window_drag_state[key] = { next = nil };
    end
end

-- Aligns a plain text label with the frame padding of the controls beside it.
function align_label()
    if imgui.AlignTextToFramePadding ~= nil then
        imgui.AlignTextToFramePadding();
    end
end

-- Text box that is skipped by Tab focus cycling, so pressing Tab in game
-- (targeting) never jumps into an Azure Codex search box. Click it to type.
function input_text_no_tab(label, buffer, size)
    local pushed = false;
    if imgui.PushItemFlag ~= nil and ImGuiItemFlags_NoTabStop ~= nil then
        imgui.PushItemFlag(ImGuiItemFlags_NoTabStop, true);
        pushed = true;
    end
    local changed = imgui.InputText(label, buffer, size);
    if pushed then
        imgui.PopItemFlag();
    end
    return changed;
end
