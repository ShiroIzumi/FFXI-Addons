require('common');
local core_mod = require('scl.core');
local events_mod = require('scl.events');
local resources_mod = require('scl.resources');
local line_is_about_me = core_mod.line_is_about_me;
local normalize_line = core_mod.normalize_line;
local safe_me = core_mod.safe_me;
local settings = core_mod.settings;
local state = core_mod.state;
local strip_control_codes = core_mod.strip_control_codes;
local add_event = events_mod.add_event;
local add_progression_event = events_mod.add_progression_event;
local source_suffix = events_mod.source_suffix;
local safe_entity_name = resources_mod.safe_entity_name;
local safe_player_server_id = resources_mod.safe_player_server_id;
local safe_status_name = resources_mod.safe_status_name;
local session = require('scl.session');
local debuglog = require('scl.debuglog');

-- True when the server id belongs to the player's party / alliance.
local function is_party_member(server_id)
    server_id = tonumber(server_id);
    if not server_id or server_id == 0 then return false end

    local found = false;
    pcall(function()
        local party = AshitaCore:GetMemoryManager():GetParty();
        for slot = 0, 17 do
            if party:GetMemberServerId(slot) == server_id then
                found = true;
                return;
            end
        end
    end);
    return found;
end

-- 0x029 messages SCL handles (anything else about the player goes to the
-- debug log when /scl debug is on).
local HANDLED_MESSAGE_IDS = {
    [6] = true, [8] = true, [9] = true, [20] = true, [38] = true, [53] = true,
    [97] = true, [105] = true, [206] = true, [251] = true, [253] = true,
    [371] = true, [372] = true, [565] = true, [582] = true, [718] = true,
    [735] = true, [809] = true, [810] = true,
};

-- ============================================================================
-- Progression / rewards
-- ============================================================================

local SKILL_NAMES = T{
    [1] = 'Hand-to-Hand',
    [2] = 'Dagger',
    [3] = 'Sword',
    [4] = 'Great Sword',
    [5] = 'Axe',
    [6] = 'Great Axe',
    [7] = 'Scythe',
    [8] = 'Polearm',
    [9] = 'Katana',
    [10] = 'Great Katana',
    [11] = 'Club',
    [12] = 'Staff',

    [25] = 'Archery',
    [26] = 'Marksmanship',
    [27] = 'Throwing',

    [28] = 'Guard',
    [29] = 'Evasion',
    [30] = 'Shield',
    [31] = 'Parry',

    [32] = 'Divine Magic',
    [33] = 'Healing Magic',
    [34] = 'Enhancing Magic',
    [35] = 'Enfeebling Magic',
    [36] = 'Elemental Magic',
    [37] = 'Dark Magic',
    [38] = 'Summoning Magic',
    [39] = 'Ninjutsu',
    [40] = 'Singing',
    [41] = 'Stringed Instrument',
    [42] = 'Wind Instrument',
    [43] = 'Blue Magic',
    [44] = 'Geomancy',
    [45] = 'Handbell',

    [48] = 'Fishing',
    [49] = 'Woodworking',
    [50] = 'Smithing',
    [51] = 'Goldsmithing',
    [52] = 'Clothcraft',
    [53] = 'Leathercraft',
    [54] = 'Bonecraft',
    [55] = 'Alchemy',
    [56] = 'Cooking',
};

local function skill_name_from_id(skill_id)
    skill_id = tonumber(skill_id);
    if not skill_id then
        return nil;
    end
    return SKILL_NAMES[skill_id] or ('Skill #' .. tostring(skill_id));
end

local function skill_id_from_name(skill_name)
    local normalized = tostring(skill_name or ''):lower():gsub('%s+magic$', '');
    for sid, known_name in pairs(SKILL_NAMES) do
        if known_name:lower():gsub('%s+magic$', '') == normalized then
            return sid;
        end
    end
    return nil;
end

-- EXP-type rewards (EXP / Limit / Capacity / Exemplar) have three possible
-- sources. The 0x02D packet is authoritative; chat text and the memory
-- watcher only fill in when no packet reported the reward.
local EXP_SOURCE_WINDOW = 2.0;

-- " (current/needed)" after an EXP gain; defined with the memory helpers below.
local exp_progress_suffix;

local function with_commas(value)
    local text = tostring(math.floor(tonumber(value) or 0));
    local formatted = text:reverse():gsub('(%d%d%d)', '%1,'):reverse();
    formatted = formatted:gsub('^,', '');
    return formatted;
end

local function report_packet_exp(label)
    state.exp_tracking.last_packet = os.clock();
    state.exp_tracking.pending = nil;
    add_progression_event('xp', label);
end

local function exp_message_label(message, amount, chain)
    local suffix = '';
    if chain and chain > 0 and chain < 100 then
        suffix = '  (Chain #' .. tostring(chain) .. ')';
    end

    if message == 8 or message == 105 or message == 253 then
        return '+' .. tostring(amount) .. ' EXP' .. exp_progress_suffix(amount, false) .. suffix;
    elseif message == 371 or message == 372 then
        return '+' .. tostring(amount) .. ' Limit Points' .. suffix;
    elseif message == 718 or message == 735 then
        return '+' .. tostring(amount) .. ' Capacity Points' .. suffix;
    elseif message == 809 or message == 810 then
        return '+' .. tostring(amount) .. ' Exemplar Points' .. suffix;
    end
    return nil;
end

local function parse_message_packet(e)
    if not e or not e.data then
        return nil;
    end

    local data = e.data;

    -- 0x029 is byte-aligned / little-endian:
    -- 0x04 actor, 0x08 target, 0x0C param1, 0x10 param2,
    -- 0x14 actor index, 0x16 target index, 0x18 message.
    local ok, parsed = pcall(function()
        return {
            actor = struct.unpack('I', data, 0x04 + 1),
            target = struct.unpack('I', data, 0x08 + 1),
            param1 = struct.unpack('I', data, 0x0C + 1),
            param2 = struct.unpack('I', data, 0x10 + 1),
            actor_index = struct.unpack('H', data, 0x14 + 1),
            target_index = struct.unpack('H', data, 0x16 + 1),
            message = struct.unpack('H', data, 0x18 + 1),
        };
    end);

    if not ok then
        return nil;
    end

    return parsed;
end

local function emit_message_packet(msg)
    if not msg then
        return;
    end

    local self_id = tonumber(safe_player_server_id());
    if not self_id then
        return;
    end

    local actor = tonumber(msg.actor);
    local target = tonumber(msg.target);
    local param1 = tonumber(msg.param1) or 0;
    local param2 = tonumber(msg.param2) or 0;
    local message = bit.band(tonumber(msg.message) or -1, 0x7FFF);
    local about_me = actor == self_id or target == self_id;

    -- Skill-ups. Message 38: Param1 = skill ID, Param2 = gain in tenths.
    -- Message 53: Param1 = skill ID, Param2 = new skill level.
    if message == 38 or message == 53 then
        if not about_me or param1 <= 0 then
            return;
        end

        local name = skill_name_from_id(param1);
        state.skillup_packet_at[param1] = os.clock();

        if message == 38 and param2 > 0 then
            add_event('incoming', 'xp', name .. ' +' .. string.format('%.1f', param2 / 10), 'skill_ups');
        elseif message == 53 then
            add_event('incoming', 'xp', name .. ' -> ' .. tostring(param2), 'skill_ups');
        end
        return;
    end

    -- Status effect wears off the player. Param1 is the status ID.
    if message == 206 then
        if target == self_id then
            local status_name = safe_status_name(param1) or ('Status #' .. tostring(param1));
            state.status_removed_at[status_name:lower()] = os.clock();
            add_event('incoming', 'ability', status_name .. ' removed', 'status_removed');
        end
        return;
    end

    -- "Protect is about to wear off." The game's own warning for the player.
    if message == 251 then
        if target == self_id then
            local status_name = safe_status_name(param1) or ('Status #' .. tostring(param1));
            add_event('incoming', 'ability', status_name .. ' wearing off', 'wear_warning');
        end
        return;
    end

    -- Defeats involving the player.
    if message == 6 or message == 97 then
        -- Session kill count: an enemy defeated by you or your party.
        if target ~= self_id and is_party_member(actor) and not is_party_member(target) then
            session.record_kill();
        end

        -- 6: actor defeats target. 97: target was defeated by actor.
        if actor == self_id and target ~= self_id then
            add_event('outgoing', 'ability', safe_entity_name(target) .. ' defeated', 'ko');
        elseif target == self_id then
            add_event('incoming', 'ability', 'You were defeated' .. source_suffix(safe_entity_name(actor)), 'ko');
        end
        return;
    end

    if message == 20 then
        if target == self_id then
            add_event('incoming', 'ability', 'You were defeated', 'ko');
        end
        return;
    end

    -- Character level up.
    if message == 9 then
        if actor == self_id and param1 > 0 then
            add_progression_event('xp', 'Level ' .. tostring(param1), 'level_up');
        end
        return;
    end

    -- Gil from a kill / chest. 565: target obtains gil. 582: actor obtains gil.
    if message == 565 or message == 582 then
        local recipient = message == 565 and target or actor;
        if recipient == self_id and param1 > 0 then
            add_progression_event('gil', '+' .. tostring(param1) .. ' gil');
        end
        return;
    end

    -- Some builds route EXP-type rewards through 0x029 as well.
    if actor == self_id or target == self_id then
        local label = exp_message_label(message, param1, param2);
        if label and param1 > 0 then
            report_packet_exp(label);
        end

        if not HANDLED_MESSAGE_IDS[message] and debuglog.enabled() then
            debuglog.report('msg:' .. tostring(message),
                ('unmapped 0x029 message %d'):fmt(message),
                ('MESSAGE msg=%d actor=%s target=%s param1=%d param2=%d'):fmt(
                    message, safe_entity_name(actor), safe_entity_name(target), param1, param2));
        end
    end
end

local function parse_exp_packet(e)
    if not e or not e.data then
        return nil;
    end

    -- 0x02D is a normal byte-aligned packet, read with struct.unpack.
    local data = e.data;

    local ok, parsed = pcall(function()
        return {
            player_id = struct.unpack('I', data, 0x04 + 1),
            target_id = struct.unpack('I', data, 0x08 + 1),
            player_index = struct.unpack('H', data, 0x0C + 1),
            target_index = struct.unpack('H', data, 0x0E + 1),
            amount = struct.unpack('I', data, 0x10 + 1),
            chain = struct.unpack('I', data, 0x14 + 1),
            message = struct.unpack('H', data, 0x18 + 1),
        };
    end);

    if not ok then
        return nil;
    end

    return parsed;
end

local function emit_exp_gain(exp)
    if not exp then
        return;
    end

    local self_id = safe_player_server_id();
    if not self_id or tonumber(exp.player_id) ~= tonumber(self_id) then
        return;
    end

    local amount = tonumber(exp.amount) or 0;
    local message = bit.band(tonumber(exp.message) or -1, 0x7FFF);

    if amount <= 0 then
        return;
    end

    local label = exp_message_label(message, amount, tonumber(exp.chain) or 0);
    if label then
        report_packet_exp(label);
    end
end

-- ============================================================================
-- Chat-text fallback (rewards only)
-- ============================================================================
-- Used only for reward lines a server may deliver without the usual packet.
-- Every line must be about the local player. Combat lines are never read
-- here, and "readies" / "starts casting" lines are never displayed.
local function handle_text_in(e)
    if not e or state.paused or not settings.enabled or e.injected then
        return;
    end

    local raw = e.message;
    if type(raw) ~= 'string' or raw == '' then
        return;
    end

    local line = normalize_line(strip_control_codes(raw));
    if line == '' then
        return;
    end

    local lower = line:lower();

    -- Remember kills briefly; kill gil is printed right after the defeat line.
    if lower:find(' defeats ', 1, true) then
        state.last_kill_time = os.clock();
    end

    local me = safe_me();
    if not me or me == '' or not line_is_about_me(line, me) then
        return;
    end

    local text_opts = { debounce = true };

    -- Gil from a kill: "Izumi obtains 9 gil."
    local gil = line:match('[Oo]btains%s+(%d+)%s+[Gg]il');
    if gil then
        local since_kill = os.clock() - (tonumber(state.last_kill_time) or 0);
        if since_kill >= 0 and since_kill <= 6.0 then
            add_progression_event('gil', '+' .. tostring(gil) .. ' gil');
        end
        return;
    end

    -- EXP-type rewards, only when no packet reported one just now.
    local amount, kind = nil, nil;

    amount = line:match('[Gg]ains?%s+(%d+)%s+[Ee]xperience%s+[Pp]oints?');
    if amount then kind = 'EXP'; end

    if not amount then
        amount = line:match('[Gg]ains?%s+(%d+)%s+[Ll]imit%s+[Pp]oints?');
        if amount then kind = 'Limit Points'; end
    end

    if not amount then
        amount = line:match('[Gg]ains?%s+(%d+)%s+[Cc]apacity%s+[Pp]oints?');
        if amount then kind = 'Capacity Points'; end
    end

    if not amount then
        amount = line:match('[Gg]ains?%s+(%d+)%s+[Ee]xemplar%s+[Pp]oints?');
        if amount then kind = 'Exemplar Points'; end
    end

    if amount and kind then
        if (os.clock() - state.exp_tracking.last_packet) > EXP_SOURCE_WINDOW then
            state.exp_tracking.last_text = os.clock();
            state.exp_tracking.pending = nil;
            local progress = (kind == 'EXP') and exp_progress_suffix(tonumber(amount) or 0, false) or '';
            add_progression_event('xp', '+' .. tostring(amount) .. ' ' .. kind .. progress);
        end
        return;
    end

    -- Skill-up fallback when packet 0x29 Message 38/53 did not arrive.
    local skill_name, rise = line:match("([%a][%a%s%-']-)%s+[Ss]kill%s+[Rr]ises%s+(%d+%.?%d*)%s+[Pp]oints?");
    if skill_name and rise then
        skill_name = skill_name:gsub("^.-'s%s+", ''):gsub("^%s+", ''):gsub("%s+$", '');
        local sid = skill_id_from_name(skill_name);
        local fresh = sid and state.skillup_packet_at[sid] and (os.clock() - state.skillup_packet_at[sid]) < 1.5;
        if not fresh then
            add_event('incoming', 'xp', skill_name .. ' +' .. tostring(rise), 'skill_ups', text_opts);
        end
        return;
    end

    local skill_name2, new_value = line:match("([%a][%a%s%-']-)%s+[Ss]kill%s+[Rr]eaches%s+[Ll]evel%s+(%d+)");
    if skill_name2 and new_value then
        skill_name2 = skill_name2:gsub("^.-'s%s+", ''):gsub("^%s+", ''):gsub("%s+$", '');
        local sid = skill_id_from_name(skill_name2);
        local fresh = sid and state.skillup_packet_at[sid] and (os.clock() - state.skillup_packet_at[sid]) < 1.5;
        if not fresh then
            add_event('incoming', 'xp', skill_name2 .. ' -> ' .. tostring(new_value), 'skill_ups', text_opts);
        end
        return;
    end

    -- Character level-up. Evaluated after skill-level lines so
    -- "Blue magic skill reaches level 99" is never read as character level 99.
    local level = line:match('[Ll]evel%s+increases%s+to%s+(%d+)')
        or line:match('[Aa]ttains%s+[Ll]evel%s+(%d+)')
        or line:match('[Yy]ou%s+attain%s+[Ll]evel%s+(%d+)');
    if level then
        add_progression_event('xp', 'Level ' .. tostring(level), 'level_up');
        return;
    end

    -- Merit / Job Point gains.
    local merit = line:match('[Oo]btains%s+(%d+)%s+[Mm]erit%s+[Pp]oints?')
        or line:match('[Gg]ains%s+(%d+)%s+[Mm]erit%s+[Pp]oints?');
    if merit then
        add_progression_event('xp', '+' .. tostring(merit) .. ' Merit Points');
        return;
    end

    if lower:find('earns a merit point', 1, true) then
        add_progression_event('xp', '+1 Merit Point');
        return;
    end

    local jp = line:match('[Oo]btains%s+(%d+)%s+[Jj]ob%s+[Pp]oints?')
        or line:match('[Gg]ains%s+(%d+)%s+[Jj]ob%s+[Pp]oints?');
    if jp then
        add_progression_event('xp', '+' .. tostring(jp) .. ' Job Points');
        return;
    end

    -- Treasure-pool finds (the item dropped): "You find a Beastman Seal on the Goblin."
    local found = line:match('[Yy]ou%s+find%s+an?%s+(.+)%s+[Oo]n%s+the%s+.+%.?$')
        or line:match('[Yy]ou%s+find%s+(.+)%s+[Oo]n%s+the%s+.+%.?$')
        or line:match('[Yy]ou%s+find%s+an?%s+(.+)%.?$');
    if found and not found:lower():find('gil', 1, true) then
        found = found:gsub('%.$', ''):gsub('%s+$', '');
        add_event('incoming', 'xp', found, 'item_drops', text_opts);
        return;
    end

    -- Items the player actually received: "Izumi obtains a Beastman Seal."
    local obtained = line:match('[Oo]btains%s+an?%s+(.+)%.?$')
        or line:match('[Oo]btains%s+the%s+(.+)%.?$')
        or line:match('[Oo]btains%s+(%d+%s+.+)%.?$');
    if obtained and not obtained:lower():find('gil', 1, true) then
        obtained = obtained:gsub('%.$', ''):gsub('%s+$', '');
        session.record_obtain(obtained);
        add_event('incoming', 'xp', obtained, 'item_obtained', text_opts);
        return;
    end

    -- Status removal fallback when 0x29/206 did not arrive.
    local removed = line:match("^.-'s%s+(.+)%s+[Ee]ffect%s+[Ww]ears%s+[Oo]ff");
    if removed then
        removed = removed:gsub('%.$', '');
        local seen = state.status_removed_at[removed:lower()];
        if not seen or (os.clock() - seen) > 2.0 then
            add_event('incoming', 'ability', removed .. ' removed', 'status_removed', text_opts);
        end
        return;
    end
end

-- ============================================================================
-- Memory-backed EXP fallback
-- ============================================================================

local function safe_player_exp()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then
        return nil, nil;
    end

    local player = mm:GetPlayer();
    if not player then
        return nil, nil;
    end

    if player.GetExpCurrent == nil or player.GetExpNeeded == nil then
        return nil, nil;
    end

    local ok_current, current = pcall(function()
        return player:GetExpCurrent();
    end);

    local ok_needed, needed = pcall(function()
        return player:GetExpNeeded();
    end);

    if not ok_current or not ok_needed then
        return nil, nil;
    end

    current = tonumber(current);
    needed = tonumber(needed);

    if not current or not needed then
        return nil, nil;
    end

    return current, needed;
end

-- amount: the gain being reported.
-- already_applied: true when the memory value already includes the gain
-- (memory watcher). Packets and chat text usually arrive before memory
-- updates, so for them the gain is added unless memory already moved.
exp_progress_suffix = function(amount, already_applied)
    local current, needed = safe_player_exp();
    if current == nil or needed == nil or needed <= 0 then
        return '';
    end

    if not already_applied and state.xp_watch.initialized
        and tonumber(state.xp_watch.current) == current then
        current = current + (tonumber(amount) or 0);
    end

    -- Level-up rollover: the new level's numbers are not known yet.
    if current >= needed then
        return '';
    end

    return ' (' .. with_commas(current) .. '/' .. with_commas(needed) .. ')';
end

local function update_exp_memory_watch()
    local now = os.clock();
    local tracking = state.exp_tracking;

    -- Show a memory-detected gain only if no packet or text reported EXP
    -- within the grace window after it was seen.
    if tracking.pending and (now - tracking.pending.at) >= 1.0 then
        local recent_report = math.max(tracking.last_packet, tracking.last_text);
        if (now - recent_report) > EXP_SOURCE_WINDOW then
            add_progression_event('xp', '+' .. tostring(tracking.pending.amount) .. ' EXP'
                .. exp_progress_suffix(tracking.pending.amount, true));
        end
        tracking.pending = nil;
    end

    if (now - (state.xp_watch.last_check or 0)) < 0.10 then
        return;
    end
    state.xp_watch.last_check = now;

    -- Zoning: wait, then take a fresh baseline instead of reporting a gain.
    if now < (state.xp_watch.suspended_until or 0) then
        state.xp_watch.initialized = false;
        return;
    end

    local current, needed = safe_player_exp();
    if current == nil or needed == nil then
        return;
    end

    -- "Needed" is never 0 for a loaded character; a 0 means the memory is
    -- not ready (login, zoning). Re-baseline on the next good read.
    if needed <= 0 then
        state.xp_watch.initialized = false;
        return;
    end

    if not state.xp_watch.initialized then
        state.xp_watch.current = current;
        state.xp_watch.needed = needed;
        state.xp_watch.initialized = true;
        return;
    end

    local old_current = tonumber(state.xp_watch.current) or current;
    local old_needed = tonumber(state.xp_watch.needed) or needed;
    local gained = 0;

    if needed == old_needed and current > old_current and old_current > 0 then
        -- Normal EXP gain within the same level. (A jump up from exactly 0 is
        -- treated as a memory reload, not a gain; a real gain from 0 still
        -- arrives through the EXP packet.)
        gained = current - old_current;

    elseif needed > old_needed and current < old_current then
        -- Level-up rollover: remaining EXP of the old level + EXP into the new
        -- one. A level-down (death) lowers "needed" and is ignored here.
        local remaining = old_needed - old_current;
        if remaining >= 0 then
            gained = remaining + current;
        end
    end

    state.xp_watch.current = current;
    state.xp_watch.needed = needed;

    if gained > 0 and gained < 100000 then
        local recent_report = math.max(tracking.last_packet, tracking.last_text);
        if (now - recent_report) > EXP_SOURCE_WINDOW then
            if tracking.pending then
                tracking.pending.amount = tracking.pending.amount + gained;
            else
                tracking.pending = { amount = gained, at = now };
            end
        end
    end
end

local function zone_name_from_id(zone_id)
    local rm = AshitaCore:GetResourceManager();
    if not rm then return nil end
    local ok, name = pcall(function()
        return rm:GetString('zones.names', zone_id);
    end);
    if ok and type(name) == 'string' and name ~= '' then
        return name;
    end
    return nil;
end

-- Shows the queued zone banner once the player has finished loading in, so
-- it does not scroll away during the loading screen.
local function update_zone_banner()
    local pending = state.pending_zone;
    if not pending then return end

    local now = os.clock();
    local waited = now - pending.at;

    if waited > 30.0 then
        state.pending_zone = nil;
        return;
    end

    if waited < 1.5 then
        return;
    end

    local loaded = false;
    pcall(function()
        local mm = AshitaCore:GetMemoryManager();
        local party = mm and mm:GetParty();
        local entity = mm and mm:GetEntity();
        if not party or not entity then return end
        local index = party:GetMemberTargetIndex(0);
        if index and index ~= 0 then
            local name = entity:GetName(index);
            loaded = type(name) == 'string' and name ~= '';
        end
    end);

    if not loaded then
        return;
    end

    state.pending_zone = nil;
    local name = zone_name_from_id(pending.id) or ('Zone #' .. tostring(pending.id));
    add_event('incoming', 'xp', '=== Area: ' .. name .. ' ===', 'zone_change', { symbol = '' });
end

-- 0x029 message packet entry point.
local function handle_message_packet(e)
    local ok, msg = pcall(parse_message_packet, e);
    if ok and msg then
        pcall(emit_message_packet, msg);
    end
end

-- 0x02D EXP / reward packet entry point.
local function handle_exp_packet(e)
    local ok, exp = pcall(parse_exp_packet, e);
    if ok and exp then
        pcall(emit_exp_gain, exp);
    end
end

-- Zone out (0x0B) / zone in (0x0A): EXP memory reads are unreliable while
-- zoning (they briefly read 0, then the full value), which looked like a
-- gain of the entire current EXP. Re-baseline after the zone settles.
local function handle_zone_packet(e)
    state.xp_watch.initialized = false;
    state.xp_watch.suspended_until = os.clock() + 8.0;
    state.exp_tracking.pending = nil;

    -- Zone in: queue an "=== Area: Name ===" banner. 0x00A carries the zone
    -- id at offset 0x30. It is shown once the player has loaded in.
    if e.id == 0x0A then
        local ok, zone_id = pcall(function()
            return struct.unpack('H', e.data, 0x30 + 1);
        end);
        if ok and zone_id and zone_id > 0 then
            state.pending_zone = { id = zone_id, at = os.clock() };
        end
    end
end

-- ----------------------------------------------------------------------------
-- Resting (/heal), Regen and Refresh ticks, read from your own party slot
-- after the change happened (nothing is announced ahead of time).
--
-- Regen / Refresh (spells, gear, BLU Auto-Regen / Auto-Refresh) tick every
-- 3 seconds; a resting tick comes every 10 seconds. A regen amount is
-- learned when two equal small HP (or MP) gains land 3s apart; after that,
-- gains that land on the 3s beat have the regen amount split off and shown
-- as [REGEN] / [REFRESH]. What is left while you are resting is the real
-- rest tick:
--   [REST] +20 HP / +15 MP / -100 TP   (TP only when TP was lost)
-- [REGEN] / [REFRESH] lines show at all times (resting or not) whenever the
-- tick restored 1 or more; a tick that restores 0 (stat full) shows nothing.
-- ----------------------------------------------------------------------------
local REST_STATUS = 33;
local REGEN_PERIOD = 3.0;
local REGEN_SLACK = 0.45;
local REGEN_MAX_AMOUNT = 50;

-- Regen / Refresh status effects (a spell or ability on you). Without one,
-- a regen tick comes from a trait (BLU Auto Regen / Auto Refresh), gear or
-- food, and is labeled AUTO.
local REGEN_BUFF = 42;
local REFRESH_BUFF = 43;
-- HP and MP from the same tick can arrive a moment apart; collect them this
-- long and show one line.
local TICK_SETTLE = 0.30;

local rest_watch = {
    active = false, hp = 0, mp = 0, tp = 0, pending = nil, last_check = 0,
    ticks = nil,               -- { hp, mp, at } collected regen / refresh tick
    regen = { stat = 'HP' },   -- amount, last_tick, cand_value, cand_time
    refresh = { stat = 'MP' },
};

local function read_rest_state()
    local mm = AshitaCore:GetMemoryManager();
    if not mm then return nil; end
    local party = mm:GetParty();
    local entity = mm:GetEntity();
    local player = mm:GetPlayer();
    if not party or not entity then return nil; end

    local ok, status, hp, mp, tp, hpmax, mpmax = pcall(function()
        local index = party:GetMemberTargetIndex(0);
        return entity:GetStatus(index), party:GetMemberHP(0), party:GetMemberMP(0), party:GetMemberTP(0),
            player and player:GetHPMax() or 0, player and player:GetMPMax() or 0;
    end);
    if not ok then return nil; end
    return tonumber(status) or 0, tonumber(hp) or 0, tonumber(mp) or 0, tonumber(tp) or 0,
        tonumber(hpmax) or 0, tonumber(mpmax) or 0;
end

-- True when `now` lands on the 3s beat of the last regen tick (allowing for
-- beats skipped while the stat was full).
local function on_regen_beat(w, now)
    if w.amount == nil or w.last_tick == nil then return false; end
    local since = now - w.last_tick;
    if since < REGEN_PERIOD - REGEN_SLACK then return false; end
    local phase = since % REGEN_PERIOD;
    return phase <= REGEN_SLACK or phase >= (REGEN_PERIOD - REGEN_SLACK);
end

-- Splits a gain into (regen part, remainder) and keeps learning the amount.
local function split_regen(w, delta, now, current, maximum)
    local regen_part = 0;

    if on_regen_beat(w, now) then
        -- A capped tick (stat reached max) can be smaller than the amount.
        regen_part = math.min(delta, w.amount);
        w.last_tick = now;
    end

    -- Learn: two equal small gains 3s apart. Rest ticks are 10s apart, so
    -- they cannot pair up this way.
    if delta <= REGEN_MAX_AMOUNT and current < maximum then
        if w.cand_time ~= nil and w.cand_value == delta
            and math.abs((now - w.cand_time) - REGEN_PERIOD) <= REGEN_SLACK then
            if w.amount ~= delta then
                w.amount = delta;
                regen_part = delta;
            end
            w.last_tick = now;
        end
        w.cand_time = now;
        w.cand_value = delta;
    end

    return regen_part, delta - regen_part;
end

-- Forget a learned amount once the beat goes quiet while the stat is not
-- full (the regen effect wore off or the gear came off).
local function expire_regen(w, now, current, maximum)
    if w.amount ~= nil and w.last_tick ~= nil and current < maximum
        and (now - w.last_tick) > (REGEN_PERIOD * 2 + REGEN_SLACK * 2) then
        w.amount = nil;
        w.last_tick = nil;
        w.auto = nil;
    end
end

local function has_buff(buff_id)
    local ok, found = pcall(function()
        local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs();
        for _, id in pairs(buffs or {}) do
            if tonumber(id) == buff_id then return true; end
        end
        return false;
    end);
    return ok and found == true;
end

-- Splits one stat's tick into (cast part, auto part).
--   * No Regen / Refresh effect on you: all of it is AUTO (trait, gear,
--     food), and a full tick teaches the auto amount (w.auto).
--   * Effect on you and an auto amount is known: the auto amount is split
--     off, the rest is the cast Regen / Refresh (a tick no bigger than the
--     auto amount is all AUTO).
--   * Effect on you, no auto amount known: all of it is the cast effect.
local function split_tick(w, amount, buff_id)
    if amount <= 0 then return 0, 0; end
    if not has_buff(buff_id) then
        if w.amount ~= nil and amount == w.amount then w.auto = amount; end
        return 0, amount;
    end
    local auto = tonumber(w.auto) or 0;
    if auto > 0 then
        if amount > auto then return amount - auto, auto; end
        -- Not more than the auto amount: the cast effect's amount is not
        -- learned yet (its first tick), so this is the auto part.
        return 0, amount;
    end
    return amount, 0;
end

-- Regen / Refresh tick text, colored per part (Performance renderer):
--   "[REGEN] +24 HP / [AUTO REFRESH] +1 MP"   (one line)
-- When a cast Regen / Refresh and the matching AUTO one tick together, the
-- cast part gets a line of its own and the AUTO parts share the next one:
--   "[REGEN] +23 HP"
--   "[AUTO REGEN] +1 HP / [AUTO REFRESH] +1 MP"
local function emit_parts(parts)
    if #parts == 0 then return; end
    local texts, segments = {}, {};
    for i, p in ipairs(parts) do
        if i > 1 then
            segments[#segments + 1] = { text = ' / ', event_type = parts[i - 1].event_type };
        end
        texts[#texts + 1] = p.text;
        segments[#segments + 1] = { text = p.text, event_type = p.event_type };
    end
    add_event('incoming', 'heal', table.concat(texts, ' / '), parts[1].event_type, { segments = segments });
end

local function emit_tick_line(ticks)
    local show_hp = ticks.hp > 0 and events_mod.event_visible('regen_ticks');
    local show_mp = ticks.mp > 0 and events_mod.event_visible('refresh_ticks');
    local hp_cast, hp_auto = 0, 0;
    local mp_cast, mp_auto = 0, 0;
    if show_hp then hp_cast, hp_auto = split_tick(rest_watch.regen, ticks.hp, REGEN_BUFF); end
    if show_mp then mp_cast, mp_auto = split_tick(rest_watch.refresh, ticks.mp, REFRESH_BUFF); end

    local cast, auto = {}, {};
    if hp_cast > 0 then cast[#cast + 1] = { text = ('[REGEN] +%d HP'):fmt(hp_cast), event_type = 'regen_ticks' }; end
    if mp_cast > 0 then cast[#cast + 1] = { text = ('[REFRESH] +%d MP'):fmt(mp_cast), event_type = 'refresh_ticks' }; end
    if hp_auto > 0 then auto[#auto + 1] = { text = ('[AUTO REGEN] +%d HP'):fmt(hp_auto), event_type = 'regen_ticks' }; end
    if mp_auto > 0 then auto[#auto + 1] = { text = ('[AUTO REFRESH] +%d MP'):fmt(mp_auto), event_type = 'refresh_ticks' }; end

    local overlap = (hp_cast > 0 and hp_auto > 0) or (mp_cast > 0 and mp_auto > 0);
    if overlap then
        emit_parts(cast);
        emit_parts(auto);
        return;
    end

    -- No overlap: one line, HP part first.
    local all = {};
    for _, list in ipairs({ cast, auto }) do
        for _, p in ipairs(list) do all[#all + 1] = p; end
    end
    table.sort(all, function(a, b) return (a.event_type == 'regen_ticks') and b.event_type ~= 'regen_ticks'; end);
    emit_parts(all);
end

local function update_rest_watch()
    local now = os.clock();

    -- Emit a collected Regen / Refresh tick once both halves are in.
    local ticks = rest_watch.ticks;
    if ticks and (now - ticks.at) >= TICK_SETTLE then
        rest_watch.ticks = nil;
        emit_tick_line(ticks);
    end

    -- Emit a collected rest tick once it has settled.
    local pending = rest_watch.pending;
    if pending and (now - pending.at) >= 0.5 then
        rest_watch.pending = nil;
        if pending.hp > 0 or pending.mp > 0 then
            local text = ('[REST] +%d HP / +%d MP'):fmt(pending.hp, pending.mp);
            if pending.tp < 0 then
                text = text .. (' / %d TP'):fmt(pending.tp);
            end
            add_event('incoming', 'heal', text, 'resting');
        end
    end

    if (now - rest_watch.last_check) < 0.10 then return; end
    rest_watch.last_check = now;

    local status, hp, mp, tp, hpmax, mpmax = read_rest_state();
    if status == nil then return; end

    local resting = status == REST_STATUS;
    local first = not rest_watch.active;
    rest_watch.active = true;

    local dhp = hp - rest_watch.hp;
    local dmp = mp - rest_watch.mp;
    local dtp = tp - rest_watch.tp;
    rest_watch.hp, rest_watch.mp, rest_watch.tp = hp, mp, tp;
    if first then return; end

    expire_regen(rest_watch.regen, now, hp, hpmax);
    expire_regen(rest_watch.refresh, now, mp, mpmax);

    local regen_hp, rest_hp = 0, 0;
    local refresh_mp, rest_mp = 0, 0;
    if dhp > 0 then regen_hp, rest_hp = split_regen(rest_watch.regen, dhp, now, hp, hpmax); end
    if dmp > 0 then refresh_mp, rest_mp = split_regen(rest_watch.refresh, dmp, now, mp, mpmax); end

    -- Regen / Refresh ticks show at all times, whenever they restored 1+.
    -- HP and MP of the same tick are collected into one line (see above).
    if regen_hp > 0 or refresh_mp > 0 then
        if rest_watch.ticks == nil then
            rest_watch.ticks = { hp = 0, mp = 0, at = now };
        end
        rest_watch.ticks.hp = rest_watch.ticks.hp + regen_hp;
        rest_watch.ticks.mp = rest_watch.ticks.mp + refresh_mp;
    end

    if not resting then
        rest_watch.pending = nil;
        return;
    end

    if rest_hp > 0 or rest_mp > 0 or dtp < 0 then
        if rest_watch.pending == nil then
            rest_watch.pending = { hp = 0, mp = 0, tp = 0, at = now };
        end
        if rest_hp > 0 then rest_watch.pending.hp = rest_watch.pending.hp + rest_hp; end
        if rest_mp > 0 then rest_watch.pending.mp = rest_watch.pending.mp + rest_mp; end
        if dtp < 0 then rest_watch.pending.tp = rest_watch.pending.tp + dtp; end
    end
end

return {
    update_rest_watch = update_rest_watch,
    handle_message_packet = handle_message_packet,
    handle_exp_packet = handle_exp_packet,
    handle_zone_packet = handle_zone_packet,
    handle_text_in = handle_text_in,
    update_exp_memory_watch = update_exp_memory_watch,
    update_zone_banner = update_zone_banner,
};
