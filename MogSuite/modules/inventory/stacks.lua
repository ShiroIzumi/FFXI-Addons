--[[
    MogSuite - modules/inventory/stacks.lua (1.5.3)

    The Stacks window (the Stacks button on the inventory window): items
    that could be stacked together, across every bag of every character
    MogSuite has seen.

    For each item it lists where the copies are, which spot to keep them in
    (the one with the most), and what to move there. Full stacks stay where
    they are; only the partial ones move.

    1.7.0: each item is a card, read top to bottom:
        NOW     every place with its slots as boxes (how full each stack is)
        STEPS   numbered: what to move where (or "take out and put back")
        AFTER   the same places once you are done, and the slots it saves
    An item whose stacks are all in one bag just says "Just tidy this bag". Ex and Rare items can't go to
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
            l = { char = char, bag = bag, count = 0, slots = 0, stacks = {} };
            e.locs[key] = l;
        end
        l.stacks[#l.stacks + 1] = count;   -- one slot (1.7.0: the boxes)
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

-- ----------------------------------------------------------------------------
-- 1.7.0: an item as a step-by-step card (Now -> Steps -> After)
-- ----------------------------------------------------------------------------

-- n of an item split into slots of the stack size: full ones, then the rest.
local function split_stacks(n, st)
    local out = {};
    while n > 0 do
        out[#out + 1] = math.min(n, st);
        n = n - st;
    end
    return out;
end

-- One row of slot boxes: each box shows its count and how full it is.
local MAX_BOXES = 10;
local function draw_boxes(dl, x, y, counts, st, h, dim)
    local bw = math.max(text_w(tostring(st)), text_w('99')) + 10;
    local shown = math.min(#counts, MAX_BOXES);
    for k = 1, shown do
        local n = counts[k];
        local full = n >= st;
        local x2 = x + bw;
        dl:AddRectFilled({ x, y }, { x2, y + h }, imgui.GetColorU32({ 1, 1, 1, dim and 0.03 or 0.06 }), 3.0);
        local frac = math.max(0, math.min(1, n / st));
        if frac > 0 then
            local col = full and accent(dim and 0.25 or 0.55) or { 0.92, 0.70, 0.32, dim and 0.25 or 0.50 };
            dl:AddRectFilled({ x + 1, y + h - 1 - (h - 2) * frac }, { x2 - 1, y + h - 1 }, imgui.GetColorU32(col), 2.0);
        end
        dl:AddRect({ x, y }, { x2, y + h }, imgui.GetColorU32(full and accent(dim and 0.4 or 0.9) or { 0.92, 0.70, 0.32, dim and 0.4 or 0.9 }), 3.0, 0, 1.0);
        local t = tostring(n);
        draw_fx_text(dl, x + (bw - text_w(t)) * 0.5, y + (h - imgui.GetTextLineHeight()) * 0.5, dim and UI_MUTED or UI_WHITE, t);
        x = x2 + 4;
    end
    if #counts > shown then
        local t = ('+%d more'):fmt(#counts - shown);
        draw_fx_text(dl, x + 2, y + (h - imgui.GetTextLineHeight()) * 0.5, UI_MUTED, t);
        x = x + text_w(t) + 6;
    end
    return x;
end

-- "NOW" / "AFTER": one line per place, with its slot boxes.
local function draw_places(dl, title, rows, me, label_w, width, st, indent)
    local lh = imgui.GetTextLineHeight();
    local h = lh + 4;
    imgui.SetCursorPosX(imgui.GetCursorPosX() + indent);
    imgui.TextColored(UI_ACCENT_TEXT, title);
    for _, r in ipairs(rows) do
        local sx, sy = imgui.GetCursorScreenPos();
        imgui.Dummy({ math.max(1, width - indent), h + 2 });
        local hovered = imgui.IsItemHovered();
        local x = sx + indent + 10;
        local yours = (r.loc.char == me);
        local col = r.keep and UI_ACCENT_TEXT or (yours and UI_TEXT or { 0.80, 0.80, 0.86, 1.0 });
        draw_fx_text(dl, x, sy + 2, col, loc_label(r.loc, me));
        local bx = x + label_w + 12;
        if #r.counts == 0 then
            draw_fx_text(dl, bx, sy + 2, UI_MUTED, 'empty (slot freed)');
        else
            local ex = draw_boxes(dl, bx, sy, r.counts, st, h, r.dim);
            if r.tag ~= nil then draw_fx_text(dl, ex + 4, sy + 2, r.tag_col or UI_MUTED, r.tag); end
        end
        if hovered and (not yours or VIEW_ONLY_BAG[r.loc.bag]) then
            imgui.SetTooltip(yours and 'Mog House storage: as you last saw it.' or (tostring(r.loc.char) .. "'s bags: as MogSuite last saw them."));
        end
    end
end

function draw_stack_card(e, me, width)
    draw_item_header(e, width);
    local dl = imgui.GetWindowDrawList();
    local st = e.stack;
    local indent = 10;

    -- What changes: moved amounts per place, and what the keep spot gets.
    local plus, minus = {}, {};
    local moves, tidy = {}, {};
    for _, p in ipairs(e.plans) do
        if p.move then
            minus[p.loc] = (minus[p.loc] or 0) + p.move;
            plus[p.to] = (plus[p.to] or 0) + p.move;
            moves[#moves + 1] = p;
        elseif p.note then
            tidy[#tidy + 1] = p;
        end
    end

    local label_w = 0;
    for _, p in ipairs(e.plans) do label_w = math.max(label_w, text_w(loc_label(p.loc, me))); end

    -- NOW
    local now = {};
    for _, p in ipairs(e.plans) do
        local counts = {};
        for _, n in ipairs(p.loc.stacks or {}) do counts[#counts + 1] = n; end
        table.sort(counts, function(a, b) return a > b; end);
        local tag, tcol = nil, nil;
        if p.keep then tag, tcol = 'keep here', UI_ACCENT_TEXT; elseif p.move then tag = ('move %d'):fmt(p.move); tcol = { 0.92, 0.70, 0.32, 1.0 }; end
        now[#now + 1] = { loc = p.loc, keep = p.keep, counts = counts, tag = tag, tag_col = tcol };
    end
    draw_places(dl, 'NOW', now, me, label_w, width, st, indent);
    imgui.Dummy({ 1, 2 });

    -- STEPS
    imgui.SetCursorPosX(imgui.GetCursorPosX() + indent);
    if #moves == 0 and #tidy > 0 then
        imgui.TextColored(UI_ACCENT_TEXT, 'STEPS');
        imgui.SameLine(0, 8);
        imgui.TextColored(state.good_color or { 0.43, 0.80, 0.50, 1.0 }, 'Just tidy this bag');
    else
        imgui.TextColored(UI_ACCENT_TEXT, 'STEPS');
    end
    local n = 0;
    local wrap = imgui.GetCursorPosX() + width - 2 * indent;
    imgui.PushTextWrapPos(wrap);
    local function step(text, col)
        n = n + 1;
        imgui.SetCursorPosX(imgui.GetCursorPosX() + indent + 10);
        imgui.TextColored(UI_ACCENT_TEXT, ('%d.'):fmt(n));
        imgui.SameLine(0, 6);
        imgui.TextColored(col or UI_TEXT, text);
    end
    for _, p in ipairs(moves) do
        local from = loc_label(p.loc, me);
        local to = loc_label(p.to, me);
        if p.cross then
            step(('Send %d from %s to %s (delivery box or trade), then put them in %s.'):fmt(p.move, from, tostring(p.to.char), BAG_NAMES[p.to.bag] or '?'));
            if imgui.IsItemHovered() then
                imgui.SetTooltip(('Another character: send it with the delivery box (or a trade) from %s to %s.'):fmt(tostring(p.loc.char), tostring(p.to.char)));
            end
        else
            step(('Move %d from %s to %s.'):fmt(p.move, from, to));
        end
    end
    -- Partial stacks left in the keep spot (its own, or after the moves): take out / put back.
    for _, p in ipairs(e.plans) do
        if p.keep then
            local after = p.loc.count + (plus[p.loc] or 0);
            local slots_now = #(p.loc.stacks or {}) + ((plus[p.loc] or 0) > 0 and 1 or 0);
            if p.note ~= nil or slots_now > math.ceil(after / st) then
                step(('In %s: take the partial stacks out and put them back; they join into %s.'):fmt(
                    loc_label(p.loc, me), table.concat(split_stacks(after, st), ' + ')));
            end
        end
    end
    if n == 0 then
        step('Nothing to move: every copy is already a full stack where it is.', UI_MUTED);
    end
    imgui.PopTextWrapPos();
    imgui.Dummy({ 1, 2 });

    -- AFTER
    local after = {};
    local slots_before, slots_after = 0, 0;
    for _, p in ipairs(e.plans) do
        local left = p.loc.count - (minus[p.loc] or 0) + (plus[p.loc] or 0);
        local counts;
        if left == p.loc.count and (plus[p.loc] or 0) == 0 and p.note == nil then
            counts = {};
            for _, c in ipairs(p.loc.stacks or {}) do counts[#counts + 1] = c; end
            table.sort(counts, function(a, b) return a > b; end);
        else
            counts = split_stacks(left, st);
        end
        slots_before = slots_before + #(p.loc.stacks or {});
        slots_after = slots_after + #counts;
        after[#after + 1] = { loc = p.loc, keep = p.keep, counts = counts, dim = (left == p.loc.count and (plus[p.loc] or 0) == 0 and p.note == nil) };
    end
    draw_places(dl, 'AFTER', after, me, label_w, width, st, indent);
    imgui.SetCursorPosX(imgui.GetCursorPosX() + indent + 10);
    if slots_after < slots_before then
        imgui.TextColored(UI_MUTED, ('%d slots'):fmt(slots_before));
        imgui.SameLine(0, 6);
        imgui.TextColored(UI_MUTED, '->');
        imgui.SameLine(0, 6);
        imgui.TextColored(UI_ACCENT_TEXT, ('%d slot%s'):fmt(slots_after, slots_after == 1 and '' or 's'));
        imgui.SameLine(0, 8);
        imgui.TextColored(state.good_color or { 0.43, 0.80, 0.50, 1.0 }, ('(%d free)'):fmt(slots_before - slots_after));
    else
        imgui.TextColored(UI_MUTED, ('%d slots, none saved (spread over several places)'):fmt(slots_before));
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
        for i, e in ipairs(list) do
            imgui.PushID('stk' .. tostring(e.id));
            draw_stack_card(e, me, width);
            imgui.PopID();
            if i < #list then imgui.Dummy({ 1, 10 }); end
        end
        imgui.EndChild();

        imgui.PopFont();
        capture_geometry(geom);
    end
    imgui.End();
    pop_theme();
end

-- ============================================================================
-- 1.6.0: shared with other modules (Crafting)
-- ============================================================================

-- How many of each item you have: every bag of this character (Mog House
-- storage from its last look). counts[id] = n, and where[id][bag] = n.
function MS.item_counts()
    local counts, where = {}, {};
    for bag, b in pairs(state.bags or {}) do
        for _, r in ipairs(b.rows or {}) do
            if not r.mirror then
                local n = tonumber(r.count) or 0;
                counts[r.id] = (counts[r.id] or 0) + n;
                where[r.id] = where[r.id] or {};
                where[r.id][bag] = (where[r.id][bag] or 0) + n;
            end
        end
    end
    return counts, where;
end

-- Item info (name, stack, flags ...) and its icon texture.
function MS.item_info(id) return get_item_info(id); end
function MS.item_icon(id)
    local info = get_item_info(id);
    return info and get_icon(info) or nil;
end
function MS.bag_name(bag) return BAG_NAMES[bag] or ('Bag ' .. tostring(bag)); end

-- Where an item drops ({ zone id, "Monster", ... }) and a zone's name (Crafting).
function MS.drops_of(id) return drops_of and drops_of(id) or nil; end
function MS.zone_name(zid) return zone_name and zone_name(zid) or ('Zone ' .. tostring(zid)); end
