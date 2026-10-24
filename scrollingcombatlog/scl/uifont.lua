--[[
    SCL - scl/uifont.lua (the shared fonts kit, from MogSuite 1.5.0; windows only, not the floating text)

    The font of the addon's windows, and the tooltip look.

    Fonts: Ashita's own ImGui font is a small pixel font, which is what
    looks sharp / jagged once it is scaled up (4K screens). The addon can
    use a Windows font instead (Tahoma by default, the font XIUI's bars
    use), drawn at its real size so it stays smooth at any UI scale.

    Fonts can only be added to ImGui when the addon loads (never while a
    frame is being drawn), so a new font choice applies after
    a reload of the addon (the settings page has a button for it). Only
    the fonts you pick are loaded.

    Tooltips: every tooltip the addon shows goes through here (BeginTooltip /
    EndTooltip / SetTooltip are wrapped inside the addon's own Lua state), so
    its text size, colors, background and wrap width follow the
    Fonts & Tooltips settings.

    Use:
      fonts.addon = 'name'          (for the Reload button)
      fonts.defaults(S)             fills the font settings in a settings table
      fonts.load(S)                 in the load event only
      fonts.set_global(S)           when the settings table is replaced
      fonts.install_tooltips()      once, at load
      fonts.push(scale) / fonts.pop()  around a window's contents
      fonts.settings_page(S, h)     the Fonts & Tooltips settings controls
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

-- Push the window font at size * scale (Ashita 4.3+ ImGui only).
function fonts.push(scale)
    local ok = pcall(function() imgui.PushFont(fonts.window_font(), fonts.window_size() * (tonumber(scale) or 1)); end);
    fonts.pushed = (fonts.pushed or 0) + (ok and 1 or 0);
    return ok;
end
function fonts.pop()
    if (fonts.pushed or 0) > 0 then
        fonts.pushed = fonts.pushed - 1;
        pcall(imgui.PopFont);
    end
end

-- Font settings (Tahoma 15 by default).
function fonts.defaults(S)
    local d = {
        font_family = 'tahoma', font_custom = '', font_size = 15,
        tooltip_custom = true, tooltip_font = 'same', tooltip_size = 0, tooltip_wrap = 0,
        tooltip_padding = 8, tooltip_border = true,
        tooltip_text_color = { 0.95, 0.95, 0.97, 1.00 }, tooltip_bg = { 0.04, 0.04, 0.05, 0.97 },
    };
    for k, v in pairs(d) do if S[k] == nil then S[k] = v; end end
    return S;
end

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

-- ============================================================================
-- Settings controls. h = { header(title), label(text, tip), dirty(), want(...),
-- ctrl_w = px, accent = color, muted = color }
-- ============================================================================

local function combo(id, S, key, list, extra, w, dirty)
    local cur = S[key] or 'default';
    local label = cur;
    for _, f in ipairs(extra or {}) do if f.key == cur then label = f.label; end end
    for _, f in ipairs(list) do if f.key == cur then label = f.label; end end
    if cur == 'custom' then label = 'Custom file...'; end
    imgui.PushItemWidth(w);
    if imgui.BeginCombo('##' .. id, label) then
        for _, f in ipairs(extra or {}) do
            if imgui.Selectable(f.label .. '##' .. id .. f.key, cur == f.key) then S[key] = f.key; dirty(); end
        end
        for _, f in ipairs(list) do
            if imgui.Selectable(f.label .. '##' .. id .. f.key, cur == f.key) then S[key] = f.key; dirty(); end
        end
        if imgui.Selectable('Custom file...##' .. id .. 'custom', cur == 'custom') then S[key] = 'custom'; dirty(); end
        imgui.EndCombo();
    end
    imgui.PopItemWidth();
end

local function color_edit(id, S, key, def, dirty)
    local c = S[key] or def;
    local v = { c[1], c[2], c[3], c[4] or 1 };
    if imgui.ColorEdit4('##' .. id, v, ImGuiColorEditFlags_NoInputs or 0) then
        S[key] = { v[1], v[2], v[3], v[4] };
        dirty();
    end
end

function fonts.settings_page(S, h)
    local list = fonts.available();
    local w = h.ctrl_w or 220;
    local muted = h.muted or { 0.62, 0.62, 0.66, 1 };
    local accent = h.accent or { 0.8, 0.8, 0.8, 1 };
    local id = 'fnt_' .. tostring(fonts.addon or 'x');
    local function slider(text, key, lo, hi, fmt, tip)
        if not h.want(text, tip) then return; end
        h.label(text, tip);
        imgui.PushItemWidth(w);
        -- Applied when you let go (a size change while dragging flickers).
        fonts.pending = fonts.pending or {};
        local v = { math.floor(fonts.pending[key] or tonumber(S[key]) or lo) };
        local f = fmt;
        if type(fmt) == 'function' then f = fmt(v[1]); end
        if imgui.SliderInt('##' .. id .. key, v, lo, hi, f) then fonts.pending[key] = v[1]; end
        if not imgui.IsItemActive() and fonts.pending[key] ~= nil then
            S[key] = fonts.pending[key];
            fonts.pending[key] = nil;
            h.dirty();
        end
        imgui.PopItemWidth();
    end
    local function check(text, key, tip)
        if not h.want(text, tip) then return; end
        local v = { S[key] ~= false };
        if imgui.Checkbox(text .. '##' .. id .. key, v) then S[key] = v[1]; h.dirty(); end
        if tip and imgui.IsItemHovered() then imgui.SetTooltip(tip); end
    end

    h.header('FONT');
    if h.want('Font', 'window font tahoma') then
        h.label('Font', 'A Windows font stays smooth at any size. Only fonts installed on this PC are listed.');
        combo(id .. 'fam', S, 'font_family', list, nil, w, h.dirty);
    end
    if S.font_family == 'custom' and h.want('Font file', 'custom ttf') then
        h.label('Font file', 'A .ttf file name in C:\\Windows\\Fonts, or a full path.');
        local buf = { tostring(S.font_custom or '') };
        imgui.PushItemWidth(w);
        if imgui.InputText('##' .. id .. 'cust', buf, 260) then S.font_custom = buf[1]; h.dirty(); end
        imgui.PopItemWidth();
    end
    -- Text size: - / + (hold to repeat), not a slider: a slider inside a
    -- window it resizes jumps under the mouse.
    if h.want('Text size', 'font size') then
        h.label('Text size', 'Base text size; the window size setting still applies on top.');
        fonts.hold = fonts.hold or {};
        local function step(label, id, dir)
            imgui.Button(label .. '##' .. id, { 26, 0 });
            if imgui.IsItemActive() then
                local t = os.clock();
                local st = fonts.hold[id];
                if st == nil then
                    fonts.hold[id] = { start = t, last = t };
                    return dir;
                end
                if t - st.start > 0.40 and t - st.last > 0.08 then st.last = t; return dir; end
            else
                fonts.hold[id] = nil;
            end
            return 0;
        end
        local d = step('-', id .. 'fsm', -1);
        imgui.SameLine(0, 4);
        imgui.Text(('%d px'):format(math.floor(tonumber(S.font_size) or 15)));
        imgui.SameLine(0, 4);
        d = d + step('+', id .. 'fsp', 1);
        if d ~= 0 then
            S.font_size = math.max(10, math.min(28, math.floor(tonumber(S.font_size) or 15) + d));
            h.dirty();
        end
    end
    if fonts.needs_reload(S) and h.want('Reload', 'font reload') then
        h.label('Apply');
        imgui.TextColored({ 0.95, 0.75, 0.30, 1.0 }, 'A new font loads on reload.');
        imgui.SameLine();
        if imgui.Button('Reload##' .. id .. 'rl') then
            AshitaCore:GetChatManager():QueueCommand(1, '/addon reload ' .. tostring(fonts.addon or ''));
        end
    end

    h.header('TOOLTIPS');
    check('Customize tooltips', 'tooltip_custom', 'Off: tooltips look like the window they come from.');
    if S.tooltip_custom ~= false then
        if h.want('Tooltip font', 'tooltip font') then
            h.label('Tooltip font');
            combo(id .. 'tf', S, 'tooltip_font', list, { { key = 'same', label = 'Same as windows' } }, w, h.dirty);
        end
        slider('Tooltip size', 'tooltip_size', 0, 32, function(v) return v == 0 and 'Same as the window' or '%d px'; end, 'Bigger is easier to read on 4K.');
        slider('Tooltip width', 'tooltip_wrap', 0, 900, function(v) return v == 0 and 'Automatic' or '%d px'; end, 'Long lines wrap at this width.');
        slider('Tooltip padding', 'tooltip_padding', 2, 24, '%d px');
        check('Tooltip border', 'tooltip_border');
        if h.want('Tooltip text color', 'tooltip color') then
            h.label('Tooltip text');
            color_edit(id .. 'ttc', S, 'tooltip_text_color', { 0.95, 0.95, 0.97, 1 }, h.dirty);
        end
        if h.want('Tooltip background', 'tooltip color') then
            h.label('Tooltip background', 'Use the alpha to make it see-through.');
            color_edit(id .. 'tbg', S, 'tooltip_bg', { 0.04, 0.04, 0.05, 0.97 }, h.dirty);
        end
        if h.want('Preview', 'tooltip preview') then
            h.label('Preview');
            imgui.TextColored(accent, 'Hover me');
            if imgui.IsItemHovered() then
                imgui.BeginTooltip();
                imgui.TextColored(accent, 'Tooltip preview');
                imgui.TextColored(muted, 'Muted line');
                imgui.TextUnformatted('Plain text line');
                imgui.EndTooltip();
            end
        end
    end
end

return fonts;
