--[[
    cfgui.lua - the settings window kit (same layout as MogSuite's settings)

    Used by MobHunt (and, later, the other single addons) so every settings
    window looks and works the same:

      * a search box at the top finds any setting by its name or help text
        and lists the matches grouped by page
      * "Saved per character" and the theme swatches on the same line
      * a sidebar on the left: groups (GENERAL, WINDOWS, LOOK ...) with the
        pages under them; the open page has an accent bar
      * the page on the right: its title with an accent bar, one line about
        what it is for, then its sections
      * settings in two columns: the name on the left, the control at a
        fixed column on the right (checkboxes keep their label on the
        right); options that only matter when another one is on sit
        indented under it (ui.sub)

    The addon gives the kit its colors and a few helpers once:
      ui.theme = { text, muted, accent, accent_text, control, danger,
                   section_header(title), help_marker(tip), tip(text),
                   toggle_button(label, id, selected, size), align_label() }
    (the color tables are read every frame, so a theme change shows at once).

    Each page saves through ui.set_dirty(fn) (the window sets it before
    drawing the pages).
]]

require('common');
local imgui = require('imgui');

local ui = {
    LABEL_W = 210,
    SLIDER_W = 230,
    scale = 1.0,
    theme = nil,
    SCALES = { 0.85, 1.00, 1.25, 1.50, 1.75, 2.00 },
};

local S = {
    q = '', page = nil, page_match = false, page_drawn = false,
    sec = nil, sec_match = false, sec_drawn = false, hits = 0,
    dirty = function() end,
    search = { '' }, last_hits = 0,
};
ui.S = S;

local function T_() return ui.theme; end
local function sc() return ui.scale or 1; end
local function clean(text) return (tostring(text or ''):gsub('##.*$', '')); end

function ui.set_query(q) S.q = tostring(q or ''):lower():gsub('^%s+', ''):gsub('%s+$', ''); end
function ui.searching() return S.q ~= ''; end
function ui.set_dirty(fn) S.dirty = fn or function() end; end
function ui.dirty() S.dirty(); end

local function matches(text)
    return text ~= nil and clean(text):lower():find(S.q, 1, true) ~= nil;
end
ui.matches = matches;

local function tip(text)
    if text == nil or text == '' then return; end
    local t = T_();
    if t ~= nil and t.tip ~= nil then t.tip(text); return; end
    if imgui.IsItemHovered() then imgui.SetTooltip(text); end
end
ui.tip = tip;

-- ----------------------------------------------------------------------------
-- Page / section
-- ----------------------------------------------------------------------------

local function page_title(title, desc)
    local t = T_();
    local c = t.accent;
    local x, y = imgui.GetCursorScreenPos();
    x, y = tonumber(x) or 0, tonumber(y) or 0;
    local h = imgui.GetTextLineHeight();
    imgui.GetWindowDrawList():AddRectFilled({ x, y + 1 }, { x + 3 * sc(), y + h - 1 }, imgui.GetColorU32({ c[1], c[2], c[3], 1 }), 1);
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 9 * sc());
    imgui.TextColored(t.accent_text, title);
    if desc ~= nil and desc ~= '' and not ui.searching() then
        imgui.PushTextWrapPos(0);
        imgui.TextColored(t.muted, desc);
        imgui.PopTextWrapPos();
    end
    imgui.PushStyleColor(ImGuiCol_Separator, { c[1], c[2], c[3], 0.45 });
    imgui.Separator();
    imgui.PopStyleColor(1);
    imgui.Spacing();
end

function ui.page(title, desc)
    S.page, S.page_match, S.page_drawn = title, ui.searching() and matches(title), false;
    S.sec, S.sec_match, S.sec_drawn = nil, false, false;
    if not ui.searching() then page_title(title, desc); end
end

function ui.section(title)
    S.sec, S.sec_match, S.sec_drawn = title, ui.searching() and matches(title), false;
    if not ui.searching() then
        imgui.Spacing();
        T_().section_header(title);
    end
end

-- Should something with this text (and help) be drawn? Draws the pending
-- page / section titles before the first match while searching.
function ui.want(text, help_text)
    if not ui.searching() then return true; end
    local ok = S.page_match or S.sec_match or matches(text) or matches(help_text);
    if not ok then return false; end
    if not S.page_drawn then
        if S.hits > 0 then imgui.Spacing(); imgui.Spacing(); end
        page_title(S.page or '', nil);
        S.page_drawn = true;
    end
    if not S.sec_drawn and S.sec ~= nil then
        T_().section_header(S.sec);
        S.sec_drawn = true;
    end
    S.hits = S.hits + 1;
    return true;
end

function ui.sub(fn)
    imgui.Indent(18 * sc());
    fn();
    imgui.Unindent(18 * sc());
end

-- Name on the left, then the cursor at the control column.
function ui.label(text, help_text)
    T_().align_label();
    imgui.TextColored(T_().muted, clean(text));
    if help_text then tip(help_text); end
    imgui.SameLine();
    imgui.SetCursorPosX(ui.LABEL_W * sc());
end

local function help(help_text)
    if help_text ~= nil and help_text ~= '' then T_().help_marker(help_text); end
end

-- ----------------------------------------------------------------------------
-- Controls. Value-table controls bind to tbl[key]; "ref" controls bind to an
-- ImGui-style { value } table (opts.ref = true: tbl is that table, key = 1).
-- opts.default_on: a missing value counts as on. opts.on_change(v).
-- ----------------------------------------------------------------------------

function ui.check(text, tbl, key, help_text, opts)
    if not ui.want(text, help_text) then return false; end
    opts = opts or {};
    local cur;
    if opts.default_on then cur = tbl[key] ~= false; else cur = tbl[key] == true; end
    local v = { cur };
    local changed = false;
    if imgui.Checkbox(clean(text) .. '##cfgui_' .. tostring(tbl) .. tostring(key), v) then
        tbl[key] = v[1];
        if opts.on_change then opts.on_change(v[1]); end
        ui.dirty();
        changed = true;
    end
    help(help_text);
    return changed;
end

-- opts.mul: shown value = stored * mul (100 for a percent).
function ui.slider_f(text, tbl, key, lo, hi, fmt, help_text, opts)
    if not ui.want(text, help_text) then return false; end
    opts = opts or {};
    local mul = opts.mul or 1;
    ui.label(text, help_text);
    imgui.PushItemWidth(ui.SLIDER_W * sc());
    local v = { (tonumber(tbl[key]) or (lo / mul)) * mul };
    local changed = false;
    if imgui.SliderFloat('##cfguif_' .. tostring(tbl) .. tostring(key), v, lo, hi, fmt or '%.2f', ImGuiSliderFlags_AlwaysClamp or 0) then
        tbl[key] = math.max(lo, math.min(hi, v[1])) / mul;
        if opts.on_change then opts.on_change(); end
        ui.dirty();
        changed = true;
    end
    imgui.PopItemWidth();
    return changed;
end

function ui.slider_i(text, tbl, key, lo, hi, fmt, help_text, opts)
    if not ui.want(text, help_text) then return false; end
    opts = opts or {};
    ui.label(text, help_text);
    imgui.PushItemWidth(ui.SLIDER_W * sc());
    local cur = math.floor(tonumber(tbl[key]) or lo);
    local v = { cur };
    local f = fmt;
    if type(fmt) == 'function' then f = fmt(cur); end
    local changed = false;
    if imgui.SliderInt('##cfguii_' .. tostring(tbl) .. tostring(key), v, lo, hi, f or '%d', ImGuiSliderFlags_AlwaysClamp or 0) then
        tbl[key] = math.max(lo, math.min(hi, math.floor(v[1])));
        if opts.on_change then opts.on_change(); end
        ui.dirty();
        changed = true;
    end
    imgui.PopItemWidth();
    return changed;
end

-- Edits the color table in place (other code keeps references to it).
function ui.color(text, tbl, help_text, with_alpha)
    if not ui.want(text, help_text) then return false; end
    ui.label(text, help_text);
    local changed;
    if with_alpha then
        changed = imgui.ColorEdit4('##cfguic_' .. tostring(tbl), tbl, ImGuiColorEditFlags_NoInputs or 0);
    else
        changed = imgui.ColorEdit3('##cfguic_' .. tostring(tbl), tbl, ImGuiColorEditFlags_NoInputs or 0);
    end
    if changed then ui.dirty(); end
    return changed;
end

-- A few options as toggle buttons. options = { { key, label, tip }, ... }
function ui.choice(text, tbl, key, options, help_text, opts)
    if not ui.want(text, help_text) then return false; end
    opts = opts or {};
    ui.label(text, help_text);
    local cur = tbl[key];
    if cur == nil then cur = opts.default; end
    local new = cur;
    for i, o in ipairs(options) do
        if i > 1 then imgui.SameLine(0, 4); end
        if T_().toggle_button(o.label, 'cfguich_' .. tostring(tbl) .. tostring(key) .. '_' .. tostring(o.key), cur == o.key) then
            new = o.key;
        end
        if o.tip then tip(o.tip); end
    end
    if new ~= cur then
        tbl[key] = new;
        if opts.on_change then opts.on_change(new); end
        ui.dirty();
        return true;
    end
    return false;
end

-- Window size presets (85% .. 200%) as toggle buttons.
function ui.scale_presets(text, tbl, key, help_text, opts)
    if not ui.want(text, (help_text or '') .. ' size scale percent') then return false; end
    opts = opts or {};
    ui.label(text, help_text);
    local cur = tonumber(tbl[key]) or 1.0;
    local changed = false;
    for i, v in ipairs(ui.SCALES) do
        if i > 1 then imgui.SameLine(0, 4); end
        if T_().toggle_button(('%d%%'):format(math.floor(v * 100 + 0.5)), 'cfguisc_' .. tostring(tbl) .. tostring(key) .. i, math.abs(cur - v) < 0.01) then
            tbl[key] = v;
            changed = true;
        end
    end
    if changed then
        if opts.on_change then opts.on_change(); end
        ui.dirty();
    end
    return changed;
end

-- A button at the control column (label = button text). Returns clicked.
function ui.button(text, id, help_text)
    if not ui.want(text, help_text) then return false; end
    imgui.SetCursorPosX(ui.LABEL_W * sc());
    local clicked = imgui.Button(clean(text) .. '##' .. id);
    if help_text then tip(help_text); end
    return clicked;
end

-- Two clicks (red in between). armed is a table the caller keeps.
function ui.danger(text, id, armed, help_text)
    if not ui.want(text, help_text) then return false; end
    imgui.SetCursorPosX(ui.LABEL_W * sc());
    local on = armed[id] ~= nil and os.clock() - armed[id] < 3.0;
    if on then
        imgui.PushStyleColor(ImGuiCol_Button, { 0.72, 0.16, 0.16, 1.0 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.82, 0.22, 0.22, 1.0 });
    end
    local clicked = imgui.Button((on and 'Click again to confirm' or clean(text)) .. '##' .. id);
    if on then imgui.PopStyleColor(2); end
    if help_text then tip(help_text); end
    if clicked then
        if on then armed[id] = nil; return true; end
        armed[id] = os.clock();
    end
    return false;
end

-- Muted help text (hidden while searching unless it matches).
function ui.info(text)
    if ui.searching() and not ui.want(text) then return; end
    imgui.PushTextWrapPos(0);
    imgui.TextColored(T_().muted, text);
    imgui.PopTextWrapPos();
end

-- A name / value line (read-only information).
function ui.value(text, value, color)
    if not ui.want(text) then return; end
    ui.label(text);
    imgui.TextColored(color or T_().text, tostring(value));
end

-- Custom content: draw it when this returns true. keywords: what a search
-- should find it by.
function ui.block(keywords) return ui.want(keywords); end
function ui.preview() return not ui.searching(); end

-- ----------------------------------------------------------------------------
-- The window body: search line, sidebar and the page.
--
-- ctx = {
--   id       = 'mh',                     unique id prefix
--   title    = 'MobHunt',                shown before each page title
--   groups   = { { label = 'GENERAL', pages = { { key, label, desc, draw }, ... } }, ... },
--   page     = function() return key end, set_page = function(key) end,
--   dirty    = function() end,           saves the settings
--   themes   = { order = { keys }, list = { [key] = { label, accent = {r,g,b 0-255} } },
--                current = function() return key end, set = function(key) end },
--   reserve_right = function() return px end   (optional: space kept free at the top right)
-- }
-- ----------------------------------------------------------------------------

local function find_page(ctx, key)
    for _, g in ipairs(ctx.groups) do
        for _, pg in ipairs(g.pages) do
            if pg.key == key then return pg; end
        end
    end
    return ctx.groups[1].pages[1];
end

local function draw_page(ctx, pg)
    ui.set_dirty(ctx.dirty);
    ui.page(ctx.title .. '  /  ' .. pg.label, pg.desc);
    local ok, err = pcall(pg.draw);
    if not ok then imgui.TextColored(T_().danger or { 1, 0.4, 0.4, 1 }, tostring(err)); end
end

local function avail_size()
    local avail = imgui.GetContentRegionAvail();
    local aw, ah;
    if type(avail) == 'table' then aw, ah = avail.x or avail[1], avail.y or avail[2];
    else aw, ah = imgui.GetContentRegionAvail(); end
    return tonumber(aw) or 600, tonumber(ah) or 500;
end

local function begin_child(id, size)
    local ok, r = pcall(imgui.BeginChild, id, size, 0, 0);
    if ok then return r; end
    return imgui.BeginChild(id, size, false, 0);
end

local function sidebar(ctx, current, w, h)
    local t = T_();
    local s = sc();
    begin_child('##' .. ctx.id .. '_cfg_nav', { w, h });
    pcall(function()
        local x, y = imgui.GetWindowPos();
        imgui.GetWindowDrawList():AddRectFilled({ x, y }, { x + w, y + h },
            imgui.GetColorU32({ t.control[1], t.control[2], t.control[3], 0.55 }), 6 * s);
    end);
    imgui.Dummy({ 1, 4 * s });
    local dim = ui.searching();
    local picked = current;
    local c = t.accent;
    for gi, g in ipairs(ctx.groups) do
        if gi > 1 then imgui.Dummy({ 1, 7 * s }); end
        imgui.SetCursorPosX(10 * s);
        imgui.TextColored({ t.muted[1], t.muted[2], t.muted[3], dim and 0.5 or 0.95 }, g.label:upper());
        for _, pg in ipairs(g.pages) do
            local on = (current == pg.key) and not dim;
            imgui.SetCursorPosX(6 * s);
            imgui.PushStyleColor(ImGuiCol_Text, on and t.accent_text or { t.text[1], t.text[2], t.text[3], dim and 0.5 or 1 });
            imgui.PushStyleColor(ImGuiCol_Header, { c[1], c[2], c[3], 0.16 });
            imgui.PushStyleColor(ImGuiCol_HeaderHovered, { c[1], c[2], c[3], 0.12 });
            imgui.PushStyleColor(ImGuiCol_HeaderActive, { c[1], c[2], c[3], 0.22 });
            if imgui.Selectable('   ' .. pg.label .. '##' .. ctx.id .. '_nav_' .. pg.key, on, 0, { w - 12 * s, 0 }) then
                picked = pg.key;
                S.search[1] = '';
            end
            imgui.PopStyleColor(4);
            if pg.desc ~= nil then tip(pg.desc); end
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

function ui.body(ctx)
    local t = T_();
    local s = sc();
    local current = find_page(ctx, ctx.page()).key;
    local nav_w = 180 * s;
    local aw, ah = avail_size();

    -- Search box and status line.
    imgui.PushItemWidth(nav_w);
    if imgui.InputTextWithHint ~= nil then
        imgui.InputTextWithHint('##' .. ctx.id .. '_cfg_search', 'Search settings...', S.search, 64);
    else
        imgui.InputText('Search##' .. ctx.id .. '_cfg_search', S.search, 64);
    end
    imgui.PopItemWidth();
    tip('Type part of a setting\'s name (or what it does) to find it.');
    ui.set_query(S.search[1]);
    imgui.SameLine();
    if ui.searching() then
        if imgui.SmallButton('Clear##' .. ctx.id .. '_cfg_clear') then S.search[1] = ''; ui.set_query(''); end
        imgui.SameLine();
        local n = S.last_hits or 0;
        imgui.TextColored(t.muted, ('%d result%s for "%s"'):format(n, n == 1 and '' or 's', S.q));
    else
        t.align_label();
        imgui.TextColored(t.muted, 'Saved per character');
    end

    -- Quick theme swatches, top right.
    if ctx.themes ~= nil then
        local sw, sh = 16 * s, 12 * s;
        local total = #ctx.themes.order * (sw + 4 * s);
        -- Room kept on the right (the addon's own X button when the title bar is off).
        local reserve = 0;
        if type(ctx.reserve_right) == 'function' then reserve = tonumber(ctx.reserve_right()) or 0; end
        imgui.SameLine(math.max(imgui.GetCursorPosX(), aw - total + 8 * s - reserve));
        local cur_theme = ctx.themes.current();
        for i, key in ipairs(ctx.themes.order) do
            local th = ctx.themes.list[key];
            if i > 1 then imgui.SameLine(0, 4 * s); end
            local a = th.accent;
            imgui.PushStyleColor(ImGuiCol_Button, { a[1] / 255, a[2] / 255, a[3] / 255, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { a[1] / 255, a[2] / 255, a[3] / 255, 0.85 });
            imgui.PushStyleColor(ImGuiCol_ButtonActive, { a[1] / 255, a[2] / 255, a[3] / 255, 0.70 });
            if imgui.Button('##' .. ctx.id .. '_qtheme_' .. key, { sw, sh }) then ctx.themes.set(key); end
            imgui.PopStyleColor(3);
            tip(th.label .. ' theme');
            if key == cur_theme then
                pcall(function()
                    local x1 = imgui.GetItemRectMin();
                    local x2, y2 = imgui.GetItemRectMax();
                    imgui.GetWindowDrawList():AddRectFilled({ x1 + 2, y2 + 1 }, { x2 - 2, y2 + 3 }, imgui.GetColorU32({ 1, 1, 1, 0.9 }), 1);
                end);
            end
        end
    end

    local h = math.max(150, ah - imgui.GetFrameHeightWithSpacing() - 4 * s);
    local picked = sidebar(ctx, current, nav_w, h);
    if picked ~= current then
        ctx.set_page(picked);
        current = picked;
    end
    imgui.SameLine(0, 10 * s);

    begin_child('##' .. ctx.id .. '_cfg_body', { math.max(200, aw - nav_w - 10 * s), h });
    S.hits = 0;
    if ui.searching() then
        for _, g in ipairs(ctx.groups) do
            for _, pg in ipairs(g.pages) do draw_page(ctx, pg); end
        end
        S.last_hits = S.hits;
        if S.hits == 0 then
            imgui.TextColored(t.muted, 'No setting matches that.');
            imgui.TextColored(t.muted, 'Try a shorter word, like "color", "size", "lock" or "font".');
        end
    else
        draw_page(ctx, find_page(ctx, current));
    end
    imgui.Dummy({ 1, 8 * s });
    imgui.EndChild();
end

return ui;
