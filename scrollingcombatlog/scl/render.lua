require('common');
local imgui = require('imgui');
local fonts = require('fonts');
local core_mod = require('scl.core');
local events_mod = require('scl.events');
local MAX_EVENTS = core_mod.MAX_EVENTS;
local clamp = core_mod.clamp;
local save_settings = core_mod.save_settings;
local settings = core_mod.settings;
local state = core_mod.state;
local event_color = events_mod.event_color;
local event_scale = events_mod.event_scale;
local rendered_event_text = events_mod.rendered_event_text;
local rgba_to_argb = events_mod.rgba_to_argb;

local rebuild_font_pool;

-- Windows fonts that ship with Windows 10 / 11. A family that is missing on
-- a PC simply falls back to the system default inside FontManager.
local FONT_FAMILIES = T{
    'Consolas',
    'Lucida Console',
    'Courier New',
    'Segoe UI',
    'Segoe UI Semibold',
    'Segoe UI Black',
    'Arial',
    'Arial Black',
    'Bahnschrift',
    'Calibri',
    'Candara',
    'Corbel',
    'Franklin Gothic Medium',
    'Tahoma',
    'Trebuchet MS',
    'Verdana',
    'Impact',
    'Cambria',
    'Constantia',
    'Georgia',
    'Palatino Linotype',
    'Times New Roman',
};

local function set_font_family(family)
    settings.font_family = tostring(family or 'Consolas');
    save_settings();
    rebuild_font_pool();
end

local function cycle_font_family(direction)
    local current = tostring(settings.font_family or 'Consolas');
    local index = 1;

    for i, family in ipairs(FONT_FAMILIES) do
        if family == current then
            index = i;
            break;
        end
    end

    index = index + direction;
    if index < 1 then index = #FONT_FAMILIES; end
    if index > #FONT_FAMILIES then index = 1; end

    set_font_family(FONT_FAMILIES[index]);
end

-- ============================================================================
-- Text effects (shared by both renderers and the Live Preview)
-- ============================================================================
--
-- text_effect: 'none' | 'outline' | 'thick' | 'shadow' | 'soft_shadow' |
--              'outline_shadow' | 'glow'
-- effect_color: 'black' | 'charcoal' | 'tinted' | 'white'
--
-- Performance renderer: every effect is just a few extra AddText calls on
-- the background draw list (no textures, no font objects), so it costs
-- next to nothing even with a full screen of text.

local TEXT_EFFECTS = {
    { key = 'none',           label = 'None' },
    { key = 'outline',        label = 'Outline' },
    { key = 'thick',          label = 'Thick Outline' },
    { key = 'shadow',         label = 'Drop Shadow' },
    { key = 'soft_shadow',    label = 'Soft Shadow' },
    { key = 'outline_shadow', label = 'Outline + Shadow' },
    { key = 'glow',           label = 'Glow' },
};

local EFFECT_COLORS = {
    { key = 'black',    label = 'Black' },
    { key = 'charcoal', label = 'Charcoal' },
    { key = 'tinted',   label = 'Tinted (darker text color)' },
    { key = 'white',    label = 'White' },
};

local TEXT_PLATES = {
    { key = 'off',    label = 'Off' },
    { key = 'subtle', label = 'Subtle' },
    { key = 'dark',   label = 'Dark' },
    { key = 'tinted', label = 'Tinted' },
};

local function current_effect()
    local e = tostring(settings.text_effect or 'none');
    for _, item in ipairs(TEXT_EFFECTS) do
        if item.key == e then return e; end
    end
    return 'none';
end

local function effect_has_outline(e)
    return e == 'outline' or e == 'thick' or e == 'outline_shadow';
end

local function effect_has_shadow(e)
    return e == 'shadow' or e == 'soft_shadow' or e == 'outline_shadow';
end

-- RGB of the outline / shadow for a given text color.
local function effect_rgb(color)
    local mode = tostring(settings.effect_color or 'black');
    if mode == 'charcoal' then return 0.16, 0.16, 0.18; end
    if mode == 'white' then return 1.0, 1.0, 1.0; end
    if mode == 'tinted' then
        return (tonumber(color[1]) or 1) * 0.28, (tonumber(color[2]) or 1) * 0.28, (tonumber(color[3]) or 1) * 0.28;
    end
    return 0.0, 0.0, 0.0;
end

local function display_case(text)
    if settings.all_caps == true then
        return tostring(text):upper();
    end
    return text;
end

local OUTLINE_4 = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } };
local OUTLINE_8 = {
    { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 },
    { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 },
};
local OUTLINE_THICK = {
    { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 },
    { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 },
    { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 },
    { -2, -1 }, { 2, -1 }, { -2, 1 }, { 2, 1 },
    { -1, -2 }, { 1, -2 }, { -1, 2 }, { 1, 2 },
};
local GLOW_RING = {
    { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 },
    { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 },
};

local fx_pos = { 0, 0 };
local fx_min = { 0, 0 };
local fx_max = { 0, 0 };

-- Draws text with the selected plate / effect / faux bold onto a draw list.
-- color: { r, g, b, a }. alpha_mul: fade multiplier. width: measured text
-- width (only needed for the backing plate; pass nil to skip the plate).
local function draw_fx_text(draw_list, font, font_size, x, y, color, alpha_mul, text, width)
    if not draw_list then return; end

    local text_alpha = (tonumber(color[4]) or 1.0) * (alpha_mul or 1.0)
        * clamp(tonumber(settings.text_opacity) or 1.0, 0.1, 1.0);
    if text_alpha <= 0.003 then return; end

    -- Backing plate.
    local plate = tostring(settings.text_plate or 'off');
    if plate ~= 'off' and width ~= nil and width > 0 then
        local strength = clamp(tonumber(settings.plate_opacity) or 0.45, 0.05, 1.0);
        local pr, pg, pb = 0.0, 0.0, 0.0;
        local pa = strength * 0.55;
        if plate == 'dark' then
            pa = strength;
        elseif plate == 'tinted' then
            pr = (tonumber(color[1]) or 1) * 0.22;
            pg = (tonumber(color[2]) or 1) * 0.22;
            pb = (tonumber(color[3]) or 1) * 0.22;
            pa = strength * 0.85;
        end
        local pad_x = math.max(3, font_size * 0.28);
        local pad_y = math.max(1, font_size * 0.08);
        fx_min[1] = x - pad_x; fx_min[2] = y - pad_y;
        fx_max[1] = x + width + pad_x; fx_max[2] = y + font_size + pad_y;
        draw_list:AddRectFilled(fx_min, fx_max, imgui.GetColorU32({ pr, pg, pb, pa * (alpha_mul or 1.0) }),
            clamp(tonumber(settings.plate_rounding) or 4.0, 0.0, 12.0));
    end

    local e = current_effect();
    local er, eg, eb = effect_rgb(color);
    local effect_alpha = text_alpha * clamp(tonumber(settings.effect_opacity) or 0.85, 0.1, 1.0);

    -- Shadow (drawn first, under everything).
    if effect_has_shadow(e) then
        local off = clamp(tonumber(settings.shadow_offset) or 2, 1, 6);
        if e == 'soft_shadow' then
            local col_far = imgui.GetColorU32({ er, eg, eb, effect_alpha * 0.35 });
            local col_mid = imgui.GetColorU32({ er, eg, eb, effect_alpha * 0.55 });
            fx_pos[1] = x + off + 1; fx_pos[2] = y + off + 1;
            draw_list:AddText(font, font_size, fx_pos, col_far, text);
            fx_pos[1] = x + off; fx_pos[2] = y + off + 1;
            draw_list:AddText(font, font_size, fx_pos, col_far, text);
            fx_pos[1] = x + off; fx_pos[2] = y + off;
            draw_list:AddText(font, font_size, fx_pos, col_mid, text);
        else
            fx_pos[1] = x + off; fx_pos[2] = y + off;
            draw_list:AddText(font, font_size, fx_pos, imgui.GetColorU32({ er, eg, eb, effect_alpha }), text);
        end
    end

    -- Glow: a faint ring in the text's own color.
    if e == 'glow' then
        local gcol = imgui.GetColorU32({ color[1], color[2], color[3], effect_alpha * 0.22 });
        for _, o in ipairs(GLOW_RING) do
            fx_pos[1] = x + o[1]; fx_pos[2] = y + o[2];
            draw_list:AddText(font, font_size, fx_pos, gcol, text);
        end
    end

    -- Outline.
    if effect_has_outline(e) then
        local ocol = imgui.GetColorU32({ er, eg, eb, effect_alpha });
        local ring = (e == 'thick') and OUTLINE_THICK or OUTLINE_8;
        if e == 'outline' and (tonumber(font_size) or 16) < 15 then ring = OUTLINE_4; end
        for _, o in ipairs(ring) do
            fx_pos[1] = x + o[1]; fx_pos[2] = y + o[2];
            draw_list:AddText(font, font_size, fx_pos, ocol, text);
        end
    end

    local tcol = imgui.GetColorU32({ color[1], color[2], color[3], text_alpha });

    -- Faux bold: one extra pass 1px to the right.
    if settings.font_bold == true then
        fx_pos[1] = x + 1; fx_pos[2] = y;
        draw_list:AddText(font, font_size, fx_pos, tcol, text);
    end

    fx_pos[1] = x; fx_pos[2] = y;
    draw_list:AddText(font, font_size, fx_pos, tcol, text);
end

-- ============================================================================
-- Custom Font renderer: style-keyed FontManager pools
-- ============================================================================
--
-- FontManager rebuilds a font's glyph texture whenever its family, height,
-- bold / italic or flags change. 1.2.x reused one pool for every event type,
-- so an object that last showed a 16px hit and now shows a 19px weapon skill
-- was re-rasterized on the spot - a hitch every time text appeared.
--
-- Now each object is created once for one exact style and never restyled;
-- only its text, position and colors change per frame (cheap). Pools are
-- keyed by style and grow on demand; Font Style changes rebuild them once.

local MAX_FONT_POOL = 96;

local function style_key(family, height, bold, italic, outlined, right_justified)
    return table.concat({
        family, tostring(height), bold and 'b' or '-', italic and 'i' or '-',
        outlined and 'o' or '-', right_justified and 'r' or 'l',
    }, '|');
end

local function create_font_object(family, height, bold, italic, outlined, right_justified)
    local flags = FontDrawFlags.None;
    if outlined then flags = bit.bor(flags, FontDrawFlags.Outlined); end
    if right_justified then flags = bit.bor(flags, FontDrawFlags.RightJustified); end

    local ok, obj = pcall(function()
        return fonts.new({
            visible = false,
            can_focus = false,
            locked = true,
            lockedz = true,
            font_family = family,
            font_height = height,
            bold = bold,
            italic = italic,
            right_justified = right_justified == true,
            draw_flags = flags,
            color = 0xFFFFFFFF,
            color_outline = outlined and 0xFF000000 or 0x00000000,
            position_x = 0,
            position_y = 0,
            text = '',
            background = {
                visible = false,
            },
        });
    end);

    if ok then
        return obj;
    end

    return nil;
end

local function pool_object_count()
    local n = 0;
    for _, pool in pairs(state.font_styles or {}) do
        n = n + #pool.objs;
    end
    return n;
end

-- Returns a pool slot { main = obj, shadow = obj|nil } for this style.
local function acquire_font_slot(family, height, bold, italic, outlined, right_justified, want_shadow)
    state.font_styles = state.font_styles or {};
    local key = style_key(family, height, bold, italic, outlined, right_justified);
    local pool = state.font_styles[key];
    if pool == nil then
        pool = { objs = {}, used = 0 };
        state.font_styles[key] = pool;
    end

    pool.used = pool.used + 1;
    local slot = pool.objs[pool.used];
    if slot == nil then
        if pool_object_count() >= MAX_FONT_POOL then
            pool.used = pool.used - 1;
            return nil;
        end
        slot = {};
        -- The shadow copy is created first so it draws underneath.
        if want_shadow then
            slot.shadow = create_font_object(family, height, bold, italic, false, right_justified);
        end
        slot.main = create_font_object(family, height, bold, italic, outlined, right_justified);
        if slot.main == nil then
            pool.used = pool.used - 1;
            return nil;
        end
        pool.objs[pool.used] = slot;
    elseif want_shadow and slot.shadow == nil then
        -- Shadow turned on after this slot was made: rebuild the pools once.
        rebuild_font_pool();
        return nil;
    end

    return slot;
end

local function begin_font_frame()
    for _, pool in pairs(state.font_styles or {}) do
        pool.used = 0;
    end
end

local function end_font_frame()
    for _, pool in pairs(state.font_styles or {}) do
        for i = pool.used + 1, #pool.objs do
            local slot = pool.objs[i];
            if slot then
                if slot.main and slot.main.visible then slot.main.visible = false; end
                if slot.shadow and slot.shadow.visible then slot.shadow.visible = false; end
            end
        end
    end
end

-- Kept for callers that hide everything (hide_unused_fonts(1)).
local function hide_unused_fonts(from_index)
    for _, pool in pairs(state.font_styles or {}) do
        for _, slot in ipairs(pool.objs) do
            if slot.main then slot.main.visible = false; end
            if slot.shadow then slot.shadow.visible = false; end
        end
        pool.used = 0;
    end
end

local function ensure_font_pool(count)
    -- Pools grow on demand per style; nothing to pre-size.
end

local function destroy_font_pool()
    for _, pool in pairs(state.font_styles or {}) do
        for _, slot in ipairs(pool.objs) do
            if slot.main then pcall(function() slot.main:destroy(); end); end
            if slot.shadow then pcall(function() slot.shadow:destroy(); end); end
        end
    end
    state.font_styles = {};

    -- Legacy flat pool (pre-1.2.7), in case anything is left in it.
    for _, obj in ipairs(state.font_pool or {}) do
        if obj then pcall(function() obj:destroy(); end); end
    end
    state.font_pool = {};
    state.font_pool_size = 0;
end

local function ensure_preview_font_pool(count)
    count = math.max(0, tonumber(count) or 0);

    while #state.preview_font_pool < count do
        local obj = create_font_object(tostring(settings.font_family or 'Consolas'), 16,
            settings.font_bold == true, settings.font_italic == true,
            effect_has_outline(current_effect()), false);
        if not obj then
            break;
        end
        state.preview_font_pool[#state.preview_font_pool + 1] = obj;
    end
end

local function hide_preview_fonts()
    for _, obj in ipairs(state.preview_font_pool) do
        if obj then
            obj.visible = false;
        end
    end
end

local function destroy_preview_font_pool()
    for _, obj in ipairs(state.preview_font_pool) do
        if obj then
            pcall(function() obj:destroy(); end);
        end
    end
    state.preview_font_pool = {};
end

rebuild_font_pool = function()
    destroy_font_pool();
    destroy_preview_font_pool();
    state.font_generation = state.font_generation + 1;
end

-- Outline color for FontManager (Custom Font) text.
local function custom_outline_argb(color, alpha)
    local r, g, b = effect_rgb(color);
    return rgba_to_argb({ r, g, b, clamp(tonumber(settings.effect_opacity) or 0.85, 0.1, 1.0) }, alpha);
end

-- Custom Font: one event. Only text / position / colors are touched.
local function draw_custom_event(ev, age, x, y, alpha_mul, align)
    local e = current_effect();
    local family = tostring(settings.font_family or 'Consolas');
    local height = math.max(8, math.floor(16 * event_scale(ev, age) + 0.5));
    local bold = settings.font_bold == true;
    local italic = settings.font_italic == true;
    local outlined = effect_has_outline(e);
    local want_shadow = effect_has_shadow(e);
    local right_justified = align == 'left';

    local slot = acquire_font_slot(family, height, bold, italic, outlined, right_justified, want_shadow);
    if slot == nil then return; end
    local obj = slot.main;

    local color = event_color(ev);
    local text_value = display_case(rendered_event_text(ev));
    local alpha = alpha_mul * clamp(tonumber(settings.text_opacity) or 1.0, 0.1, 1.0);

    if align == 'center' then
        local width = 0;
        local ok, measured = pcall(function() return tonumber((obj:get_text_size())); end);
        if ok and measured and measured > 0 then
            width = measured;
        else
            local base = imgui.GetFontSize();
            local estimate = tonumber((imgui.CalcTextSize(text_value))) or 0;
            width = (base > 0) and (estimate * (height / base) * 1.15) or estimate;
        end
        x = x - width / 2;
    end

    if obj.text ~= text_value then obj.text = text_value; end
    if obj.position_x ~= x then obj.position_x = x; end
    if obj.position_y ~= y then obj.position_y = y; end

    local new_color = rgba_to_argb(color, alpha);
    if obj.color ~= new_color then obj.color = new_color; end
    if outlined then
        local new_outline = custom_outline_argb(color, alpha);
        if obj.color_outline ~= new_outline then obj.color_outline = new_outline; end
    end
    if obj.visible ~= true then obj.visible = true; end

    local shadow = slot.shadow;
    if shadow then
        local off = clamp(tonumber(settings.shadow_offset) or 2, 1, 6);
        local r, g, b = effect_rgb(color);
        local shadow_color = rgba_to_argb({ r, g, b, clamp(tonumber(settings.effect_opacity) or 0.85, 0.1, 1.0) * 0.8 }, alpha);
        if shadow.text ~= text_value then shadow.text = text_value; end
        if shadow.position_x ~= x + off then shadow.position_x = x + off; end
        if shadow.position_y ~= y + off then shadow.position_y = y + off; end
        if shadow.color ~= shadow_color then shadow.color = shadow_color; end
        if shadow.visible ~= true then shadow.visible = true; end
    end
end

-- Config Live Preview (Performance): draws a sample line at the cursor with
-- the exact same effect code the renderer uses, then reserves its space.
local function draw_imgui_text_with_outline(color, text_value)
    text_value = display_case(text_value);
    local font = imgui.GetFont();
    local size = imgui.GetFontSize();
    local width = tonumber((imgui.CalcTextSize(text_value))) or 0;
    local x, y = imgui.GetCursorScreenPos();
    x = tonumber(x) or 0; y = tonumber(y) or 0;
    local pad = math.max(3, size * 0.28);

    draw_fx_text(imgui.GetWindowDrawList(), font, size, x + pad, y + 2, color, 1.0, text_value, width);
    imgui.Dummy({ width + pad * 2 + 4, size + 4 });
end

-- ============================================================================
-- Lanes: outgoing, incoming and the center Notifications lane
-- ============================================================================

local ARC_WIDTH = 80.0;
local NOTIFY_MAX_VISIBLE = 5;

local function lane_of(ev)
    return ev.lane or ev.direction or 'outgoing';
end

local function lane_anchor(lane)
    if lane == 'incoming' then return settings.incoming; end
    if lane == 'notify' then return settings.notification; end
    return settings.outgoing;
end

local function lane_duration(lane)
    local duration = math.max(0.5, tonumber(settings.duration) or 3.5);
    if lane == 'notify' then
        return duration * 1.25;
    end
    return duration;
end

-- Fade out over the last 38% of the event's life; 'fade' motion also fades in.
local function event_alpha(age, duration, motion)
    local t = clamp(age / duration, 0.0, 1.0);
    local alpha = 1.0;
    if t > 0.62 then
        alpha = 1.0 - ((t - 0.62) / 0.38);
    end
    if motion == 'fade' then
        alpha = alpha * clamp(age / 0.30, 0.0, 1.0);
    end
    return clamp(alpha, 0.0, 1.0);
end

-- Critical "pop": grows quickly, then settles back to normal size.
-- Performance renderer only (FontManager font-size changes cause hitching).
local function crit_pop_scale(ev, age)
    if settings.crit_pop ~= true or ev.event_type ~= 'criticals' or lane_of(ev) == 'notify' then
        return 1.0;
    end
    if age < 0.08 then
        return 1.0 + 0.45 * (age / 0.08);
    end
    if age < 0.30 then
        return 1.45 - 0.45 * ((age - 0.08) / 0.22);
    end
    return 1.0;
end

-- Performance renderer: draws straight onto ImGui's background draw list.
-- align: 'right' (text starts at x), 'left' (text ends at x), 'center'.
local perf_pos = { 0, 0 };

local function draw_scrolling_event_performance(ev, age, x, y, alpha_mul, align)
    local draw_list = imgui.GetBackgroundDrawList and imgui.GetBackgroundDrawList() or nil;
    if not draw_list then
        return;
    end

    local color = event_color(ev);
    local display_text = display_case(rendered_event_text(ev));
    local base_size = imgui.GetFontSize();
    local normal_size = base_size * event_scale(ev, age);
    local font_size = normal_size * crit_pop_scale(ev, age);

    -- Width is needed for left / center alignment and for the backing plate.
    local measured_w = nil;
    if align ~= 'right' or tostring(settings.text_plate or 'off') ~= 'off' then
        measured_w = tonumber((imgui.CalcTextSize(display_text))) or 0;
        if base_size > 0 then
            measured_w = measured_w * (font_size / base_size);
        end
    end
    if align ~= 'right' then
        x = (align == 'center') and (x - measured_w / 2) or (x - measured_w);
    end

    -- Keep a popping crit centered on its row.
    y = y - (font_size - normal_size) / 2;

    -- Line made of differently colored parts (for example the Regen part in
    -- the Regen color and the Refresh part in the Refresh color).
    if ev.segments ~= nil and #ev.segments > 0 then
        local scale = (base_size > 0) and (font_size / base_size) or 1.0;
        local total_w = measured_w or ((tonumber((imgui.CalcTextSize(display_text))) or 0) * scale);
        local font = imgui.GetFont();
        local cx = x;
        for i, seg in ipairs(ev.segments) do
            local seg_text = display_case(tostring(seg.text or ''));
            local seg_color = event_color({ event_type = seg.event_type, kind = ev.kind, direction = ev.direction });
            -- The backing plate is drawn once, under the whole line.
            draw_fx_text(draw_list, font, font_size, cx, y, seg_color, alpha_mul, seg_text, (i == 1) and total_w or nil);
            cx = cx + (tonumber((imgui.CalcTextSize(seg_text))) or 0) * scale;
        end
        return;
    end

    draw_fx_text(draw_list, imgui.GetFont(), font_size, x, y, color, alpha_mul, display_text, measured_w);
end

local function draw_lane(events, lane, now, pool_index)
    if #events == 0 then
        return pool_index;
    end

    local anchor = lane_anchor(lane);
    local is_notify = lane == 'notify';
    local duration = lane_duration(lane);
    local motion = is_notify and 'static' or tostring(anchor.motion or 'scroll');

    local speed = math.max(0.0, tonumber(settings.scroll_speed) or 70.0);
    if motion == 'fade' then
        speed = speed * 0.35;
    elseif motion == 'static' then
        speed = 0.0;
    end

    local anchor_x = tonumber(anchor.x) or 500;
    local anchor_y = tonumber(anchor.y) or 500;
    -- Notifications stack downward from the anchor, newest on top.
    local growth_up = (not is_notify) and (anchor.growth or 'up') ~= 'down';
    local align = is_notify and 'center' or (((anchor.orientation or 'right') == 'left') and 'left' or 'right');
    local performance = (settings.renderer_mode or 'performance') == 'performance';

    local previous_y = nil;
    local previous_height = nil;

    for _, ev in ipairs(events) do
        pool_index = pool_index + 1;
        if pool_index > MAX_FONT_POOL then
            break;
        end

        local age = math.max(0.0, now - ev.created);
        local travel = age * speed;
        local candidate_y = growth_up and (anchor_y - travel) or (anchor_y + travel);
        local y = candidate_y;

        local current_height = math.max(
            20.0,
            imgui.GetFontSize() * event_scale(ev, age) * 1.45
        );

        if previous_y ~= nil then
            local spacing = math.max(current_height, previous_height or current_height) + 3.0;
            if growth_up then
                y = math.min(candidate_y, previous_y - spacing);
            else
                y = math.max(candidate_y, previous_y + spacing);
            end
        end

        -- Arc: drift sideways along a curve as the text rises.
        local x = anchor_x;
        if motion == 'arc' then
            local progress = clamp(age / duration, 0.0, 1.0);
            local offset = ARC_WIDTH * (1.0 - (1.0 - progress) * (1.0 - progress));
            x = (align == 'left') and (anchor_x - offset) or (anchor_x + offset);
        end

        local alpha = event_alpha(age, duration, motion);

        if performance then
            draw_scrolling_event_performance(ev, age, x, y, alpha, align);
        else
            draw_custom_event(ev, age, x, y, alpha, align);
        end

        previous_y = y;
        previous_height = current_height;
    end

    return pool_index;
end

local function newest_first(a, b)
    return a.created > b.created;
end

local function draw_events()
    if not settings.enabled then
        hide_unused_fonts(1);
        return;
    end

    local now = os.clock();
    local keep = {};
    local lanes = { outgoing = {}, incoming = {}, notify = {} };

    for _, ev in ipairs(state.events) do
        local lane = lane_of(ev);
        if (now - ev.created) < lane_duration(lane) then
            keep[#keep + 1] = ev;
            local list = lanes[lane] or lanes.outgoing;
            list[#list + 1] = ev;
        end
    end

    state.events = keep;

    table.sort(lanes.outgoing, newest_first);
    table.sort(lanes.incoming, newest_first);
    table.sort(lanes.notify, newest_first);

    -- Visible cap: drop the OLDEST rows (end of each newest-first list).
    local cap = math.floor(clamp(tonumber(settings.max_visible_events) or 14, 4, MAX_EVENTS));
    while (#lanes.outgoing + #lanes.incoming) > cap do
        local oldest_out = lanes.outgoing[#lanes.outgoing];
        local oldest_in = lanes.incoming[#lanes.incoming];

        if oldest_out and oldest_in then
            if oldest_out.created <= oldest_in.created then
                table.remove(lanes.outgoing);
            else
                table.remove(lanes.incoming);
            end
        elseif oldest_out then
            table.remove(lanes.outgoing);
        elseif oldest_in then
            table.remove(lanes.incoming);
        else
            break;
        end
    end

    while #lanes.notify > NOTIFY_MAX_VISIBLE do
        table.remove(lanes.notify);
    end

    local used = 0;
    local performance = (settings.renderer_mode or 'performance') == 'performance';

    if performance then
        -- Completely bypass FontManager while fighting.
        if state.fonts_visible_last then
            hide_unused_fonts(1);
            state.fonts_visible_last = false;
        end
    else
        begin_font_frame();
        state.fonts_visible_last = true;
    end

    used = draw_lane(lanes.outgoing, 'outgoing', now, used);
    used = draw_lane(lanes.incoming, 'incoming', now, used);
    used = draw_lane(lanes.notify, 'notify', now, used);

    if not performance then
        end_font_frame();
    end
end

return {
    FONT_FAMILIES = FONT_FAMILIES,
    cycle_font_family = cycle_font_family,
    rebuild_font_pool = rebuild_font_pool,
    MAX_FONT_POOL = MAX_FONT_POOL,
    ensure_font_pool = ensure_font_pool,
    hide_unused_fonts = hide_unused_fonts,
    destroy_font_pool = destroy_font_pool,
    ensure_preview_font_pool = ensure_preview_font_pool,
    hide_preview_fonts = hide_preview_fonts,
    destroy_preview_font_pool = destroy_preview_font_pool,
    draw_imgui_text_with_outline = draw_imgui_text_with_outline,
    draw_fx_text = draw_fx_text,
    set_font_family = set_font_family,
    TEXT_EFFECTS = TEXT_EFFECTS,
    EFFECT_COLORS = EFFECT_COLORS,
    TEXT_PLATES = TEXT_PLATES,
    current_effect = current_effect,
    effect_has_outline = effect_has_outline,
    effect_has_shadow = effect_has_shadow,
    custom_outline_argb = custom_outline_argb,
    display_case = display_case,
    draw_events = draw_events,
};
