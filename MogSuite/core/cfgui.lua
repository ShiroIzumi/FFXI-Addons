--[[
    MogSuite - core/cfgui.lua

    The building blocks of the settings window (same layout as Triage and
    WhatsMyDamage): every page and section, and every setting on them, goes
    through here so the search box can find it.

    While the search box is empty a page draws normally. While it has text,
    every page of every module is drawn and each setting only shows when its
    name or help text (or its section / page title) matches; the page and
    section titles are drawn just before the first match under them.

    Settings sit in two columns: the name on the left, the control at a
    fixed column on the right (checkboxes keep their label on the right).
    Options that only matter when another one is on sit indented under it
    (ui.sub).

    Every module gets this as `ui` in its scope. A page tells the kit how to
    save with ui.set_dirty(fn) (the config window does it before each page).
]]

require('common');
local imgui = require('imgui');
local theme = require('core.theme');

local ui = {
    LABEL_W = 200,
    SLIDER_W = 220,
    scale = 1.0,
};

local S = {
    q = '', page = nil, page_match = false, page_drawn = false,
    sec = nil, sec_match = false, sec_drawn = false, hits = 0,
    color = nil, dirty = function() end,
};
ui.S = S;

function ui.set_query(q) S.q = tostring(q or ''):lower():gsub('^%s+', ''):gsub('%s+$', ''); end
function ui.searching() return S.q ~= ''; end
function ui.set_dirty(fn) S.dirty = fn or function() end; end
function ui.dirty() S.dirty(); end
function ui.reset_hits() S.hits = 0; end
function ui.hits() return S.hits; end

local function sc() return ui.scale or 1; end
local function clean(text) return (tostring(text or ''):gsub('##.*$', '')); end

local function matches(text)
    return text ~= nil and clean(text):lower():find(S.q, 1, true) ~= nil;
end
ui.matches = matches;

-- Page title with its module color, one line about the page, a line.
local function page_title(title, desc, color)
    local c = color or theme.UI_ACCENT;
    local x, y = imgui.GetCursorScreenPos();
    x, y = tonumber(x) or 0, tonumber(y) or 0;
    local h = imgui.GetTextLineHeight();
    imgui.GetWindowDrawList():AddRectFilled({ x, y + 1 }, { x + 3 * sc(), y + h - 1 }, imgui.GetColorU32({ c[1], c[2], c[3], 1 }), 1);
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 9 * sc());
    imgui.TextColored(theme.UI_ACCENT_TEXT, title);
    if desc ~= nil and desc ~= '' and not ui.searching() then
        imgui.PushTextWrapPos(0);
        imgui.TextColored(theme.UI_MUTED, desc);
        imgui.PopTextWrapPos();
    end
    imgui.PushStyleColor(ImGuiCol_Separator, { c[1], c[2], c[3], 0.45 });
    imgui.Separator();
    imgui.PopStyleColor(1);
    imgui.Spacing();
end

-- Starts a page (the config window calls this).
function ui.page(title, desc, color)
    S.page, S.page_match, S.page_drawn, S.color = title, ui.searching() and matches(title), false, color;
    S.sec, S.sec_match, S.sec_drawn = nil, false, false;
    if not ui.searching() then page_title(title, desc, color); end
end

-- Starts a section inside a page.
function ui.section(title)
    S.sec, S.sec_match, S.sec_drawn = title, ui.searching() and matches(title), false;
    if not ui.searching() then
        imgui.Spacing();
        theme.section_header(title);
    end
end

-- Should something with this text (and help) be drawn? Draws the pending
-- page / section titles before the first match.
function ui.want(text, tip)
    if not ui.searching() then return true; end
    local ok = S.page_match or S.sec_match or matches(text) or matches(tip);
    if not ok then return false; end
    if not S.page_drawn then
        if S.hits > 0 then imgui.Spacing(); imgui.Spacing(); end
        page_title(S.page or '', nil, S.color);
        S.page_drawn = true;
    end
    if not S.sec_drawn and S.sec ~= nil then
        theme.section_header(S.sec);
        S.sec_drawn = true;
    end
    S.hits = S.hits + 1;
    return true;
end

-- Options that only matter when the one above is on.
function ui.sub(fn)
    imgui.Indent(18 * sc());
    fn();
    imgui.Unindent(18 * sc());
end

-- Name on the left, then the cursor at the control column.
function ui.label(text, tip)
    theme.align_label();
    imgui.TextColored(theme.UI_MUTED, clean(text));
    if tip then theme.tip(tip); end
    imgui.SameLine();
    imgui.SetCursorPosX(ui.LABEL_W * sc());
end

-- Help shown as a (?) after a control.
local function help(tip)
    if tip ~= nil and tip ~= '' then theme.help_marker(tip); end
end

-- ----------------------------------------------------------------------------
-- Controls bound to a table field. Each saves through ui.dirty().
-- opts.default_on: a missing / nil value counts as on.
-- opts.on_change: called after a change.
-- ----------------------------------------------------------------------------

function ui.check(text, tbl, key, tip, opts)
    if not ui.want(text, tip) then return false; end
    opts = opts or {};
    local cur;
    if opts.default_on then cur = tbl[key] ~= false; else cur = tbl[key] == true; end
    local v = { cur };
    local changed = false;
    if imgui.Checkbox(clean(text) .. '##msui_' .. tostring(tbl) .. tostring(key), v) then
        tbl[key] = v[1];
        if opts.on_change then opts.on_change(v[1]); end
        ui.dirty();
        changed = true;
    end
    help(tip);
    return changed;
end

-- opts.mul: shown value = stored * mul (e.g. 100 for a percent).
function ui.slider_f(text, tbl, key, lo, hi, fmt, tip, opts)
    if not ui.want(text, tip) then return false; end
    opts = opts or {};
    local mul = opts.mul or 1;
    ui.label(text, tip);
    imgui.PushItemWidth(ui.SLIDER_W * sc());
    local v = { (tonumber(tbl[key]) or (lo / mul)) * mul };
    local changed = false;
    if imgui.SliderFloat('##msuif_' .. tostring(tbl) .. tostring(key), v, lo, hi, fmt or '%.2f', ImGuiSliderFlags_AlwaysClamp or 0) then
        tbl[key] = math.max(lo, math.min(hi, v[1])) / mul;
        if opts.on_change then opts.on_change(); end
        ui.dirty();
        changed = true;
    end
    imgui.PopItemWidth();
    return changed;
end

function ui.slider_i(text, tbl, key, lo, hi, fmt, tip, opts)
    if not ui.want(text, tip) then return false; end
    opts = opts or {};
    ui.label(text, tip);
    imgui.PushItemWidth(ui.SLIDER_W * sc());
    local cur = math.floor(tonumber(tbl[key]) or lo);
    local v = { cur };
    local f = fmt;
    if type(fmt) == 'function' then f = fmt(cur); end
    local changed = false;
    if imgui.SliderInt('##msuii_' .. tostring(tbl) .. tostring(key), v, lo, hi, f or '%d', ImGuiSliderFlags_AlwaysClamp or 0) then
        tbl[key] = math.max(lo, math.min(hi, math.floor(v[1])));
        if opts.on_change then opts.on_change(); end
        ui.dirty();
        changed = true;
    end
    imgui.PopItemWidth();
    return changed;
end

-- Edits the color table in place (other code keeps references to it).
function ui.color(text, tbl, tip, with_alpha)
    if not ui.want(text, tip) then return false; end
    ui.label(text, tip);
    local changed = theme.color_edit('##msuic_' .. tostring(tbl), tbl, with_alpha);
    if changed then ui.dirty(); end
    return changed;
end

-- A few options as toggle buttons. options = { { key, label, tip }, ... }
function ui.choice(text, tbl, key, options, tip, opts)
    if not ui.want(text, tip) then return false; end
    opts = opts or {};
    ui.label(text, tip);
    local cur = tbl[key];
    if cur == nil then cur = opts.default; end
    local new = cur;
    for i, o in ipairs(options) do
        if i > 1 then imgui.SameLine(0, 4); end
        if theme.toggle_button(o.label, 'msuich_' .. tostring(tbl) .. tostring(key) .. '_' .. tostring(o.key), cur == o.key) then
            new = o.key;
        end
        if o.tip then theme.tip(o.tip); end
    end
    if new ~= cur then
        tbl[key] = new;
        if opts.on_change then opts.on_change(new); end
        ui.dirty();
        return true;
    end
    return false;
end

-- A button at the control column (label = button text). Returns clicked.
function ui.button(text, id, tip)
    if not ui.want(text, tip) then return false; end
    imgui.SetCursorPosX(ui.LABEL_W * sc());
    local clicked = imgui.Button(clean(text) .. '##' .. id);
    if tip then theme.tip(tip); end
    return clicked;
end

-- A button that needs two clicks (it turns red in between). armed is a
-- table the caller keeps; returns true on the second click.
function ui.danger(text, id, armed, tip)
    if not ui.want(text, tip) then return false; end
    imgui.SetCursorPosX(ui.LABEL_W * sc());
    local on = armed[id] ~= nil and os.clock() - armed[id] < 3.0;
    if on then
        imgui.PushStyleColor(ImGuiCol_Button, { 0.72, 0.16, 0.16, 1.0 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.82, 0.22, 0.22, 1.0 });
    end
    local clicked = imgui.Button((on and 'Click again to confirm' or clean(text)) .. '##' .. id);
    if on then imgui.PopStyleColor(2); end
    if tip then theme.tip(tip); end
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
    imgui.TextColored(theme.UI_MUTED, text);
    imgui.PopTextWrapPos();
end

-- Custom content (previews, lists): draw it when this returns true.
-- keywords: what a search should find it by.
function ui.block(keywords)
    return ui.want(keywords);
end

-- Previews are only drawn outside of search.
function ui.preview() return not ui.searching(); end

return ui;
