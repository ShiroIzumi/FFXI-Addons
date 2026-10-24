--[[
    MogSuite - Inventory settings (pages in the MogSuite settings window).
    Every setting goes through `ui` (core/cfgui.lua) so the search box finds it.
]]

-- How the settings window saves this module's changes.
module_config_dirty = function() mark_dirty(); end

local ARMED = {};
local ON = { default_on = true };
local function new_view() state.view_gen = state.view_gen + 1; end

local VIEWS = {
    { key = 'list', label = 'List', tip = 'Icon, name and quantity on each row.' },
    { key = 'grid', label = 'Grid', tip = 'An icon grid with the quantity in the corner.' },
    { key = 'categories', label = 'Categories', tip = 'Items grouped into sections (Weapons, Armor, Usable, ...).' },
    { key = 'usable', label = 'Usable', tip = 'Food, medicines, scrolls, ninja tools and ammo, each in its own section.' },
    { key = 'cleanup', label = 'Cleanup', tip = 'Suggestions only: stacks to merge, items spread over bags, NPC-only sell items, outgrown gear.' },
    { key = 'upgrades', label = 'Upgrades', tip = 'Gear in your Inventory / Wardrobes that beats what you wear.' },
};
local WATCH_MODES = {
    { key = 'drop', label = 'Every time it drops', tip = 'Alerts again each time you use one while you are at or under the limit.' },
    { key = 'once', label = 'Once per login', tip = 'One alert per item until you reload / log in again.' },
};
local QTY = {
    { key = 'x', label = 'x12', tip = 'Shows how many you have, e.g. x12.' },
    { key = 'stack', label = '12/99 (stack)', tip = 'Shows how many you have out of a full stack, e.g. 12/99.' },
};
local CAT_STYLES = {
    { key = 'list', label = 'List' },
    { key = 'grid', label = 'Grid' },
};

local function config_window()
    ui.section('WINDOW');
    ui.check('Lock position and size', config, 'locked', 'Stops the inventory window (and its pop-outs) from being moved or resized.');
    ui.check('Show title bar', config, 'title_bar', 'Shows the window title bar. Without it, the window has its own X button.');
    if ui.button('Reset window position', 'nai_resetpos', 'Moves the inventory window back to its default place and size.') then module_reset_position(); end

    ui.section('HEADER');
    ui.check('Compact header', config, 'compact_header',
        'Two rows: your pinned bags + a Bags menu, then search / sort / view / Filter. Untick for every bag tab and the filter chips (the old look).', ON);
    if config.compact_header ~= false then
        ui.info('Pin or unpin bags in the Bags v menu. Shift+Click a tab or menu entry still opens it in its own window.');
    end

    ui.section('LAYOUT');
    -- Older saves may hold another value: anything else is List.
    local view_tbl = { view = (VIEW_LABELS[config.view] ~= nil) and config.view or 'list' };
    if ui.choice('View', view_tbl, 'view', VIEWS, 'For the main window. Pop-out windows have their own view menu.') then
        config.view = view_tbl.view;
        new_view();
    end
    ui.slider_f('Size', config, 'font_scale', 0.75, 2.50, '%.2fx', 'Scales the text, icons and rows together.');
    ui.slider_i('List icon size', config, 'icon_size', 12, 48, '%d px', 'Icon size in the List view (before Size).');
    ui.slider_i('Grid cell size', config, 'grid_icon', 24, 80, '%d px', 'Cell size in the Grid view (before Size).');
    ui.slider_i('Row spacing', config, 'row_spacing', 0, 10, '%d px', 'Extra space above and below each row.');
    ui.check('Show E / Rare / Ex tags in the list', config, 'show_tags', 'E = equipped, Rare, Ex, and Split for partial stacks.', ON);
end

local function config_items()
    ui.section('ITEMS');
    local q = { qty_format = (config.qty_format == 'stack') and 'stack' or 'x' };
    if ui.choice('Quantity', q, 'qty_format', QTY, 'How quantities are written.') then config.qty_format = q.qty_format; end
    ui.check('Show x1 on single items', config, 'show_qty_one', 'Also shows the quantity on items you have one of.');
    ui.check("Grey out gear your job / level can't wear", config, 'grey_unusable', 'Gear your current job or level cannot equip is drawn dimmed.', ON);
    ui.check('Pin favorites to the top (List / Grid)', config, 'pin_favorites',
        'Right-click an item > Add to favorites. Favorites get a star, sit at the top and cannot be dropped.',
        { default_on = true, on_change = new_view });
    ui.check('Mark split stacks (could be merged)', config, 'show_split', 'Partial stacks of the same item in one bag get a Split tag (a blue corner in the grid).', ON);

    ui.section('INVENTORY FULL WARNING');
    ui.check('Warn at the top of the screen', config, 'warn_full', 'A banner shows for a few seconds when an item comes in and you are at or under the free-slot limit.', ON);
    if config.warn_full ~= false or ui.searching() then
        ui.sub(function()
            ui.slider_i('Free slots or fewer', config, 'warn_free', 0, 20, '%d', 'Warn when this many inventory slots or fewer are left.');
            if ui.button('Test the banner', 'nai_wtest', 'Shows the banner for a few seconds.') then state.warn_until = os.clock() + 5.0; end
        end);
    end

    ui.section('NEW ITEMS');
    ui.check('Highlight items you just got', config, 'new_highlight', 'Items you just received are highlighted. Zoning does not count as new.', ON);
    if config.new_highlight ~= false or ui.searching() then
        ui.sub(function()
            ui.check('Keep highlighted until hovered or the window closes', config, 'new_sticky',
                'On: the highlight stays until you hover the item or close the window. Off: it fades after the time below.', ON);
            if config.new_sticky == false or ui.searching() then
                ui.slider_i('Highlight time', config, 'new_seconds', 2, 60, '%d sec', 'How long the highlight lasts when it is not kept.');
            end
        end);
    end
end

local function config_colors()
    ui.section('COLORS');
    ui.color('Item name', config.name_color, 'Color of item names.', true);
    ui.color('Quantity and gil', config.qty_color, 'Color of quantities, gil and values.', true);
    ui.info('The text effect is set for every window in Global > Text.');

    if ui.preview() then
        ui.section('PREVIEW');
        local dl = imgui.GetWindowDrawList();
        local sx, sy = imgui.GetCursorScreenPos();
        local w = 320 * ui.scale;
        local lh = imgui.GetTextLineHeight();
        dl:AddRectFilled({ sx, sy }, { sx + w, sy + lh + 12 }, imgui.GetColorU32({ 0.45, 0.50, 0.40, 1.0 }), 4.0);
        draw_fx_text(dl, sx + 8, sy + 6, config.name_color, 'Pot of Honey');
        draw_fx_text(dl, sx + 8 + text_w('Pot of Honey'), sy + 6, config.qty_color, ' x12');
        draw_fx_text(dl, sx + w - text_w('1,200 gil') - 8, sy + 6, config.qty_color, '1,200 gil');
        imgui.Dummy({ w, lh + 14 });
    end
end

local function config_value()
    ui.section('ITEM VALUE');
    ui.check('Show sell value (tooltips, footer, categories, log)', config, 'show_value', 'What an NPC vendor pays for the items.', ON);
    ui.check('Show Auction House category in tooltips', config, 'show_ah', 'Where the item is listed on the Auction House, e.g. Materials > Alchemy.', ON);

    ui.section('PRICE LIST');
    if ui.block('Price list item_basic.sql reload prices') then
        load_price_list();
        if prices.source ~= nil then
            imgui.TextColored(config.qty_color, ('%s items'):fmt(fmt_gil(prices.count)));
            imgui.TextDisabled(prices.source);
        else
            imgui.TextColored(UI_DANGER, 'The built-in price list is missing.');
            imgui.TextWrapped('Reinstall MogSuite (data\\item_prices.lua), or put LandSandBoat\'s sql\\item_basic.sql in the MogSuite folder and press Reload.');
        end
    end
    if ui.button('Reload price list', 'nai_reload_prices',
        'Reads the price list again. A LandSandBoat item_basic.sql in the MogSuite folder is used instead of the built-in list when present.') then
        prices.base, prices.nosale, prices.ah, prices.loaded, prices.count, prices.source = {}, {}, {}, false, 0, nil;
        load_price_list();
    end

    ui.section('LEARNED AT VENDORS');
    if ui.block('Learned vendor prices appraise shop') then
        local n = 0;
        for _ in pairs(learned) do n = n + 1; end
        imgui.Text(('%d exact prices learned'):fmt(n));
    end
    ui.info('When a shop appraises an item (you pick it to sell), MogSuite saves the exact price HorizonXI gave you. Learned prices replace the list price and are marked [vendor]. They are shared by all your characters.');
    if ui.danger('Forget learned prices', 'nai_forget', ARMED, 'Deletes every learned vendor price (click twice).') then
        for k in pairs(learned) do learned[k] = nil; end
        write_lua_file(DATA_DIR .. 'prices_learned.lua', learned);
    end
    ui.info('Fame does not change NPC sell prices.');
end

local function config_categories()
    ui.section('CATEGORIES VIEW');
    ui.info('Pick Categories in the view menu of the inventory window.');
    local cs = { cat_style = (config.cat_style == 'grid') and 'grid' or 'list' };
    if ui.choice('Each section shows as', cs, 'cat_style', CAT_STYLES, 'How the items inside each category section are drawn.') then
        config.cat_style = cs.cat_style;
    end

    ui.section('SECTION ORDER');
    ui.info('An item goes in the first section it fits, in this priority: Favorites, New, Equipped, Ammo, Weapons, Armor, Usable, Crystals, Rare / Ex, Materials. The order below is the display order.');
    if ui.block('Section order move up down categories') then
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
    end
    if ui.button('Reset order', 'nai_cat_reset', 'Puts the sections back in their default order.') then
        config.cat_order = T{ 'favorites', 'new', 'equipped', 'weapons', 'armor', 'ammo', 'usable', 'crystals', 'rareex', 'materials' };
        mark_dirty();
    end
    if ui.button('Expand all sections', 'nai_cat_expand', 'Opens every collapsed section again.') then
        config.cat_collapsed = T{};
        mark_dirty();
    end
    ui.info('Click a section header in the inventory to collapse / expand it.');
end

local function config_bags()
    ui.section('BAG TABS');
    ui.info('Untick a bag to hide its tab. Bags your character does not have are not listed.');
    config.hidden_bags = config.hidden_bags or T{};
    local any = false;
    for _, bag in ipairs(TAB_ORDER) do
        local b = state.bags[bag];
        if b ~= nil and bag ~= 3 then
            any = true;
            local name = BAG_NAMES[bag] or ('Bag ' .. bag);
            if ui.want(name, 'bag tab hide show') then
                local shown = { not config.hidden_bags[bag] };
                local label = ('%s  (%d / %d)%s##nai_bag_show_%d'):fmt(name, b.used, b.max,
                    VIEW_ONLY_BAG[bag] and '  view only' or '', bag);
                if imgui.Checkbox(label, shown) then
                    config.hidden_bags[bag] = (not shown[1]) or nil;
                    state.rows_dirty = true;
                    mark_dirty();
                end
            end
        end
    end
    if not any and not ui.searching() then imgui.TextDisabled('Waiting for your inventory...'); end
end

local function config_tooltips()
    ui.section('ITEM TOOLTIPS');
    ui.check('Where it drops', config, 'tip_drops', 'Monsters and zones that drop the item (mobdb data).', ON);
    ui.check('Recipes', config, 'tip_recipes', 'What the item is made from, and which recipes use it (Horizon-era crafts).', ON);
    ui.check('How many you have in other bags', config, 'tip_other_bags', '"You have 12 in Satchel, 3 in Mog Safe".', ON);
    ui.info('Font, size and colors of every tooltip: Settings > Global > Fonts & Tooltips.');
end

local function config_watch()
    ui.section('WATCH LIST');
    ui.info('Right-click an item > Watch this item. You get an alert window when you are down to the number set here (carried bags count).');
    config.watch = config.watch or T{};
    local ids = {};
    for id in pairs(config.watch) do ids[#ids + 1] = id; end
    table.sort(ids, function(a, b) return (item_name_of(a) or '') < (item_name_of(b) or ''); end);
    if #ids == 0 and not ui.searching() then imgui.TextDisabled('No items watched yet.'); end
    for _, id in ipairs(ids) do
        local w = config.watch[id];
        local name = item_name_of(id);
        if ui.want(name, 'watch list item alert') then
            ui.label(name, 'Alert when you have this many or fewer.');
            imgui.PushItemWidth(110 * (ui.scale or 1));
            local v = { tonumber(w.min) or 1 };
            if imgui.InputInt('##nai_w_' .. tostring(id), v) then
                w.min = math.max(0, math.min(9999, v[1]));
                watch.alerted[id] = nil;
                mark_dirty();
            end
            imgui.PopItemWidth();
            imgui.SameLine();
            if imgui.SmallButton('Remove##nai_wr_' .. tostring(id)) then
                config.watch[id] = nil;
                mark_dirty();
            end
        end
    end
    ui.section('ALERT');
    ui.choice('Alert', config, 'watch_mode', WATCH_MODES, 'How often a running-low item alerts.', { default = 'drop' });
    ui.check('Play a sound', config, 'watch_sound', 'Plays a sound with the alert window.');
    if config.watch_sound == true or ui.searching() then
        if ui.want('Sound file', 'wav path sound') then
            ui.label('Sound file', 'A .wav file. Empty = the Windows notify sound.');
            config.watch_sound_file = config.watch_sound_file or '';
            local buf = { tostring(config.watch_sound_file) };
            imgui.PushItemWidth(320 * (ui.scale or 1));
            if imgui.InputText('##nai_w_sound', buf, 260) then
                config.watch_sound_file = buf[1];
                mark_dirty();
            end
            imgui.PopItemWidth();
            imgui.SameLine();
            if imgui.SmallButton('Test##nai_w_test') then
                local p = tostring(config.watch_sound_file or '');
                if p == '' then p = DEFAULT_SOUND; end
                pcall(function() ashita.misc.play_sound(p); end);
            end
        end
    end
end

module_config_sections = {
    { key = 'window', label = 'Window', draw = config_window, desc = 'Where the inventory window sits, how it lays items out, and how big rows and icons are.' },
    { key = 'items', label = 'Items', draw = config_items, desc = 'How quantities read, which items stand out, the inventory-full warning and new-item highlights.' },
    { key = 'colors', label = 'Colors', draw = config_colors, desc = 'Colors for item names, quantities and gil.' },
    { key = 'tooltips', label = 'Tooltips', draw = config_tooltips, desc = 'What item tooltips show: drops, recipes, other bags, AH category.' },
    { key = 'watch', label = 'Watch list', draw = config_watch, desc = 'Items that alert you when you are running low.' },
    { key = 'value', label = 'Value', draw = config_value, desc = 'Vendor sell values, the price list, and prices learned at shops.' },
    { key = 'categories', label = 'Categories', draw = config_categories, desc = 'How the Categories view draws its sections, and their order.' },
    { key = 'bags', label = 'Bags', draw = config_bags, desc = 'Which bag tabs show in the inventory window.' },
};
