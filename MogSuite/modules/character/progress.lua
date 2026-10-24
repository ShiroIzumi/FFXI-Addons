--[[
    MogSuite - modules/character/progress.lua (1.5.0)

    The Progress and Conquest tabs.

    Progress:
      - Nation, rank and rank points (from the game's player data).
      - Current missions: nation, Rise of the Zilart, Chains of Promathia
        (packet 0x056, port 0xFFFF) and Treasures of Aht Urhgan (port 0x0080),
        which the server sends when you log in / zone. Layout and mission
        numbers from LandSandBoat (src/map/packets/s2c/0x056_mission.*,
        scripts/globals/missions.lua).
      - Fame: the game never tells the client your fame; only the fame
        NPCs do. Each area shows who to talk to, and you set the level here.
      - Access: things your key items open (airships, Chocobo License...).

    Conquest (packet 0x05E, sent when you zone / open the conquest map;
    layout from LandSandBoat src/map/packets/s2c/0x05e_conquest.h):
      who controls each region, the days to the next tally, the current
      region's influence bars, and your conquest points.

    MogSuite only listens; it never asks the server for any of this.
]]

function ensure_progress_config()
    if config.progress == nil then config.progress = T{}; end
    local p = config.progress;
    if p.fame == nil then p.fame = T{}; end
    if p.missions == nil then p.missions = T{}; end
    if p.conquest == nil then p.conquest = T{}; end
end
ensure_progress_config();

NATIONS = { [0] = "San d'Oria", [1] = 'Bastok', [2] = 'Windurst' };
NATION_COLORS = {
    [1] = { 0.95, 0.40, 0.40, 1.0 },   -- San d'Oria
    [2] = { 0.45, 0.65, 1.00, 1.0 },   -- Bastok
    [3] = { 0.45, 0.90, 0.50, 1.0 },   -- Windurst
    [4] = { 0.80, 0.62, 0.40, 1.0 },   -- Beastmen
};
OWNER_NAMES = { [0] = 'Neutral', [1] = "San d'Oria", [2] = 'Bastok', [3] = 'Windurst', [4] = 'Beastmen' };

-- Mission names (LandSandBoat scripts/globals/missions.lua).
local function pretty(s)
    local small = { the = true, of = true, to = true, a = true, ['in'] = true, ['and'] = true, ['for'] = true, on = true, at = true };
    local out, first = {}, true;
    for w in s:lower():gmatch('[^_]+') do
        if first or not small[w] then w = w:sub(1, 1):upper() .. w:sub(2); end
        out[#out + 1] = w;
        first = false;
    end
    return table.concat(out, ' ');
end

local function list_of(names)
    local t = {};
    for i, n in ipairs(names) do t[i - 1] = pretty(n); end
    return t;
end

NATION_MISSIONS = {
    [0] = list_of({ 'SMASH_THE_ORCISH_SCOUTS', 'BAT_HUNT', 'SAVE_THE_CHILDREN', 'THE_RESCUE_DRILL', 'THE_DAVOI_REPORT',
        'JOURNEY_ABROAD', 'JOURNEY_TO_BASTOK', 'JOURNEY_TO_WINDURST', 'JOURNEY_TO_BASTOK', 'JOURNEY_TO_WINDURST',
        'INFILTRATE_DAVOI', 'THE_CRYSTAL_SPRING', 'APPOINTMENT_TO_JEUNO', 'MAGICITE', 'THE_RUINS_OF_FEI_YIN',
        'THE_SHADOW_LORD', 'LEAUTES_LAST_WISHES', 'RANPERRES_FINAL_REST', 'PRESTIGE_OF_THE_PAPSQUE', 'THE_SECRET_WEAPON',
        'COMING_OF_AGE', 'LIGHTBRINGER', 'BREAKING_BARRIERS', 'THE_HEIR_TO_THE_LIGHT' }),
    [1] = list_of({ 'THE_ZERUHN_REPORT', 'GEOLOGICAL_SURVEY', 'FETICHISM', 'THE_CRYSTAL_LINE', 'WADING_BEASTS',
        'THE_EMISSARY', 'THE_EMISSARY_SANDORIA', 'THE_EMISSARY_WINDURST', 'THE_EMISSARY_SANDORIA', 'THE_EMISSARY_WINDURST',
        'THE_FOUR_MUSKETEERS', 'TO_THE_FORSAKEN_MINES', 'JEUNO', 'MAGICITE', 'DARKNESS_RISING',
        'XARCABARD_LAND_OF_TRUTHS', 'RETURN_OF_THE_TALEKEEPER', 'THE_PIRATES_COVE', 'THE_FINAL_IMAGE', 'ON_MY_WAY',
        'THE_CHAINS_THAT_BIND_US', 'ENTER_THE_TALEKEEPER', 'THE_SALT_OF_THE_EARTH', 'WHERE_TWO_PATHS_CONVERGE' }),
    [2] = list_of({ 'THE_HORUTOTO_RUINS_EXPERIMENT', 'THE_HEART_OF_THE_MATTER', 'THE_PRICE_OF_PEACE', 'LOST_FOR_WORDS',
        'A_TESTING_TIME', 'THE_THREE_KINGDOMS', 'THE_THREE_KINGDOMS_SANDORIA', 'THE_THREE_KINGDOMS_BASTOK',
        'THE_THREE_KINGDOMS_SANDORIA', 'THE_THREE_KINGDOMS_BASTOK', 'TO_EACH_HIS_OWN_RIGHT', 'WRITTEN_IN_THE_STARS',
        'A_NEW_JOURNEY', 'MAGICITE', 'THE_FINAL_SEAL', 'THE_SHADOW_AWAITS', 'FULL_MOON_FOUNTAIN', 'SAINTLY_INVITATION',
        'THE_SIXTH_MINISTRY', 'AWAKENING_OF_THE_GODS', 'VAIN', 'THE_JESTER_WHOD_BE_KING', 'DOLL_OF_THE_DEAD', 'MOON_READING' }),
};
-- Mission number shown in the game (1-1 ... 9-2) for each id.
NATION_MISSION_NUM = { [0] = '1-1', '1-2', '1-3', '2-1', '2-2', '2-3', '2-3', '2-3', '2-3', '2-3', '3-1', '3-2', '3-3',
    '4-1', '5-1', '5-2', '6-1', '6-2', '7-1', '7-2', '8-1', '8-2', '9-1', '9-2' };

ZILART_MISSIONS = {
    { 0, 'The New Frontier' }, { 4, 'Welcome t\'Norg' }, { 6, "Kazham's Chieftainess" }, { 8, 'The Temple of Uggalepih' },
    { 10, 'Headstone Pilgrimage' }, { 12, 'Through the Quicksand Caves' }, { 14, 'The Chamber of Oracles' },
    { 16, "Return to Delkfutt's Tower" }, { 18, "Ro'Maeve" }, { 20, 'The Temple of Desolation' }, { 22, 'The Hall of the Gods' },
    { 23, 'The Mithra and the Crystal' }, { 24, 'The Gate of the Gods' }, { 26, 'Ark Angels' }, { 27, 'The Sealed Shrine' },
    { 28, 'The Celestial Nexus' }, { 30, 'Awakening' }, { 31, 'The Last Verse' },
};
COP_MISSIONS = {
    { 101, 'Ancient Flames Beckon' }, { 110, 'The Rites of Life' }, { 118, 'Below the Arks' }, { 128, 'The Mothercrystals' },
    { 138, 'An Invitation West' }, { 218, 'The Lost City' }, { 228, 'Distant Beliefs' }, { 238, 'An Eternal Melody' },
    { 248, 'Ancient Vows' }, { 257, 'A Transient Dream' }, { 258, 'The Call of the Wyrmking' }, { 318, 'A Vessel Without a Captain' },
    { 325, 'The Road Forks' }, { 335, 'Descendants of a Line Lost' }, { 341, 'Comedy of Errors' }, { 350, 'Tending Aged Wounds' },
    { 358, 'Darkness Named' }, { 368, 'Sheltering Doubt' }, { 418, 'The Savage' }, { 428, 'The Secrets of Worship' },
    { 438, 'Slanderous Utterings' }, { 448, 'The Enduring Tumult of War' }, { 518, 'Desires of Emptiness' }, { 530, 'Three Paths' },
    { 543, 'Partners Without Fame' }, { 552, 'Spiral' }, { 560, 'Where Messengers Gather' }, { 568, 'Flames for the Dead' },
    { 578, 'For Whom the Verse Is Sung' }, { 618, 'A Place to Return' }, { 628, 'More Questions Than Answers' },
    { 638, 'One to Be Feared' }, { 648, 'Chains and Bonds' }, { 718, 'Flames in the Darkness' }, { 728, 'Fire in the Eyes of Men' },
    { 738, 'Calm Before the Storm' }, { 748, "The Warrior's Path" }, { 758, 'Emptiness Bleeds' }, { 800, 'Garden of Antiquity' },
    { 818, 'A Fate Decided' }, { 828, 'When Angels Fall' }, { 840, 'Dawn' }, { 850, 'The Last Verse' },
};
TOAU_MISSIONS = list_of({ 'LAND_OF_SACRED_SERPENTS', 'IMMORTAL_SENTRIES', 'PRESIDENT_SALAHEEM', 'KNIGHT_OF_GOLD',
    'CONFESSIONS_OF_ROYALTY', 'EASTERLY_WINDS', 'WESTERLY_WINDS', 'A_MERCENARY_LIFE', 'UNDERSEA_SCOUTING', 'ASTRAL_WAVES',
    'IMPERIAL_SCHEMES', 'ROYAL_PUPPETEER', 'LOST_KINGDOM', 'THE_DOLPHIN_CREST', 'THE_BLACK_COFFIN', 'GHOSTS_OF_THE_PAST',
    'GUESTS_OF_THE_EMPIRE', 'PASSING_GLORY', 'SWEETS_FOR_THE_SOUL', 'TEAHOUSE_TUMULT', 'FINDERS_KEEPERS',
    'SHIELD_OF_DIPLOMACY', 'SOCIAL_GRACES', 'FOILED_AMBITION', 'PLAYING_THE_PART', 'SEAL_OF_THE_SERPENT',
    'MISPLACED_NOBILITY', 'BASTION_OF_KNOWLEDGE', 'PUPPET_IN_PERIL', 'PREVALENCE_OF_PIRATES', 'SHADES_OF_VENGEANCE',
    'IN_THE_BLOOD', 'SENTINELS_HONOR', 'TESTING_THE_WATERS', 'LEGACY_OF_THE_LOST', 'GAZE_OF_THE_SABOTEUR', 'PATH_OF_BLOOD',
    'STIRRINGS_OF_WAR', 'ALLIED_RUMBLINGS', 'UNRAVELING_REASON', 'LIGHT_OF_JUDGMENT', 'PATH_OF_DARKNESS', 'FANGS_OF_THE_LION',
    'NASHMEIRAS_PLEA', 'RAGNAROK', 'IMPERIAL_CORONATION', 'THE_EMPRESS_CROWNED', 'ETERNAL_MERCENARY' });

local function from_steps(list, id)
    if id == nil or id >= 65535 then return nil; end
    local best = nil;
    for _, e in ipairs(list) do
        if e[1] <= id then best = e; end
    end
    return best and best[2] or nil;
end

-- Fame areas and who tells you your fame (bg-wiki "Fame").
FAME_AREAS = {
    { key = 'sandoria', label = "San d'Oria", npc = 'Namonutice', where = 'Southern San d\'Oria (K-6), Lion Springs Tavern' },
    { key = 'bastok', label = 'Bastok', npc = 'Flaco', where = 'Port Bastok (E-6), in front of the Steaming Sheep' },
    { key = 'windurst', label = 'Windurst', npc = 'Zabirego-Hajigo', where = 'Windurst Waters (F-10), Timbre Timbers' },
    { key = 'jeuno', label = 'Jeuno', npc = 'Mendi', where = 'Lower Jeuno (H-8), across from the magic shop' },
    { key = 'selbina', label = 'Selbina / Rabao', npc = 'Waylea', where = 'Rabao (G-9)' },
    { key = 'norg', label = 'Norg', npc = 'Vaultimand', where = 'Norg (H-8)' },
};
FAME_LEVELS = { 'Not set', '1', '2', '3', '4', '5', '6', '7', '8', '9' };

-- Key items that open things (names as the game has them; any the game
-- doesn't know are skipped).
ACCESS_KEY_ITEMS = {
    { 'Airship Pass', 'Airships between the nations and Jeuno' },
    { 'Airship Pass for Kazham', 'Airship to Kazham' },
    { 'Chocobo License', 'Riding chocobos' },
    { 'Cosmo-Cleanse', 'Entering Limbus (Temenos / Apollyon)' },
    { 'Tenshodo Member\'s Card', 'Tenshodo (shop and Norg)' },
    { 'Prismatic Hourglass', 'Entering Dynamis' },
    { 'Vial of Shrouded Sand', 'Entering Dynamis' },
    { 'Shard of Apathy', 'The Garden of Ru\'Hmet (CoP)' },
    { 'Pso\'Xja Pass', 'Pso\'Xja gates' },
    { 'Imperial Army ID Tag', 'Assault' },
    { 'Assault Armband', 'Assault (party leader)' },
    { 'Runic Portal Use Permit', 'Runic Portals to Assault staging points' },
};

ki_ids = nil;   -- [lower name] = id
function key_item_id(name)
    if ki_ids == nil then
        ki_ids = {};
        local rm = AshitaCore:GetResourceManager();
        for id = 0, 3071 do
            local ok, n = pcall(function() return rm:GetString('keyitems.names', id); end);
            if ok and type(n) == 'string' and n ~= '' then
                local k = n:lower();
                if ki_ids[k] == nil then ki_ids[k] = id; end
            end
        end
    end
    return ki_ids[name:lower()];
end

function has_key_item(id)
    local ok, v = pcall(function() return get_player():HasKeyItem(id); end);
    return ok and v == true;
end

-- ============================================================================
-- Packets
-- ============================================================================

local function u32(data, o)
    local a, b, c, d = data:byte(o + 1, o + 4);
    return (a or 0) + (b or 0) * 256 + (c or 0) * 65536 + (d or 0) * 16777216;
end
local function u16(data, o)
    local a, b = data:byte(o + 1, o + 2);
    return (a or 0) + (b or 0) * 256;
end

function progress_packet(e)
    local data = e.data_modified or e.data;
    if data == nil then return; end
    if e.id == 0x056 then
        local port = u16(data, 0x24);
        local m = config.progress.missions;
        if port == 0xFFFF then
            m.nation = u32(data, 0x04);
            m.nation_cur = u32(data, 0x08);
            m.zilart = u32(data, 0x0C);
            m.cop = u32(data, 0x10);
            m.at = os.time();
            state.settings_dirty = true;
        elseif port == 0x0080 then
            m.toau = u32(data, 0x04 + 5 * 4);
            m.at = os.time();
            state.settings_dirty = true;
        end
    elseif e.id == 0x05E then
        local c = config.progress.conquest;
        local regions = T{};
        for r = 0, 18 do
            local base = 0x1A + r * 4;
            regions[r + 1] = T{ owner = data:byte(base + 4) or 0, rank = data:byte(base + 1) or 0 };
        end
        c.regions = regions;
        c.balance = data:byte(0x05) or 0;
        c.tally_days = data:byte(0x8C + 1) or 0;
        c.cur_bars = T{ data:byte(0x86 + 1) or 0, data:byte(0x87 + 1) or 0, data:byte(0x88 + 1) or 0, data:byte(0x94 + 1) or 0 };
        c.points = u32(data, 0x90);
        c.at = os.time();
        c.zone = tonumber(safe_call(get_party(), 'GetMemberZone', 0)) or 0;
        c.raw = data:sub(1, 0xA0):gsub('.', function(ch) return ('%02X'):format(ch:byte()); end);
        state.settings_dirty = true;
    end
end

-- ============================================================================
-- Progress tab
-- ============================================================================

local function row(label, value, col)
    imgui.TextColored(state.muted_color, label);
    imgui.SameLine(170 * state.overall_scale[1]);
    imgui.TextColored(col or UI_TEXT, value);
end

function draw_progress_tab(player)
    local scale = state.overall_scale[1];
    local nation = tonumber(safe_call(player, 'GetNation'));
    local rank = tonumber(safe_call(player, 'GetRank')) or tonumber(safe_call(player, 'GetNationRank'));
    local rank_pts = tonumber(safe_call(player, 'GetRankPoints'));

    sheet_section('NATION');
    imgui.Spacing();
    row('Nation', NATIONS[nation or -1] or '?', nation and NATION_COLORS[nation + 1] or nil);
    if rank ~= nil and rank > 0 then row('Rank', tostring(rank)); end
    if rank_pts ~= nil then row('Rank points', tostring(rank_pts)); end

    sheet_section('MISSIONS', 'current mission of each storyline');
    imgui.Spacing();
    local m = config.progress.missions;
    if m.at == nil then
        imgui.TextColored(state.muted_color, 'Zone once and MogSuite fills this in (the game sends it when you zone).');
    else
        local nm = tonumber(m.nation_cur) or 65535;
        local nlist = NATION_MISSIONS[tonumber(m.nation) or nation or 0] or {};
        if nm >= 65535 or nlist[nm] == nil then
            row(NATIONS[tonumber(m.nation) or 0] or 'Nation', 'No mission accepted');
        else
            row(NATIONS[tonumber(m.nation) or 0] or 'Nation', ('%s  %s'):fmt(NATION_MISSION_NUM[nm] or '?', nlist[nm]));
        end
        row('Rise of the Zilart', from_steps(ZILART_MISSIONS, tonumber(m.zilart)) or 'Not started');
        row('Chains of Promathia', from_steps(COP_MISSIONS, tonumber(m.cop)) or 'Not started');
        local t = tonumber(m.toau);
        row('Treasures of Aht Urhgan', (t ~= nil and t < 65535 and TOAU_MISSIONS[t]) and (('%d  %s'):fmt(t + 1, TOAU_MISSIONS[t])) or 'Not started / unknown');
        imgui.TextColored(with_alpha(state.muted_color, 0.7), 'Updated ' .. format_ago(m.at));
    end

    sheet_section('FAME', 'the game never tells MogSuite your fame');
    imgui.Spacing();
    imgui.PushTextWrapPos(0);
    imgui.TextColored(state.warn_color, 'Talk to the fame NPC of an area, then set the level they told you here.');
    imgui.PopTextWrapPos();
    for _, a in ipairs(FAME_AREAS) do
        local cur = config.progress.fame[a.key];
        imgui.TextColored(state.muted_color, a.label);
        imgui.SameLine(170 * scale);
        imgui.PushItemWidth(90 * scale);
        if imgui.BeginCombo('##ms_fame_' .. a.key, cur and ('Level ' .. tostring(cur)) or 'Not set') then
            for i, lv in ipairs(FAME_LEVELS) do
                local v = (i > 1) and (i - 1) or nil;
                if imgui.Selectable(lv .. '##ms_fl_' .. a.key .. i, cur == v) then
                    config.progress.fame[a.key] = v;
                    config.progress.fame[a.key .. '_at'] = os.time();
                    state.settings_dirty = true;
                end
            end
            imgui.EndCombo();
        end
        imgui.PopItemWidth();
        imgui.SameLine(0, 8);
        imgui.TextColored(UI_ACCENT_TEXT, 'Ask ' .. a.npc);
        tip(a.npc .. ': ' .. a.where .. (config.progress.fame[a.key .. '_at'] and ('\nSet ' .. format_ago(config.progress.fame[a.key .. '_at'])) or ''));
    end

    sheet_section('ACCESS', 'from your key items');
    imgui.Spacing();
    local shown = 0;
    for _, k in ipairs(ACCESS_KEY_ITEMS) do
        local id = key_item_id(k[1]);
        if id ~= nil then
            local have = has_key_item(id);
            if have or k[2] ~= nil then
                shown = shown + 1;
                imgui.TextColored(have and state.good_color or with_alpha(state.muted_color, 0.6), have and 'Yes' or ' - ');
                imgui.SameLine(40 * scale);
                imgui.TextColored(have and UI_TEXT or state.muted_color, k[1]);
                if k[2] ~= nil then
                    imgui.SameLine(0, 8);
                    imgui.TextColored(with_alpha(state.muted_color, 0.8), k[2]);
                end
            end
        end
    end
    if shown == 0 then imgui.TextColored(state.muted_color, 'Key items not read yet.'); end
end

-- ============================================================================
-- Conquest tab
-- ============================================================================

REGION_NAMES = { 'Ronfaure', 'Zulkheim', 'Norvallen', 'Gustaberg', 'Derfland', 'Sarutabaruta', 'Kolshushu', 'Aragoneu',
    'Fauregandi', 'Valdeaunia', 'Qufim', "Li'Telor", 'Kuzotz', 'Vollbow', 'Elshimo Lowlands', 'Elshimo Uplands',
    "Tu'Lia", 'Movalpolos', 'Tavnazian Archipelago' };

function draw_conquest_tab(player)
    local scale = state.overall_scale[1];
    local c = config.progress.conquest;
    local nation = tonumber(safe_call(player, 'GetNation'));

    sheet_section('CONQUEST');
    imgui.Spacing();
    if c.at == nil then
        imgui.PushTextWrapPos(0);
        imgui.TextColored(state.muted_color, 'Waiting for the conquest data. The game sends it when you zone (or open the region map). Zone once and this fills in.');
        imgui.PopTextWrapPos();
    else
        local days = tonumber(c.tally_days) or 0;
        row('Next tally', (days <= 0) and 'Today' or (('%d day%s'):fmt(days, days == 1 and '' or 's')), UI_ACCENT_TEXT);
        if nation ~= nil then row('Your nation', NATIONS[nation] or '?', NATION_COLORS[nation + 1]); end
        row('Your conquest points', fmt_thousands(c.points or 0));
        -- Points per nation from the Currencies list.
        local vals = config.currencies and config.currencies.values or {};
        for _, n in ipairs({ "San d'Oria", 'Bastok', 'Windurst' }) do
            local v = vals[('Conquest Points (%s)'):fmt(n)];
            if v ~= nil and tonumber(v) and tonumber(v) > 0 then row('  ' .. n .. ' CP', fmt_thousands(v)); end
        end

        -- Regions per owner.
        local count = { [0] = 0, 0, 0, 0, 0 };
        for _, r in ipairs(c.regions or {}) do count[r.owner] = (count[r.owner] or 0) + 1; end
        sheet_section('REGIONS', ('San d\'Oria %d  -  Bastok %d  -  Windurst %d  -  Beastmen %d'):fmt(count[1] or 0, count[2] or 0, count[3] or 0, count[4] or 0));
        imgui.Spacing();
        local mine = (nation ~= nil) and (nation + 1) or -1;
        local cols = (avail_width() > 420 * scale) and 2 or 1;
        local colw = avail_width() / cols;
        for i, r in ipairs(c.regions or {}) do
            local name = REGION_NAMES[i] or ('Region ' .. i);
            local col = (i - 1) % cols;
            if col > 0 then imgui.SameLine(colw * col); end
            local own = OWNER_NAMES[r.owner] or '?';
            imgui.TextColored(r.owner == mine and state.good_color or UI_TEXT, name);
            imgui.SameLine(colw * col + 150 * scale);
            imgui.TextColored(NATION_COLORS[r.owner] or state.muted_color, own);
        end
        imgui.Spacing();
        imgui.PushTextWrapPos(0);
        imgui.TextColored(with_alpha(state.muted_color, 0.8), 'Green = your nation holds it (outpost warps, region bonuses and better prices from that region\'s merchants there).');
        imgui.PopTextWrapPos();

        local bars = c.cur_bars or {};
        if (bars[1] or 0) + (bars[2] or 0) + (bars[3] or 0) + (bars[4] or 0) > 0 then
            sheet_section('THIS REGION', 'influence where you were when it was sent');
            imgui.Spacing();
            local labels = { "San d'Oria", 'Bastok', 'Windurst', 'Beastmen' };
            for k = 1, 4 do
                imgui.TextColored(NATION_COLORS[k], labels[k]);
                imgui.SameLine(110 * scale);
                draw_bar(math.max(60, avail_width() - 10), line_height() - 2, (bars[k] or 0) / 100, NATION_COLORS[k]);
            end
        end
        imgui.TextColored(with_alpha(state.muted_color, 0.7), 'Updated ' .. format_ago(c.at));
    end
end
