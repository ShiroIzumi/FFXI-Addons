--[[
    addoncontrolpanel - Documented source for GitHub

    This file keeps the original runtime behavior intact while adding
    section-level comments that explain the major systems, persistence,
    rendering, commands, and Ashita v4 integration points.

    Comments are documentation only.
]]--

addon.name    = 'addoncontrolpanel'
addon.author  = 'Izumi (ShiroIzumi)'
addon.version = '2.0.0'
addon.desc    = 'Provides a UI to manage Ashita addons.'
addon.link    = ''

require('common')
local imgui = require('imgui')
local json = require('json')
local settings = require('settings')

-- ============================================================================
-- Paths and tracked-addon persistence
-- ============================================================================
-- acp_config.json stores the user's addon list and optional config commands.
local list_config_path = string.format('%s/config/acp_config.json', AshitaCore:GetInstallPath())

-- ============================================================================
-- Default appearance and window geometry
-- ============================================================================
local defaults = T{
    font_scale = 1.00,

    appearance = T{
        background = T{ 0.018, 0.024, 0.032, 0.94 },
        border = true,
        title_bar = true,
        locked = false,
    },

    window = T{
        x = 180,
        y = 140,
        width = 720,
        height = 620,
    },

    config_window = T{
        x = 930,
        y = 160,
        width = 390,
        height = 350,
    },
}

local ui_config = settings.load(defaults)

-- ============================================================================
-- Runtime ImGui state
-- ============================================================================
-- One-element tables are used for values edited by Ashita ImGui controls.
local state = T{
    visible = { false },
    config_open = { false },

    new_addon = { '' },
    new_config_cmd = { '' },

    selected_index = 1,
    config_edit_buf = { '' },

    font_scale = { tonumber(ui_config.font_scale) or 1.00 },

    background = {
        tonumber(ui_config.appearance and ui_config.appearance.background and ui_config.appearance.background[1]) or defaults.appearance.background[1],
        tonumber(ui_config.appearance and ui_config.appearance.background and ui_config.appearance.background[2]) or defaults.appearance.background[2],
        tonumber(ui_config.appearance and ui_config.appearance.background and ui_config.appearance.background[3]) or defaults.appearance.background[3],
        tonumber(ui_config.appearance and ui_config.appearance.background and ui_config.appearance.background[4]) or defaults.appearance.background[4],
    },

    border = { ui_config.appearance == nil or ui_config.appearance.border ~= false },
    title_bar = { ui_config.appearance == nil or ui_config.appearance.title_bar ~= false },
    locked = { ui_config.appearance ~= nil and ui_config.appearance.locked == true },

    apply_saved_geometry = true,
    last_x = tonumber(ui_config.window and ui_config.window.x) or defaults.window.x,
    last_y = tonumber(ui_config.window and ui_config.window.y) or defaults.window.y,
    last_w = tonumber(ui_config.window and ui_config.window.width) or defaults.window.width,
    last_h = tonumber(ui_config.window and ui_config.window.height) or defaults.window.height,

    apply_saved_config_geometry = true,
    config_last_x = tonumber(ui_config.config_window and ui_config.config_window.x) or defaults.config_window.x,
    config_last_y = tonumber(ui_config.config_window and ui_config.config_window.y) or defaults.config_window.y,
    config_last_w = tonumber(ui_config.config_window and ui_config.config_window.width) or defaults.config_window.width,
    config_last_h = tonumber(ui_config.config_window and ui_config.config_window.height) or defaults.config_window.height,

    geometry_dirty = false,
    config_geometry_dirty = false,
    appearance_dirty = false,
    last_save = 0,
}

local addon_list = {}

local HEAD = { 0.38, 0.78, 1.00, 1.00 }
local GREEN = { 0.30, 1.00, 0.42, 1.00 }
local RED = { 1.00, 0.34, 0.38, 1.00 }
local MUTED = { 0.56, 0.61, 0.68, 1.00 }
local TEXT = { 0.92, 0.94, 0.97, 1.00 }
local TITLE = { 0.030, 0.045, 0.060, 1.00 }
local BORDER = { 0.16, 0.23, 0.31, 1.00 }
local CONTROL = { 0.055, 0.075, 0.100, 1.00 }
local CONTROL_HOVER = { 0.090, 0.145, 0.200, 1.00 }
local CONTROL_ACTIVE = { 0.110, 0.200, 0.285, 1.00 }

local function strip(value)
    return tostring(value or ''):match('^%s*(.-)%s*$')
end

local function contains_name(name)
    for _, entry in ipairs(addon_list) do
        if tostring(entry.name or ''):lower() == tostring(name or ''):lower() then
            return true
        end
    end
    return false
end

local function sort_addons()
    table.sort(addon_list, function(a, b)
        return tostring(a.name or ''):lower() < tostring(b.name or ''):lower()
    end)
end

-- ============================================================================
-- Load/save tracked addon list
-- ============================================================================
local function load_list_config()
    local file = io.open(list_config_path, 'r')
    if not file then
        return
    end

    local raw = file:read('*a')
    file:close()

    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then
        return
    end

    addon_list = {}

    for _, value in ipairs(data) do
        if type(value) == 'string' then
            table.insert(addon_list, { name = value })
        elseif type(value) == 'table' and value.name then
            table.insert(addon_list, {
                name = tostring(value.name),
                config = value.config and tostring(value.config) or nil,
            })
        end
    end

    sort_addons()

    if state.selected_index > #addon_list then
        state.selected_index = math.max(1, #addon_list)
    end
end

local function save_list_config()
    sort_addons()

    local file = io.open(list_config_path, 'w+')
    if not file then
        return
    end

    file:write(json.encode(addon_list))
    file:close()
end

-- ============================================================================
-- UI settings migration and persistence
-- ============================================================================
local function ensure_ui_tables()
    if ui_config.appearance == nil then ui_config.appearance = T{} end
    if ui_config.appearance.background == nil then ui_config.appearance.background = T{} end
    if ui_config.window == nil then ui_config.window = T{} end
    if ui_config.config_window == nil then ui_config.config_window = T{} end
end

local function save_ui_config()
    ensure_ui_tables()

    ui_config.font_scale = state.font_scale[1]

    for i = 1, 4 do
        ui_config.appearance.background[i] = state.background[i]
    end

    ui_config.appearance.border = state.border[1]
    ui_config.appearance.title_bar = state.title_bar[1]
    ui_config.appearance.locked = state.locked[1]

    ui_config.window.x = state.last_x
    ui_config.window.y = state.last_y
    ui_config.window.width = state.last_w
    ui_config.window.height = state.last_h

    ui_config.config_window.x = state.config_last_x
    ui_config.config_window.y = state.config_last_y
    ui_config.config_window.width = state.config_last_w
    ui_config.config_window.height = state.config_last_h

    settings.save()
end

-- ============================================================================
-- Main/config window geometry tracking
-- ============================================================================
local function capture_main_geometry()
    local x, y = imgui.GetWindowPos()
    local w, h = imgui.GetWindowSize()

    x = tonumber(x)
    y = tonumber(y)
    w = tonumber(w)
    h = tonumber(h)

    if not x or not y or not w or not h then
        return
    end

    if math.abs(x - state.last_x) >= 1
        or math.abs(y - state.last_y) >= 1
        or math.abs(w - state.last_w) >= 1
        or math.abs(h - state.last_h) >= 1 then

        state.last_x = x
        state.last_y = y
        state.last_w = w
        state.last_h = h
        state.geometry_dirty = true
    end
end

local function capture_config_geometry()
    local x, y = imgui.GetWindowPos()
    local w, h = imgui.GetWindowSize()

    x = tonumber(x)
    y = tonumber(y)
    w = tonumber(w)
    h = tonumber(h)

    if not x or not y or not w or not h then
        return
    end

    if math.abs(x - state.config_last_x) >= 1
        or math.abs(y - state.config_last_y) >= 1
        or math.abs(w - state.config_last_w) >= 1
        or math.abs(h - state.config_last_h) >= 1 then

        state.config_last_x = x
        state.config_last_y = y
        state.config_last_w = w
        state.config_last_h = h
        state.config_geometry_dirty = true
    end
end

-- ============================================================================
-- Local ImGui theme
-- ============================================================================
-- Styling is scoped to this addon and does not change Ashita globally.
local function push_theme()
    imgui.PushStyleColor(ImGuiCol_WindowBg, {
        state.background[1],
        state.background[2],
        state.background[3],
        state.background[4],
    })
    imgui.PushStyleColor(ImGuiCol_TitleBg, TITLE)
    imgui.PushStyleColor(ImGuiCol_TitleBgActive, TITLE)
    imgui.PushStyleColor(ImGuiCol_Border, BORDER)
    imgui.PushStyleColor(ImGuiCol_Text, TEXT)
    imgui.PushStyleColor(ImGuiCol_FrameBg, CONTROL)
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, CONTROL_HOVER)
    imgui.PushStyleColor(ImGuiCol_FrameBgActive, CONTROL_ACTIVE)
    imgui.PushStyleColor(ImGuiCol_Button, CONTROL)
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, CONTROL_HOVER)
    imgui.PushStyleColor(ImGuiCol_ButtonActive, CONTROL_ACTIVE)
    imgui.PushStyleColor(ImGuiCol_Separator, BORDER)
end

local function pop_theme()
    imgui.PopStyleColor(12)
end

-- ============================================================================
-- Ashita command helpers
-- ============================================================================
local function queue_command(command)
    local chat = AshitaCore:GetChatManager()
    if not chat then
        return
    end
    chat:QueueCommand(1, command)
end

local function normalize_config_command(entry)
    local command = strip(entry.config or '')
    if command == '' then
        command = strip(entry.name or '')
    end

    if command:sub(1, 1) ~= '/' then
        command = '/' .. command
    end

    return command
end

local function reset_window()
    state.last_x = defaults.window.x
    state.last_y = defaults.window.y
    state.last_w = defaults.window.width
    state.last_h = defaults.window.height
    state.apply_saved_geometry = true
    state.geometry_dirty = true
end

local function reset_appearance()
    state.font_scale[1] = defaults.font_scale

    for i = 1, 4 do
        state.background[i] = defaults.appearance.background[i]
    end

    state.border[1] = defaults.appearance.border
    state.title_bar[1] = defaults.appearance.title_bar
    state.locked[1] = defaults.appearance.locked
    state.appearance_dirty = true
end

-- ============================================================================
-- Settings window renderer
-- ============================================================================
local function draw_config_window()
    if not state.config_open[1] then
        state.apply_saved_config_geometry = true
        return
    end

    if state.apply_saved_config_geometry then
        imgui.SetNextWindowPos({ state.config_last_x, state.config_last_y }, { 0, 0 })
        imgui.SetNextWindowSize({ state.config_last_w, state.config_last_h })
        state.apply_saved_config_geometry = false
    end

    push_theme()

    if imgui.Begin('Addon Control Panel - Config##acp_config', state.config_open, ImGuiWindowFlags_NoNav) then
        imgui.TextColored(HEAD, 'WINDOW')
        imgui.Separator()

        local locked = { state.locked[1] }
        if imgui.Checkbox('Lock Window Position / Size', locked) then
            state.locked[1] = locked[1]
            state.appearance_dirty = true
        end

        local title = { state.title_bar[1] }
        if imgui.Checkbox('Show Title Bar', title) then
            state.title_bar[1] = title[1]
            state.appearance_dirty = true
        end

        local border = { state.border[1] }
        if imgui.Checkbox('Show Border', border) then
            state.border[1] = border[1]
            state.appearance_dirty = true
        end

        imgui.Spacing()
        imgui.TextColored(HEAD, 'FONT')
        imgui.Separator()

        imgui.PushItemWidth(250)
        if imgui.SliderFloat('Font Scale##acp_font', state.font_scale, 0.75, 1.75, '%.2fx') then
            state.appearance_dirty = true
        end
        imgui.PopItemWidth()

        imgui.Spacing()
        imgui.TextColored(HEAD, 'BACKGROUND')
        imgui.Separator()

        imgui.PushItemWidth(250)
        if imgui.ColorEdit4('Window Color##acp_bg', state.background) then
            state.appearance_dirty = true
        end

        local opacity = { state.background[4] }
        if imgui.SliderFloat('Background Opacity##acp_alpha', opacity, 0.05, 1.00, '%.2f') then
            state.background[4] = opacity[1]
            state.appearance_dirty = true
        end
        imgui.PopItemWidth()

        imgui.Spacing()
        imgui.Separator()

        if imgui.Button('Reset Appearance') then
            reset_appearance()
        end

        imgui.SameLine()

        if imgui.Button('Reset Window Position / Size') then
            reset_window()
        end

        capture_config_geometry()
    end

    imgui.End()
    pop_theme()
end

-- ============================================================================
-- Add-addon UI
-- ============================================================================
local function draw_add_section()
    imgui.TextColored(HEAD, 'ADD ADDON')
    imgui.Separator()

    imgui.Text('Addon Name:')
    imgui.SameLine()
    imgui.PushItemWidth(220)
    imgui.InputText('##addoninput', state.new_addon, 100)
    imgui.PopItemWidth()

    imgui.SameLine()
    imgui.Text('Config Command:')
    imgui.SameLine()
    imgui.PushItemWidth(220)
    imgui.InputText('##configinput', state.new_config_cmd, 100)
    imgui.PopItemWidth()

    imgui.SameLine()
    if imgui.Button('Add') then
        local name = strip(state.new_addon[1]):lower()
        local cfg = strip(state.new_config_cmd[1])

        if name ~= '' and not contains_name(name) then
            table.insert(addon_list, {
                name = name,
                config = cfg ~= '' and cfg or nil,
            })
            sort_addons()
            save_list_config()
            state.new_addon[1] = ''
            state.new_config_cmd[1] = ''
        end
    end
end

-- ============================================================================
-- Edit/remove tracked addon UI
-- ============================================================================
local function draw_edit_section()
    if #addon_list == 0 then
        return
    end

    imgui.Spacing()
    imgui.TextColored(HEAD, 'EDIT TRACKED ADDON')
    imgui.Separator()

    if state.selected_index < 1 then state.selected_index = 1 end
    if state.selected_index > #addon_list then state.selected_index = #addon_list end

    local current = addon_list[state.selected_index]
    local current_name = current and current.name or ''

    imgui.PushItemWidth(220)
    if imgui.BeginCombo('##acp_select_addon', current_name) then
        for i, entry in ipairs(addon_list) do
            if imgui.Selectable(entry.name, state.selected_index == i) then
                state.selected_index = i
                state.config_edit_buf[1] = entry.config or ''
            end
        end
        imgui.EndCombo()
    end
    imgui.PopItemWidth()

    imgui.SameLine()

    if imgui.Button('Remove Addon') and current then
        table.remove(addon_list, state.selected_index)

        if state.selected_index > #addon_list then
            state.selected_index = math.max(1, #addon_list)
        end

        if addon_list[state.selected_index] then
            state.config_edit_buf[1] = addon_list[state.selected_index].config or ''
        else
            state.config_edit_buf[1] = ''
        end

        save_list_config()
        return
    end

    current = addon_list[state.selected_index]
    if not current then
        return
    end

    imgui.Text('Config Command:')
    imgui.SameLine()

    imgui.PushItemWidth(300)
    imgui.InputText('##editconfig', state.config_edit_buf, 100)
    imgui.PopItemWidth()

    imgui.SameLine()

    if imgui.Button('Update') then
        local cfg = strip(state.config_edit_buf[1])
        current.config = cfg ~= '' and cfg or nil
        save_list_config()
    end
end

-- ============================================================================
-- Tracked addon action rows
-- ============================================================================
-- Each row exposes Load, Unload, Reload, and Config actions.
local function draw_addon_rows()
    imgui.Spacing()
    imgui.TextColored(HEAD, 'TRACKED ADDONS')
    imgui.SameLine()
    imgui.TextColored(MUTED, ('(%d)'):format(#addon_list))
    imgui.Separator()

    if #addon_list == 0 then
        imgui.TextColored(MUTED, 'No addons are currently tracked.')
        return
    end

    -- Do not use BeginChild here. Newer Ashita v4 ImGui bindings changed the
    -- BeginChild overload and caused the crash in ACP 1.2.
    for i, entry in ipairs(addon_list) do
        local name = tostring(entry.name or '')
        local config_cmd = normalize_config_command(entry)

        if i % 2 == 0 then
            local row_x, row_y = imgui.GetCursorScreenPos()
            local avail_w = select(1, imgui.GetContentRegionAvail())
            local row_h = imgui.GetTextLineHeightWithSpacing() + 6
            local dl = imgui.GetWindowDrawList()

            if dl then
                dl:AddRectFilled(
                    { row_x, row_y },
                    { row_x + math.max(100, tonumber(avail_w) or 100), row_y + row_h },
                    0x101C2A35
                )
            end
        end

        imgui.TextColored(TEXT, name)

        imgui.SameLine()
        imgui.SetCursorPosX(220)

        imgui.PushStyleColor(ImGuiCol_Button, { 0.08, 0.30, 0.16, 1.00 })
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.10, 0.42, 0.21, 1.00 })
        imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.12, 0.52, 0.25, 1.00 })
        if imgui.Button(('Load##%s'):format(name)) then
            queue_command(('/addon load %s'):format(name))
        end
        imgui.PopStyleColor(3)

        imgui.SameLine()

        imgui.PushStyleColor(ImGuiCol_Button, { 0.48, 0.12, 0.14, 1.00 })
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.66, 0.17, 0.19, 1.00 })
        imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.78, 0.22, 0.24, 1.00 })
        if imgui.Button(('Unload##%s'):format(name)) then
            queue_command(('/addon unload %s'):format(name))
        end
        imgui.PopStyleColor(3)

        imgui.SameLine()

        if imgui.Button(('Reload##%s'):format(name)) then
            queue_command(('/addon reload %s'):format(name))
        end

        imgui.SameLine()

        imgui.PushStyleColor(ImGuiCol_Button, { 0.12, 0.28, 0.46, 1.00 })
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.16, 0.39, 0.62, 1.00 })
        imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.20, 0.48, 0.74, 1.00 })
        if imgui.Button(('Config##%s'):format(name)) then
            queue_command(config_cmd)
        end
        imgui.PopStyleColor(3)

        imgui.SameLine()
        imgui.TextColored(MUTED, config_cmd)
    end
end

-- ============================================================================
-- Main control-panel renderer
-- ============================================================================
local function draw_main_window()
    if not state.visible[1] then
        state.apply_saved_geometry = true
        state.config_open[1] = false
        return
    end

    if state.apply_saved_geometry then
        imgui.SetNextWindowPos({ state.last_x, state.last_y }, { 0, 0 })
        imgui.SetNextWindowSize({ state.last_w, state.last_h })
        state.apply_saved_geometry = false
    end

    local flags = ImGuiWindowFlags_NoNav

    if state.locked[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoResize)
    end

    if not state.title_bar[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar)
    end

    push_theme()
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0)

    if imgui.Begin('Addon Control Panel##acp', state.visible, flags) then
        if not state.title_bar[1] then
            local window_w = select(1, imgui.GetWindowSize())
            window_w = tonumber(window_w) or state.last_w

            local saved_x, saved_y = imgui.GetCursorPos()
            imgui.SetCursorPos({ math.max(8, window_w - 30), 6 })

            if imgui.Button('X##acp_custom_close', { 22, 20 }) then
                state.visible[1] = false
                state.config_open[1] = false
            end

            imgui.SetCursorPos({ saved_x, saved_y })
        end

        local base_font_size = imgui.GetFontSize()
        imgui.PushFont(nil, base_font_size * state.font_scale[1])

        imgui.TextColored(HEAD, 'ADDON CONTROL PANEL')
        imgui.SameLine()

        if imgui.Button('Config##acp_open_config') then
            state.config_open[1] = not state.config_open[1]
        end

        imgui.TextColored(MUTED, 'Load, unload, reload, and open configuration for tracked addons.')
        imgui.Spacing()

        draw_add_section()
        draw_edit_section()
        draw_addon_rows()

        imgui.PopFont()

        if not state.locked[1] then
            capture_main_geometry()
        end
    end

    imgui.End()
    imgui.PopStyleVar(1)
    pop_theme()

    draw_config_window()

    if (state.geometry_dirty or state.config_geometry_dirty or state.appearance_dirty)
        and (os.clock() - state.last_save) >= 0.50 then

        save_ui_config()
        state.geometry_dirty = false
        state.config_geometry_dirty = false
        state.appearance_dirty = false
        state.last_save = os.clock()
    end
end

-- ============================================================================
-- Ashita command/event registrations
-- ============================================================================
ashita.events.register('command', 'acp_cmd', function(e)
    if not e or not e.command then
        return
    end

    local args = e.command:args()
    if #args == 0 or not args[1]:any('/acp', '/addoncontrolpanel') then
        return
    end

    e.blocked = true

    if #args >= 2 and tostring(args[2]):lower() == 'config' then
        state.config_open[1] = not state.config_open[1]
        return
    end

    state.visible[1] = not state.visible[1]

    if not state.visible[1] then
        state.config_open[1] = false
    end
end)

ashita.events.register('unload', 'acp_unload', function()
    save_ui_config()
end)

ashita.events.register('d3d_present', 'acp_ui', function()
    draw_main_window()
end)

load_list_config()
