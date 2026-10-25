--[[
    WhatsMyDamage - core/fonts.lua

    Windows fonts for the meter. Every font in the list that exists in
    C:\Windows\Fonts is added to ImGui once, when the addon loads (never
    while a frame is drawn). After that, text can be drawn in any of them at
    any size with an outline and / or a shadow.

    "Default" is the font Ashita's windows already use. Bahnschrift is the
    closest Windows font to Details' narrow bold look.
]]

require('common');
local imgui = require('imgui');

local fonts = {
    loaded = {},     -- key -> ImFont, or false when it could not load
    ready = false,
};

-- Shown in the settings, in this order. file = in C:\Windows\Fonts.
fonts.FAMILIES = {
    { key = 'default', label = 'Default' },
    { key = 'bahnschrift', label = 'Bahnschrift', file = 'bahnschrift.ttf' },
    { key = 'arialnb', label = 'Arial Narrow Bold', file = 'arialnb.ttf' },
    { key = 'arialn', label = 'Arial Narrow', file = 'arialn.ttf' },
    { key = 'segoe', label = 'Segoe UI', file = 'segoeui.ttf' },
    { key = 'segoesb', label = 'Segoe UI Semibold', file = 'seguisb.ttf' },
    { key = 'segoeb', label = 'Segoe UI Bold', file = 'segoeuib.ttf' },
    { key = 'segoebl', label = 'Segoe UI Black', file = 'seguibl.ttf' },
    { key = 'arial', label = 'Arial', file = 'arial.ttf' },
    { key = 'arialb', label = 'Arial Bold', file = 'arialbd.ttf' },
    { key = 'arialbl', label = 'Arial Black', file = 'ariblk.ttf' },
    { key = 'tahoma', label = 'Tahoma', file = 'tahoma.ttf' },
    { key = 'tahomab', label = 'Tahoma Bold', file = 'tahomabd.ttf' },
    { key = 'verdana', label = 'Verdana', file = 'verdana.ttf' },
    { key = 'verdanab', label = 'Verdana Bold', file = 'verdanab.ttf' },
    { key = 'calibri', label = 'Calibri', file = 'calibri.ttf' },
    { key = 'calibrib', label = 'Calibri Bold', file = 'calibrib.ttf' },
    { key = 'candara', label = 'Candara', file = 'candara.ttf' },
    { key = 'candarab', label = 'Candara Bold', file = 'candarab.ttf' },
    { key = 'corbel', label = 'Corbel', file = 'corbel.ttf' },
    { key = 'corbelb', label = 'Corbel Bold', file = 'corbelb.ttf' },
    { key = 'constantia', label = 'Constantia', file = 'constan.ttf' },
    { key = 'franklin', label = 'Franklin Gothic Medium', file = 'framd.ttf' },
    { key = 'trebuchet', label = 'Trebuchet MS', file = 'trebuc.ttf' },
    { key = 'trebuchetb', label = 'Trebuchet MS Bold', file = 'trebucbd.ttf' },
    { key = 'impact', label = 'Impact', file = 'impact.ttf' },
    { key = 'georgia', label = 'Georgia', file = 'georgia.ttf' },
    { key = 'georgiab', label = 'Georgia Bold', file = 'georgiab.ttf' },
    { key = 'palatino', label = 'Palatino Linotype', file = 'pala.ttf' },
    { key = 'times', label = 'Times New Roman', file = 'times.ttf' },
    { key = 'timesb', label = 'Times New Roman Bold', file = 'timesbd.ttf' },
    { key = 'consolas', label = 'Consolas', file = 'consola.ttf' },
    { key = 'consolasb', label = 'Consolas Bold', file = 'consolab.ttf' },
    { key = 'courier', label = 'Courier New', file = 'cour.ttf' },
    { key = 'lucidacon', label = 'Lucida Console', file = 'lucon.ttf' },
    { key = 'lucidasans', label = 'Lucida Sans Unicode', file = 'l_10646.ttf' },
    { key = 'mssans', label = 'Microsoft Sans Serif', file = 'micross.ttf' },
    { key = 'leelawadee', label = 'Leelawadee UI', file = 'LeelawUI.ttf' },
    { key = 'leelawadeeb', label = 'Leelawadee UI Bold', file = 'LeelaUIb.ttf' },
    { key = 'ebrima', label = 'Ebrima', file = 'ebrima.ttf' },
    { key = 'gadugi', label = 'Gadugi', file = 'gadugi.ttf' },
    { key = 'nirmala', label = 'Nirmala UI', file = 'Nirmala.ttf' },
    { key = 'comic', label = 'Comic Sans MS', file = 'comic.ttf' },
    { key = 'gabriola', label = 'Gabriola', file = 'Gabriola.ttf' },
};

local function windows_fonts()
    local dir = os.getenv('WINDIR') or 'C:\\Windows';
    return dir .. '\\Fonts\\';
end

local function exists(path)
    local f = io.open(path, 'rb');
    if f == nil then return false; end
    f:close();
    return true;
end

-- Load event only.
function fonts.load_all()
    if fonts.ready then return; end
    fonts.ready = true;
    local dir = windows_fonts();
    for _, f in ipairs(fonts.FAMILIES) do
        if f.file ~= nil then
            local path = dir .. f.file;
            local font = false;
            if exists(path) then
                local ok, r = pcall(function() return imgui.AddFontFromFileTTF(path, 18.0); end);
                if ok and r ~= nil then font = r; end
            end
            fonts.loaded[f.key] = font;
        end
    end
end

-- Families that loaded (for the settings list).
function fonts.available()
    local out = {};
    for _, f in ipairs(fonts.FAMILIES) do
        if f.file == nil or fonts.loaded[f.key] then out[#out + 1] = f; end
    end
    return out;
end

function fonts.get(key)
    local f = fonts.loaded[key];
    if f then return f; end
    return imgui.GetFont();
end

function fonts.label(key)
    for _, f in ipairs(fonts.FAMILIES) do
        if f.key == key then return f.label; end
    end
    return 'Default';
end

-- Width of text in a style (pushes the font at its size and measures).
local wcache, wcache_n = {}, 0;
function fonts.width(st, text)
    text = tostring(text or '');
    local size = tonumber(st.size) or 14;
    local key = tostring(st.family) .. '|' .. size .. '|' .. text;
    local w = wcache[key];
    if w ~= nil then return w; end
    local ok = pcall(imgui.PushFont, fonts.get(st.family), size);
    w = tonumber((imgui.CalcTextSize(text))) or 0;
    if ok then imgui.PopFont(); end
    if wcache_n > 2000 then wcache, wcache_n = {}, 0; end
    wcache[key] = w;
    wcache_n = wcache_n + 1;
    return w;
end

function fonts.clear_cache() wcache, wcache_n = {}, 0; end

-- Draws text with a style { family, size, color, outline (px), outline_color,
-- shadow, shadow_offset, shadow_alpha }. color overrides st.color.
function fonts.text(dl, x, y, text, st, color, alpha)
    text = tostring(text or '');
    if text == '' then return; end
    alpha = alpha or 1;
    local font = fonts.get(st.family);
    local size = tonumber(st.size) or 14;
    local col = color or st.color or { 1, 1, 1, 1 };
    local oc = st.outline_color or { 0, 0, 0, 1 };
    local o = math.floor(tonumber(st.outline) or 0);
    if st.shadow then
        local so = tonumber(st.shadow_offset) or 1.5;
        dl:AddText(font, size, { x + so, y + so }, imgui.GetColorU32({ 0, 0, 0, (tonumber(st.shadow_alpha) or 0.75) * alpha }), text);
    end
    if o > 0 then
        local u = imgui.GetColorU32({ oc[1], oc[2], oc[3], (oc[4] or 1) * alpha });
        for dx = -o, o do
            for dy = -o, o do
                if (dx ~= 0 or dy ~= 0) and dx * dx + dy * dy <= o * o + 1 then
                    dl:AddText(font, size, { x + dx, y + dy }, u, text);
                end
            end
        end
    end
    dl:AddText(font, size, { x, y }, imgui.GetColorU32({ col[1], col[2], col[3], (col[4] or 1) * alpha }), text);
end

-- Shortens text with "..." to fit a width.
function fonts.fit(st, text, w)
    text = tostring(text or '');
    if fonts.width(st, text) <= w then return text; end
    local n = #text;
    while n > 1 and fonts.width(st, text:sub(1, n) .. '...') > w do n = n - 1; end
    return text:sub(1, n) .. '...';
end

return fonts;
