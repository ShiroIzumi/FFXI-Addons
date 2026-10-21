require('common');
local imgui = require('imgui');
local core_mod = require('scl.core');
local events_mod = require('scl.events');
local render_mod = require('scl.render');
local theme_mod = require('scl.theme');
local clamp = core_mod.clamp;
local copy_defaults = core_mod.copy_defaults;
local defaults = core_mod.defaults;
local ensure_event_option = core_mod.ensure_event_option;
local save_settings = core_mod.save_settings;
local settings = core_mod.settings;
local state = core_mod.state;
local add_event = events_mod.add_event;
local event_color = events_mod.event_color;
local event_scale = events_mod.event_scale;
local rendered_event_text = events_mod.rendered_event_text;
local rgba_to_argb = events_mod.rgba_to_argb;
local source_suffix = events_mod.source_suffix;
local target_suffix = events_mod.target_suffix;
local cycle_font_family = render_mod.cycle_font_family;
local draw_imgui_text_with_outline = render_mod.draw_imgui_text_with_outline;
local ensure_preview_font_pool = render_mod.ensure_preview_font_pool;
local hide_preview_fonts = render_mod.hide_preview_fonts;
local hide_unused_fonts = render_mod.hide_unused_fonts;
local rebuild_font_pool = render_mod.rebuild_font_pool;
local FONT_FAMILIES = render_mod.FONT_FAMILIES;
local set_font_family = render_mod.set_font_family;
local TEXT_EFFECTS = render_mod.TEXT_EFFECTS;
local EFFECT_COLORS = render_mod.EFFECT_COLORS;
local TEXT_PLATES = render_mod.TEXT_PLATES;
local current_effect = render_mod.current_effect;
local effect_has_outline = render_mod.effect_has_outline;
local effect_has_shadow = render_mod.effect_has_shadow;
local custom_outline_argb = render_mod.custom_outline_argb;
local display_case = render_mod.display_case;
local UI_ACCENT_TEXT = theme_mod.UI_ACCENT_TEXT;
local UI_BG = theme_mod.UI_BG;
local UI_BORDER = theme_mod.UI_BORDER;
local UI_GOLD = theme_mod.UI_GOLD;
local UI_MUTED = theme_mod.UI_MUTED;
local UI_RED = theme_mod.UI_RED;
local UI_THEMES = theme_mod.UI_THEMES;
local UI_THEME_ORDER = theme_mod.UI_THEME_ORDER;
local UI_TRANSPARENT = theme_mod.UI_TRANSPARENT;
local align_label = theme_mod.align_label;
local draw_styled_tab = theme_mod.draw_styled_tab;
local draw_toggle_button = theme_mod.draw_toggle_button;
local help_marker = theme_mod.help_marker;
local pop_theme = theme_mod.pop_theme;
local push_theme = theme_mod.push_theme;
local section_header = theme_mod.section_header;
local UI_ACCENT = theme_mod.UI_ACCENT;
local session = require('scl.session');
local debuglog = require('scl.debuglog');

local function reset_anchor(key)
    if key ~= 'incoming' and key ~= 'outgoing' and key ~= 'notification' then
        return;
    end

    settings[key].x = defaults[key].x;
    settings[key].y = defaults[key].y;
    state.move_initialized[key] = false;
    save_settings();
end

local function reset_all_settings()
    copy_defaults(settings, defaults);
    state.events = {};
    hide_unused_fonts(1);
    rebuild_font_pool();
    state.move_mode = false;
    state.move_initialized.incoming = false;
    state.move_initialized.outgoing = false;
    state.move_initialized.notification = false;
    state.confirm_reset_all = false;
    save_settings();
end


local function draw_move_anchor(title, key, color)
    local anchor = settings[key];
    if not anchor then
        return;
    end

    -- IMPORTANT: only apply the saved position ONCE when move mode is opened.
    -- Calling SetNextWindowPos every frame pins the ImGui window in place and
    -- makes dragging impossible. We deliberately avoid ImGuiCond_* and use
    -- static state instead for Ashita v4 compatibility.
    -- The Notifications anchor is the CENTER of its text, so its handle window
    -- is centered on the anchor point instead of starting at it.
    local centered = key == 'notification';
    state.move_half_width = state.move_half_width or {};
    local half = centered and (state.move_half_width[key] or 130) or 0;

    if not state.move_initialized[key] then
        imgui.SetNextWindowPos({
            (tonumber(anchor.x) or 500) - half,
            tonumber(anchor.y) or 500
        });
        state.move_initialized[key] = true;
    end

    local flags = bit.bor(
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_NoNav
    );

    push_theme();
    imgui.PushStyleColor(ImGuiCol_Border, color);

    if imgui.Begin(title .. '##scl_move_' .. key, nil, flags) then
        imgui.TextColored(color, title);
        imgui.TextDisabled('Drag this window to position the lane.');

        -- Current Ashita v4 returns x, y as separate numeric values.
        local x, y = imgui.GetWindowPos();
        x = tonumber(x);
        y = tonumber(y);

        if centered and x then
            local w = tonumber((imgui.GetWindowSize())) or 260;
            state.move_half_width[key] = w / 2;
            x = x + w / 2;
        end

        if x and y then
            local old_x = tonumber(anchor.x) or x;
            local old_y = tonumber(anchor.y) or y;

            if math.abs(x - old_x) >= 1 or math.abs(y - old_y) >= 1 then
                anchor.x = x;
                anchor.y = y;
                save_settings();
            end
        end
    end

    imgui.End();
    imgui.PopStyleColor(1);
    pop_theme();
end

local function draw_move_mode()
    if not state.move_mode or settings.locked == true then
        return;
    end

    draw_move_anchor(
        'Incoming Combat Text',
        'incoming',
        { 1.00, 0.36, 0.36, 1.00 }
    );

    draw_move_anchor(
        'Outgoing Combat Text',
        'outgoing',
        { 1.00, 0.88, 0.32, 1.00 }
    );

    draw_move_anchor(
        'Notifications (center)',
        'notification',
        { 0.80, 0.86, 1.00, 1.00 }
    );
end

local function draw_live_preview()
    local custom = (settings.renderer_mode or 'performance') == 'custom';
    if custom then
        imgui.TextDisabled('Custom Font preview: family, bold, italic, outline, colors and size are live.');
    else
        imgui.TextDisabled('Performance preview: effect, plate, colors, prefixes and size are live.');
    end

    local samples = {
        { 'outgoing', 'critical', '148' .. target_suffix('Goblin'), 'criticals' },
        { 'outgoing', 'ability', 'Vorpal Blade  722' .. target_suffix('Goblin'), 'weapon_skills' },
        { 'outgoing', 'ability', 'Thunder II  843' .. target_suffix('Goblin') .. ' [MB]', 'magic_bursts' },
        { 'outgoing', 'ability', 'Light  486' .. target_suffix('Goblin'), 'skillchains' },
        { 'incoming', 'incoming', '-63' .. source_suffix('Goblin'), 'incoming_damage' },
        { 'incoming', 'miss', 'PARRY' .. source_suffix('Goblin'), 'defenses' },
        { 'incoming', 'miss', '1 absorbed' .. source_suffix('Goblin'), 'defenses', '[SHADOW] ' },
        { 'incoming', 'heal', '+93 HP  <-  Cure II', 'healing_received' },
        { 'incoming', 'xp', '+189 EXP', 'exp' },
    };

    local max_w = 0;

    if not custom then
        hide_preview_fonts();
        state.preview_hole = nil;

        for i, sample in ipairs(samples) do
            local ev = {
                direction = sample[1],
                kind = sample[2],
                text = sample[3],
                event_type = sample[4],
                symbol = sample[5],
                created = os.clock(),
            };

            local c = event_color(ev);
            local scale = event_scale(ev, 0);
            local preview_text = rendered_event_text(ev);
            imgui.PushFont(nil, imgui.GetFontSize() * scale);
            local text_w = tonumber((imgui.CalcTextSize(preview_text))) or 0;
            if text_w > max_w then max_w = text_w; end
            draw_imgui_text_with_outline(c, preview_text);
            imgui.PopFont();

            if i == 4 then
                imgui.Separator();
            end
        end

        state.preview_needed_w = max_w;

        return;
    end

    -- Custom Font renderer:
    -- ImGui cannot preview arbitrary Windows FontManager families, so use a
    -- dedicated set of actual FontManager objects positioned over the Preview
    -- area. This makes the preview match the selected family/style instead of
    -- always looking like the ImGui UI font.
    ensure_preview_font_pool(#samples);

    local start_x, start_y = imgui.GetCursorScreenPos();
    start_x = tonumber(start_x) or 0;
    start_y = tonumber(start_y) or 0;

    local y = start_y;
    local used_height = 0;

    for i, sample in ipairs(samples) do
        local ev = {
            direction = sample[1],
            kind = sample[2],
            text = sample[3],
            event_type = sample[4],
            symbol = sample[5],
            created = os.clock(),
        };

        local obj = state.preview_font_pool[i];
        local scale = event_scale(ev, 0);
        local height = math.max(8, math.floor(16 * scale + 0.5));
        local line_height = math.max(20, height + 5);

        if i == 5 then
            y = y + 8;
            used_height = used_height + 8;
        end

        if obj then
            local family = tostring(settings.font_family or 'Consolas');
            if obj.font_family ~= family then obj.font_family = family; end
            if obj.font_height ~= height then obj.font_height = height; end

            local bold = settings.font_bold == true;
            local italic = settings.font_italic == true;
            if obj.bold ~= bold then obj.bold = bold; end
            if obj.italic ~= italic then obj.italic = italic; end

            local preview_draw_flags = FontDrawFlags.None;
            if effect_has_outline(current_effect()) then
                preview_draw_flags = bit.bor(preview_draw_flags, FontDrawFlags.Outlined);
            end
            if obj.draw_flags ~= preview_draw_flags then
                obj.draw_flags = preview_draw_flags;
            end

            local display_text = display_case(rendered_event_text(ev));
            if obj.text ~= display_text then obj.text = display_text; end
            if obj.position_x ~= start_x then obj.position_x = start_x; end

            -- Width of the rendered FontManager text. Falls back to an ImGui
            -- estimate scaled to the font height when the size is unavailable.
            local text_w = 0;
            local ok_size, measured = pcall(function()
                local w = obj:get_text_size();
                return tonumber(w);
            end);
            if ok_size and measured and measured > 0 then
                text_w = measured;
            else
                local base = imgui.GetFontSize();
                local est = tonumber((imgui.CalcTextSize(display_text))) or 0;
                if base > 0 then
                    text_w = est * (height / base) * 1.15;
                end
            end
            if text_w > max_w then max_w = text_w; end
            if obj.position_y ~= y then obj.position_y = y; end

            local c = event_color(ev);
            local new_color = rgba_to_argb(c, clamp(tonumber(settings.text_opacity) or 1.0, 0.1, 1.0));
            local new_outline = effect_has_outline(current_effect())
                and custom_outline_argb(c, 1.0)
                or 0x00000000;

            if obj.color ~= new_color then obj.color = new_color; end
            if obj.color_outline ~= new_outline then obj.color_outline = new_outline; end
            if obj.visible ~= true then obj.visible = true; end
        end

        y = y + line_height;
        used_height = used_height + line_height;
    end

    -- Reserve the physical space occupied by FontManager text so the Tools
    -- section begins below the live preview instead of underneath it.
    imgui.Dummy({ 1, used_height });
    state.preview_needed_w = max_w;

    -- FontManager text always renders underneath ImGui windows. Remember the
    -- preview area so the Tools window can leave that area unpainted and the
    -- preview text shows through it.
    local win_x = tonumber((imgui.GetWindowPos())) or start_x;
    local win_w = tonumber((imgui.GetWindowSize())) or 400;
    state.preview_hole = {
        x1 = start_x - 6,
        y1 = start_y - 4,
        x2 = win_x + win_w - 12,
        y2 = start_y + used_height + 4,
    };

    -- Hide any extra preview objects left from a future/older larger sample set.
    for i = #samples + 1, #state.preview_font_pool do
        local obj = state.preview_font_pool[i];
        if obj then obj.visible = false; end
    end
end

local function draw_bool_setting(label, current, key)
    local value = { current == true };
    if imgui.Checkbox(label, value) then
        settings[key] = value[1];
        save_settings();
    end
end

local function draw_event_option(label, key)
    ensure_event_option(key);

    local opt = settings.event_options[key];
    local shown = { opt.show ~= false };

    if imgui.Checkbox('##show_' .. key, shown) then
        opt.show = shown[1];
        save_settings();
    end

    imgui.SameLine();
    imgui.Text(label);
    imgui.SameLine();

    local c = {
        tonumber(opt.color[1]) or 1.0,
        tonumber(opt.color[2]) or 1.0,
        tonumber(opt.color[3]) or 1.0
    };

    if imgui.ColorEdit3('##color_' .. key, c, ImGuiColorEditFlags_NoInputs) then
        opt.color[1] = c[1];
        opt.color[2] = c[2];
        opt.color[3] = c[3];
        opt.color[4] = 1.0;
        save_settings();
    end
end

local function draw_lane_direction(key, title, accent)
    local lane = settings[key];

    imgui.TextColored(accent, title);

    align_label();
    imgui.Text('Text Direction');
    imgui.SameLine(130);
    if draw_toggle_button('Left', key .. '_orient_left', (lane.orientation or 'right') == 'left')
        and (lane.orientation or 'right') ~= 'left' then
        lane.orientation = 'left';
        save_settings();
    end

    imgui.SameLine();
    if draw_toggle_button('Right', key .. '_orient_right', (lane.orientation or 'right') == 'right')
        and (lane.orientation or 'right') ~= 'right' then
        lane.orientation = 'right';
        save_settings();
    end

    imgui.TextDisabled('Left = text extends left from anchor; Right = extends right.');

    align_label();
    imgui.Text('Growth');
    imgui.SameLine(130);
    if draw_toggle_button('Up', key .. '_growth_up', (lane.growth or 'up') == 'up')
        and (lane.growth or 'up') ~= 'up' then
        lane.growth = 'up';
        save_settings();
    end

    imgui.SameLine();
    if draw_toggle_button('Down', key .. '_growth_down', (lane.growth or 'up') == 'down')
        and (lane.growth or 'up') ~= 'down' then
        lane.growth = 'down';
        save_settings();
    end

    if settings.locked == true then
        imgui.TextColored(UI_MUTED, ('Position locked at %.0f, %.0f'):fmt(
            tonumber(lane.x) or 0,
            tonumber(lane.y) or 0
        ));
    else
        imgui.PushItemWidth(105);
        local x = { tonumber(lane.x) or 0 };
        local y = { tonumber(lane.y) or 0 };

        if imgui.InputFloat('X##' .. key, x, 5.0, 20.0, '%.0f') then
            lane.x = x[1];
            save_settings();
        end
        imgui.SameLine();
        if imgui.InputFloat('Y##' .. key, y, 5.0, 20.0, '%.0f') then
            lane.y = y[1];
            save_settings();
        end
        imgui.PopItemWidth();
    end
end

local function add_test_events()
    add_event('outgoing', 'outgoing', '34' .. target_suffix('Diving Beetle'), 'melee_damage');
    add_event('outgoing', 'critical', '88' .. target_suffix('Diving Beetle'), 'criticals');
    add_event('outgoing', 'outgoing', '74' .. target_suffix('Diving Beetle'), 'ranged_damage');
    add_event('outgoing', 'ability', 'Fast Blade  156' .. target_suffix('Diving Beetle'), 'weapon_skills');
    add_event('outgoing', 'ability', 'Light  84' .. target_suffix('Diving Beetle'), 'skillchains');
    add_event('outgoing', 'ability', 'Bludgeon  48' .. target_suffix('Diving Beetle') .. ' [MB]', 'magic_bursts');
    add_event('outgoing', 'ability', 'Add. Effect  12' .. target_suffix('Diving Beetle'), 'additional_effects');
    add_event('outgoing', 'ability', 'Cure  120' .. target_suffix('Kyrias'), 'spells');
    add_event('outgoing', 'ability', 'Cocoon  ->  You', 'buffs');
    add_event('incoming', 'incoming', '-24' .. source_suffix('Diving Beetle'), 'incoming_damage');
    add_event('incoming', 'incoming', '-87' .. source_suffix('Diving Beetle') .. ' [BLOCK]', 'incoming_damage');
    add_event('incoming', 'miss', 'PARRY' .. source_suffix('Diving Beetle'), 'defenses');
    add_event('incoming', 'miss', '1 absorbed' .. source_suffix('Diving Beetle'), 'defenses', { symbol = '[SHADOW] ' });
    add_event('incoming', 'ability', 'Slow' .. source_suffix('Diving Beetle'), 'status_negative');
    add_event('incoming', 'heal', '+93 HP  <-  Pollen', 'healing_received');
    add_event('incoming', 'heal', '+24 MP  <-  Magic Hammer', 'mp_recovery');
    add_event('incoming', 'heal', '[REST] +20 HP / +15 MP / -100 TP', 'resting');
    add_event('incoming', 'heal', '[REGEN] +24 HP / [AUTO REFRESH] +1 MP', 'regen_ticks', { segments = {
        { text = '[REGEN] +24 HP', event_type = 'regen_ticks' }, { text = ' / ', event_type = 'regen_ticks' },
        { text = '[AUTO REFRESH] +1 MP', event_type = 'refresh_ticks' } } });
    add_event('incoming', 'xp', '+189 EXP', 'exp');
    add_event('incoming', 'gil', '+9 gil', 'gil');
    add_event('incoming', 'xp', 'Sword +0.3', 'skill_ups');
    add_event('incoming', 'xp', 'Beastman Seal', 'item_drops');
    add_event('incoming', 'xp', 'Beastman Seal', 'item_obtained');
    add_event('incoming', 'xp', '=== Area: East Ronfaure ===', 'zone_change', { symbol = '' });
    add_event('outgoing', 'ability', 'Fire II  212' .. target_suffix('Diving Beetle'), 'spells', { element = 0 });
    add_event('outgoing', 'ability', 'Blizzard  98' .. target_suffix('Diving Beetle'), 'spells', { element = 1 });
    add_event('outgoing', 'ability', 'Firaga  840 (4 targets)', 'spells', { element = 0 });
    add_event('incoming', 'ability', 'Protect wearing off', 'wear_warning');
    add_event('incoming', 'ability', 'Haste wore off', 'status_removed');
    add_event('incoming', 'ability', 'Food wears off in 20s', 'food_warning');
    add_event('incoming', 'xp', 'Level 31', 'level_up');
    add_event('outgoing', 'ability', 'Savage Blade  1120' .. target_suffix('Diving Beetle'), 'weapon_skills', { amount = 1120 });
end

local function draw_general_config_tab()
    section_header('DISPLAY & BEHAVIOR', UI_ACCENT_TEXT);

    imgui.PushItemWidth(235);

    local theme_index = 0;
    local theme_items = {};
    for index, key in ipairs(UI_THEME_ORDER) do
        theme_items[#theme_items + 1] = UI_THEMES[key].label;
        if key == tostring(settings.ui_theme or 'garnet'):lower() then
            theme_index = index - 1;
        end
    end

    local theme_value = { theme_index };
    if imgui.Combo('Theme##scl_theme', theme_value, table.concat(theme_items, '\0') .. '\0\0') then
        local chosen = UI_THEME_ORDER[(tonumber(theme_value[1]) or 0) + 1];
        if chosen and chosen ~= settings.ui_theme then
            settings.ui_theme = chosen;
            save_settings();
        end
    end

    local duration = { tonumber(settings.duration) or 3.5 };
    if imgui.SliderFloat('Display Time##scl', duration, 0.5, 12.0, '%.1f sec') then
        settings.duration = duration[1];
        save_settings();
    end

    local speed = { tonumber(settings.scroll_speed) or 70.0 };
    if imgui.SliderFloat('Scroll Speed##scl', speed, 0.0, 300.0, '%.0f px/s') then
        settings.scroll_speed = speed[1];
        save_settings();
    end

    local global_font = { tonumber(settings.font_scale) or 1.35 };
    if imgui.SliderFloat('Global Font##scl', global_font, 0.75, 3.00, '%.2fx') then
        settings.font_scale = global_font[1];
        save_settings();
    end

    local max_visible = { math.floor(tonumber(settings.max_visible_events) or 14) };
    if imgui.SliderInt('Maximum Visible Events##scl', max_visible, 4, 30) then
        settings.max_visible_events = max_visible[1];
        save_settings();
    end

    imgui.PopItemWidth();
    help_marker('Caps active scrolling rows to keep heavy combat readable and predictable.');

    imgui.Spacing();
    section_header('CONTENT', UI_ACCENT_TEXT);

    local symbols = { settings.show_symbols == true };
    if imgui.Checkbox('Event Symbols / Prefixes', symbols) then
        settings.show_symbols = symbols[1];
        save_settings();
    end

    local targets = { settings.show_target_names ~= false };
    if imgui.Checkbox('Show Outgoing Target Names', targets) then
        settings.show_target_names = targets[1];
        save_settings();
    end
    help_marker('When disabled, outgoing damage/spells omit the "-> Target" suffix.');

    local sources = { settings.show_source_names ~= false };
    if imgui.Checkbox('Show Incoming Source Names', sources) then
        settings.show_source_names = sources[1];
        save_settings();
    end
    help_marker('When disabled, incoming damage/effects omit the "<- Source" suffix.');

    local zeroes = { settings.show_zero_damage == true };
    if imgui.Checkbox('Show 0 Damage / No-Damage Results', zeroes) then
        settings.show_zero_damage = zeroes[1];
        save_settings();
    end
    help_marker('Shows numeric zero-damage results. Full resists can still appear as [RESIST].');

    local misses = { settings.show_misses ~= false };
    if imgui.Checkbox('Show Misses', misses) then
        settings.show_misses = misses[1];
        save_settings();
    end

    local combine = { settings.combine_repeated_hits ~= false };
    if imgui.Checkbox('Combine Rapid Repeated Hits', combine) then
        settings.combine_repeated_hits = combine[1];
        save_settings();
    end
    help_marker('Merges rapid melee/ranged hits from the same source/target into "total (N hits)".');

    imgui.Spacing();
    section_header('POSITIONING', UI_ACCENT_TEXT);

    local locked = { settings.locked == true };
    if imgui.Checkbox('Lock Positions', locked) then
        settings.locked = locked[1];

        if settings.locked then
            state.move_mode = false;
        else
            state.move_mode = true;
            state.move_initialized.incoming = false;
            state.move_initialized.outgoing = false;
        end

        save_settings();
    end
    help_marker('Unlocked positions immediately show the draggable Incoming and Outgoing anchor boxes.');
end

local function draw_checkbox_setting(label, key, help)
    local value = { settings[key] == true };
    if imgui.Checkbox(label, value) then
        settings[key] = value[1];
        save_settings();
    end
    if help then help_marker(help); end
end

local function draw_motion_choice(lane_key, title)
    local lane = settings[lane_key];
    local motion = tostring(lane.motion or 'scroll');

    align_label();
    imgui.Text(title);
    imgui.SameLine(130);
    for index, option in ipairs({ { 'scroll', 'Scroll' }, { 'arc', 'Arc' }, { 'fade', 'Fade In' } }) do
        if index > 1 then imgui.SameLine(); end
        if draw_toggle_button(option[2], lane_key .. '_motion_' .. option[1], motion == option[1])
            and motion ~= option[1] then
            lane.motion = option[1];
            save_settings();
        end
    end
end

local function draw_notify_option(label, key)
    local value = { settings.notify[key] == true };
    if imgui.Checkbox(label .. '##notify_' .. key, value) then
        settings.notify[key] = value[1];
        save_settings();
    end
end

local function draw_display_config_tab()
    section_header('MOTION', UI_ACCENT_TEXT);
    draw_motion_choice('outgoing', 'Outgoing');
    draw_motion_choice('incoming', 'Incoming');
    imgui.TextDisabled('Scroll = straight. Arc = curves sideways as it rises. Fade In = appears in place and drifts.');

    imgui.Spacing();
    section_header('EFFECTS', UI_ACCENT_TEXT);
    draw_checkbox_setting('Critical Pop', 'crit_pop',
        'Criticals briefly grow, then settle. Performance renderer only; Custom Font keeps a fixed size.');
    draw_checkbox_setting('Element Colors', 'element_colors',
        'Spells and additional effects use their element color (Fire, Ice, Wind, Earth, Thunder, Water, Light, Dark) instead of the category color.');
    draw_checkbox_setting('Combine AoE Hits', 'combine_aoe',
        'One line for a spell / weapon skill / ability that hits several targets, e.g. "Firaga III  1840 (4 targets)".');

    imgui.Spacing();
    section_header('NOTIFICATIONS (CENTER LANE)', UI_ACCENT_TEXT);
    imgui.TextDisabled('Checked events move to the center lane instead of scrolling.');
    draw_notify_option('Level Up', 'level_up');
    draw_notify_option('Skillchains', 'skillchains');
    draw_notify_option('Magic Bursts', 'magic_bursts');
    draw_notify_option('Zone Change', 'zone_change');
    draw_notify_option('Buff Wearing Off', 'wear_warning');
    draw_notify_option('Big Hits (copy of large outgoing damage)', 'big_hits');
    draw_notify_option('Low HP Warning', 'low_hp');
    draw_notify_option('Buff Wore Off (Protect, Haste, ...)', 'status_removed');
    draw_notify_option('Food Running Out (20s, then every 5s)', 'food_warning');

    imgui.PushItemWidth(235);
    local threshold = { math.floor(tonumber(settings.big_hit_threshold) or 500) };
    if imgui.SliderInt('Big Hit Threshold##scl', threshold, 50, 5000) then
        settings.big_hit_threshold = threshold[1];
        save_settings();
    end
    local scale = { tonumber(settings.notify_scale) or 1.30 };
    if imgui.SliderFloat('Notification Size##scl', scale, 0.80, 2.50, '%.2fx') then
        settings.notify_scale = scale[1];
        save_settings();
    end
    imgui.PopItemWidth();
    imgui.TextDisabled('Move the center lane with /scl unlock (Notifications handle).');
end


-- Generic dropdown over a { {key, label}, ... } list. Returns the chosen key
-- when it changed, otherwise nil.
local function draw_choice_combo(label, list, current_key)
    local index = 0;
    local labels = {};
    for i, item in ipairs(list) do
        labels[#labels + 1] = item.label;
        if item.key == current_key then index = i - 1; end
    end
    local value = { index };
    if imgui.Combo(label, value, table.concat(labels, '\0') .. '\0\0') then
        local chosen = list[(tonumber(value[1]) or 0) + 1];
        if chosen and chosen.key ~= current_key then
            return chosen.key;
        end
    end
    return nil;
end

local function draw_font_style_config_tab()
    section_header('FONT STYLE', UI_ACCENT_TEXT);

    local renderer = settings.renderer_mode or 'performance';
    local custom = renderer == 'custom';

    align_label();
    imgui.Text('Renderer');
    imgui.SameLine(130);

    if draw_toggle_button('Performance', 'renderer_performance', renderer == 'performance')
        and renderer ~= 'performance' then
        settings.renderer_mode = 'performance';
        hide_unused_fonts(1);
        save_settings();
    end

    imgui.SameLine();

    if draw_toggle_button('Custom Font', 'renderer_custom', renderer == 'custom')
        and renderer ~= 'custom' then
        settings.renderer_mode = 'custom';
        rebuild_font_pool();
        save_settings();
    end

    if not custom then
        imgui.TextColored(UI_MUTED, 'Recommended: smooth ImGui renderer. Every effect below is supported.');
    else
        imgui.TextColored(UI_MUTED, 'Windows fonts via FontManager. Each style is built once and reused (no hitching).');
    end

    imgui.Spacing();
    imgui.PushItemWidth(235);

    -- Font family (Custom Font). Dropdown plus the old < > buttons.
    local family = tostring(settings.font_family or 'Consolas');
    local family_index = 0;
    for i, name in ipairs(FONT_FAMILIES) do
        if name == family then family_index = i - 1; end
    end
    local family_value = { family_index };
    if imgui.Combo('Font Family##scl_font_family', family_value, table.concat(FONT_FAMILIES, '\0') .. '\0\0') then
        local chosen = FONT_FAMILIES[(tonumber(family_value[1]) or 0) + 1];
        if chosen and chosen ~= family then set_font_family(chosen); end
    end
    imgui.SameLine();
    if imgui.SmallButton('<##font_family_prev') then cycle_font_family(-1); end
    imgui.SameLine();
    if imgui.SmallButton('>##font_family_next') then cycle_font_family(1); end
    if not custom then
        imgui.TextColored(UI_MUTED, 'Font Family and Italic apply to Custom Font only.');
    end

    local bold = { settings.font_bold == true };
    if imgui.Checkbox('Bold', bold) then
        settings.font_bold = bold[1];
        save_settings();
        if custom then rebuild_font_pool(); end
    end
    imgui.SameLine();

    local italic = { settings.font_italic == true };
    if imgui.Checkbox('Italic', italic) then
        settings.font_italic = italic[1];
        save_settings();
        if custom then rebuild_font_pool(); end
    end
    imgui.SameLine();

    local caps = { settings.all_caps == true };
    if imgui.Checkbox('ALL CAPS', caps) then
        settings.all_caps = caps[1];
        save_settings();
    end

    local opacity = { clamp(tonumber(settings.text_opacity) or 1.0, 0.1, 1.0) };
    if imgui.SliderFloat('Text Opacity##scl_text_opacity', opacity, 0.10, 1.00, '%.2f') then
        settings.text_opacity = opacity[1];
        save_settings();
    end

    imgui.Spacing();
    section_header('TEXT EFFECT', UI_ACCENT_TEXT);

    local effect = current_effect();
    local chosen_effect = draw_choice_combo('Effect##scl_text_effect', TEXT_EFFECTS, effect);
    if chosen_effect then
        settings.text_effect = chosen_effect;
        settings.font_outline = effect_has_outline(chosen_effect);
        save_settings();
        if custom then rebuild_font_pool(); end
        effect = chosen_effect;
    end
    if custom and effect == 'glow' then
        imgui.TextColored(UI_MUTED, 'Glow is Performance-only; Custom Font shows plain text.');
    end

    if effect ~= 'none' and effect ~= 'glow' then
        local chosen_color = draw_choice_combo('Effect Color##scl_effect_color', EFFECT_COLORS,
            tostring(settings.effect_color or 'black'));
        if chosen_color then
            settings.effect_color = chosen_color;
            save_settings();
        end
    end

    if effect ~= 'none' then
        local strength = { clamp(tonumber(settings.effect_opacity) or 0.85, 0.1, 1.0) };
        if imgui.SliderFloat('Effect Strength##scl_effect_opacity', strength, 0.10, 1.00, '%.2f') then
            settings.effect_opacity = strength[1];
            save_settings();
        end
    end

    if effect_has_shadow(effect) then
        local offset = { math.floor(clamp(tonumber(settings.shadow_offset) or 2, 1, 6)) };
        if imgui.SliderInt('Shadow Distance##scl_shadow_offset', offset, 1, 6, '%d px') then
            settings.shadow_offset = offset[1];
            save_settings();
        end
        if custom then
            imgui.TextColored(UI_MUTED, 'Custom Font shadow uses a second font copy behind the text.');
        end
    end

    imgui.Spacing();
    section_header('BACKING PLATE', UI_ACCENT_TEXT);

    local chosen_plate = draw_choice_combo('Plate##scl_text_plate', TEXT_PLATES, tostring(settings.text_plate or 'off'));
    if chosen_plate then
        settings.text_plate = chosen_plate;
        save_settings();
    end
    if tostring(settings.text_plate or 'off') ~= 'off' then
        local plate_opacity = { clamp(tonumber(settings.plate_opacity) or 0.45, 0.05, 1.0) };
        if imgui.SliderFloat('Plate Opacity##scl_plate_opacity', plate_opacity, 0.05, 1.00, '%.2f') then
            settings.plate_opacity = plate_opacity[1];
            save_settings();
        end
        local rounding = { clamp(tonumber(settings.plate_rounding) or 4.0, 0.0, 12.0) };
        if imgui.SliderFloat('Plate Rounding##scl_plate_rounding', rounding, 0.0, 12.0, '%.0f px') then
            settings.plate_rounding = rounding[1];
            save_settings();
        end
    end
    if custom then
        imgui.TextColored(UI_MUTED, 'The backing plate is drawn by the Performance renderer only.');
    else
        imgui.TextColored(UI_MUTED, 'A soft box behind each line; helps on bright ground / snow.');
    end

    imgui.PopItemWidth();

    imgui.Spacing();
    section_header('TYPOGRAPHY', UI_ACCENT_TEXT);

    imgui.PushItemWidth(235);

    local melee = { tonumber(settings.melee_scale) or 1.00 };
    if imgui.SliderFloat('Normal Damage##scale', melee, 0.60, 2.00, '%.2fx') then
        settings.melee_scale = melee[1];
        save_settings();
    end

    local ability = { tonumber(settings.ability_scale) or 1.00 };
    if imgui.SliderFloat('Abilities / WS##scale', ability, 0.60, 2.00, '%.2fx') then
        settings.ability_scale = ability[1];
        save_settings();
    end

    local heal = { tonumber(settings.heal_scale) or 1.00 };
    if imgui.SliderFloat('Healing##scale', heal, 0.60, 2.00, '%.2fx') then
        settings.heal_scale = heal[1];
        save_settings();
    end

    local reward = { tonumber(settings.reward_scale) or 1.00 };
    if imgui.SliderFloat('Rewards##scale', reward, 0.60, 2.00, '%.2fx') then
        settings.reward_scale = reward[1];
        save_settings();
    end

    imgui.PopItemWidth();

    imgui.TextColored(
        UI_MUTED,
        'Criticals use Normal Damage size; * prefix and Critical color identify them.'
    );
end

local function draw_outgoing_config_tab()
    section_header('OUTGOING EVENTS', UI_ACCENT_TEXT);

    draw_event_option('Melee Damage', 'melee_damage');
    draw_event_option('Ranged Damage', 'ranged_damage');
    draw_event_option('Criticals', 'criticals');
    draw_event_option('Weapon Skills', 'weapon_skills');
    draw_event_option('Spells', 'spells');
    draw_event_option('Magic Bursts', 'magic_bursts');
    draw_event_option('Skillchains', 'skillchains');
    draw_event_option('Abilities', 'outgoing_abilities');
    draw_event_option('Pet Damage', 'pet_damage');
    draw_event_option('Additional Effects', 'additional_effects');
    draw_event_option('Counters / Retaliation', 'counters');
    draw_event_option('Buffs', 'buffs');

    imgui.Spacing();
    section_header('OUTGOING LAYOUT', UI_ACCENT_TEXT);
    draw_lane_direction('outgoing', 'Outgoing Lane', UI_GOLD);
end

local function draw_incoming_config_tab()
    section_header('INCOMING EVENTS', UI_ACCENT_TEXT);

    draw_event_option('Incoming Damage', 'incoming_damage');
    draw_event_option('Incoming Abilities', 'incoming_abilities');
    draw_event_option('Defenses (Evade/Parry/Block/Shadows)', 'defenses');
    draw_event_option('Positive Status', 'status_positive');
    draw_event_option('Negative Status', 'status_negative');
    draw_event_option('Buff Wore Off', 'status_removed');
    draw_event_option('Healing Received', 'healing_received');
    draw_event_option('MP Recovery', 'mp_recovery');
    draw_event_option('Resting (/heal) Ticks', 'resting');
    draw_event_option('Regen Ticks', 'regen_ticks');
    draw_event_option('Refresh Ticks', 'refresh_ticks');
    draw_event_option('Drain / Aspir', 'drain_aspir');
    draw_event_option('KO / Defeat', 'ko');
    draw_event_option('Low HP Warning', 'low_hp');
    imgui.PushItemWidth(235);
    local low_hp = { math.floor(tonumber(settings.low_hp_percent) or 25) };
    if imgui.SliderInt('Low HP Warning At##scl_lowhp', low_hp, 5, 75, '%d%%') then
        settings.low_hp_percent = low_hp[1];
        save_settings();
    end
    imgui.PopItemWidth();

    imgui.Spacing();
    section_header('INCOMING LAYOUT', UI_ACCENT_TEXT);
    draw_lane_direction('incoming', 'Incoming Lane', UI_RED);

    imgui.Spacing();
    section_header('REWARDS', UI_ACCENT_TEXT);

    draw_event_option('EXP / LP / CP / JP', 'exp');
    draw_event_option('Gil', 'gil');
    draw_event_option('Level Up', 'level_up');
    draw_event_option('Skill Ups', 'skill_ups');
    draw_event_option('Item Drops (found in treasure pool)', 'item_drops');
    draw_event_option('Items Obtained (received)', 'item_obtained');
    draw_event_option('Zone Change (=== Area ===)', 'zone_change');
    draw_event_option('Buff Wearing Off Warning', 'wear_warning');
    draw_event_option('Food Running Out (20s, then every 5s)', 'food_warning');
end


local function geometry_changed(last, x, y, w, h)
    if not last then return true end
    return math.abs((last.x or 0) - x) >= 1
        or math.abs((last.y or 0) - y) >= 1
        or math.abs((last.w or 0) - w) >= 1
        or math.abs((last.h or 0) - h) >= 1;
end

local function persist_window_geometry(which, x, y, w, h)
    local target = settings.config_tools_window;
    if which == 'main' then
        target = settings.config_window;
    elseif which == 'session' then
        target = settings.session_window;
    end
    if not target then return end

    target.x = math.floor(x + 0.5);
    target.y = math.floor(y + 0.5);
    target.w = math.floor(w + 0.5);
    target.h = math.floor(h + 0.5);

    local now = os.clock();
    if (now - (state.config_geometry.last_save_clock or 0)) >= 0.35 then
        state.config_geometry.last_save_clock = now;
        save_settings();
    end
end

local function capture_current_window_geometry(which)
    -- Current Ashita v4 imgui.GetWindowPos() / GetWindowSize() return
    -- TWO numeric values, not an ImVec2/table. Indexing the first return value
    -- triggers the sugar math namespace error seen in 1.0.4.
    local x, y = imgui.GetWindowPos();
    local w, h = imgui.GetWindowSize();

    x = tonumber(x);
    y = tonumber(y);
    w = tonumber(w);
    h = tonumber(h);

    if x == nil or y == nil or w == nil or h == nil then
        return;
    end

    local last_key = 'last_' .. tostring(which);
    local last = state.config_geometry[last_key];

    if geometry_changed(last, x, y, w, h) then
        state.config_geometry[last_key] = { x = x, y = y, w = w, h = h };
        persist_window_geometry(which, x, y, w, h);
    end
end

-- Paints the Tools window background everywhere except the live-preview
-- area, so Custom Font (FontManager) preview text stays visible.
local function draw_tools_background()
    local draw_list = imgui.GetWindowDrawList();
    if not draw_list then return; end

    local wx, wy = imgui.GetWindowPos();
    local ww, wh = imgui.GetWindowSize();
    wx = tonumber(wx); wy = tonumber(wy); ww = tonumber(ww); wh = tonumber(wh);
    if not wx or not wy or not ww or not wh then return; end

    local top = wy + (imgui.GetFrameHeight and imgui.GetFrameHeight() or 22);
    local right = wx + ww;
    local bottom = wy + wh;
    local bg = imgui.GetColorU32(UI_BG);
    local hole = state.preview_hole;

    if not hole then
        draw_list:AddRectFilled({ wx, top }, { right, bottom }, bg, 0.0);
        return;
    end

    local hx1 = clamp(hole.x1, wx, right);
    local hx2 = clamp(hole.x2, wx, right);
    local hy1 = clamp(hole.y1, top, bottom);
    local hy2 = clamp(hole.y2, top, bottom);

    draw_list:AddRectFilled({ wx, top }, { right, hy1 }, bg, 0.0);
    draw_list:AddRectFilled({ wx, hy2 }, { right, bottom }, bg, 0.0);
    draw_list:AddRectFilled({ wx, hy1 }, { hx1, hy2 }, bg, 0.0);
    draw_list:AddRectFilled({ hx2, hy1 }, { right, hy2 }, bg, 0.0);

    -- Frame the see-through preview area.
    draw_list:AddRect({ hx1, hy1 }, { hx2, hy2 }, imgui.GetColorU32(UI_BORDER), 4.0);
end

local function draw_config_companion()
    if not state.config_geometry.tools_initialized then
        imgui.SetNextWindowPos({
            tonumber(settings.config_tools_window.x) or defaults.config_tools_window.x,
            tonumber(settings.config_tools_window.y) or defaults.config_tools_window.y
        });
        imgui.SetNextWindowSize({
            tonumber(settings.config_tools_window.w) or defaults.config_tools_window.w,
            tonumber(settings.config_tools_window.h) or defaults.config_tools_window.h
        });
        state.config_geometry.tools_initialized = true;
    end

    -- Custom Font preview: the window background is painted manually around
    -- the preview area (see draw_tools_background) instead of by ImGui.
    local custom = (settings.renderer_mode or 'performance') == 'custom';
    if custom then
        imgui.PushStyleColor(ImGuiCol_WindowBg, UI_TRANSPARENT);
    else
        state.preview_hole = nil;
    end

    local tools_open = imgui.Begin('SCL Preview & Tools##scl_config_tools', nil, ImGuiWindowFlags_NoNav);

    if custom then
        imgui.PopStyleColor(1);
    end

    if not tools_open then
        hide_preview_fonts();
    end

    if tools_open then
        if custom then
            draw_tools_background();
        end
        capture_current_window_geometry('tools');
        section_header('LIVE PREVIEW', UI_ACCENT_TEXT);
        draw_live_preview();

        imgui.Spacing();
        section_header('TOOLS & RESET', UI_ACCENT_TEXT);

        if imgui.Button('Test Display') then
            add_test_events();
        end
        imgui.SameLine();
        if imgui.Button('Clear Active Text') then
            state.events = {};
            hide_unused_fonts(1);
        end

        if imgui.Button('Reset Outgoing Position') then
            reset_anchor('outgoing');
        end
        imgui.SameLine();
        if imgui.Button('Reset Incoming Position') then
            reset_anchor('incoming');
        end
        if imgui.Button('Reset Notification Position') then
            reset_anchor('notification');
        end

        if draw_toggle_button('Session Summary', 'tools_session', state.session_open[1] == true) then
            state.session_open[1] = not state.session_open[1];
            state.session_geometry_initialized = false;
        end
        imgui.SameLine();
        if draw_toggle_button(state.debug and 'Debug Log: ON' or 'Debug Log: OFF', 'tools_debug', state.debug == true) then
            debuglog.set_enabled(not state.debug);
        end

        if not state.confirm_reset_all then
            if imgui.Button('Reset All Settings') then
                state.confirm_reset_all = true;
            end
        else
            imgui.TextColored(UI_RED, 'Reset every SCL setting?');
            if imgui.Button('Confirm Reset All') then
                reset_all_settings();
            end
            imgui.SameLine();
            if imgui.Button('Cancel Reset') then
                state.confirm_reset_all = false;
            end
        end

        imgui.Spacing();
        section_header('COMMANDS', UI_ACCENT_TEXT);
        imgui.TextColored(UI_MUTED, '/scl config  - close/open configuration');
        imgui.TextColored(UI_MUTED, '/scl unlock  - show draggable anchor boxes');
        imgui.TextColored(UI_MUTED, '/scl lock    - save/lock positions');
        imgui.TextColored(UI_MUTED, '/scl test    - show sample events');
        imgui.TextColored(UI_MUTED, '/scl clear   - clear active text');
        imgui.TextColored(UI_MUTED, '/scl pause   - pause/resume capture');
        imgui.TextColored(UI_MUTED, '/scl session - session summary window');
        imgui.TextColored(UI_MUTED, '/scl debug   - log unmapped messages to file');
        imgui.TextColored(UI_MUTED, '/scl         - show/hide combat text');
    end
    imgui.End();
end

-- ============================================================================
-- Session summary window (local player only)
-- ============================================================================

local function format_number(value)
    local text = tostring(math.floor((tonumber(value) or 0) + 0.5));
    local sign, digits = text:match('^(%-?)(%d+)$');
    if not digits then return text end
    local formatted = digits:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '');
    return sign .. formatted;
end

local function format_duration(seconds)
    seconds = math.floor(tonumber(seconds) or 0);
    local h = math.floor(seconds / 3600);
    local m = math.floor((seconds % 3600) / 60);
    local sec = seconds % 60;
    if h > 0 then
        return ('%dh %02dm'):fmt(h, m);
    end
    return ('%dm %02ds'):fmt(m, sec);
end

local function session_row(label, value, color)
    imgui.TextColored(UI_MUTED, label);
    -- Value column scales with the window's text size.
    imgui.SameLine(math.floor(150 * clamp(tonumber(settings.session_font_scale) or 1.0, 0.75, 2.50)));
    if color then
        imgui.TextColored(color, value);
    else
        imgui.Text(value);
    end
end

-- ----------------------------------------------------------------------------
-- Items Obtained panel: a borderless sister window attached to the Session
-- window. It sizes itself to the item list (more columns once a column is as
-- tall as the Session window) so the Session window never has to be resized.
-- Hidden while no items have been obtained.
-- ----------------------------------------------------------------------------

local ITEMS_SIDE_ORDER = { 'right', 'left', 'below', 'inside' };
local ITEMS_SIDE_LABELS = 'Right side\0Left side\0Below\0Inside window\0\0';

local function session_items_side()
    local side = tostring(settings.session_items_side or 'right'):lower();
    for _, key in ipairs(ITEMS_SIDE_ORDER) do
        if key == side then return side; end
    end
    return 'right';
end

local function draw_session_items_panel(anchor)
    local data = anchor.data;
    if data == nil or data.drop_order == nil or #data.drop_order == 0 then
        return;
    end

    local entries = {};
    for _, key in ipairs(data.drop_order) do
        local entry = data.drops[key];
        if entry then
            entries[#entries + 1] = ('%s  x%d'):fmt(tostring(entry.name or '?'), tonumber(entry.count) or 0);
        end
    end
    if #entries == 0 then return; end

    local gap = 4;
    local font_scale = anchor.font_scale or 1.0;
    local line_h = (tonumber(imgui.GetTextLineHeightWithSpacing()) or 17) * font_scale;

    -- Rows per column: as tall as the Session window when docked on a side,
    -- a fixed 10 rows when docked below.
    local rows;
    if anchor.side == 'below' then
        rows = 10;
    else
        rows = math.floor((anchor.h - (line_h * 2.5) - 24) / math.max(line_h, 1));
    end
    rows = math.max(4, rows);
    local columns = math.ceil(#entries / rows);

    local px, py;
    if anchor.side == 'below' then
        px, py = anchor.x, anchor.y + anchor.h + gap;
    elseif anchor.side == 'left' then
        local w = tonumber(state.items_panel_w) or 200;
        px, py = anchor.x - w - gap, anchor.y;
    else
        px, py = anchor.x + anchor.w + gap, anchor.y;
    end
    imgui.SetNextWindowPos({ px, py });

    local flags = bit.bor(
        ImGuiWindowFlags_NoTitleBar,
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoMove,
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoNav,
        ImGuiWindowFlags_NoFocusOnAppearing or 0,
        ImGuiWindowFlags_NoSavedSettings or 0
    );

    push_theme();
    if imgui.Begin('SCL Items##scl_session_items', nil, flags) then
        imgui.PushFont(nil, imgui.GetFontSize() * font_scale);

        section_header(('ITEMS OBTAINED (%d)'):fmt(#entries), UI_ACCENT_TEXT);

        for col = 1, columns do
            if col > 1 then imgui.SameLine(0, 22); end
            imgui.BeginGroup();
            local first = (col - 1) * rows + 1;
            local last = math.min(#entries, col * rows);
            for i = first, last do
                imgui.Text(entries[i]);
            end
            imgui.EndGroup();
        end

        imgui.PopFont();

        local w = select(1, imgui.GetWindowSize());
        state.items_panel_w = tonumber(w) or state.items_panel_w;
    end
    imgui.End();
    pop_theme();
end

local function draw_session_window()
    local anchor = nil;
    if not state.session_open[1] then
        state.session_geometry_initialized = false;
        state.config_geometry.last_session = nil;
        return;
    end

    if not state.session_geometry_initialized then
        imgui.SetNextWindowPos({
            tonumber(settings.session_window.x) or 1320,
            tonumber(settings.session_window.y) or 120
        });
        imgui.SetNextWindowSize({
            tonumber(settings.session_window.w) or 360,
            tonumber(settings.session_window.h) or 420
        });
        state.session_geometry_initialized = true;
    end

    push_theme();

    if imgui.Begin('SCL Session##scl_session', state.session_open, ImGuiWindowFlags_NoNav) then
        capture_current_window_geometry('session');

        -- Text size for the window contents (title bar keeps its size).
        local font_scale = clamp(tonumber(settings.session_font_scale) or 1.0, 0.75, 2.50);
        imgui.PushFont(nil, imgui.GetFontSize() * font_scale);

        local data = session.get();
        local hours = data.elapsed / 3600.0;

        section_header('SESSION  ' .. format_duration(data.elapsed), UI_ACCENT_TEXT);
        session_row('EXP', format_number(data.exp) .. '   (' .. format_number(data.exp / hours) .. ' / hr)');
        if data.limit > 0 then
            session_row('Limit Points', format_number(data.limit) .. '   (' .. format_number(data.limit / hours) .. ' / hr)');
        end
        if data.capacity > 0 then
            session_row('Capacity Points', format_number(data.capacity) .. '   (' .. format_number(data.capacity / hours) .. ' / hr)');
        end
        session_row('Gil', format_number(data.gil) .. '   (' .. format_number(data.gil / hours) .. ' / hr)');
        session_row('Kills', format_number(data.kills));

        section_header('DAMAGE', UI_ACCENT_TEXT);
        local fight = data.fight;
        if fight then
            session_row(fight.active and 'Current fight' or 'Last fight',
                format_number(fight.total) .. '   (' .. format_number(fight.dps) .. ' DPS, '
                    .. format_duration(fight.seconds) .. ')');
        else
            session_row('Current fight', '--');
        end
        session_row('Total damage', format_number(data.damage_total));

        if data.biggest_hit then
            session_row('Biggest hit', format_number(data.biggest_hit.amount)
                .. (data.biggest_hit.crit and ' (crit)' or '')
                .. '  ->  ' .. tostring(data.biggest_hit.target or '?'));
        else
            session_row('Biggest hit', '--');
        end

        if data.biggest_ws then
            session_row('Biggest WS', tostring(data.biggest_ws.name or '?') .. '  '
                .. format_number(data.biggest_ws.amount));
        else
            session_row('Biggest WS', '--');
        end

        if data.biggest_magic then
            session_row('Biggest Magic', tostring(data.biggest_magic.name or '?') .. '  '
                .. format_number(data.biggest_magic.amount));
        else
            session_row('Biggest Magic', '--');
        end

        section_header('DEFENSE & HEALING', UI_ACCENT_TEXT);

        local taken = data.biggest_hit_taken;
        if taken then
            session_row('Biggest hit taken', format_number(taken.amount) .. '  ('
                .. tostring(taken.name or 'melee') .. '  <-  ' .. tostring(taken.source or '?') .. ')');
        else
            session_row('Biggest hit taken', '--');
        end

        local heal_done = data.biggest_heal_done;
        if heal_done then
            session_row('Biggest heal done', format_number(heal_done.amount) .. '  ('
                .. tostring(heal_done.name or '?') .. '  ->  ' .. tostring(heal_done.target or '?') .. ')');
        else
            session_row('Biggest heal done', '--');
        end

        local heal_taken = data.biggest_heal_taken;
        if heal_taken then
            session_row('Biggest heal taken', format_number(heal_taken.amount) .. '  ('
                .. tostring(heal_taken.name or '?') .. '  <-  ' .. tostring(heal_taken.source or '?') .. ')');
        else
            session_row('Biggest heal taken', '--');
        end

        section_header('PET', UI_ACCENT_TEXT);

        if data.biggest_pet then
            local pet = data.biggest_pet;
            local source = pet.name and tostring(pet.name) or 'melee';
            session_row('Biggest Pet Hit', format_number(pet.amount) .. '  (' .. source
                .. (pet.pet and (', ' .. tostring(pet.pet)) or '') .. ')');
        else
            session_row('Biggest Pet Hit', '--');
        end

        local items_side = session_items_side();
        if items_side == 'inside' then
            section_header('ITEMS OBTAINED', UI_ACCENT_TEXT);
            if #data.drop_order == 0 then
                imgui.TextDisabled('None yet.');
            else
                for _, key in ipairs(data.drop_order) do
                    local entry = data.drops[key];
                    if entry then
                        imgui.Text(('%s  x%d'):fmt(entry.name, entry.count));
                    end
                end
            end
        end

        imgui.Spacing();
        imgui.Separator();
        if imgui.Button('Reset Session') then
            session.reset();
        end
        imgui.SameLine();
        imgui.TextDisabled('Your own numbers only.');

        imgui.PushItemWidth(160);
        local size_value = { font_scale };
        if imgui.SliderFloat('Text Size##scl_session_font', size_value, 0.75, 2.50, '%.2fx') then
            settings.session_font_scale = size_value[1];
            save_settings();
        end

        local side_index = 0;
        for index, key in ipairs(ITEMS_SIDE_ORDER) do
            if key == items_side then side_index = index - 1; end
        end
        local side_value = { side_index };
        if imgui.Combo('Items Panel##scl_items_side', side_value, ITEMS_SIDE_LABELS) then
            local chosen = ITEMS_SIDE_ORDER[(tonumber(side_value[1]) or 0) + 1];
            if chosen and chosen ~= items_side then
                settings.session_items_side = chosen;
                save_settings();
            end
        end
        imgui.PopItemWidth();

        imgui.PopFont();

        -- Remember where the Session window is so the items panel can attach.
        local wx, wy = imgui.GetWindowPos();
        local ww, wh = imgui.GetWindowSize();
        anchor = {
            x = tonumber(wx) or 0, y = tonumber(wy) or 0,
            w = tonumber(ww) or 0, h = tonumber(wh) or 0,
            font_scale = font_scale,
            data = data,
            side = items_side,
        };
    end
    imgui.End();

    pop_theme();

    if anchor ~= nil and anchor.side ~= 'inside' then
        draw_session_items_panel(anchor);
    end
end

local function draw_config()
    if not state.config_open[1] then
        hide_preview_fonts();
        state.config_geometry.main_initialized = false;
        state.config_geometry.tools_initialized = false;
        state.config_geometry.last_main = nil;
        state.config_geometry.last_tools = nil;
        return;
    end

    push_theme();

    if not state.config_geometry.main_initialized then
        imgui.SetNextWindowPos({
            tonumber(settings.config_window.x) or defaults.config_window.x,
            tonumber(settings.config_window.y) or defaults.config_window.y
        });
        imgui.SetNextWindowSize({
            tonumber(settings.config_window.w) or defaults.config_window.w,
            tonumber(settings.config_window.h) or defaults.config_window.h
        });
        state.config_geometry.main_initialized = true;
    end

    imgui.SetNextWindowSizeConstraints({ 620, 560 }, { 1200, 1200 });

    if imgui.Begin('Scrolling Combat Text - Config##scl_config', state.config_open, ImGuiWindowFlags_NoNav) then
        capture_current_window_geometry('main');
        imgui.TextColored(UI_ACCENT_TEXT, 'SELF-ONLY COMBAT DISPLAY');
        imgui.SameLine();
        imgui.TextColored(UI_MUTED, 'v' .. tostring(addon.version));
        imgui.TextDisabled('Completed actions, incoming effects, and personal rewards only.');

        imgui.Spacing();

        local config_tabs = {
            { label = 'General', id = 'scl_tab_general', draw = draw_general_config_tab },
            { label = 'Display', id = 'scl_tab_display', draw = draw_display_config_tab },
            { label = 'Font Style', id = 'scl_tab_font', draw = draw_font_style_config_tab },
            { label = 'Outgoing', id = 'scl_tab_outgoing', draw = draw_outgoing_config_tab },
            { label = 'Incoming', id = 'scl_tab_incoming', draw = draw_incoming_config_tab },
        };

        local selected_tab = tonumber(state.config_tab) or 1;
        if selected_tab < 1 or selected_tab > #config_tabs then
            selected_tab = 1;
        end

        -- Flat styled tab row with a red underline on the active tab.
        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 14, 6 });
        for index, tab in ipairs(config_tabs) do
            if index > 1 then
                imgui.SameLine(0, 4);
            end
            if draw_styled_tab(tab.label, tab.id, index == selected_tab) then
                selected_tab = index;
            end
        end
        imgui.PopStyleVar(1);
        state.config_tab = selected_tab;

        imgui.Spacing();
        imgui.Separator();

        -- Only the tab content scrolls; the header and tab row stay in place.
        imgui.BeginChild('##scl_config_content', { 0, 0 });
        config_tabs[selected_tab].draw();
        imgui.EndChild();
    end
    imgui.End();

    if state.config_open[1] then
        -- Grow the Tools window so the live preview always fits.
        local needed_w = math.floor((tonumber(state.preview_needed_w) or 0) + 48);
        local min_w = math.max(380, math.min(needed_w, 1600));
        imgui.SetNextWindowSizeConstraints({ min_w, 520 }, { math.max(800, min_w), 1200 });
        draw_config_companion();
    end

    pop_theme();
end

return {
    reset_anchor = reset_anchor,
    reset_all_settings = reset_all_settings,
    draw_move_mode = draw_move_mode,
    draw_live_preview = draw_live_preview,
    add_test_events = add_test_events,
    draw_config = draw_config,
    draw_session_window = draw_session_window,
};
