--[[
    MogSuite - modules/inventory/menus.lua

    Item tooltip, right-click menu and the drop dialog.
]]

-- ============================================================================
-- Tooltip and context menu
-- ============================================================================

function draw_tooltip(row)
    local info = row.info;
    imgui.BeginTooltip();
    imgui.PushTextWrapPos(math.floor(340 * (tonumber(config.font_scale) or 1.0)));
    imgui.TextColored(UI_ACCENT_TEXT, info.name);
    if info.rare or info.ex then
        imgui.SameLine();
        imgui.TextColored(UI_MUTED, (info.rare and '[Rare]' or '') .. (info.ex and '[Ex]' or ''));
    end
    if row.equipped ~= nil then
        imgui.TextColored(UI_ACCENT, ('Equipped (%s)'):fmt(SLOT_LABELS[row.equipped] or '?'));
        if row.mirror then
            imgui.TextColored(EQUIP_USE_BLUE, ('In %s; shown here because it can be used (right-click > Use).'):fmt(BAG_NAMES[row.bag] or 'another bag'));
        end
        if row.info.enchanted then
            local label = use_label(row);
            imgui.TextColored(UI_MUTED, label);
        end
    end
    if info.type == TYPE_WEAPON or info.type == TYPE_ARMOR then
        local slots = {};
        for _, s in ipairs(equip_slot_list(info)) do slots[#slots + 1] = SLOT_LABELS[s]; end
        if #slots > 0 then imgui.TextColored(UI_MUTED, '[' .. table.concat(slots, ' / ') .. ']'); end
    end
    if info.desc ~= nil and info.desc ~= '' then
        imgui.TextWrapped(info.desc);
    end
    if (info.level or 0) > 0 then
        imgui.TextColored(UI_MUTED, ('Lv %d  %s'):fmt(info.level, jobs_text(info.jobs)));
    end
    local wear_ok, why = can_wear(info);
    if not wear_ok then
        imgui.TextColored(UI_DANGER, why == 'level' and ("Your level is too low to equip this.") or "Your job can't equip this.");
    end
    if (info.stack or 1) > 1 then
        imgui.TextColored(UI_MUTED, ('Stack %d / %d'):fmt(row.count, info.stack));
    end
    if row.split ~= nil then
        imgui.TextColored(UI_ACCENT_TEXT, ('%d partial stacks in this bag (%d total) - could be merged'):fmt(row.split, row.split_total or 0));
    end
    if config.show_value ~= false then
        local text, col = value_line(row);
        imgui.TextColored(col, text);
        -- A full stack, owned or not (is buying one on the AH worth it?).
        local each = price_of(row.id);
        local stack = tonumber(info.stack) or 1;
        if each ~= nil and stack > 1 then
            imgui.TextColored(config.qty_color, ('Full stack (%d) sells for %s gil'):fmt(stack, fmt_gil(each * stack)));
        end
    end
    if config.show_ah ~= false then
        local ah = ah_of(row.id);
        if ah == 'none' then
            imgui.TextColored(UI_MUTED, 'Not sold on the Auction House');
        elseif ah ~= nil then
            imgui.TextColored(UI_MUTED, 'AH: ' .. ah);
        end
    end
    if is_favorite(row) then imgui.TextColored(UI_ACCENT_TEXT, 'Favorite'); end
    local where = BAG_NAMES[row.bag] or ('Bag ' .. tostring(row.bag));
    if row.source == 'alt' then
        where = tostring(row.char) .. ' - ' .. where;
    elseif row.source == 'snapshot' then
        local b = state.bags[row.bag];
        where = where .. ((b and b.snapshot) and (' (snapshot ' .. os.date('%Y-%m-%d %H:%M', b.snapshot) .. ')') or ' (snapshot)');
    end
    imgui.TextColored(UI_MUTED, where);
    imgui.PopTextWrapPos();
    imgui.EndTooltip();
end

function draw_context_menu()
    if not imgui.BeginPopup('##nai_item_ctx') then return; end
    local row = state.ctx;
    if row == nil then
        imgui.EndPopup();
        return;
    end

    imgui.TextColored(UI_ACCENT_TEXT, row.info.name);
    if row.count > 1 then
        imgui.SameLine();
        imgui.TextColored(UI_MUTED, ('x%d'):fmt(row.count));
    end
    imgui.Separator();

    local any = true;
    if row.source == 'alt' then
        imgui.TextDisabled(('%s - %s (view only)'):fmt(tostring(row.char), BAG_NAMES[row.bag] or '?'));
    elseif VIEW_ONLY_BAG[row.bag] then
        imgui.TextDisabled('Mog House storage (view only)');
    end
    if imgui.Selectable((is_favorite(row) and 'Remove from favorites' or 'Add to favorites') .. '##nai_fav') then
        config.favorites = config.favorites or T{};
        config.favorites[row.id] = (not is_favorite(row)) or nil;
        state.view_gen = state.view_gen + 1;
        mark_dirty();
    end
    if can_use(row) then
        any = true;
        local label, ready = use_label(row);
        if ready then
            if imgui.Selectable(label .. '##nai_use') then do_use(row); end
        else
            imgui.TextDisabled(label);
        end
    end
    if can_equip(row) then
        any = true;
        local slots = equip_slot_list(row.info);
        if #slots == 1 then
            if imgui.Selectable('Equip##nai_equip') then do_equip(row, slots[1]); end
        else
            for _, s in ipairs(slots) do
                if imgui.Selectable(('Equip to %s##nai_equip_%d'):fmt(SLOT_LABELS[s], s)) then do_equip(row, s); end
            end
        end
    elseif row.equipped ~= nil then
        any = true;
        imgui.TextDisabled(('Equipped (%s)'):fmt(SLOT_LABELS[row.equipped] or '?'));
    end
    if can_drop(row) then
        any = true;
        imgui.Separator();
        if is_favorite(row) then
            imgui.TextDisabled('Drop (remove from favorites first)');
        else
            imgui.PushStyleColor(ImGuiCol_Text, UI_DANGER);
            if imgui.Selectable('Drop...##nai_drop') then
                state.drop = { row = row, qty = { row.count }, armed_at = nil };
            end
            imgui.PopStyleColor(1);
        end
    end
    if not any then
        imgui.TextDisabled('No actions for this item here.');
    end
    imgui.EndPopup();
end

-- Drop dialog: quantity for stacks, second red click for Rare / Ex.
function draw_drop_dialog()
    local d = state.drop;
    if d == nil then return; end
    local row = d.row;

    local dsize = imgui.GetIO().DisplaySize;
    imgui.SetNextWindowPos({ (tonumber(dsize.x) or 1920) * 0.5 - 170, (tonumber(dsize.y) or 1080) * 0.4 }, { 0, 0 });
    push_theme({ UI_POPUP[1], UI_POPUP[2], UI_POPUP[3], 0.98 });
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoMove);
    if imgui.Begin('Drop Item##nai_drop_dialog', nil, flags) then
        imgui.PushFont(nil, imgui.GetFontSize() * (tonumber(config.font_scale) or 1.0));
        imgui.TextColored(UI_DANGER, 'DROP ITEM');
        imgui.Text(row.info.name);
        if row.info.rare or row.info.ex then
            imgui.SameLine();
            imgui.TextColored(UI_MUTED, (row.info.rare and '[Rare]' or '') .. (row.info.ex and '[Ex]' or ''));
        end
        if row.count > 1 then
            imgui.PushItemWidth(220);
            imgui.SliderInt('Quantity##nai_drop_qty', d.qty, 1, row.count, '%d', ImGuiSliderFlags_AlwaysClamp);
            imgui.PopItemWidth();
        end
        if row.info.rare or row.info.ex then
            imgui.TextColored(UI_MUTED, 'Rare / Ex items are gone for good once dropped.');
        end
        imgui.Spacing();

        local needs_second = row.info.rare or row.info.ex;
        local armed = d.armed_at ~= nil and (os.clock() - d.armed_at) < 3.0;
        imgui.PushStyleColor(ImGuiCol_Button, armed and { 0.72, 0.16, 0.16, 1.0 } or { 0.45, 0.12, 0.12, 1.0 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.80, 0.20, 0.20, 1.0 });
        imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.90, 0.24, 0.24, 1.0 });
        imgui.PushStyleColor(ImGuiCol_Text, UI_WHITE);
        local label = (needs_second and not armed) and 'Drop (click twice)' or (armed and 'Click again to drop' or 'Drop');
        local clicked = imgui.Button(label .. '##nai_drop_go');
        imgui.PopStyleColor(4);
        if clicked then
            if needs_second and not armed then
                d.armed_at = os.clock();
            else
                do_drop(row, d.qty[1]);
                state.drop = nil;
            end
        end
        imgui.SameLine();
        if imgui.Button('Cancel##nai_drop_cancel') then state.drop = nil; end
        imgui.PopFont();
    end
    imgui.End();
    pop_theme();
end
