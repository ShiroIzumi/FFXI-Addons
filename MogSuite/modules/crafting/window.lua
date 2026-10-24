--[[
    MogSuite - modules/crafting/window.lua

    The Crafting window (J):
      Skills    your crafting skills, recipes you can do and the ones good for
                skill-ups
      Recipes   every Horizon-era recipe: search by result or material, craft
                and level filters; the right side shows the materials (and how
                many you have, from every bag), HQ results and your own rates
      Can make  recipes you have every material for right now
      Ledger    your synths: NQ / HQ / break counts and rates per recipe
]]

local TABS = {
    { key = 'skills',  label = 'Skills',   color = COLORS.light },
    { key = 'recipes', label = 'Recipes',  color = COLORS.water },
    { key = 'canmake', label = 'Can make', color = COLORS.wind },
    { key = 'ledger',  label = 'Ledger',   color = COLORS.earth },
};

local GOOD = { 0.43, 0.85, 0.50, 1.0 };
local WARN = { 0.95, 0.72, 0.32, 1.0 };
local BAD  = { 0.92, 0.42, 0.40, 1.0 };
local HQC  = { 0.55, 0.80, 1.00, 1.0 };

local function lh() return imgui.GetTextLineHeight(); end
local function avail_w() return tonumber((imgui.GetContentRegionAvail())) or 400; end
local function scale() return tonumber(config.font_scale) or 1.0; end

local function icon(id, size)
    local tex = MS.item_icon and MS.item_icon(id) or nil;
    if tex ~= nil then
        imgui.Image(tex.id, { size, size });
    else
        imgui.Dummy({ size, size });
    end
end

local function pct(v) return ('%d%%'):fmt(math.floor((v or 0) + 0.5)); end

-- "Smithing 42 (Goldsmithing 10)"
local function level_text(rec)
    local s = ('%s %d'):fmt(rec.craft.name, rec.level);
    if #rec.subs > 0 then
        local p = {};
        for _, sub in ipairs(rec.subs) do p[#p + 1] = ('%s %d'):fmt(sub.craft.short, sub.level); end
        s = s .. '  (' .. table.concat(p, ', ') .. ')';
    end
    return s;
end

-- ============================================================================
-- 1.6.2: tips, where to get things, a shopping list
-- ============================================================================

local function pct1(v)
    v = (v or 0) * 100;
    if v > 0 and v < 1 then return ('%.1f%%'):fmt(v); end
    return ('%d%%'):fmt(math.floor(v + 0.5));
end

-- "Make it" links and where it drops, under a missing material.
function draw_sources(id)
    local indent = 30 * scale();
    local makes = recipes_making(id);
    if makes ~= nil and #makes > 0 then
        local r = makes[1];
        imgui.SetCursorPosX(imgui.GetCursorPosX() + indent);
        imgui.TextColored(UI_MUTED, 'Make it:');
        imgui.SameLine();
        local label = ('%s %d%s##crmk%d_%d'):fmt(r.craft.short, r.level, (#makes > 1) and (' (+%d more)'):fmt(#makes - 1) or '', id, r.id);
        if imgui.SmallButton(label) then state.selected = r; state.plan_n = { 1 }; end
        if imgui.IsItemHovered() then
            local parts = {};
            for _, need in ipairs(recipe_needs(r)) do parts[#parts + 1] = (need.n > 1 and (need.n .. 'x ') or '') .. item_name(need.id); end
            imgui.SetTooltip(('%s x%d  -  %s %d\n%s + %s\nClick to open this recipe.'):fmt(recipe_name(r), r.qty, r.craft.name, r.level,
                item_name(r.crystal), table.concat(parts, ', ')));
        end
    end
    local drops, total = drop_sources(id, 2);
    if drops ~= nil and #drops > 0 then
        imgui.SetCursorPosX(imgui.GetCursorPosX() + indent);
        imgui.TextColored(UI_MUTED, 'Drops from: ' .. table.concat(drops, ', ') .. ((total > #drops) and (' +%d more'):fmt(total - #drops) or ''));
        if imgui.IsItemHovered() then
            local all = drop_sources(id, 12) or {};
            imgui.SetTooltip(table.concat(all, '\n'));
        end
    end
    if (makes == nil or #makes == 0) and (drops == nil or #drops == 0) then
        imgui.SetCursorPosX(imgui.GetCursorPosX() + indent);
        imgui.TextColored(UI_MUTED, 'Not in the data: a vendor, the AH or a guild shop.');
    end
end

-- Make x N: what to get after what you already own (every bag).
function draw_planner(rec)
    state.plan_n = state.plan_n or { 1 };
    imgui.TextColored(UI_MUTED, 'Make');
    imgui.SameLine();
    imgui.PushItemWidth(90 * scale());
    if imgui.InputInt('##crplan', state.plan_n, 1, 12) then state.plan_n[1] = math.max(1, math.min(999, state.plan_n[1])); end
    imgui.PopItemWidth();
    imgui.SameLine();
    imgui.TextColored(UI_MUTED, 'synths');
    local list = shopping_list(rec, state.plan_n[1]);
    local any = false;
    for _, it in ipairs(list) do
        if it.short > 0 then
            if not any then imgui.TextColored(UI_ACCENT_TEXT, 'Still need:'); any = true; end
            imgui.SetCursorPosX(imgui.GetCursorPosX() + 12 * scale());
            imgui.TextColored(UI_TEXT, ('%d x %s'):fmt(it.short, item_name(it.id)));
            imgui.SameLine();
            imgui.TextColored(UI_MUTED, ('(have %d of %d)'):fmt(it.have, it.need));
        end
    end
    if not any then imgui.TextColored(GOOD, ('You have everything for %d.'):fmt(state.plan_n[1])); end
end

-- Your odds, skill-ups and the guild.
function draw_tips(rec)
    imgui.TextColored(UI_MUTED, 'TIPS');
    local o = recipe_odds(rec);
    -- Odds.
    local line;
    if o.worst ~= nil and o.worst.diff > 0 then
        line = ('Break %s, no HQ: you are %d under it in %s.'):fmt(pct1(o.brk), o.worst.diff, o.worst.craft.name);
        imgui.TextColored(o.brk >= 0.5 and BAD or WARN, line);
    else
        imgui.TextColored(GOOD, ('Break %s'):fmt(pct1(o.brk)));
        imgui.SameLine();
        imgui.TextColored(HQC, ('HQ %s'):fmt(pct1(o.hq)));
        imgui.SameLine();
        imgui.TextColored(UI_MUTED, ('(HQ2 %s, HQ3 %s)'):fmt(pct1(o.hq2), pct1(o.hq3)));
        if o.tier < 4 then
            local next_at = ({ 11, 31, 51 })[o.tier];
            local c = o.worst and o.worst.craft or rec.craft;
            local need = nil;
            for _, x in ipairs(o.crafts) do
                if -x.diff < next_at and (need == nil or (next_at + x.diff) > need.n) then need = { craft = x.craft, n = next_at + x.diff }; end
            end
            if need ~= nil then
                imgui.TextColored(UI_MUTED, ('Better HQ odds %d more level%s of %s from now.'):fmt(need.n, need.n == 1 and '' or 's', need.craft.name));
            end
        end
    end
    if #o.crafts > 1 then
        local parts = {};
        for _, x in ipairs(o.crafts) do
            parts[#parts + 1] = ('%s %d/%d'):fmt(x.craft.short, x.skill, x.level);
        end
        imgui.TextColored(UI_MUTED, 'Your skill / needed: ' .. table.concat(parts, ', '));
    end
    -- Skill-ups.
    local text, kind = skillup_verdict(rec);
    local col = (kind == 'good') and GOOD or ((kind == 'ok') and WARN or ((kind == 'bad') and BAD or UI_MUTED));
    imgui.PushTextWrapPos(0);
    imgui.TextColored(col, text);
    -- Guild.
    local g, open = guild_line(rec.craft.name);
    if g ~= nil then imgui.TextColored(open and UI_TEXT or UI_MUTED, g); end
    imgui.PopTextWrapPos();
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Guild image support and crafting gear raise your skill a little; they are not in these numbers.');
    end
end

-- ============================================================================
-- The recipe on the right
-- ============================================================================

local function draw_recipe(rec)
    if rec == nil then
        imgui.TextDisabled('Pick a recipe on the left.');
        return;
    end
    local isz = math.floor(32 * scale());
    icon(rec.result, isz);
    imgui.SameLine();
    imgui.BeginGroup();
    imgui.TextColored(UI_ACCENT_TEXT, recipe_name(rec) .. ((rec.qty > 1) and (' x' .. rec.qty) or ''));
    imgui.TextColored(rec.craft.color, level_text(rec));
    imgui.EndGroup();
    if rec.desynth then imgui.TextColored(WARN, 'Desynthesis'); end
    if rec.ki ~= nil and rec.ki > 0 then
        imgui.TextColored(WARN, 'Needs a key item (guild support / recipe item).');
    end
    local ok = skill_ok(rec);
    local yours = state.skills[rec.craft.name] or 0;
    imgui.TextColored(ok and GOOD or BAD, ok and ('Your %s: %d'):fmt(rec.craft.name, yours) or ('Your %s: %d (needs %d)'):fmt(rec.craft.name, yours, rec.level));
    imgui.Separator();

    -- Crystal and materials.
    imgui.TextColored(UI_MUTED, 'MATERIALS');
    local c = state.counts;
    local small = math.floor(20 * scale());
    local function line(id, n, label)
        local have = c[id] or 0;
        icon(id, small);
        imgui.SameLine();
        imgui.TextColored(UI_TEXT, (n > 1 and (n .. 'x ') or '') .. (label or item_name(id)));
        imgui.SameLine(avail_w() * 0.70);
        imgui.TextColored(have >= n and GOOD or BAD, ('have %d'):fmt(have));
        if imgui.IsItemHovered() then
            local where = state.where[id];
            if where ~= nil then
                local parts = {};
                for bag, k in pairs(where) do parts[#parts + 1] = ('%s %d'):fmt(MS.bag_name and MS.bag_name(bag) or tostring(bag), k); end
                table.sort(parts);
                imgui.SetTooltip(table.concat(parts, '\n'));
            end
        end
        -- 1.6.2: missing: where to get it.
        if have < n then draw_sources(id); end
    end
    local cry = (c[rec.crystal] or 0) + ((rec.hq_crystal or 0) > 0 and (c[rec.hq_crystal] or 0) or 0);
    icon(rec.crystal, small);
    imgui.SameLine();
    imgui.TextColored(UI_TEXT, item_name(rec.crystal));
    imgui.SameLine(avail_w() * 0.70);
    imgui.TextColored(cry > 0 and GOOD or BAD, ('have %d'):fmt(cry));
    for _, need in ipairs(recipe_needs(rec)) do line(need.id, need.n); end
    local times = times_you_can(rec);
    imgui.TextColored(times > 0 and GOOD or UI_MUTED, times > 0 and ('You can make it %d time%s.'):fmt(times, times == 1 and '' or 's') or 'Missing materials.');
    draw_planner(rec);
    imgui.Separator();

    -- HQ results.
    imgui.TextColored(UI_MUTED, 'RESULTS');
    imgui.TextColored(UI_TEXT, ('NQ   %s x%d'):fmt(item_name(rec.result), rec.qty));
    for t = 1, 3 do
        local h = rec.hq[t];
        if h[1] ~= nil and h[1] > 0 then
            imgui.TextColored(HQC, ('HQ%d  %s x%d'):fmt(t, item_name(h[1]), h[2]));
        end
    end
    imgui.Separator();

    draw_tips(rec);
    imgui.Separator();

    -- Your ledger.
    imgui.TextColored(UI_MUTED, 'YOUR SYNTHS');
    local e = load_ledger()[rec.id];
    if e == nil or (e.n or 0) == 0 then
        imgui.TextDisabled('None yet. Every synth you make is counted here.');
        return;
    end
    local hq, brk = ledger_rates(e);
    imgui.TextColored(UI_TEXT, ('%d made'):fmt(e.n));
    imgui.SameLine();
    imgui.TextColored(HQC, ('HQ %s'):fmt(pct(hq)));
    imgui.SameLine();
    imgui.TextColored(BAD, ('break %s'):fmt(pct(brk)));
    imgui.TextColored(UI_MUTED, ('NQ %d   HQ1 %d   HQ2 %d   HQ3 %d   break %d'):fmt(e.nq or 0, e.hq1 or 0, e.hq2 or 0, e.hq3 or 0, e.brk or 0));
    local function table_of(title, t, names)
        if t == nil or next(t) == nil then return; end
        imgui.TextColored(UI_MUTED, title);
        local keys = {};
        for k in pairs(t) do keys[#keys + 1] = k; end
        table.sort(keys);
        for _, k in ipairs(keys) do
            local x = t[k];
            imgui.TextColored(UI_TEXT, '  ' .. tostring(names[k] or k));
            imgui.SameLine(avail_w() * 0.45);
            imgui.TextColored(UI_MUTED, ('%d made  HQ %s  break %s'):fmt(x.n or 0, pct((x.hq or 0) * 100 / math.max(1, x.n or 0)),
                pct((x.brk or 0) * 100 / math.max(1, x.n or 0))));
        end
    end
    table_of('By day', e.days, LEDGER_DAYS);
    table_of('By moon', e.moons, MOON_NAMES);
    table_of('By facing (approximate)', e.dirs, LEDGER_DIRS);
    if e.last ~= nil then imgui.TextColored(UI_MUTED, 'Last synth ' .. os.date('%Y-%m-%d %H:%M', e.last)); end
end

-- ============================================================================
-- Recipe list (Recipes / Can make)
-- ============================================================================

local function filtered(canmake)
    load_recipes();
    local q = tostring(state.search[1] or ''):lower();
    local key = table.concat({ q, tostring(config.craft), tostring(config.only_skill), tostring(config.only_have),
        tostring(config.show_desynth), tostring(canmake), tostring(state.counts_at) }, '|');
    if state.list_key == key and state.list_cache ~= nil then return state.list_cache; end
    local out = {};
    for _, rec in ipairs(RECIPES) do
        local ok = true;
        if rec.desynth and not config.show_desynth then ok = false; end
        if ok and config.craft ~= 'all' and rec.craft.name ~= config.craft then ok = false; end
        if ok and q ~= '' then
            recipe_name(rec);
            if not rec.name_lower:find(q, 1, true) then
                local found = false;
                for _, need in ipairs(recipe_needs(rec)) do
                    if item_name(need.id):lower():find(q, 1, true) then found = true; break; end
                end
                ok = found;
            end
        end
        if ok and (config.only_skill or canmake) and not skill_ok(rec) and not canmake then ok = false; end
        if ok and (config.only_have or canmake) and times_you_can(rec) == 0 then ok = false; end
        if ok then out[#out + 1] = rec; end
    end
    if canmake then
        -- Closest to your skill first.
        table.sort(out, function(a, b)
            local da = (state.skills[a.craft.name] or 0) - a.level;
            local db = (state.skills[b.craft.name] or 0) - b.level;
            if (da >= 0) ~= (db >= 0) then return da >= 0; end
            if da ~= db then return math.abs(da) < math.abs(db); end
            return recipe_name(a) < recipe_name(b);
        end);
    else
        table.sort(out, function(a, b)
            if a.craft.index ~= b.craft.index and config.craft == 'all' then return a.craft.index < b.craft.index; end
            if a.level ~= b.level then return a.level < b.level; end
            return recipe_name(a) < recipe_name(b);
        end);
    end
    state.list_cache, state.list_key = out, key;
    return out;
end

local function draw_list(list, canmake)
    local row_h = math.max(lh(), math.floor(20 * scale())) + 4;
    local w = avail_w();
    local dl = imgui.GetWindowDrawList();
    local first, last;
    -- Only draw the rows in view (a few thousand recipes).
    local y_top = imgui.GetScrollY();
    local win_h = imgui.GetWindowHeight();
    first = math.max(1, math.floor(y_top / row_h) - 2);
    last = math.min(#list, first + math.ceil(win_h / row_h) + 5);
    if first > 1 then imgui.Dummy({ 1, (first - 1) * row_h }); end
    for i = first, last do
        local rec = list[i];
        local sx, sy = imgui.GetCursorScreenPos();
        local sel = state.selected == rec;
        if imgui.InvisibleButton('##crl' .. rec.id, { math.max(1, w), row_h }) then state.selected = rec; end
        local hov = imgui.IsItemHovered();
        if sel then dl:AddRectFilled({ sx, sy }, { sx + w, sy + row_h }, imgui.GetColorU32(accent(0.22)), 3.0);
        elseif hov then dl:AddRectFilled({ sx, sy }, { sx + w, sy + row_h }, imgui.GetColorU32(accent(0.12)), 3.0);
        elseif i % 2 == 0 then dl:AddRectFilled({ sx, sy }, { sx + w, sy + row_h }, imgui.GetColorU32({ 1, 1, 1, 0.025 }), 3.0); end
        local isz = row_h - 4;
        local tex = MS.item_icon and MS.item_icon(rec.result) or nil;
        if tex ~= nil then dl:AddImage(tex.id, { sx + 3, sy + 2 }, { sx + 3 + isz, sy + 2 + isz }); end
        local ty = sy + (row_h - lh()) / 2;
        local can = skill_ok(rec);
        draw_fx_text(dl, sx + isz + 10, ty, can and UI_TEXT or UI_MUTED, recipe_name(rec) .. ((rec.qty > 1) and (' x' .. rec.qty) or ''));
        local right = sx + w - 8;
        local lv = ('%s %d'):fmt(rec.craft.short, rec.level) .. ((#rec.subs > 0) and ' +' or '');
        local lw = text_w(lv);
        draw_fx_text(dl, right - lw, ty, rec.craft.color, lv);
        right = right - lw - 12;
        local times = times_you_can(rec);
        if times > 0 then
            local t = ('can make %d'):fmt(times);
            draw_fx_text(dl, right - text_w(t), ty, GOOD, t);
            right = right - text_w(t) - 12;
        end
        local e = LEDGER and LEDGER[rec.id] or nil;
        if e ~= nil and (e.n or 0) > 0 then
            local hq = ledger_rates(e);
            local t = ('HQ %s'):fmt(pct(hq));
            draw_fx_text(dl, right - text_w(t), ty, HQC, t);
        end
        if hov then
            imgui.SetTooltip(level_text(rec) .. '\n' .. (can and 'Within your skill.' or 'Above your skill.'));
        end
    end
    if last < #list then imgui.Dummy({ 1, (#list - last) * row_h }); end
end

local function draw_filters(canmake)
    imgui.PushItemWidth(200 * scale());
    if imgui.InputTextWithHint ~= nil then
        imgui.InputTextWithHint('##crsearch', 'Search result or material', state.search, 48);
    else
        imgui.InputText('##crsearch', state.search, 48);
    end
    imgui.PopItemWidth();
    imgui.SameLine();
    -- 1.6.3: a fixed width (it filled the row and pushed the buttons out).
    imgui.PushItemWidth(150 * scale());
    local combo_open = imgui.BeginCombo('##crcraft', config.craft == 'all' and 'All crafts' or config.craft);
    imgui.PopItemWidth();
    if combo_open then
        if imgui.Selectable('All crafts', config.craft == 'all') then config.craft = 'all'; mark_dirty(); end
        for _, c in ipairs(CRAFTS) do
            imgui.PushStyleColor(ImGuiCol_Text, c.color);
            if imgui.Selectable(('%s  (%d)##crc%d'):fmt(c.name, state.skills[c.name] or 0, c.index), config.craft == c.name) then config.craft = c.name; mark_dirty(); end
            imgui.PopStyleColor(1);
        end
        imgui.EndCombo();
    end
    if not canmake then
        imgui.SameLine();
        if toggle_button('My skill', 'cr_onlyskill', config.only_skill == true) then config.only_skill = not config.only_skill; mark_dirty(); end
        tip('Only recipes your skill can do (main and sub crafts).');
        imgui.SameLine(0, 4);
        if toggle_button('Have materials', 'cr_onlyhave', config.only_have == true) then config.only_have = not config.only_have; mark_dirty(); end
        tip('Only recipes you have every material for (every bag).');
        imgui.SameLine(0, 4);
        if toggle_button('Desynth', 'cr_desynth', config.show_desynth == true) then config.show_desynth = not config.show_desynth; mark_dirty(); end
        tip('Also show desynthesis recipes.');
    end
end

local function draw_recipes(canmake)
    draw_filters(canmake);
    local list = filtered(canmake);
    imgui.TextColored(UI_MUTED, ('%d recipe%s'):fmt(#list, #list == 1 and '' or 's'));
    if canmake then
        imgui.SameLine();
        imgui.TextColored(UI_MUTED, '- you have every material (all bags, Mog House storage as last seen). Within your skill first.');
    end
    local side = math.max(300, avail_w() * 0.42);
    begin_child('##crlist', { avail_w() - side - 8, 0 }, 0);
    if #list == 0 then imgui.TextDisabled(canmake and 'Nothing you have every material for.' or 'No recipe matches.'); end
    draw_list(list, canmake);
    imgui.EndChild();
    imgui.SameLine(0, 8);
    begin_child('##crdetail', { 0, 0 }, 0);
    draw_recipe(state.selected);
    imgui.EndChild();
end

-- ============================================================================
-- Skills
-- ============================================================================

local function draw_skills()
    load_recipes();
    local w = avail_w();
    local range = math.max(1, tonumber(config.skillup_range) or 10);
    imgui.TextColored(UI_MUTED, 'Skill-ups come from recipes a little above your skill. "Next" picks the best ones: ready to make first, then the fewest missing materials.');
    imgui.Spacing();
    local counts = {};
    for _, rec in ipairs(RECIPES) do
        if not rec.desynth then
            local c = counts[rec.craft.name] or { total = 0, can = 0, up = 0 };
            counts[rec.craft.name] = c;
            c.total = c.total + 1;
            local s = state.skills[rec.craft.name] or 0;
            if rec.level <= s then c.can = c.can + 1;
            elseif rec.level <= s + range then c.up = c.up + 1; end
        end
    end
    local dl = imgui.GetWindowDrawList();
    for _, c in ipairs(CRAFTS) do
        local s = state.skills[c.name] or 0;
        local n = counts[c.name] or { total = 0, can = 0, up = 0 };
        local x, y = imgui.GetCursorScreenPos();
        local rh = lh() * 2 + 10;
        if imgui.InvisibleButton('##crsk' .. c.index, { w, rh }) then
            config.craft = c.name;
            config.only_skill = false;
            config.tab = 'recipes';
            state.search[1] = '';
            mark_dirty();
        end
        local hov = imgui.IsItemHovered();
        dl:AddRectFilled({ x, y }, { x + w, y + rh }, imgui.GetColorU32(hov and accent(0.14) or { 1, 1, 1, 0.03 }), 4.0);
        dl:AddRectFilled({ x, y }, { x + 4, y + rh }, imgui.GetColorU32(c.color), 2.0);
        draw_fx_text(dl, x + 12, y + 4, c.color, c.name);
        draw_fx_text(dl, x + 12 + w * 0.22, y + 4, UI_TEXT, tostring(s));
        local bx, bw = x + 12 + w * 0.30, w * 0.40;
        dl:AddRectFilled({ bx, y + 8 }, { bx + bw, y + 8 + lh() * 0.5 }, imgui.GetColorU32(UI_CONTROL), 3.0);
        dl:AddRectFilled({ bx, y + 8 }, { bx + bw * math.min(1, s / 100), y + 8 + lh() * 0.5 }, imgui.GetColorU32({ c.color[1], c.color[2], c.color[3], 0.7 }), 3.0);
        draw_fx_text(dl, x + 12, y + 6 + lh(), UI_MUTED, ('%d recipes within your skill   %d for skill-ups   %d in all'):fmt(n.can, n.up, n.total));
        -- 1.6.2: the best next recipes to skill up on.
        local picks = next_recipes(c, 3);
        if #picks > 0 then
            imgui.SetCursorPosX(imgui.GetCursorPosX() + 12);
            imgui.TextColored(UI_MUTED, 'Next:');
            for i, p in ipairs(picks) do
                imgui.SameLine(0, 8);
                local tag = (p.times > 0) and 'ready' or ((p.missing == 1) and 'need 1' or ('need %d'):fmt(p.missing));
                local label = ('%s (%d, %s)##crnx%d'):fmt(recipe_name(p.rec), p.rec.level, tag, p.rec.id);
                if p.times > 0 then imgui.PushStyleColor(ImGuiCol_Text, GOOD); end
                if imgui.SmallButton(label) then
                    state.selected = p.rec;
                    state.plan_n = { 1 };
                    config.tab = 'recipes';
                    config.craft = c.name;
                    state.search[1] = '';
                    mark_dirty();
                end
                if p.times > 0 then imgui.PopStyleColor(1); end
                if imgui.IsItemHovered() then
                    imgui.SetTooltip(('%s  -  %s %d (%d over your skill)\n%s\nClick to open it with its shopping list.'):fmt(
                        recipe_name(p.rec), c.name, p.rec.level, p.d,
                        (p.times > 0) and ('You can make it %d time%s now.'):fmt(p.times, p.times == 1 and '' or 's')
                        or ('Missing %d material%s.'):fmt(p.missing, p.missing == 1 and '' or 's')));
                end
            end
        end
        imgui.Spacing();
    end
    imgui.TextColored(UI_MUTED, 'Skills are whole levels as the game reports them (the decimals are not sent).');
end

-- ============================================================================
-- Ledger
-- ============================================================================

local function draw_ledger()
    load_recipes();
    local L = load_ledger();
    local by_id = {};
    for _, rec in ipairs(RECIPES) do by_id[rec.id] = rec; end
    local rows = {};
    local tot = { n = 0, hq = 0, brk = 0 };
    for id, e in pairs(L) do
        local rec = by_id[tonumber(id)];
        if rec ~= nil and (e.n or 0) > 0 then
            rows[#rows + 1] = { rec = rec, e = e };
            tot.n = tot.n + e.n;
            tot.hq = tot.hq + (e.hq1 or 0) + (e.hq2 or 0) + (e.hq3 or 0);
            tot.brk = tot.brk + (e.brk or 0);
        end
    end
    table.sort(rows, function(a, b) return (a.e.last or 0) > (b.e.last or 0); end);
    imgui.TextColored(UI_TEXT, ('%d synths'):fmt(tot.n));
    imgui.SameLine();
    imgui.TextColored(HQC, ('HQ %s'):fmt(pct(tot.hq * 100 / math.max(1, tot.n))));
    imgui.SameLine();
    imgui.TextColored(BAD, ('break %s'):fmt(pct(tot.brk * 100 / math.max(1, tot.n))));
    imgui.SameLine();
    imgui.TextColored(UI_MUTED, '- all your characters. Click a row for the details.');
    local side = math.max(300, avail_w() * 0.42);
    begin_child('##crledger', { avail_w() - side - 8, 0 }, 0);
    if #rows == 0 then imgui.TextDisabled('No synths yet. They are counted as you craft.'); end
    local w = avail_w();
    for _, r in ipairs(rows) do
        local hq, brk = ledger_rates(r.e);
        local sel = state.selected == r.rec;
        if imgui.Selectable(('%s##crlg%d'):fmt(recipe_name(r.rec), r.rec.id), sel, 0, { w * 0.42, 0 }) then state.selected = r.rec; end
        imgui.SameLine(w * 0.44);
        imgui.TextColored(UI_TEXT, ('%d'):fmt(r.e.n));
        imgui.SameLine(w * 0.54);
        imgui.TextColored(HQC, 'HQ ' .. pct(hq));
        imgui.SameLine(w * 0.70);
        imgui.TextColored(BAD, 'brk ' .. pct(brk));
        imgui.SameLine(w * 0.86);
        imgui.TextColored(UI_MUTED, r.e.last and os.date('%m/%d', r.e.last) or '');
    end
    imgui.EndChild();
    imgui.SameLine(0, 8);
    begin_child('##crledgerd', { 0, 0 }, 0);
    draw_recipe(state.selected);
    imgui.EndChild();
end

local DRAW = {
    skills = draw_skills,
    recipes = function() draw_recipes(false); end,
    canmake = function() draw_recipes(true); end,
    ledger = draw_ledger,
};

-- ============================================================================
-- Window
-- ============================================================================

function draw_crafting_window()
    if not state.visible[1] then
        if config.visible then config.visible = false; mark_dirty(); end
        state.apply_geometry = true;
        return;
    end
    refresh_counts();
    load_ledger();
    local W = config.window;
    if state.apply_geometry then
        local x, y = tonumber(W.x) or -1, tonumber(W.y) or -1;
        if x < 0 or y < 0 then
            local io = imgui.GetIO();
            local dw = io and io.DisplaySize and tonumber(io.DisplaySize.x) or 1920;
            local dh = io and io.DisplaySize and tonumber(io.DisplaySize.y) or 1080;
            x, y = math.max(0, (dw - W.w) / 2), math.max(0, (dh - W.h) / 3);
        end
        imgui.SetNextWindowPos({ x, y });
        imgui.SetNextWindowSize({ W.w, W.h });
        state.apply_geometry = false;
    end
    imgui.SetNextWindowSizeConstraints({ 640, 380 }, { 4000, 4000 });
    push_theme();
    local flags = ImGuiWindowFlags_NoNav;
    if config.locked then flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoResize); end
    if imgui.Begin('MogSuite  -  Crafting##ms_crafting', state.visible, flags) then
        imgui.PushFont(MS_FONT(), MS_FONT_SIZE() * scale());
        for i, t in ipairs(TABS) do
            if i > 1 then imgui.SameLine(0, 4); end
            if color_tab(t.label, 'cr_tab_' .. t.key, config.tab == t.key, t.color) then config.tab = t.key; mark_dirty(); end
        end
        imgui.SameLine();
        local cw = text_w('Config') + 16;
        imgui.SetCursorPosX(math.max(imgui.GetCursorPosX(), imgui.GetWindowWidth() - cw - 12));
        if imgui.Button('Config##cr_cfg') then MS.open_config('crafting'); end
        imgui.Separator();
        begin_child('##cr_body', { 0, 0 }, 0);
        local ok, err = pcall(DRAW[config.tab] or DRAW.recipes);
        if not ok then imgui.TextColored(BAD, tostring(err)); end
        imgui.EndChild();
        imgui.PopFont();
        if not imgui.IsMouseDown(0) then
            local px, py = imgui.GetWindowPos();
            local sw, sh = imgui.GetWindowSize();
            px, py, sw, sh = tonumber(px), tonumber(py), tonumber(sw), tonumber(sh);
            if px ~= nil and (math.abs(px - (W.x or 0)) >= 1 or math.abs(py - (W.y or 0)) >= 1
                or math.abs(sw - (W.w or 0)) >= 1 or math.abs(sh - (W.h or 0)) >= 1) then
                W.x, W.y, W.w, W.h = px, py, sw, sh;
                mark_dirty();
            end
        end
    end
    imgui.End();
    pop_theme();
    if config.visible ~= true then config.visible = true; mark_dirty(); end
end
