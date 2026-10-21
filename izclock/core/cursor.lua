--[[
    IzClock - core/cursor.lua  (same pointer as Triage / MogSuite)

    A visible mouse pointer drawn while the mouse is over any IzClock window
    (including its popups and dropdowns). FFXI hides the Windows pointer, so
    without this the mouse is invisible over the addon.

    imgui.Begin / BeginPopup / BeginCombo are wrapped (only inside IzClock's
    own Lua state) so every IzClock window checks whether the mouse is over
    it. At the end of the frame the pointer is drawn on ImGui's foreground
    layer, above every window.
]]

require('common');
local imgui = require('imgui');
local bit = require('bit');

local unpack = unpack or table.unpack;

local cursor = {
    hovered = false,
    shown_last = false,
    installed = false,
};

-- Arrow shape in pixels at size 1.0 (tip at 0, 0).
local OUTLINE = {
    { 0, 0 }, { 0, 17 }, { 4, 13 }, { 7, 20 }, { 10, 19 }, { 7, 12 }, { 12, 12 },
};
-- The same arrow split into triangles for the fill.
local FILL = {
    { 1, 2, 3 }, { 1, 3, 6 }, { 1, 6, 7 }, { 3, 4, 5 }, { 3, 5, 6 },
};

local function check_hover()
    local flags = bit.bor(ImGuiHoveredFlags_RootAndChildWindows or 3,
        ImGuiHoveredFlags_AllowWhenBlockedByPopup or 32,
        ImGuiHoveredFlags_AllowWhenBlockedByActiveItem or 128);
    local ok, over = pcall(imgui.IsWindowHovered, flags);
    if ok and over then cursor.hovered = true; end
end

local function wrap(name)
    local real = imgui[name];
    if type(real) ~= 'function' then return; end
    imgui[name] = function(...)
        local results = { real(...) };
        if results[1] then check_hover(); end
        return unpack(results);
    end
end

function cursor.install()
    if cursor.installed then return; end
    cursor.installed = true;
    for _, name in ipairs({ 'Begin', 'BeginPopup', 'BeginPopupModal', 'BeginPopupContextItem',
        'BeginPopupContextWindow', 'BeginPopupContextVoid', 'BeginCombo' }) do
        wrap(name);
    end
end

cursor.DEFAULT_SIZE    = 1.4;
cursor.DEFAULT_COLOR   = { 1.00, 0.10, 0.75, 1.00 };
cursor.DEFAULT_OUTLINE = { 0.05, 0.00, 0.05, 1.00 };

local function color4(t, def)
    if type(t) ~= 'table' then return def; end
    return { tonumber(t[1]) or def[1], tonumber(t[2]) or def[2], tonumber(t[3]) or def[3], tonumber(t[4]) or def[4] };
end

-- Call once per frame after every IzClock window has been drawn.
-- cfg: { enabled, size, color, outline, shadow }
function cursor.draw(cfg)
    local show = cursor.hovered;
    cursor.hovered = false;

    if not show and cursor.shown_last then
        pcall(function()
            local popup = imgui.IsPopupOpen('', ImGuiPopupFlags_AnyPopup or 3072);
            local io = imgui.GetIO();
            if popup and io ~= nil and io.WantCaptureMouse then show = true; end
        end);
    end
    cursor.shown_last = show;

    if not show or cfg == nil or cfg.enabled == false then return; end

    pcall(function()
        local x, y = imgui.GetMousePos();
        x, y = tonumber(x), tonumber(y);
        if x == nil or y == nil then return; end

        local dl = imgui.GetForegroundDrawList();
        if dl == nil then return; end

        local s = tonumber(cfg.size) or cursor.DEFAULT_SIZE;
        local pts = {};
        for i, p in ipairs(OUTLINE) do
            pts[i] = { x + p[1] * s, y + p[2] * s };
        end

        local fill = imgui.GetColorU32(color4(cfg.color, cursor.DEFAULT_COLOR));
        local edge = imgui.GetColorU32(color4(cfg.outline, cursor.DEFAULT_OUTLINE));
        local shadow = imgui.GetColorU32({ 0.0, 0.0, 0.0, 0.40 });

        if cfg.shadow ~= false then
            local off = 1.5 * s;
            for _, t in ipairs(FILL) do
                local a, b, c = pts[t[1]], pts[t[2]], pts[t[3]];
                dl:AddTriangleFilled({ a[1] + off, a[2] + off }, { b[1] + off, b[2] + off }, { c[1] + off, c[2] + off }, shadow);
            end
        end
        for _, t in ipairs(FILL) do
            dl:AddTriangleFilled(pts[t[1]], pts[t[2]], pts[t[3]], fill);
        end
        local thickness = math.max(1.0, 1.2 * s);
        for i = 1, #pts do
            local a, b = pts[i], pts[(i % #pts) + 1];
            dl:AddLine(a, b, edge, thickness);
        end
    end);
end

return cursor;
