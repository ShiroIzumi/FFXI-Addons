--[[
    MogSuite - Inventory settings (drawn inside the MogSuite config window).
]]

local function checkbox(label, key, default_on, tooltip, on_change)
    local v = { (default_on and config[key] ~= false) or (not default_on and config[key] == true) };
    if imgui.Checkbox(label, v) then
        config[key] = v[1];
        if on_change then on_change(); end
        mark_dirty();
    end
    if tooltip then tip(tooltip); end
end

local function config_window()
    section_header('Window');
    checkbox('Lock position and size##nai_lock', 'locked', false, 'Stops the inventory window (and its pop-outs) from being moved or resized.');
    checkbox('Show title bar##nai_tb', 'title_bar', false, 'Shows the window title bar. Without it, the window has its own X button.');
    if imgui.Button('Reset window position##nai_resetpos') then module_reset_position(); end
    tip('Moves the inventory window back to its default place and size.');

    imgui.Spacing();
    section_header('Layout');
    align_label();
    imgui.Text('View:');
    imgui.SameLine();
    if imgui.RadioButton('List##nai_vlist', config.view ~= 'grid' and config.view ~= 'categories') then config.view = 'list'; state.view_gen = state.view_gen + 1; mark_dirty(); end
    tip('Icon, name and quantity on each row.');
    imgui.SameLine();
    if imgui.RadioButton('Grid##nai_vgrid', config.view == 'grid') then config.view = 'grid'; state.view_gen = state.view_gen + 1; mark_dirty(); end
    tip('An icon grid with the quantity in the corner.');
    imgui.SameLine();
    if imgui.RadioButton('Categories##nai_vcat', config.view == 'categories') then config.view = 'categories'; state.view_gen = state.view_gen + 1; mark_dirty(); end
    tip('Items grouped into sections (Weapons, Armor, Usable, ...).');
    imgui.TextDisabled('For the main window. Pop-out windows have their own view menu.');

    imgui.PushItemWidth(220);
    local fs = { tonumber(config.font_scale) or 1.0 };
    if imgui.SliderFloat('Size##nai_fs', fs, 0.75, 2.50, '%.2fx', ImGuiSliderFlags_AlwaysClamp) then config.font_scale = fs[1]; mark_dirty(); end
    tip('Scales the text, icons and rows together.');
    local ic = { tonumber(config.icon_size) or 24 };
    if imgui.SliderInt('List icon size##nai_ic', ic, 12, 48, '%d px', ImGuiSliderFlags_AlwaysClamp) then config.icon_size = ic[1]; mark_dirty(); end
    tip('Icon size in the List view (before Size).');
    local gi = { tonumber(config.grid_icon) or 40 };
    if imgui.SliderInt('Grid cell size##nai_gi', gi, 24, 80, '%d px', ImGuiSliderFlags_AlwaysClamp) then config.grid_icon = gi[1]; mark_dirty(); end
    tip('Cell size in the Grid view (before Size).');
    local rs = { tonumber(config.row_spacing) or 2 };
    if imgui.SliderInt('Row spacing##nai_rs', rs, 0, 10, '%d px', ImGuiSliderFlags_AlwaysClamp) then config.row_spacing = rs[1]; mark_dirty(); end
    tip('Extra space above and below each row.');
    imgui.PopItemWidth();
    checkbox('Show E / Rare / Ex tags in the list##nai_tags', 'show_tags', true, 'E = equipped, Rare, Ex, and Split for partial stacks.');
end

local function config_items()
    section_header('Items');
    align_label();
    imgui.Text('Quantity:');
    imgui.SameLine();
    if imgui.RadioButton('x12##nai_qf_x', config.qty_format ~= 'stack') then config.qty_format = 'x'; mark_dirty(); end
    tip('Shows how many you have, e.g. x12.');
    imgui.SameLine();
    if imgui.RadioButton('12/99 (stack)##nai_qf_s', config.qty_format == 'stack') then config.qty_format = 'stack'; mark_dirty(); end
    tip('Shows how many you have out of a full stack, e.g. 12/99.');
    checkbox('Show x1 on single items##nai_q1', 'show_qty_one', false, 'Also shows the quantity on items you have one of.');
    checkbox("Grey out gear your job / level can't wear##nai_gu", 'grey_unusable', true, 'Gear your current job or level cannot equip is drawn dimmed.');
    checkbox('Pin favorites to the top (List / Grid)##nai_pf', 'pin_favorites', true,
        'Right-click an item > Add to favorites. Favorites get a star, sit at the top and cannot be dropped.',
        function() state.view_gen = state.view_gen + 1; end);
    checkbox('Mark split stacks (could be merged)##nai_ss', 'show_split', true, 'Partial stacks of the same item in one bag get a Split tag (a blue corner in the grid).');

    imgui.Spacing();
    section_header('Inventory full warning');
    checkbox('Warn at the top of the screen##nai_wf', 'warn_full', true, 'A banner shows for a few seconds when an item comes in and you are at or under the free-slot limit.');
    imgui.PushItemWidth(220);
    local wn = { tonumber(config.warn_free) or 5 };
    if imgui.SliderInt('Free slots or fewer##nai_wn', wn, 0, 20, '%d', ImGuiSliderFlags_AlwaysClamp) then config.warn_free = wn[1]; mark_dirty(); end
    tip('Warn when this many inventory slots or fewer are left.');
    imgui.PopItemWidth();
    imgui.SameLine();
    if imgui.Button('Test##nai_wtest') then state.warn_until = os.clock() + 5.0; end
    tip('Shows the banner for a few seconds.');

    imgui.Spacing();
    section_header('New items');
    checkbox('Highlight items you just got##nai_new', 'new_highlight', true, 'Items you just received are highlighted. Zoning does not count as new.');
    checkbox('Keep highlighted until hovered or the window closes##nai_newsticky', 'new_sticky', true,
        'On: the highlight stays until you hover the item or close the window. Off: it fades after the time below.');
    if config.new_sticky == false then
        imgui.PushItemWidth(220);
        local ns = { tonumber(config.new_seconds) or 10 };
        if imgui.SliderInt('Highlight time##nai_newsec', ns, 2, 60, '%d sec', ImGuiSliderFlags_AlwaysClamp) then config.new_seconds = ns[1]; mark_dirty(); end
        imgui.PopItemWidth();
    end
end

local function config_colors()
    section_header('Colors');
    if color_edit('Item name##nai_namec', config.name_color, true) then mark_dirty(); end
    tip('Color of item names.');
    if color_edit('Quantity and gil##nai_qtyc', config.qty_color, true) then mark_dirty(); end
    tip('Color of quantities, gil and values.');
    imgui.TextDisabled('The text effect is set for every window in Global > Text.');

    imgui.Spacing();
    section_header('Preview');
    local dl = imgui.GetWindowDrawList();
    local sx, sy = imgui.GetCursorScreenPos();
    dl:AddRectFilled({ sx, sy }, { sx + 300, sy + imgui.GetTextLineHeight() + 12 }, imgui.GetColorU32({ 0.45, 0.50, 0.40, 1.0 }), 4.0);
    draw_fx_text(dl, sx + 8, sy + 6, config.name_color, 'Pot of Honey');
    draw_fx_text(dl, sx + 8 + text_w('Pot of Honey'), sy + 6, config.qty_color, ' x12');
    imgui.Dummy({ 300, imgui.GetTextLineHeight() + 14 });
end

local function config_value()
    section_header('Item value');
    checkbox('Show sell value (tooltips, footer, categories, log)##nai_sv', 'show_value', true, 'What an NPC vendor pays for the items.');
    checkbox('Show Auction House category in tooltips##nai_sa', 'show_ah', true, 'Where the item is listed on the Auction House, e.g. Materials > Alchemy.');

    imgui.Spacing();
    section_header('Price list');
    load_price_list();
    if prices.source ~= nil then
        imgui.TextColored(config.qty_color, ('%s items'):fmt(fmt_gil(prices.count)));
        imgui.TextDisabled(prices.source);
    else
        imgui.TextColored(UI_DANGER, 'The built-in price list is missing.');
        imgui.TextWrapped('Reinstall MogSuite (data\\item_prices.lua), or put LandSandBoat\'s sql\\item_basic.sql in the MogSuite folder and press Reload.');
    end
    if imgui.Button('Reload price list##nai_reload_prices') then
        prices.base, prices.nosale, prices.ah, prices.loaded, prices.count, prices.source = {}, {}, {}, false, 0, nil;
        load_price_list();
    end
    tip('Reads the price list again. A LandSandBoat item_basic.sql in the MogSuite folder is used instead of the built-in list when present.');

    imgui.Spacing();
    section_header('Learned at vendors');
    local n = 0;
    for _ in pairs(learned) do n = n + 1; end
    imgui.Text(('%d exact prices learned'):fmt(n));
    imgui.TextWrapped('When a shop appraises an item (you pick it to sell), MogSuite saves the exact price HorizonXI gave you. Learned prices replace the list price and are marked [vendor]. They are shared by all your characters.');
    local armed = state.forget_armed ~= nil and os.clock() - state.forget_armed < 3.0;
    if armed then imgui.PushStyleColor(ImGuiCol_Button, { 0.72, 0.16, 0.16, 1.0 }); end
    local clicked = imgui.Button((armed and 'Click again to forget' or 'Forget learned prices') .. '##nai_forget');
    if armed then imgui.PopStyleColor(1); end
    tip('Deletes every learned vendor price (click twice).');
    if clicked then
        if armed then
            for k in pairs(learned) do learned[k] = nil; end
            write_lua_file(DATA_DIR .. 'prices_learned.lua', learned);
            state.forget_armed = nil;
        else
            state.forget_armed = os.clock();
        end
    end
    imgui.Spacing();
    imgui.TextDisabled('Fame does not change NPC sell prices.');
end

local function config_categories()
    section_header('Categories view');
    imgui.TextDisabled('Pick Categories in the view menu of the inventory window.');
    align_label();
    imgui.Text('Each section shows as:');
    imgui.SameLine();
    if imgui.RadioButton('List##nai_cs_list', config.cat_style ~= 'grid') then config.cat_style = 'list'; mark_dirty(); end
    imgui.SameLine();
    if imgui.RadioButton('Grid##nai_cs_grid', config.cat_style == 'grid') then config.cat_style = 'grid'; mark_dirty(); end

    imgui.Spacing();
    section_header('Section order');
    imgui.TextWrapped('An item goes in the first section it fits, in this priority: Favorites, New, Equipped, Ammo, Weapons, Armor, Usable, Crystals, Rare / Ex, Materials. The order below is the display order.');
    imgui.Spacing();
    local order = cat_order();
    local move_from, move_to = nil, nil;
    for i, k in ipairs(order) do
        if imgui.ArrowButton ~= nil then
            if imgui.ArrowButton('##nai_cat_up_' .. k, ImGuiDir_Up or 2) and i > 1 then move_from, move_to = i, i - 1; end
            tip('Move up');
            imgui.SameLine(0, 2);
            if imgui.ArrowButton('##nai_cat_dn_' .. k, ImGuiDir_Down or 3) and i < #order then move_from, move_to = i, i + 1; end
            tip('Move down');
        else
            if imgui.Button('^##nai_cat_up_' .. k) and i > 1 then move_from, move_to = i, i - 1; end
            imgui.SameLine(0, 2);
            if imgui.Button('v##nai_cat_dn_' .. k) and i < #order then move_from, move_to = i, i + 1; end
        end
        imgui.SameLine(0, 10);
        align_label();
        imgui.Text(('%d.  %s'):fmt(i, CATEGORIES[k]));
        if config.cat_collapsed and config.cat_collapsed[k] then
            imgui.SameLine(0, 8);
            imgui.TextDisabled('(collapsed)');
        end
    end
    if move_from ~= nil then
        order[move_from], order[move_to] = order[move_to], order[move_from];
        config.cat_order = T(order);
        mark_dirty();
    end
    imgui.Spacing();
    if imgui.Button('Reset order##nai_cat_reset') then
        config.cat_order = T{ 'favorites', 'new', 'equipped', 'weapons', 'armor', 'ammo', 'usable', 'crystals', 'rareex', 'materials' };
        mark_dirty();
    end
    tip('Puts the sections back in their default order.');
    imgui.SameLine();
    if imgui.Button('Expand all sections##nai_cat_expand') then
        config.cat_collapsed = T{};
        mark_dirty();
    end
    tip('Opens every collapsed section again.');
    imgui.TextDisabled('Click a section header in the inventory to collapse / expand it.');
end

local function config_bags()
    section_header('Bag tabs');
    imgui.TextDisabled('Untick a bag to hide its tab. Bags your character does not have are not listed.');
    config.hidden_bags = config.hidden_bags or T{};
    local any = false;
    for _, bag in ipairs(TAB_ORDER) do
        local b = state.bags[bag];
        if b ~= nil and bag ~= 3 then
            any = true;
            local shown = { not config.hidden_bags[bag] };
            local label = ('%s  (%d / %d)%s##nai_bag_show_%d'):fmt(BAG_NAMES[bag] or ('Bag ' .. bag), b.used, b.max,
                VIEW_ONLY_BAG[bag] and '  view only' or '', bag);
            if imgui.Checkbox(label, shown) then
                config.hidden_bags[bag] = (not shown[1]) or nil;
                state.rows_dirty = true;
                mark_dirty();
            end
        end
    end
    if not any then imgui.TextDisabled('Waiting for your inventory...'); end
end

module_config_sections = {
    { key = 'window', label = 'Window', draw = config_window },
    { key = 'items', label = 'Items', draw = config_items },
    { key = 'colors', label = 'Colors', draw = config_colors },
    { key = 'value', label = 'Value', draw = config_value },
    { key = 'categories', label = 'Categories', draw = config_categories },
    { key = 'bags', label = 'Bags', draw = config_bags },
};
