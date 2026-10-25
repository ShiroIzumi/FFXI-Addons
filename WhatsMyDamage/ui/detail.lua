--[[
    WhatsMyDamage - ui/detail.lua

    1) The hover breakdown over a meter row: every source grouped (melee,
       ranged, weapon skills, skillchains, magic per spell with its magic
       bursts, abilities, items, additional effects, spikes & counters),
       with amount, share and accuracy per source and overall. Pets are
       listed on their own even when they are combined with their owner.
       Kills and deaths at the bottom.

    2) The details window (click a row): a player picker, tabs for Damage /
       Healing / Taken / Deaths, summary cards, a full table per source
       (Total, %, Hits, Avg, Min, Max, Crit, Acc), misses / shadows /
       parries / resists, every monster or player it went to or came from,
       pets in their own tables, and a death recap (the last hits before
       each death). It remembers where you put it and its size.

    Accuracy = landed / (landed + missed + avoided + resisted). Skillchains,
    additional effects, spikes and counters always land, so they have none.
]]

require('common');
local imgui = require('imgui');
local theme = require('core.theme');
local data = require('core.data');
local tracker = require('core.tracker');

local detail = {
    open_flag = { false },
    sid = nil,
    tab = 1,             -- 1 damage, 2 healing, 3 taken, 4 deaths
    placed = false,
};

local MODE_TAB = { damage = 1, heal = 2, taken = 3 };
local TAB_MODE = { 'damage', 'heal', 'taken' };
local NO_ACC = { sc = true, add = true, spikes = true };

local function commas(n)
    local s = tostring(math.floor((tonumber(n) or 0) + 0.5));
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse();
    if out:sub(1, 1) == ',' then out = out:sub(2); end
    return out;
end

local function pct(a, b) if (b or 0) <= 0 then return 0; end return a * 100 / b; end

-- ============================================================================
-- Summaries
-- ============================================================================

local function tries(c) return c.hits + c.misses + c.avoided + c.resisted; end

-- Groups of one stat, in data.GROUPS order, each with its sources (biggest first).
function detail.groups(stat)
    local by = {};
    for _, c in pairs(stat.cats) do
        if c.total > 0 or tries(c) > 0 then
            local g = by[c.group];
            if g == nil then
                g = { key = c.group, label = data.GROUP_LABEL[c.group] or c.group, total = 0, hits = 0, misses = 0,
                      avoided = 0, resisted = 0, crits = 0, mb = 0, mb_total = 0, cats = {} };
                by[c.group] = g;
            end
            g.total = g.total + c.total;
            g.hits = g.hits + c.hits;
            g.misses = g.misses + c.misses;
            g.avoided = g.avoided + c.avoided;
            g.resisted = g.resisted + c.resisted;
            g.crits = g.crits + c.crits;
            g.mb = g.mb + (c.mb or 0);
            g.mb_total = g.mb_total + (c.mb_total or 0);
            g.cats[#g.cats + 1] = c;
        end
    end
    local out = {};
    for _, gd in ipairs(data.GROUPS) do
        local g = by[gd.key];
        if g ~= nil then
            table.sort(g.cats, function(a, b)
                if a.total ~= b.total then return a.total > b.total; end
                return tostring(a.name) < tostring(b.name);
            end);
            out[#out + 1] = g;
        end
    end
    return out;
end

-- Overall numbers for one stat: accuracy (sources that can miss), crit rate, biggest.
function detail.overall(stat)
    local o = { hits = 0, tries = 0, crits = 0, swings = 0, max = 0, max_name = nil, count = 0, avoid = {} };
    for _, c in pairs(stat.cats) do
        o.count = o.count + c.hits;
        if not NO_ACC[c.group] then
            o.hits = o.hits + c.hits;
            o.tries = o.tries + tries(c);
            o.crits = o.crits + c.crits;
            o.swings = o.swings + c.hits;
        end
        if c.max > o.max then o.max, o.max_name = c.max, c.name; end
        o.misses = (o.misses or 0) + c.misses;
        o.resisted = (o.resisted or 0) + c.resisted;
        for k, n in pairs(c.avoid or {}) do o.avoid[k] = (o.avoid[k] or 0) + n; end
    end
    o.acc = (o.tries > 0) and (o.hits * 100 / o.tries) or nil;
    o.crit = (o.swings > 0) and (o.crits * 100 / o.swings) or nil;
    return o;
end

local function acc_text(c, group)
    if NO_ACC[group] then return '-'; end
    local t = tries(c);
    if t == 0 then return '-'; end
    return ('%.1f%%'):format(c.hits * 100 / t);
end

-- Taken: how much of it you avoided.
local function avoid_text(c)
    local t = tries(c);
    if t == 0 then return '-'; end
    return ('%.1f%%'):format((t - c.hits) * 100 / t);
end

-- Pets of a player (combined rows carry them; otherwise look them up).
local function pets_of(sid)
    local out = {};
    for _, a in pairs(tracker.store().actors) do
        if a.pet and a.owner == sid then out[#out + 1] = a; end
    end
    table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name); end);
    return out;
end

-- ============================================================================
-- Hover breakdown
-- ============================================================================

local TT = { x = {}, k = 1 };

-- One tooltip line: name on the left, then right-aligned columns.
local function tline(name, cols, color, indent)
    local k = TT.k;
    imgui.SetCursorPosX((8 + (indent or 0) * 12) * k);
    imgui.TextColored(color or theme.UI_TEXT, name);
    for i, text in ipairs(cols) do
        if text ~= nil and text ~= '' then
            local w = tonumber((imgui.CalcTextSize(text))) or 0;
            imgui.SameLine(TT.x[i] * k - w);
            imgui.TextColored((i == 1) and theme.UI_TEXT or theme.UI_MUTED, text);
        end
    end
end

local function tooltip_stat(cfg, stat, mode, total_ref, title, title_color)
    local groups = detail.groups(stat);
    if title ~= nil then
        imgui.Spacing();
        imgui.TextColored(title_color or theme.UI_ACCENT_TEXT, title);
    end
    if #groups == 0 then
        imgui.TextColored(theme.UI_MUTED, '  nothing yet');
        return;
    end
    for _, g in ipairs(groups) do
        local c4;
        if mode == 'damage' then c4 = acc_text(g, g.key);
        elseif mode == 'taken' then c4 = avoid_text(g);
        else c4 = tostring(g.hits); end
        tline(g.label, { commas(g.total), ('%.1f%%'):format(pct(g.total, total_ref)), c4 }, theme.UI_ACCENT_TEXT, 0);
        -- A group with one source named like the group (Melee, Ranged): no extra line.
        local single = #g.cats == 1 and g.cats[1].name == g.label;
        for _, c in ipairs(g.cats) do
            if not single then
                local d4;
                if mode == 'damage' then d4 = acc_text(c, g.key);
                elseif mode == 'taken' then d4 = avoid_text(c);
                else d4 = tostring(c.hits); end
                tline(c.name, { commas(c.total), ('%.1f%%'):format(pct(c.total, total_ref)), d4 }, nil, 1);
            end
            if (c.mb or 0) > 0 then
                tline(('Magic Burst x%d'):format(c.mb), { commas(c.mb_total or 0), ('%.1f%%'):format(pct(c.mb_total or 0, total_ref)), '' }, theme.UI_WARN, 2);
            end
        end
        if g.key == 'magic' and g.mb > 0 and #g.cats > 1 then
            tline(('All Magic Bursts x%d'):format(g.mb), { commas(g.mb_total), ('%.1f%%'):format(pct(g.mb_total, total_ref)), '' }, theme.UI_WARN, 1);
        end
    end
end

function detail.tooltip(cfg, row, mode)
    if cfg.tooltip and cfg.tooltip.show == false then return; end
    local a = row.a;
    if a == nil then return; end
    local size = tonumber(cfg.tooltip and cfg.tooltip.size) or 14;
    theme.push(nil, size / 14, { border = true });
    imgui.PushFont(nil, size);
    local ok, err = pcall(function()
        imgui.BeginTooltip();
        local k = size / 14;
        TT.k = k;
        TT.x = { 250, 305, 360 };
        local label = data.MODE_LABEL[mode] or mode;
        local who = tostring(row.name or '?');
        if row.pet then who = who .. '  (' .. tostring(row.owner_name or '?') .. '\'s pet)';
        elseif a.job ~= nil and a.job ~= '' then who = who .. '  (' .. a.job .. ')'; end
        imgui.TextColored(theme.UI_WHITE, who);
        imgui.SameLine(TT.x[3] * k - (tonumber((imgui.CalcTextSize(label))) or 0));
        imgui.TextColored(theme.UI_MUTED, label);
        imgui.TextColored(theme.UI_ACCENT_TEXT, ('%s  (%.1f%% of the party)'):format(commas(row.value), row.pct or 0));
        imgui.PushStyleColor(ImGuiCol_Separator, theme.accent(0.35));
        imgui.Separator();
        imgui.PopStyleColor(1);
        local h4 = (mode == 'damage') and 'Acc' or ((mode == 'taken') and 'Avoid' or 'Count');
        tline('Source', { 'Amount', '%', h4 }, theme.UI_MUTED, 0);

        local total = row.value;
        tooltip_stat(cfg, a[mode], mode, total);
        local pets = row.pets or {};
        for _, p in ipairs(pets) do
            if p[mode].total > 0 or next(p[mode].cats) ~= nil then
                tooltip_stat(cfg, p[mode], mode, total, ('Pet: %s  -  %s'):format(tostring(p.name), commas(p[mode].total)), { 0.70, 0.85, 1.0, 1 });
            end
        end

        imgui.PushStyleColor(ImGuiCol_Separator, theme.accent(0.35));
        imgui.Separator();
        imgui.PopStyleColor(1);
        local o = detail.overall(a[mode]);
        if mode == 'damage' then
            local parts = {};
            if o.acc ~= nil then parts[#parts + 1] = ('Accuracy %.1f%%'):format(o.acc); end
            if o.crit ~= nil then parts[#parts + 1] = ('Crits %.1f%%'):format(o.crit); end
            if o.max > 0 then parts[#parts + 1] = ('Best %s (%s)'):format(commas(o.max), tostring(o.max_name)); end
            if #parts > 0 then imgui.TextColored(theme.UI_TEXT, table.concat(parts, '   ')); end
            for _, p in ipairs(pets) do
                local po = detail.overall(p.damage);
                if po.acc ~= nil then imgui.TextColored(theme.UI_MUTED, ('%s accuracy %.1f%%'):format(tostring(p.name), po.acc)); end
            end
            imgui.TextColored(theme.UI_MUTED, ('Kills %d'):format(a.kills or 0));
        elseif mode == 'heal' then
            imgui.TextColored(theme.UI_TEXT, ('Heals %d   Average %s   Best %s (%s)'):format(o.count,
                commas(o.count > 0 and a.heal.total / o.count or 0), commas(o.max), tostring(o.max_name or '-')));
        else
            local t = o.tries;
            if t > 0 then
                imgui.TextColored(theme.UI_TEXT, ('Avoided %.1f%% of attacks'):format((t - o.hits) * 100 / t));
                local bits = {};
                if (o.misses or 0) > 0 then bits[#bits + 1] = ('missed %d'):format(o.misses); end
                for kk, n in pairs(o.avoid) do
                    if kk ~= 'evaded' and kk ~= 'resisted' then bits[#bits + 1] = ('%s %d'):format(kk, n); end
                end
                if (o.resisted or 0) > 0 then bits[#bits + 1] = ('resisted %d'):format(o.resisted); end
                if #bits > 0 then imgui.TextColored(theme.UI_MUTED, table.concat(bits, ', ')); end
            end
            if o.max > 0 then imgui.TextColored(theme.UI_TEXT, ('Biggest hit taken %s (%s)'):format(commas(o.max), tostring(o.max_name))); end
        end
        local deaths = a.deaths or {};
        if #deaths > 0 then
            local last = deaths[#deaths];
            local how = last.killer and (' - last by ' .. last.killer) or '';
            local lh = last.recap and last.recap[#last.recap];
            if lh ~= nil then how = how .. (' (%s %s)'):format(tostring(lh.what), commas(lh.amount)); end
            imgui.TextColored(theme.UI_DANGER, ('Deaths %d%s'):format(#deaths, how));
        end
        imgui.TextColored(theme.with_alpha(theme.UI_MUTED, 0.7), 'Click for the full details.');
        imgui.EndTooltip();
    end);
    imgui.PopFont();
    theme.pop();
    if not ok then error(err); end
end

-- ============================================================================
-- Details window
-- ============================================================================

function detail.open(sid, mode)
    detail.sid = sid;
    detail.tab = MODE_TAB[mode] or 1;
    detail.open_flag[1] = true;
end

function detail.toggle()
    detail.open_flag[1] = not detail.open_flag[1];
end

local child_sig = nil;
local function begin_child(id, size)
    if child_sig == 1 then return imgui.BeginChild(id, size, ImGuiChildFlags_None or 0); end
    if child_sig == 2 then return imgui.BeginChild(id, size, false); end
    if child_sig == 3 then return imgui.BeginChild(id, size); end
    local ok, r = pcall(imgui.BeginChild, id, size, ImGuiChildFlags_None or 0);
    if ok then child_sig = 1; return r; end
    ok, r = pcall(imgui.BeginChild, id, size, false);
    if ok then child_sig = 2; return r; end
    child_sig = 3;
    return imgui.BeginChild(id, size);
end
detail.begin_child = begin_child;

local function U32(c) return imgui.GetColorU32(c); end

-- Summary cards: { { label, value, sub }, ... } in one row.
local function cards(list, k)
    local avail = imgui.GetContentRegionAvail();
    if type(avail) == 'table' then avail = avail.x or avail[1]; end
    avail = tonumber(avail) or 500;
    local n = #list;
    local gap = 6 * k;
    local cw = (avail - gap * (n - 1)) / n;
    local ch = 50 * k;
    local x0, y0 = imgui.GetCursorScreenPos();
    x0, y0 = tonumber(x0) or 0, tonumber(y0) or 0;
    local dl = imgui.GetWindowDrawList();
    for i, c in ipairs(list) do
        local x = x0 + (i - 1) * (cw + gap);
        dl:AddRectFilled({ x, y0 }, { x + cw, y0 + ch }, U32(theme.with_alpha(theme.UI_CONTROL, 0.85)), 5 * k);
        dl:AddRectFilled({ x, y0 }, { x + 3 * k, y0 + ch }, U32(c.color or theme.accent(0.9)), 2);
        local fs = imgui.GetFontSize();
        theme.text(dl, x + 10 * k, y0 + 5 * k, theme.UI_MUTED, c.label, fs * 0.85);
        theme.text(dl, x + 10 * k, y0 + 5 * k + fs * 0.95, theme.UI_WHITE, c.value, fs * 1.2);
        if c.sub ~= nil then
            local sw = theme.measure(c.sub, fs * 0.78);
            theme.text(dl, x + cw - sw - 6 * k, y0 + 6 * k, theme.UI_MUTED, c.sub, fs * 0.78);
        end
    end
    imgui.Dummy({ avail, ch + 4 * k });
end

-- Columns for the source tables: { header, width, right aligned }.
local COLS = {
    damage = { { 'Total', 70 }, { '%', 50 }, { 'Hits', 44 }, { 'Avg', 56 }, { 'Min', 50 }, { 'Max', 56 }, { 'Crit', 50 }, { 'Acc', 56 } },
    heal = { { 'Total', 70 }, { '%', 50 }, { 'Count', 48 }, { 'Avg', 56 }, { 'Min', 50 }, { 'Max', 56 } },
    taken = { { 'Total', 70 }, { '%', 50 }, { 'Hits', 44 }, { 'Avg', 56 }, { 'Min', 50 }, { 'Max', 56 }, { 'Crit', 50 }, { 'Avoid', 56 } },
};

local function col_values(mode, c, total, group)
    local avg = (c.hits > 0) and (c.total / c.hits) or 0;
    local v = { commas(c.total), ('%.1f%%'):format(pct(c.total, total)), tostring(c.hits), commas(avg),
        c.min and commas(c.min) or '-', commas(c.max) };
    if mode ~= 'heal' then
        v[7] = (c.hits > 0 and not NO_ACC[group]) and ('%.1f%%'):format(c.crits * 100 / c.hits) or '-';
        v[8] = (mode == 'damage') and acc_text(c, group) or avoid_text(c);
    end
    return v;
end

-- Draws one table row; bar = fraction for the mini bar behind the name.
local function table_row(mode, name, vals, k, name_w, bar, bar_color, name_color, indent)
    local cols = COLS[mode];
    local x0, y0 = imgui.GetCursorScreenPos();
    x0, y0 = tonumber(x0) or 0, tonumber(y0) or 0;
    local fs = imgui.GetFontSize();
    local rh = fs + 4 * k;
    if bar ~= nil and bar > 0 then
        local dl = imgui.GetWindowDrawList();
        local c = bar_color or theme.UI_ACCENT;
        dl:AddRectFilled({ x0, y0 }, { x0 + name_w * bar, y0 + rh }, U32({ c[1], c[2], c[3], 0.28 }), 2);
        dl:AddRectFilled({ x0, y0 + rh - 2 }, { x0 + name_w * bar, y0 + rh }, U32({ c[1], c[2], c[3], 0.75 }), 0);
    end
    local cx = imgui.GetCursorPosX();
    imgui.SetCursorPosX(cx + (4 + (indent or 0) * 12) * k);
    imgui.TextColored(name_color or theme.UI_TEXT, name);
    local x = name_w;
    for i, col in ipairs(cols) do
        x = x + col[2] * k;
        local t = vals[i] or '';
        if t ~= '' then
            local w = tonumber((imgui.CalcTextSize(t))) or 0;
            imgui.SameLine(cx + x - w);
            imgui.TextColored((i == 1) and theme.UI_WHITE or theme.UI_TEXT, t);
        end
    end
end

local function table_header(mode, k, name_w, title)
    local cols = COLS[mode];
    local cx = imgui.GetCursorPosX();
    imgui.SetCursorPosX(cx + 4 * k);
    imgui.TextColored(theme.UI_MUTED, title or 'Source');
    local x = name_w;
    for _, col in ipairs(cols) do
        x = x + col[2] * k;
        local w = tonumber((imgui.CalcTextSize(col[1]))) or 0;
        imgui.SameLine(cx + x - w);
        imgui.TextColored(theme.UI_MUTED, col[1]);
    end
    imgui.PushStyleColor(ImGuiCol_Separator, theme.accent(0.30));
    imgui.Separator();
    imgui.PopStyleColor(1);
end

local function name_width(mode, k)
    local avail = imgui.GetContentRegionAvail();
    if type(avail) == 'table' then avail = avail.x or avail[1]; end
    avail = tonumber(avail) or 600;
    local used = 0;
    for _, col in ipairs(COLS[mode]) do used = used + col[2] * k; end
    return math.max(110 * k, avail - used - 6 * k);
end

local AVOID_LABEL = { shadows = 'Shadows', parried = 'Parried', anticipated = 'Anticipated', dodged = 'Dodged', evaded = 'Evaded',
    resisted = 'Resisted', countered = 'Countered', guarded = 'Guarded', blocked = 'Blocked' };

local function source_table(cfg, mode, stat, total, k, color)
    local groups = detail.groups(stat);
    if #groups == 0 then
        imgui.TextColored(theme.UI_MUTED, 'Nothing yet.');
        return;
    end
    local nw = name_width(mode, k);
    table_header(mode, k, nw);
    local top = 0;
    for _, g in ipairs(groups) do
        for _, c in ipairs(g.cats) do top = math.max(top, c.total); end
    end
    for _, g in ipairs(groups) do
        local single = #g.cats == 1 and g.cats[1].name == g.label;
        if single then
            local c = g.cats[1];
            table_row(mode, g.label, col_values(mode, c, total, g.key), k, nw, top > 0 and c.total / top or 0, color, theme.UI_ACCENT_TEXT, 0);
        else
            -- Group line, then its sources.
            local gv = col_values(mode, g, total, g.key);
            gv[4], gv[5], gv[6] = '', '', '';
            table_row(mode, g.label, gv, k, nw, nil, nil, theme.UI_ACCENT_TEXT, 0);
            for _, c in ipairs(g.cats) do
                table_row(mode, c.name, col_values(mode, c, total, g.key), k, nw, top > 0 and c.total / top or 0, color, nil, 1);
                if (c.mb or 0) > 0 then
                    local mv = { commas(c.mb_total or 0), ('%.1f%%'):format(pct(c.mb_total or 0, total)), tostring(c.mb),
                        commas((c.mb_total or 0) / c.mb) };
                    table_row(mode, 'Magic Burst', mv, k, nw, nil, nil, theme.UI_WARN, 2);
                end
            end
        end
    end
    -- Misses / avoided / resisted.
    local o = detail.overall(stat);
    local bits = {};
    if (o.misses or 0) > 0 then bits[#bits + 1] = (mode == 'taken' and 'Missed you %d' or 'Missed %d'):format(o.misses); end
    for kk, n in pairs(o.avoid) do
        if kk ~= 'resisted' and kk ~= 'evaded' then bits[#bits + 1] = ('%s %d'):format(AVOID_LABEL[kk] or kk, n); end
    end
    if (o.resisted or 0) > 0 then bits[#bits + 1] = ('Resisted %d'):format(o.resisted); end
    if #bits > 0 then
        imgui.Spacing();
        imgui.TextColored(theme.UI_MUTED, table.concat(bits, '    '));
    end
end

-- Who it went to (damage: monsters; healing: players) or came from (taken).
local function targets_table(mode, stats, k)
    local by = {};
    for _, stat in ipairs(stats) do
        for _, c in pairs(stat.cats) do
            for who, amt in pairs(c.from or {}) do by[who] = (by[who] or 0) + amt; end
        end
    end
    local list, total = {}, 0;
    for who, amt in pairs(by) do
        if amt > 0 then list[#list + 1] = { who, amt }; total = total + amt; end
    end
    if #list == 0 then return; end
    table.sort(list, function(a, b) return a[2] > b[2]; end);
    theme.section_header(mode == 'damage' and 'TARGETS' or (mode == 'heal' and 'HEALED' or 'DAMAGE FROM'));
    local avail = imgui.GetContentRegionAvail();
    if type(avail) == 'table' then avail = avail.x or avail[1]; end
    avail = tonumber(avail) or 500;
    local dl = imgui.GetWindowDrawList();
    for i, e in ipairs(list) do
        if i > 15 then
            imgui.TextColored(theme.UI_MUTED, ('...and %d more'):format(#list - 15));
            break;
        end
        local x0, y0 = imgui.GetCursorScreenPos();
        x0, y0 = tonumber(x0) or 0, tonumber(y0) or 0;
        local fs = imgui.GetFontSize();
        dl:AddRectFilled({ x0, y0 }, { x0 + avail * 0.6 * (e[2] / list[1][2]), y0 + fs + 2 }, U32(theme.accent(0.18)), 2);
        local cx = imgui.GetCursorPosX();
        imgui.SetCursorPosX(cx + 4 * k);
        imgui.TextColored(theme.UI_TEXT, tostring(e[1]));
        local t = ('%s  (%.1f%%)'):format(commas(e[2]), pct(e[2], total));
        local w = tonumber((imgui.CalcTextSize(t))) or 0;
        imgui.SameLine(cx + avail * 0.6 + 120 * k - w);
        imgui.TextColored(theme.UI_TEXT, t);
    end
end

local function party_total(mode)
    local _, total = tracker.rows(mode, { combine = true, alliance = true });
    return total;
end

local function draw_mode(cfg, a, mode, k, job_color)
    local stat = a[mode];
    local pets = a.pet and {} or pets_of(a.sid);
    local mine = stat.total;
    for _, p in ipairs(pets) do mine = mine + p[mode].total; end
    local ptotal = party_total(mode);
    local o = detail.overall(stat);
    local list;
    if mode == 'damage' then
        list = {
            { label = 'Damage', value = commas(mine), sub = (#pets > 0) and 'with pet' or nil, color = job_color },
            { label = 'Of the party', value = ('%.1f%%'):format(pct(mine, ptotal)) },
            { label = 'Accuracy', value = o.acc and ('%.1f%%'):format(o.acc) or '-' },
            { label = 'Crit rate', value = o.crit and ('%.1f%%'):format(o.crit) or '-' },
            { label = 'Biggest hit', value = commas(o.max), sub = o.max_name },
            { label = 'Kills / Deaths', value = ('%d / %d'):format(a.kills or 0, #(a.deaths or {})) },
        };
    elseif mode == 'heal' then
        list = {
            { label = 'Healing', value = commas(mine), color = job_color },
            { label = 'Of the party', value = ('%.1f%%'):format(pct(mine, ptotal)) },
            { label = 'Heals', value = tostring(o.count) },
            { label = 'Average', value = commas(o.count > 0 and stat.total / o.count or 0) },
            { label = 'Biggest heal', value = commas(o.max), sub = o.max_name },
        };
    else
        local avoided = (o.tries > 0) and ('%.1f%%'):format((o.tries - o.hits) * 100 / o.tries) or '-';
        list = {
            { label = 'Damage taken', value = commas(mine), color = job_color },
            { label = 'Of the party', value = ('%.1f%%'):format(pct(mine, ptotal)) },
            { label = 'Avoided', value = avoided },
            { label = 'Biggest hit', value = commas(o.max), sub = o.max_name },
            { label = 'Deaths', value = tostring(#(a.deaths or {})) },
        };
    end
    cards(list, k);
    imgui.Spacing();
    theme.section_header('BY SOURCE');
    source_table(cfg, mode, stat, mine, k, job_color);
    for _, p in ipairs(pets) do
        if p[mode].total > 0 or next(p[mode].cats) ~= nil then
            theme.section_header(('PET: %s  -  %s  (%.1f%% of %s)'):format(tostring(p.name):upper(), commas(p[mode].total),
                pct(p[mode].total, mine), tostring(a.name)));
            local po = detail.overall(p[mode]);
            if mode == 'damage' and po.acc ~= nil then
                imgui.TextColored(theme.UI_MUTED, ('Accuracy %.1f%%%s'):format(po.acc, po.crit and ('   Crit rate %.1f%%'):format(po.crit) or ''));
            end
            source_table(cfg, mode, p[mode], mine, k, { 0.70, 0.85, 1.0, 1 });
        end
    end
    local stats = { stat };
    for _, p in ipairs(pets) do stats[#stats + 1] = p[mode]; end
    targets_table(mode, stats, k);
end

local function draw_deaths(a, k)
    local deaths = a.deaths or {};
    if #deaths == 0 then
        imgui.TextColored(theme.UI_MUTED, 'No deaths. Nice.');
        return;
    end
    for i = #deaths, 1, -1 do
        local d = deaths[i];
        theme.section_header(('DEATH %d  -  %s%s'):format(i, os.date('%H:%M:%S', d.t),
            d.killer and ('  -  by ' .. d.killer) or ''));
        local recap = d.recap or {};
        if #recap == 0 then
            imgui.TextColored(theme.UI_MUTED, 'No hits seen in the 30 seconds before.');
        else
            local sum = 0;
            for j = #recap, 1, -1 do
                local r = recap[j];
                sum = sum + (r.amount or 0);
                local cx = imgui.GetCursorPosX();
                imgui.TextColored(theme.UI_MUTED, ('-%ds'):format(math.max(0, d.t - (r.t or d.t))));
                imgui.SameLine(cx + 50 * k);
                imgui.TextColored(j == #recap and theme.UI_DANGER or theme.UI_TEXT, ('%s  %s'):format(tostring(r.from or '?'), tostring(r.what or '')));
                local t = commas(r.amount) .. (r.crit and ' (crit)' or '');
                local w = tonumber((imgui.CalcTextSize(t))) or 0;
                imgui.SameLine(cx + 380 * k - w);
                imgui.TextColored(theme.UI_WHITE, t);
            end
            imgui.TextColored(theme.UI_MUTED, ('%s damage in the last %d hits'):format(commas(sum), #recap));
        end
    end
end

-- Everyone in the store, biggest first (for the picker).
local function people()
    local out = {};
    for _, a in pairs(tracker.store().actors) do
        if not a.pet then out[#out + 1] = a; end
    end
    table.sort(out, function(x, y)
        if x.damage.total ~= y.damage.total then return x.damage.total > y.damage.total; end
        return tostring(x.name) < tostring(y.name);
    end);
    return out;
end

-- Press-and-hold stepping for the button just drawn: one step the moment it
-- is pressed, then repeating after a short hold.
detail.hold = nil;   -- { id, next }
function detail.hold_step(id, dir, size, dc, ctx)
    local now = os.clock();
    if imgui.IsItemActive() then
        local h = detail.hold;
        local step = false;
        if h == nil or h.id ~= id then
            detail.hold = { id = id, next = now + 0.40 };
            step = true;
        elseif now >= h.next then
            h.next = now + 0.08;
            step = true;
        end
        if step then
            local n = math.max(10, math.min(24, size + dir));
            if n ~= size then
                dc.size = n;
                ctx.dirty();
            end
        end
    elseif detail.hold ~= nil and detail.hold.id == id then
        detail.hold = nil;
    end
end

function detail.draw(cfg, ctx, job_color_fn)
    if not detail.open_flag[1] then return; end
    local dc = cfg.detail;
    local size = tonumber(dc.size) or 14;
    local k = size / 14;
    if not detail.placed then
        local x, y = tonumber(dc.x) or -1, tonumber(dc.y) or -1;
        if x < 0 or y < 0 then x, y = 200, 160; end
        local w, h = tonumber(dc.w) or -1, tonumber(dc.h) or -1;
        if w <= 0 or h <= 0 then w, h = 720 * k, 560 * k; end
        imgui.SetNextWindowPos({ x, y });
        imgui.SetNextWindowSize({ w, h });
        detail.placed = true;
    end
    theme.push(nil, k, { border = true });
    imgui.PushFont(nil, size);
    local flags = bit.bor(ImGuiWindowFlags_NoCollapse or 0, ImGuiWindowFlags_NoSavedSettings or 0);
    local st = tracker.store();
    local a = detail.sid and st.actors[detail.sid] or nil;
    local title = 'WhatsMyDamage - ' .. (a and tostring(a.name) or 'Details');
    if imgui.Begin(title .. '###wmd_detail', detail.open_flag, flags) then
        local ok, err = pcall(function()
            -- Player picker.
            local list = people();
            if a == nil and #list > 0 then a = list[1]; detail.sid = a.sid; end
            imgui.PushItemWidth(220 * k);
            local cur = a and (tostring(a.name) .. (a.pet and ' (pet)' or (a.job and (' (' .. a.job .. ')') or ''))) or 'nobody yet';
            if imgui.BeginCombo('##wmd_who', cur) then
                for _, p in ipairs(list) do
                    if imgui.Selectable(tostring(p.name) .. (p.job and ('  (' .. p.job .. ')') or '') .. '##wmdw' .. p.sid, a ~= nil and p.sid == a.sid) then
                        detail.sid = p.sid;
                        a = p;
                    end
                end
                imgui.EndCombo();
            end
            imgui.PopItemWidth();
            if a ~= nil and a.pet then
                imgui.SameLine();
                local owner = st.actors[a.owner];
                if owner ~= nil and imgui.SmallButton('Show ' .. tostring(owner.name) .. '##wmd_owner') then
                    detail.sid = owner.sid;
                    a = owner;
                end
            end
            imgui.SameLine();
            local secs = tracker.elapsed();
            imgui.TextColored(theme.UI_MUTED, ('Fight time %dm %02ds'):format(math.floor(secs / 60), secs % 60));
            -- Text size, right on the window: - and + buttons (a slider here
            -- fought with the window resizing under the mouse while dragging).
            -- They act the moment you press (not on release) and keep going
            -- while held. Fixed spot, so the ticking fight time can't move it.
            imgui.SameLine(380 * k);
            theme.align_label();
            imgui.TextColored(theme.UI_MUTED, 'Text');
            imgui.SameLine();
            imgui.SmallButton(' - ##wmd_detail_smaller');
            detail.hold_step('smaller', -1, size, dc, ctx);
            theme.tip('Smaller text (hold to keep going)');
            imgui.SameLine();
            imgui.TextColored(theme.UI_TEXT, tostring(size));
            imgui.SameLine();
            imgui.SmallButton(' + ##wmd_detail_bigger');
            detail.hold_step('bigger', 1, size, dc, ctx);
            theme.tip('Bigger text (hold to keep going; also in Settings > Text)');

            detail.tab = theme.tab_row({ 'Damage Done', 'Healing Done', 'Damage Taken', 'Deaths' }, detail.tab, 'wmd_dtab', k);
            if a == nil then
                imgui.TextColored(theme.UI_MUTED, 'No data yet.');
                return;
            end
            begin_child('##wmd_detail_body', { 0, 0 });
            local jc = job_color_fn(a.pet and (st.actors[a.owner] or {}).job or a.job);
            if detail.tab == 4 then
                draw_deaths(a, k);
            else
                draw_mode(cfg, a, TAB_MODE[detail.tab], k, jc);
            end
            imgui.Dummy({ 1, 6 * k });
            imgui.EndChild();
        end);
        if not ok then ctx.error('details window', err); end
        -- Remember place and size.
        if not imgui.IsMouseDown(0) then
            local x, y = imgui.GetWindowPos();
            local w, h = imgui.GetWindowSize();
            x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h);
            if x and y and w and h then
                x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h);
                if x ~= dc.x or y ~= dc.y or w ~= dc.w or h ~= dc.h then
                    dc.x, dc.y, dc.w, dc.h = x, y, w, h;
                    ctx.dirty();
                end
            end
        end
    end
    imgui.End();
    imgui.PopFont();
    theme.pop();
    if not detail.open_flag[1] then detail.placed = false; end
end

return detail;
