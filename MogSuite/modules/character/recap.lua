--[[
    MogSuite - modules/character/recap.lua (1.5.0)

    Death Recap: the last actions done to you (hits, misses, shadows, heals,
    status effects), kept from the game's action packets (0x028). When you
    die the list is frozen and (optionally) the Death Recap window opens
    with the killing blow at the top. The Recap button in the Character
    window opens it any time (the live list until you die).

    Only actions that FINISHED are recorded (the game's action result
    packet), never an enemy starting a move (HorizonXI rule).
]]

-- ============================================================================
-- Settings
-- ============================================================================

function ensure_recap_config()
    if config.recap == nil then config.recap = T{}; end
    local r = config.recap;
    if r.count == nil then r.count = 10; end
    if r.popup == nil then r.popup = true; end
    if r.heals == nil then r.heals = true; end
    if r.misses == nil then r.misses = true; end
    if r.status == nil then r.status = true; end
    if r.show_hp == nil then r.show_hp = true; end
    if r.window == nil then r.window = T{ x = -1, y = -1, w = 460, h = 360 }; end
end
ensure_recap_config();

recap = {
    events = {},        -- newest last, up to 50
    frozen = nil,       -- list at your death (newest last)
    died_at = nil,
    open = { false },
    placed = false,
    last_hp = nil,
    names = {},         -- server id -> name
};

-- ============================================================================
-- Action packet (0x028)
-- ============================================================================

local function unpack_bits(data_raw, pos, n)
    return ashita.bits.unpack_be(data_raw, 0, pos, n);
end

function parse_action(e)
    local raw = e.data_raw;
    if raw == nil then return nil; end
    local pos = 40;
    local function b(n) local v = unpack_bits(raw, pos, n); pos = pos + n; return v; end
    local a = {};
    a.actor = b(32);
    local ntargets = b(6);
    b(4);
    a.cat = b(4);
    a.param = b(16);
    b(16);
    a.recast = b(32);
    a.targets = {};
    for _ = 1, math.min(ntargets, 64) do
        local t = { id = b(32), actions = {} };
        local nact = b(4);
        for _ = 1, nact do
            local act = {};
            act.reaction = b(5);
            act.animation = b(12);
            act.effect = b(7);
            act.knockback = b(3);
            act.param = b(17);
            act.message = b(10);
            act.flags = b(31);
            if b(1) == 1 then act.add = { anim = b(10), param = b(17), message = b(10) }; end
            if b(1) == 1 then act.spike = { anim = b(10), param = b(14), message = b(10) }; end
            t.actions[#t.actions + 1] = act;
        end
        a.targets[#a.targets + 1] = t;
    end
    return a;
end

-- ============================================================================
-- Names
-- ============================================================================

function name_of_server_id(sid)
    sid = tonumber(sid) or 0;
    if sid == 0 then return '?'; end
    local cached = recap.names[sid];
    if cached ~= nil then return cached; end
    local name = nil;
    pcall(function()
        local em = AshitaCore:GetMemoryManager():GetEntity();
        -- Monsters and NPCs: index = low 12 bits of the server id.
        local idx = sid % 0x1000;
        if (tonumber(em:GetServerId(idx)) or 0) == sid then name = em:GetName(idx); end
        if name == nil or name == '' then
            for i = 0, 0x8FF do
                if (tonumber(em:GetServerId(i)) or 0) == sid then name = em:GetName(i); break; end
            end
        end
    end);
    name = (type(name) == 'string' and name ~= '') and name or ('#' .. tostring(sid % 0x1000));
    recap.names[sid] = name;
    return name;
end

local function res_name(res)
    if res == nil then return nil; end
    local n = resource_name(res);
    if n ~= nil and n ~= '' then return n; end
    return nil;
end

local function string_res(table_name, id)
    local s = nil;
    pcall(function() s = AshitaCore:GetResourceManager():GetString(table_name, id); end);
    if type(s) == 'string' and s ~= '' then return s; end
    return nil;
end

-- What was used: "Attack", a weapon skill, a spell, a monster move...
function action_label(cat, param)
    local rm = AshitaCore:GetResourceManager();
    if cat == 1 then return 'Attack'; end
    if cat == 2 then return 'Ranged attack'; end
    if cat == 4 then
        local n = nil;
        pcall(function() n = res_name(rm:GetSpellById(param)); end);
        return n or ('Spell ' .. tostring(param));
    end
    if cat == 5 then
        local n = nil;
        pcall(function() n = res_name(rm:GetItemById(param)); end);
        return n or 'Item';
    end
    if cat == 3 or cat == 11 then
        local n = nil;
        if cat == 3 and param < 256 then pcall(function() n = res_name(rm:GetAbilityById(param)); end); end
        n = n or string_res('monsters.abilities', param) or string_res('monsters.abilities', param - 256);
        if n == nil then pcall(function() n = res_name(rm:GetAbilityById(param)); end); end
        return n or ('Move ' .. tostring(param));
    end
    if cat == 6 or cat == 14 or cat == 15 then
        local n = nil;
        pcall(function() n = res_name(rm:GetAbilityById(param + 512)); end);
        return n or 'Ability';
    end
    if cat == 13 then return 'Pet move'; end
    return 'Action';
end

-- How it went: kind = 'dmg' | 'heal' | 'miss' | 'shadow' | 'status' | 'other'
MSG_DMG = { [1] = true, [2] = true, [67] = true, [77] = true, [110] = true, [157] = true, [185] = true, [196] = true,
    [197] = true, [227] = true, [252] = true, [264] = true, [265] = true, [274] = true, [317] = true, [352] = true,
    [353] = true, [379] = true, [522] = true, [576] = true, [577] = true, [648] = true, [650] = true, [747] = true, [748] = true };
MSG_MISS = { [15] = true, [63] = true, [85] = true, [106] = true, [158] = true, [188] = true, [189] = true, [245] = true,
    [282] = true, [284] = true, [324] = true, [354] = true, [355] = true, [592] = true, [653] = true, [654] = true, [656] = true };
MSG_SHADOW = { [14] = true, [31] = true, [535] = true };
MSG_HEAL = { [7] = true, [24] = true, [102] = true, [238] = true, [263] = true, [306] = true, [318] = true, [367] = true,
    [373] = true, [539] = true, [587] = true, [651] = true };
MSG_STATUS = { [82] = true, [127] = true, [141] = true, [160] = true, [164] = true, [166] = true, [186] = true, [194] = true,
    [203] = true, [205] = true, [230] = true, [236] = true, [237] = true, [242] = true, [243] = true, [266] = true,
    [267] = true, [268] = true, [269] = true, [270] = true, [271] = true, [272] = true, [277] = true, [278] = true,
    [279] = true, [280] = true, [319] = true, [320] = true, [374] = true, [375] = true, [412] = true, [645] = true, [754] = true, [755] = true };

function result_of(act)
    local m = act.message;
    if MSG_SHADOW[m] then return 'shadow', act.param; end
    if MSG_MISS[m] then return 'miss', 0; end
    if MSG_HEAL[m] then return 'heal', act.param; end
    if MSG_STATUS[m] then return 'status', act.param; end
    if MSG_DMG[m] then return 'dmg', act.param; end
    return 'other', act.param;
end

-- ============================================================================
-- Recording
-- ============================================================================

local function my_server_id()
    return tonumber(safe_call(get_party(), 'GetMemberServerId', 0)) or 0;
end

function recap_packet(e)
    local ok, a = pcall(parse_action, e);
    if not ok or a == nil then return; end
    -- Finished actions only (starts are categories 7, 8, 9, 12).
    if a.cat == 7 or a.cat == 8 or a.cat == 9 or a.cat == 12 or a.cat == 0 then return; end
    local me = my_server_id();
    if me == 0 then return; end
    local r = config.recap;
    for _, t in ipairs(a.targets) do
        if t.id == me then
            for _, act in ipairs(t.actions) do
                local kind, value = result_of(act);
                local keep = true;
                if kind == 'heal' and r.heals == false then keep = false; end
                if (kind == 'miss' or kind == 'shadow') and r.misses == false then keep = false; end
                if kind == 'status' and r.status == false then keep = false; end
                -- Your own actions on yourself are only kept when they heal you.
                if a.actor == me and kind ~= 'heal' then keep = false; end
                if keep then
                    local hp = tonumber(safe_call(get_party(), 'GetMemberHP', 0));
                    recap.events[#recap.events + 1] = {
                        t = os.clock(), when = os.time(), actor = name_of_server_id(a.actor), self = a.actor == me,
                        what = action_label(a.cat, a.param), cat = a.cat, kind = kind, value = value,
                        msg = act.message, hp = hp, crit = act.message == 67 or act.message == 353,
                    };
                    if #recap.events > 50 then table.remove(recap.events, 1); end
                end
            end
        end
    end
end

-- Called every frame: notices when your HP hits 0.
function recap_watch()
    local hp = tonumber(safe_call(get_party(), 'GetMemberHP', 0));
    if hp == nil then return; end
    if recap.last_hp ~= nil and recap.last_hp > 0 and hp == 0 then
        local n = math.max(1, tonumber(config.recap.count) or 10);
        local list = {};
        for i = math.max(1, #recap.events - n + 1), #recap.events do list[#list + 1] = recap.events[i]; end
        recap.frozen = list;
        recap.died_at = os.time();
        recap.died_clock = os.clock();
        if config.recap.popup ~= false then
            recap.open[1] = true;
            recap.placed = false;
        end
    end
    recap.last_hp = hp;
end

-- ============================================================================
-- Window
-- ============================================================================

RECAP_COLORS = {
    dmg = { 1.00, 0.45, 0.40, 1.0 }, heal = { 0.45, 0.90, 0.50, 1.0 }, miss = { 0.65, 0.66, 0.70, 1.0 },
    shadow = { 0.55, 0.75, 1.00, 1.0 }, status = { 0.80, 0.62, 1.00, 1.0 }, other = { 0.80, 0.80, 0.82, 1.0 },
};

function recap_result_text(ev)
    if ev.kind == 'dmg' then return ('%d damage%s'):fmt(ev.value or 0, ev.crit and ' (critical)' or ''); end
    if ev.kind == 'heal' then return ('+%d HP'):fmt(ev.value or 0); end
    if ev.kind == 'miss' then return 'missed / resisted'; end
    if ev.kind == 'shadow' then return 'absorbed by a shadow'; end
    if ev.kind == 'status' then
        local n = nil;
        pcall(function() n = AshitaCore:GetResourceManager():GetString('buffs.names', ev.value or 0); end);
        return (type(n) == 'string' and n ~= '') and n or 'status effect';
    end
    return ('message %d (%d)'):fmt(ev.msg or 0, ev.value or 0);
end

function draw_recap_window()
    if not recap.open[1] then return; end
    local w = config.recap.window;
    local scale = state.overall_scale[1];
    if not recap.placed then
        local x, y = tonumber(w.x) or -1, tonumber(w.y) or -1;
        if x < 0 or y < 0 then x, y = state.last_x + state.last_w + 8, state.last_y; end
        imgui.SetNextWindowPos({ x, y });
        imgui.SetNextWindowSize({ (tonumber(w.w) or 460) * scale, (tonumber(w.h) or 360) * scale });
        recap.placed = true;
    end
    push_sheet_theme(scale);
    if imgui.Begin('MogSuite  -  Death Recap##ms_recap', recap.open, ImGuiWindowFlags_NoNav) then
        imgui.PushFont(MS_FONT(), MS_FONT_SIZE() * scale);
        local list = recap.frozen;
        local title;
        if list ~= nil then
            title = ('You died %s'):fmt(format_ago(recap.died_at));
        else
            local n = math.max(1, tonumber(config.recap.count) or 10);
            list = {};
            for i = math.max(1, #recap.events - n + 1), #recap.events do list[#list + 1] = recap.events[i]; end
            title = ('Last %d actions done to you'):fmt(n);
        end
        imgui.TextColored(UI_ACCENT_TEXT, title);
        if recap.frozen ~= nil then
            imgui.SameLine();
            if imgui.SmallButton('Show live##ms_recap_live') then recap.frozen = nil; end
            tip('Show the actions happening now instead of the ones before your death.');
        end
        imgui.Separator();
        if #list == 0 then
            imgui.TextColored(state.muted_color, 'Nothing has been done to you yet.');
        end
        -- Newest first; the first damage line before a death is the killing blow.
        local killing = nil;
        if recap.frozen ~= nil then
            for i = #list, 1, -1 do
                if list[i].kind == 'dmg' then killing = i; break; end
            end
        end
        local base = (recap.frozen ~= nil) and recap.died_clock or os.clock();
        for i = #list, 1, -1 do
            local ev = list[i];
            local col = RECAP_COLORS[ev.kind] or RECAP_COLORS.other;
            local ago = (ev.t or base) - (base or ev.t);
            imgui.TextColored(state.muted_color, ('%5.1fs'):fmt(ago));
            imgui.SameLine(64 * scale);
            imgui.TextColored(ev.self and RECAP_COLORS.heal or UI_BRIGHT or UI_TEXT, ev.actor);
            imgui.SameLine(0, 6);
            imgui.TextColored(state.muted_color, ev.what);
            imgui.SameLine(0, 6);
            imgui.TextColored(col, recap_result_text(ev));
            if config.recap.show_hp ~= false and ev.hp ~= nil then
                imgui.SameLine(0, 8);
                imgui.TextColored(state.muted_color, ('(HP %d)'):fmt(ev.hp));
            end
            if i == killing then
                imgui.SameLine(0, 8);
                imgui.TextColored(state.bad_color, 'killing blow');
            end
        end
        imgui.PopFont();
        if not imgui.IsMouseDown(0) then
            local x, y = imgui.GetWindowPos();
            local ww, hh = imgui.GetWindowSize();
            x, y, ww, hh = tonumber(x), tonumber(y), tonumber(ww), tonumber(hh);
            if x and y and ww and hh and (math.floor(x) ~= w.x or math.floor(y) ~= w.y) then
                w.x, w.y = math.floor(x), math.floor(y);
                w.w, w.h = math.floor(ww / scale), math.floor(hh / scale);
                state.settings_dirty = true;
            end
        end
    end
    imgui.End();
    pop_sheet_theme();
end
