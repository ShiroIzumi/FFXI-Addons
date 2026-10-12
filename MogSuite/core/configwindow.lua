--[[
    MogSuite - core/configwindow.lua

    The one config window for the whole suite: Character / Inventory /
    Actions / Global tabs across the top, each with its own sections.
]]

require('common');
local imgui = require('imgui');
local bit = require('bit');
local theme = require('core.theme');
local globalconfig = require('core.globalconfig');

local configwindow = {
    open = { false },
    apply_geometry = true,
    focus = false,
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

-- Opens the window on a tab ('character', 'inventory', 'actions', 'global').
function configwindow.show(G, tab)
    if tab ~= nil then G.config_tab = tab; end
    configwindow.open[1] = true;
    configwindow.focus = true;
    G.config_visible = true;
end

-- ctx: { G, modules = { env, ... }, dirty = fn, version, state = {} }
function configwindow.draw(ctx)
    local G = ctx.G;
    if not configwindow.open[1] then
        configwindow.apply_geometry = true;
        if G.config_visible then G.config_visible = false; ctx.dirty(); end
        return;
    end

    G.config_window = G.config_window or T{ x = 180, y = 140, w = 640, h = 620 };
    local geom = G.config_window;
    if configwindow.apply_geometry then
        imgui.SetNextWindowPos({ geom.x, geom.y }, { 0, 0 });
        imgui.SetNextWindowSize({ geom.w, geom.h });
        configwindow.apply_geometry = false;
    end
    if configwindow.focus and imgui.SetNextWindowFocus ~= nil then imgui.SetNextWindowFocus(); end
    configwindow.focus = false;
    if imgui.SetNextWindowSizeConstraints ~= nil then
        imgui.SetNextWindowSizeConstraints({ 420, 320 }, { 4000, 4000 });
    end

    theme.push();
    if imgui.Begin('MogSuite Settings##ms_config', configwindow.open, ImGuiWindowFlags_NoNav) then
        imgui.PushFont(nil, imgui.GetFontSize() * (tonumber(G.config_scale) or 1.0));

        -- Tabs: one per module, then Global.
        local tabs = {};
        for _, env in ipairs(ctx.modules) do tabs[#tabs + 1] = { info = env.module_info, env = env }; end
        tabs[#tabs + 1] = { info = GLOBAL_INFO };
        local current = G.config_tab or 'character';
        local found = false;
        for _, t in ipairs(tabs) do if t.info.key == current then found = true; end end
        if not found then current = 'global'; end

        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 14, 6 });
        local active = nil;
        for i, t in ipairs(tabs) do
            if i > 1 then imgui.SameLine(0, 4); end
            if theme.color_tab(t.info.label, 'ms_cfg_' .. t.info.key, t.info.key == current, t.info.color, t.info.tooltip) then
                current = t.info.key;
                G.config_tab = current;
                ctx.dirty();
            end
            if t.info.key == current then active = t; end
        end
        imgui.PopStyleVar(1);

        -- Sections of the selected tab.
        local sections = (active.env ~= nil) and (active.env.module_config_sections or {}) or globalconfig.sections;
        G.config_section = G.config_section or T{};
        local sec_key = G.config_section[current];
        local section = nil;
        for _, sec in ipairs(sections) do if sec.key == sec_key then section = sec; end end
        section = section or sections[1];

        imgui.Spacing();
        local avail = tonumber((imgui.GetContentRegionAvail())) or 400;
        local used = 0;
        for i, sec in ipairs(sections) do
            local w = theme.text_w(sec.label) + 18;
            if i > 1 then
                if used + 6 + w <= avail then imgui.SameLine(0, 6); used = used + 6; else used = 0; end
            end
            if theme.chip(sec.label, 'ms_sec_' .. current .. '_' .. sec.key, sec == section) then
                G.config_section[current] = sec.key;
                section = sec;
                ctx.dirty();
            end
            used = used + w;
        end

        -- A thin line in the tab's color under the section chips.
        local x1, y1 = imgui.GetCursorScreenPos();
        local c = active.info.color;
        imgui.GetWindowDrawList():AddRectFilled({ x1, y1 + 3 }, { x1 + avail, y1 + 4 }, imgui.GetColorU32({ c[1], c[2], c[3], 0.55 }), 0);
        imgui.Dummy({ avail, 8 });

        theme.begin_child('##ms_cfg_body', { 0, 0 }, 0);
        imgui.Spacing();
        if section ~= nil then
            if active.env ~= nil then
                local ok, err = pcall(section.draw);
                if not ok then imgui.TextColored(theme.UI_DANGER, tostring(err)); end
            else
                section.draw(ctx);
            end
        end
        imgui.EndChild();

        imgui.PopFont();
        capture_geometry(geom, ctx.dirty);
    end
    imgui.End();
    theme.pop();
end

return configwindow;
