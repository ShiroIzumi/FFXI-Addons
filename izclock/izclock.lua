--[[
    IzClock - Ashita v4 / HorizonXI
    Version 2.9.0

    Commands:
      /ic
      /izclock

    Displays the current Vana'diel time and elemental day.

    This version does NOT depend on packet 0x5C.  Vana'diel time advances at a
    fixed 25x Earth-time rate, so it is calculated directly from Unix time using
    the same epoch offset used by established FFXI clock implementations.

    Ashita v4 safety:
      * No ImGuiCond_* usage.
      * No Player / Entity access required.
      * Uses current Ashita v4 settings persistence.
]]--

addon.name      = 'izclock';
addon.author    = 'Izumi (ShiroIzumi)';
addon.version   = '2.9.4';
addon.desc      = 'Displays Vana\'diel time, day rotation, moon phase, and local time.';
addon.link      = '';

require 'common';

local imgui    = require 'imgui';
local settings = require 'settings';

local defaults = T{
    visible = false,
    config_visible = false,
    font_scale = 1.00,
    window_alpha = 0.92,
    mini_mode = false,
    hide_title_bar = false,
    hide_border = false,
    show_local_time = false,
    local_time_24h = false,
    show_local_seconds = false,
    show_moon_phase = false,
    show_element_icons = false,
    compact_mode = false,
    lock_window = false,
    background_color = { 0.055, 0.070, 0.095 },
    alignment = 'left',
    window = T{
        x = 50,
        y = 50,
        width = 520,
        height = 150,
    },
};

local config = settings.load(defaults);

local state = T{
    open = { true },
    config_open = { config.config_visible == true },
    font_scale = { tonumber(config.font_scale) or 1.00 },
    window_alpha = { tonumber(config.window_alpha) or 0.92 },
    mini_mode = { config.mini_mode == true },
    hide_title_bar = { config.hide_title_bar == true },
    hide_border = { config.hide_border == true },
    show_local_time = { config.show_local_time == true },
    local_time_24h = { config.local_time_24h == true },
    show_local_seconds = { config.show_local_seconds == true },
    show_moon_phase = { config.show_moon_phase == true },
    show_element_icons = { config.show_element_icons == true },
    compact_mode = { config.compact_mode == true },
    lock_window = { config.lock_window == true },
    background_color = {
        tonumber(config.background_color and config.background_color[1]) or 0.055,
        tonumber(config.background_color and config.background_color[2]) or 0.070,
        tonumber(config.background_color and config.background_color[3]) or 0.095,
    },
    alignment = (config.alignment == 'right' and 'right') or (config.alignment == 'center' and 'center') or 'left',
    apply_saved_geometry = true,
    last_x = tonumber(config.window.x) or 50,
    last_y = tonumber(config.window.y) or 50,
    last_w = tonumber(config.window.width) or 520,
    last_h = tonumber(config.window.height) or 150,
    geometry_dirty = false,
    last_geometry_save = 0,
};

-- IzClock should always appear immediately when loaded or reloaded.
config.visible = true;

local days = T{
    [0] = 'Firesday',
    [1] = 'Earthsday',
    [2] = 'Watersday',
    [3] = 'Windsday',
    [4] = 'Iceday',
    [5] = 'Lightningday',
    [6] = 'Lightsday',
    [7] = 'Darksday',
};

-- Element-inspired day colors.  These are deliberately bright enough to read
-- on the addon's dark local ImGui theme without affecting any global UI style.
local day_colors = T{
    [0] = { 1.00, 0.34, 0.22, 1.00 }, -- Firesday
    [1] = { 0.78, 0.62, 0.30, 1.00 }, -- Earthsday
    [2] = { 0.30, 0.68, 1.00, 1.00 }, -- Watersday
    [3] = { 0.38, 0.92, 0.58, 1.00 }, -- Windsday
    [4] = { 0.58, 0.90, 1.00, 1.00 }, -- Iceday
    [5] = { 0.78, 0.52, 1.00, 1.00 }, -- Lightningday
    [6] = { 1.00, 0.92, 0.55, 1.00 }, -- Lightsday
    [7] = { 0.72, 0.58, 0.86, 1.00 }, -- Darksday
};

local day_icons = T{
    [0] = '[Fi]',
    [1] = '[Ea]',
    [2] = '[Wa]',
    [3] = '[Wi]',
    [4] = '[Ic]',
    [5] = '[Li]',
    [6] = '[Ls]',
    [7] = '[Da]',
};

local moon_phases = T{
    [0] = 'New Moon',
    [1] = 'Waxing Crescent',
    [2] = 'First Quarter Moon',
    [3] = 'Waxing Gibbous',
    [4] = 'Full Moon',
    [5] = 'Waning Gibbous',
    [6] = 'Last Quarter Moon',
    [7] = 'Waning Crescent',
};

local UI_TEXT   = { 0.91, 0.94, 0.98, 1.00 };
local UI_MUTED  = { 0.58, 0.64, 0.72, 1.00 };
local UI_ACCENT = { 0.34, 0.76, 1.00, 1.00 };

-- FFXI / Vana'diel constants.
-- One Vana'diel day = 3456 Earth seconds.
-- One Vana'diel hour = 144 Earth seconds.
local VANA_EPOCH_OFFSET = 92514960;
local EARTH_SECONDS_PER_VANA_DAY = 3456;
local EARTH_SECONDS_PER_VANA_HOUR = 144;

local function get_vana_time()
    -- os.time() is Unix epoch time. Adding the established Vana'diel epoch
    -- offset gives the same day/time basis used by the working clock.
    local raw = os.time() + VANA_EPOCH_OFFSET;

    local total_days = math.floor(raw / EARTH_SECONDS_PER_VANA_DAY);
    local day_index = total_days % 8;

    local hour = math.floor(raw / EARTH_SECONDS_PER_VANA_HOUR) % 24;

    -- A Vana'diel minute is 2.4 Earth seconds.
    local minute = math.floor((raw % EARTH_SECONDS_PER_VANA_HOUR) / 2.4);

    -- Earth seconds until the next Vana'diel day begins.
    local seconds_into_day = raw % EARTH_SECONDS_PER_VANA_DAY;
    local seconds_to_next_day = EARTH_SECONDS_PER_VANA_DAY - seconds_into_day;
    if seconds_to_next_day <= 0 then
        seconds_to_next_day = EARTH_SECONDS_PER_VANA_DAY;
    end

    return hour, minute, day_index, total_days, seconds_to_next_day;
end

local function format_countdown(total_seconds)
    total_seconds = math.max(0, math.floor(tonumber(total_seconds) or 0));

    local minutes = math.floor(total_seconds / 60);
    local seconds = total_seconds % 60;

    return ('%02dm %02ds'):fmt(minutes, seconds);
end

local function get_moon_info(total_days)
    -- FFXI uses an 84-Vana-day lunar cycle. The signed value ranges from
    -- -100..100; the game displays its absolute value as illumination percent.
    local cycle_days = 84;
    local signed_percent = ((((total_days + 26) % cycle_days) - (cycle_days / 2))
        / (cycle_days / 2)) * 100;

    local phase = 0;

    if signed_percent >= 7 and signed_percent <= 38 then
        phase = 1; -- Waxing Crescent
    elseif signed_percent >= 40 and signed_percent <= 55 then
        phase = 2; -- First Quarter Moon
    elseif signed_percent >= 57 and signed_percent <= 88 then
        phase = 3; -- Waxing Gibbous
    elseif signed_percent >= 90 or signed_percent <= -95 then
        phase = 4; -- Full Moon
    elseif signed_percent >= -93 and signed_percent <= -62 then
        phase = 5; -- Waning Gibbous
    elseif signed_percent >= -60 and signed_percent <= -45 then
        phase = 6; -- Last Quarter Moon
    elseif signed_percent >= -43 and signed_percent <= -12 then
        phase = 7; -- Waning Crescent
    else
        phase = 0; -- New Moon
    end

    local percent = math.floor(math.abs(signed_percent) + 0.5);

    return moon_phases[phase] or 'Unknown Moon', percent;
end

local function get_upcoming_days(current_day_index)
    local upcoming = {};

    -- Show the next seven days in order, which displays the complete rotation
    -- before returning to the current elemental day.
    for offset = 1, 7 do
        local idx = (current_day_index + offset) % 8;
        upcoming[#upcoming + 1] = idx;
    end

    return upcoming;
end

local function align_line(total_width)
    if state.alignment == 'left' then
        return;
    end

    local avail_w = imgui.GetContentRegionAvail();
    avail_w = tonumber(avail_w) or 0;

    if avail_w > total_width then
        local x = imgui.GetCursorPosX();
        local remaining = avail_w - total_width;

        if state.alignment == 'center' then
            imgui.SetCursorPosX(x + (remaining / 2));
        elseif state.alignment == 'right' then
            imgui.SetCursorPosX(x + remaining);
        end
    end
end

local function text_width(value)
    local w = imgui.CalcTextSize(value);
    return tonumber(w) or 0;
end

local function day_value_width(day_index)
    local width = text_width(days[day_index] or 'Unknown');

    if state.show_element_icons[1] then
        width = width + text_width(day_icons[day_index] or '[?]') + text_width(' ');
    end

    return width;
end

local function draw_day_value(day_index)
    if state.show_element_icons[1] then
        imgui.TextColored(day_colors[day_index] or UI_TEXT, day_icons[day_index] or '[?]');
        imgui.SameLine();
    end

    imgui.TextColored(day_colors[day_index] or UI_TEXT, days[day_index] or 'Unknown');
end


local function draw_day_rotation_tooltip(current_day_index)
    if not imgui.IsItemHovered() then
        return;
    end

    -- Real tooltip rendering gives us a vertical, color-coded list and
    -- automatically uses IzClock's currently pushed font / font scale.
    imgui.BeginTooltip();

    imgui.TextColored(UI_MUTED, 'DAY ROTATION');
    imgui.Separator();

    for offset = 0, 7 do
        local idx = (current_day_index + offset) % 8;
        local name = days[idx] or 'Unknown';

        if offset == 0 then
            imgui.TextColored(day_colors[idx] or UI_TEXT, ('> %s'):fmt(name));
            imgui.SameLine();
            imgui.TextColored(UI_MUTED, '(Current)');
        else
            imgui.TextColored(day_colors[idx] or UI_TEXT, ('  %s'):fmt(name));
        end
    end

    imgui.EndTooltip();
end

local function draw_label_value(label, value, value_color)
    local combined_width = text_width(label) + text_width(' ') + text_width(value);
    align_line(combined_width);

    imgui.TextColored(UI_MUTED, label);
    imgui.SameLine();
    imgui.TextColored(value_color or UI_TEXT, value);
end

local function draw_label_day(label, day_index)
    local combined_width = text_width(label) + text_width(' ') + day_value_width(day_index);
    align_line(combined_width);

    imgui.TextColored(UI_MUTED, label);
    imgui.SameLine();
    draw_day_value(day_index);
end

local function draw_day_rotation(current_day_index)
    local upcoming = get_upcoming_days(current_day_index);

    local total_width = 0;
    for i, idx in ipairs(upcoming) do
        if i > 1 then
            total_width = total_width + text_width(' > ');
        end
        total_width = total_width + day_value_width(idx);
    end

    align_line(total_width);

    for i, idx in ipairs(upcoming) do
        if i > 1 then
            imgui.SameLine();
            imgui.TextColored(UI_MUTED, '>');
            imgui.SameLine();
        end

        draw_day_value(idx);
    end
end

local function compact_part_width(label, value)
    return text_width(label) + text_width(' ') + text_width(value);
end

local function draw_compact_separator()
    imgui.SameLine();
    imgui.TextColored(UI_MUTED, '|');
    imgui.SameLine();
end

local function draw_compact_line(local_time_str, vana_time_str, day_index, next_day_index, countdown_str, moon_name, moon_percent)
    local parts_width = 0;
    local separators = 0;

    if state.show_local_time[1] then
        parts_width = parts_width + compact_part_width('LOCAL', local_time_str or '--:--');
        separators = separators + 1;
    end

    parts_width = parts_width + compact_part_width('VANA', vana_time_str);
    separators = separators + 1;

    parts_width = parts_width + day_value_width(day_index) + text_width(' > ') + day_value_width(next_day_index);
    separators = separators + 1;

    parts_width = parts_width + compact_part_width('NEXT', countdown_str);

    if state.show_moon_phase[1] then
        separators = separators + 1;
        parts_width = parts_width + compact_part_width('MOON', ('%s (%d%%)'):fmt(moon_name, moon_percent));
    end

    parts_width = parts_width + (separators * text_width(' | '));
    align_line(parts_width);

    if state.show_local_time[1] then
        imgui.TextColored(UI_MUTED, 'LOCAL');
        imgui.SameLine();
        imgui.TextColored(UI_TEXT, local_time_str or '--:--');
        draw_compact_separator();
    end

    imgui.TextColored(UI_MUTED, 'VANA');
    imgui.SameLine();
    imgui.TextColored(UI_ACCENT, vana_time_str);
    draw_compact_separator();

    draw_day_value(day_index);
    local hover_current_day = imgui.IsItemHovered();

    imgui.SameLine();
    imgui.TextColored(UI_MUTED, '>');
    local hover_day_arrow = imgui.IsItemHovered();

    imgui.SameLine();
    draw_day_value(next_day_index);
    local hover_next_day = imgui.IsItemHovered();

    if hover_current_day or hover_day_arrow or hover_next_day then
        -- draw_day_rotation_tooltip normally checks hover on the last item.
        -- The next-day item is last here; for current day / arrow hover, open
        -- the same tooltip directly so the entire "Day > Next Day" segment is
        -- interactive without changing its visual layout.
        if hover_next_day then
            draw_day_rotation_tooltip(day_index);
        else
            imgui.BeginTooltip();
            imgui.TextColored(UI_MUTED, 'DAY ROTATION');
            imgui.Separator();

            for offset = 0, 7 do
                local idx = (day_index + offset) % 8;
                local name = days[idx] or 'Unknown';

                if offset == 0 then
                    imgui.TextColored(day_colors[idx] or UI_TEXT, ('> %s'):fmt(name));
                    imgui.SameLine();
                    imgui.TextColored(UI_MUTED, '(Current)');
                else
                    imgui.TextColored(day_colors[idx] or UI_TEXT, ('  %s'):fmt(name));
                end
            end

            imgui.EndTooltip();
        end
    end

    draw_compact_separator();

    imgui.TextColored(UI_MUTED, 'NEXT');
    imgui.SameLine();
    imgui.TextColored(UI_TEXT, countdown_str);

    if state.show_moon_phase[1] then
        draw_compact_separator();
        imgui.TextColored(UI_MUTED, 'MOON');
        imgui.SameLine();
        imgui.TextColored(UI_TEXT, ('%s (%d%%)'):fmt(moon_name, moon_percent));
    end
end

local function save_config()
    config.visible = state.open[1];
    config.config_visible = state.config_open[1];
    config.font_scale = state.font_scale[1];
    config.window_alpha = state.window_alpha[1];
    config.mini_mode = state.mini_mode[1];
    config.hide_title_bar = state.hide_title_bar[1];
    config.hide_border = state.hide_border[1];
    config.show_local_time = state.show_local_time[1];
    config.local_time_24h = state.local_time_24h[1];
    config.show_local_seconds = state.show_local_seconds[1];
    config.show_moon_phase = state.show_moon_phase[1];
    config.show_element_icons = state.show_element_icons[1];
    config.compact_mode = state.compact_mode[1];
    config.lock_window = state.lock_window[1];

    if config.background_color == nil then
        config.background_color = T{};
    end
    config.background_color[1] = state.background_color[1];
    config.background_color[2] = state.background_color[2];
    config.background_color[3] = state.background_color[3];

    config.alignment = state.alignment;

    if config.window == nil then
        config.window = T{};
    end

    config.window.x = state.last_x;
    config.window.y = state.last_y;
    config.window.width = state.last_w;
    config.window.height = state.last_h;

    settings.save();
end

local function capture_window_geometry()
    -- Current Ashita v4 ImGui returns two numeric values from each function.
    local x, y = imgui.GetWindowPos();
    local w, h = imgui.GetWindowSize();

    x = tonumber(x);
    y = tonumber(y);
    w = tonumber(w);
    h = tonumber(h);

    if x == nil or y == nil or w == nil or h == nil then
        return;
    end

    if math.abs(x - state.last_x) >= 1
        or math.abs(y - state.last_y) >= 1
        or math.abs(w - state.last_w) >= 1
        or math.abs(h - state.last_h) >= 1 then
        state.last_x = x;
        state.last_y = y;
        state.last_w = w;
        state.last_h = h;
        state.geometry_dirty = true;
    end
end

ashita.events.register('command', 'izclock_command_cb', function(e)
    if e == nil or e.command == nil then
        return;
    end

    local args = e.command:args();
    if #args == 0 then
        return;
    end

    if args[1]:any('/ic', '/izclock') then
        e.blocked = true;

        state.open[1] = not state.open[1];
        config.visible = state.open[1];
        settings.save();
        return;
    end

    if args[1]:any('/icconfig') then
        e.blocked = true;

        state.config_open[1] = not state.config_open[1];
        config.config_visible = state.config_open[1];
        settings.save();
        return;
    end
end);


-- Ashita v4 loads the addon before the active character profile is always
-- available. The settings library can therefore replace the startup settings
-- table after login. Rehydrate every runtime UI value when that happens so
-- IzClock immediately uses the character's saved profile without requiring
-- /addon reload izclock.
settings.register('settings', 'izclock_settings_update', function(s)
    if s == nil then
        return;
    end

    config = s;

    state.config_open[1] = config.config_visible == true;
    state.font_scale[1] = tonumber(config.font_scale) or 1.00;
    state.window_alpha[1] = tonumber(config.window_alpha) or 0.92;
    state.mini_mode[1] = config.mini_mode == true;
    state.hide_title_bar[1] = config.hide_title_bar == true;
    state.hide_border[1] = config.hide_border == true;
    state.show_local_time[1] = config.show_local_time == true;
    state.local_time_24h[1] = config.local_time_24h == true;
    state.show_local_seconds[1] = config.show_local_seconds == true;
    state.show_moon_phase[1] = config.show_moon_phase == true;
    state.show_element_icons[1] = config.show_element_icons == true;
    state.compact_mode[1] = config.compact_mode == true;
    state.lock_window[1] = config.lock_window == true;

    state.background_color[1] = tonumber(config.background_color and config.background_color[1]) or 0.055;
    state.background_color[2] = tonumber(config.background_color and config.background_color[2]) or 0.070;
    state.background_color[3] = tonumber(config.background_color and config.background_color[3]) or 0.095;

    state.alignment =
        (config.alignment == 'right' and 'right')
        or (config.alignment == 'center' and 'center')
        or 'left';

    if type(config.window) ~= 'table' then
        config.window = T{
            x = 50,
            y = 50,
            width = 520,
            height = 150,
        };
    end

    state.last_x = tonumber(config.window.x) or 50;
    state.last_y = tonumber(config.window.y) or 50;
    state.last_w = tonumber(config.window.width) or 520;
    state.last_h = tonumber(config.window.height) or 150;

    -- Reapply the character profile's saved window geometry on the next frame.
    state.apply_saved_geometry = true;
    state.geometry_dirty = false;
    state.last_geometry_save = 0;

    -- The clock itself should remain visible after login/reprofile.
    config.visible = true;
    state.open[1] = true;
end);

ashita.events.register('d3d_present', 'izclock_present_cb', function()
    if not state.open[1] then
        return;
    end

    if state.apply_saved_geometry then
        imgui.SetNextWindowPos({ state.last_x, state.last_y });
        imgui.SetNextWindowSize({ state.last_w, state.last_h });
        state.apply_saved_geometry = false;
    end

    local hour, minute, day_index, total_days, seconds_to_next_day = get_vana_time();
    local time_str = ('%02d:%02d'):fmt(hour, minute);
    local next_day_index = (day_index + 1) % 8;
    local countdown_str = format_countdown(seconds_to_next_day);
    local moon_name, moon_percent = get_moon_info(total_days);

    -- Uses the computer's local timezone, including DST as handled by Windows.
    local local_time_str = nil;
    if state.local_time_24h[1] then
        local_time_str = os.date(state.show_local_seconds[1] and '%H:%M:%S' or '%H:%M');
    else
        local_time_str = os.date(state.show_local_seconds[1] and '%I:%M:%S %p' or '%I:%M %p');
        if local_time_str ~= nil and local_time_str:sub(1, 1) == '0' then
            local_time_str = local_time_str:sub(2);
        end
    end

    -- Local theme only: this removes the default gray/red appearance without
    -- changing the user's global Ashita / ImGui theme.
    imgui.PushStyleColor(ImGuiCol_WindowBg,        {
        state.background_color[1],
        state.background_color[2],
        state.background_color[3],
        state.window_alpha[1]
    });
    imgui.PushStyleColor(ImGuiCol_TitleBg,         { 0.070, 0.105, 0.150, 1.00 });
    imgui.PushStyleColor(ImGuiCol_TitleBgActive,   { 0.085, 0.150, 0.215, 1.00 });
    imgui.PushStyleColor(ImGuiCol_TitleBgCollapsed,{ 0.070, 0.105, 0.150, 1.00 });
    local border_alpha = state.hide_border[1] and 0.00 or 0.90;
    imgui.PushStyleColor(ImGuiCol_Border,          { 0.20, 0.38, 0.52, border_alpha });
    imgui.PushStyleColor(ImGuiCol_Separator,       { 0.18, 0.34, 0.46, 0.85 });
    imgui.PushStyleColor(ImGuiCol_Text,            UI_TEXT);

    local window_flags = ImGuiWindowFlags_NoNav;

    if state.hide_title_bar[1] then
        window_flags = bit.bor(window_flags, ImGuiWindowFlags_NoTitleBar);
    end

    if state.lock_window[1] then
        window_flags = bit.bor(window_flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoResize);
    end

    if imgui.Begin('IzClock##izclock', state.open, window_flags) then
        -- Current Ashita v4 font scaling approach.  Do not use the removed
        -- SetWindowFontScale API.
        local base_font_size = imgui.GetFontSize();
        imgui.PushFont(nil, base_font_size * state.font_scale[1]);

        if state.compact_mode[1] then
            draw_compact_line(
                local_time_str,
                time_str,
                day_index,
                next_day_index,
                countdown_str,
                moon_name,
                moon_percent
            );
        else
            if state.show_local_time[1] then
                draw_label_value('LOCAL TIME', local_time_str or '--:--', UI_TEXT);
            end

            draw_label_value('VANA\'DIEL TIME', time_str, UI_ACCENT);

            if state.mini_mode[1] then
                local combined_width = text_width('CURRENT DAY') + text_width(' ') + day_value_width(day_index);
                align_line(combined_width);

                imgui.TextColored(UI_MUTED, 'CURRENT DAY');
                imgui.SameLine();
                draw_day_value(day_index);
                draw_day_rotation_tooltip(day_index);
            else
                draw_label_day('CURRENT DAY', day_index);
            end

            draw_label_value('NEXT DAY IN', countdown_str, UI_TEXT);

            if state.show_moon_phase[1] then
                draw_label_value('MOON', ('%s (%d%%)'):fmt(moon_name, moon_percent), UI_TEXT);
            end

            if state.mini_mode[1] then
                draw_label_day('NEXT DAY', next_day_index);
            else
                imgui.Separator();

                local rotation_label = 'UPCOMING ROTATION';
                align_line(text_width(rotation_label));
                imgui.TextColored(UI_MUTED, rotation_label);
                draw_day_rotation(day_index);
            end
        end

        imgui.PopFont();

        capture_window_geometry();
    end

    imgui.End();

    imgui.PopStyleColor(7);

    if state.geometry_dirty and (os.clock() - state.last_geometry_save) >= 0.50 then
        save_config();
        state.geometry_dirty = false;
        state.last_geometry_save = os.clock();
    end
end);

local function render_config_window()
    if not state.config_open[1] then
        return;
    end

    -- Keep the configuration window visually related to IzClock but slightly
    -- more opaque than the display window so controls stay easy to read.
    imgui.PushStyleColor(ImGuiCol_WindowBg,         { 0.055, 0.070, 0.095, 0.98 });
    imgui.PushStyleColor(ImGuiCol_TitleBg,          { 0.070, 0.105, 0.150, 1.00 });
    imgui.PushStyleColor(ImGuiCol_TitleBgActive,    { 0.085, 0.150, 0.215, 1.00 });
    imgui.PushStyleColor(ImGuiCol_TitleBgCollapsed, { 0.070, 0.105, 0.150, 1.00 });
    imgui.PushStyleColor(ImGuiCol_Border,           { 0.20, 0.38, 0.52, 0.90 });
    imgui.PushStyleColor(ImGuiCol_Separator,        { 0.18, 0.34, 0.46, 0.85 });
    imgui.PushStyleColor(ImGuiCol_Text,             UI_TEXT);

    if imgui.Begin('IzClock Configuration##izclock_config', state.config_open, ImGuiWindowFlags_NoNav) then
        imgui.TextColored(UI_ACCENT, 'Display');
        imgui.Separator();

        imgui.Text('Font Size');
        imgui.SameLine();
        imgui.PushItemWidth(190);
        if imgui.SliderFloat('##izclock_font_scale_config', state.font_scale, 0.75, 2.00, '%.2fx') then
            config.font_scale = state.font_scale[1];
            settings.save();
        end
        imgui.PopItemWidth();

        imgui.Text('Transparency');
        imgui.SameLine();
        imgui.PushItemWidth(190);
        if imgui.SliderFloat('##izclock_alpha_config', state.window_alpha, 0.00, 1.00, '%.2f') then
            config.window_alpha = state.window_alpha[1];
            settings.save();
        end
        imgui.PopItemWidth();

        imgui.SameLine();
        imgui.Text('Background');
        imgui.SameLine();

        -- RGB only: transparency remains controlled by the dedicated slider.
        -- ColorEdit3 is supported by current Ashita v4 ImGui bindings.
        if imgui.ColorEdit3('##izclock_background_color', state.background_color, ImGuiColorEditFlags_NoInputs) then
            if config.background_color == nil then
                config.background_color = T{};
            end
            config.background_color[1] = state.background_color[1];
            config.background_color[2] = state.background_color[2];
            config.background_color[3] = state.background_color[3];
            settings.save();
        end

        imgui.TextColored(UI_MUTED, '0.00 = fully transparent   1.00 = opaque');

        imgui.Separator();
        imgui.TextColored(UI_ACCENT, 'Layout');

        if imgui.Checkbox('Mini Mode', state.mini_mode) then
            config.mini_mode = state.mini_mode[1];
            settings.save();
        end
        imgui.SameLine();
        imgui.TextColored(UI_MUTED, '(unchecked = Full)');

        if imgui.Checkbox('Compact One-Line', state.compact_mode) then
            config.compact_mode = state.compact_mode[1];
            settings.save();
        end

        if imgui.Checkbox('Lock Window', state.lock_window) then
            config.lock_window = state.lock_window[1];
            settings.save();
        end

        if imgui.Checkbox('Hide Title Bar', state.hide_title_bar) then
            config.hide_title_bar = state.hide_title_bar[1];
            settings.save();
        end

        if imgui.Checkbox('Hide Border', state.hide_border) then
            config.hide_border = state.hide_border[1];
            settings.save();
        end

        if imgui.Checkbox('Show Moon Phase', state.show_moon_phase) then
            config.show_moon_phase = state.show_moon_phase[1];
            settings.save();
        end

        if imgui.Checkbox('Elemental Icons', state.show_element_icons) then
            config.show_element_icons = state.show_element_icons[1];
            settings.save();
        end

        if imgui.Checkbox('Show Local Time', state.show_local_time) then
            config.show_local_time = state.show_local_time[1];
            settings.save();
        end

        imgui.SameLine();
        if imgui.Checkbox('24hr Format', state.local_time_24h) then
            config.local_time_24h = state.local_time_24h[1];
            settings.save();
        end

        imgui.SameLine();
        if imgui.Checkbox('Seconds', state.show_local_seconds) then
            config.show_local_seconds = state.show_local_seconds[1];
            settings.save();
        end

        imgui.Text('Alignment');
        imgui.SameLine();

        if state.alignment == 'left' then
            imgui.TextColored(UI_ACCENT, 'Left');
        else
            if imgui.Button('Left') then
                state.alignment = 'left';
                config.alignment = 'left';
                settings.save();
            end
        end

        imgui.SameLine();

        if state.alignment == 'center' then
            imgui.TextColored(UI_ACCENT, 'Center');
        else
            if imgui.Button('Center') then
                state.alignment = 'center';
                config.alignment = 'center';
                settings.save();
            end
        end

        imgui.SameLine();

        if state.alignment == 'right' then
            imgui.TextColored(UI_ACCENT, 'Right');
        else
            if imgui.Button('Right') then
                state.alignment = 'right';
                config.alignment = 'right';
                settings.save();
            end
        end

        imgui.TextColored(UI_MUTED, 'Mini: Time / Day / next-day countdown / Next Day');
        imgui.TextColored(UI_MUTED, 'Full: Mini data + full 7-day rotation');
        imgui.TextColored(UI_MUTED, 'Compact: single-line layout (overrides Mini / Full)');

        imgui.Separator();
        imgui.TextColored(UI_MUTED, 'Commands:');
        imgui.Text('/ic        Toggle clock');
        imgui.Text('/icconfig  Toggle this window');
    end

    imgui.End();
    imgui.PopStyleColor(7);

    if state.config_open[1] == false then
        config.config_visible = false;
        settings.save();
    end
end

ashita.events.register('d3d_present', 'izclock_config_present_cb', function()
    render_config_window();
end);

ashita.events.register('unload', 'izclock_unload_cb', function()
    save_config();
end);
