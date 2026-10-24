--[[
    MogSuite - modules/inventory/window.lua

    The inventory window and its pop-outs (Shift+Click a tab), and the open key.
]]

function capture_geometry(geom)
    local x, y = imgui.GetWindowPos();
    local w, h = imgui.GetWindowSize();
    x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h);
    if x == nil or w == nil then return; end
    if math.abs(x - geom.x) >= 1 or math.abs(y - geom.y) >= 1 or math.abs(w - geom.w) >= 1 or math.abs(h - geom.h) >= 1 then
        geom.x, geom.y, geom.w, geom.h = x, y, w, h;
        mark_dirty();
    end
end

VIEW_LABELS = { list = 'List', grid = 'Grid', categories = 'Categories', usable = 'Usable', cleanup = 'Cleanup', upgrades = 'Upgrades' };
VIEW_ORDER = { 'list', 'grid', 'categories', 'usable', 'cleanup', 'upgrades' };
VIEW_TIPS = {
    list = 'Icon, name and quantity on each row',
    grid = 'An icon grid',
    categories = 'Weapons, Armor, Usable, ... sections',
    usable = 'Food, medicines, scrolls, ninja tools and ammo',
    cleanup = 'Suggestions: stacks to merge, items spread over bags, NPC-only sell items, outgrown gear',
    upgrades = 'Gear in your Inventory / Wardrobes better than what you wear',
};

-- Compact header (1.5.0): the bag menu groups.
BAG_GROUPS = {
    { label = 'Carried', bags = { 0, 5, 6, 7 } },
    { label = 'Wardrobes', bags = { 8, 10, 11, 12, 13, 14, 15, 16 } },
    { label = 'Mog House', bags = { 1, 9, 2, 4 } },
    { label = 'Other', bags = { -1, 3, -2, -3 } },
};
DEFAULT_PINNED = { -1, 0, 5, 6, 8, -3 };

function pinned_bags()
    if config.pinned_bags == nil then
        config.pinned_bags = T{};
        for _, b in ipairs(DEFAULT_PINNED) do config.pinned_bags[#config.pinned_bags + 1] = b; end
    end
    return config.pinned_bags;
end

function is_pinned(bag)
    for _, b in ipairs(pinned_bags()) do if b == bag then return true; end end
    return false;
end

function toggle_pin(bag)
    local list = pinned_bags();
    for i, b in ipairs(list) do
        if b == bag then table.remove(list, i); mark_dirty(); return; end
    end
    -- Keep the menu's order.
    list[#list + 1] = bag;
    local rank = {};
    local n = 0;
    for _, g in ipairs(BAG_GROUPS) do for _, b in ipairs(g.bags) do n = n + 1; rank[b] = n; end end
    rank[-1] = 0;
    table.sort(list, function(a, b) return (rank[a] or 99) < (rank[b] or 99); end);
    mark_dirty();
end

-- Bag exists for this character (and its tab is not hidden).
function bag_available(bag)
    if bag == -1 or bag == -3 then return true; end
    if bag == -2 then return next(chars) ~= nil; end
    for _, b in ipairs(state.bag_order) do if b == bag then return true; end end
    return false;
end

-- Click / Shift+Click on a bag (tab or menu entry).
function pick_bag(value)
    local shift = false;
    pcall(function() shift = imgui.GetIO().KeyShift == true; end);
    if shift or mod_down(0x10, state.mods.shift) then
        if find_popout(value) ~= nil then close_popout(value); else open_popout(value); end
    else
        V.bag = value;
        if value == -3 then state.key_items = nil; end
        mark_dirty();
    end
end

-- Tab colors: bags of the same kind share a color.
BAG_TAB_COLOR = {
    [-1] = 'ice', [0] = 'earth', [1] = 'water', [2] = 'water', [4] = 'water', [9] = 'water',
    [5] = 'wind', [6] = 'wind', [7] = 'wind', [3] = 'light', [-2] = 'light', [-3] = 'fire',
};
function bag_tab_color(bag)
    return COLORS[BAG_TAB_COLOR[bag] or 'thunder'];
end

-- Grey placeholder text inside an empty search box (last item).
function draw_search_hint(text)
    if imgui.GetItemRectMin == nil or imgui.IsItemActive() then return; end
    local x1, y1 = imgui.GetItemRectMin();
    x1, y1 = tonumber(x1), tonumber(y1);
    if x1 == nil then return; end
    local pad = (imgui.GetStyle ~= nil and imgui.GetStyle().FramePadding) or nil;
    local px = (pad and tonumber(pad.x)) or 7;
    local py = (pad and tonumber(pad.y)) or 3;
    imgui.GetWindowDrawList():AddText({ x1 + px, y1 + py }, imgui.GetColorU32({ UI_MUTED[1], UI_MUTED[2], UI_MUTED[3], 0.55 }), text);
end

function tab_label(bag)
    if bag == -1 then return 'All'; end
    if bag == -2 then return 'Characters'; end
    if bag == -3 then return 'Key Items'; end
    return BAG_NAMES[bag] or ('Bag ' .. tostring(bag));
end

-- Pop-out windows: config.popouts = list of { bag, view, sort, sort_desc,
-- filter, window }. One per tab. Runtime bits (search text, row cache,
-- geometry flag) live in state.pop_rt[bag].
function find_popout(bag)
    for i, p in ipairs(config.popouts or {}) do
        if p.bag == bag then return p, i; end
    end
    return nil, nil;
end

function pop_rt(bag)
    local rt = state.pop_rt[bag];
    if rt == nil then
        rt = { search = { '' }, cache = nil, key = nil, apply_geometry = true };
        state.pop_rt[bag] = rt;
    end
    return rt;
end

function open_popout(bag)
    config.popouts = config.popouts or T{};
    config.popout_saved = config.popout_saved or T{};
    if find_popout(bag) == nil then
        local saved = config.popout_saved[tostring(bag)];
        if saved ~= nil and saved.window ~= nil then
            -- Reopen where you left it, with the same size and view.
            table.insert(config.popouts, T{
                bag = bag,
                view = saved.view or config.view or 'list',
                sort = saved.sort or config.sort or 'slot',
                sort_desc = saved.sort_desc == true,
                filter = saved.filter or 'all',
                window = T{ x = tonumber(saved.window.x) or 300, y = tonumber(saved.window.y) or 200,
                            w = tonumber(saved.window.w) or 380, h = tonumber(saved.window.h) or 460 },
            });
        else
            local n = #config.popouts;
            table.insert(config.popouts, T{
                bag = bag,
                view = config.view or 'list',
                sort = config.sort or 'slot',
                sort_desc = config.sort_desc == true,
                filter = 'all',
                window = T{ x = config.window.x + config.window.w + 10 + n * 24, y = config.window.y + n * 24, w = 380, h = 460 },
            });
        end
    end
    local rt = pop_rt(bag);
    rt.apply_geometry = true;
    rt.focus = true;
    if bag == -3 then state.key_items = nil; end
    state.hidden = false;
    mark_dirty();
end

function close_popout(bag)
    local p, i = find_popout(bag);
    if p ~= nil then
        -- Remember its size, position and view for the next time it opens.
        config.popout_saved = config.popout_saved or T{};
        local w = p.window or {};
        config.popout_saved[tostring(bag)] = T{
            view = p.view, sort = p.sort, sort_desc = p.sort_desc == true, filter = p.filter,
            window = T{ x = tonumber(w.x) or 300, y = tonumber(w.y) or 200, w = tonumber(w.w) or 380, h = tonumber(w.h) or 460 },
        };
    end
    if i ~= nil then table.remove(config.popouts, i); end
    state.pop_rt[bag] = nil;
    mark_dirty();
end

-- Draws the main window (popout == nil) or one pop-out window. V is the
-- settings table for the window (config for main, the pop-out entry
-- otherwise); VS holds its runtime bits.
function draw_inventory_window(popout)
    local open_ref;
    if popout == nil then
        V, VS = config, state.main_rt;
        VS.geom = config.window;
        open_ref = state.visible;
    else
        V, VS = popout, pop_rt(popout.bag);
        popout.window = popout.window or T{ x = 300, y = 200, w = 380, h = 460 };
        VS.geom = popout.window;
        VS.open = VS.open or { true };
        VS.open[1] = true;
        open_ref = VS.open;
    end
    V.filter = V.filter or 'all';

    if VS.apply_geometry ~= false then
        imgui.SetNextWindowPos({ VS.geom.x, VS.geom.y }, { 0, 0 });
        imgui.SetNextWindowSize({ VS.geom.w, VS.geom.h });
        VS.apply_geometry = false;
    end
    if VS.focus and imgui.SetNextWindowFocus ~= nil then
        imgui.SetNextWindowFocus();
    end
    VS.focus = nil;
    if imgui.SetNextWindowSizeConstraints ~= nil then
        imgui.SetNextWindowSizeConstraints({ 260, 220 }, { 4000, 4000 });
    end

    push_theme();
    local flags = ImGuiWindowFlags_NoNav;
    if config.locked then flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoResize); end
    if not config.title_bar then flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar); end

    local title = (popout == nil) and 'MogSuite  -  Inventory##nai_main'
        or ('Inventory  -  %s##nai_pop_%s'):fmt(tab_label(popout.bag), tostring(popout.bag));
    if imgui.Begin(title, open_ref, flags) then
        local scale = tonumber(config.font_scale) or 1.0;
        imgui.PushFont(MS_FONT(), MS_FONT_SIZE() * scale);
        local frame_h = imgui.GetFrameHeight();

        if popout == nil then
            -- Header: bag tabs, then Characters and Key Items.
            -- Shift+Click a tab opens it in its own window.
            if V.bag == -2 and next(chars) == nil then V.bag = -1; end
            if state.bag_order[1] ~= nil and V.bag >= 0 and state.bags[V.bag] == nil then
                V.bag = state.bag_order[1];
            end
            imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 9, 4 });
            local avail = tonumber((imgui.GetContentRegionAvail())) or 400;
            local line_x = 0;
            local tab_idx = 0;
            local function tab(value)
                local label = tab_label(value);
                tab_idx = tab_idx + 1;
                local w = text_w(label) + 18;
                if tab_idx > 1 then
                    if line_x + 4 + w <= avail then imgui.SameLine(0, 4); line_x = line_x + 4;
                    else line_x = 0; end
                end
                if color_tab(label, 'nai_bag_' .. tostring(value), V.bag == value, bag_tab_color(value)) then
                    -- Shift+Click again closes that tab's window.
                    pick_bag(value);
                end
                local popped = find_popout(value) ~= nil;
                if popped and imgui.GetItemRectMin ~= nil then
                    -- Small "own window" mark in the tab's top-right corner.
                    local x1, y1 = imgui.GetItemRectMin();
                    local x2 = imgui.GetItemRectMax();
                    local dl = imgui.GetWindowDrawList();
                    local s = 5;
                    local bx, by = x2 - s - 4, y1 + 3;
                    dl:AddRect({ bx - 2, by + 2 }, { bx + s - 2, by + s + 2 }, imgui.GetColorU32(accent(0.55)), 1.0, 0, 1.0);
                    dl:AddRectFilled({ bx, by }, { bx + s, by + s }, imgui.GetColorU32(accent(0.95)), 1.0);
                end
                if imgui.IsItemHovered() then
                    imgui.SetTooltip(not popped and 'Shift+Click to open in its own window'
                        or 'Open in its own window  -  Shift+Click to close it');
                end
                line_x = line_x + w;
            end
            if config.compact_header == false then
                tab(-1);
                for _, bag in ipairs(state.bag_order) do tab(bag); end
                if next(chars) ~= nil then tab(-2); end
                tab(-3);
            else
                -- Pinned bags, the open bag if it is not pinned, then Bags v.
                for _, bag in ipairs(pinned_bags()) do
                    if bag_available(bag) then tab(bag); end
                end
                if not is_pinned(V.bag) then tab(V.bag); end
                local more = 'Bags v';
                local mw = text_w(more) + 18;
                if line_x + 8 + mw <= avail then imgui.SameLine(0, 8); end
                if imgui.Button(more .. '##nai_bags_menu') then imgui.OpenPopup('##nai_bags_pop'); end
                if imgui.IsItemHovered() then imgui.SetTooltip('Every bag. Pin the ones you use for a quick tab.'); end
                if imgui.BeginPopup('##nai_bags_pop') then
                    local sel_w = text_w('Wardrobe 8  80/80  (own window)') + 12;
                    for gi, g in ipairs(BAG_GROUPS) do
                        local shown = {};
                        for _, b in ipairs(g.bags) do if bag_available(b) then shown[#shown + 1] = b; end end
                        if #shown > 0 then
                            if gi > 1 then imgui.Spacing(); end
                            imgui.TextColored(UI_ACCENT_TEXT, g.label);
                            imgui.Separator();
                            for _, b in ipairs(shown) do
                                local label = tab_label(b);
                                local bb = state.bags[b];
                                if bb ~= nil then label = ('%s  %d/%d'):fmt(label, bb.used, bb.max); end
                                if find_popout(b) ~= nil then label = label .. '  (own window)'; end
                                local col = bag_tab_color(b);
                                imgui.PushStyleColor(ImGuiCol_Text, (V.bag == b) and col or UI_TEXT);
                                if imgui.Selectable(label .. '##nai_bm_' .. tostring(b), V.bag == b, 0, { sel_w, 0 }) then
                                    pick_bag(b);
                                end
                                imgui.PopStyleColor(1);
                                if imgui.IsItemHovered() then imgui.SetTooltip('Click to show it  -  Shift+Click for its own window'); end
                                imgui.SameLine(sel_w + 16);
                                if imgui.SmallButton((is_pinned(b) and 'Unpin' or 'Pin') .. '##nai_pin_' .. tostring(b)) then toggle_pin(b); end
                                if imgui.IsItemHovered() then imgui.SetTooltip(is_pinned(b) and 'Remove its quick tab' or 'Add a quick tab for it'); end
                            end
                        end
                    end
                    imgui.EndPopup();
                end
            end
            imgui.PopStyleVar(1);
        elseif not config.title_bar then
            -- Pop-out header: its tab name (no title bar to show it).
            imgui.AlignTextToFramePadding();
            imgui.TextColored(UI_ACCENT_TEXT, tab_label(V.bag));
        end

        local key_items = V.bag == -3;

        -- Toolbar: search, sort, view, log, config, close.
        local sort_w = key_items and 0 or (text_w('Newest v') + 34);
        local view_w = key_items and 0 or (text_w('Categories') + 34);
        local log_w = (popout == nil) and (text_w('Log') + 16) or 0;
        local cfg_w = (popout == nil) and (text_w('Config') + 16) or 0;
        local compact = config.compact_header ~= false;
        local filter_label = 'Filter';
        if compact then
            if key_items then
                local kf = state.ki_filter or 'all';
                if kf ~= 'all' then filter_label = 'Filter: ' .. ({ permanent = 'Permanent', temporary = 'Temporary', other = 'Maps & Other' })[kf]; end
            elseif V.filter ~= 'all' then
                for _, f in ipairs(FILTERS) do if f.key == V.filter then filter_label = 'Filter: ' .. f.label; end end
            end
            filter_label = filter_label .. ' v';
        end
        local filter_w = compact and (text_w(filter_label) + 18) or 0;
        local close_w = config.title_bar and 0 or (frame_h + 6);
        local row_w = tonumber((imgui.GetContentRegionAvail())) or 400;
        imgui.PushItemWidth(math.max(80, row_w - sort_w - view_w - filter_w - log_w - cfg_w - close_w - 48));
        imgui.InputText('##nai_search', VS.search, 64);
        if (VS.search[1] or '') == '' then draw_search_hint(key_items and 'Search key items' or 'Search items'); end
        imgui.PopItemWidth();
        if imgui.IsItemHovered() and not imgui.IsItemActive() then
            imgui.SetTooltip(key_items and 'Search key items' or 'Search item names');
        end

        if not key_items then
            imgui.SameLine();
            imgui.PushItemWidth(sort_w);
            local sort_labels = { slot = 'Slot', name = 'Name', type = 'Type', qty = 'Qty', newest = 'Newest' };
            if imgui.BeginCombo('##nai_sort', (sort_labels[V.sort] or 'Slot') .. (V.sort_desc and ' v' or ' ^')) then
                for _, k in ipairs({ 'slot', 'name', 'type', 'qty', 'newest' }) do
                    if imgui.Selectable(sort_labels[k], V.sort == k) then
                        if V.sort == k then V.sort_desc = not V.sort_desc; else V.sort = k; V.sort_desc = false; end
                        mark_dirty();
                    end
                end
                imgui.EndCombo();
            end
            imgui.PopItemWidth();
            if imgui.IsItemHovered() then imgui.SetTooltip('Sort (pick the same one again to reverse)'); end

            imgui.SameLine();
            imgui.PushItemWidth(view_w);
            if imgui.BeginCombo('##nai_view', VIEW_LABELS[V.view] or 'List') then
                for _, k in ipairs(VIEW_ORDER) do
                    if imgui.Selectable(VIEW_LABELS[k], V.view == k) then
                        V.view = k;
                        mark_dirty();
                    end
                end
                imgui.EndCombo();
            end
            imgui.PopItemWidth();
            if imgui.IsItemHovered() then imgui.SetTooltip(VIEW_TIPS[V.view] or 'How items are shown'); end
        end

        if compact then
            imgui.SameLine();
            local active = (key_items and (state.ki_filter or 'all') ~= 'all') or ((not key_items) and V.filter ~= 'all');
            if active then imgui.PushStyleColor(ImGuiCol_Text, UI_ACCENT_TEXT); end
            if imgui.Button(filter_label .. '##nai_filter_btn') then imgui.OpenPopup('##nai_filter_pop'); end
            if active then imgui.PopStyleColor(1); end
            if imgui.IsItemHovered() then imgui.SetTooltip('Show only some items'); end
            if imgui.BeginPopup('##nai_filter_pop') then
                local list = key_items and {
                    { key = 'all', label = 'All' }, { key = 'permanent', label = 'Permanent' },
                    { key = 'temporary', label = 'Temporary' }, { key = 'other', label = 'Maps & Other' },
                } or FILTERS;
                for _, f in ipairs(list) do
                    local cur = key_items and (state.ki_filter or 'all') or V.filter;
                    if imgui.Selectable(f.label .. '##nai_fp_' .. f.key, cur == f.key) then
                        if key_items then state.ki_filter = f.key; else V.filter = f.key; mark_dirty(); end
                    end
                end
                imgui.EndPopup();
            end
        end

        if popout == nil then
            imgui.SameLine();
            if imgui.Button('Log##nai_logbtn') then state.log_visible[1] = not state.log_visible[1]; end
            if imgui.IsItemHovered() then imgui.SetTooltip('Session loot log and gil'); end
            imgui.SameLine();
            if imgui.Button('Config##nai_cfg') then MS.open_config('inventory'); end
            tip('Inventory settings');
        end
        if not config.title_bar then
            imgui.SameLine();
            if imgui.Button('X##nai_close', { frame_h, frame_h }) then open_ref[1] = false; end
            tip((popout == nil) and 'Close the inventory' or 'Close this window');
        end

        -- Key item chips: All / Permanent / Temporary / Maps & Other.
        if key_items and not compact then
            local KF = {
                { key = 'all', label = 'All' },
                { key = 'permanent', label = 'Permanent' },
                { key = 'temporary', label = 'Temporary' },
                { key = 'other', label = 'Maps & Other' },
            };
            local cw = tonumber((imgui.GetContentRegionAvail())) or 400;
            local cx = 0;
            for i, f in ipairs(KF) do
                local w = text_w(f.label) + 18;
                if i > 1 then
                    if cx + 4 + w <= cw then imgui.SameLine(0, 4); cx = cx + 4; else cx = 0; end
                end
                if chip(f.label, 'nai_kf_' .. f.key, (state.ki_filter or 'all') == f.key) then
                    state.ki_filter = f.key;
                end
                cx = cx + w;
            end
        end

        -- Filter chips.
        if not key_items and not compact then
            local cw = tonumber((imgui.GetContentRegionAvail())) or 400;
            local cx = 0;
            for i, f in ipairs(FILTERS) do
                local w = text_w(f.label) + 18;
                if i > 1 then
                    if cx + 4 + w <= cw then imgui.SameLine(0, 4); cx = cx + 4; else cx = 0; end
                end
                if chip(f.label, 'nai_f_' .. f.key, V.filter == f.key) then
                    V.filter = f.key;
                    mark_dirty();
                end
                cx = cx + w;
            end
        end

        -- Footer reserved at the bottom.
        local footer_h = imgui.GetTextLineHeightWithSpacing() + 6;
        local _, avail_h = imgui.GetContentRegionAvail();
        avail_h = math.max(60, (tonumber(avail_h) or 300) - footer_h);

        local rows = key_items and {} or get_view_rows();
        local show_bag = V.bag == -1 or V.bag == -2;
        local ki_shown = 0;
        begin_child('##nai_items', { 0, avail_h }, 0);
        if key_items then
            ki_shown = draw_key_items_view();
        elseif V.view == 'cleanup' then
            draw_cleanup_view();
        elseif V.view == 'upgrades' then
            draw_upgrades_view();
        elseif #rows == 0 then
            local msg = 'Nothing here.';
            if next(state.bags) == nil then msg = 'Waiting for inventory...'; end
            if V.bag == -2 and next(chars) == nil then msg = 'No characters saved yet.'; end
            imgui.TextDisabled(msg);
        elseif V.view == 'categories' then
            draw_categories_view(rows, show_bag);
        elseif V.view == 'usable' then
            draw_usable_view(rows, show_bag);
        elseif V.view == 'grid' then
            draw_grid_view(rows);
        else
            draw_list_view(rows, show_bag);
        end
        draw_context_menu();
        imgui.EndChild();

        -- Footer: slots / value on the left, gil (+ session change) on the right.
        imgui.Separator();
        if key_items then
            imgui.TextColored(UI_MUTED, ('%d key items'):fmt(#(state.key_items or {})));
            if ki_shown ~= #(state.key_items or {}) then
                imgui.SameLine(0, 6);
                imgui.TextDisabled(('(%d shown)'):fmt(ki_shown));
            end
        elseif V.bag == -2 then
            local n = 0;
            for _ in pairs(chars) do n = n + 1; end
            imgui.TextColored(UI_MUTED, ('%d character%s  -  view only'):fmt(n, n == 1 and '' or 's'));
        else
            local used, max = 0, 0;
            if V.bag == -1 then
                for _, bag in ipairs(state.bag_order) do
                    local b = state.bags[bag];
                    if b then used = used + b.used; max = max + b.max; end
                end
            elseif state.bags[V.bag] ~= nil then
                used, max = state.bags[V.bag].used, state.bags[V.bag].max;
            end
            local full = max > 0 and used >= max;
            imgui.TextColored(full and UI_DANGER or UI_MUTED, ('%d / %d'):fmt(used, max));
            imgui.SameLine(0, 6);
            imgui.TextColored(UI_MUTED, (V.bag == -1) and 'slots (all bags)' or 'slots');
            local b = state.bags[V.bag];
            if V.bag >= 0 and VIEW_ONLY_BAG[V.bag] then
                imgui.SameLine(0, 10);
                if b ~= nil and b.snapshot ~= nil then
                    imgui.TextDisabled('(snapshot)');
                    if imgui.IsItemHovered() then
                        imgui.SetTooltip(('Saved %s - visit your Mog House to refresh it.'):fmt(os.date('%Y-%m-%d %H:%M', b.snapshot)));
                    end
                else
                    imgui.TextDisabled('(view only)');
                end
            end
        end
        if not key_items and config.show_value ~= false and #rows > 0 then
            local total = rows_value(rows);
            if total > 0 then
                imgui.SameLine(0, 12);
                imgui.TextColored(UI_MUTED, 'Worth');
                imgui.SameLine(0, 4);
                imgui.TextColored(config.qty_color, fmt_gil(total));
                if imgui.IsItemHovered() then imgui.SetTooltip('Sell value of the items shown (known prices only)'); end
            end
        end

        -- Gil (and this session's change) only on the Inventory tab / window.
        if V.bag == 0 then
        local gil_label = 'Gil ';
        local gil_text = fmt_gil(state.gil);
        local delta = (state.session_gil ~= nil) and (state.gil - state.session_gil) or 0;
        local delta_text = (delta ~= 0) and ((delta > 0 and ' (+' or ' (-') .. fmt_gil(math.abs(delta)) .. ')') or '';
        imgui.SameLine();
        local gx = (tonumber((imgui.GetWindowContentRegionMax and imgui.GetWindowContentRegionMax())) or 0);
        if gx > 0 then
            imgui.SetCursorPosX(math.max(imgui.GetCursorPosX() + 10, gx - text_w(gil_label) - text_w(gil_text) - text_w(delta_text)));
        end
        imgui.TextColored(UI_MUTED, gil_label);
        imgui.SameLine(0, 0);
        imgui.TextColored(config.qty_color, gil_text);
        if delta_text ~= '' then
            imgui.SameLine(0, 0);
            imgui.TextColored(delta > 0 and { 0.45, 0.85, 0.45, 1.0 } or { 0.90, 0.45, 0.40, 1.0 }, delta_text);
            if imgui.IsItemHovered() then imgui.SetTooltip('Gil gained / spent this session'); end
        end
        end

        imgui.PopFont();
        if not config.locked then capture_geometry(VS.geom); end
    end
    imgui.End();
    pop_theme();
end

function draw_main_window()
    if state.hidden then return; end
    if state.visible[1] then
        draw_inventory_window(nil);
    else
        state.main_rt.apply_geometry = true;
    end

    -- Pop-outs (copy the list: closing one removes it while we loop).
    local list = {};
    for _, p in ipairs(config.popouts or {}) do list[#list + 1] = p; end
    for _, p in ipairs(list) do
        draw_inventory_window(p);
        local rt = state.pop_rt[p.bag];
        if rt ~= nil and rt.open ~= nil and rt.open[1] == false then close_popout(p.bag); end
    end

    draw_drop_dialog();
end

-- Open key and /nai: hide everything that's showing, or show the main
-- window plus every pop-out you didn't close with X.
function toggle_all()
    local showing = (not state.hidden) and (state.visible[1] or #(config.popouts or {}) > 0);
    if showing then
        state.hidden = true;
    else
        state.hidden = false;
        state.visible[1] = true;
        state.main_rt.apply_geometry = true;
        for bag, rt in pairs(state.pop_rt) do rt.apply_geometry = true; end
        state.rows_dirty = true;
    end
    mark_dirty();
end
