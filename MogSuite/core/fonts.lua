--[[
    MogSuite - core/fonts.lua (1.5.0)

    The font every MogSuite window uses, and the tooltip look.

    Fonts: Ashita's own ImGui font is a small pixel font, which is what
    looks sharp / jagged once it is scaled up (4K screens). MogSuite can
    use a Windows font instead (Tahoma by default, the font XIUI's bars
    use), drawn at its real size so it stays smooth at any UI scale.

    Fonts can only be added to ImGui when the addon loads (never while a
    frame is being drawn), so a new font choice applies after
    "/addon reload mogsuite" (the settings page has a button for it). Only
    the fonts you pick are loaded.

    Tooltips: every tooltip MogSuite shows goes through here (BeginTooltip /
    EndTooltip / SetTooltip are wrapped inside MogSuite's own Lua state), so
    its text size, colors, background and wrap width follow the Global >
    Fonts & Tooltips settings.

    Globals for the modules:
      MS_FONT()          the ImFont to push (nil = Ashita's default font)
      MS_FONT_SIZE()     base text size in pixels (before a window's scale)
]]

require('common');
local imgui = require('imgui');

local fonts = {
    loaded = {},      -- [key] = ImFont | false
    G = nil,
    tip_depth = 0,
};

-- Shown in settings, in this order (file in C:\Windows\Fonts). Missing
-- files are left out of the list.
fonts.FAMILIES = {
    { key = 'default', label = "Ashita default (pixel font)" },
    { key = 'tahoma', label = 'Tahoma', file = 'tahoma.ttf' },
    { key = 'tahomab', label = 'Tahoma Bold', file = 'tahomabd.ttf' },
    { key = 'segoe', label = 'Segoe UI', file = 'segoeui.ttf' },
    { key = 'segoesb', label = 'Segoe UI Semibold', file = 'seguisb.ttf' },
    { key = 'segoeb', label = 'Segoe UI Bold', file = 'segoeuib.ttf' },
    { key = 'verdana', label = 'Verdana', file = 'verdana.ttf' },
    { key = 'verdanab', label = 'Verdana Bold', file = 'verdanab.ttf' },
    { key = 'arial', label = 'Arial', file = 'arial.ttf' },
    { key = 'arialb', label = 'Arial Bold', file = 'arialbd.ttf' },
    { key = 'calibri', label = 'Calibri', file = 'calibri.ttf' },
    { key = 'calibrib', label = 'Calibri Bold', file = 'calibrib.ttf' },
    { key = 'candara', label = 'Candara', file = 'Candara.ttf' },
    { key = 'corbel', label = 'Corbel', file = 'corbel.ttf' },
    { key = 'bahnschrift', label = 'Bahnschrift', file = 'bahnschrift.ttf' },
    { key = 'trebuchet', label = 'Trebuchet MS', file = 'trebuc.ttf' },
    { key = 'trebuchetb', label = 'Trebuchet MS Bold', file = 'trebucbd.ttf' },
    { key = 'franklin', label = 'Franklin Gothic Medium', file = 'framd.ttf' },
    { key = 'gadugi', label = 'Gadugi', file = 'gadugi.ttf' },
    { key = 'leelawadee', label = 'Leelawadee UI', file = 'LeelawUI.ttf' },
    { key = 'nirmala', label = 'Nirmala UI', file = 'Nirmala.ttf' },
    { key = 'mssans', label = 'Microsoft Sans Serif', file = 'micross.ttf' },
    { key = 'lucidasans', label = 'Lucida Sans Unicode', file = 'l_10646.ttf' },
    { key = 'lucidacon', label = 'Lucida Console', file = 'lucon.ttf' },
    { key = 'consolas', label = 'Consolas', file = 'consola.ttf' },
    { key = 'cascadia', label = 'Cascadia Mono', file = 'CascadiaMono.ttf' },
    { key = 'georgia', label = 'Georgia', file = 'georgia.ttf' },
    { key = 'cambria', label = 'Cambria', file = 'cambria.ttc' },
    { key = 'palatino', label = 'Palatino Linotype', file = 'pala.ttf' },
    { key = 'times', label = 'Times New Roman', file = 'times.ttf' },
};

local function fonts_dir()
    return (os.getenv('WINDIR') or 'C:\\Windows') .. '\\Fonts\\';
end

local exists_cache = {};
local function exists(path)
    if exists_cache[path] ~= nil then return exists_cache[path]; end
    local f = io.open(path, 'rb');
    local ok = f ~= nil;
    if f then f:close(); end
    exists_cache[path] = ok;
    return ok;
end

function fonts.find(key)
    for _, f in ipairs(fonts.FAMILIES) do
        if f.key == key then return f; end
    end
    return nil;
end

-- Installed families (for the settings list), plus a custom file.
function fonts.available()
    local out = {};
    for _, f in ipairs(fonts.FAMILIES) do
        if f.file == nil or exists(fonts_dir() .. f.file) then out[#out + 1] = f; end
    end
    return out;
end

local function path_of(key, G)
    if key == 'custom' then
        local p = tostring((G and G.font_custom) or '');
        if p == '' then return nil; end
        if not p:find('[\\/]') then p = fonts_dir() .. p; end
        return p;
    end
    local f = fonts.find(key);
    if f == nil or f.file == nil then return nil; end
    return fonts_dir() .. f.file;
end

local function load_one(key, G)
    if key == nil or key == 'default' or fonts.loaded[key] ~= nil then return; end
    local path = path_of(key, G);
    local font = false;
    if path ~= nil and exists(path) then
        local ok, r = pcall(function() return imgui.AddFontFromFileTTF(path, 18.0); end);
        if ok and r ~= nil then font = r; end
    end
    fonts.loaded[key] = font;
end

-- Load event only: the window font and the tooltip font you picked.
function fonts.load(G)
    fonts.G = G;
    if G == nil then return; end
    fonts.loaded_family = G.font_family;
    fonts.loaded_tip_family = G.tooltip_font;
    load_one(G.font_family, G);
    if G.tooltip_font ~= nil and G.tooltip_font ~= 'same' then load_one(G.tooltip_font, G); end
end

function fonts.set_global(G) fonts.G = G; end

-- A choice that is not loaded yet (needs a reload).
function fonts.needs_reload(G)
    G = G or fonts.G;
    if G == nil then return false; end
    if (G.font_family or 'default') ~= (fonts.loaded_family or 'default') then return true; end
    local tf = G.tooltip_font or 'same';
    if tf ~= 'same' and tf ~= 'default' and fonts.loaded[tf] == nil then return true; end
    return false;
end

local function font_of(key)
    if key == nil or key == 'default' then return nil; end
    local f = fonts.loaded[key];
    if f then return f; end
    return nil;
end

function fonts.window_font()
    local G = fonts.G;
    if G == nil then return nil; end
    return font_of(G.font_family);
end

-- Base text size: the size you picked when a Windows font is in use; with
-- Ashita's font, its own size (so nothing changes for people who keep it).
function fonts.window_size()
    local G = fonts.G;
    local cur = tonumber(imgui.GetFontSize()) or 13;
    if G == nil then return cur; end
    if fonts.window_font() ~= nil then return tonumber(G.font_size) or 15; end
    return cur;
end

function MS_FONT() return fonts.window_font(); end
function MS_FONT_SIZE() return fonts.window_size(); end

-- ============================================================================
-- Tooltips
-- ============================================================================

local function c4(t, d)
    if type(t) ~= 'table' then return d; end
    return { tonumber(t[1]) or d[1], tonumber(t[2]) or d[2], tonumber(t[3]) or d[3], tonumber(t[4]) or d[4] or 1 };
end

-- What to push around a tooltip (nil = nothing changes).
local function tip_style()
    local G = fonts.G;
    if G == nil or G.tooltip_custom == false then return nil; end
    local st = {};
    local tf = G.tooltip_font or 'same';
    if tf == 'same' then st.font = fonts.window_font(); else st.font = font_of(tf); end
    local base = tonumber(imgui.GetFontSize()) or 13;
    local px = tonumber(G.tooltip_size) or 0;
    -- 0 = the size of the window the tooltip belongs to.
    if px > 0 then st.size = px; else st.size = base; end
    st.text = G.tooltip_text_color;
    st.bg = G.tooltip_bg;
    st.pad = tonumber(G.tooltip_padding) or 8;
    st.border = G.tooltip_border ~= false;
    return st;
end

fonts.tip_stack = {};

local function push_tip()
    local st = tip_style();
    local rec = { font = false, colors = 0, vars = 0 };
    if st ~= nil then
        if st.font ~= nil or st.size ~= nil then
            pcall(function() imgui.PushFont(st.font, st.size); rec.font = true; end);
        end
        if type(st.text) == 'table' then
            imgui.PushStyleColor(ImGuiCol_Text, c4(st.text, { 0.93, 0.93, 0.95, 1 }));
            rec.colors = rec.colors + 1;
        end
        if type(st.bg) == 'table' then
            imgui.PushStyleColor(ImGuiCol_PopupBg, c4(st.bg, { 0.05, 0.05, 0.06, 0.97 }));
            rec.colors = rec.colors + 1;
        end
        imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { st.pad, st.pad });
        imgui.PushStyleVar(ImGuiStyleVar_PopupBorderSize, st.border and 1.0 or 0.0);
        rec.vars = 2;
    end
    fonts.tip_stack[#fonts.tip_stack + 1] = rec;
end

local function pop_tip()
    local rec = table.remove(fonts.tip_stack);
    if rec == nil then return; end
    if rec.vars > 0 then imgui.PopStyleVar(rec.vars); end
    if rec.colors > 0 then imgui.PopStyleColor(rec.colors); end
    if rec.font then pcall(imgui.PopFont); end
end

-- Wrap width for tooltips (px), from the settings.
function fonts.tip_wrap()
    local G = fonts.G;
    local w = tonumber(G and G.tooltip_wrap) or 0;
    if w <= 0 then return nil; end
    return w;
end

function fonts.install_tooltips()
    if fonts.tips_installed then return; end
    fonts.tips_installed = true;
    local real_begin = imgui.BeginTooltip;
    local real_end = imgui.EndTooltip;
    local real_set = imgui.SetTooltip;
    if type(real_begin) ~= 'function' or type(real_end) ~= 'function' then return; end
    imgui.BeginTooltip = function(...)
        push_tip();
        local r = real_begin(...);
        local wrap = fonts.tip_wrap();
        if wrap ~= nil then
            imgui.PushTextWrapPos(wrap);
            fonts.tip_stack[#fonts.tip_stack].wrap = true;
        end
        return r;
    end
    imgui.EndTooltip = function(...)
        local top = fonts.tip_stack[#fonts.tip_stack];
        if top ~= nil and top.wrap then imgui.PopTextWrapPos(); end
        local r = real_end(...);
        pop_tip();
        return r;
    end
    if type(real_set) == 'function' then
        imgui.SetTooltip = function(text, ...)
            imgui.BeginTooltip();
            imgui.TextUnformatted(tostring(text or ''));
            imgui.EndTooltip();
        end
    end
end

return fonts;
