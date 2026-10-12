--[[
    MogSuite - modules/character/currencies.lua

    The Currencies tab. Read from the game's own Currencies list (packet 0x113) when
    you open Main Menu > Currencies; MogSuite never asks the server for it.
]]

-- ============================================================================
-- Currencies tab (1.5.0)
-- Read from packet 0x113, which the server sends when you open Main Menu >
-- Currencies. MogSuite only listens; it never requests it. Saved per
-- character with the settings.
-- ============================================================================

-- { offset, type ('i' int32, 'H' uint16, 'B' uint8), name, group }
CURRENCY_FIELDS = {
    { 0x04, 'i', "Conquest Points (San d'Oria)", 'Conquest' },
    { 0x08, 'i', 'Conquest Points (Bastok)', 'Conquest' },
    { 0x0C, 'i', 'Conquest Points (Windurst)', 'Conquest' },
    { 0x10, 'H', "Beastmen's Seals", 'Seals and crests' },
    { 0x12, 'H', "Kindred's Seals", 'Seals and crests' },
    { 0x14, 'H', "Kindred's Crests", 'Seals and crests' },
    { 0x16, 'H', "High Kindred's Crests", 'Seals and crests' },
    { 0x18, 'H', "Sacred Kindred's Crests", 'Seals and crests' },
    { 0x1A, 'H', 'Ancient Beastcoins', 'Seals and crests' },
    { 0x1C, 'H', 'Valor Points', 'Fields of Valor' },
    { 0x1E, 'H', 'Scylds', 'Other' },
    { 0x20, 'i', 'Guild Points (Fishing)', 'Guild' },
    { 0x24, 'i', 'Guild Points (Woodworking)', 'Guild' },
    { 0x28, 'i', 'Guild Points (Smithing)', 'Guild' },
    { 0x2C, 'i', 'Guild Points (Goldsmithing)', 'Guild' },
    { 0x30, 'i', 'Guild Points (Clothcraft)', 'Guild' },
    { 0x34, 'i', 'Guild Points (Leathercraft)', 'Guild' },
    { 0x38, 'i', 'Guild Points (Bonecraft)', 'Guild' },
    { 0x3C, 'i', 'Guild Points (Alchemy)', 'Guild' },
    { 0x40, 'i', 'Guild Points (Cooking)', 'Guild' },
    { 0x44, 'i', 'Cinders', 'Synergy' },
    { 0x48, 'B', 'Fire Fewell', 'Synergy' },
    { 0x49, 'B', 'Ice Fewell', 'Synergy' },
    { 0x4A, 'B', 'Wind Fewell', 'Synergy' },
    { 0x4B, 'B', 'Earth Fewell', 'Synergy' },
    { 0x4C, 'B', 'Lightning Fewell', 'Synergy' },
    { 0x4D, 'B', 'Water Fewell', 'Synergy' },
    { 0x4E, 'B', 'Light Fewell', 'Synergy' },
    { 0x4F, 'B', 'Dark Fewell', 'Synergy' },
    { 0x50, 'i', 'Ballista Points', 'Ballista' },
    { 0x54, 'i', 'Fellow Points', 'Adventuring Fellow' },
    { 0x58, 'H', "Chocobucks (San d'Oria)", 'Chocobo' },
    { 0x5A, 'H', 'Chocobucks (Bastok)', 'Chocobo' },
    { 0x5C, 'H', 'Chocobucks (Windurst)', 'Chocobo' },
    { 0x5E, 'H', 'Daily Tally', 'Other' },
    { 0x60, 'i', 'Research Marks', 'Other' },
    { 0x64, 'B', 'Wizened Tunnel Worms', 'Other' },
    { 0x65, 'B', 'Wizened Morion Worms', 'Other' },
    { 0x66, 'B', 'Wizened Phantom Worms', 'Other' },
    { 0x68, 'i', 'Moblin Marbles', 'Moblin Maze Mongers' },
    { 0x6C, 'H', 'Infamy', 'Other' },
    { 0x6E, 'H', 'Prestige', 'Other' },
    { 0x70, 'i', 'Legion Points', 'Legion' },
    { 0x74, 'i', 'Sparks of Eminence', 'Other' },
    { 0x78, 'i', 'Shining Stars', 'Other' },
    { 0x7C, 'i', 'Imperial Standing', 'Aht Urhgan' },
    { 0x80, 'i', 'Assault Points (Leujaoam Sanctum)', 'Assault' },
    { 0x84, 'i', 'Assault Points (Mamool Ja Training Grounds)', 'Assault' },
    { 0x88, 'i', 'Assault Points (Lebros Cavern)', 'Assault' },
    { 0x8C, 'i', 'Assault Points (Periqia)', 'Assault' },
    { 0x90, 'i', 'Assault Points (Ilrusi Atoll)', 'Assault' },
    { 0x94, 'i', 'Assault Points (Nyzul Isle)', 'Assault' },
    { 0x98, 'i', 'Zeni', 'Aht Urhgan' },
    { 0x9C, 'i', 'Jettons', 'Other' },
    { 0xA0, 'i', 'Therion Ichor', 'Einherjar' },
    { 0xA4, 'i', 'Allied Notes', 'Campaign' },
    { 0xA8, 'H', 'A.M.A.N. Vouchers', 'Other' },
    { 0xAA, 'H', 'Login Points', 'Other' },
    { 0xAC, 'i', 'Cruor', 'Other' },
    { 0xB0, 'i', 'Resistance Credits', 'Other' },
    { 0xB4, 'i', 'Dominion Notes', 'Other' },
    { 0xB8, 'B', '5th Echelon Battle Trophies', 'Campaign' },
    { 0xB9, 'B', '4th Echelon Battle Trophies', 'Campaign' },
    { 0xBA, 'B', '3rd Echelon Battle Trophies', 'Campaign' },
    { 0xBB, 'B', '2nd Echelon Battle Trophies', 'Campaign' },
    { 0xBC, 'B', '1st Echelon Battle Trophies', 'Campaign' },
    { 0xBD, 'B', 'Cave Conservation Points', 'Other' },
    { 0xBE, 'B', 'Imperial Army ID Tags', 'Other' },
    { 0xBF, 'B', 'Op Credits', 'Other' },
    { 0xC0, 'i', 'Traverser Stones', 'Other' },
    { 0xC4, 'i', 'Voidstones', 'Other' },
    { 0xC8, 'i', "Kupofried's Corundums", 'Other' },
};

-- Reads every field the packet is long enough for.
function parse_currencies(data)
    local values = T{};
    local size = #data;
    for _, f in ipairs(CURRENCY_FIELDS) do
        local bytes = (f[2] == 'i') and 4 or ((f[2] == 'H') and 2 or 1);
        if f[1] + bytes <= size then
            local ok, v = pcall(struct.unpack, f[2], data, f[1] + 1);
            if ok and tonumber(v) ~= nil then
                values[f[3]] = math.max(0, tonumber(v));
            end
        end
    end
    return values;
end

-- 67622 -> "67,622"
function fmt_thousands(n)
    local s = tostring(math.floor(tonumber(n) or 0));
    local neg = s:sub(1, 1) == '-';
    if neg then s = s:sub(2); end
    s = s:reverse():gsub('(%d%d%d)', '%1,'):reverse();
    if s:sub(1, 1) == ',' then s = s:sub(2); end
    return (neg and '-' or '') .. s;
end

function currency_ago(t)
    local seconds = math.max(0, os.time() - (tonumber(t) or os.time()));
    if seconds < 60 then return 'updated just now'; end
    if seconds < 3600 then return ('updated %dm ago'):fmt(math.floor(seconds / 60)); end
    if seconds < 86400 then return ('updated %dh ago'):fmt(math.floor(seconds / 3600)); end
    return ('updated %dd ago'):fmt(math.floor(seconds / 86400));
end

-- Name / amount tiles, alphabetical down each column (two columns when
-- there is room). dim = the zero group.
function draw_currency_tiles(list, dim, id)
    local scale = state.overall_scale[1];
    local avail = avail_width();
    local gap = 5 * scale;
    local pad = 8 * scale;
    local lh = line_height();

    local need = 0;
    local lh_big = lh;
    for _, c in ipairs(list) do
        local w, h = big_text_size(c.text);
        c.text_w = w;
        lh_big = h;
        need = math.max(need, text_width(c.name) + w + pad * 2 + 14 * scale);
    end
    require_width(need);
    local columns = fit_columns(2, need, gap, avail, 1);
    local tile_w = (avail - gap * (columns - 1)) / columns;
    local tile_h = lh_big + 8 * scale;
    local rows = math.ceil(#list / columns);
    local ox, oy = screen_xy();
    local hovered = nil;

    local name_col = dim and with_alpha(state.muted_color, 0.60) or state.muted_color;
    local value_col = dim and with_alpha(state.muted_color, 0.45) or UI_BRIGHT;
    local bg = dim and TILE_BG_LOCKED or TILE_BG;

    for i, c in ipairs(list) do
        local col = math.floor((i - 1) / rows);
        local row = (i - 1) % rows;
        local x = ox + col * (tile_w + gap);
        local y = oy + row * (tile_h + gap);
        imgui.SetCursorScreenPos({ x, y });
        imgui.InvisibleButton(('##cs_cur_%s_%d'):fmt(id, i), { math.max(1, tile_w), math.max(1, tile_h) });
        local over = imgui.IsItemHovered();
        tile_rect(x, y, tile_w, tile_h, over and ui_accent(0.12) or bg);
        text_at(x + pad, y + (tile_h - lh) / 2, name_col, c.name);
        big_text_at(x + tile_w - pad - c.text_w, y + (tile_h - lh_big) / 2, value_col, c.text);
        if over then hovered = c; end
    end
    end_tile_block(ox, oy, rows * (tile_h + gap) - gap);

    if hovered ~= nil then
        imgui.BeginTooltip();
        imgui.TextColored(UI_ACCENT_TEXT, hovered.name);
        imgui.TextColored(state.muted_color, hovered.group);
        imgui.TextColored(UI_BRIGHT, fmt_thousands(hovered.value));
        imgui.EndTooltip();
    end
end

function draw_currencies_tab()
    local scale = state.overall_scale[1];
    local saved = config.currencies or T{};
    local values = saved.values or T{};
    local have_data = (tonumber(saved.at) or 0) > 0;

    -- Search + Show zero, "updated ..." on the right.
    local start_x = imgui.GetCursorPosX();
    local full_w = avail_width();
    local search_w = math.max(140 * scale, math.min(280 * scale, full_w * 0.42));
    imgui.PushItemWidth(search_w);
    if imgui.InputTextWithHint ~= nil then
        imgui.InputTextWithHint('##cs_cur_search', 'Search currencies', state.cur_search, 64);
    else
        imgui.InputText('##cs_cur_search', state.cur_search, 64);
    end
    imgui.PopItemWidth();
    imgui.SameLine(0, 6 * scale);
    if draw_toggle_button('Show zero', 'cs_cur_zero', state.cur_show_zero[1] == true) then
        state.cur_show_zero[1] = not state.cur_show_zero[1];
        state.settings_dirty = true;
    end
    tip('Also list currencies you have none of');
    local note = have_data and currency_ago(saved.at) or 'not loaded yet';
    require_width(search_w + text_width('Show zero') + text_width(note) + 50 * scale);
    imgui.SameLine();
    imgui.SetCursorPosX(math.max(imgui.GetCursorPosX() + 8 * scale, start_x + full_w - text_width(note)));
    imgui.AlignTextToFramePadding();
    imgui.TextColored(state.muted_color, note);
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Open Main Menu > Currencies in game to refresh.');
    end

    if not have_data then
        imgui.Spacing();
        imgui.TextColored(state.muted_color, 'No currency data for this character yet.');
        imgui.TextColored(state.muted_color, 'Open Main Menu > Currencies in game once; MogSuite remembers it.');
        return;
    end

    local query = tostring(state.cur_search[1] or ''):lower():gsub('^%s+', ''):gsub('%s+$', '');
    local held, zero = {}, {};
    for _, f in ipairs(CURRENCY_FIELDS) do
        local v = values[f[3]];
        if v ~= nil and (query == '' or f[3]:lower():find(query, 1, true) ~= nil or f[4]:lower():find(query, 1, true) ~= nil) then
            local entry = { name = f[3], group = f[4], value = tonumber(v) or 0, text = fmt_thousands(v) };
            if entry.value > 0 then held[#held + 1] = entry; else zero[#zero + 1] = entry; end
        end
    end
    local by_name = function(a, b) return a.name:lower() < b.name:lower(); end;
    table.sort(held, by_name);
    table.sort(zero, by_name);

    sheet_section('EARNED', (#held == 1) and '1 currency' or (('%d currencies'):fmt(#held)));
    imgui.Spacing();
    if #held > 0 then
        draw_currency_tiles(held, false, 'held');
    else
        imgui.TextColored(state.muted_color, (query ~= '') and 'Nothing earned matches the search.' or 'Nothing earned yet.');
    end

    if state.cur_show_zero[1] and #zero > 0 then
        sheet_section('NONE YET', ('%d'):fmt(#zero));
        imgui.Spacing();
        draw_currency_tiles(zero, true, 'zero');
    elseif query ~= '' and #held == 0 and #zero == 0 then
        imgui.Spacing();
        imgui.TextColored(state.muted_color, 'No currency matches the search.');
    end
end
