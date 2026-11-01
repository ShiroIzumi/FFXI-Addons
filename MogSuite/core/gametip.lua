--[[
    MogSuite - core/gametip.lua  (1.7.0)

    Item tooltips in the game's own look (the same look as the item
    window on the FFXI Safe page): FFXI's translucent navy window with a
    pale frame, the icon and the name at the top, Rare / Ex tags, then

        (Dagger) [Main / Sub] All Races
        <description>
        Lv.30 WAR/RDM/THF

    and below a thin line, MogSuite's own lines (where it is, stack,
    value, ...). Global > Fonts & Tooltips > Item tooltips switches back to
    the theme look ('theme'). The tooltip font and size settings still
    apply; the colors are the game's.

    Use:
        if game_tip.enabled() then
            game_tip.begin({ name, rare, ex, icon, equip, skill, slots, races, desc, level, jobs_text });
            game_tip.sep();
            game_tip.line(game_tip.MUTED, 'In Wardrobe 2');
            game_tip.finish();
        end
]]

require('common');
local imgui = require('imgui');
local bit = require('bit');
local fonts = require('core.fonts');

local gametip = {};

-- The game's colors.
gametip.NAME   = { 1.00, 1.00, 1.00, 1.00 };
gametip.TEXT   = { 0.95, 0.95, 0.97, 1.00 };
gametip.LINE   = { 0.85, 0.87, 0.96, 1.00 };   -- slots / races line
gametip.MUTED  = { 0.70, 0.75, 0.90, 1.00 };   -- secondary text, readable on navy
gametip.TAG    = { 1.00, 0.91, 0.66, 1.00 };   -- Rare / Ex
gametip.GOLD   = { 1.00, 0.86, 0.48, 1.00 };   -- headings (Equipped, Drops from, ...)
gametip.GOOD   = { 0.58, 0.92, 0.62, 1.00 };
gametip.BAD    = { 1.00, 0.56, 0.50, 1.00 };
gametip.BLUE   = { 0.58, 0.82, 1.00, 1.00 };
gametip.BG_TOP = { 0.165, 0.188, 0.361, 0.96 };
gametip.BG_BOT = { 0.086, 0.102, 0.220, 0.96 };
gametip.FRAME  = { 0.84, 0.86, 0.94, 0.85 };
gametip.INNER  = { 0.04, 0.05, 0.12, 0.90 };

-- Weapon skills (resource Skill).
gametip.SKILLS = {
    [1] = 'Hand-to-Hand', [2] = 'Dagger', [3] = 'Sword', [4] = 'Great Sword', [5] = 'Axe', [6] = 'Great Axe',
    [7] = 'Scythe', [8] = 'Polearm', [9] = 'Katana', [10] = 'Great Katana', [11] = 'Club', [12] = 'Staff',
    [25] = 'Archery', [26] = 'Marksmanship', [27] = 'Throwing', [41] = 'Stringed Instrument',
    [42] = 'Wind Instrument', [45] = 'Handbell', [48] = 'Fishing',
};

-- Slot groups, in the game's order (first match is shown).
local SLOT_GROUPS = {
    { 'Main', 0x0001 }, { 'Sub', 0x0002 }, { 'Range', 0x0004 }, { 'Ammo', 0x0008 }, { 'Head', 0x0010 },
    { 'Neck', 0x0200 }, { 'Ear', 0x1800 }, { 'Body', 0x0020 }, { 'Hands', 0x0040 }, { 'Ring', 0x6000 },
    { 'Back', 0x8000 }, { 'Waist', 0x0400 }, { 'Legs', 0x0080 }, { 'Feet', 0x0100 },
};

local RACES = { [1] = 'Hume (M)', [2] = 'Hume (F)', [3] = 'Elvaan (M)', [4] = 'Elvaan (F)',
    [5] = 'Tarutaru (M)', [6] = 'Tarutaru (F)', [7] = 'Mithra', [8] = 'Galka' };
local RACE_ALL = 0x1FE;

function gametip.slot_text(slots)
    slots = tonumber(slots) or 0;
    for _, g in ipairs(SLOT_GROUPS) do
        if bit.band(slots, g[2]) ~= 0 then
            if g[1] == 'Main' and bit.band(slots, 0x0002) ~= 0 then return 'Main / Sub'; end
            return g[1];
        end
    end
    return '';
end

function gametip.races_text(mask)
    mask = bit.band(tonumber(mask) or 0, RACE_ALL);
    if mask == 0 or mask == RACE_ALL then return 'All Races'; end
    local male = bit.bor(2, 8, 32, 256);
    local female = bit.bor(4, 16, 64, 128);
    if mask == male then return 'Male only'; end
    if mask == female then return 'Female only'; end
    local out = {};
    for id = 1, 8 do
        if bit.band(mask, bit.lshift(1, id)) ~= 0 then out[#out + 1] = RACES[id]; end
    end
    return table.concat(out, ', ');
end

-- On (default) unless Global > Fonts & Tooltips > Item tooltips is 'theme'.
function gametip.enabled()
    local G = fonts.G;
    return G == nil or G.item_tip_style ~= 'theme';
end

local function U32(c) return imgui.GetColorU32(c); end
local function xy(a, b)
    if type(a) == 'table' then return tonumber(a[1] or a.x) or 0, tonumber(a[2] or a.y) or 0; end
    return tonumber(a) or 0, tonumber(b) or 0;
end

-- One line with the game's 1px shadow.
function gametip.line(col, text)
    text = tostring(text or '');
    local x, y = xy(imgui.GetCursorScreenPos());
    -- No shadow on a line that wraps (the shadow would not wrap with it).
    local tw = tonumber((imgui.CalcTextSize(text))) or 0;
    if gametip.wrap_w == nil or tw <= gametip.wrap_w then
        pcall(function() imgui.GetWindowDrawList():AddText({ x + 1, y + 1 }, U32({ 0, 0, 0, 0.75 }), text); end);
    end
    imgui.TextColored(col or gametip.TEXT, text);
end

-- Wrapped text (no shadow).
function gametip.wrapped(col, text)
    imgui.PushStyleColor(ImGuiCol_Text, col or gametip.TEXT);
    imgui.TextWrapped(tostring(text or ''));
    imgui.PopStyleColor(1);
end

-- A thin pale line between the item and MogSuite's own lines.
function gametip.sep()
    imgui.Spacing();
    local x, y = xy(imgui.GetCursorScreenPos());
    local w = math.max(gametip.cur_w or 0, 120);
    pcall(function() imgui.GetWindowDrawList():AddLine({ x, y }, { x + w, y }, U32({ 0.84, 0.86, 0.94, 0.35 }), 1.0); end);
    imgui.Dummy({ 1, 3 });
end

-- Rare / Ex chip.
local function chip(dl, label)
    local x, y = xy(imgui.GetCursorScreenPos());
    local tw = tonumber((imgui.CalcTextSize(label))) or 20;
    local h = imgui.GetFontSize();
    pcall(function()
        dl:AddRectFilled({ x, y }, { x + tw + 8, y + h + 1 }, U32({ 1, 1, 1, 0.12 }), 3);
        dl:AddRect({ x, y }, { x + tw + 8, y + h + 1 }, U32({ 0.84, 0.86, 0.94, 0.60 }), 3);
    end);
    imgui.SetCursorScreenPos({ x + 4, y });
    imgui.TextColored(gametip.TAG, label);
end

local sizes = {};   -- tooltip size per item name (last frame), for the background

-- Opens the tooltip and draws the item part. o = {
--   name, rare, ex, icon (texture table with .id), equip (weapon / armor),
--   skill, slots, races, desc, level, jobs_text }
function gametip.begin(o)
    fonts.next_game = true;
    imgui.BeginTooltip();
    fonts.next_game = false;
    local dl = imgui.GetWindowDrawList();
    local fs = tonumber(imgui.GetFontSize()) or 15;
    gametip.key = tostring(o.name or '');
    gametip.wrap_w = nil;
    gametip.cur_w = fs * 18;

    -- Background: navy, a little lighter at the top, with a dark inner line.
    local wx, wy = xy(imgui.GetWindowPos());
    local sz = sizes[gametip.key];
    if sz ~= nil then
        pcall(function()
            dl:AddRectFilledMultiColor({ wx + 2, wy + 2 }, { wx + sz[1] - 2, wy + sz[2] - 2 },
                U32(gametip.BG_TOP), U32(gametip.BG_TOP), U32(gametip.BG_BOT), U32(gametip.BG_BOT));
        end);
        pcall(function() dl:AddRect({ wx + 1, wy + 1 }, { wx + sz[1] - 1, wy + sz[2] - 1 }, U32(gametip.INNER), 5, 0, 1.0); end);
        gametip.cur_w = math.max(gametip.cur_w, sz[1] - 2 * fs);
    end

    -- Header: icon, name, tags.
    local isz = math.floor(fs * 2.1 + 0.5);
    if o.icon ~= nil and o.icon.id ~= nil then
        pcall(function() imgui.Image(o.icon.id, { isz, isz }); end);
        imgui.SameLine(0, math.floor(fs * 0.6));
    elseif o.mark ~= nil then
        -- 1.8.0 (actions): no icon in the game data, so a colored badge with a short label.
        local x, y = xy(imgui.GetCursorScreenPos());
        local c = o.mark;
        pcall(function()
            dl:AddRectFilled({ x, y }, { x + isz, y + isz }, U32({ c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, 0.95 }), 5);
            dl:AddRectFilled({ x + 2, y + 2 }, { x + isz - 2, y + isz * 0.45 }, U32({ c[1], c[2], c[3], 0.22 }), 4);
            dl:AddRect({ x, y }, { x + isz, y + isz }, U32({ c[1], c[2], c[3], 0.95 }), 5, 0, 1.5);
            local t = tostring(o.mark_text or '');
            local tw = tonumber((imgui.CalcTextSize(t))) or fs;
            dl:AddText({ x + (isz - tw) / 2 + 1, y + (isz - fs) / 2 + 1 }, U32({ 0, 0, 0, 0.8 }), t);
            dl:AddText({ x + (isz - tw) / 2, y + (isz - fs) / 2 }, U32({ math.min(1, c[1] + 0.25), math.min(1, c[2] + 0.25), math.min(1, c[3] + 0.25), 1 }), t);
        end);
        imgui.Dummy({ isz, isz });
        imgui.SameLine(0, math.floor(fs * 0.6));
    end
    imgui.BeginGroup();
    if not (o.rare or o.ex or (o.tags ~= nil and #o.tags > 0)) and (o.icon ~= nil or o.mark ~= nil) then
        local x, y = xy(imgui.GetCursorScreenPos());
        imgui.SetCursorScreenPos({ x, y + math.max(0, (isz - fs) / 2 - 1) });
    end
    gametip.line(gametip.NAME, o.name);
    if o.tags ~= nil and #o.tags > 0 then
        for i, t in ipairs(o.tags) do
            if i > 1 then imgui.SameLine(0, 6); end
            chip(dl, t);
        end
    elseif o.rare or o.ex then
        if o.rare then chip(dl, 'Rare'); end
        if o.ex then
            if o.rare then imgui.SameLine(0, 10); end
            chip(dl, 'Ex');
        end
    end
    imgui.EndGroup();
    imgui.Dummy({ 1, math.floor(fs * 0.2) });

    -- Body: (skill) [slot] races, the description, Lv / jobs.
    gametip.wrap_w = fs * 21;
    local wrap_x = imgui.GetCursorPosX() + gametip.wrap_w;
    imgui.PushTextWrapPos(wrap_x);
    if o.equip then
        local skill = gametip.SKILLS[tonumber(o.skill) or 0];
        local slot = gametip.slot_text(o.slots);
        local parts = {};
        if skill ~= nil then parts[#parts + 1] = '(' .. skill .. ')'; end
        if slot ~= '' then parts[#parts + 1] = '[' .. slot .. ']'; end
        parts[#parts + 1] = gametip.races_text(o.races);
        gametip.line(gametip.LINE, table.concat(parts, ' '));
    end
    if o.sub ~= nil and o.sub ~= '' then gametip.line(gametip.LINE, o.sub); end
    if o.desc ~= nil and o.desc ~= '' then
        gametip.wrapped(gametip.TEXT, o.desc);
    end
    if o.equip and ((tonumber(o.level) or 0) > 0 or (o.jobs_text or '') ~= '') then
        imgui.Dummy({ 1, math.floor(fs * 0.15) });
        gametip.line(gametip.NAME, ('Lv.%d %s'):format(tonumber(o.level) or 0, o.jobs_text or ''));
    end
    gametip.wrap_open = true;
    return true;
end

function gametip.finish()
    if gametip.wrap_open then
        imgui.PopTextWrapPos();
        gametip.wrap_open = false;
    end
    local w, h = xy(imgui.GetWindowSize());
    if w > 0 and h > 0 then sizes[gametip.key or ''] = { w, h }; end
    imgui.EndTooltip();
end

return gametip;
