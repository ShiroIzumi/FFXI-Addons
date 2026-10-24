--[[
    MogSuite - modules/character/equip.lua (1.5.0)

    Changing gear from the Character window, and the Upgrade finder.

    Double-click a slot on the Overview's equipment strip (or right-click >
    Change) and a panel opens on the right side of the Character window,
    attached to it. It lists every item for that slot you carry in your
    Inventory or Mog Wardrobes (the only places the game equips from),
    split into:
      Usable        your job can wear it at your current level
      Usable later  your job can wear it, your level is too low (level sync
                    counts: synced to 55, a Lv 57 item waits here)
      Unusable      wrong job (or race)
    with the icon, name, bag, level and stats. Double-click an item (or
    right-click > Equip) and MogSuite sends the game's own /equip for it.
    Nothing is equipped any other way.

    Upgrade finder: every item is scored with a stat priority per job
    (Settings > Character > Upgrade finder, editable). Items that score
    better than what you wear get a green arrow, the best usable one a
    star. MS.upgrade_summary() gives the Inventory module its Upgrades
    view (best per slot, outleveled items, newly equippable).
]]

-- ============================================================================
-- Stats from an item's description
-- ============================================================================

-- { key, label, { patterns } }  checked in this order; matched text is
-- removed so "Ranged Accuracy" is not counted again as "Accuracy".
STAT_DEFS = {
    { 'DMG', 'Damage (weapons)', { 'dmg%s*:%s*()(%d+)' } },
    { 'DELAY', 'Delay', { 'delay%s*:%s*()(%d+)' } },
    { 'DEF', 'DEF', { 'def%s*:%s*()(%d+)', 'def%s*([%+%-])(%d+)' } },
    { 'HP', 'HP', { '[^%a]hp%s*([%+%-])(%d+)', '^hp%s*([%+%-])(%d+)' } },
    { 'MP', 'MP', { '[^%a]mp%s*([%+%-])(%d+)', '^mp%s*([%+%-])(%d+)' } },
    { 'RACC', 'Ranged Accuracy', { 'ranged%s+accuracy%s*([%+%-])(%d+)', 'rng%.?%s*acc%.?%s*([%+%-])(%d+)', 'r%.?acc%.?%s*([%+%-])(%d+)' } },
    { 'RATK', 'Ranged Attack', { 'ranged%s+attack%s*([%+%-])(%d+)', 'rng%.?%s*atk%.?%s*([%+%-])(%d+)', 'r%.?atk%.?%s*([%+%-])(%d+)' } },
    { 'MACC', 'Magic Accuracy', { 'magic%s+accuracy%s*([%+%-])(%d+)', 'm%.?%s*acc%.?%s*([%+%-])(%d+)' } },
    { 'MAB', 'Magic Attack Bonus', { 'magic%s+atk%.?%s*bonus%s*([%+%-])(%d+)', 'magic%s+attack%s+bonus%s*([%+%-])(%d+)', 'mag%.?%s*atk%.?%s*bns%.?%s*([%+%-])(%d+)', 'mab%s*([%+%-])(%d+)' } },
    { 'MDB', 'Magic Defense Bonus', { 'magic%s+def%.?%s*bonus%s*([%+%-])(%d+)', 'mag%.?%s*def%.?%s*bns%.?%s*([%+%-])(%d+)' } },
    { 'HASTE', 'Haste %', { 'haste%s*([%+%-])(%d+)%%' } },
    { 'ACC', 'Accuracy', { 'accuracy%s*([%+%-])(%d+)', 'acc%.?%s*([%+%-])(%d+)' } },
    { 'ATK', 'Attack', { 'attack%s*([%+%-])(%d+)', 'atk%.?%s*([%+%-])(%d+)' } },
    { 'STP', 'Store TP', { 'store%s+tp%s*([%+%-])(%d+)', 'stp%s*([%+%-])(%d+)' } },
    { 'SB', 'Subtle Blow', { 'subtle%s+blow%s*([%+%-])(%d+)' } },
    { 'DA', 'Double Attack %', { 'double%s+attack%s*([%+%-])(%d+)%%' } },
    { 'TA', 'Triple Attack %', { 'triple%s+attack%s*([%+%-])(%d+)%%' } },
    { 'CRIT', 'Critical hit rate %', { 'critical%s+hit%s+rate%s*([%+%-])(%d+)%%' } },
    { 'FC', 'Fast Cast %', { 'fast%s+cast%s*([%+%-])(%d+)%%' } },
    { 'CONSERVE', 'Conserve MP', { 'conserve%s+mp%s*([%+%-])(%d+)' } },
    { 'CURE', 'Cure potency %', { 'cure%s+potency%s*([%+%-])(%d+)%%' } },
    { 'ENMITY', 'Enmity', { 'enmity%s*([%+%-])(%d+)' } },
    { 'MEVA', 'Magic Evasion', { 'magic%s+evasion%s*([%+%-])(%d+)' } },
    { 'EVA', 'Evasion', { 'evasion%s*([%+%-])(%d+)', 'eva%.?%s*([%+%-])(%d+)' } },
    { 'REGEN', 'Regen', { 'regen%s*([%+%-])(%d+)' } },
    { 'REFRESH', 'Refresh', { 'refresh%s*([%+%-])(%d+)' } },
    { 'STR', 'STR', { 'str%s*([%+%-])(%d+)' } },
    { 'DEX', 'DEX', { 'dex%s*([%+%-])(%d+)' } },
    { 'VIT', 'VIT', { 'vit%s*([%+%-])(%d+)' } },
    { 'AGI', 'AGI', { 'agi%s*([%+%-])(%d+)' } },
    { 'INT', 'INT', { 'int%s*([%+%-])(%d+)' } },
    { 'MND', 'MND', { 'mnd%s*([%+%-])(%d+)' } },
    { 'CHR', 'CHR', { 'chr%s*([%+%-])(%d+)' } },
};

-- What each stat is worth per point, per job (Settings can change them).
-- DMG counts as damage per 240 delay, so faster weapons are judged fairly.
local MELEE = { DMG = 6, DEF = 0.2, HP = 0.15, STR = 2, DEX = 2.5, VIT = 0.6, AGI = 0.6, ACC = 2, ATK = 1.2, HASTE = 4, STP = 1, DA = 4, TA = 5, CRIT = 3, EVA = 0.4 };
local function w(base, extra)
    local t = {};
    for k, v in pairs(base) do t[k] = v; end
    for k, v in pairs(extra or {}) do t[k] = v; end
    return t;
end
DEFAULT_WEIGHTS = {
    WAR = w(MELEE, { ENMITY = 0.5 }),
    MNK = w(MELEE, { VIT = 1, SB = 1 }),
    WHM = { MP = 0.6, MND = 3, CURE = 3, CONSERVE = 1.5, FC = 2, REFRESH = 10, HP = 0.15, DEF = 0.2, VIT = 0.5, INT = 0.3, ENMITY = -1, MDB = 1.5 },
    BLM = { MP = 0.5, INT = 3, MAB = 3, MACC = 2, CONSERVE = 1, FC = 2, REFRESH = 10, HP = 0.1, DEF = 0.1, ENMITY = -1 },
    RDM = { MP = 0.5, MND = 2, INT = 2, MACC = 2.5, MAB = 1.5, FC = 2.5, REFRESH = 10, HP = 0.15, DEF = 0.2, ACC = 0.5, ENMITY = -0.5 },
    THF = w(MELEE, { DEX = 3, AGI = 2, ENMITY = -0.5 }),
    PLD = { HP = 0.6, DEF = 1, VIT = 2, ENMITY = 3, MND = 0.8, MP = 0.3, ACC = 0.6, ATK = 0.3, HASTE = 4, EVA = 0.8, CURE = 1, FC = 1 },
    DRK = w(MELEE, { STR = 2.5, INT = 0.3, ENMITY = -0.3 }),
    BST = w(MELEE, { CHR = 1.5 }),
    BRD = { CHR = 3, HP = 0.15, MP = 0.3, FC = 2, DEF = 0.2, VIT = 0.4, ENMITY = -0.5, HASTE = 2 },
    RNG = { RACC = 3, RATK = 2, AGI = 2.5, STR = 1, DEX = 0.5, STP = 1, HP = 0.1, DEF = 0.1, ENMITY = -1, DMG = 3 },
    SAM = w(MELEE, { STP = 2, ENMITY = -0.3 }),
    NIN = w(MELEE, { EVA = 2, ENMITY = 1, AGI = 1.2 }),
    DRG = w(MELEE, { ENMITY = -0.3 }),
    SMN = { MP = 1, REFRESH = 12, INT = 0.5, MND = 0.5, CHR = 0.3, HP = 0.1, DEF = 0.1, FC = 1, ENMITY = -0.5 },
    BLU = w(MELEE, { MP = 0.3, MND = 0.5, INT = 0.5, MACC = 1, MAB = 1 }),
    COR = w(MELEE, { RACC = 2, RATK = 1.5, AGI = 1.5 }),
    PUP = w(MELEE, { HP = 0.2 }),
    DNC = w(MELEE, { CHR = 1, DEX = 3 }),
    SCH = { MP = 0.5, INT = 2.5, MND = 2, MAB = 2, MACC = 2, FC = 2, REFRESH = 10, CURE = 1.5, HP = 0.1, DEF = 0.1, ENMITY = -1 },
};
JOB_SHORT_LIST = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG',
    'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH' };

function ensure_equip_config()
    if config.equip == nil then config.equip = T{}; end
    local e = config.equip;
    if e.weights == nil then e.weights = T{}; end
    if e.show_unusable == nil then e.show_unusable = true; end
    if e.show_later == nil then e.show_later = true; end
    if e.show_stats == nil then e.show_stats = true; end
    if e.width == nil then e.width = 380; end
end
ensure_equip_config();

function job_weights(job_short)
    local saved = config.equip.weights[job_short];
    if saved ~= nil and next(saved) ~= nil then return saved; end
    return DEFAULT_WEIGHTS[job_short] or MELEE;
end

stat_cache = {};   -- [item id] = { key = value }

function item_stats(id, desc)
    local c = stat_cache[id];
    if c ~= nil then return c; end
    local text = ' ' .. tostring(desc or ''):lower():gsub('[\"\'`]', '') .. ' ';
    -- Pet / latent / set text does not count for you.
    text = player_stat_text(text);
    local out = {};
    for _, def in ipairs(STAT_DEFS) do
        local total = 0;
        for _, pat in ipairs(def[3]) do
            text = text:gsub(pat, function(sign, number)
                local v = tonumber(number) or 0;
                if sign == '-' then v = -v; end
                total = total + v;
                return ' ';
            end);
        end
        if total ~= 0 then out[def[1]] = total; end
    end
    stat_cache[id] = out;
    return out;
end

function item_score(stats, weights)
    local s = 0;
    for k, v in pairs(stats) do
        if k == 'DMG' then
            local delay = math.max(1, tonumber(stats.DELAY) or 240);
            s = s + (tonumber(weights.DMG) or 0) * v * 240 / delay;
        elseif k ~= 'DELAY' then
            s = s + (tonumber(weights[k]) or 0) * v;
        end
    end
    return s;
end

-- ============================================================================
-- Your gear (Inventory + Mog Wardrobes)
-- ============================================================================

EQUIP_FROM_BAGS = { 0, 8, 10, 11, 12, 13, 14, 15, 16 };
EQUIP_BAG_NAMES = { [0] = 'Inventory', [8] = 'Wardrobe', [10] = 'Wardrobe 2', [11] = 'Wardrobe 3', [12] = 'Wardrobe 4',
    [13] = 'Wardrobe 5', [14] = 'Wardrobe 6', [15] = 'Wardrobe 7', [16] = 'Wardrobe 8' };
SLOT_COMMAND = { [0] = 'main', [1] = 'sub', [2] = 'range', [3] = 'ammo', [4] = 'head', [5] = 'body', [6] = 'hands',
    [7] = 'legs', [8] = 'feet', [9] = 'neck', [10] = 'waist', [11] = 'ear1', [12] = 'ear2', [13] = 'ring1', [14] = 'ring2', [15] = 'back' };
RACE_NAMES = { 'Hume (male)', 'Hume (female)', 'Elvaan (male)', 'Elvaan (female)', 'Tarutaru (male)', 'Tarutaru (female)', 'Mithra', 'Galka' };

function my_race()
    local r = nil;
    pcall(function()
        local idx = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
        r = tonumber(AshitaCore:GetMemoryManager():GetEntity():GetRace(idx));
    end);
    return r;
end

function equipped_ids()
    local out = {};
    for _, e in ipairs(cached_equipment() or {}) do
        if e.id ~= nil then out[e.slot] = e.id; end
    end
    return out;
end

-- Every wearable item you carry, once per (bag, slot).
function scan_wearables()
    local inv = get_inventory();
    local rm = AshitaCore:GetResourceManager();
    local list = {};
    if inv == nil or rm == nil then return list; end
    for _, bag in ipairs(EQUIP_FROM_BAGS) do
        local max = tonumber(safe_call(inv, 'GetContainerCountMax', bag)) or 80;
        if max > 0 then
            for i = 1, math.min(max, 80) do
                local it = safe_call(inv, 'GetContainerItem', bag, i);
                local id = it and tonumber(it.Id) or 0;
                if id > 0 and id ~= 65535 then
                    local res = nil;
                    pcall(function() res = rm:GetItemById(id); end);
                    local slots = res and tonumber(res.Slots) or 0;
                    if slots ~= 0 then
                        list[#list + 1] = {
                            id = id, bag = bag, index = i, res = res, slots = slots,
                            name = resource_name(res) or ('Item ' .. id),
                            level = tonumber(res.Level) or 0, jobs = tonumber(res.Jobs) or 0,
                            races = tonumber(res.Races) or 0, desc = item_description(res),
                            flags = it.Flags,
                        };
                    end
                end
            end
        end
    end
    return list;
end

local function jobs_list_text(mask)
    local out, n = {}, 0;
    for i, j in ipairs(JOB_SHORT_LIST) do
        if bit.band(mask, bit.lshift(1, i)) ~= 0 then out[#out + 1] = j; n = n + 1; end
    end
    if n >= 18 then return 'All jobs'; end
    return table.concat(out, ' / ');
end

local function races_text(mask)
    local out = {};
    for i, n in ipairs(RACE_NAMES) do
        if bit.band(mask, bit.lshift(1, i)) ~= 0 then out[#out + 1] = n; end
    end
    return table.concat(out, ', ');
end

-- 'usable' | 'later' | 'unusable', and why.
function classify(item, job, level, base_level, race)
    if item.jobs ~= 0 and bit.band(item.jobs, bit.lshift(1, job)) == 0 then
        return 'unusable', 'Only for ' .. jobs_list_text(item.jobs);
    end
    if race ~= nil and race > 0 and item.races ~= 0 and bit.band(item.races, 0x1FE) ~= 0x1FE
        and bit.band(item.races, bit.lshift(1, race)) == 0 then
        return 'unusable', 'Only for ' .. races_text(item.races);
    end
    if item.level > level then
        if base_level ~= nil and base_level > level and item.level <= base_level then
            return 'later', ('Available at Lv %d (you are synced to %d)'):fmt(item.level, level);
        end
        return 'later', ('Available at Lv %d'):fmt(item.level);
    end
    return 'usable', nil;
end

-- Everything for one slot, sorted and classified.
function gear_for_slot(slot)
    local player = get_player();
    local job = tonumber(safe_call(player, 'GetMainJob')) or 0;
    local level = tonumber(safe_call(player, 'GetMainJobLevel')) or 0;
    local base = tonumber(safe_call(player, 'GetJobLevel', job)) or level;
    local race = my_race();
    local weights = job_weights(JOB_SHORT_LIST[job] or 'WAR');
    local worn = equipped_ids()[slot];
    local worn_score = 0;
    local groups = { usable = {}, later = {}, unusable = {} };
    local seen = {};
    for _, it in ipairs(state.equip_scan or {}) do
        if bit.band(it.slots, bit.lshift(1, slot)) ~= 0 then
            local key = it.id .. ':' .. it.bag .. ':' .. it.index;
            if not seen[key] then
                seen[key] = true;
                local kind, why = classify(it, job, level, base, race);
                local entry = { item = it, kind = kind, why = why, stats = item_stats(it.id, it.desc) };
                entry.score = item_score(entry.stats, weights);
                if it.id == worn then entry.worn = true; worn_score = entry.score; end
                groups[kind][#groups[kind] + 1] = entry;
            end
        end
    end
    local best = nil;
    for _, e in ipairs(groups.usable) do
        e.better = (not e.worn) and e.score > worn_score + 0.01;
        if best == nil or e.score > best.score then best = e; end
    end
    if best ~= nil and best.score > 0 then best.best = true; end
    table.sort(groups.usable, function(a, b)
        if a.worn ~= b.worn then return a.worn == true; end
        if a.score ~= b.score then return a.score > b.score; end
        return a.item.name < b.item.name;
    end);
    table.sort(groups.later, function(a, b)
        if a.item.level ~= b.item.level then return a.item.level < b.item.level; end
        return a.item.name < b.item.name;
    end);
    table.sort(groups.unusable, function(a, b) return a.item.name < b.item.name; end);
    return groups, worn_score;
end

function refresh_equip_scan(force)
    local now = os.clock();
    if force or state.equip_scan == nil or now - (state.equip_scan_at or 0) > 1.0 then
        state.equip_scan = scan_wearables();
        state.equip_scan_at = now;
    end
end

function equip_item(slot, item)
    local cmd = ('/equip %s "%s"'):fmt(SLOT_COMMAND[slot] or 'main', item.name);
    AshitaCore:GetChatManager():QueueCommand(1, cmd);
end

-- ============================================================================
-- The side panel
-- ============================================================================

equip_panel = { slot = nil, open = { false } };

EQUIP_LAYOUT_LABEL = {};
for _, s in ipairs(EQUIP_LAYOUT or {}) do EQUIP_LAYOUT_LABEL[s[1]] = s[2]; end

function open_equip_panel(slot)
    equip_panel.slot = slot;
    equip_panel.open[1] = true;
    refresh_equip_scan(true);
end

local function stat_line(stats)
    local parts = {};
    for _, def in ipairs(STAT_DEFS) do
        local v = stats[def[1]];
        if v ~= nil then
            if def[1] == 'DMG' or def[1] == 'DELAY' or def[1] == 'DEF' then
                parts[#parts + 1] = ('%s:%d'):fmt(def[1] == 'DELAY' and 'Delay' or def[1], v);
            else
                parts[#parts + 1] = ('%s%s%d'):fmt(def[2]:gsub(' %%', ''), v >= 0 and '+' or '', v);
            end
        end
    end
    return table.concat(parts, '  ');
end

local function draw_entry(dl, e, slot, width, scale)
    local it = e.item;
    local lh = line_height();
    local icon = 28 * scale;
    local show_stats = config.equip.show_stats ~= false;
    local sl = show_stats and stat_line(e.stats) or '';
    local h = math.max(icon + 6 * scale, lh * (sl ~= '' and 2 or 1) + lh * ((e.why ~= nil) and 1 or 0) + 8 * scale);
    local x, y = screen_xy();
    imgui.InvisibleButton('##ms_eq_' .. it.bag .. '_' .. it.index, { math.max(1, width), h });
    local hovered = imgui.IsItemHovered();
    local can = e.kind == 'usable' and not e.worn;
    if hovered and imgui.IsMouseDoubleClicked(0) and can then equip_item(slot, it); end
    if hovered and imgui.IsMouseClicked(1) then
        equip_panel.ctx = e;
        imgui.OpenPopup('##ms_eq_ctx');
    end
    local bg = e.worn and { UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 0.16 } or (hovered and { 1, 1, 1, 0.06 } or { 1, 1, 1, 0.02 });
    dl:AddRectFilled({ x, y }, { x + width, y + h }, imgui.GetColorU32(bg), 4.0);
    local tex = item_icon(it.id);
    if tex ~= nil and tex.id ~= nil then
        imgui.SetCursorScreenPos({ x + 4 * scale, y + 3 * scale });
        imgui.Image(tex.id, { icon, icon });
    end
    local tx = x + icon + 10 * scale;
    local name_col = (e.kind == 'usable') and UI_TEXT or ((e.kind == 'later') and state.warn_color or with_alpha(state.muted_color, 0.8));
    text_at(tx, y + 4 * scale, name_col, it.name);
    local nx = tx + text_width(it.name) + 6 * scale;
    if e.worn then
        text_at(nx, y + 4 * scale, UI_ACCENT_TEXT, 'worn');
    elseif e.best then
        text_at(nx, y + 4 * scale, state.good_color, '* best');
    elseif e.better then
        text_at(nx, y + 4 * scale, state.good_color, '^ upgrade');
    end
    local right = ('Lv %d  %s'):fmt(it.level, EQUIP_BAG_NAMES[it.bag] or '');
    text_at(x + width - text_width(right) - 8 * scale, y + 4 * scale, state.muted_color, right);
    local ly = y + 4 * scale + lh;
    if sl ~= '' then
        text_at(tx, ly, with_alpha(state.muted_color, 0.95), sl);
        ly = ly + lh;
    end
    if e.why ~= nil then
        text_at(tx, ly, (e.kind == 'later') and state.warn_color or state.bad_color, e.why);
    end
    imgui.SetCursorScreenPos({ x, y + h + 2 * scale });
    imgui.Dummy({ 1, 0 });
    if hovered and not imgui.IsPopupOpen('##ms_eq_ctx') then
        imgui.BeginTooltip();
        imgui.TextColored(UI_ACCENT_TEXT, it.name);
        imgui.TextColored(state.muted_color, ('Lv %d  -  %s  -  %s'):fmt(it.level, jobs_list_text(it.jobs), EQUIP_BAG_NAMES[it.bag] or ''));
        if it.desc ~= '' then imgui.TextWrapped(it.desc); end
        if e.why ~= nil then imgui.TextColored((e.kind == 'later') and state.warn_color or state.bad_color, e.why); end
        imgui.TextColored(state.muted_color, ('Upgrade score %.0f (Settings > Character > Upgrade finder)'):fmt(e.score));
        if can then imgui.TextColored(UI_ACCENT_TEXT, 'Double-click to equip'); end
        imgui.EndTooltip();
    end
end

function draw_equip_panel()
    if not equip_panel.open[1] or equip_panel.slot == nil or not state.open[1] then return; end
    refresh_equip_scan(false);
    local slot = equip_panel.slot;
    local scale = state.overall_scale[1];
    local pw = (tonumber(config.equip.width) or 380) * scale;
    imgui.SetNextWindowPos({ state.last_x + state.last_w + 4, state.last_y });
    imgui.SetNextWindowSize({ pw, state.last_h });
    push_sheet_theme(scale);
    local flags = bit.bor(ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoMove,
        ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoSavedSettings or 0);
    if imgui.Begin('MogSuite  -  Gear##ms_equip_panel', equip_panel.open, flags) then
        imgui.PushFont(MS_FONT(), MS_FONT_SIZE() * scale);
        local label = (EQUIP_LAYOUT_LABEL and EQUIP_LAYOUT_LABEL[slot]) or (SLOT_COMMAND[slot] or '?');
        imgui.TextColored(UI_ACCENT_TEXT, label:upper());
        imgui.SameLine();
        imgui.TextColored(state.muted_color, 'double-click to equip');
        imgui.SameLine();
        imgui.SetCursorPosX(imgui.GetWindowWidth() - 30 * scale);
        if imgui.Button('X##ms_eq_close', { 22 * scale, 0 }) then equip_panel.open[1] = false; end
        tip('Close');
        local groups = gear_for_slot(slot);
        imgui.Separator();
        local width = avail_width();
        local dl = imgui.GetWindowDrawList();
        imgui.BeginChild('##ms_eq_list', { 0, 0 }, 0);
        local any = false;
        local sections = {
            { 'usable', 'USABLE', true },
            { 'later', 'USABLE LATER', config.equip.show_later ~= false },
            { 'unusable', 'UNUSABLE', config.equip.show_unusable ~= false },
        };
        for _, sec in ipairs(sections) do
            local list = groups[sec[1]];
            if sec[3] and #list > 0 then
                any = true;
                sheet_section(sec[2], tostring(#list));
                imgui.Spacing();
                -- Wardrobes with nothing for this slot are simply not listed.
                for _, e in ipairs(list) do draw_entry(dl, e, slot, avail_width(), scale); end
            end
        end
        if not any then imgui.TextColored(state.muted_color, 'Nothing for this slot in your Inventory or Wardrobes.'); end
        if imgui.BeginPopup('##ms_eq_ctx') then
            local e = equip_panel.ctx;
            if e ~= nil then
                imgui.TextColored(UI_ACCENT_TEXT, e.item.name);
                imgui.Separator();
                if e.kind == 'usable' and not e.worn then
                    if imgui.Selectable('Equip##ms_eq_do') then equip_item(slot, e.item); end
                else
                    imgui.TextDisabled(e.worn and 'Already equipped' or (e.why or "Can't equip"));
                end
            end
            imgui.EndPopup();
        end
        imgui.EndChild();
        imgui.PopFont();
    end
    imgui.End();
    pop_sheet_theme();
end

-- ============================================================================
-- Upgrade summary for the Inventory module (MS.upgrade_summary)
-- ============================================================================

SUMMARY_SLOTS = { 0, 1, 2, 3, 4, 9, 11, 12, 5, 6, 13, 14, 15, 10, 7, 8 };

function upgrade_summary()
    refresh_equip_scan(false);
    local player = get_player();
    local level = tonumber(safe_call(player, 'GetMainJobLevel')) or 0;
    local out = { level = level, slots = {} };
    for _, slot in ipairs(SUMMARY_SLOTS) do
        local groups, worn_score = gear_for_slot(slot);
        local s = { slot = slot, label = EQUIP_LAYOUT_LABEL and EQUIP_LAYOUT_LABEL[slot] or SLOT_COMMAND[slot], upgrades = {}, outleveled = {}, new = {} };
        local best = nil;
        for _, e in ipairs(groups.usable) do
            if e.best then best = e; end
            if e.better then s.upgrades[#s.upgrades + 1] = e; end
            if e.item.level == level and e.item.level > 1 then s.new[#s.new + 1] = e; end
        end
        if best ~= nil then
            for _, e in ipairs(groups.usable) do
                if not e.worn and not e.best and e.score < best.score and e.item.level < best.item.level then
                    s.outleveled[#s.outleveled + 1] = e;
                end
            end
        end
        s.best = best;
        out.slots[#out.slots + 1] = s;
    end
    return out;
end

-- Shared with the Inventory module (same Lua state).
MS.upgrade_summary = function() return upgrade_summary(); end
MS.open_equip_slot = function(slot)
    state.open[1] = true;
    state.apply_saved_geometry = true;
    state.tab[1] = 1;
    open_equip_panel(slot);
end
