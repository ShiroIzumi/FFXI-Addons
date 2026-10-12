--[[
    MogSuite - modules/character/stats.lua

    Player access, gear stats read from your equipped items' descriptions, haste
    effects and the stat cards.
]]

function safe_call(obj, method_name, ...)
    if obj == nil then return nil; end
    local fn = obj[method_name];
    if type(fn) ~= 'function' then return nil; end
    local ok, value = pcall(fn, obj, ...);
    if not ok then return nil; end
    return value;
end

function get_player()
    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return nil; end
    return mm:GetPlayer();
end

function get_party()
    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return nil; end
    return mm:GetParty();
end

function get_inventory()
    local mm = AshitaCore:GetMemoryManager();
    if mm == nil then return nil; end
    return mm:GetInventory();
end

function section_title(text)
    imgui.TextColored(UI_ACCENT_TEXT, text);
end

function value_text(label, value, same_line)
    if same_line then imgui.SameLine(); end
    imgui.TextColored(state.muted_color, label);
    imgui.SameLine();
    imgui.Text(tostring(value));
end

function stat_total(player, index)
    local base = tonumber(safe_call(player, 'GetStat', index)) or 0;
    local mod = tonumber(safe_call(player, 'GetStatModifier', index)) or 0;
    return base + mod, base, mod;
end

function fmt_signed(n)
    n = tonumber(n) or 0;
    if n >= 0 then return '+' .. tostring(math.floor(n)); end
    return tostring(math.floor(n));
end

function get_current_vitals(player)
    local party = get_party();
    local hp = tonumber(safe_call(party, 'GetMemberHP', 0));
    local mp = tonumber(safe_call(party, 'GetMemberMP', 0));
    local tp = tonumber(safe_call(party, 'GetMemberTP', 0));
    local hpmax = tonumber(safe_call(player, 'GetHPMax')) or 0;
    local mpmax = tonumber(safe_call(player, 'GetMPMax')) or 0;
    return hp or 0, hpmax, mp or 0, mpmax, tp or 0;
end

push_sheet_theme = nil;
pop_sheet_theme = nil;

function item_description(item)
    if item == nil then return ''; end

    -- Ashita's IItem::Description field is `const char* Description[3]`
    -- (0 default, 1 Japanese, 2 English). In LuaJIT this is cdata, not a
    -- normal Lua table/string, so tostring(item.Description) only produces
    -- a cdata pointer description instead of the item's actual help text.
    local ok_desc, desc = pcall(function() return item.Description; end);
    if not ok_desc or desc == nil then return ''; end

    local function read_description(index)
        local ok, value = pcall(function()
            local ptr = desc[index];
            if ptr == nil then return ''; end
            return ffi.string(ptr);
        end);

        if ok and type(value) == 'string' and value ~= '' then
            return value;
        end
        return '';
    end

    -- Horizon/Ashita exposes the readable English equipment help text in
    -- Description[1]. Description[2] is encoded/garbled on this client.
    local result = read_description(1);
    if result == '' then result = read_description(2); end
    if result == '' then result = read_description(0); end

    -- Resource strings can contain control bytes / line breaks. Convert them
    -- into spaces so stat patterns can match reliably across wrapped lines.
    result = result:gsub('[%c]', ' ');
    result = result:gsub('%s+', ' ');

    -- Horizon resource descriptions frequently wrap multi-word stat names
    -- in quotes, for example: "Store TP"+5 "Subtle Blow"+5.
    -- Strip straight / smart quotes so the parser sees the same canonical
    -- stat text regardless of whether a particular item uses quotation marks.
    result = result:gsub('[\"\'`]', '');
    result = result:gsub('“', ''):gsub('”', ''):gsub('‘', ''):gsub('’', '');

    return result;
end

-- Description markers after which an item's text no longer describes the
-- wearer's own always-on stats (pet stats, latent effects, set bonuses...).
NON_PLAYER_MARKERS = {
    'pet:', 'avatar:', 'automaton:', 'wyvern:', 'luopan:',
    'latent effect', 'set:', 'set bonus', 'enchantment:', 'additional effect:',
    'dispense:', 'unity ranking',
};

function player_stat_text(description)
    local lower = tostring(description or ''):lower();
    local cut_at = nil;
    for _, marker in ipairs(NON_PLAYER_MARKERS) do
        local found = lower:find(marker, 1, true);
        if found and (cut_at == nil or found < cut_at) then
            cut_at = found;
        end
    end
    if cut_at then
        return description:sub(1, cut_at - 1);
    end
    return description;
end

-- Equipped item ids as one string; changes whenever gear changes.
function equipped_signature()
    local inv = get_inventory();
    if inv == nil then return ''; end

    local ids = {};
    for slot = 0, 15 do
        local id = 0;
        local eitem = safe_call(inv, 'GetEquippedItem', slot);
        if eitem ~= nil and tonumber(eitem.Index) ~= nil and tonumber(eitem.Index) ~= 0 then
            local idx = tonumber(eitem.Index);
            local bag = math.floor(bit.band(idx, 0xFF00) / 0x0100);
            local pos = idx % 0x0100;
            local iitem = safe_call(inv, 'GetContainerItem', bag, pos);
            id = iitem and tonumber(iitem.Id) or 0;
        end
        ids[#ids + 1] = tostring(id);
    end
    return table.concat(ids, ',');
end

function equipped_item_text()
    local inv = get_inventory();
    local rm = AshitaCore:GetResourceManager();
    if inv == nil or rm == nil then return ''; end

    local pieces = {};
    for slot = 0, 15 do
        local eitem = safe_call(inv, 'GetEquippedItem', slot);
        if eitem ~= nil and tonumber(eitem.Index) ~= nil and tonumber(eitem.Index) ~= 0 then
            local idx = tonumber(eitem.Index);
            local bag = math.floor(bit.band(idx, 0xFF00) / 0x0100);
            local pos = idx % 0x0100;
            local iitem = safe_call(inv, 'GetContainerItem', bag, pos);
            local id = iitem and tonumber(iitem.Id) or nil;
            if id ~= nil and id > 0 and id ~= 65535 then
                local resource = rm:GetItemById(id);
                local d = player_stat_text(item_description(resource));
                if d ~= '' then pieces[#pieces + 1] = d; end
            end
        end
    end
    return table.concat(pieces, ' | ');
end

function consume_patterns(text, patterns)
    text = tostring(text or ''):lower();
    text = text:gsub('[\"\'`]', '');
    text = text:gsub('“', ''):gsub('”', ''):gsub('‘', ''):gsub('’', '');
    local total = 0;

    for _, pattern in ipairs(patterns) do
        text = text:gsub(pattern, function(sign, number)
            local value = tonumber(number) or 0;
            if sign == '-' then value = -value; end
            total = total + value;

            -- Preserve token separation after removing the matched stat.
            return ' ';
        end);
    end

    return total, text;
end

function sum_patterns(text, patterns)
    local total = 0;
    total = select(1, consume_patterns(text, patterns));
    return total;
end

function derive_gear_stats()
    local source = equipped_item_text():lower();
    local out = {};

    -- Consume the specific ranged/magic forms first so generic "Accuracy"
    -- and "Attack" do not also count the same text a second time.
    out.ranged_accuracy, source = consume_patterns(source, {
        'ranged%s+accuracy%s*([%+%-])(%d+)',
        'rng%.?%s*acc%.?%s*([%+%-])(%d+)',
        'r%.?acc%.?%s*([%+%-])(%d+)',
    });

    out.ranged_attack, source = consume_patterns(source, {
        'ranged%s+attack%s*([%+%-])(%d+)',
        'rng%.?%s*atk%.?%s*([%+%-])(%d+)',
        'r%.?atk%.?%s*([%+%-])(%d+)',
    });

    out.magic_accuracy, source = consume_patterns(source, {
        'magic%s+accuracy%s*([%+%-])(%d+)',
        'm%.?%s*acc%.?%s*([%+%-])(%d+)',
    });

    out.magic_attack, source = consume_patterns(source, {
        'magic%s+atk%.?%s*bonus%s*([%+%-])(%d+)',
        'magic%s+attack%s+bonus%s*([%+%-])(%d+)',
        'mab%s*([%+%-])(%d+)',
    });

    out.haste, source = consume_patterns(source, {
        'haste%s*([%+%-])(%d+)%%',
    });

    out.accuracy, source = consume_patterns(source, {
        'accuracy%s*([%+%-])(%d+)',
        'acc%.?%s*([%+%-])(%d+)',
    });

    out.attack, source = consume_patterns(source, {
        'attack%s*([%+%-])(%d+)',
        'atk%.?%s*([%+%-])(%d+)',
    });

    out.store_tp, source = consume_patterns(source, {
        'store%s+tp%s*([%+%-])(%d+)',
        'stp%s*([%+%-])(%d+)',
    });

    out.subtle_blow, source = consume_patterns(source, {
        'subtle%s+blow%s*([%+%-])(%d+)',
        's%.?blow%s*([%+%-])(%d+)',
    });

    out.double_attack, source = consume_patterns(source, {
        'double%s+attack%s*([%+%-])(%d+)%%',
    });

    out.triple_attack, source = consume_patterns(source, {
        'triple%s+attack%s*([%+%-])(%d+)%%',
    });

    out.fast_cast, source = consume_patterns(source, {
        'fast%s+cast%s*([%+%-])(%d+)%%',
    });

    out.spell_interrupt, source = consume_patterns(source, {
        'spell%s+interruption%s+rate%s+down%s*([%+%-])(%d+)%%',
        'spell%s+interrupt%s+rate%s+down%s*([%+%-])(%d+)%%',
    });

    out.enmity, source = consume_patterns(source, {
        'enmity%s*([%+%-])(%d+)',
    });

    out.magic_evasion, source = consume_patterns(source, {
        'magic%s+evasion%s*([%+%-])(%d+)',
        'm%.?%s*eva%.?%s*([%+%-])(%d+)',
    });

    out.evasion, source = consume_patterns(source, {
        'evasion%s*([%+%-])(%d+)',
        'eva%.?%s*([%+%-])(%d+)',
    });

    out.regen, source = consume_patterns(source, {
        'regen%s*([%+%-])(%d+)',
    });

    out.refresh, source = consume_patterns(source, {
        'refresh%s*([%+%-])(%d+)',
    });

    out.counter, source = consume_patterns(source, {
        'counter%s*([%+%-])(%d+)%%',
    });

    out.cure_potency, source = consume_patterns(source, {
        'cure%s+potency%s*([%+%-])(%d+)%%',
    });

    out.movement, source = consume_patterns(source, {
        'movement%s+speed%s*([%+%-])(%d+)%%',
        'movement%s+speed%s*([%+%-])(%d+)',
    });

    return out;
end

-- Gear stats only change when gear changes; re-parse at most twice a second
-- and only when the equipped item ids differ.
function cached_gear_stats()
    local now = os.clock();
    if state.gear_stats ~= nil and (now - state.gear_checked) < 0.5 then
        return state.gear_stats;
    end
    state.gear_checked = now;

    local signature = equipped_signature();
    if state.gear_stats == nil or signature ~= state.gear_signature then
        state.gear_stats = derive_gear_stats();
        state.gear_signature = signature;
    end
    return state.gear_stats;
end

-- Active haste-related effects (names from the client's buff table).
HASTE_EFFECT_IDS = {
    [33] = true,   -- Haste
    [214] = true,  -- March
    [353] = true,  -- Hasso
    [64] = true,   -- Last Resort
    [228] = true,  -- Embrava
    [370] = true,  -- Haste Samba
    [13] = true,   -- Slow (shown as a penalty)
};

function buff_name(id)
    local rm = AshitaCore:GetResourceManager();
    if rm == nil then return nil; end
    local ok, name = pcall(function() return rm:GetString('buffs.names', id); end);
    if ok and name ~= nil and tostring(name) ~= '' then
        return tostring(name);
    end
    return nil;
end

-- Reads the player's 32 buff slots. GetBuffs() can come back as a plain Lua
-- table or as a userdata array depending on the Ashita build, and 1.1.0 only
-- accepted a table (so Haste was never found). Both are read by index here.
function read_buff_ids(player)
    local ids = {};
    local buffs = safe_call(player, 'GetBuffs');
    if buffs == nil then
        return ids;
    end

    local function index_buffs(i)
        local ok, value = pcall(function() return buffs[i]; end);
        if ok then return tonumber(value); end
        return nil;
    end

    -- Slots are 1..32 on current builds; 0 is checked too for 0-based arrays.
    for i = 0, 32 do
        local id = index_buffs(i);
        if id ~= nil and id > 0 and id ~= 255 then
            ids[#ids + 1] = id;
        end
    end

    return ids;
end

function active_haste_effects(player)
    local list = {};
    local seen = {};
    for _, id in ipairs(read_buff_ids(player)) do
        if HASTE_EFFECT_IDS[id] then
            local name = buff_name(id) or ('Effect #' .. tostring(id));
            local count_key = name:lower();
            seen[count_key] = (seen[count_key] or 0) + 1;
            if seen[count_key] == 1 then
                list[#list + 1] = { id = id, name = name };
            end
        end
    end

    for _, entry in ipairs(list) do
        local count = seen[entry.name:lower()] or 1;
        if count > 1 then
            entry.name = ('%s x%d'):fmt(entry.name, count);
        end
    end

    return list;
end

function skill_value(player, index)
    local entry = safe_call(player, 'GetCombatSkill', index);
    if entry == nil then return 0; end
    return tonumber(safe_call(entry, 'GetSkill')) or 0;
end

function craft_value(player, index)
    local entry = safe_call(player, 'GetCraftSkill', index);
    if entry == nil then return 0, false; end
    local v = tonumber(safe_call(entry, 'GetSkill')) or 0;
    local capped = safe_call(entry, 'IsCapped') == true;
    return v, capped;
end

function format_metric(value, cap, suffix)
    suffix = suffix or '';
    if value == nil then
        if cap ~= nil then
            return string.format('-- / %s%s', tostring(cap), suffix);
        end
        return '--';
    end

    local function fmt(v)
        local n = tonumber(v);
        if n == nil then return tostring(v); end
        if math.abs(n - math.floor(n)) < 0.001 then
            return tostring(math.floor(n));
        end
        return string.format('%.2f', n):gsub('0+$', ''):gsub('%.$', '');
    end

    if cap ~= nil then
        return string.format('%s%s / %s%s', fmt(value), suffix, fmt(cap), suffix);
    end
    return fmt(value) .. suffix;
end

function draw_metric(label, value, cap, suffix, derived, card_width)
    local label_text = derived and (label .. ' *') or label;
    local row_start_x = imgui.GetCursorPosX();

    imgui.TextColored(state.muted_color, label_text);

    local display = format_metric(value, cap, suffix);
    local tw = select(1, imgui.CalcTextSize(display));
    tw = tonumber(tw) or 0;

    -- Keep the value inside the child window. 1.0.4 used the remaining
    -- content width after drawing the label, then added that entire amount
    -- to the current cursor position; this pushed the value beyond the
    -- right edge and ImGui clipped it.
    imgui.SameLine();

    local right_padding = 10;
    local value_x = math.max(
        imgui.GetCursorPosX(),
        (tonumber(card_width) or 250) - tw - right_padding
    );
    imgui.SetCursorPosX(value_x);

    local color = { 0.90, 0.93, 0.96, 1.00 };
    if cap ~= nil and value ~= nil then
        local n = tonumber(value) or 0;
        local c = tonumber(cap) or 0;
        if c > 0 and n >= c then
            color = state.warn_color;
        elseif n > 0 then
            color = state.good_color;
        end
    elseif value ~= nil and tonumber(value) ~= nil and tonumber(value) > 0 then
        color = state.good_color;
    end

    imgui.TextColored(color, display);
end

function card_background(width, height)
    local x, y = imgui.GetCursorScreenPos();
    local dl = imgui.GetWindowDrawList();
    if dl and x and y then
        dl:AddRectFilled({ x, y }, { x + width, y + height }, imgui.GetColorU32({ 1.0, 1.0, 1.0, 0.035 }), 5.0);
        dl:AddRect({ x, y }, { x + width, y + height }, imgui.GetColorU32({ UI_BORDER[1], UI_BORDER[2], UI_BORDER[3], 0.55 }), 5.0);
    end
end

function draw_card_title(title)
    imgui.TextColored(UI_ACCENT_TEXT, title);
    imgui.PushStyleColor(ImGuiCol_Separator, ui_accent(0.30));
    imgui.Separator();
    imgui.PopStyleColor(1);
end

function draw_advanced_card(id, title, width, height, rows)
    card_background(width, height);
    imgui.BeginChild(id, { width, height }, 0);
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 4);
    draw_card_title(title);

    for _, row in ipairs(rows) do
        draw_metric(row[1], row[2], row[3], row[4], row[5], width - 4);
    end

    imgui.EndChild();
end
