require('common');
local imgui = require('imgui');
local core_mod = require('scl.core');
local events_mod = require('scl.events');
local render_mod = require('scl.render');
local theme_mod = require('scl.theme');
local uifont = require('scl.uifont');
local ui = require('scl.cfgui');
local history_mod = require('scl.history');
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
    -- 1.5.0: a lane whose text ends at the anchor (orientation 'left') puts
    -- its handle's right edge on the anchor, so the box sits where the text is.
    local right_edge = (not centered) and anchor.orientation == 'left';
    state.move_half_width = state.move_half_width or {};
    local half = centered and (state.move_half_width[key] or 130) or 0;
    if right_edge then half = (state.move_half_width[key] or 260); end

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
        elseif right_edge and x then
            local w = tonumber((imgui.GetWindowSize())) or 260;
            state.move_half_width[key] = w;
            x = x + w;
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

-- 1.5.1: the 'centered' layout in Move Mode: a small crosshair handle on
-- the center point (it never covers the lanes) and real sample text, drawn by
-- SCL's own renderer in your font and size, so you see exactly where each
-- lane's text goes.
local PREVIEW = {
    { 'outgoing', 'outgoing', '34', 'melee_damage', 'Diving Beetle' },
    { 'incoming', 'incoming', '-24', 'incoming_damage', 'Diving Beetle', true },
    { 'outgoing', 'ability', 'Savage Blade  1120', 'weapon_skills', 'Diving Beetle' },
    { 'incoming', 'miss', 'PARRY', 'defenses', 'Diving Beetle', true },
    { 'outgoing', 'critical', '88', 'criticals', 'Diving Beetle' },
    { 'incoming', 'heal', '+93 HP  <-  Pollen', 'healing_received' },
};
local function feed_preview()
    local now = os.clock();
    if (state.preview_next or 0) > now then return; end
    state.preview_next = now + 0.9;
    state.preview_step = ((state.preview_step or 0) % #PREVIEW) + 1;
    local p = PREVIEW[state.preview_step];
    local text = p[3];
    if p[5] then text = text .. (p[6] and source_suffix(p[5]) or target_suffix(p[5])); end
    add_event(p[1], p[2], text, p[4], { preview = true });
    -- A notification now and then.
    state.preview_note = (state.preview_note or 0) + 1;
    if state.preview_note % 4 == 1 then
        add_event('incoming', 'xp', 'Level 31', 'level_up', { preview = true });
    end
end

local function draw_center_layout()
    local L = settings.layout;
    local cx, cy = core_mod.layout_center();
    local size = 30;
    if not state.move_initialized.center then
        imgui.SetNextWindowPos({ cx - size / 2, cy - size / 2 });
        state.move_initialized.center = true;
    end
    imgui.SetNextWindowSize({ size, size });
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoSavedSettings or 0,
        ImGuiWindowFlags_NoBackground or 0);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    imgui.PushStyleVar(ImGuiStyleVar_WindowMinSize, { 8, 8 });
    local hovered = false;
    if imgui.Begin('##scl_center_handle', nil, flags) then
        local x, y = imgui.GetWindowPos();
        x, y = tonumber(x), tonumber(y);
        hovered = imgui.IsWindowHovered();
        if x then
            local ncx, ncy = x + size / 2, y + size / 2;
            if math.abs(ncx - cx) >= 1 or math.abs(ncy - cy) >= 1 then
                L.cx, L.cy = ncx, ncy;
                cx, cy = ncx, ncy;
                state.center_dirty = true;
            end
        end
    end
    imgui.End();
    imgui.PopStyleVar(3);
    if state.center_dirty and not imgui.IsMouseDown(0) then
        state.center_dirty = false;
        save_settings();
    end

    feed_preview();

    -- The crosshair and thin lane edges (the text itself is the real thing).
    local dl = imgui.GetForegroundDrawList and imgui.GetForegroundDrawList() or nil;
    if dl == nil then return; end
    local function col(c, a) return imgui.GetColorU32({ c[1], c[2], c[3], a }); end
    local W, IN, OUT = { 0.80, 0.86, 1.00 }, { 1.00, 0.36, 0.36 }, { 1.00, 0.88, 0.32 };
    local r = size / 2 - 2;
    dl:AddCircleFilled({ cx, cy }, r, col({ 0, 0, 0 }, hovered and 0.55 or 0.35), 24);
    dl:AddCircle({ cx, cy }, r, col(W, 0.95), 24, 2.0);
    dl:AddLine({ cx - r - 6, cy }, { cx + r + 6, cy }, col(W, 0.95), 1.5);
    dl:AddLine({ cx, cy - r - 6 }, { cx, cy + r + 6 }, col(W, 0.95), 1.5);
    local tip = hovered and 'Drag onto your character' or 'SCL center';
    local tw = tonumber((imgui.CalcTextSize(tip))) or 0;
    dl:AddText({ cx - tw / 2 + 1, cy + r + 9 }, col({ 0, 0, 0 }, 0.8), tip);
    dl:AddText({ cx - tw / 2, cy + r + 8 }, col(W, 0.95), tip);
    local inc = core_mod.lane_anchor('incoming');
    local out = core_mod.lane_anchor('outgoing');
    local note = core_mod.lane_anchor('notify');
    -- Lane edges up to the top of the band, the band's top, and the line the
    -- Notifications grow up from.
    local top = tonumber(inc.top_limit) or (inc.y - 260);
    dl:AddLine({ inc.x, inc.y + 18 }, { inc.x, top }, col(IN, 0.35), 1.0);
    dl:AddLine({ out.x, out.y + 18 }, { out.x, top }, col(OUT, 0.35), 1.0);
    dl:AddLine({ inc.x - 160, top }, { inc.x, top }, col(IN, 0.18), 1.0);
    dl:AddLine({ out.x, top }, { out.x + 160, top }, col(OUT, 0.18), 1.0);
    dl:AddLine({ note.x - 120, note.y + 20 }, { note.x + 120, note.y + 20 }, col(W, 0.35), 1.0);
end

local function draw_move_mode()
    if not state.move_mode or settings.locked == true then
        return;
    end

    -- 1.5.0: centered layout: one handle for everything.
    if settings.layout ~= nil and settings.layout.mode == 'centered' then
        draw_center_layout();
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

-- ============================================================================
-- 1.6.0: the settings pages, built on scl/cfgui.lua (the same settings kit as
-- MobHunt, WhatsMyDamage and IzClock). Name on the left, the control at a
-- fixed column; everything can be found with the search box.
-- ============================================================================

ui.theme = {
    text = theme_mod.UI_TEXT,
    muted = UI_MUTED,
    accent = UI_ACCENT,
    accent_text = UI_ACCENT_TEXT,
    control = theme_mod.UI_CONTROL,
    danger = UI_RED,
    section_header = function(title) section_header(title, UI_ACCENT_TEXT); end,
    help_marker = help_marker,
    tip = function(text_value)
        if imgui.IsItemHovered() then
            imgui.BeginTooltip();
            imgui.PushTextWrapPos(420);
            imgui.TextUnformatted(text_value);
            imgui.PopTextWrapPos();
            imgui.EndTooltip();
        end
    end,
    toggle_button = function(label, id, selected, size) return draw_toggle_button(label, id, selected, size); end,
    align_label = align_label,
};

local function searching() return ui.searching(); end
local function cfg_sc() return ui.scale or 1; end

-- A dropdown at the control column over a { {key, label}, ... } list.
local function cfg_combo(text, tbl, key, list, help_text, on_change)
    if not ui.want(text, help_text) then return false; end
    ui.label(text, help_text);
    imgui.PushItemWidth(ui.SLIDER_W * cfg_sc());
    local cur = tbl[key];
    local index, labels = 0, {};
    for i, item in ipairs(list) do
        labels[#labels + 1] = item.label;
        if item.key == cur then index = i - 1; end
    end
    local value = { index };
    local changed = false;
    if imgui.Combo('##cfgcombo_' .. tostring(tbl) .. tostring(key), value, table.concat(labels, '\0') .. '\0\0') then
        local chosen = list[(tonumber(value[1]) or 0) + 1];
        if chosen and chosen.key ~= cur then
            tbl[key] = chosen.key;
            if on_change then on_change(chosen.key); end
            save_settings();
            changed = true;
        end
    end
    imgui.PopItemWidth();
    if help_text then help_marker(help_text); end
    return changed;
end

-- One event row: show it (checkbox) and its color.
local function draw_event_option(label, key)
    if not ui.want(label, 'event color show') then return; end
    ensure_event_option(key);
    local opt = settings.event_options[key];
    local shown = { opt.show ~= false };
    if imgui.Checkbox(label .. '##show_' .. key, shown) then
        opt.show = shown[1];
        save_settings();
    end
    imgui.SameLine(ui.LABEL_W * cfg_sc() + 120 * cfg_sc());
    local c = { tonumber(opt.color[1]) or 1.0, tonumber(opt.color[2]) or 1.0, tonumber(opt.color[3]) or 1.0 };
    if imgui.ColorEdit3('##color_' .. key, c, ImGuiColorEditFlags_NoInputs) then
        opt.color[1] = c[1];
        opt.color[2] = c[2];
        opt.color[3] = c[3];
        opt.color[4] = 1.0;
        save_settings();
    end
    if imgui.IsItemHovered() then imgui.SetTooltip(label .. ' color'); end
end

local ORIENTATIONS = {
    { key = 'left', label = 'Left', tip = 'The text extends left from the anchor.' },
    { key = 'right', label = 'Right', tip = 'The text extends right from the anchor.' },
};
local GROWTHS = {
    { key = 'up', label = 'Up' },
    { key = 'down', label = 'Down' },
};
local MOTIONS = {
    { key = 'scroll', label = 'Scroll', tip = 'Straight up (or down).' },
    { key = 'arc', label = 'Arc', tip = 'Curves sideways as it rises.' },
    { key = 'fade', label = 'Fade In', tip = 'Appears in place and drifts.' },
};

local function draw_lane_layout(key, name)
    local lane = settings[key];
    if lane.orientation == nil then lane.orientation = 'right'; end
    if lane.growth == nil then lane.growth = 'up'; end
    ui.choice('Text direction##' .. key, lane, 'orientation', ORIENTATIONS, 'Left = text extends left from the anchor; Right = extends right.');
    ui.choice('Growth##' .. key, lane, 'growth', GROWTHS, 'Which way new lines push the old ones.');
    if ui.want('Position##' .. key, name .. ' lane position x y') then
        ui.label('Position##' .. key);
        if settings.locked == true then
            imgui.TextColored(UI_MUTED, ('Locked at %.0f, %.0f'):fmt(tonumber(lane.x) or 0, tonumber(lane.y) or 0));
        else
            imgui.PushItemWidth(105 * cfg_sc());
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
    if ui.button('Reset ' .. name .. ' position', 'scl_reset_' .. key, 'Moves the ' .. name .. ' lane back to where it started.') then
        reset_anchor(key);
    end
end

-- GENERAL ---------------------------------------------------------------------

local function draw_general_config_tab()
    ui.section('DISPLAY');
    ui.slider_f('Display time', settings, 'duration', 0.5, 12.0, '%.1f sec', 'How long each line stays on screen.');
    ui.slider_f('Scroll speed', settings, 'scroll_speed', 0.0, 300.0, '%.0f px/s', 'How fast the lines move.');
    ui.slider_f('Global font size', settings, 'font_scale', 0.75, 3.00, '%.2fx', 'The size of all floating combat text (Text > Font Style has the size of each kind).');
    ui.slider_i('Most lines on screen', settings, 'max_visible_events', 4, 30, '%d', 'Caps active scrolling rows to keep heavy combat readable and predictable.');

    ui.section('CONTENT');
    ui.check('Event symbols / prefixes', settings, 'show_symbols', 'Symbols like * for criticals and [MB] for magic bursts.');
    ui.check('Show outgoing target names', settings, 'show_target_names', 'When off, outgoing damage / spells omit the "-> Target" part.', { default_on = true });
    ui.check('Show incoming source names', settings, 'show_source_names', 'When off, incoming damage / effects omit the "<- Source" part.', { default_on = true });
    ui.check('Show 0 damage / no-damage results', settings, 'show_zero_damage', 'Shows numeric zero-damage results. Full resists can still appear as [RESIST].');
    ui.check('Show misses', settings, 'show_misses', nil, { default_on = true });
    ui.check('Combine rapid repeated hits', settings, 'combine_repeated_hits', 'Merges rapid melee / ranged hits from the same source / target into "total (N hits)".', { default_on = true });

    ui.section('POSITIONING');
    ui.check('Lock positions', settings, 'locked', 'Unlocked positions show the handles: one center handle (Centered layout), or a box per lane (Free layout). /scl unlock and /scl lock do the same.', {
        on_change = function(v)
            if v then
                state.move_mode = false;
            else
                state.move_mode = true;
                state.move_initialized.incoming = false;
                state.move_initialized.outgoing = false;
            end
        end,
    });
    local L = settings.layout;
    if L ~= nil then
        ui.choice('Layout', L, 'mode', {
            { key = 'centered', label = 'Centered on one point', tip = 'Drag one handle onto your character; Incoming goes on its left, Outgoing on its right, Notifications above, evenly.' },
            { key = 'free', label = 'Free (each lane)', tip = 'Drag each lane on its own.' },
        }, 'Centered: one handle for everything. Free: each lane has its own handle.', {
            on_change = function(mode)
                if mode == 'centered' then
                    state.move_initialized.center = false;
                else
                    state.move_initialized.incoming = false;
                    state.move_initialized.outgoing = false;
                    state.move_initialized.notification = false;
                end
            end,
        });
        if L.mode == 'centered' or searching() then
            ui.sub(function()
                ui.slider_i('Side gap', L, 'gap', 0, 400, '%d px', 'How far Incoming (left) and Outgoing (right) start from the center.');
                ui.slider_i('Side lanes start', L, 'down', -300, 400, '%d px', 'The bottom of the side lanes, below (+) or above (-) the center. A lane set to grow Up scrolls up from here; a lane set to grow Down starts at the top of the band and scrolls down to here (Incoming / Outgoing pages > Growth).');
                ui.slider_i('Side lane height', L, 'height', 60, 900, '%d px', 'How far Incoming / Outgoing scroll up before fading out. Notifications sit above this.');
                ui.slider_i('Notifications gap', L, 'note_gap', 0, 300, '%d px', 'Space between the top of the side lanes and the Notifications (they grow upward from there).');
                if ui.button('Center on the screen', 'scl_lay_reset', 'Puts the center handle back in the middle of the screen. Unlock positions to drag it.') then
                    L.cx, L.cy = -1, -1;
                    state.move_initialized.center = false;
                    save_settings();
                end
            end);
        end
    end
end

-- TEXT ------------------------------------------------------------------------

local NOTIFY = {
    { 'Level up', 'level_up' }, { 'Skillchains', 'skillchains' }, { 'Magic bursts', 'magic_bursts' },
    { 'Zone change', 'zone_change' }, { 'Buff wearing off', 'wear_warning' },
    { 'Big hits (copy of large outgoing damage)', 'big_hits' }, { 'Low HP warning', 'low_hp' },
    { 'Buff wore off (Protect, Haste, ...)', 'status_removed' }, { 'Food running out (20s, then every 5s)', 'food_warning' },
};

local function draw_display_config_tab()
    ui.section('MOTION');
    for _, lane in ipairs({ { 'outgoing', 'Outgoing' }, { 'incoming', 'Incoming' } }) do
        local t = settings[lane[1]];
        if t.motion == nil then t.motion = 'scroll'; end
        ui.choice(lane[2] .. ' motion', t, 'motion', MOTIONS, 'Scroll = straight. Arc = curves sideways as it rises. Fade In = appears in place and drifts.');
    end

    ui.section('EFFECTS');
    ui.check('Critical pop', settings, 'crit_pop', 'Criticals briefly grow, then settle. Performance renderer only; Custom Font keeps a fixed size.');
    ui.check('Element colors', settings, 'element_colors', 'Spells and additional effects use their element color (Fire, Ice, Wind, Earth, Thunder, Water, Light, Dark) instead of the category color.');
    ui.check('Combine AoE hits', settings, 'combine_aoe', 'One line for a spell / weapon skill / ability that hits several targets, e.g. "Firaga III  1840 (4 targets)".');

    ui.section('NOTIFICATIONS (CENTER LANE)');
    ui.info('Checked events move to the center lane instead of scrolling.');
    for _, n in ipairs(NOTIFY) do
        ui.check(n[1] .. '##notify_' .. n[2], settings.notify, n[2]);
    end
    ui.slider_i('Big hit threshold', settings, 'big_hit_threshold', 50, 5000, '%d', 'Outgoing damage at or above this is also shown in Notifications (when Big hits is on).');
    ui.slider_f('Notification size', settings, 'notify_scale', 0.80, 2.50, '%.2fx', 'The size of the center lane\'s text.');
    if ui.button('Reset Notification position', 'scl_reset_notification', 'Moves the center lane back to where it started. /scl unlock shows its handle.') then
        reset_anchor('notification');
    end
end

local RENDERERS = {
    { key = 'performance', label = 'Performance', tip = 'Recommended: smooth ImGui renderer. Every effect is supported.' },
    { key = 'custom', label = 'Custom Font', tip = 'Windows fonts via FontManager. Each style is built once and reused (no hitching).' },
};

local function draw_font_style_config_tab()
    local custom = (settings.renderer_mode or 'performance') == 'custom';
    ui.section('FONT STYLE');
    if settings.renderer_mode == nil then settings.renderer_mode = 'performance'; end
    ui.choice('Renderer', settings, 'renderer_mode', RENDERERS, 'Performance draws with ImGui (every effect works). Custom Font uses Windows fonts through FontManager.', {
        on_change = function(mode)
            if mode == 'custom' then rebuild_font_pool(); else hide_unused_fonts(1); end
        end,
    });
    custom = (settings.renderer_mode or 'performance') == 'custom';

    if ui.want('Font family', 'custom font family windows') then
        ui.label('Font family', 'Custom Font renderer only.');
        imgui.PushItemWidth(ui.SLIDER_W * cfg_sc());
        local family = tostring(settings.font_family or 'Consolas');
        local family_index = 0;
        for i, name in ipairs(FONT_FAMILIES) do
            if name == family then family_index = i - 1; end
        end
        local family_value = { family_index };
        if imgui.Combo('##scl_font_family', family_value, table.concat(FONT_FAMILIES, '\0') .. '\0\0') then
            local chosen = FONT_FAMILIES[(tonumber(family_value[1]) or 0) + 1];
            if chosen and chosen ~= family then set_font_family(chosen); end
        end
        imgui.PopItemWidth();
        imgui.SameLine();
        if imgui.SmallButton('<##font_family_prev') then cycle_font_family(-1); end
        imgui.SameLine();
        if imgui.SmallButton('>##font_family_next') then cycle_font_family(1); end
        if not custom then
            imgui.SameLine();
            imgui.TextColored(UI_MUTED, '(Custom Font only)');
        end
    end
    ui.check('Bold', settings, 'font_bold', nil, { on_change = function() if custom then rebuild_font_pool(); end end });
    ui.check('Italic', settings, 'font_italic', 'Custom Font only.', { on_change = function() if custom then rebuild_font_pool(); end end });
    ui.check('ALL CAPS', settings, 'all_caps');
    if settings.text_opacity == nil then settings.text_opacity = 1.0; end
    ui.slider_f('Text opacity', settings, 'text_opacity', 10, 100, '%.0f%%', 'How see-through the floating text is.', { mul = 100 });

    ui.section('TEXT EFFECT');
    if settings.text_effect == nil then settings.text_effect = current_effect(); end
    cfg_combo('Effect', settings, 'text_effect', TEXT_EFFECTS, 'An outline or shadow keeps the text readable over bright ground.', function(chosen)
        settings.font_outline = effect_has_outline(chosen);
        if custom then rebuild_font_pool(); end
    end);
    local effect = current_effect();
    if custom and effect == 'glow' then ui.info('Glow is Performance-only; Custom Font shows plain text.'); end
    if (effect ~= 'none' and effect ~= 'glow') or searching() then
        if settings.effect_color == nil then settings.effect_color = 'black'; end
        cfg_combo('Effect color', settings, 'effect_color', EFFECT_COLORS, 'The color of the outline / shadow.');
    end
    if effect ~= 'none' or searching() then
        if settings.effect_opacity == nil then settings.effect_opacity = 0.85; end
        ui.slider_f('Effect strength', settings, 'effect_opacity', 10, 100, '%.0f%%', nil, { mul = 100 });
    end
    if effect_has_shadow(effect) or searching() then
        if settings.shadow_offset == nil then settings.shadow_offset = 2; end
        ui.slider_i('Shadow distance', settings, 'shadow_offset', 1, 6, '%d px', custom and 'Custom Font shadow uses a second font copy behind the text.' or nil);
    end

    ui.section('BACKING PLATE');
    if settings.text_plate == nil then settings.text_plate = 'off'; end
    cfg_combo('Plate', settings, 'text_plate', TEXT_PLATES, custom and 'The backing plate is drawn by the Performance renderer only.' or 'A soft box behind each line; helps on bright ground / snow.');
    if tostring(settings.text_plate or 'off') ~= 'off' or searching() then
        ui.sub(function()
            if settings.plate_opacity == nil then settings.plate_opacity = 0.45; end
            if settings.plate_rounding == nil then settings.plate_rounding = 4.0; end
            ui.slider_f('Plate opacity', settings, 'plate_opacity', 5, 100, '%.0f%%', nil, { mul = 100 });
            ui.slider_f('Plate rounding', settings, 'plate_rounding', 0.0, 12.0, '%.0f px');
        end);
    end

    ui.section('SIZES');
    ui.slider_f('Normal damage', settings, 'melee_scale', 0.60, 2.00, '%.2fx', 'Criticals use this size too; the * prefix and the Critical color identify them.');
    ui.slider_f('Abilities / WS', settings, 'ability_scale', 0.60, 2.00, '%.2fx');
    ui.slider_f('Healing', settings, 'heal_scale', 0.60, 2.00, '%.2fx');
    ui.slider_f('Rewards', settings, 'reward_scale', 0.60, 2.00, '%.2fx');
end

local function draw_outgoing_config_tab()
    ui.section('OUTGOING EVENTS');
    draw_event_option('Melee damage', 'melee_damage');
    draw_event_option('Ranged damage', 'ranged_damage');
    draw_event_option('Criticals', 'criticals');
    draw_event_option('Weapon skills', 'weapon_skills');
    draw_event_option('Spells', 'spells');
    draw_event_option('Magic bursts', 'magic_bursts');
    draw_event_option('Skillchains', 'skillchains');
    draw_event_option('Abilities', 'outgoing_abilities');
    draw_event_option('Pet damage', 'pet_damage');
    draw_event_option('Additional effects', 'additional_effects');
    draw_event_option('Counters / retaliation', 'counters');
    draw_event_option('Buffs', 'buffs');

    ui.section('OUTGOING LANE');
    draw_lane_layout('outgoing', 'Outgoing');
end

local function draw_incoming_config_tab()
    ui.section('INCOMING EVENTS');
    draw_event_option('Incoming damage', 'incoming_damage');
    draw_event_option('Incoming abilities', 'incoming_abilities');
    draw_event_option('Defenses (Evade / Parry / Block / Shadows)', 'defenses');
    draw_event_option('Positive status', 'status_positive');
    draw_event_option('Negative status', 'status_negative');
    draw_event_option('Buff wore off', 'status_removed');
    draw_event_option('Healing received', 'healing_received');
    draw_event_option('MP recovery', 'mp_recovery');
    draw_event_option('Resting (/heal) ticks', 'resting');
    draw_event_option('Regen ticks', 'regen_ticks');
    draw_event_option('Refresh ticks', 'refresh_ticks');
    draw_event_option('Drain / Aspir', 'drain_aspir');
    draw_event_option('KO / defeat', 'ko');
    draw_event_option('Low HP warning', 'low_hp');
    ui.sub(function()
        ui.slider_i('Low HP warning at', settings, 'low_hp_percent', 5, 75, '%d%%', 'The Low HP warning shows when your HP drops below this.');
    end);

    ui.section('INCOMING LANE');
    draw_lane_layout('incoming', 'Incoming');

    ui.section('REWARDS');
    draw_event_option('EXP / LP / CP / JP', 'exp');
    draw_event_option('Gil', 'gil');
    draw_event_option('Level up', 'level_up');
    draw_event_option('Skill ups', 'skill_ups');
    draw_event_option('Item drops (found in treasure pool)', 'item_drops');
    draw_event_option('Items obtained (received)', 'item_obtained');
    draw_event_option('Zone change (=== Area ===)', 'zone_change');
    draw_event_option('Buff wearing off warning', 'wear_warning');
    draw_event_option('Food running out (20s, then every 5s)', 'food_warning');
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
        uifont.push(font_scale);

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

        uifont.pop();

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

    local sl = settings.look and settings.look.session or {};
    push_theme(sl.own_alpha and (tonumber(sl.alpha) or 0.97) or nil);

    if imgui.Begin('SCL Session##scl_session', state.session_open, ImGuiWindowFlags_NoNav) then
        capture_current_window_geometry('session');

        -- Text size for the window contents (title bar keeps its size).
        local font_scale = clamp(tonumber(settings.session_font_scale) or 1.0, 0.75, 2.50);
        uifont.push(font_scale);

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

        uifont.pop();

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

-- WINDOWS ---------------------------------------------------------------------

-- Own opacity for one window (look = { own_alpha, alpha }).
local function own_opacity(look, key_on, key_alpha, what)
    ui.check('Own opacity##' .. what, look, key_on, 'Off: the ' .. what .. ' uses the background opacity from Look > Theme & colors. On: set it here.');
    if look[key_on] or searching() then
        ui.sub(function()
            ui.slider_f('Opacity##' .. what, look, key_alpha, 10, 100, '%.0f%%', 'How see-through the background of the ' .. what .. ' is. Text stays solid.', { mul = 100 });
        end);
    end
end

-- 1.4.0: History page.
local function draw_history_config_tab()
    local H = settings.history;
    ui.section('WINDOW');
    if ui.want('History window', 'open close /scl history') then
        ui.label('History window', 'Same as /scl history.');
        if draw_toggle_button(history_mod.open[1] and 'Open - click to close' or 'Closed - click to open', 'scl_hist_open', history_mod.open[1] == true) then history_mod.toggle(); end
    end
    ui.check('Keep a history', H, 'enabled', 'Each side (Notifications, Incoming, Outgoing) keeps its last events for the History window.', { default_on = true });
    ui.check('Show the time of each line', H, 'show_time', nil, { default_on = true });
    ui.check('Newest at the top', H, 'newest_first', nil, { default_on = true });
    ui.slider_i('Events per side', H, 'size', 10, 200, '%d', 'How many lines each side keeps.');
    ui.slider_f('Top part height', H, 'notify_height', 10, 60, '%.0f%%', 'How much of the window the Notifications part (top) takes. Incoming is on the left, Outgoing on the right, like the floating text.', { mul = 100 });

    ui.section('LOOK');
    -- Size: presets plus the old - / + steps (5%); the History lines only
    -- (the title bar keeps its size).
    if ui.scale_presets('Size', H, 'font_scale', 'Size of the lines in the History window (on top of Fonts & Tooltips > Text size).') then
        history_mod.size_dirty = nil;
    end
    if ui.want('Size (fine)', 'history text size steps') then
        ui.label('Size (fine)', 'Hold - or + to keep going.');
        state.hist_hold = state.hist_hold or {};
        local function step(label, id, dir)
            imgui.Button(label .. '##' .. id, { 26 * cfg_sc(), 0 });
            if imgui.IsItemActive() then
                local t = os.clock();
                local st = state.hist_hold[id];
                if st == nil then
                    state.hist_hold[id] = { start = t, last = t };
                    return dir;
                end
                if t - st.start > 0.40 and t - st.last > 0.08 then st.last = t; return dir; end
            else
                state.hist_hold[id] = nil;
            end
            return 0;
        end
        local pct = math.floor(clamp(tonumber(H.font_scale) or 1.0, 0.60, 2.50) * 100 + 0.5);
        local d = step('-', 'scl_hist_fsm', -5);
        imgui.SameLine(0, 4);
        imgui.AlignTextToFramePadding();
        imgui.Text(('%d%%'):fmt(pct));
        imgui.SameLine(0, 4);
        d = d + step('+', 'scl_hist_fsp', 5);
        if d ~= 0 then
            H.font_scale = clamp((pct + d) / 100, 0.60, 2.50);
            history_mod.size_dirty = os.clock();
        end
        if history_mod.size_dirty ~= nil and state.hist_hold.scl_hist_fsm == nil and state.hist_hold.scl_hist_fsp == nil then
            history_mod.size_dirty = nil;
            save_settings();
        end
    end
    own_opacity(H, 'own_alpha', 'opacity', 'History window');
end

local ITEMS_SIDES = {
    { key = 'right', label = 'Right' },
    { key = 'left', label = 'Left' },
    { key = 'below', label = 'Below' },
    { key = 'inside', label = 'Inside', tip = 'In the Session window itself (the old list).' },
};

local function draw_session_config_tab()
    ui.section('WINDOW');
    if ui.want('Session window', 'open close /scl session') then
        ui.label('Session window', 'Same as /scl session: your EXP, gil, kills and items this session.');
        if draw_toggle_button(state.session_open[1] and 'Open - click to close' or 'Closed - click to open', 'scl_sess_open', state.session_open[1] == true) then
            state.session_open[1] = not state.session_open[1];
            state.session_geometry_initialized = false;
        end
    end
    if settings.session_items_side == nil then settings.session_items_side = 'right'; end
    ui.choice('Items panel', settings, 'session_items_side', ITEMS_SIDES, 'Where the Items Obtained list sits: a panel attached to the Session window, or inside it.');

    ui.section('LOOK');
    ui.scale_presets('Size', settings, 'session_font_scale', 'Text size of the Session window (the title bar keeps its size). Also on the window itself.');
    ui.slider_f('Size (fine)##session', settings, 'session_font_scale', 0.75, 2.50, '%.2fx', 'The same setting as Size, in small steps.');
    own_opacity(settings.look.session, 'own_alpha', 'alpha', 'Session window');
end

local function draw_settings_window_tab()
    ui.section('SETTINGS WINDOW');
    ui.scale_presets('Settings size', settings, 'config_scale', 'Text and spacing of this window and the Preview & Tools window.');
    ui.slider_f('Opacity##config', settings.look.config, 'alpha', 10, 100, '%.0f%%', 'How see-through this settings window is. It has its own opacity, separate from the other windows.', { mul = 100 });
    if ui.button('Reset size and position', 'scl_cfg_reset', 'Puts this window and the Preview & Tools window back in their starting place and size.') then
        for k, v in pairs(defaults.config_window) do settings.config_window[k] = v; end
        for k, v in pairs(defaults.config_tools_window) do settings.config_tools_window[k] = v; end
        state.config_geometry.main_initialized = false;
        state.config_geometry.tools_initialized = false;
        save_settings();
    end

    ui.section('PREVIEW & TOOLS WINDOW');
    ui.info('Opens next to this window: a live preview of the floating text, test events and resets.');
    own_opacity(settings.look.tools, 'own_alpha', 'alpha', 'Preview & Tools window');
end

-- LOOK ------------------------------------------------------------------------

local function theme_buttons()
    if not ui.want('Theme', 'Colors of SCL\'s windows. Forest Rust Bone Copper Gold Garnet Fuchsia Silver Amethyst Emerald Midnight') then return; end
    ui.label('Theme', 'Colors of SCL\'s windows: accents, tabs, borders and title bars.');
    local s = cfg_sc();
    local col_x = ui.LABEL_W * s;
    local avail = imgui.GetContentRegionAvail();
    if type(avail) == 'table' then avail = avail.x or avail[1]; end
    local right = col_x + (tonumber(avail) or 500);
    local chip = 9 * s;
    local current = tostring(settings.ui_theme or 'garnet'):lower();
    for i, key in ipairs(UI_THEME_ORDER) do
        local th = UI_THEMES[key];
        local text = '      ' .. th.label;
        local bw = (tonumber((imgui.CalcTextSize(text))) or 60) + 16 * s;
        if i > 1 then
            imgui.SameLine(0, 4);
            if imgui.GetCursorPosX() + bw > right then
                imgui.NewLine();
                imgui.SetCursorPosX(col_x);
            end
        end
        if draw_toggle_button(text, 'scl_theme_' .. key, key == current) then
            settings.ui_theme = key;
            save_settings();
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

local function draw_theme_config_tab()
    ui.section('THEME');
    theme_buttons();
    ui.section('BACKGROUND');
    local B = settings.ui_bg;
    ui.check("Use the theme's background", B, 'use_theme', 'Each theme has its own dark background (Midnight is deep navy). Off: pick your own color below.', { default_on = true });
    if B.use_theme == false or searching() then
        ui.sub(function() ui.color('Background color', B.color, 'The background of SCL\'s windows.', false); end);
    end
    ui.slider_f('Opacity', B, 'alpha', 10, 100, '%.0f%%', 'How see-through the Session, Preview & Tools and move-handle windows are (unless one has its own opacity on its page).', { mul = 100 });
    ui.info('The floating combat text is not a window: its look is on the Text pages.');
end

-- 1.4.0: the font of SCL's windows. The floating text keeps Font Style.
local function draw_uifont_config_tab()
    uifont.settings_page(settings.ui_font, {
        header = function(t) ui.section(t); end,
        label = function(text_value, help_text) ui.label(text_value, help_text); end,
        dirty = function() save_settings(); end,
        want = function(text_value, help_text) return ui.want(text_value, help_text); end,
        ctrl_w = ui.SLIDER_W * cfg_sc(),
        accent = UI_ACCENT_TEXT,
        muted = UI_MUTED,
    });
    ui.info('For the Settings, Preview & Tools, Session and History windows. The floating combat text uses Text > Font Style.');
end

-- HELP ------------------------------------------------------------------------

local CMDS = {
    { '/scl', 'show / hide the combat text' },
    { '/scl config', 'this window' },
    { '/scl unlock', 'show the handles to move the lanes' },
    { '/scl lock', 'save and lock the positions' },
    { '/scl test', 'show sample events' },
    { '/scl clear', 'clear the text on screen' },
    { '/scl pause', 'pause / resume' },
    { '/scl history', 'the History window' },
    { '/scl session', 'the Session window' },
    { '/scl debug', 'log unmapped messages to a file' },
    { '/scl help', 'list the commands in chat' },
};

local function draw_commands_config_tab()
    ui.section('COMMANDS');
    for _, c in ipairs(CMDS) do
        if ui.want(c[1], c[2]) then
            imgui.TextColored(UI_ACCENT_TEXT, c[1]);
            imgui.SameLine(ui.LABEL_W * cfg_sc());
            imgui.TextColored(UI_MUTED, c[2]);
        end
    end
    ui.section('ABOUT');
    ui.value('Version', tostring(addon.version));
    ui.info('ScrollingCombatLog by Izumi. Written for HorizonXI. Self-only: completed actions, incoming effects and your own rewards; nothing is shown when an enemy starts an action.');
end

local CONFIG_GROUPS = {
    { label = 'GENERAL', pages = {
        { key = 'general', label = 'General', desc = 'How long the text stays, what it includes, and where the lanes sit.', draw = draw_general_config_tab },
    } },
    { label = 'TEXT', pages = {
        { key = 'display', label = 'Display', desc = 'How the text moves, the extra effects, and which events go to the center (Notifications) lane.', draw = draw_display_config_tab },
        { key = 'font', label = 'Font Style', desc = 'The look of the floating combat text: renderer, font, effect, backing plate and sizes.', draw = draw_font_style_config_tab },
        { key = 'outgoing', label = 'Outgoing', desc = 'What you do: which events show, their colors, and the Outgoing lane.', draw = draw_outgoing_config_tab },
        { key = 'incoming', label = 'Incoming', desc = 'What happens to you and your rewards: which events show, their colors, and the Incoming lane.', draw = draw_incoming_config_tab },
    } },
    { label = 'WINDOWS', pages = {
        { key = 'history', label = 'History', desc = 'The window with the last events of each side.', draw = draw_history_config_tab },
        { key = 'session', label = 'Session', desc = 'The window with your EXP, gil, kills and items this session.', draw = draw_session_config_tab },
        { key = 'settings', label = 'Settings window', desc = 'This window and the Preview & Tools window next to it.', draw = draw_settings_window_tab },
    } },
    { label = 'LOOK', pages = {
        { key = 'theme', label = 'Theme & colors', desc = 'The theme and the background of SCL\'s windows.', draw = draw_theme_config_tab },
        { key = 'uifont', label = 'Fonts & Tooltips', desc = 'The font of SCL\'s windows (not the floating text), and how tooltips look.', draw = draw_uifont_config_tab },
    } },
    { label = 'HELP', pages = {
        { key = 'commands', label = 'Commands', desc = 'Type these in chat.', draw = draw_commands_config_tab },
    } },
};

local CONFIG_CTX = {
    id = 'scl',
    title = 'SCL',
    groups = CONFIG_GROUPS,
    page = function() return settings.config_page or 'general'; end,
    set_page = function(key) settings.config_page = key; save_settings(); end,
    dirty = function() save_settings(); end,
    themes = {
        order = UI_THEME_ORDER,
        list = UI_THEMES,
        current = function() return tostring(settings.ui_theme or 'garnet'):lower(); end,
        set = function(key) settings.ui_theme = key; save_settings(); end,
    },
    status = function()
        if settings.paused == true then return 'Paused (/scl pause)', UI_GOLD; end
        if settings.enabled == false then return 'Hidden (/scl to show)', UI_GOLD; end
        return nil;
    end,
};

local function draw_config()
    if not state.config_open[1] then
        hide_preview_fonts();
        state.config_geometry.main_initialized = false;
        state.config_geometry.tools_initialized = false;
        state.config_geometry.last_main = nil;
        state.config_geometry.last_tools = nil;
        return;
    end

    local k = clamp(tonumber(settings.config_scale) or 1.0, 0.85, 2.0);
    ui.scale = k;
    push_theme(tonumber(settings.look.config.alpha) or 0.97);

    if not state.config_geometry.main_initialized then
        imgui.SetNextWindowPos({
            tonumber(settings.config_window.x) or defaults.config_window.x,
            tonumber(settings.config_window.y) or defaults.config_window.y
        });
        imgui.SetNextWindowSize({
            math.max(820, tonumber(settings.config_window.w) or defaults.config_window.w),
            tonumber(settings.config_window.h) or defaults.config_window.h
        });
        state.config_geometry.main_initialized = true;
    end

    imgui.SetNextWindowSizeConstraints({ 700 * k, 460 * k }, { 4000, 4000 });

    uifont.push(k);
    if imgui.Begin('SCL Settings##scl_config', state.config_open, bit.bor(ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoCollapse or 0)) then
        capture_current_window_geometry('main');
        local ok, err = pcall(ui.body, CONFIG_CTX);
        if not ok then imgui.TextColored(UI_RED, tostring(err)); end
    end
    imgui.End();
    uifont.pop();
    pop_theme();

    if state.config_open[1] then
        -- Grow the Tools window so the live preview always fits.
        local needed_w = math.floor((tonumber(state.preview_needed_w) or 0) + 48);
        local min_w = math.max(380, math.min(needed_w, 1600));
        imgui.SetNextWindowSizeConstraints({ min_w, 520 }, { math.max(800, min_w), 1200 });
        local tl = settings.look.tools;
        push_theme(tl.own_alpha and (tonumber(tl.alpha) or 0.97) or nil);
        draw_config_companion();
        pop_theme();
    end
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
