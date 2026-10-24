--[[
    MogSuite - core/configwindow.lua

    The one settings window for the whole suite, laid out like Triage and
    WhatsMyDamage:

      * a search box at the top finds any setting in any module by name or
        by its help text, and lists the matches grouped by page
      * a sidebar on the left: one group per module in the module's own
        color (CHARACTER, INVENTORY, ACTIONS, REQUESTS), then GLOBAL; the
        dot next to a module's name shows whether its window is open; click
        the dot to open or close that window
      * the page on the right starts with its title and one line about what
        it is for

    The window remembers its place, size and the last page you looked at.
    Pages come from each module's module_config_sections (key, label, desc,
    draw) and from core/globalconfig.lua.
]]

require('common');
local imgui = require('imgui');
local bit = require('bit');
local theme = require('core.theme');
local ui = require('core.cfgui');
local globalconfig = require('core.globalconfig');

local configwindow = {
    open = { false },
    apply_geometry = true,
    focus = false,
    search = { '' },
    pending_tab = nil,
};

local GLOBAL_INFO = { key = 'global', label = 'Global', color = theme.COLORS.ice, tooltip = 'Theme, text, keybinds and all windows' };

local function capture_geometry(geom, dirty)
    local x, y = imgui.GetWindowPos();
    local w, h = imgui.GetWindowSize();
    x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h);
    if x == nil or w == nil then return; end
    if math.abs(x - (geom.x or 0)) >= 1 or math.abs(y - (geom.y or 0)) >= 1
        or math.abs(w - (geom.w or 0)) >= 1 or math.abs(h - (geom.h or 0)) >= 1 then
        geom.x, geom.y, geom.w, geom.h = x, y, w, h;
        dirty();
    end
end

-- Opens the window, on a module's first page when tab is given
-- ('character', 'inventory', 'actions', 'requests', 'global').
function configwindow.show(G, tab)
    if tab ~= nil then
        G.config_tab = tab;
        configwindow.pending_tab = tab;
    end
    configwindow.open[1] = true;
    configwindow.focus = true;
    G.config_visible = true;
end

-- ============================================================================
-- Pages
-- ============================================================================

-- Groups for the sidebar: { info, env (nil for Global), pages = { { key, label, desc, draw } } }
local function build_groups(ctx)
    local groups = {};
    for _, env in ipairs(ctx.modules) do
        local secs = env.module_config_sections;
        if secs ~= nil and #secs > 0 then
            groups[#groups + 1] = { info = env.module_info, env = env, pages = secs };
        end
    end
    groups[#groups + 1] = { info = GLOBAL_INFO, env = nil, pages = globalconfig.sections };
    return groups;
end

local function page_id(g, pg) return g.info.key .. ':' .. pg.key; end

local function find_page(groups, id)
    for _, g in ipairs(groups) do
        for _, pg in ipairs(g.pages) do
            if page_id(g, pg) == id then return g, pg; end
        end
    end
    return groups[1], groups[1].pages[1];
end

-- Draws one page (title, then its settings) with the right save function.
local function draw_page(ctx, g, pg)
    if g.env ~= nil then
        ui.set_dirty(g.env.module_config_dirty or ctx.dirty);
    else
        ui.set_dirty(ctx.dirty);
    end
    local title = pg.label;
    if ui.searching() or g.env ~= nil then title = g.info.label .. '  /  ' .. pg.label; end
    if g.env == nil and not ui.searching() then title = 'Global  /  ' .. pg.label; end
    ui.page(title, pg.desc, g.info.color);
    if g.env ~= nil then
        local ok, err = pcall(pg.draw);
        if not ok then imgui.TextColored(theme.UI_DANGER, tostring(err)); end
    else
        local ok, err = pcall(pg.draw, ctx);
        if not ok then imgui.TextColored(theme.UI_DANGER, tostring(err)); end
    end
end

-- ============================================================================
-- Sidebar
-- ============================================================================

-- The open / closed dot next to a module's name. Returns clicked.
local function window_dot(id, x, y, r, open, color)
    imgui.SetCursorScreenPos({ x - r - 3, y - r - 3 });
    local clicked = imgui.InvisibleButton(id, { (r + 3) * 2, (r + 3) * 2 });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    local c = color;
    if open then
        dl:AddCircleFilled({ x, y }, r + (hov and 1 or 0), imgui.GetColorU32({ c[1], c[2], c[3], 1 }), 16);
    else
        dl:AddCircle({ x, y }, r + (hov and 1 or 0), imgui.GetColorU32({ c[1], c[2], c[3], hov and 1 or 0.6 }), 16, 1.5);
    end
    return clicked, hov;
end

local function draw_sidebar(ctx, groups, current, w, h)
    local s = ui.scale;
    theme.begin_child('##ms_cfg_nav', { w, h }, 0);
    pcall(function()
        local x, y = imgui.GetWindowPos();
        imgui.GetWindowDrawList():AddRectFilled({ x, y }, { x + w, y + h },
            imgui.GetColorU32({ theme.UI_CONTROL[1], theme.UI_CONTROL[2], theme.UI_CONTROL[3], 0.55 }), 6 * s);
    end);
    imgui.Dummy({ 1, 4 * s });
    local dim = ui.searching();
    local new_current = current;
    for gi, g in ipairs(groups) do
        if gi > 1 then imgui.Dummy({ 1, 7 * s }); end
        local c = g.info.color or theme.UI_ACCENT;
        -- Group header: a colored bar, the name, and (for modules with a
        -- window) the open / closed dot on the right.
        imgui.SetCursorPosX(10 * s);
        local hx, hy = imgui.GetCursorScreenPos();
        hx, hy = tonumber(hx) or 0, tonumber(hy) or 0;
        local th = imgui.GetTextLineHeight();
        imgui.GetWindowDrawList():AddRectFilled({ hx - 4 * s, hy + 2 }, { hx - 2 * s, hy + th - 2 }, imgui.GetColorU32({ c[1], c[2], c[3], dim and 0.5 or 1 }), 1);
        imgui.TextColored({ c[1], c[2], c[3], dim and 0.55 or 0.95 }, g.info.label:upper());
        if g.env ~= nil and not g.info.no_window and g.env.module_toggle ~= nil then
            local open = false;
            if type(g.env.module_is_open) == 'function' then
                local ok, r = pcall(g.env.module_is_open);
                open = ok and r == true;
            end
            local wx = (tonumber((imgui.GetWindowPos())) or 0) + w - 14 * s;
            local clicked, hov = window_dot('##ms_dot_' .. g.info.key, wx, hy + th / 2, 4.5 * s, open, c);
            if hov then theme.tip((open and 'The %s window is open. Click to close it.' or 'Click to open the %s window.'):format(g.info.label)); end
            if clicked then pcall(g.env.module_toggle); end
            imgui.SetCursorScreenPos({ hx, hy + th + 2 * s });
        end
        for _, pg in ipairs(g.pages) do
            local id = page_id(g, pg);
            local on = (current == id) and not dim;
            imgui.SetCursorPosX(6 * s);
            imgui.PushStyleColor(ImGuiCol_Text, on and theme.UI_ACCENT_TEXT or { theme.UI_TEXT[1], theme.UI_TEXT[2], theme.UI_TEXT[3], dim and 0.5 or 1 });
            imgui.PushStyleColor(ImGuiCol_Header, { c[1], c[2], c[3], 0.16 });
            imgui.PushStyleColor(ImGuiCol_HeaderHovered, { c[1], c[2], c[3], 0.12 });
            imgui.PushStyleColor(ImGuiCol_HeaderActive, { c[1], c[2], c[3], 0.22 });
            if imgui.Selectable('   ' .. pg.label .. '##ms_nav_' .. id, on, 0, { w - 12 * s, 0 }) then
                new_current = id;
                configwindow.search[1] = '';
            end
            imgui.PopStyleColor(4);
            if pg.desc ~= nil then theme.tip(pg.desc); end
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
    return new_current;
end

-- ============================================================================
-- Window
-- ============================================================================

-- ctx: { G, modules = { env, ... }, dirty = fn, version, state = {} }
function configwindow.draw(ctx)
    local G = ctx.G;
    if not configwindow.open[1] then
        configwindow.apply_geometry = true;
        if G.config_visible then G.config_visible = false; ctx.dirty(); end
        return;
    end

    G.config_window = G.config_window or T{ x = 180, y = 140, w = 780, h = 640 };
    local geom = G.config_window;
    -- Older saves were sized for the tabbed layout: make room for the sidebar.
    if (tonumber(geom.w) or 0) < 700 and not G.config_widened then
        geom.w = 780;
        G.config_widened = true;
        configwindow.apply_geometry = true;
        ctx.dirty();
    end
    if configwindow.apply_geometry then
        imgui.SetNextWindowPos({ geom.x, geom.y }, { 0, 0 });
        imgui.SetNextWindowSize({ geom.w, geom.h });
        configwindow.apply_geometry = false;
    end
    if configwindow.focus and imgui.SetNextWindowFocus ~= nil then imgui.SetNextWindowFocus(); end
    configwindow.focus = false;
    if imgui.SetNextWindowSizeConstraints ~= nil then
        imgui.SetNextWindowSizeConstraints({ 560, 340 }, { 4000, 4000 });
    end

    theme.push();
    if imgui.Begin('MogSuite Settings##ms_config', configwindow.open, ImGuiWindowFlags_NoNav) then
        local s = tonumber(G.config_scale) or 1.0;
        ui.scale = s;
        imgui.PushFont(MS_FONT(), MS_FONT_SIZE() * s);
        local ok, err = pcall(function()
            local groups = build_groups(ctx);

            -- Which page (opened from a module's own settings button, or the last one).
            if configwindow.pending_tab ~= nil then
                for _, g in ipairs(groups) do
                    if g.info.key == configwindow.pending_tab then G.config_page = page_id(g, g.pages[1]); end
                end
                configwindow.pending_tab = nil;
                configwindow.search[1] = '';
                ctx.dirty();
            end
            local cg, cp = find_page(groups, G.config_page or '');
            local current = page_id(cg, cp);

            local nav_w = 170 * s;
            local avail = imgui.GetContentRegionAvail();
            local aw, ah;
            if type(avail) == 'table' then aw, ah = avail.x or avail[1], avail.y or avail[2];
            else aw, ah = imgui.GetContentRegionAvail(); end
            aw, ah = tonumber(aw) or 600, tonumber(ah) or 500;

            -- Search box and status line.
            imgui.PushItemWidth(nav_w);
            if imgui.InputTextWithHint ~= nil then
                imgui.InputTextWithHint('##ms_cfg_search', 'Search settings...', configwindow.search, 64);
            else
                imgui.InputText('Search##ms_cfg_search', configwindow.search, 64);
            end
            imgui.PopItemWidth();
            theme.tip('Type part of a setting\'s name (or what it does) to find it in any module.');
            ui.set_query(configwindow.search[1]);
            imgui.SameLine();
            if ui.searching() then
                if imgui.SmallButton('Clear##ms_cfg_clear') then configwindow.search[1] = ''; ui.set_query(''); end
                imgui.SameLine();
                local n = configwindow.last_hits or 0;
                imgui.TextColored(theme.UI_MUTED, ('%d result%s for "%s"'):format(n, n == 1 and '' or 's', ui.S.q));
            else
                theme.align_label();
                imgui.TextColored(theme.UI_MUTED, 'Saved per character');
            end

            -- Quick theme swatches, top right.
            local sw, sh = 16 * s, 12 * s;
            local total = #theme.ORDER * (sw + 4 * s);
            imgui.SameLine(math.max(imgui.GetCursorPosX(), aw - total + 8 * s));
            local cur_theme = theme.key(G.theme);
            for i, key in ipairs(theme.ORDER) do
                local t = theme.THEMES[key];
                if i > 1 then imgui.SameLine(0, 4 * s); end
                local a = t.accent;
                imgui.PushStyleColor(ImGuiCol_Button, { a[1] / 255, a[2] / 255, a[3] / 255, 1.0 });
                imgui.PushStyleColor(ImGuiCol_ButtonHovered, { a[1] / 255, a[2] / 255, a[3] / 255, 0.85 });
                imgui.PushStyleColor(ImGuiCol_ButtonActive, { a[1] / 255, a[2] / 255, a[3] / 255, 0.70 });
                if imgui.Button('##ms_qtheme_' .. key, { sw, sh }) then
                    G.theme = key;
                    theme.applied = nil;
                    ctx.dirty();
                end
                imgui.PopStyleColor(3);
                theme.tip(t.label .. ' theme');
                if key == cur_theme then theme.draw_item_underline({ 1, 1, 1, 0.9 }); end
            end

            local h = math.max(150, ah - imgui.GetFrameHeightWithSpacing() - 4 * s);
            local picked = draw_sidebar(ctx, groups, current, nav_w, h);
            if picked ~= current then
                G.config_page = picked;
                cg, cp = find_page(groups, picked);
                ctx.dirty();
            end
            imgui.SameLine(0, 10 * s);

            theme.begin_child('##ms_cfg_body', { math.max(200, aw - nav_w - 10 * s), h }, 0);
            ui.reset_hits();
            if ui.searching() then
                for _, g in ipairs(groups) do
                    for _, pg in ipairs(g.pages) do draw_page(ctx, g, pg); end
                end
                configwindow.last_hits = ui.hits();
                if ui.hits() == 0 then
                    imgui.TextColored(theme.UI_MUTED, 'No setting matches that.');
                    imgui.TextColored(theme.UI_MUTED, 'Try a shorter word, like "color", "size", "lock" or "key".');
                end
            else
                draw_page(ctx, cg, cp);
            end
            imgui.Dummy({ 1, 8 * s });
            imgui.EndChild();
        end);
        if not ok then imgui.TextColored(theme.UI_DANGER, tostring(err)); end
        imgui.PopFont();
        capture_geometry(geom, ctx.dirty);
    end
    imgui.End();
    theme.pop();
end

return configwindow;
