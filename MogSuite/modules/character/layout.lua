--[[
    MogSuite - modules/character/layout.lua

    Layout helpers: aligned text, bars, section headers, chips and tiles.
]]

-- ============================================================================
-- Layout helpers (1.2.0 redesign)
-- Labels are muted and left-aligned, values are bright and right-aligned in
-- fixed cells, so nothing runs together at any window width.
-- ============================================================================

UI_BRIGHT   = { 0.92, 0.94, 0.96, 1.00 };
TRACK_COLOR = { 1.00, 1.00, 1.00, 0.08 };
HP_COLOR    = { 0.85, 0.40, 0.48, 1.00 };
MP_COLOR    = { 0.37, 0.60, 0.85, 1.00 };
TP_COLOR    = { 0.85, 0.71, 0.37, 1.00 };

function with_alpha(c, a)
    return { c[1], c[2], c[3], (c[4] or 1.0) * a };
end

function avail_width()
    local w = select(1, imgui.GetContentRegionAvail());
    return tonumber(w) or 400;
end

-- NOTE: CalcTextSize returns (x, y). 1.2.0 passed both straight into
-- tonumber(), which treated the height as a number BASE and returned wrong
-- widths (or nil) - the cause of the overlapping columns at larger fonts.
function text_width(s)
    local w = imgui.CalcTextSize(tostring(s));
    return tonumber(w) or 0;
end

-- Each frame the layout reports the narrowest width its content can live
-- in; the next frame the window is not allowed to get narrower than that.
function require_width(w)
    w = tonumber(w) or 0;
    if w > (tonumber(state.frame_req_w) or 0) then
        state.frame_req_w = w;
    end
end

function line_height()
    return tonumber(select(2, imgui.CalcTextSize('Ag'))) or 14;
end

-- Right-aligns text so it ends at right_x (window-local). Call SameLine first
-- when it should share the current line.
function text_right(text, color, right_x)
    text = tostring(text);
    imgui.SetCursorPosX(math.max(imgui.GetCursorPosX(), right_x - text_width(text)));
    imgui.TextColored(color, text);
end

-- Thin rounded progress bar on the window draw list; advances the cursor.
function draw_bar(width, height, frac, color)
    local x, y = imgui.GetCursorScreenPos();
    x = tonumber(x); y = tonumber(y);
    local dl = imgui.GetWindowDrawList();
    width = math.max(1, width);
    if x and y and dl then
        frac = math.max(0, math.min(1, tonumber(frac) or 0));
        dl:AddRectFilled({ x, y }, { x + width, y + height }, imgui.GetColorU32(TRACK_COLOR), height * 0.5);
        if frac > 0 then
            dl:AddRectFilled({ x, y }, { x + math.max(height, width * frac), y + height },
                imgui.GetColorU32(color), height * 0.5);
        end
    end
    imgui.Dummy({ width, height });
end

-- Accent section header with a soft rule; optional muted note on the right.
function sheet_section(title, note)
    imgui.Spacing();
    local start_x = imgui.GetCursorPosX();
    local avail = avail_width();
    imgui.TextColored(UI_ACCENT_TEXT, title);
    if note ~= nil and note ~= '' then
        imgui.SameLine();
        text_right(note, state.muted_color, start_x + avail);
    end
    imgui.PushStyleColor(ImGuiCol_Separator, ui_accent(0.30));
    imgui.Separator();
    imgui.PopStyleColor(1);
end

-- Header-sized section for a column group (explicit width).
function column_section(title, note, width)
    local start_x = imgui.GetCursorPosX();
    imgui.TextColored(UI_ACCENT_TEXT, title);
    if note ~= nil and note ~= '' then
        imgui.SameLine();
        text_right(note, state.muted_color, start_x + width);
    end
    local x, y = imgui.GetCursorScreenPos();
    local dl = imgui.GetWindowDrawList();
    x = tonumber(x); y = tonumber(y);
    if x and y and dl then
        dl:AddLine({ x, y }, { x + width, y }, imgui.GetColorU32(ui_accent(0.30)), 1.0);
    end
    imgui.Dummy({ width, 3 * state.overall_scale[1] });
end

-- HP / MP / TP: three cells, label + value on top, thin bar underneath.
function draw_vitals(hp, hpmax, mp, mpmax, tp)
    local scale = state.overall_scale[1];
    local gap = 12 * scale;
    local avail = avail_width();
    local cell = (avail - gap * 2) / 3;
    local base_x = imgui.GetCursorPosX();

    local items = {
        { 'HP', ('%d / %d'):fmt(hp, hpmax), (hpmax > 0) and (hp / hpmax) or 0, HP_COLOR },
        { 'MP', ('%d / %d'):fmt(mp, mpmax), (mpmax > 0) and (mp / mpmax) or 0, MP_COLOR },
        { 'TP', tostring(tp), tp / 3000, TP_COLOR },
    };

    local need = text_width('MP') + text_width('9999 / 9999') + gap;
    require_width(need * 3 + gap * 2);

    for i, it in ipairs(items) do
        local x0 = base_x + (i - 1) * (cell + gap);
        if i > 1 then imgui.SameLine(); end
        imgui.SetCursorPosX(x0);
        imgui.TextColored(state.muted_color, it[1]);
        imgui.SameLine();
        text_right(it[2], UI_BRIGHT, x0 + cell);
    end

    for i, it in ipairs(items) do
        local x0 = base_x + (i - 1) * (cell + gap);
        if i > 1 then imgui.SameLine(); end
        imgui.SetCursorPosX(x0);
        draw_bar(cell, 5 * scale, it[3], it[4]);
    end
end

-- Label / value grid. items: { label, value, value_color, extra, extra_color }.
-- extra (e.g. "+5" from gear) is drawn small after the value.
function draw_kv_grid(items, columns, min_cell)
    local scale = state.overall_scale[1];
    local avail = avail_width();
    local gap = 18 * scale;

    -- Narrowest cell that fits every label + value (+ gear bonus).
    local need = 0;
    for _, it in ipairs(items) do
        local w = text_width(it[1]) + text_width(it[2]) + 12 * scale;
        if it[4] ~= nil and it[4] ~= '' then
            w = w + text_width(it[4]) + 3 * scale;
        end
        need = math.max(need, w);
    end
    columns = math.max(1, math.min(columns, math.floor((avail + gap) / (need + gap))));
    require_width(need);

    local cell = (avail - gap * (columns - 1)) / columns;
    local base_x = imgui.GetCursorPosX();

    for i, it in ipairs(items) do
        local col = (i - 1) % columns;
        if col ~= 0 then imgui.SameLine(); end
        local x0 = base_x + col * (cell + gap);
        imgui.SetCursorPosX(x0);
        imgui.TextColored(state.muted_color, tostring(it[1]));

        local value = tostring(it[2]);
        imgui.SameLine();
        if it[4] ~= nil and it[4] ~= '' then
            local spacing = 3 * scale;
            local total_w = text_width(value) + spacing + text_width(it[4]);
            imgui.SetCursorPosX(math.max(imgui.GetCursorPosX(), x0 + cell - total_w));
            imgui.TextColored(it[3] or UI_BRIGHT, value);
            imgui.SameLine(0, spacing);
            imgui.TextColored(it[5] or state.good_color, tostring(it[4]));
        else
            text_right(value, it[3] or UI_BRIGHT, x0 + cell);
        end
    end
end

-- Small rounded chip. Returns its width.
function draw_chip(text, text_color, bg_color)
    local scale = state.overall_scale[1];
    local pad_x, pad_y = 6 * scale, 1 * scale;
    local w = text_width(text) + pad_x * 2;
    local h = line_height() + pad_y * 2;

    local sx, sy = imgui.GetCursorScreenPos();
    sx = tonumber(sx); sy = tonumber(sy);
    local dl = imgui.GetWindowDrawList();
    if sx and sy and dl then
        dl:AddRectFilled({ sx, sy }, { sx + w, sy + h }, imgui.GetColorU32(bg_color), 4.0);
    end

    local cx, cy = imgui.GetCursorPos();
    cx = tonumber(cx) or 0; cy = tonumber(cy) or 0;
    imgui.SetCursorPos({ cx + pad_x, cy + pad_y });
    imgui.TextColored(text_color, tostring(text));
    imgui.SetCursorPos({ cx, cy });
    imgui.Dummy({ w, h });
    return w;
end

-- Chips that wrap to the next line when the row is full.
function draw_chip_row(chips)
    local scale = state.overall_scale[1];
    local gap = 4 * scale;
    local avail = avail_width();
    local used = 0;

    for i, c in ipairs(chips) do
        local w = text_width(c[1]) + 12 * scale;
        require_width(w);
        if i > 1 then
            if used + gap + w <= avail then
                imgui.SameLine(0, gap);
                used = used + gap;
            else
                used = 0;
            end
        end
        draw_chip(c[1], c[2], c[3]);
        used = used + w;
    end
end

-- Comma-separated effect names that wrap inside the available width.
function draw_effect_list(effects)
    if effects == nil or #effects == 0 then
        imgui.TextColored(state.muted_color, 'none');
        return;
    end

    for index, effect in ipairs(effects) do
        local color = (effect.id == 13) and state.bad_color or state.good_color;
        imgui.TextColored(color, effect.name .. ((index < #effects) and ',' or ''));
        if index < #effects then
            imgui.SameLine();
            local remaining = select(1, imgui.GetContentRegionAvail());
            local next_w = text_width(effects[index + 1].name .. ',');
            if (tonumber(remaining) or 0) < next_w + 8 then
                imgui.NewLine();
            end
        end
    end
end

-- ============================================================================
-- Overview tab pieces (1.4.0: tile layout)
-- Every tile is placed at measured screen positions, so text never collides
-- and the grids fall back to fewer columns when the window is narrow.
-- ============================================================================

TILE_BG        = { 1.00, 1.00, 1.00, 0.035 };
TILE_BG_LOCKED = { 1.00, 1.00, 1.00, 0.018 };
VALUE_FONT_MUL = 1.12;

function screen_xy()
    local x, y = imgui.GetCursorScreenPos();
    return tonumber(x) or 0, tonumber(y) or 0;
end

function tile_rect(x, y, w, h, bg, border)
    local dl = imgui.GetWindowDrawList();
    if dl == nil then return; end
    local r = 5.0 * state.overall_scale[1];
    dl:AddRectFilled({ x, y }, { x + w, y + h }, imgui.GetColorU32(bg), r);
    if border ~= nil then
        dl:AddRect({ x, y }, { x + w, y + h }, imgui.GetColorU32(border), r);
    end
end

function text_at(x, y, color, text)
    imgui.SetCursorScreenPos({ x, y });
    imgui.TextColored(color, tostring(text));
end

-- Width / height of text in the larger value font.
function big_text_size(text)
    imgui.PushFont(nil, imgui.GetFontSize() * VALUE_FONT_MUL);
    local w = text_width(text);
    local h = line_height();
    imgui.PopFont();
    return w, h;
end

function big_text_at(x, y, color, text)
    imgui.PushFont(nil, imgui.GetFontSize() * VALUE_FONT_MUL);
    text_at(x, y, color, text);
    imgui.PopFont();
end

-- Moves the cursor below a block of tiles that started at (ox, oy).
function end_tile_block(ox, oy, height)
    imgui.SetCursorScreenPos({ ox, oy + height });
    imgui.Dummy({ 1, 1 });
end

-- Picks how many columns fit: preferred, then half, then a quarter.
function fit_columns(preferred, need, gap, avail, minimum)
    local columns = preferred;
    while columns > (minimum or 1) and (need * columns + gap * (columns - 1)) > avail do
        columns = math.max(minimum or 1, math.floor(columns / 2));
    end
    return columns;
end
