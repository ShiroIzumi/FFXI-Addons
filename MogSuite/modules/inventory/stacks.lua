--[[
    MogSuite - modules/inventory/stacks.lua (1.5.3)

    The Stacks window (the Stacks button on the inventory window): items
    that could be stacked together, across every bag of every character
    MogSuite has seen.

    For each item it lists where the copies are, which spot to keep them in
    (the one with the most), and what to move there. Full stacks stay where
    they are; only the partial ones move. Ex and Rare items can't go to
    another character, so they are only combined within one character.

    Suggestions only: nothing is moved for you. Other characters' bags are
    the last time MogSuite saw them (log in on them to refresh); Mog House
    storage is the last time you were in your Mog House.
]]

stacks = {
    open = { false },
    placed = false,
    search = { '' },
};

local function stack_of(info) return math.max(1, tonumber(info and info.stack) or 1); end

local function ceil_div(a, b) return math.floor((a + b - 1) / b); end

local function loc_label(l, me)
    local bag = BAG_NAMES[l.bag] or ('Bag ' .. tostring(l.bag));
    if l.char == me then return bag; end
    return tostring(l.char) .. '  ' .. bag;
end

-- Every stackable item, where it is, and the moves that save slots.
function stacks_collect()
    local me = state.player_name or get_player_name() or '?';
    local scope = config.stacks_scope or 'all';
    local by_id = {};
    local function add(char, bag, id, count)
        local info = get_item_info(id);
        if info == nil or count <= 0 then return; end
        local st = stack_of(info);
        if st <= 1 then return; end
        local e = by_id[id];
        if e == nil then
            e = { id = id, info = info, stack = st, locs = {}, total = 0, slots = 0 };
            by_id[id] = e;
        end
        local key = tostring(char) .. ':' .. tostring(bag);
        local l = e.locs[key];
        if l == nil then
            l = { char = char, bag = bag, count = 0, slots = 0 };
            e.locs[key] = l;
        end
        l.count = l.count + count;
        l.slots = l.slots + 1;
        e.total = e.total + count;
        e.slots = e.slots + 1;
    end

    -- You: what your bags show now (Mog House storage from its last look).
    for bag, b in pairs(state.bags or {}) do
        for _, r in ipairs(b.rows or {}) do
            if not r.mirror then add(me, bag, r.id, tonumber(r.count) or 0); end
        end
    end
    -- Your other characters: their saved bags.
    if scope == 'all' then
        for name, rec in pairs(chars or {}) do
            if name ~= me and type(rec) == 'table' and type(rec.bags) == 'table' then
                for bag, list in pairs(rec.bags) do
                    for _, it in ipairs(list) do
                        add(name, tonumber(bag) or bag, tonumber(it[1]) or 0, tonumber(it[2]) or 0);
                    end
                end
            end
        end
    end

    local out = {};
    local q = tostring(stacks.search[1] or ''):lower();
    for _, e in pairs(by_id) do
        if q == '' or (e.info.name_lower or ''):find(q, 1, true) then
            local bound = (e.info.ex or e.info.rare) and true or false;
            e.bound = bound;
            -- Groups that can be combined: one per character for Ex / Rare,
            -- one for everyone otherwise.
            local groups = {};
            for _, l in pairs(e.locs) do
                local gk = bound and tostring(l.char) or '*';
                groups[gk] = groups[gk] or { locs = {}, total = 0, slots = 0 };
                local g = groups[gk];
                g.locs[#g.locs + 1] = l;
                g.total = g.total + l.count;
                g.slots = g.slots + l.slots;
            end
            local need, plans = 0, {};
            for _, g in pairs(groups) do
                need = need + ceil_div(g.total, e.stack);
                -- Keep spot: the most copies; yours first when it's a tie.
                table.sort(g.locs, function(a, b)
                    if a.count ~= b.count then return a.count > b.count; end
                    if (a.char == me) ~= (b.char == me) then return a.char == me; end
                    return (BAG_NAMES[a.bag] or '') < (BAG_NAMES[b.bag] or '');
                end);
                local keep = g.locs[1];
                for i, l in ipairs(g.locs) do
                    local p = { loc = l, keep = (i == 1) };
                    if i == 1 then
                        if l.slots > ceil_div(l.count, e.stack) then
                            p.note = ('%d partial stacks here: combine them (take them out and put them back)'):fmt(l.slots);
                        end
                    else
                        local partial = l.count % e.stack;
                        if l.slots > ceil_div(l.count, e.stack) then partial = l.count - math.floor(l.count / e.stack) * e.stack; end
                        if partial > 0 or l.slots > ceil_div(l.count, e.stack) then
                            p.move = (partial > 0) and partial or l.count;
                            p.to = keep;
                            p.cross = (l.char ~= keep.char);
                        end
                    end
                    plans[#plans + 1] = p;
                end
            end
            e.saves = e.slots - need;
            e.plans = plans;
            if e.saves > 0 or (config.stacks_show_spread == true and #plans > 1) then
                out[#out + 1] = e;
            end
        end
    end
    local sort = config.stacks_sort or 'saves';
    table.sort(out, function(a, b)
        if sort == 'saves' and a.saves ~= b.saves then return a.saves > b.saves; end
        return (a.info.name_lower or '') < (b.info.name_lower or '');
    end);
    return out, me;
end

local function draw_item_header(e, width)
    local scale = tonumber(config.font_scale) or 1.0;
    local icon = math.floor((tonumber(config.icon_size) or 24) * scale);
    local line_h = imgui.GetTextLineHeight();
    local row_h = math.max(icon, line_h) + 4;
    local dl = imgui.GetWindowDrawList();
    local sx, sy = imgui.GetCursorScreenPos();
    imgui.Dummy({ math.max(1, width), row_h });
    dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32(accent(0.10)), 3.0);
    local x = sx + 4;
    local tex = get_icon(e.info);
    local iy = sy + (row_h - icon) * 0.5;
    if tex ~= nil then
        dl:AddImage(tex.id, { x, iy }, { x + icon, iy + icon }, { 0, 0 }, { 1, 1 }, imgui.GetColorU32(UI_WHITE));
    else
        dl:AddRectFilled({ x, iy }, { x + icon, iy + icon }, imgui.GetColorU32(UI_CONTROL), 3.0);
    end
    x = x + icon + 8;
    local ty = sy + (row_h - line_h) * 0.5;
    draw_fx_text(dl, x, ty, config.name_color, e.info.name);
    x = x + text_w(e.info.name) + 6;
    local q = ('x%d'):fmt(e.total);
    draw_fx_text(dl, x, ty, config.qty_color, q);
    x = x + text_w(q) + 6;
    draw_fx_text(dl, x, ty, UI_MUTED, ('stacks of %d'):fmt(e.stack));
    local right = sx + width - 6;
    local saves = (e.saves > 0) and (('saves %d slot%s'):fmt(e.saves, e.saves == 1 and '' or 's')) or 'no slot saved';
    local sw = text_w(saves);
    draw_fx_text(dl, right - sw, ty, (e.saves > 0) and UI_ACCENT_TEXT or UI_MUTED, saves);
    right = right - sw - 10;
    if e.info.ex then
        local w = text_w('Ex');
        draw_fx_text(dl, right - w, ty, { 0.55, 0.75, 1.0, 1.0 }, 'Ex');
        right = right - w - 8;
    end
    if e.info.rare then
        local w = text_w('Rare');
        draw_fx_text(dl, right - w, ty, { 0.95, 0.75, 0.35, 1.0 }, 'Rare');
    end
    if imgui.IsItemHovered() and e.bound then
        imgui.SetTooltip((e.info.ex and 'Ex' or 'Rare') .. ": can't go to another character, so it is only combined within each character.");
    end
end

function draw_stacks_window()
    if not stacks.open[1] then
        stacks.placed = false;
        return;
    end
    config.stacks_window = config.stacks_window or T{ x = 720, y = 160, w = 520, h = 560 };
    local geom = config.stacks_window;
    if not stacks.placed then
        imgui.SetNextWindowPos({ geom.x, geom.y }, { 0, 0 });
        imgui.SetNextWindowSize({ geom.w, geom.h });
        stacks.placed = true;
    end
    imgui.SetNextWindowSizeConstraints({ 380, 240 }, { 4000, 4000 });
    push_theme();
    if imgui.Begin('MogSuite  -  Stacks##nai_stacks', stacks.open, ImGuiWindowFlags_NoNav) then
        imgui.PushFont(MS_FONT(), MS_FONT_SIZE() * (tonumber(config.font_scale) or 1.0));
        local frame_h = imgui.GetFrameHeight();

        -- Toolbar.
        imgui.PushItemWidth(170);
        if imgui.InputTextWithHint ~= nil then
            imgui.InputTextWithHint('##nai_stk_search', 'Search items', stacks.search, 64);
        else
            imgui.InputText('##nai_stk_search', stacks.search, 64);
        end
        imgui.PopItemWidth();
        imgui.SameLine();
        local scope = config.stacks_scope or 'all';
        if toggle_button('All characters', 'nai_stk_all', scope == 'all') then config.stacks_scope = 'all'; mark_dirty(); end
        tip('Your bags and every other character MogSuite has seen.');
        imgui.SameLine(0, 4);
        if toggle_button('This character', 'nai_stk_me', scope == 'me') then config.stacks_scope = 'me'; mark_dirty(); end
        tip('Only your own bags.');
        imgui.SameLine();
        local sort = config.stacks_sort or 'saves';
        if imgui.Button((sort == 'saves' and 'Most saved' or 'Name') .. ' v##nai_stk_sort') then
            config.stacks_sort = (sort == 'saves') and 'name' or 'saves';
            mark_dirty();
        end
        tip('Sort: most slots saved first, or by name.');
        imgui.SameLine();
        local spread = config.stacks_show_spread == true;
        if toggle_button('Spread', 'nai_stk_spread', spread) then config.stacks_show_spread = not spread; mark_dirty(); end
        tip('Also list items that are in several places even when no slot would be saved (full stacks).');

        local list, me = stacks_collect();
        local total_saves = 0;
        for _, e in ipairs(list) do total_saves = total_saves + math.max(0, e.saves); end
        imgui.TextColored(UI_MUTED, ('%d item%s  -  '):fmt(#list, #list == 1 and '' or 's'));
        imgui.SameLine(0, 0);
        imgui.TextColored(total_saves > 0 and UI_ACCENT_TEXT or UI_MUTED, ('%d slot%s you could free'):fmt(total_saves, total_saves == 1 and '' or 's'));
        imgui.SameLine();
        imgui.TextColored(UI_MUTED, '(suggestions only; move them yourself)');
        imgui.Separator();

        begin_child('##nai_stk_list', { 0, 0 }, 0);
        local width = tonumber((imgui.GetContentRegionAvail())) or 400;
        if #list == 0 then
            imgui.TextDisabled('Nothing to stack. Everything is already together.');
        end
        local indent = 28;
        for i, e in ipairs(list) do
            imgui.PushID('stk' .. tostring(e.id));
            draw_item_header(e, width);
            for _, p in ipairs(e.plans) do
                local l = p.loc;
                local yours = (l.char == me);
                imgui.SetCursorPosX(imgui.GetCursorPosX() + indent);
                if p.keep then
                    imgui.TextColored(UI_ACCENT_TEXT, 'Keep');
                else
                    imgui.TextColored(p.move and UI_TEXT or UI_MUTED, p.move and 'Move' or '    ');
                end
                imgui.SameLine(indent + 52);
                imgui.TextColored(yours and UI_TEXT or { 0.80, 0.80, 0.86, 1.0 }, loc_label(l, me));
                imgui.SameLine(0, 6);
                imgui.TextColored(config.qty_color, ('x%d'):fmt(l.count));
                if l.slots > 1 then
                    imgui.SameLine(0, 4);
                    imgui.TextColored(UI_MUTED, ('(%d slots)'):fmt(l.slots));
                end
                if p.move then
                    imgui.SameLine(0, 10);
                    imgui.TextColored(UI_MUTED, ('->  %d to %s'):fmt(p.move, (p.to.char == me) and BAG_NAMES[p.to.bag] or loc_label(p.to, me)));
                    if p.cross then
                        imgui.SameLine(0, 6);
                        imgui.TextColored({ 0.92, 0.70, 0.32, 1.0 }, '(trade / delivery box)');
                        if imgui.IsItemHovered() then
                            imgui.SetTooltip(('Another character: send it with the delivery box (or a trade) from %s to %s.'):fmt(tostring(l.char), tostring(p.to.char)));
                        end
                    end
                elseif p.note then
                    imgui.SameLine(0, 10);
                    imgui.TextColored(UI_MUTED, p.note);
                end
                if not yours or VIEW_ONLY_BAG[l.bag] then
                    if imgui.IsItemHovered() and not p.cross then
                        imgui.SetTooltip(yours and 'Mog House storage: as you last saw it.' or (tostring(l.char) .. "'s bags: as MogSuite last saw them."));
                    end
                end
            end
            imgui.PopID();
            if i < #list then imgui.Dummy({ 1, 6 }); end
        end
        imgui.EndChild();

        imgui.PopFont();
        capture_geometry(geom);
    end
    imgui.End();
    pop_theme();
end
