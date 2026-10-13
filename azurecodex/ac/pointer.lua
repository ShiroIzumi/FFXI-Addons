--[[
    Azure Codex - ac/pointer.lua

    The visible mouse pointer drawn over Azure Codex windows (FFXI hides the
    Windows one): wraps imgui.Begin / popups to detect hover, draws the arrow.
]]

-- ----------------------------------------------------------------------------
-- Visible mouse pointer. FFXI hides the Windows pointer, so one is drawn while
-- the mouse is over any Azure Codex window, dropdown or popup. imgui.Begin /
-- popups / combos are wrapped (only inside Azure Codex's own Lua state) so
-- each window checks whether the mouse is over it; the pointer is drawn last
-- each frame on ImGui's foreground layer.
-- ----------------------------------------------------------------------------
mouse_pointer = { hovered = false, shown_last = false };

do
    local unpack_fn = unpack or table.unpack;
    local function check_hover()
        local flags = bit.bor(ImGuiHoveredFlags_RootAndChildWindows or 3,
            ImGuiHoveredFlags_AllowWhenBlockedByPopup or 32,
            ImGuiHoveredFlags_AllowWhenBlockedByActiveItem or 128);
        local ok, over = pcall(imgui.IsWindowHovered, flags);
        if ok and over then mouse_pointer.hovered = true; end
    end
    for _, name in ipairs({ 'Begin', 'BeginPopup', 'BeginPopupModal', 'BeginPopupContextItem',
        'BeginPopupContextWindow', 'BeginPopupContextVoid', 'BeginCombo' }) do
        local real = imgui[name];
        if type(real) == 'function' then
            imgui[name] = function(...)
                local results = { real(...) };
                if results[1] then check_hover(); end
                return unpack_fn(results);
            end
        end
    end
end

-- Arrow shape in pixels at size 1.0 (tip at 0, 0) and its fill triangles.
POINTER_OUTLINE = {
    { 0, 0 }, { 0, 17 }, { 4, 13 }, { 7, 20 }, { 10, 19 }, { 7, 12 }, { 12, 12 },
};
POINTER_FILL = {
    { 1, 2, 3 }, { 1, 3, 6 }, { 1, 6, 7 }, { 3, 4, 5 }, { 3, 5, 6 },
};

function pointer_color(t, def)
    if type(t) ~= 'table' then return def; end
    return { tonumber(t[1]) or def[1], tonumber(t[2]) or def[2], tonumber(t[3]) or def[3], tonumber(t[4]) or def[4] };
end

-- Drawn last each frame, above every window.
function draw_mouse_pointer()
    local show = mouse_pointer.hovered;
    mouse_pointer.hovered = false;

    -- Popups ImGui opens on its own (the color picker) are not wrapped, so
    -- keep the pointer while one is open and the mouse is still over ImGui.
    if not show and mouse_pointer.shown_last then
        pcall(function()
            local popup = imgui.IsPopupOpen('', ImGuiPopupFlags_AnyPopup or 3072);
            local io = imgui.GetIO();
            if popup and io ~= nil and io.WantCaptureMouse then show = true; end
        end);
    end
    mouse_pointer.shown_last = show;

    local cur = config.cursor;
    if not show or cur == nil or cur.enabled == false then return; end

    pcall(function()
        local x, y = imgui.GetMousePos();
        x, y = tonumber(x), tonumber(y);
        if x == nil or y == nil then return; end
        local dl = imgui.GetForegroundDrawList();
        if dl == nil then return; end

        local s = tonumber(cur.size) or defaults.cursor.size;
        local pts = {};
        for i, p in ipairs(POINTER_OUTLINE) do
            pts[i] = { x + p[1] * s, y + p[2] * s };
        end

        local fill = imgui.GetColorU32(pointer_color(cur.color, defaults.cursor.color));
        local edge = imgui.GetColorU32(pointer_color(cur.outline, defaults.cursor.outline));
        local shadow = imgui.GetColorU32({ 0.0, 0.0, 0.0, 0.40 });

        if cur.shadow ~= false then
            local off = 1.5 * s;
            for _, t in ipairs(POINTER_FILL) do
                local a, b, c = pts[t[1]], pts[t[2]], pts[t[3]];
                dl:AddTriangleFilled({ a[1] + off, a[2] + off }, { b[1] + off, b[2] + off }, { c[1] + off, c[2] + off }, shadow);
            end
        end
        for _, t in ipairs(POINTER_FILL) do
            dl:AddTriangleFilled(pts[t[1]], pts[t[2]], pts[t[3]], fill);
        end
        local thickness = math.max(1.0, 1.2 * s);
        for i = 1, #pts do
            dl:AddLine(pts[i], pts[(i % #pts) + 1], edge, thickness);
        end
    end);
end
