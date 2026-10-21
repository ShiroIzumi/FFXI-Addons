--[[
    MogSuite - modules/inventory/views.lua

    The List, Grid and Categories views.
]]

-- ============================================================================
-- Main window
-- ============================================================================

function is_new(row)
    if not config.new_highlight then return false, 0; end
    local t = state.new_at[row.bag] and state.new_at[row.bag][row.id] or nil;
    if t == nil then return false, 0; end
    if config.new_sticky ~= false then return true, 1.0; end
    local age = os.clock() - t;
    local dur = math.max(1, tonumber(config.new_seconds) or 10);
    if age > dur then
        state.new_at[row.bag][row.id] = nil;
        return false, 0;
    end
    return true, 1 - (age / dur);
end

-- Hovering a new item clears its highlight (live rows only).
function seen_new(row)
    if row.source ~= nil or row.bag == nil or row.id == nil then return; end
    local b = state.new_at[row.bag];
    if b ~= nil and b[row.id] ~= nil then
        b[row.id] = nil;
        state.view_gen = (state.view_gen or 0) + 1;
    end
end

function open_ctx(row)
    state.ctx = row;
    imgui.OpenPopup('##nai_item_ctx');
end

-- Five-point star (fonts may not have a star glyph).
function draw_star(dl, cx, cy, r, col)
    local outer, inner = {}, {};
    for i = 0, 4 do
        local a = -math.pi / 2 + i * (2 * math.pi / 5);
        outer[i] = { cx + math.cos(a) * r, cy + math.sin(a) * r };
        local b = a + math.pi / 5;
        inner[i] = { cx + math.cos(b) * r * 0.45, cy + math.sin(b) * r * 0.45 };
    end
    for i = 0, 4 do
        local prev = inner[(i + 4) % 5];
        dl:AddTriangleFilled(prev, outer[i], inner[i], col);
        dl:AddTriangleFilled({ cx, cy }, prev, inner[i], col);
    end
end

STAR_COLOR = { 1.00, 0.82, 0.30, 1.0 };
SPLIT_COLOR = { 0.55, 0.85, 0.95, 1.0 };

-- Quantity text: ' x12' / ' 12/99' (list) or '12' / '12/99' (grid).
function qty_text(row, grid)
    local st = tonumber(row.info.stack) or 1;
    if config.qty_format == 'stack' and st > 1 then
        return grid and ('%d/%d'):fmt(row.count, st) or (' %d/%d'):fmt(row.count, st);
    end
    if row.count > 1 or config.show_qty_one then
        return grid and tostring(row.count) or (' x%d'):fmt(row.count);
    end
    return nil;
end

function is_dimmed(row)
    return config.grey_unusable ~= false and not can_wear(row.info);
end

function dim_color(col, dim)
    if not dim then return col; end
    return { col[1] * 0.6, col[2] * 0.6, col[3] * 0.6, (col[4] or 1.0) * 0.55 };
end

-- show_bag: draw the bag (and character) on the right of each row.
function draw_list_view(rows, show_bag)
    local scale = tonumber(config.font_scale) or 1.0;
    local icon = math.floor((tonumber(config.icon_size) or 24) * scale);
    local line_h = imgui.GetTextLineHeight();
    local row_h = math.max(icon, line_h) + (tonumber(config.row_spacing) or 2) * 2;
    local width = tonumber((imgui.GetContentRegionAvail())) or 300;
    local dl = imgui.GetWindowDrawList();

    for i, row in ipairs(rows) do
        local sx, sy = imgui.GetCursorScreenPos();
        imgui.InvisibleButton('##nai_row_' .. row.uid, { math.max(1, width), row_h });
        local hovered = imgui.IsItemHovered();
        if hovered and imgui.IsMouseClicked(1) then open_ctx(row); end
        if hovered then seen_new(row); end
        -- Rows scrolled out of view are skipped (icons load as you scroll).
        local visible = imgui.IsItemVisible == nil or imgui.IsItemVisible();
        if visible then

        local dim = is_dimmed(row);
        if i % 2 == 0 then
            dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32({ 1, 1, 1, 0.025 }), 3.0);
        end
        local new, strength = is_new(row);
        if new then
            local pulse = 0.55 + 0.45 * math.abs(math.sin(os.clock() * 4));
            dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32(accent(0.30 * strength * pulse)), 3.0);
            dl:AddRectFilled({ sx, sy }, { sx + 3, sy + row_h }, imgui.GetColorU32(accent(strength)), 0.0);
        end
        if hovered then
            dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32(accent(0.16)), 3.0);
        end

        local x = sx + 4;
        local tex = get_icon(row.info);
        local iy = sy + (row_h - icon) * 0.5;
        if tex ~= nil then
            dl:AddImage(tex.id, { x, iy }, { x + icon, iy + icon }, { 0, 0 }, { 1, 1 },
                imgui.GetColorU32(dim and { 1, 1, 1, 0.35 } or UI_WHITE));
        else
            dl:AddRectFilled({ x, iy }, { x + icon, iy + icon }, imgui.GetColorU32(UI_CONTROL), 3.0);
        end
        x = x + icon + 8;

        local ty = sy + (row_h - line_h) * 0.5;
        if is_favorite(row) then
            local r = math.max(4, line_h * 0.36);
            draw_star(dl, x + r, sy + row_h * 0.5, r, imgui.GetColorU32(STAR_COLOR));
            x = x + r * 2 + 5;
        end
        local name_col = row.equipped ~= nil and UI_ACCENT_TEXT or config.name_color;
        if row.mirror then name_col = EQUIP_USE_BLUE; end
        draw_fx_text(dl, x, ty, dim_color(name_col, dim), row.info.name);
        x = x + text_w(row.info.name);
        local q = qty_text(row, false);
        if q ~= nil then
            draw_fx_text(dl, x, ty, dim_color(config.qty_color, dim), q);
            x = x + text_w(q);
        end
        -- Enchanted gear: charges "(19/30)" and the time until usable.
        local ch, timer = enchant_suffix(row);
        if ch ~= nil then
            draw_fx_text(dl, x, ty, dim_color(EQUIP_USE_BLUE, dim), ch);
            x = x + text_w(ch);
        end
        if timer ~= nil then
            draw_fx_text(dl, x, ty, dim_color({ 0.92, 0.70, 0.32, 1.0 }, dim), timer);
            x = x + text_w(timer);
        end

        -- Right side: tags, split marker and (All / Characters) the bag.
        local right = sx + width - 6;
        local function right_text(s, col)
            local w = text_w(s);
            if right - w > x + 12 then
                draw_fx_text(dl, right - w, ty, col, s);
                right = right - w - 8;
            end
        end
        if show_bag then
            local where = BAG_NAMES[row.bag] or '';
            if row.source == 'alt' then where = tostring(row.char) .. ' - ' .. where; end
            right_text(where, UI_MUTED);
        end
        if config.show_tags then
            if row.info.ex then right_text('Ex', { 0.55, 0.75, 1.0, 1.0 }); end
            if row.info.rare then right_text('Rare', { 0.95, 0.75, 0.35, 1.0 }); end
            if row.equipped ~= nil then right_text('E', UI_ACCENT); end
        end
        if config.show_split ~= false and row.split ~= nil then right_text('Split', SPLIT_COLOR); end

        if hovered and not imgui.IsPopupOpen('##nai_item_ctx') then draw_tooltip(row); end
        end
    end
end

function draw_grid_view(rows)
    local scale = tonumber(config.font_scale) or 1.0;
    local cell = math.floor((tonumber(config.grid_icon) or 40) * scale);
    local gap = 4;
    local width = tonumber((imgui.GetContentRegionAvail())) or 300;
    local cols = math.max(1, math.floor((width + gap) / (cell + gap)));
    local dl = imgui.GetWindowDrawList();

    for i, row in ipairs(rows) do
        if (i - 1) % cols ~= 0 then imgui.SameLine(0, gap); end
        local sx, sy = imgui.GetCursorScreenPos();
        imgui.InvisibleButton('##nai_cell_' .. row.uid, { cell, cell });
        local hovered = imgui.IsItemHovered();
        if hovered and imgui.IsMouseClicked(1) then open_ctx(row); end
        if hovered then seen_new(row); end
        local visible = imgui.IsItemVisible == nil or imgui.IsItemVisible();
        if visible then

        local dim = is_dimmed(row);
        dl:AddRectFilled({ sx, sy }, { sx + cell, sy + cell }, imgui.GetColorU32({ 1, 1, 1, 0.04 }), 4.0);
        local tex = get_icon(row.info);
        if tex ~= nil then
            local p = math.floor(cell * 0.12);
            dl:AddImage(tex.id, { sx + p, sy + p }, { sx + cell - p, sy + cell - p }, { 0, 0 }, { 1, 1 },
                imgui.GetColorU32(dim and { 1, 1, 1, 0.35 } or UI_WHITE));
        end
        local new, strength = is_new(row);
        if new then
            dl:AddRect({ sx, sy }, { sx + cell, sy + cell }, imgui.GetColorU32(accent(strength)), 4.0, 0, 2.0);
        end
        if row.equipped ~= nil then
            dl:AddCircleFilled({ sx + 6, sy + 6 }, 3.0, imgui.GetColorU32(row.mirror and EQUIP_USE_BLUE or UI_ACCENT), 10);
        end
        if row.mirror then
            dl:AddRect({ sx, sy }, { sx + cell, sy + cell }, imgui.GetColorU32(EQUIP_USE_BLUE), 4.0, 0, 1.5);
        end
        if is_favorite(row) then
            local r = math.max(4, cell * 0.12);
            draw_star(dl, sx + cell - r - 2, sy + r + 2, r, imgui.GetColorU32(STAR_COLOR));
        end
        if config.show_split ~= false and row.split ~= nil then
            local t = math.max(6, cell * 0.2);
            dl:AddTriangleFilled({ sx + 1, sy + cell - 1 - t }, { sx + 1, sy + cell - 1 }, { sx + 1 + t, sy + cell - 1 },
                imgui.GetColorU32(SPLIT_COLOR));
        end
        if hovered then
            dl:AddRect({ sx, sy }, { sx + cell, sy + cell }, imgui.GetColorU32(accent(0.9)), 4.0, 0, 1.5);
        end
        local q = qty_text(row, true);
        if q ~= nil and text_w(q) > cell - 4 then q = tostring(row.count); end
        if q ~= nil then
            draw_fx_text(dl, sx + cell - text_w(q) - 3, sy + cell - imgui.GetTextLineHeight() - 1, dim_color(config.qty_color, dim), q);
        end
        if hovered and not imgui.IsPopupOpen('##nai_item_ctx') then draw_tooltip(row); end
        end
    end
end

-- ----------------------------------------------------------------------------
-- Categories view (AdiBags style): sections in your order, each a list or grid
-- ----------------------------------------------------------------------------

CATEGORIES = {
    favorites = 'Favorites', new = 'New', equipped = 'Equipped', weapons = 'Weapons', armor = 'Armor',
    ammo = 'Ammo', usable = 'Usable', crystals = 'Crystals', rareex = 'Rare / Ex', materials = 'Materials',
};
CAT_DEFAULT_ORDER = { 'favorites', 'new', 'equipped', 'weapons', 'armor', 'ammo', 'usable', 'crystals', 'rareex', 'materials' };

-- Your order with any missing / unknown keys fixed.
function cat_order()
    local out, seen = {}, {};
    for _, k in ipairs(config.cat_order or {}) do
        if CATEGORIES[k] ~= nil and not seen[k] then out[#out + 1] = k; seen[k] = true; end
    end
    for _, k in ipairs(CAT_DEFAULT_ORDER) do
        if not seen[k] then out[#out + 1] = k; seen[k] = true; end
    end
    return out;
end

SLOT_AMMO_BIT = 8;  -- bit 3

function category_of(row)
    if is_favorite(row) then return 'favorites'; end
    if (is_new(row)) then return 'new'; end
    if row.equipped ~= nil then return 'equipped'; end
    local info = row.info;
    if (info.type == TYPE_WEAPON or info.type == TYPE_ARMOR) and info.slots == SLOT_AMMO_BIT then return 'ammo'; end
    if info.type == TYPE_WEAPON then return 'weapons'; end
    if info.type == TYPE_ARMOR then return 'armor'; end
    if info.type == TYPE_USABLE then return 'usable'; end
    if info.type == TYPE_CRYSTAL then return 'crystals'; end
    if info.rare or info.ex then return 'rareex'; end
    return 'materials';
end

function draw_categories_view(rows, show_bag)
    local groups = {};
    for _, row in ipairs(rows) do
        local c = category_of(row);
        groups[c] = groups[c] or {};
        table.insert(groups[c], row);
    end
    config.cat_collapsed = config.cat_collapsed or T{};
    local dl = imgui.GetWindowDrawList();
    local line_h = imgui.GetTextLineHeight();

    for _, key in ipairs(cat_order()) do
        local list = groups[key];
        if list ~= nil and #list > 0 then
            local collapsed = config.cat_collapsed[key] == true;
            local width = tonumber((imgui.GetContentRegionAvail())) or 300;
            local h = line_h + 8;
            local sx, sy = imgui.GetCursorScreenPos();
            if imgui.InvisibleButton('##nai_cat_' .. key, { math.max(1, width), h }) then
                config.cat_collapsed[key] = (not collapsed) or nil;
                collapsed = not collapsed;
                mark_dirty();
            end
            local hovered = imgui.IsItemHovered();
            dl:AddRectFilled({ sx, sy }, { sx + width, sy + h }, imgui.GetColorU32(accent(hovered and 0.26 or 0.13)), 4.0);
            dl:AddRectFilled({ sx, sy + h - 2 }, { sx + width, sy + h }, imgui.GetColorU32(accent(0.55)), 0.0);

            -- Arrow: right when collapsed, down when open.
            local ax, ay, a = sx + 10, sy + h * 0.5, math.max(3, line_h * 0.22);
            local acol = imgui.GetColorU32(UI_ACCENT_TEXT);
            if collapsed then
                dl:AddTriangleFilled({ ax - a * 0.6, ay - a }, { ax + a * 0.8, ay }, { ax - a * 0.6, ay + a }, acol);
            else
                dl:AddTriangleFilled({ ax - a, ay - a * 0.6 }, { ax + a, ay - a * 0.6 }, { ax, ay + a * 0.8 }, acol);
            end

            local label = CATEGORIES[key];
            local ty = sy + 4;
            draw_fx_text(dl, sx + 22, ty, UI_ACCENT_TEXT, label);
            local cnt = ('  %d'):fmt(#list);
            draw_fx_text(dl, sx + 22 + text_w(label), ty, UI_MUTED, cnt);
            if config.show_value ~= false then
                local total = rows_value(list);
                if total > 0 then
                    local vt = fmt_gil(total) .. ' gil';
                    draw_fx_text(dl, sx + width - text_w(vt) - 8, ty, config.qty_color, vt);
                end
            end

            if not collapsed then
                imgui.Dummy({ 1, 2 });
                if config.cat_style == 'grid' then
                    draw_grid_view(list);
                else
                    draw_list_view(list, show_bag);
                end
            end
            imgui.Dummy({ 1, 4 });
        end
    end
end

-- ----------------------------------------------------------------------------
