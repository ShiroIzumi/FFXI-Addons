--[[
    MogSuite - modules/inventory/keyitems.lua

    The Key Items tab: read from the game's key item packets, with TEMP tags.
]]

-- Key Items tab
-- ----------------------------------------------------------------------------

KEY_ITEM_MAX = 3071;

-- Key item names (the resource table name differs between Ashita builds).
function key_item_name(rm, id)
    local name = nil;
    for _, tbl in ipairs({ 'keyitems.names', 'keyitems' }) do
        pcall(function() name = rm:GetString(tbl, id); end);
        if name ~= nil and tostring(name) ~= '' then return tostring(name); end
    end
    return 'Key Item ' .. id;
end

-- Your key items (permanent and temporary): from the game's own key item
-- list packets (0x055, sent on login / zoning, remembered per character) plus
-- Ashita's HasKeyItem when that works on your build.
function scan_key_items()
    local have = {};
    local name = get_player_name() or state.player_name;
    local rec = name and chars[name] or nil;
    -- Tables seen this session win over the saved copy.
    local tables = {};
    if rec ~= nil and rec.ki ~= nil then
        for tbl, ids in pairs(rec.ki) do tables[tonumber(tbl) or tbl] = ids; end
    end
    for tbl, entry in pairs(state.ki_session or {}) do
        if entry.owner == nil or entry.owner == name then tables[tbl] = entry.ids; end
    end
    for _, ids in pairs(tables) do
        for _, id in ipairs(ids) do have[tonumber(id) or 0] = true; end
    end
    pcall(function()
        local player = AshitaCore:GetMemoryManager():GetPlayer();
        local errors = 0;
        for id = 1, KEY_ITEM_MAX do
            local ok, v = pcall(function() return player:HasKeyItem(id); end);
            if ok then
                if v == true or v == 1 then have[id] = true; end
            else
                errors = errors + 1;
                if errors > 3 then break; end   -- not available on this build
            end
        end
    end);

    local rm = AshitaCore:GetResourceManager();
    local list = {};
    for id in pairs(have) do
        if id > 0 then
            local n = key_item_name(rm, id);
            list[#list + 1] = { id = id, name = n, name_lower = n:lower() };
        end
    end
    table.sort(list, function(a, b) return a.name_lower < b.name_lower; end);
    state.key_items = list;
    state.key_items_at = os.clock();
end

function draw_key_items_view()
    if state.key_items == nil or os.clock() - state.key_items_at > 5.0 then scan_key_items(); end
    local query = tostring(VS.search[1] or ''):lower():gsub('^%s+', ''):gsub('%s+$', '');
    local line_h = imgui.GetTextLineHeight();
    local row_h = line_h + (tonumber(config.row_spacing) or 2) * 2 + 2;
    local width = tonumber((imgui.GetContentRegionAvail())) or 300;
    local dl = imgui.GetWindowDrawList();
    local kf = state.ki_filter or 'all';
    local shown = 0;
    for _, k in ipairs(state.key_items) do
        local cat, auto = ki_category(k.id, k.name_lower);
        if (query == '' or k.name_lower:find(query, 1, true) ~= nil) and (kf == 'all' or kf == cat) then
            shown = shown + 1;
            local sx, sy = imgui.GetCursorScreenPos();
            imgui.InvisibleButton('##nai_ki_' .. k.id, { math.max(1, width), row_h });
            local hovered = imgui.IsItemHovered();
            local is_temp = cat == 'temporary';
            if hovered and imgui.IsMouseClicked(1) then
                local want = not is_temp;
                if want == (auto == 'temporary') then
                    ki_temp[k.id] = nil;      -- back to the built-in list
                else
                    ki_temp[k.id] = want;     -- your override
                end
                is_temp = want;
                write_lua_file(DATA_DIR .. 'key_items_temp.lua', ki_temp);
            end
            if hovered then
                local tip = is_temp and 'Temporary  -  right-click to mark as permanent' or 'Right-click to mark as temporary';
                if ki_temp[k.id] ~= nil then tip = tip .. '\n(your mark - right-click again to go back to the default)'; end
                imgui.SetTooltip(tip);
            end
            if imgui.IsItemVisible == nil or imgui.IsItemVisible() then
                if shown % 2 == 0 then
                    dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32({ 1, 1, 1, 0.025 }), 3.0);
                end
                if imgui.IsItemHovered() then
                    dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32(accent(0.16)), 3.0);
                end
                local cy = sy + row_h * 0.5;
                dl:AddCircleFilled({ sx + 10, cy }, math.max(2.5, line_h * 0.16), imgui.GetColorU32(accent(0.9)), 12);
                draw_fx_text(dl, sx + 22, sy + (row_h - line_h) * 0.5, config.name_color, k.name);
                if is_temp then
                    local label = 'TEMP';
                    local tw = text_w(label);
                    local bx2 = sx + width - 6;
                    local bx1 = bx2 - tw - 12;
                    local by1, by2 = sy + 2, sy + row_h - 2;
                    dl:AddRectFilled({ bx1, by1 }, { bx2, by2 }, imgui.GetColorU32({ 0.95, 0.70, 0.30, 0.18 }), 4.0);
                    dl:AddRect({ bx1, by1 }, { bx2, by2 }, imgui.GetColorU32({ 0.95, 0.70, 0.30, 0.75 }), 4.0, 0, 1.0);
                    draw_fx_text(dl, bx1 + 6, sy + (row_h - line_h) * 0.5, { 0.98, 0.76, 0.36, 1.0 }, label);
                end
            end
        end
    end
    if shown == 0 then
        imgui.TextDisabled(#state.key_items == 0 and 'No key items found (zone once to load them).' or 'No key items match the search / filter.');
    end
    return shown;
end
