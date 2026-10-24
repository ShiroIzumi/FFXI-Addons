--[[
    MogSuite - modules/inventory/extras.lua (1.5.0)

    Tooltip extras, the Usable / Cleanup / Upgrades views and the Watch list.

    Tooltip extras (each can be turned off in Settings > Inventory > Tooltips):
      - where it drops (mobdb data, data/drops.lua)
      - what it is made from / which recipes use it (LandSandBoat recipes,
        data/recipes.lua, Horizon-era crafts only)
      - "you have N more in <bag>"

    Usable view: food, medicines, scrolls, ninja tools, ammo and other usable
    items, each in its own section.

    Cleanup view: suggestions only. MogSuite never moves, sells or drops
    anything by itself: partial stacks to merge, the same item spread over
    several bags, items that only sell to NPCs, and gear you have outgrown.

    Upgrades view: per equipment slot, gear in your Inventory / Wardrobes that
    beats what you wear (the Character window's Upgrade finder). Click a
    slot to open the Character window's gear panel there.

    Watch list: right-click an item > Watch this item, and pick how few is
    "running low". An alert window (and an optional sound) tells you when
    you drop to that many.
]]

-- ============================================================================
-- Data (loaded the first time a tooltip needs it)
-- ============================================================================

extras = { recipes = nil, made_by = nil, used_in = nil, drops = nil };

local function load_data(name)
    local path = DATA_DIR .. name;
    local f = loadfile(path);
    if f == nil then return nil; end
    local ok, t = pcall(f);
    if ok and type(t) == 'table' then return t; end
    return nil;
end

function recipe_index()
    if extras.made_by ~= nil then return; end
    extras.made_by, extras.used_in = {}, {};
    extras.recipes = load_data('recipes.lua') or {};
    for _, r in ipairs(extras.recipes) do
        local res = r[1];
        extras.made_by[res] = extras.made_by[res] or {};
        table.insert(extras.made_by[res], r);
        local seen = {};
        for _, ing in ipairs(r[6] or {}) do
            if not seen[ing] then
                seen[ing] = true;
                extras.used_in[ing] = extras.used_in[ing] or {};
                table.insert(extras.used_in[ing], r);
            end
        end
    end
end

function drops_of(id)
    if extras.drops == nil then extras.drops = load_data('drops.lua') or {}; end
    return extras.drops[id];
end

zone_name_cache = {};
function zone_name(zid)
    local n = zone_name_cache[zid];
    if n ~= nil then return n; end
    n = '';
    pcall(function() n = tostring(AshitaCore:GetResourceManager():GetString('zones.names', zid) or ''); end);
    if n == '' then n = 'Zone ' .. tostring(zid); end
    zone_name_cache[zid] = n;
    return n;
end

function item_name_of(id)
    local info = get_item_info(id);
    return info and info.name or ('Item ' .. tostring(id));
end

-- Count of an item in every bag of this character: { [bag] = count }.
function counts_by_bag(id)
    local out = {};
    for bag, b in pairs(state.bags or {}) do
        for _, r in ipairs(b.rows or {}) do
            if r.id == id and r.source == nil then out[bag] = (out[bag] or 0) + r.count; end
        end
    end
    return out;
end

-- ============================================================================
-- Tooltip extras (called at the end of draw_tooltip)
-- ============================================================================

local MAX_LINES = 5;

function draw_tooltip_extras(row)
    local info = row.info;
    if config.tip_other_bags ~= false and row.source == nil then
        local parts = {};
        for bag, n in pairs(counts_by_bag(row.id)) do
            if bag ~= row.bag then parts[#parts + 1] = ('%d in %s'):fmt(n, BAG_NAMES[bag] or ('Bag ' .. bag)); end
        end
        if #parts > 0 then
            table.sort(parts);
            imgui.TextColored(config.qty_color, 'You have ' .. table.concat(parts, ', '));
        end
    end

    if config.tip_drops ~= false then
        local d = drops_of(row.id);
        if d ~= nil and #d > 0 then
            imgui.Spacing();
            imgui.TextColored(UI_ACCENT_TEXT, 'Drops from');
            local shown = 0;
            for i = 1, #d, 2 do
                if shown >= MAX_LINES then
                    imgui.TextColored(UI_MUTED, ('  ...and %d more'):fmt((#d - i + 1) / 2));
                    break;
                end
                imgui.TextColored(UI_MUTED, ('  %s  (%s)'):fmt(tostring(d[i + 1]), zone_name(d[i])));
                shown = shown + 1;
            end
        end
    end

    if config.tip_recipes ~= false then
        recipe_index();
        local made = extras.made_by[row.id];
        if made ~= nil and #made > 0 then
            imgui.Spacing();
            imgui.TextColored(UI_ACCENT_TEXT, 'Made with');
            for i, r in ipairs(made) do
                if i > 2 then break; end
                local ings = {};
                local counts, order = {}, {};
                for _, ing in ipairs(r[6] or {}) do
                    if counts[ing] == nil then order[#order + 1] = ing; end
                    counts[ing] = (counts[ing] or 0) + 1;
                end
                for _, ing in ipairs(order) do
                    ings[#ings + 1] = (counts[ing] > 1 and (counts[ing] .. 'x ') or '') .. item_name_of(ing);
                end
                imgui.TextColored(UI_MUTED, ('  %s %d%s: %s + %s'):fmt(r[3], r[4], r[7] and (' (' .. r[7] .. ')') or '',
                    item_name_of(r[5]), table.concat(ings, ', ')));
            end
        end
        local used = extras.used_in[row.id];
        if used ~= nil and #used > 0 then
            imgui.Spacing();
            imgui.TextColored(UI_ACCENT_TEXT, ('Used in %d recipe%s'):fmt(#used, #used == 1 and '' or 's'));
            local list = {};
            for _, r in ipairs(used) do list[#list + 1] = r; end
            table.sort(list, function(a, b) if a[4] ~= b[4] then return a[4] < b[4]; end return a[3] < b[3]; end);
            for i, r in ipairs(list) do
                if i > MAX_LINES then
                    imgui.TextColored(UI_MUTED, ('  ...and %d more'):fmt(#list - MAX_LINES));
                    break;
                end
                imgui.TextColored(UI_MUTED, ('  %s  (%s %d)'):fmt(item_name_of(r[1]), r[3], r[4]));
            end
        end
    end

    local w = config.watch and config.watch[row.id];
    if w ~= nil then
        imgui.TextColored(UI_ACCENT_TEXT, ('Watched: alert at %d or fewer'):fmt(tonumber(w.min) or 0));
    end
end

-- ============================================================================
-- Section header (Usable / Cleanup / Upgrades views)
-- ============================================================================

local function section(key, label, count, right)
    config.cat_collapsed = config.cat_collapsed or T{};
    local ckey = 'x_' .. key;
    local collapsed = config.cat_collapsed[ckey] == true;
    local dl = imgui.GetWindowDrawList();
    local line_h = imgui.GetTextLineHeight();
    local width = tonumber((imgui.GetContentRegionAvail())) or 300;
    local h = line_h + 8;
    local sx, sy = imgui.GetCursorScreenPos();
    if imgui.InvisibleButton('##nai_xsec_' .. key, { math.max(1, width), h }) then
        config.cat_collapsed[ckey] = (not collapsed) or nil;
        collapsed = not collapsed;
        mark_dirty();
    end
    local hovered = imgui.IsItemHovered();
    dl:AddRectFilled({ sx, sy }, { sx + width, sy + h }, imgui.GetColorU32(accent(hovered and 0.26 or 0.13)), 4.0);
    dl:AddRectFilled({ sx, sy + h - 2 }, { sx + width, sy + h }, imgui.GetColorU32(accent(0.55)), 0.0);
    local ax, ay, a = sx + 10, sy + h * 0.5, math.max(3, line_h * 0.22);
    local acol = imgui.GetColorU32(UI_ACCENT_TEXT);
    if collapsed then
        dl:AddTriangleFilled({ ax - a * 0.6, ay - a }, { ax + a * 0.8, ay }, { ax - a * 0.6, ay + a }, acol);
    else
        dl:AddTriangleFilled({ ax - a, ay - a * 0.6 }, { ax + a, ay - a * 0.6 }, { ax, ay + a * 0.8 }, acol);
    end
    draw_fx_text(dl, sx + 22, sy + 4, UI_ACCENT_TEXT, label);
    if count ~= nil then draw_fx_text(dl, sx + 22 + text_w(label), sy + 4, UI_MUTED, ('  %d'):fmt(count)); end
    if right ~= nil and right ~= '' then
        draw_fx_text(dl, sx + width - text_w(right) - 8, sy + 4, config.qty_color, right);
    end
    imgui.Dummy({ 1, 2 });
    return not collapsed;
end

-- ============================================================================
-- Usable view
-- ============================================================================

USABLE_GROUPS = {
    { key = 'food', label = 'Food' },
    { key = 'meds', label = 'Medicines' },
    { key = 'scrolls', label = 'Scrolls' },
    { key = 'tools', label = 'Ninja Tools' },
    { key = 'ammo', label = 'Ammo' },
    { key = 'other', label = 'Other usable items' },
};

function ah_cat(id)
    load_price_list();
    return prices.ah[tonumber(id) or 0];
end

function usable_group(row)
    local a = ah_cat(row.id);
    if a == 15 or ((row.info.type == TYPE_WEAPON or row.info.type == TYPE_ARMOR) and row.info.slots == SLOT_AMMO_BIT) then return 'ammo'; end
    if a ~= nil and a >= 51 and a <= 58 then return 'food'; end
    if a == 33 then return 'meds'; end
    if a == 28 or a == 29 or a == 30 or a == 31 or a == 32 or a == 45 or a == 60 then return 'scrolls'; end
    if a == 49 then return 'tools'; end
    if row.info.type == TYPE_USABLE then return 'other'; end
    return nil;
end

function draw_usable_view(rows, show_bag)
    local groups = {};
    for _, row in ipairs(rows) do
        local g = usable_group(row);
        if g ~= nil then
            groups[g] = groups[g] or {};
            table.insert(groups[g], row);
        end
    end
    local any = false;
    for _, g in ipairs(USABLE_GROUPS) do
        local list = groups[g.key];
        if list ~= nil and #list > 0 then
            any = true;
            if section('u_' .. g.key, g.label, #list) then
                draw_list_view(list, show_bag);
            end
            imgui.Dummy({ 1, 4 });
        end
    end
    if not any then imgui.TextDisabled('No usable items here.'); end
end

-- ============================================================================
-- Cleanup view (suggestions only)
-- ============================================================================

function draw_cleanup_view()
    imgui.TextColored(UI_MUTED, 'Suggestions only - nothing is moved, sold or dropped for you.');
    imgui.Dummy({ 1, 4 });

    -- Partial stacks (same bag) and the same item in several carried bags.
    local split, spread, sell = {}, {}, {};
    local by_id = {};
    for _, bag in ipairs(state.bag_order or {}) do
        local b = state.bags[bag];
        for _, r in ipairs(b and b.rows or {}) do
            if r.source == nil then
                if r.split ~= nil then split[#split + 1] = r; end
                by_id[r.id] = by_id[r.id] or { bags = {}, rows = {} };
                by_id[r.id].bags[bag] = true;
                table.insert(by_id[r.id].rows, r);
            end
        end
    end
    for _, e in pairs(by_id) do
        local n = 0;
        for _ in pairs(e.bags) do n = n + 1; end
        if n >= 2 and (tonumber(e.rows[1].info.stack) or 1) > 1 then
            for _, r in ipairs(e.rows) do spread[#spread + 1] = r; end
        end
    end
    -- Things that only sell to NPCs: not Rare/Ex, not a favorite, no
    -- Auction House category, a known sell price, not gear or crystals.
    local inv = state.bags[0];
    for _, r in ipairs(inv and inv.rows or {}) do
        local info = r.info;
        if r.source == nil and not info.rare and not info.ex and not is_favorite(r)
            and info.type ~= TYPE_WEAPON and info.type ~= TYPE_ARMOR and info.type ~= TYPE_CRYSTAL
            and ah_of(r.id) == 'none' then
            local each = price_of(r.id);
            if each ~= nil and each > 0 then sell[#sell + 1] = r; end
        end
    end
    local function sort_name(a, b)
        if a.info.name_lower ~= b.info.name_lower then return a.info.name_lower < b.info.name_lower; end
        return (a.bag * 1000 + a.index) < (b.bag * 1000 + b.index);
    end
    table.sort(split, sort_name);
    table.sort(spread, sort_name);
    table.sort(sell, function(a, b) return (price_of(a.id) or 0) * a.count > (price_of(b.id) or 0) * b.count; end);

    local any = false;
    if #split > 0 then
        any = true;
        if section('c_split', 'Partial stacks you could merge', #split) then draw_list_view(split, true); end
        imgui.Dummy({ 1, 4 });
    end
    if #spread > 0 then
        any = true;
        if section('c_spread', 'Same item in several bags', #spread) then draw_list_view(spread, true); end
        imgui.Dummy({ 1, 4 });
    end
    if #sell > 0 then
        any = true;
        local total = rows_value(sell);
        if section('c_sell', 'Sells to NPCs only (not on the AH)', #sell, total > 0 and (fmt_gil(total) .. ' gil') or nil) then
            draw_list_view(sell, false);
        end
        imgui.Dummy({ 1, 4 });
    end
    if MS.upgrade_summary ~= nil then
        local ok, sum = pcall(MS.upgrade_summary);
        if ok and sum ~= nil then
            local old = {};
            for _, s in ipairs(sum.slots) do
                for _, e in ipairs(s.outleveled) do old[#old + 1] = { e = e, s = s }; end
            end
            if #old > 0 then
                any = true;
                if section('c_old', 'Gear you have outgrown (a better one is usable)', #old) then
                    for _, o in ipairs(old) do
                        imgui.TextColored(UI_TEXT, o.e.item.name);
                        imgui.SameLine();
                        imgui.TextColored(UI_MUTED, ('Lv %d  %s  -  %s is better'):fmt(o.e.item.level, tostring(o.s.label),
                            o.s.best and o.s.best.item.name or '?'));
                    end
                end
                imgui.Dummy({ 1, 4 });
            end
        end
    end
    if not any then imgui.TextDisabled('Nothing to clean up. Nice and tidy!'); end
end

-- ============================================================================
-- Upgrades view
-- ============================================================================

function draw_upgrades_view()
    if MS.upgrade_summary == nil then
        imgui.TextDisabled('The Upgrades view needs the Character module.');
        return;
    end
    local ok, sum = pcall(MS.upgrade_summary);
    if not ok or sum == nil then
        imgui.TextDisabled('Waiting for your character...');
        return;
    end
    imgui.TextColored(UI_MUTED, 'Inventory + Wardrobes, scored with your job\'s stat priority. Click a slot to open the gear panel.');
    imgui.Dummy({ 1, 4 });
    local any = false;
    for _, s in ipairs(sum.slots) do
        local n = #s.upgrades;
        local label = tostring(s.label or '?');
        if n > 0 or #s.new > 0 then
            any = true;
            if imgui.Selectable(('%s##nai_upg_%d'):fmt(label, s.slot), false) then
                pcall(MS.open_equip_slot, s.slot);
            end
            if imgui.IsItemHovered() then imgui.SetTooltip('Open the gear panel for this slot'); end
            imgui.Indent();
            for _, e in ipairs(s.upgrades) do
                imgui.TextColored({ 0.30, 1.00, 0.42, 1.0 }, (e.best and '* ' or '^ ') .. e.item.name);
                imgui.SameLine();
                imgui.TextColored(UI_MUTED, ('Lv %d  %s'):fmt(e.item.level, BAG_NAMES[e.item.bag] or ''));
            end
            for _, e in ipairs(s.new) do
                if not e.better then
                    imgui.TextColored(UI_ACCENT_TEXT, 'new at your level: ' .. e.item.name);
                end
            end
            imgui.Unindent();
        end
    end
    if not any then imgui.TextDisabled('No upgrades in your Inventory or Wardrobes right now.'); end
end

-- ============================================================================
-- Watch list
-- ============================================================================

watch = { low = {}, alerted = {}, prev = {}, open = { false }, placed = false };
DEFAULT_SOUND = (os.getenv('WINDIR') or 'C:\\Windows') .. '\\Media\\Windows Notify System Generic.wav';

function watch_toggle(row)
    config.watch = config.watch or T{};
    if config.watch[row.id] ~= nil then
        config.watch[row.id] = nil;
    else
        local st = tonumber(row.info.stack) or 1;
        config.watch[row.id] = T{ min = (st > 1) and math.max(1, math.floor(st / 4)) or 1 };
    end
    watch.alerted[row.id] = nil;
    mark_dirty();
end

local function play_alert()
    if config.watch_sound ~= true then return; end
    local p = tostring(config.watch_sound_file or '');
    if p == '' then p = DEFAULT_SOUND; end
    pcall(function() ashita.misc.play_sound(p); end);
end

-- totals = [item id] = count in carried bags (from scan_bags).
function watch_check(totals)
    if config.watch == nil or next(config.watch) == nil or totals == nil then return; end
    local mode = config.watch_mode or 'drop';
    local fire = false;
    local low = {};
    for id, w in pairs(config.watch) do
        local n = totals[id] or 0;
        local min = tonumber(w.min) or 0;
        local before = watch.prev[id];
        if n <= min then
            low[#low + 1] = { id = id, count = n, min = min };
            local dropped = before ~= nil and n < before;
            if mode == 'drop' then
                if dropped or (before == nil and not watch.alerted[id]) then fire = true; watch.alerted[id] = true; end
            elseif not watch.alerted[id] then
                fire = true;
                watch.alerted[id] = true;
            end
        elseif mode == 'drop' then
            watch.alerted[id] = nil;
        end
        watch.prev[id] = n;
    end
    table.sort(low, function(a, b) return a.count < b.count; end);
    watch.low = low;
    if fire then
        watch.open[1] = true;
        play_alert();
    end
    if #low == 0 then watch.open[1] = false; end
end

function draw_watch_window()
    if not watch.open[1] or #watch.low == 0 then return; end
    config.watch_window = config.watch_window or T{ x = 700, y = 160 };
    if not watch.placed then
        imgui.SetNextWindowPos({ config.watch_window.x, config.watch_window.y }, { 0, 0 });
        watch.placed = true;
    end
    push_theme();
    local flags = bit.bor(ImGuiWindowFlags_NoNav, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoFocusOnAppearing or 0);
    if imgui.Begin('MogSuite  -  Running low##nai_watch', watch.open, flags) then
        local scale = tonumber(config.font_scale) or 1.0;
        imgui.PushFont(MS_FONT(), MS_FONT_SIZE() * scale);
        imgui.TextColored(UI_DANGER, 'RUNNING LOW');
        imgui.Separator();
        for _, l in ipairs(watch.low) do
            local info = get_item_info(l.id);
            local tex = info and get_icon(info) or nil;
            if tex ~= nil then
                local s = imgui.GetTextLineHeight();
                imgui.Image(tex.id, { s, s });
                imgui.SameLine();
            end
            imgui.TextColored(UI_TEXT, info and info.name or ('Item ' .. l.id));
            imgui.SameLine();
            imgui.TextColored(l.count == 0 and UI_DANGER or config.qty_color, ('%d left'):fmt(l.count));
            imgui.SameLine();
            imgui.TextColored(UI_MUTED, ('(alert at %d)'):fmt(l.min));
        end
        imgui.Spacing();
        if imgui.Button('Dismiss##nai_watch_ok') then watch.open[1] = false; end
        imgui.SameLine();
        if imgui.Button('Settings##nai_watch_cfg') then MS.open_config('inventory'); end
        imgui.PopFont();
        local x, y = imgui.GetWindowPos();
        x, y = tonumber(x), tonumber(y);
        if x ~= nil and (math.abs(x - config.watch_window.x) >= 1 or math.abs(y - config.watch_window.y) >= 1) then
            config.watch_window.x, config.watch_window.y = x, y;
            mark_dirty();
        end
    end
    imgui.End();
    pop_theme();
end
