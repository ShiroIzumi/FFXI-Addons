--[[
    cfgkit.lua - the settings window in MogSuite's layout (Izumi, 2026-11-02)

    One file, the same in every addon that uses it:
      * a search box at the top: finds any setting on any page by its name
        or help text, shows each page's title before its matches and how
        many there are
      * a sidebar with colored sections (a colored bar and the section's
        name in capitals) and their pages; the page you are on is marked
        with the section's color
      * each page starts with "Section  /  Page", a line about what it is
        for, and a line in the section's color
      * theme swatches at the top right (when the addon has themes)

    Use:
      local kit = require('cfgkit');
      kit.draw({
          id = 'pr', title = 'PartyRecast Settings', open = open_tbl,
          pos = cfg.config_pos, scale = s, dirty = fn,
          groups = { { label = 'Bars', color = {r,g,b,1}, pages = {
              { key = 'bars', label = 'Bars & colors', desc = '...', draw = fn, keywords = '...' }, ... } }, ... },
          page = cfg.config_page, set_page = function(key) ... end,
          theme = theme_module, theme_key = key, set_theme = function(key) ... end,
          push = function() end, pop = function() end,     -- the addon's own look / font
          after_begin = function() end,                     -- optional, right after Begin
          before_end = function() end,                      -- optional, right before End (when it was open)
          flags = ImGuiWindowFlags_NoNav,                  -- optional extra window flags
          begin = fn, finish = fn,                          -- optional: the addon opens / closes the window
          status = 'Saved per character',
      });
    In page code: kit.want(label, help, ...) before a setting (false = skip it
    while searching), kit.header(title) for a section heading (hidden while
    searching), kit.searching().

    While searching, each page is first tried out of sight to see whether it
    has matches; a page with matches shows only those, a page whose name or
    keywords match shows whole.
]]

require('common');
local imgui = require('imgui');

local kit = {
    Q = '',
    mode = nil,        -- nil | 'probe' | 'search'
    hits = 0,
    pending = nil,
    search = {},       -- [id] = { '' }
    placed = {},
    last_hits = {},
    th = nil,
    s = 1,
};

local function lower(x) return tostring(x or ''):lower(); end

function kit.searching() return kit.Q ~= '' and (kit.mode == 'probe' or kit.mode == 'search'); end

local function col(name, def)
    local th = kit.th;
    local c = th and th[name];
    if type(c) == 'table' then return c; end
    return def;
end

local function tip(text)
    if text == nil or text == '' then return; end
    if kit.th ~= nil and type(kit.th.tip) == 'function' then kit.th.tip(text); return; end
    if imgui.IsItemHovered() then
        imgui.BeginTooltip();
        imgui.PushTextWrapPos(380);
        imgui.TextUnformatted(text);
        imgui.PopTextWrapPos();
        imgui.EndTooltip();
    end
end
kit.tip = tip;

-- "Section  /  Page", a line about it, a line in the section's color.
function kit.page_title(title, desc, c)
    c = c or col('UI_ACCENT', { 0.5, 0.6, 0.9, 1 });
    local s = kit.s;
    local x, y = imgui.GetCursorScreenPos();
    x, y = tonumber(x) or 0, tonumber(y) or 0;
    local h = imgui.GetTextLineHeight();
    imgui.GetWindowDrawList():AddRectFilled({ x, y + 1 }, { x + 3 * s, y + h - 1 }, imgui.GetColorU32({ c[1], c[2], c[3], 1 }), 1);
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 9 * s);
    imgui.TextColored(col('UI_ACCENT_TEXT', { 0.8, 0.85, 1, 1 }), title);
    if desc ~= nil and desc ~= '' then
        imgui.PushTextWrapPos(0);
        imgui.TextColored(col('UI_MUTED', { 0.62, 0.62, 0.66, 1 }), desc);
        imgui.PopTextWrapPos();
    end
    imgui.PushStyleColor(ImGuiCol_Separator, { c[1], c[2], c[3], 0.45 });
    imgui.Separator();
    imgui.PopStyleColor(1);
    imgui.Spacing();
end

-- Should a setting with this text be drawn? (Always, unless searching.)
function kit.want(...)
    if kit.Q == '' or kit.mode == nil or kit.mode == 'all' then return true; end
    for _, t in ipairs({ ... }) do
        if t ~= nil and lower(t):find(kit.Q, 1, true) then
            kit.hits = kit.hits + 1;
            if kit.mode == 'search' and kit.pending ~= nil then
                if kit.drawn_titles > 0 then imgui.Spacing(); imgui.Spacing(); end
                kit.page_title(kit.pending[1], nil, kit.pending[2]);
                kit.pending = nil;
                kit.drawn_titles = kit.drawn_titles + 1;
            end
            return true;
        end
    end
    return false;
end

-- A section heading (accent text and a faint line), hidden while searching.
function kit.header(title)
    if kit.searching() then return; end
    imgui.Spacing();
    imgui.TextColored(col('UI_ACCENT_TEXT', { 0.8, 0.85, 1, 1 }), title);
    local a = col('UI_ACCENT', { 0.5, 0.6, 0.9, 1 });
    imgui.PushStyleColor(ImGuiCol_Separator, { a[1], a[2], a[3], 0.35 });
    imgui.Separator();
    imgui.PopStyleColor(1);
    imgui.Spacing();
end

local function child(id, size)
    local th = kit.th;
    if th ~= nil and type(th.child) == 'function' then return th.child(id, size, false); end
    return imgui.BeginChild(id, size, false);
end

local function sidebar(o, cur_key, w, h)
    local s = kit.s;
    child('##' .. o.id .. '_nav', { w, h });
    pcall(function()
        local x, y = imgui.GetWindowPos();
        x, y = tonumber(x) or 0, tonumber(y) or 0;
        local c = col('UI_CONTROL', { 0.1, 0.1, 0.11, 1 });
        imgui.GetWindowDrawList():AddRectFilled({ x, y }, { x + w, y + h }, imgui.GetColorU32({ c[1], c[2], c[3], 0.55 }), 6 * s);
    end);
    imgui.Dummy({ 1, 4 * s });
    local dim = kit.Q ~= '';
    local picked = cur_key;
    local text = col('UI_TEXT', { 0.93, 0.93, 0.95, 1 });
    for gi, g in ipairs(o.groups) do
        if gi > 1 then imgui.Dummy({ 1, 7 * s }); end
        local c = g.color or col('UI_ACCENT', { 0.5, 0.6, 0.9, 1 });
        imgui.SetCursorPosX(10 * s);
        local hx, hy = imgui.GetCursorScreenPos();
        hx, hy = tonumber(hx) or 0, tonumber(hy) or 0;
        local th = imgui.GetTextLineHeight();
        imgui.GetWindowDrawList():AddRectFilled({ hx - 4 * s, hy + 2 }, { hx - 2 * s, hy + th - 2 }, imgui.GetColorU32({ c[1], c[2], c[3], dim and 0.5 or 1 }), 1);
        imgui.TextColored({ c[1], c[2], c[3], dim and 0.55 or 0.95 }, tostring(g.label):upper());
        for _, p in ipairs(g.pages) do
            local on = (cur_key == p.key) and not dim;
            imgui.SetCursorPosX(6 * s);
            imgui.PushStyleColor(ImGuiCol_Text, on and col('UI_ACCENT_TEXT', { 0.8, 0.85, 1, 1 }) or { text[1], text[2], text[3], dim and 0.5 or 1 });
            imgui.PushStyleColor(ImGuiCol_Header, { c[1], c[2], c[3], 0.16 });
            imgui.PushStyleColor(ImGuiCol_HeaderHovered, { c[1], c[2], c[3], 0.12 });
            imgui.PushStyleColor(ImGuiCol_HeaderActive, { c[1], c[2], c[3], 0.22 });
            if imgui.Selectable('   ' .. p.label .. '##' .. o.id .. '_nav_' .. p.key, on, 0, { w - 12 * s, 0 }) then
                picked = p.key;
                kit.search[o.id][1] = '';
            end
            imgui.PopStyleColor(4);
            if p.desc ~= nil then tip(p.desc); end
            if on then
                pcall(function()
                    local x1, y1 = imgui.GetItemRectMin();
                    local _, y2 = imgui.GetItemRectMax();
                    imgui.GetWindowDrawList():AddRectFilled({ x1, y1 + 2 * s }, { x1 + 3 * s, y2 - 2 * s }, imgui.GetColorU32({ c[1], c[2], c[3], 1 }), 1);
                end);
            end
        end
    end
    imgui.Dummy({ 1, 6 * s });
    imgui.EndChild();
    return picked;
end

local function find_page(groups, key)
    for _, g in ipairs(groups) do
        for _, p in ipairs(g.pages) do if p.key == key then return g, p; end end
    end
    return groups[1], groups[1].pages[1];
end
kit.find_page = find_page;

-- Opens a page (from a button somewhere else).
function kit.reset_search(id) if kit.search[id] ~= nil then kit.search[id][1] = ''; end end
function kit.replace(id) kit.placed[id] = nil; end

local function run(p)
    local ok, err = pcall(p.draw);
    if not ok then imgui.TextColored(col('UI_DANGER', { 0.9, 0.36, 0.36, 1 }), tostring(err)); end
end

function kit.draw(o)
    if o.open ~= nil and not o.open[1] then return; end
    kit.th = o.theme;
    local s = tonumber(o.scale) or 1;
    kit.s = s;
    kit.search[o.id] = kit.search[o.id] or { '' };
    local pos = o.pos or {};
    local own = o.begin == nil;   -- false: the addon opens / closes the window itself (o.begin / o.finish)
    if own and not kit.placed[o.id] then
        local x, y = tonumber(pos.x) or -1, tonumber(pos.y) or -1;
        if x < 0 or y < 0 then x, y = (o.default_pos and o.default_pos[1]) or 200, (o.default_pos and o.default_pos[2]) or 140; end
        local w, h = tonumber(pos.w) or -1, tonumber(pos.h) or -1;
        if w <= 0 or h <= 0 then
            w, h = ((o.default_size and o.default_size[1]) or 820) * s, ((o.default_size and o.default_size[2]) or 600) * s;
            pcall(function()
                local dh = tonumber(imgui.GetIO().DisplaySize.y);
                if dh ~= nil and dh > 300 then h = math.min(h, dh - 80); end
            end);
        end
        imgui.SetNextWindowPos({ x, y });
        imgui.SetNextWindowSize({ w, h });
        kit.placed[o.id] = true;
    end
    local visible;
    if own then
        if imgui.SetNextWindowSizeConstraints ~= nil then pcall(imgui.SetNextWindowSizeConstraints, { 560, 340 }, { 5000, 5000 }); end
        if o.push ~= nil then o.push(); end
        local flags = bit.bor(ImGuiWindowFlags_NoCollapse or 0, ImGuiWindowFlags_NoSavedSettings or 0, o.flags or 0);
        visible = imgui.Begin(o.title .. '##' .. o.id .. '_cfgkit', o.open, flags);
    else
        visible = o.begin();
    end
    if visible then
        if o.after_begin ~= nil then pcall(o.after_begin); end
        local ok, err = pcall(function()
            local nav_w = (o.nav_width or 175) * s;
            local aw, ah = imgui.GetContentRegionAvail();
            if type(aw) == 'table' then aw, ah = aw.x or aw[1], aw.y or aw[2]; end
            aw, ah = tonumber(aw) or 600, tonumber(ah) or 500;

            -- Search box, status, theme swatches.
            imgui.PushItemWidth(nav_w);
            -- TAB never lands in the search box (it keeps targeting in game).
            local notab = 0;
            if imgui.PushItemFlag ~= nil and ImGuiItemFlags_NoTabStop ~= nil then
                imgui.PushItemFlag(ImGuiItemFlags_NoTabStop, true); notab = 1;
            elseif imgui.PushAllowKeyboardFocus ~= nil then
                imgui.PushAllowKeyboardFocus(false); notab = 2;
            end
            if imgui.InputTextWithHint ~= nil then
                imgui.InputTextWithHint('##' .. o.id .. '_search', 'Search settings...', kit.search[o.id], 64);
            else
                imgui.InputText('##' .. o.id .. '_search', kit.search[o.id], 64);
            end
            if notab == 1 then imgui.PopItemFlag(); elseif notab == 2 then imgui.PopAllowKeyboardFocus(); end
            imgui.PopItemWidth();
            tip('Type part of a setting\'s name (or what it does) to find it on any page.');
            kit.Q = lower(kit.search[o.id][1]):gsub('^%s+', ''):gsub('%s+$', '');
            imgui.SameLine();
            if kit.Q ~= '' then
                if imgui.SmallButton('Clear##' .. o.id .. '_sclear') then kit.search[o.id][1] = ''; kit.Q = ''; end
                imgui.SameLine();
                local n = kit.last_hits[o.id] or 0;
                imgui.TextColored(col('UI_MUTED', { 0.62, 0.62, 0.66, 1 }), ('%d result%s for "%s"'):format(n, n == 1 and '' or 's', kit.Q));
            else
                if imgui.AlignTextToFramePadding ~= nil then imgui.AlignTextToFramePadding(); end
                imgui.TextColored(col('UI_MUTED', { 0.62, 0.62, 0.66, 1 }), o.status or 'Saved per character');
            end
            local th = o.theme;
            if o.set_theme ~= nil and th ~= nil and type(th.ORDER) == 'table' and type(th.THEMES) == 'table' then
                local sw, sh = 16 * s, 12 * s;
                local total = #th.ORDER * (sw + 4 * s);
                imgui.SameLine(math.max(imgui.GetCursorPosX(), aw - total + 8 * s));
                for i, key in ipairs(th.ORDER) do
                    local t = th.THEMES[key];
                    if t ~= nil then
                        if i > 1 then imgui.SameLine(0, 4 * s); end
                        local a = t.accent or { 128, 128, 128 };
                        local k = (a[1] > 1 or a[2] > 1 or a[3] > 1) and 255 or 1;
                        imgui.PushStyleColor(ImGuiCol_Button, { a[1] / k, a[2] / k, a[3] / k, 1.0 });
                        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { a[1] / k, a[2] / k, a[3] / k, 0.85 });
                        imgui.PushStyleColor(ImGuiCol_ButtonActive, { a[1] / k, a[2] / k, a[3] / k, 0.70 });
                        if imgui.Button('##' .. o.id .. '_qt_' .. key, { sw, sh }) then o.set_theme(key); end
                        imgui.PopStyleColor(3);
                        tip(tostring(t.label or key) .. ' theme');
                        if key == o.theme_key then
                            pcall(function()
                                local x1 = imgui.GetItemRectMin();
                                local x2, y2 = imgui.GetItemRectMax();
                                imgui.GetWindowDrawList():AddRectFilled({ tonumber(x1) + 2, tonumber(y2) + 1 }, { tonumber(x2) - 2, tonumber(y2) + 3 }, imgui.GetColorU32({ 1, 1, 1, 0.9 }), 1);
                            end);
                        end
                    end
                end
            end

            local h = math.max(150, ah - imgui.GetFrameHeightWithSpacing() - 4 * s);
            local cg, cp = find_page(o.groups, o.page);
            local picked = sidebar(o, cp.key, nav_w, h);
            if picked ~= cp.key then
                if o.set_page ~= nil then o.set_page(picked); end
                cg, cp = find_page(o.groups, picked);
                if o.dirty ~= nil then o.dirty(); end
            end
            imgui.SameLine(0, 10 * s);

            child('##' .. o.id .. '_body', { math.max(200, aw - nav_w - 10 * s), h });
            if o.item_width ~= nil then imgui.PushItemWidth(o.item_width * s); end
            if kit.Q ~= '' then
                local total = 0;
                kit.drawn_titles = 0;
                for _, g in ipairs(o.groups) do
                    for _, p in ipairs(g.pages) do
                        -- Out of sight first: does it have matches?
                        kit.mode, kit.hits, kit.pending = 'probe', 0, nil;
                        if imgui.BeginChild('##' .. o.id .. '_probe_' .. p.key, { 1, 1 }, false) then pcall(p.draw); end
                        imgui.EndChild();
                        local n = kit.hits;
                        if n > 0 then
                            kit.mode, kit.hits = 'search', 0;
                            kit.pending = { g.label .. '  /  ' .. p.label, g.color };
                            run(p);
                            total = total + n;
                        else
                            local words = lower(p.label) .. ' ' .. lower(p.desc) .. ' ' .. lower(p.keywords);
                            if words:find(kit.Q, 1, true) then
                                if kit.drawn_titles > 0 then imgui.Spacing(); imgui.Spacing(); end
                                kit.page_title(g.label .. '  /  ' .. p.label, p.desc, g.color);
                                kit.drawn_titles = kit.drawn_titles + 1;
                                kit.mode = 'all';
                                run(p);
                                total = total + 1;
                            end
                        end
                    end
                end
                kit.mode, kit.pending = nil, nil;
                kit.last_hits[o.id] = total;
                if total == 0 then
                    local m = col('UI_MUTED', { 0.62, 0.62, 0.66, 1 });
                    imgui.TextColored(m, 'No setting matches that.');
                    imgui.TextColored(m, 'Try a shorter word, like "color", "size", "lock" or "key".');
                end
            else
                kit.mode = nil;
                kit.page_title(cg.label .. '  /  ' .. cp.label, cp.desc, cg.color);
                run(cp);
            end
            kit.mode = nil;
            if o.item_width ~= nil then imgui.PopItemWidth(); end
            imgui.Dummy({ 1, 8 * s });
            imgui.EndChild();
        end);
        kit.mode = nil;
        if not ok then imgui.TextColored(col('UI_DANGER', { 0.9, 0.36, 0.36, 1 }), tostring(err)); end

        if own and o.pos ~= nil and not imgui.IsMouseDown(0) then
            local x, y = imgui.GetWindowPos();
            local w, h = imgui.GetWindowSize();
            x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h);
            if x and y and w and h then
                x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h);
                if x ~= pos.x or y ~= pos.y or w ~= pos.w or h ~= pos.h then
                    pos.x, pos.y, pos.w, pos.h = x, y, w, h;
                    if o.dirty ~= nil then o.dirty(); end
                end
            end
        end
    end
    if visible and o.before_end ~= nil then pcall(o.before_end); end
    if own then
        imgui.End();
        if o.pop ~= nil then o.pop(); end
    else
        o.finish();
    end
end

-- ============================================================================
-- kit.filter(imgui): an imgui that skips, while searching, every widget whose
-- label doesn't match (for page code written without kit.want). Plain text
-- and separators hide while searching; a widget is also matched against the
-- short text (a label, 40 characters or less) drawn just before it; a widget
-- with no label of its own ('##id') is shown with that text. Everything inside an open combo / popup / tooltip shows.
-- ============================================================================
local WIDGETS = {
    Checkbox = true, SliderFloat = true, SliderInt = true, SliderFloat2 = true, SliderInt2 = true,
    DragFloat = true, DragInt = true, DragFloat2 = true, DragInt2 = true,
    ColorEdit3 = true, ColorEdit4 = true, ColorButton = true, ColorPicker3 = true, ColorPicker4 = true,
    Combo = true, InputText = true, InputTextWithHint = true, InputInt = true, InputFloat = true, InputTextMultiline = true,
    Button = true, SmallButton = true, ArrowButton = true, RadioButton = true, Selectable = true, CheckboxFlags = true,
};
local OPENERS = { BeginCombo = 'EndCombo', BeginPopup = 'EndPopup', BeginPopupContextItem = 'EndPopup', BeginPopupContextWindow = 'EndPopup', BeginTooltip = 'EndTooltip', BeginPopupModal = 'EndPopup' };
local CLOSERS = { EndCombo = true, EndPopup = true, EndTooltip = true };
local DRAWS = { Dummy = true, Image = true, ImageButton = true, InvisibleButton = true, ProgressBar = true, BeginChild = true, BeginTable = true, PlotLines = true, PlotHistogram = true, TreeNode = true, CollapsingHeader = true };
local TEXTS = { Text = 1, TextColored = 2, TextWrapped = 1, TextDisabled = 1, TextUnformatted = 1, BulletText = 1, LabelText = 1, Separator = 0, Bullet = 0 };

function kit.filter(real)
    local f = { pass = 0, skipped = false, line = nil, ctx = nil };
    local cache = {};
    local function label_of(l) return (tostring(l or ''):gsub('##.*$', '')); end
    local function flush_line()
        if f.line ~= nil then real.SameLine(unpack(f.line)); f.line = nil; end
    end
    return setmetatable({}, { __index = function(_, k)
        if cache[k] ~= nil then return cache[k]; end
        if k == 'kit_flush' then return flush_line; end
        if k == 'kit_skip' then return function() f.skipped = true; f.line = nil; end; end
        local fn = real[k];
        if type(fn) ~= 'function' then return fn; end
        local w;
        if WIDGETS[k] or k == 'BeginCombo' then
            w = function(lbl, ...)
                if not kit.searching() or f.pass > 0 then flush_line(); f.skipped = false; return fn(lbl, ...); end
                local l = label_of(lbl);
                local ok, shown = false, nil;
                if l ~= '' then ok = kit.want(l); end
                if not ok and f.ctx ~= nil and (l == '' or #f.ctx[1] <= 40) then
                    ok = kit.want(f.ctx[1]);
                    if ok and l == '' and not f.ctx.done then shown = f.ctx; end
                end
                if not ok then f.skipped = true; f.line = nil; return false; end
                if shown ~= nil then shown.done = true; shown[2](unpack(shown[3])); real.SameLine(); f.line = nil; else flush_line(); end
                f.skipped = false;
                return fn(lbl, ...);
            end;
            if k == 'BeginCombo' then
                local inner = w;
                w = function(...) local r = inner(...); if r then f.pass = f.pass + 1; end return r; end;
            end
        elseif OPENERS[k] then
            w = function(...) local r = fn(...); if r and kit.searching() then f.pass = f.pass + 1; end return r; end;
        elseif CLOSERS[k] then
            w = function(...) if f.pass > 0 then f.pass = f.pass - 1; end return fn(...); end;
        elseif TEXTS[k] ~= nil then
            w = function(...)
                if not kit.searching() or f.pass > 0 then flush_line(); return fn(...); end
                local args = { ... };
                local t = TEXTS[k] == 2 and args[2] or args[1];
                if t ~= nil and TEXTS[k] > 0 then f.ctx = { tostring(t), fn, args }; end
                f.line = nil;
                return nil;
            end;
        elseif k == 'SameLine' then
            w = function(...)
                if not kit.searching() or f.pass > 0 then return fn(...); end
                if f.skipped then return; end
                f.line = { ... };
            end;
        elseif k == 'IsItemHovered' or k == 'IsItemActive' or k == 'IsItemClicked' or k == 'IsItemDeactivatedAfterEdit' then
            w = function(...) if kit.searching() and f.pass == 0 and f.skipped then return false; end return fn(...); end;
        elseif k == 'Spacing' or k == 'NewLine' then
            w = function(...) if kit.searching() and f.pass == 0 then return; end return fn(...); end;
        elseif DRAWS[k] then
            w = function(...) if f.pass == 0 then flush_line(); end return fn(...); end;
        else
            w = fn;
        end
        cache[k] = w;
        return w;
    end });
end

return kit;
