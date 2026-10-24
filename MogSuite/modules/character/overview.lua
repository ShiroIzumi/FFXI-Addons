--[[
    MogSuite - modules/character/overview.lua

    The Overview tab: equipped items, attributes, resistances, haste and jobs.
]]

-- Label / value tiles. items: { label, value, extra, extra_color, value_color, highlight }
function draw_stat_tiles(items, preferred_columns)
    local scale = state.overall_scale[1];
    local avail = avail_width();
    local gap = 5 * scale;
    local pad = 8 * scale;
    local lh = line_height();

    local value_w = {};
    local lh_big = lh;
    local need = 0;
    for i, it in ipairs(items) do
        local w, h = big_text_size(it.value);
        value_w[i] = w;
        lh_big = h;
        local tile = text_width(it.label) + w + pad * 2 + 10 * scale;
        if it.extra ~= nil and it.extra ~= '' then
            tile = tile + text_width(it.extra) + 3 * scale;
        end
        need = math.max(need, tile);
    end

    require_width(need * 2 + gap);
    local columns = fit_columns(preferred_columns, need, gap, avail, 2);
    local tile_w = (avail - gap * (columns - 1)) / columns;
    local tile_h = lh_big + 8 * scale;
    local ox, oy = screen_xy();

    for i, it in ipairs(items) do
        local col = (i - 1) % columns;
        local row = math.floor((i - 1) / columns);
        local x = ox + col * (tile_w + gap);
        local y = oy + row * (tile_h + gap);

        tile_rect(x, y, tile_w, tile_h, it.highlight and ui_accent(0.12) or TILE_BG);
        text_at(x + pad, y + (tile_h - lh) / 2, state.muted_color, it.label);

        local right = x + tile_w - pad;
        if it.extra ~= nil and it.extra ~= '' then
            local ew = text_width(it.extra);
            text_at(right - ew, y + (tile_h - lh) / 2 + (lh_big - lh) * 0.35, it.extra_color or state.good_color, it.extra);
            right = right - ew - 3 * scale;
        end
        big_text_at(right - value_w[i], y + (tile_h - lh_big) / 2, it.value_color or UI_BRIGHT, it.value);
    end

    local rows = math.ceil(#items / columns);
    end_tile_block(ox, oy, rows * (tile_h + gap) - gap);
end

function draw_attributes(player)
    local labels = { 'STR', 'DEX', 'VIT', 'AGI', 'INT', 'MND', 'CHR' };
    local items = {};

    for i = 0, 6 do
        local total, _, mod = stat_total(player, i);
        local extra = nil;
        local extra_color = nil;
        if mod ~= 0 then
            extra = fmt_signed(mod);
            extra_color = (mod > 0) and state.good_color or state.bad_color;
        end
        items[#items + 1] = { label = labels[i + 1], value = tostring(total), extra = extra, extra_color = extra_color };
    end

    items[#items + 1] = {
        label = 'ATK / DEF',
        value = ('%d / %d'):fmt(tonumber(safe_call(player, 'GetAttack')) or 0, tonumber(safe_call(player, 'GetDefense')) or 0),
        highlight = true,
    };

    draw_stat_tiles(items, 4);
end

RESIST_NAMES = { 'Fire', 'Ice', 'Wind', 'Earth', 'Thunder', 'Water', 'Light', 'Dark' };

function draw_resistances(player)
    local scale = state.overall_scale[1];
    local avail = avail_width();
    local gap = 4 * scale;
    local lh = line_height();

    local need = 0;
    for _, name in ipairs(RESIST_NAMES) do
        need = math.max(need, text_width(name) + 10 * scale);
    end
    need = math.max(need, text_width('-100') + 10 * scale);

    require_width(need * 4 + gap * 3);
    local columns = fit_columns(8, need, gap, avail, 4);
    local tile_w = (avail - gap * (columns - 1)) / columns;
    local strip = 3 * scale;
    local tile_h = strip + lh * 2 + 8 * scale;
    local ox, oy = screen_xy();
    local dl = imgui.GetWindowDrawList();

    for i = 0, 7 do
        local value = tonumber(safe_call(player, 'GetResist', i)) or 0;
        local col = i % columns;
        local row = math.floor(i / columns);
        local x = ox + col * (tile_w + gap);
        local y = oy + row * (tile_h + gap);

        tile_rect(x, y, tile_w, tile_h, TILE_BG);
        if dl ~= nil then
            dl:AddRectFilled({ x, y }, { x + tile_w, y + strip }, imgui.GetColorU32(ELEMENT_COLORS[i + 1]), 2.0);
        end

        local name = RESIST_NAMES[i + 1];
        text_at(x + (tile_w - text_width(name)) / 2, y + strip + 3 * scale, state.muted_color, name);

        local value_text = tostring(value);
        local color = with_alpha(state.muted_color, 0.55);
        if value > 0 then
            color = state.good_color;
        elseif value < 0 then
            color = state.bad_color;
        end
        text_at(x + (tile_w - text_width(value_text)) / 2, y + strip + 3 * scale + lh + 1 * scale, color, value_text);
    end

    local rows = math.ceil(8 / columns);
    end_tile_block(ox, oy, rows * (tile_h + gap) - gap);
end

-- Rounded chip made of colored text segments: { { text, color }, ... }.
function draw_segment_chip(segments)
    local scale = state.overall_scale[1];
    local pad_x = 9 * scale;
    local pad_y = 2 * scale;
    local space = 5 * scale;
    local lh = line_height();

    local w = pad_x * 2;
    for i, seg in ipairs(segments) do
        w = w + text_width(seg[1]);
        if i > 1 then w = w + space; end
    end
    local h = lh + pad_y * 2;

    local x, y = screen_xy();
    local dl = imgui.GetWindowDrawList();
    if dl ~= nil then
        dl:AddRectFilled({ x, y }, { x + w, y + h }, imgui.GetColorU32({ 1.0, 1.0, 1.0, 0.05 }), h / 2);
    end

    local cx = x + pad_x;
    for i, seg in ipairs(segments) do
        if i > 1 then cx = cx + space; end
        text_at(cx, y + pad_y, seg[2], seg[1]);
        cx = cx + text_width(seg[1]);
    end

    imgui.SetCursorScreenPos({ x, y });
    imgui.Dummy({ w, h });
    return w;
end

function draw_haste_row(gear, effects)
    local scale = state.overall_scale[1];
    local haste = tonumber(gear and gear.haste) or 0;

    local gear_w = draw_segment_chip({
        { 'Gear', state.muted_color },
        { format_metric(haste, 25, '%'), (haste > 0) and state.good_color or UI_BRIGHT },
    });

    local segments = { { 'Active', state.muted_color } };
    if effects == nil or #effects == 0 then
        segments[#segments + 1] = { 'none', with_alpha(state.muted_color, 0.7) };
    else
        for index, effect in ipairs(effects) do
            local color = (effect.id == 13) and state.bad_color or state.good_color;
            segments[#segments + 1] = { effect.name .. ((index < #effects) and ',' or ''), color };
        end
    end

    imgui.SameLine(0, 6 * scale);
    local active_w = draw_segment_chip(segments);
    require_width(gear_w + 6 * scale + math.min(active_w, 220 * scale));
end

function draw_jobs(player, main_job, sub_job)
    local scale = state.overall_scale[1];
    local avail = avail_width();
    local gap_x = 5 * scale;
    local gap_y = 8 * scale;
    local pad = 7 * scale;
    local lh = line_height();
    local _, lh_big = big_text_size('75');
    local bar_h = 3 * scale;

    local level_w = big_text_size('75');
    local need = text_width('WAR') + level_w + pad * 2 + 12 * scale;
    require_width(need * 3 + gap_x * 2);
    local columns = fit_columns(6, need, gap_x, avail, 3);
    local tile_w = (avail - gap_x * (columns - 1)) / columns;
    local tile_h = lh_big + bar_h + 12 * scale;
    local ox, oy = screen_xy();
    local dl = imgui.GetWindowDrawList();
    local hovered_text = nil;

    -- Room above the first row for a MAIN / SUB tag.
    imgui.PushFont(nil, imgui.GetFontSize() * 0.72);
    local tag_lh = line_height();
    local main_tag_w = text_width('MAIN');
    local sub_tag_w = text_width('SUB');
    imgui.PopFont();
    local tag_h = tag_lh + 2 * scale;
    oy = oy + tag_h / 2;

    for id = 1, 18 do
        local level = tonumber(safe_call(player, 'GetJobLevel', id)) or 0;
        local label = skilldata.jobs[id] or ('J' .. tostring(id));
        local locked = level <= 0;
        local capped = level >= 75;
        local is_main = (id == main_job);
        local is_sub = (id == sub_job) and not is_main;

        local col = (id - 1) % columns;
        local row = math.floor((id - 1) / columns);
        local x = ox + col * (tile_w + gap_x);
        local y = oy + row * (tile_h + gap_y);

        -- Hover target first; the text drawn after it does not block hover.
        imgui.SetCursorScreenPos({ x, y });
        imgui.InvisibleButton('##cs_job_' .. tostring(id), { tile_w, tile_h });
        if imgui.IsItemHovered() then
            if locked then
                hovered_text = ('%s - not unlocked'):fmt(label);
            elseif capped then
                hovered_text = ('%s %d - level cap reached'):fmt(label, level);
            else
                hovered_text = ('%s %d / 75 - %d levels to go'):fmt(label, level, 75 - level);
            end
        end

        local bg = locked and TILE_BG_LOCKED or TILE_BG;
        local border = nil;
        if is_main then
            bg = ui_accent(0.22);
            border = UI_ACCENT;
        elseif is_sub then
            border = ui_accent(0.55);
        end
        tile_rect(x, y, tile_w, tile_h, bg, border);

        local label_color = locked and with_alpha(state.muted_color, 0.40) or state.muted_color;
        local level_text = locked and '--' or tostring(level);
        local level_color = UI_BRIGHT;
        if locked then
            level_color = with_alpha(state.muted_color, 0.40);
        elseif capped or is_main then
            level_color = UI_ACCENT_TEXT;
        end

        local text_y = y + 4 * scale;
        text_at(x + pad, text_y + (lh_big - lh) / 2, label_color, label);
        local lw = big_text_size(level_text);
        big_text_at(x + tile_w - pad - lw, text_y, level_color, level_text);

        -- Thin progress bar toward 75.
        if dl ~= nil then
            local by = y + tile_h - bar_h - 4 * scale;
            local bx0 = x + pad;
            local bx1 = x + tile_w - pad;
            dl:AddRectFilled({ bx0, by }, { bx1, by + bar_h }, imgui.GetColorU32(TRACK_COLOR), bar_h / 2);
            if not locked then
                local frac = math.min(1, level / 75);
                local fill = capped and UI_ACCENT or ui_accent(0.70);
                dl:AddRectFilled({ bx0, by }, { bx0 + math.max(bar_h, (bx1 - bx0) * frac), by + bar_h },
                    imgui.GetColorU32(fill), bar_h / 2);
            end
        end

        -- MAIN / SUB tag centered on the tile's top edge.
        if (is_main or is_sub) and dl ~= nil then
            local tag = is_main and 'MAIN' or 'SUB';
            local tw = is_main and main_tag_w or sub_tag_w;
            local tag_w = tw + 8 * scale;
            local tx = x + (tile_w - tag_w) / 2;
            local ty = y - tag_h / 2;
            local tag_bg = is_main and UI_ACCENT or { UI_TITLE_ACTIVE[1], UI_TITLE_ACTIVE[2], UI_TITLE_ACTIVE[3], 1.0 };
            dl:AddRectFilled({ tx, ty }, { tx + tag_w, ty + tag_h }, imgui.GetColorU32(tag_bg), 3.0);
            if not is_main then
                dl:AddRect({ tx, ty }, { tx + tag_w, ty + tag_h }, imgui.GetColorU32(ui_accent(0.55)), 3.0);
            end
            imgui.PushFont(nil, imgui.GetFontSize() * 0.72);
            text_at(tx + 4 * scale, ty + 1 * scale, is_main and { 0.04, 0.04, 0.05, 1.0 } or UI_ACCENT_TEXT, tag);
            imgui.PopFont();
        end
    end

    local rows = math.ceil(18 / columns);
    end_tile_block(ox, oy, rows * (tile_h + gap_y) - gap_y);

    if hovered_text ~= nil then
        imgui.SetTooltip(hovered_text);
    end
end

-- "16 of 18 unlocked - 7 at 75" for the Jobs header.
function jobs_note(player)
    local unlocked, capped = 0, 0;
    for id = 1, 18 do
        local level = tonumber(safe_call(player, 'GetJobLevel', id)) or 0;
        if level > 0 then unlocked = unlocked + 1; end
        if level >= 75 then capped = capped + 1; end
    end
    return ('%d of 18 unlocked - %d at 75'):fmt(unlocked, capped);
end

-- ============================================================================
-- Equipped items: the 16 slots in the in-game layout (used by the Overview
-- equipment strip; hover a slot for the item's full description).
-- ============================================================================

EQUIP_LAYOUT = {
    { 0, 'Main' },  { 1, 'Sub' },    { 2, 'Range' },   { 3, 'Ammo' },
    { 4, 'Head' },  { 9, 'Neck' },   { 11, 'Ear 1' },  { 12, 'Ear 2' },
    { 5, 'Body' },  { 6, 'Hands' },  { 13, 'Ring 1' }, { 14, 'Ring 2' },
    { 15, 'Back' }, { 10, 'Waist' }, { 7, 'Legs' },    { 8, 'Feet' },
};

-- Item name from the resource (Name is a cdata char* array like
-- Description). Picks the first readable (ASCII) entry.
function resource_name(resource)
    if resource == nil then return nil; end
    local ok_n, names = pcall(function() return resource.Name; end);
    if not ok_n or names == nil then return nil; end
    for _, i in ipairs({ 1, 0, 2 }) do
        local ok, v = pcall(function()
            local ptr = names[i];
            if ptr == nil then return ''; end
            return ffi.string(ptr);
        end);
        if ok and type(v) == 'string' and v ~= '' and v:match('^[%w%s%p]+$') then
            return v;
        end
    end
    return nil;
end

function read_equipment()
    local list = {};
    local inv = get_inventory();
    local rm = AshitaCore:GetResourceManager();

    for _, slot in ipairs(EQUIP_LAYOUT) do
        local entry = { slot = slot[1], label = slot[2] };
        if inv ~= nil and rm ~= nil then
            local eitem = safe_call(inv, 'GetEquippedItem', slot[1]);
            if eitem ~= nil and tonumber(eitem.Index) ~= nil and tonumber(eitem.Index) ~= 0 then
                local idx = tonumber(eitem.Index);
                local bag = math.floor(bit.band(idx, 0xFF00) / 0x0100);
                local pos = idx % 0x0100;
                local iitem = safe_call(inv, 'GetContainerItem', bag, pos);
                local id = iitem and tonumber(iitem.Id) or nil;
                if id ~= nil and id > 0 and id ~= 65535 then
                    local resource = rm:GetItemById(id);
                    entry.id = id;
                    entry.name = resource_name(resource) or ('Item ' .. tostring(id));
                    entry.description = item_description(resource);
                end
            end
        end
        list[#list + 1] = entry;
    end
    return list;
end

-- Re-read only when the equipped-item signature changes (checked twice a
-- second), same as the gear stat cache.
function cached_equipment()
    local now = os.clock();
    if state.equip_list == nil or (now - (tonumber(state.equip_checked) or -1)) >= 0.5 then
        state.equip_checked = now;
        local signature = equipped_signature();
        if state.equip_list == nil or signature ~= state.equip_signature then
            state.equip_list = read_equipment();
            state.equip_signature = signature;
        end
    end
    return state.equip_list;
end

-- ============================================================================
-- Overview equipment strip (1.4.0): EquipMon-style item icons, two rows of
-- eight (four per row when the window is narrow). Hover a slot for the same
-- item description.
-- ============================================================================

d3d8dev = nil;
pcall(function() d3d8dev = d3d.get_device(); end);

-- item id -> { tex = texture, id = imgui texture id }, or false if it failed.
icon_cache = {};

function item_icon(item_id)
    item_id = tonumber(item_id) or 0;
    if item_id <= 0 or item_id == 65535 or d3d8dev == nil then return nil; end

    local cached = icon_cache[item_id];
    if cached ~= nil then
        return cached or nil;
    end

    local entry = false;
    pcall(function()
        local resource = AshitaCore:GetResourceManager():GetItemById(item_id);
        if resource == nil or resource.Bitmap == nil or (tonumber(resource.ImageSize) or 0) <= 0 then
            return;
        end

        local texture_ptr = ffi.new('IDirect3DTexture8*[1]');
        local C = ffi.C;
        if C.D3DXCreateTextureFromFileInMemoryEx(d3d8dev, resource.Bitmap, resource.ImageSize,
            0xFFFFFFFF, 0xFFFFFFFF, 1, 0, C.D3DFMT_A8R8G8B8, C.D3DPOOL_MANAGED,
            C.D3DX_DEFAULT, C.D3DX_DEFAULT, 0xFF000000, nil, nil, texture_ptr) ~= C.S_OK then
            return;
        end

        local texture = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', texture_ptr[0]));
        entry = { tex = texture, id = tonumber(ffi.cast('uint32_t', texture)) };
    end);

    icon_cache[item_id] = entry;
    return entry or nil;
end

-- Drops icons for items that are no longer equipped.
function prune_icons(list)
    local keep = {};
    for _, entry in ipairs(list or {}) do
        if entry.id ~= nil then keep[entry.id] = true; end
    end
    if equip_panel ~= nil and equip_panel.open[1] then
        for _, it in ipairs(state.equip_scan or {}) do keep[it.id] = true; end
    end
    for id in pairs(icon_cache) do
        if not keep[id] then
            icon_cache[id] = nil;
        end
    end
end

EQUIP_SHORT = {
    [0] = 'Main', [1] = 'Sub', [2] = 'Rng', [3] = 'Ammo',
    [4] = 'Head', [5] = 'Body', [6] = 'Hand', [7] = 'Legs', [8] = 'Feet',
    [9] = 'Neck', [10] = 'Wst', [11] = 'Ear', [12] = 'Ear',
    [13] = 'Ring', [14] = 'Ring', [15] = 'Back',
};

function draw_item_tooltip(entry)
    local scale = state.overall_scale[1];
    imgui.BeginTooltip();
    imgui.PushTextWrapPos(420 * scale);
    if entry.name ~= nil then
        imgui.TextColored(UI_ACCENT_TEXT, entry.name);
        imgui.TextColored(state.muted_color, entry.label);
        if entry.description ~= nil and entry.description ~= '' then
            imgui.Spacing();
            imgui.TextUnformatted(entry.description);
        end
    else
        imgui.TextColored(state.muted_color, entry.label .. ' - empty');
    end
    imgui.PopTextWrapPos();
    imgui.EndTooltip();
end

function draw_equipment_strip()
    local scale = state.overall_scale[1];
    local list = cached_equipment();

    if list ~= state.icon_list then
        prune_icons(list);
        state.icon_list = list;
    end

    local icon = 32 * scale;
    local frame = icon + 4 * scale;
    local gap = 4 * scale;
    local avail = avail_width();

    require_width(frame * 4 + gap * 3);
    local columns = (avail >= frame * 8 + gap * 7) and 8 or 4;

    local ox, oy = screen_xy();
    local dl = imgui.GetWindowDrawList();
    local lh = line_height();
    local hovered = nil;

    for i, entry in ipairs(list) do
        local col = (i - 1) % columns;
        local row = math.floor((i - 1) / columns);
        local x = ox + col * (frame + gap);
        local y = oy + row * (frame + gap);

        imgui.SetCursorScreenPos({ x, y });
        imgui.InvisibleButton('##cs_eq_slot_' .. tostring(i), { frame, frame });
        local is_hovered = imgui.IsItemHovered();
        if is_hovered then hovered = entry; end
        if is_hovered and imgui.IsMouseDoubleClicked(0) then open_equip_panel(entry.slot); end
        if is_hovered and imgui.IsMouseClicked(1) then
            state.slot_ctx = entry;
            imgui.OpenPopup('##cs_eq_slot_ctx');
        end
        local is_open = equip_panel.open[1] and equip_panel.slot == entry.slot;

        if dl ~= nil then
            dl:AddRectFilled({ x, y }, { x + frame, y + frame }, imgui.GetColorU32({ 0.06, 0.06, 0.07, 1.0 }), 4.0);
            local edge = (is_hovered or is_open) and UI_ACCENT or { UI_BORDER[1], UI_BORDER[2], UI_BORDER[3], 0.85 };
            dl:AddRect({ x, y }, { x + frame, y + frame }, imgui.GetColorU32(edge), 4.0);
        end

        local tex = (entry.id ~= nil) and item_icon(entry.id) or nil;
        if tex ~= nil and tex.id ~= nil then
            imgui.SetCursorScreenPos({ x + 2 * scale, y + 2 * scale });
            imgui.Image(tex.id, { icon, icon });
        else
            local short = (entry.id ~= nil) and '?' or (EQUIP_SHORT[entry.slot] or '');
            local tw = text_width(short);
            if tw <= frame - 2 then
                text_at(x + (frame - tw) / 2, y + (frame - lh) / 2, with_alpha(state.muted_color, 0.45), short);
            end
        end
    end

    local rows = math.ceil(#list / columns);
    end_tile_block(ox, oy, rows * (frame + gap) - gap);

    if hovered ~= nil and not imgui.IsPopupOpen('##cs_eq_slot_ctx') then
        draw_item_tooltip(hovered);
    end

    if imgui.BeginPopup('##cs_eq_slot_ctx') then
        local e = state.slot_ctx;
        if e ~= nil then
            imgui.TextColored(UI_ACCENT_TEXT, e.label .. (e.name and ('  -  ' .. e.name) or ''));
            imgui.Separator();
            if imgui.Selectable('Change...##cs_eq_change') then open_equip_panel(e.slot); end
            if e.id ~= nil and imgui.Selectable('Remove##cs_eq_remove') then
                AshitaCore:GetChatManager():QueueCommand(1, '/equip ' .. (SLOT_COMMAND[e.slot] or 'main'));
            end
        end
        imgui.EndPopup();
    end
end
