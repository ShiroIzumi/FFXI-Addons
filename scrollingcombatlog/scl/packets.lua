require('common');
local core_mod = require('scl.core');
local events_mod = require('scl.events');
local resources_mod = require('scl.resources');
local settings = core_mod.settings;
local state = core_mod.state;
local add_combat_number = events_mod.add_combat_number;
local add_event = events_mod.add_event;
local source_suffix = events_mod.source_suffix;
local target_suffix = events_mod.target_suffix;
local safe_ability_name = resources_mod.safe_ability_name;
local safe_entity_name = resources_mod.safe_entity_name;
local safe_item_name = resources_mod.safe_item_name;
local safe_monster_ability_name = resources_mod.safe_monster_ability_name;
local safe_pet_server_id = resources_mod.safe_pet_server_id;
local safe_player_server_id = resources_mod.safe_player_server_id;
local safe_spell_name = resources_mod.safe_spell_name;
local safe_status_name = resources_mod.safe_status_name;
local safe_spell_element = resources_mod.safe_spell_element;
local session = require('scl.session');
local debuglog = require('scl.debuglog');

-- ============================================================================
-- Action message tables
-- ============================================================================
-- IDs come from the client's action-message resource table. Grouping them by
-- meaning keeps the classification logic below readable and makes it easy to
-- map an extra HorizonXI-specific message later.

local function id_set(list)
    local out = {};
    for _, id in ipairs(list) do
        out[id] = true;
    end
    return out;
end

-- HorizonXI COMPLIANCE ------------------------------------------------------
-- Action packet categories that announce an action BEFORE it happens:
--   7  = weapon skill / monster TP move "readies"
--   8  = spell "starts casting"
--   9  = item "starts using"
--   12 = ranged attack "starts aiming"
-- Displaying these would warn the player about incoming actions, which is a
-- prohibited advantage on HorizonXI. They are discarded before parsing and
-- are never displayed in any form. Only completed actions are shown.
local START_CATEGORIES = id_set({ 7, 8, 9, 12 });

-- Completed-action categories this addon reads.
--   1 melee, 2 ranged, 3 weapon skill, 4 spell, 5 item, 6 job ability,
--   11 monster TP move, 13 pet ability, 14 dance/flourish, 15 rune ability.
local FINISH_CATEGORIES = id_set({ 1, 2, 3, 4, 5, 6, 11, 13, 14, 15 });

-- Melee / ranged hits that carry damage in Param.
local MELEE_DAMAGE_MESSAGES = id_set({ 1, 67, 157, 352, 353, 576, 577 });
local CRITICAL_MESSAGES = id_set({ 67, 353 });

-- Damage dealt by a spell, weapon skill, ability, item or TP move.
local DAMAGE_MESSAGES = id_set({
    2, 110, 157, 185, 196, 197, 252, 264, 265, 317, 379, 413, 522, 648, 650, 747,
});

-- HP recovered by the target.
local HEAL_MESSAGES = id_set({
    7, 24, 26, 102, 103, 122, 238, 263, 318, 357, 367, 651,
});

-- MP recovered by the target.
local MP_RECOVER_MESSAGES = id_set({ 25, 224, 276, 358, 451, 588 });

-- HP / MP drained from the target (the actor gains it).
local HP_DRAIN_MESSAGES = id_set({ 187, 227, 274, 281, 748, 802 });
local MP_DRAIN_MESSAGES = id_set({ 225, 228, 275, 366, 750, 751 });

-- Weapon skill / ability that missed or was evaded.
local ACTION_MISS_MESSAGES = id_set({ 158, 188, 245, 282, 324, 658 });

-- Spell / ability resisted, or had no effect.
local RESIST_MESSAGES = id_set({ 85, 284, 653, 654, 655, 656 });
local NO_EFFECT_MESSAGES = id_set({ 156, 189, 248, 283, 323, 355, 659 });

-- Messages whose Param is a status-effect ID.
local STATUS_MESSAGES = id_set({
    127, 141, 186, 194, 203, 205, 230, 236, 237, 242, 243, 266, 267, 268,
    269, 270, 271, 272, 277, 278, 279, 280, 319, 320,
});

-- Status messages that are "gains the effect of" (beneficial wording).
local POSITIVE_STATUS_MESSAGES = id_set({ 186, 194, 205, 230, 266, 280, 319 });

-- Magic Burst result messages.
local MAGIC_BURST_MESSAGES = id_set({
    252, 265, 268, 269, 271, 272, 274, 275, 379, 650, 747, 748, 750, 751, 752, 753,
});

-- Defensive outcomes against a melee / ranged swing.
local DEFENSE_LABELS = {
    [30]  = 'ANTICIPATE',
    [32]  = 'DODGE',
    [69]  = 'BLOCK',
    [70]  = 'PARRY',
    [282] = 'EVADE',
};

-- Same outcomes, worded from the attacker's side (your attack was stopped).
local OUTGOING_DEFENSE_LABELS = {
    [15]  = 'MISS',
    [30]  = 'ANTICIPATED',
    [31]  = 'SHADOW',
    [32]  = 'DODGED',
    [69]  = 'BLOCKED',
    [70]  = 'PARRIED',
    [282] = 'EVADED',
    [354] = 'MISS',
};

-- Skillchains are reported in the additional-effect message of the closing
-- weapon skill. 288-302 deal damage, 385-398 heal (for example vs. undead).
local SKILLCHAIN_ORDER = {
    'Light', 'Darkness', 'Gravitation', 'Fragmentation', 'Distortion',
    'Fusion', 'Compression', 'Liquefaction', 'Induration', 'Reverberation',
    'Transfixion', 'Scission', 'Detonation', 'Impaction', 'Cosmic Elucidation',
};

local SKILLCHAIN_MESSAGES = {};
for i, name in ipairs(SKILLCHAIN_ORDER) do
    SKILLCHAIN_MESSAGES[287 + i] = { name = name, heal = false };
    if i <= 14 then
        SKILLCHAIN_MESSAGES[384 + i] = { name = name, heal = true };
    end
end
SKILLCHAIN_MESSAGES[767] = { name = 'Radiance', heal = false };
SKILLCHAIN_MESSAGES[768] = { name = 'Umbra', heal = false };
SKILLCHAIN_MESSAGES[769] = { name = 'Radiance', heal = true };
SKILLCHAIN_MESSAGES[770] = { name = 'Umbra', heal = true };

-- 1.3.0 ------------------------------------------------------------------
-- Steal / Mug / Despoil / Charm results (job ability finish messages).
local STEAL_SUCCESS   = id_set({ 125 });        -- param = item id
local STEAL_FAIL      = id_set({ 153 });
local MUG_SUCCESS     = id_set({ 129 });        -- param = gil
local MUG_FAIL        = id_set({ 244 });
local DESPOIL_SUCCESS = id_set({ 593 });        -- param = item id
local CHARM_SUCCESS   = id_set({ 136 });
local CHARM_FAIL      = id_set({ 137, 138 });

-- Phantom Roll / Double-Up results (param = the roll total).
local ROLL_TOTAL = id_set({ 420, 424 });
local ROLL_BUST  = id_set({ 426, 427 });
local ROLL_FAIL  = id_set({ 422, 423, 425, 428 });
local ROLL_ALL   = id_set({ 420, 421, 422, 423, 424, 425, 426, 427, 428 });

-- Lucky / unlucky numbers per roll.
local ROLL_NUMBERS = {
    ["Corsair's Roll"] = { 5, 9 }, ['Ninja Roll'] = { 4, 8 }, ["Hunter's Roll"] = { 4, 8 },
    ['Chaos Roll'] = { 4, 8 }, ["Magus's Roll"] = { 2, 6 }, ["Healer's Roll"] = { 3, 7 },
    ['Drachen Roll'] = { 4, 8 }, ['Choral Roll'] = { 2, 6 }, ["Monk's Roll"] = { 3, 7 },
    ['Beast Roll'] = { 4, 8 }, ['Samurai Roll'] = { 2, 6 }, ["Evoker's Roll"] = { 5, 9 },
    ["Rogue's Roll"] = { 5, 9 }, ["Warlock's Roll"] = { 4, 8 }, ["Fighter's Roll"] = { 5, 9 },
    ['Puppet Roll'] = { 3, 7 }, ["Gallant's Roll"] = { 3, 7 }, ["Wizard's Roll"] = { 5, 9 },
    ["Dancer's Roll"] = { 3, 7 }, ["Scholar's Roll"] = { 2, 6 },
};

-- Spell "interrupted" code in a category 8 packet's main param (the other
-- category 8 code, 24931, is "starts casting" and is never used).
local CAST_INTERRUPTED = 28787;

-- Stoneskin status id (a 0-damage hit while it's up was absorbed by it).
local STATUS_STONESKIN = 37;
local stoneskin_cache = { at = -1, value = false };

local function has_stoneskin()
    local now = os.clock();
    if now - stoneskin_cache.at < 0.25 then
        return stoneskin_cache.value;
    end
    stoneskin_cache.at = now;
    stoneskin_cache.value = false;
    pcall(function()
        local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs();
        for i = 1, 32 do
            if tonumber(buffs[i]) == STATUS_STONESKIN then
                stoneskin_cache.value = true;
                return;
            end
        end
    end);
    return stoneskin_cache.value;
end

local function likely_beneficial_status(name)
    local n = tostring(name or ''):lower();
    if n == '' then return false end
    local prefixes = {
        'protect', 'shell', 'haste', 'refresh', 'regen', 'stoneskin',
        'phalanx', 'blink', 'aquaveil', 'reraise', 'sneak', 'invisible',
        'bar', 'boost', 'gain', 'enfire', 'enblizzard', 'enaero',
        'enstone', 'enthunder', 'enwater', 'enlight', 'endark',
    };
    for _, p in ipairs(prefixes) do
        if n:sub(1, #p) == p then
            return true;
        end
    end
    return false;
end

local function sata_suffix()
    local tags = {};
    if state.sata.sneak then tags[#tags + 1] = 'SA'; end
    if state.sata.trick then tags[#tags + 1] = 'TA'; end
    if #tags == 0 then return '' end
    return ' [' .. table.concat(tags, '+') .. ']';
end

local function consume_sata()
    state.sata.sneak = false;
    state.sata.trick = false;
end


-- ============================================================================
-- Packet-driven live combat capture (0x028 action packet)
-- ============================================================================

-- Reads only the category field (bits 82-85) so start-of-action packets can
-- be thrown away before any other parsing work happens.
local function peek_action_category(e)
    if not e or not e.data_raw then
        return nil;
    end
    local ok, category = pcall(function()
        return ashita.bits.unpack_be(e.data_raw, 0, 82, 4);
    end);
    if ok then
        return category;
    end
    return nil;
end

local function parse_action_packet(e)
    if not e or not e.data_raw then
        return nil;
    end

    local bit_data = e.data_raw;
    local bit_offset = 40;

    local function unpack_bits(length)
        local value = ashita.bits.unpack_be(bit_data, 0, bit_offset, length);
        bit_offset = bit_offset + length;
        return value;
    end

    local act = {
        actor_id = unpack_bits(32),
        targets = {},
    };

    -- 0x028 layout: target count = 6 bits, 4 unknown bits, category = 4
    -- bits, action id/param = 17 bits (+15 unused), recast = 32 bits.
    local target_count = unpack_bits(6);
    bit_offset = bit_offset + 4;

    act.category = unpack_bits(4);
    act.param = unpack_bits(17);

    bit_offset = bit_offset + 15;
    act.recast = unpack_bits(32);

    if not target_count or target_count < 0 or target_count > 32 then
        return nil;
    end

    for _ = 1, target_count do
        local target = {
            server_id = unpack_bits(32),
            actions = {},
        };

        local action_count = unpack_bits(4);
        if not action_count or action_count < 0 or action_count > 16 then
            return nil;
        end

        for _ = 1, action_count do
            local action = {
                reaction = unpack_bits(5),
                animation = unpack_bits(12),
                special_effect = unpack_bits(7),
                knockback = unpack_bits(3),
                param = unpack_bits(17),
                message = unpack_bits(10),
                flags = unpack_bits(31),
            };

            local has_additional = unpack_bits(1) == 1;
            if has_additional then
                action.additional = {
                    animation = unpack_bits(6),
                    effect = unpack_bits(4),
                    param = unpack_bits(17),
                    message = unpack_bits(10),
                };
            end

            -- Spikes block: 6-bit animation + 4-bit effect, 14-bit param,
            -- 10-bit message (same 10-bit header as the additional effect).
            -- Earlier builds skipped the 4 effect bits, which shifted Param
            -- and Message so spike / counter damage never matched.
            local has_spikes = unpack_bits(1) == 1;
            if has_spikes then
                action.spikes = {
                    animation = unpack_bits(6),
                    effect = unpack_bits(4),
                    param = unpack_bits(14),
                    message = unpack_bits(10),
                };
            end

            target.actions[#target.actions + 1] = action;
        end

        act.targets[#act.targets + 1] = target;
    end

    return act;
end

-- Job abilities that come in category 3 (the weapon skill category) with
-- their ability id as the param (LandSandBoat abilities.sql actionType 3):
-- Steal 41 would otherwise read as Swift Blade (weapon skill 41), Mug 45 as
-- Atonement, and so on. A real weapon skill uses the weapon skill messages,
-- so an id on this list without one of those messages is the job ability.
local CAT3_ABILITIES = {
    [26] = true,  -- Eagle Eye Shot
    [41] = true,  -- Steal
    [45] = true,  -- Mug
    [46] = true,  -- Shield Bash
    [57] = true,  -- Shadowbind
    [66] = true,  -- Jump
    [67] = true,  -- High Jump
    [68] = true,  -- Super Jump
    [77] = true,  -- Weapon Bash
    [150] = true, -- Tomahawk
    [168] = true, -- Blade Bash
    [170] = true, -- Angon
    [228] = true, -- Despoil
    [260] = true, -- Spirit Jump
    [285] = true, -- Bounty Shot
    [293] = true, -- Soul Jump
    [328] = true, -- Larceny
    [329] = true, -- Intervene
};
local WS_MESSAGES = { [185] = true, [186] = true, [187] = true, [188] = true, [189] = true, [194] = true,
    [197] = true, [224] = true, [225] = true, [226] = true, [238] = true, [264] = true, [274] = true };

-- Steal / Mug / Despoil / Larceny results.
local STEAL_OK = { [125] = true, [453] = true };      -- param = item id
local STEAL_FAIL = { [153] = true, [454] = true };
local MUG_OK = { [129] = true };                       -- param = gil
local MUG_FAIL = { [244] = true };

local function is_cat3_ability(act)
    if not act or act.category ~= 3 or not CAT3_ABILITIES[tonumber(act.param) or -1] then
        return false;
    end
    local first = act.targets and act.targets[1] and act.targets[1].actions and act.targets[1].actions[1];
    local message = first and tonumber(first.message) or -1;
    return not WS_MESSAGES[message];
end

local function action_name(act)
    if not act then
        return nil;
    end

    -- Steal, Mug, Jump, Shield Bash ... (job abilities in category 3).
    if act.is_ja then
        return safe_ability_name((tonumber(act.param) or 0) + 512);
    end

    -- Magic finish.
    if act.category == 4 then
        return safe_spell_name(act.param);
    end

    -- Weapon skill finish: packet id maps directly.
    if act.category == 3 then
        return safe_ability_name(act.param);
    end

    -- Item finish.
    if act.category == 5 then
        return safe_item_name(act.param);
    end

    -- Player job abilities use the +512 resource offset in Ashita.
    if act.category == 6 or act.category == 14 or act.category == 15 then
        return safe_ability_name((tonumber(act.param) or 0) + 512);
    end

    -- Monster / pet TP moves need their own lookup path.
    if act.category == 11 or act.category == 13 then
        return safe_monster_ability_name(act.param);
    end

    return nil;
end

local function fallback_action_name(act)
    if act.category == 4 then return 'Spell #' .. tostring(act.param); end
    if act.category == 3 and not act.is_ja then return 'Weapon Skill #' .. tostring(act.param); end
    if act.category == 5 then return 'Item #' .. tostring(act.param); end
    if act.category == 11 or act.category == 13 then return 'Mob Ability #' .. tostring(act.param); end
    return 'Ability #' .. tostring(act.param);
end

local function status_text(action)
    local message = tonumber(action.message) or -1;
    if not STATUS_MESSAGES[message] then
        return nil;
    end
    return safe_status_name(action.param);
end

-- Additional effect riding on a hit / weapon skill.
-- outgoing = true when the local player's action produced it.
local function emit_additional_effect(action, outgoing, other_name)
    local add = action and action.additional;
    if not add then return end

    local message = tonumber(add.message) or -1;
    local amount = tonumber(add.param) or 0;

    -- Skillchains are reported separately.
    if SKILLCHAIN_MESSAGES[message] then return end

    -- En-spell style additional effects carry their element in the 6-bit
    -- animation (1 Fire .. 8 Dark), mapped to element ids 0-7.
    local anim = tonumber(add.animation) or 0;
    local element = (anim >= 1 and anim <= 8) and (anim - 1) or nil;

    if outgoing then
        if (message == 163 or message == 229) and amount > 0 then
            session.record_damage(amount, 'add', nil, other_name);
            add_event('outgoing', 'ability',
                'Add. Effect  ' .. tostring(amount) .. target_suffix(other_name),
                'additional_effects', { element = element, amount = amount });
        elseif message == 161 and amount > 0 then
            add_event('outgoing', 'ability',
                'Add. Effect  +' .. tostring(amount) .. ' HP' .. target_suffix(other_name),
                'drain_aspir');
        elseif message == 162 and amount > 0 then
            add_event('outgoing', 'ability',
                'Add. Effect  +' .. tostring(amount) .. ' MP' .. target_suffix(other_name),
                'drain_aspir');
        elseif message == 165 and amount > 0 then
            add_event('outgoing', 'ability',
                'Add. Effect  +' .. tostring(amount) .. ' TP' .. target_suffix(other_name),
                'additional_effects');
        elseif message == 160 or message == 164 then
            local status = safe_status_name(amount) or ('Status #' .. tostring(amount));
            add_event('outgoing', 'ability',
                'Add. Effect: ' .. status .. target_suffix(other_name),
                'additional_effects');
        elseif (message == 167 or message == 384) and amount > 0 then
            add_event('incoming', 'heal',
                '+' .. tostring(amount) .. ' HP  <-  Add. Effect',
                'healing_received');
        elseif message == 152 and amount > 0 then
            add_event('incoming', 'heal',
                '+' .. tostring(amount) .. ' MP  <-  Add. Effect',
                'mp_recovery');
        elseif message == 603 and amount > 0 then
            add_event('outgoing', 'ability',
                'Treasure Hunter ' .. tostring(amount) .. target_suffix(other_name),
                'additional_effects');
        end
        return;
    end

    -- Enemy en-effects landing on the local player.
    if (message == 163 or message == 229) and amount > 0 then
        session.record_hit_taken(amount, 'Add. Effect', other_name);
        add_event('incoming', 'incoming',
            '-' .. tostring(amount) .. source_suffix(other_name) .. ' [ADD]',
            'incoming_damage', { element = element });
    elseif message == 161 and amount > 0 then
        add_event('incoming', 'incoming',
            '-' .. tostring(amount) .. ' HP drained' .. source_suffix(other_name),
            'incoming_damage');
    elseif message == 162 and amount > 0 then
        add_event('incoming', 'ability',
            '-' .. tostring(amount) .. ' MP drained' .. source_suffix(other_name),
            'incoming_abilities');
    elseif message == 160 or message == 164 then
        local status = safe_status_name(amount) or ('Status #' .. tostring(amount));
        add_event('incoming', 'ability', status .. source_suffix(other_name), 'status_negative');
    end
end

-- Spikes / counter data attached to a melee swing.
-- player_attacked = true  : the local player swung; the reaction hits the player.
-- player_attacked = false : the local player was hit; the reaction is the player's.
local function emit_spikes(action, player_attacked, other_name)
    local spikes = action and action.spikes;
    if not spikes then return end

    local message = tonumber(spikes.message) or -1;
    local amount = tonumber(spikes.param) or 0;

    if player_attacked then
        if (message == 44 or message == 132 or message == 33 or message == 536) and amount > 0 then
            session.record_hit_taken(amount, (message == 44 or message == 132) and 'Spikes' or 'Counter', other_name);
        end

        if message == 44 and amount > 0 then
            add_event('incoming', 'incoming',
                '-' .. tostring(amount) .. source_suffix(other_name) .. ' [SPIKES]',
                'incoming_damage');
        elseif message == 132 and amount > 0 then
            add_event('incoming', 'incoming',
                '-' .. tostring(amount) .. ' HP drained' .. source_suffix(other_name) .. ' [SPIKES]',
                'incoming_damage');
        elseif message == 383 and amount > 0 then
            add_event('incoming', 'heal',
                '+' .. tostring(amount) .. ' HP  <-  Spikes',
                'healing_received');
        elseif (message == 33 or message == 536) and amount > 0 then
            add_event('incoming', 'incoming',
                '-' .. tostring(amount) .. source_suffix(other_name)
                    .. (message == 33 and ' [COUNTER]' or ' [RETALIATION]'),
                'incoming_damage');
        elseif message == 14 or message == 535 then
            add_event('incoming', 'miss',
                tostring(amount) .. ' absorbed' .. source_suffix(other_name),
                'defenses', { symbol = '[SHADOW] ' });
        end
        return;
    end

    if (message == 44 or message == 33 or message == 536) and amount > 0 then
        session.record_damage(amount, 'counter', nil, other_name);
    end

    if message == 44 and amount > 0 then
        add_event('outgoing', 'ability',
            'Spikes ' .. tostring(amount) .. target_suffix(other_name), 'counters');
    elseif message == 132 and amount > 0 then
        add_event('outgoing', 'ability',
            'Spikes drain ' .. tostring(amount) .. target_suffix(other_name), 'counters');
    elseif message == 33 and amount > 0 then
        add_event('outgoing', 'ability',
            'Counter ' .. tostring(amount) .. target_suffix(other_name), 'counters');
    elseif message == 536 and amount > 0 then
        add_event('outgoing', 'ability',
            'Retaliation ' .. tostring(amount) .. target_suffix(other_name), 'counters');
    elseif message == 592 and settings.show_misses == true then
        add_event('outgoing', 'miss',
            'Counter MISS' .. target_suffix(other_name), 'counters');
    end
end

local function emit_skillchain(action, target_name)
    local add = action and action.additional;
    if not add then return end

    local sc = SKILLCHAIN_MESSAGES[tonumber(add.message) or -1];
    if not sc then return end

    local amount = tonumber(add.param) or 0;
    local text_value = sc.name;
    if amount > 0 then
        text_value = text_value .. (sc.heal and '  +' or '  ') .. tostring(amount);
    end
    if not sc.heal then
        session.record_damage(amount, 'sc', sc.name, target_name);
    end
    add_event('outgoing', 'ability', text_value .. target_suffix(target_name), 'skillchains',
        { amount = (not sc.heal) and amount or nil });
end

-- Melee / ranged swing (categories 1 and 2).
local function emit_melee(act, action, actor_is_me, target_is_me, actor_name, target_name, target_id)
    local message = tonumber(action.message) or -1;
    local amount = tonumber(action.param) or 0;
    local ranged = act.category == 2;

    if actor_is_me then
        if MELEE_DAMAGE_MESSAGES[message] then
            local is_crit = CRITICAL_MESSAGES[message] == true;
            local event_type = is_crit and 'criticals' or (ranged and 'ranged_damage' or 'melee_damage');
            local prefix = (ranged and is_crit) and '[R] ' or '';

            -- Sneak Attack / Trick Attack ride on the next melee hit.
            local tag = '';
            if not ranged and (state.sata.sneak or state.sata.trick) then
                tag = sata_suffix();
                consume_sata();
            end

            session.record_damage(amount, is_crit and 'crit' or (ranged and 'ranged' or 'melee'), nil, target_name);

            add_combat_number(
                'outgoing',
                is_crit and 'critical' or 'outgoing',
                amount,
                target_name,
                event_type,
                prefix,
                tostring(target_id) .. ':' .. tostring(act.category),
                tag
            );

        elseif message == 33 then
            -- The target countered the player's swing.
            session.record_hit_taken(amount, 'Counter', target_name);
            add_combat_number('incoming', 'incoming', amount, target_name,
                'incoming_damage', '-', nil, ' [COUNTER]');

        elseif message == 14 then
            -- The counter was absorbed by the player's shadows.
            add_event('incoming', 'miss',
                tostring(amount) .. ' absorbed' .. source_suffix(target_name),
                'defenses', { symbol = '[SHADOW] ' });

        else
            -- Missed / stopped. Sneak Attack and Trick Attack are spent too.
            if not ranged then
                consume_sata();
            end

            local label = OUTGOING_DEFENSE_LABELS[message];
            if label and settings.show_misses == true then
                add_event('outgoing', 'miss',
                    (ranged and '[R] ' or '') .. label .. target_suffix(target_name),
                    ranged and 'ranged_damage' or 'melee_damage',
                    { symbol = '' });
            end
        end

        emit_additional_effect(action, true, target_name);
        emit_spikes(action, true, target_name);
        return;
    end

    if not target_is_me then
        return;
    end

    if MELEE_DAMAGE_MESSAGES[message] and amount == 0 and has_stoneskin() then
        add_event('incoming', 'miss', 'STONESKIN absorbed' .. source_suffix(actor_name), 'defenses');

    elseif MELEE_DAMAGE_MESSAGES[message] then
        local is_crit = CRITICAL_MESSAGES[message] == true;
        local reaction = tonumber(action.reaction) or 0;
        local tag = '';
        if reaction == 12 then
            tag = ' [BLOCK]';
        elseif reaction == 10 then
            tag = ' [GUARD]';
        end
        if is_crit then
            tag = tag .. ' [CRIT]';
        end

        session.record_hit_taken(amount, nil, actor_name);

        add_combat_number(
            'incoming',
            is_crit and 'critical' or 'incoming',
            amount,
            actor_name,
            'incoming_damage',
            ranged and '[R] -' or '-',
            tostring(act.actor_id) .. ':' .. tostring(act.category),
            tag
        );

    elseif message == 33 then
        -- The player countered the attacker.
        session.record_damage(amount, 'counter', nil, actor_name);
        add_event('outgoing', 'ability',
            'Counter ' .. tostring(amount) .. target_suffix(actor_name), 'counters');

    elseif message == 592 then
        if settings.show_misses == true then
            add_event('outgoing', 'miss', 'Counter MISS' .. target_suffix(actor_name), 'counters');
        end

    elseif message == 31 then
        add_event('incoming', 'miss',
            tostring(amount) .. ' absorbed' .. source_suffix(actor_name),
            'defenses', { symbol = '[SHADOW] ' });

    elseif DEFENSE_LABELS[message] then
        add_event('incoming', 'miss', DEFENSE_LABELS[message] .. source_suffix(actor_name), 'defenses');

    elseif message == 15 or message == 354 then
        if settings.show_misses == true then
            add_event('incoming', 'miss', 'MISS' .. source_suffix(actor_name), 'defenses');
        end
    end

    emit_additional_effect(action, false, actor_name);
    emit_spikes(action, false, actor_name);
end

-- Spell / weapon skill / ability / item / TP move performed by the player.
-- aggregated = true when this damage is part of an AoE that is shown as one
-- combined line; the per-target damage line is then skipped.
local function emit_own_finish(act, action, target_is_me, target_name, display_name, aggregated)
    local message = tonumber(action.message) or -1;
    local amount = tonumber(action.param) or 0;
    local mb_tag = MAGIC_BURST_MESSAGES[message] and ' [MB]' or '';
    local element = act.category == 4 and safe_spell_element(act.param) or nil;
    local skip_damage_line = aggregated == true and DAMAGE_MESSAGES[message] == true;

    -- Heals and MP gains landing on the player read best as incoming.
    if target_is_me and HEAL_MESSAGES[message] then
        session.record_heal_done(amount, display_name, 'You');
        session.record_heal_taken(amount, display_name, 'You');
        if amount > 0 then
            add_event('incoming', 'heal',
                '+' .. tostring(amount) .. ' HP  <-  ' .. display_name, 'healing_received');
        end
        return;
    end

    if target_is_me and MP_RECOVER_MESSAGES[message] then
        if amount > 0 then
            add_event('incoming', 'heal',
                '+' .. tostring(amount) .. ' MP  <-  ' .. display_name, 'mp_recovery');
        end
        return;
    end

    -- Job abilities that use category 3 (Steal, Mug, Jump ...).
    if act.category == 3 and act.is_ja then
        local event_type = 'outgoing_abilities';
        if STEAL_OK[message] then
            local item = safe_item_name(amount) or ('Item #' .. tostring(amount));
            add_event('outgoing', 'ability', display_name .. ': ' .. item .. target_suffix(target_name), event_type);
        elseif STEAL_FAIL[message] then
            add_event('outgoing', 'miss', display_name .. '  nothing stolen' .. target_suffix(target_name), event_type);
        elseif MUG_OK[message] then
            add_event('outgoing', 'ability', display_name .. ': ' .. tostring(amount) .. ' gil' .. target_suffix(target_name), event_type);
        elseif MUG_FAIL[message] then
            add_event('outgoing', 'miss', display_name .. '  no gil' .. target_suffix(target_name), event_type);
        elseif ACTION_MISS_MESSAGES[message] then
            add_event('outgoing', 'ability', display_name .. '  MISS' .. target_suffix(target_name), event_type);
        elseif DAMAGE_MESSAGES[message] or message == 110 then
            session.record_damage(amount, 'ability', display_name, target_name);
            local text_value = display_name;
            if amount > 0 or settings.show_zero_damage == true then
                text_value = text_value .. '  ' .. tostring(amount);
            end
            add_event('outgoing', 'ability', text_value .. target_suffix(target_name), event_type, { amount = amount });
        else
            local status = status_text(action);
            local suffix = (status and status ~= display_name) and ('  (' .. status .. ')') or '';
            add_event('outgoing', 'ability', display_name .. target_suffix(target_name) .. suffix, event_type);
        end
        emit_additional_effect(action, true, target_name);
        return;
    end

    if act.category == 3 then
        local event_type = 'weapon_skills';

        if ACTION_MISS_MESSAGES[message] then
            add_event('outgoing', 'ability', display_name .. '  MISS' .. target_suffix(target_name), event_type);
            consume_sata();
        elseif DAMAGE_MESSAGES[message] then
            session.record_damage(amount, 'ws', display_name, target_name);
            if not skip_damage_line then
                local text_value = display_name;
                if amount > 0 or settings.show_zero_damage == true then
                    text_value = text_value .. '  ' .. tostring(amount);
                end
                add_event('outgoing', 'ability',
                    text_value .. target_suffix(target_name) .. mb_tag .. sata_suffix(), event_type,
                    { amount = amount });
                consume_sata();
            end
        elseif HP_DRAIN_MESSAGES[message] then
            add_event('outgoing', 'ability',
                display_name .. '  +' .. tostring(amount) .. ' HP' .. target_suffix(target_name) .. mb_tag, event_type);
        elseif MP_DRAIN_MESSAGES[message] then
            add_event('outgoing', 'ability',
                display_name .. '  +' .. tostring(amount) .. ' MP' .. target_suffix(target_name) .. mb_tag, event_type);
        elseif HEAL_MESSAGES[message] then
            session.record_heal_done(amount, display_name, target_name);
            add_event('outgoing', 'ability',
                display_name .. '  +' .. tostring(amount) .. ' HP' .. target_suffix(target_name), event_type);
        else
            local status = status_text(action);
            local suffix = (status and status ~= display_name) and ('  (' .. status .. ')') or '';
            add_event('outgoing', 'ability', display_name .. target_suffix(target_name) .. suffix, event_type);
        end

        emit_skillchain(action, target_name);
        emit_additional_effect(action, true, target_name);
        return;
    end

    if act.category == 4 then
        if HEAL_MESSAGES[message] then
            session.record_heal_done(amount, display_name, target_name);
            add_event('outgoing', 'ability',
                display_name .. '  ' .. tostring(amount) .. target_suffix(target_name), 'spells');
        elseif MP_RECOVER_MESSAGES[message] then
            add_event('outgoing', 'ability',
                display_name .. '  +' .. tostring(amount) .. ' MP' .. target_suffix(target_name), 'spells');
        elseif HP_DRAIN_MESSAGES[message] then
            -- Drain-type spells (Drain, Bio-style drains, BLU drains) deal
            -- damage too, so they count toward magic damage.
            session.record_damage(amount, 'spell', display_name, target_name);
            add_event('outgoing', 'ability',
                display_name .. '  +' .. tostring(amount) .. ' HP' .. target_suffix(target_name) .. mb_tag,
                'drain_aspir', { element = element });
        elseif MP_DRAIN_MESSAGES[message] then
            add_event('outgoing', 'ability',
                display_name .. '  +' .. tostring(amount) .. ' MP' .. target_suffix(target_name) .. mb_tag,
                'drain_aspir', { element = element });
        elseif DAMAGE_MESSAGES[message] then
            session.record_damage(amount, 'spell', display_name, target_name);
            if not skip_damage_line and (amount > 0 or settings.show_zero_damage == true) then
                add_event('outgoing', 'ability',
                    display_name .. '  ' .. tostring(amount) .. target_suffix(target_name) .. mb_tag,
                    mb_tag ~= '' and 'magic_bursts' or 'spells',
                    { element = element, amount = amount });
            end
        elseif RESIST_MESSAGES[message] then
            add_event('outgoing', 'ability',
                display_name .. target_suffix(target_name) .. '  [RESIST]', 'spells');
        elseif NO_EFFECT_MESSAGES[message] then
            add_event('outgoing', 'ability',
                display_name .. target_suffix(target_name) .. '  [NO EFFECT]', 'spells');
        elseif target_is_me then
            add_event('outgoing', 'ability', display_name .. '  ->  You', 'buffs');
        elseif STATUS_MESSAGES[message] and not POSITIVE_STATUS_MESSAGES[message]
            and not likely_beneficial_status(display_name) then
            -- An enfeeble that stuck.
            local status = status_text(action);
            local extra = (status and status:lower() ~= display_name:lower()) and ('  (' .. status .. ')') or '';
            add_event('outgoing', 'ability',
                display_name .. target_suffix(target_name) .. '  [LANDED]' .. extra, 'spells');
        else
            add_event('outgoing', 'ability',
                display_name .. target_suffix(target_name) .. mb_tag,
                mb_tag ~= '' and 'magic_bursts' or 'spells');
        end

        emit_skillchain(action, target_name);
        return;
    end

    -- Job abilities, dances, rune abilities, items.
    local event_type = 'outgoing_abilities';

    if STEAL_SUCCESS[message] or DESPOIL_SUCCESS[message] then
        local item = safe_item_name(amount) or ('Item #' .. tostring(amount));
        add_event('outgoing', 'ability', display_name .. '  ' .. item .. target_suffix(target_name), event_type);
        return;
    elseif MUG_SUCCESS[message] then
        add_event('outgoing', 'ability', display_name .. '  ' .. tostring(amount) .. ' gil' .. target_suffix(target_name), event_type);
        return;
    elseif STEAL_FAIL[message] or MUG_FAIL[message] then
        add_event('outgoing', 'ability', display_name .. '  FAILED' .. target_suffix(target_name), event_type);
        return;
    elseif CHARM_SUCCESS[message] then
        add_event('outgoing', 'ability', 'Charmed' .. target_suffix(target_name), event_type);
        return;
    elseif CHARM_FAIL[message] then
        add_event('outgoing', 'ability', 'Charm FAILED' .. target_suffix(target_name), event_type);
        return;
    elseif RESIST_MESSAGES[message] then
        add_event('outgoing', 'ability', display_name .. target_suffix(target_name) .. '  [RESIST]', event_type);
        return;
    end

    if ACTION_MISS_MESSAGES[message] then
        add_event('outgoing', 'ability', display_name .. '  MISS' .. target_suffix(target_name), event_type);
    elseif DAMAGE_MESSAGES[message] then
        session.record_damage(amount, 'ability', display_name, target_name);
        if not skip_damage_line then
            local text_value = display_name;
            if amount > 0 or settings.show_zero_damage == true then
                text_value = text_value .. '  ' .. tostring(amount);
            end
            add_event('outgoing', 'ability', text_value .. target_suffix(target_name) .. mb_tag, event_type,
                { amount = amount });
        end
    elseif HEAL_MESSAGES[message] then
        session.record_heal_done(amount, display_name, target_name);
        add_event('outgoing', 'ability',
            display_name .. '  +' .. tostring(amount) .. ' HP' .. target_suffix(target_name), event_type);
    elseif HP_DRAIN_MESSAGES[message] then
        add_event('outgoing', 'ability',
            display_name .. '  +' .. tostring(amount) .. ' HP' .. target_suffix(target_name), 'drain_aspir');
    elseif MP_DRAIN_MESSAGES[message] then
        add_event('outgoing', 'ability',
            display_name .. '  +' .. tostring(amount) .. ' MP' .. target_suffix(target_name), 'drain_aspir');
    elseif NO_EFFECT_MESSAGES[message] then
        add_event('outgoing', 'ability',
            display_name .. target_suffix(target_name) .. '  [NO EFFECT]', event_type);
    else
        local status = status_text(action);
        local suffix = (status and status ~= display_name) and ('  (' .. status .. ')') or '';
        add_event('outgoing', 'ability', display_name .. target_suffix(target_name) .. suffix, event_type);
    end

    emit_additional_effect(action, true, target_name);
end

-- Spell / weapon skill / ability / item / TP move performed by someone else
-- that landed on the player.
local function emit_incoming_finish(act, action, actor_name, display_name)
    local message = tonumber(action.message) or -1;
    local amount = tonumber(action.param) or 0;
    local mb_tag = MAGIC_BURST_MESSAGES[message] and ' [MB]' or '';
    local element = act.category == 4 and safe_spell_element(act.param) or nil;

    -- Raise / Arise cast on you (the offer menu appears in game).
    if act.category == 4 and (display_name:match('^Raise') or display_name:match('^Arise')) then
        add_event('incoming', 'ability',
            'RAISE OFFERED  ' .. display_name .. source_suffix(actor_name), 'status_positive');
        return;
    end

    if HEAL_MESSAGES[message] then
        session.record_heal_taken(amount, display_name, actor_name);
        if amount > 0 then
            add_event('incoming', 'heal',
                '+' .. tostring(amount) .. ' HP  <-  ' .. display_name, 'healing_received');
        end
        return;
    end

    if MP_RECOVER_MESSAGES[message] then
        if amount > 0 then
            add_event('incoming', 'heal',
                '+' .. tostring(amount) .. ' MP  <-  ' .. display_name, 'mp_recovery');
        end
        return;
    end

    if HP_DRAIN_MESSAGES[message] then
        session.record_hit_taken(amount, display_name, actor_name);
        add_event('incoming', 'ability',
            display_name .. '  -' .. tostring(amount) .. ' HP' .. source_suffix(actor_name) .. mb_tag,
            'incoming_abilities');
        return;
    end

    if MP_DRAIN_MESSAGES[message] then
        add_event('incoming', 'ability',
            display_name .. '  -' .. tostring(amount) .. ' MP' .. source_suffix(actor_name) .. mb_tag,
            'incoming_abilities');
        return;
    end

    if DAMAGE_MESSAGES[message] and amount == 0 and has_stoneskin() then
        add_event('incoming', 'miss',
            'STONESKIN absorbed  ' .. display_name .. source_suffix(actor_name), 'defenses');
        return;
    end

    if DAMAGE_MESSAGES[message] then
        session.record_hit_taken(amount, display_name, actor_name);
        if amount > 0 or settings.show_zero_damage == true then
            local prefix = act.category == 4 and '[SP] ' or '';
            add_event('incoming', 'ability',
                prefix .. display_name .. '  -' .. tostring(amount) .. source_suffix(actor_name) .. mb_tag,
                'incoming_abilities', { element = element });
        end
        return;
    end

    if ACTION_MISS_MESSAGES[message] then
        add_event('incoming', 'miss',
            'EVADE  ' .. display_name .. source_suffix(actor_name), 'defenses');
        return;
    end

    if message == 31 then
        add_event('incoming', 'miss',
            tostring(amount) .. ' absorbed  ' .. display_name .. source_suffix(actor_name),
            'defenses', { symbol = '[SHADOW] ' });
        return;
    end

    if RESIST_MESSAGES[message] then
        -- You resisted it: shown as a defense.
        add_event('incoming', 'miss',
            'RESIST  ' .. display_name .. source_suffix(actor_name), 'defenses');
        return;
    end

    if NO_EFFECT_MESSAGES[message] then
        if settings.show_zero_damage == true then
            add_event('incoming', 'ability',
                display_name .. source_suffix(actor_name) .. '  [NO EFFECT]', 'status_negative');
        end
        return;
    end

    local status = status_text(action);
    local positive = POSITIVE_STATUS_MESSAGES[message] == true
        or likely_beneficial_status(display_name)
        or likely_beneficial_status(status);

    local text_value = display_name;
    if status and status:lower() ~= display_name:lower() then
        text_value = status .. '  [' .. display_name .. ']';
    end

    add_event('incoming', 'ability',
        text_value .. source_suffix(actor_name) .. mb_tag,
        positive and 'status_positive' or 'status_negative');
end

-- Actions performed by the player's own pet.
local function emit_pet_action(act, display_name)
    local pet_name = safe_entity_name(act.actor_id);
    for _, target in ipairs(act.targets or {}) do
        local target_name = safe_entity_name(target.server_id);

        for _, action in ipairs(target.actions or {}) do
            local message = tonumber(action.message) or -1;
            local amount = tonumber(action.param) or 0;

            if act.category == 1 or act.category == 2 then
                if MELEE_DAMAGE_MESSAGES[message] then
                    session.record_pet_damage(amount, nil, pet_name, target_name);
                    add_combat_number('outgoing', 'ability', amount, target_name, 'pet_damage', '',
                        'pet:' .. tostring(target.server_id));
                elseif OUTGOING_DEFENSE_LABELS[message] and settings.show_misses == true then
                    add_event('outgoing', 'miss',
                        OUTGOING_DEFENSE_LABELS[message] .. target_suffix(target_name), 'pet_damage');
                end
            else
                local name = display_name or fallback_action_name(act);
                if DAMAGE_MESSAGES[message] then
                    session.record_pet_damage(amount, name, pet_name, target_name);
                    if amount > 0 or settings.show_zero_damage == true then
                        add_event('outgoing', 'ability',
                            name .. '  ' .. tostring(amount) .. target_suffix(target_name), 'pet_damage');
                    end
                elseif HEAL_MESSAGES[message] then
                    add_event('outgoing', 'ability',
                        name .. '  +' .. tostring(amount) .. ' HP' .. target_suffix(target_name), 'pet_damage');
                elseif ACTION_MISS_MESSAGES[message] then
                    add_event('outgoing', 'ability',
                        name .. '  MISS' .. target_suffix(target_name), 'pet_damage');
                else
                    add_event('outgoing', 'ability', name .. target_suffix(target_name), 'pet_damage');
                end
            end
        end
    end
end

-- ----------------------------------------------------------------------------
-- /scl debug: messages SCL classifies. Anything else involving the player is
-- written to the debug log so HorizonXI-specific IDs can be mapped.
-- ----------------------------------------------------------------------------
local KNOWN_ACTION_MESSAGES = {};
for _, set in ipairs({
    MELEE_DAMAGE_MESSAGES, DAMAGE_MESSAGES, HEAL_MESSAGES, MP_RECOVER_MESSAGES,
    HP_DRAIN_MESSAGES, MP_DRAIN_MESSAGES, ACTION_MISS_MESSAGES, RESIST_MESSAGES,
    NO_EFFECT_MESSAGES, STATUS_MESSAGES, MAGIC_BURST_MESSAGES,
    id_set({ 14, 15, 31, 33, 100, 101, 135, 354, 592 }),
    STEAL_SUCCESS, STEAL_FAIL, MUG_SUCCESS, MUG_FAIL, DESPOIL_SUCCESS, CHARM_SUCCESS, CHARM_FAIL, ROLL_ALL,
}) do
    for id in pairs(set) do KNOWN_ACTION_MESSAGES[id] = true; end
end
for id in pairs(DEFENSE_LABELS) do KNOWN_ACTION_MESSAGES[id] = true; end
for id in pairs(OUTGOING_DEFENSE_LABELS) do KNOWN_ACTION_MESSAGES[id] = true; end

local KNOWN_ADDITIONAL_MESSAGES = id_set({ 152, 160, 161, 162, 163, 164, 165, 167, 229, 384, 603 });
for id in pairs(SKILLCHAIN_MESSAGES) do KNOWN_ADDITIONAL_MESSAGES[id] = true; end
local KNOWN_SPIKES_MESSAGES = id_set({ 14, 33, 44, 132, 383, 535, 536, 592 });

local function debug_check_action(act, action, display_name, actor_name, target_name)
    if not debuglog.enabled() then return end

    local message = tonumber(action.message) or -1;
    local base = ('cat=%d actor=%s target=%s action=%s(%s) msg=%d param=%d'):fmt(
        tonumber(act.category) or -1, tostring(actor_name), tostring(target_name),
        tostring(display_name or '-'), tostring(act.param), message, tonumber(action.param) or 0);

    if not KNOWN_ACTION_MESSAGES[message] then
        debuglog.report('act:' .. tostring(act.category) .. ':' .. message,
            ('unmapped action message %d (category %d, %s)'):fmt(message, tonumber(act.category) or -1, tostring(display_name or '-')),
            'ACTION ' .. base);
    end

    local add = action.additional;
    if add and not KNOWN_ADDITIONAL_MESSAGES[tonumber(add.message) or -1] then
        debuglog.report('add:' .. tostring(add.message),
            ('unmapped additional-effect message %s'):fmt(tostring(add.message)),
            ('ADDITIONAL %s add_msg=%s add_param=%s add_anim=%s'):fmt(base, tostring(add.message), tostring(add.param), tostring(add.animation)));
    end

    local spikes = action.spikes;
    if spikes and not KNOWN_SPIKES_MESSAGES[tonumber(spikes.message) or -1] then
        debuglog.report('spk:' .. tostring(spikes.message),
            ('unmapped spikes message %s'):fmt(tostring(spikes.message)),
            ('SPIKES %s spk_msg=%s spk_param=%s'):fmt(base, tostring(spikes.message), tostring(spikes.param)));
    end
end

-- AoE: the player's single action that damaged two or more targets is shown
-- as one combined line ("Firaga III  1840 (4 targets)").
local AOE_CATEGORIES = id_set({ 3, 4, 5, 6, 14, 15 });

local function aoe_summary(act, self_id)
    if settings.combine_aoe ~= true or not AOE_CATEGORIES[act.category] then
        return nil;
    end

    local total, count, mb = 0, 0, false;
    for _, target in ipairs(act.targets or {}) do
        if tonumber(target.server_id) ~= tonumber(self_id) then
            for _, action in ipairs(target.actions or {}) do
                local message = tonumber(action.message) or -1;
                if DAMAGE_MESSAGES[message] then
                    total = total + (tonumber(action.param) or 0);
                    count = count + 1;
                    if MAGIC_BURST_MESSAGES[message] then mb = true; end
                end
            end
        end
    end

    if count < 2 then
        return nil;
    end
    return { total = total, count = count, mb = mb };
end

local function emit_aoe_summary(act, summary, display_name)
    local event_type = 'outgoing_abilities';
    local element = nil;
    local suffix = '';

    if act.category == 3 and not act.is_ja then
        event_type = 'weapon_skills';
        suffix = sata_suffix();
        consume_sata();
    elseif act.category == 4 then
        event_type = summary.mb and 'magic_bursts' or 'spells';
        element = safe_spell_element(act.param);
    end

    add_event('outgoing', 'ability',
        ('%s  %d (%d targets)%s%s'):fmt(display_name, summary.total, summary.count,
            summary.mb and ' [MB]' or '', suffix),
        event_type, { element = element, amount = summary.total });
end

local function emit_self_action(act)
    local self_id = safe_player_server_id();
    if not self_id or not act then
        return;
    end

    -- Compliance guard (see START_CATEGORIES). The packet handler already
    -- discards these; this keeps any future caller from displaying them.
    if START_CATEGORIES[act.category] or not FINISH_CATEGORIES[act.category] then
        return;
    end

    act.is_ja = is_cat3_ability(act);

    local actor_id = tonumber(act.actor_id);
    local actor_is_me = actor_id == tonumber(self_id);
    local pet_id = safe_pet_server_id();
    local actor_is_pet = pet_id ~= nil and actor_id == tonumber(pet_id);
    local is_melee = act.category == 1 or act.category == 2;
    local resolved_name = (not is_melee) and action_name(act) or nil;
    local display_name = resolved_name or fallback_action_name(act);

    if actor_is_pet then
        emit_pet_action(act, resolved_name);
        return;
    end

    -- Sneak Attack / Trick Attack: the tag rides on the next melee hit or
    -- weapon skill, and is spent by a miss.
    if actor_is_me and act.category == 6 and resolved_name then
        if resolved_name == 'Sneak Attack' then
            state.sata.sneak = true;
        elseif resolved_name == 'Trick Attack' then
            state.sata.trick = true;
        end
    end

    -- Phantom Roll / Double-Up: one line with the total, LUCKY / BUST tags.
    if actor_is_me and act.category == 6 then
        local first = act.targets and act.targets[1] and act.targets[1].actions and act.targets[1].actions[1];
        local message = first and tonumber(first.message) or -1;
        if ROLL_ALL[message] then
            if resolved_name and ROLL_NUMBERS[resolved_name] then
                state.last_roll = resolved_name;
            end
            local roll = state.last_roll or resolved_name or 'Roll';
            local total = tonumber(first.param) or 0;
            local text;
            if ROLL_BUST[message] then
                text = roll .. '  BUST';
            elseif ROLL_FAIL[message] then
                text = (resolved_name or roll) .. '  [NO EFFECT]';
            else
                local nums = ROLL_NUMBERS[roll];
                local tag = '';
                if total == 11 then tag = '  [11!]';
                elseif nums and total == nums[1] then tag = '  [LUCKY]';
                elseif nums and total == nums[2] then tag = '  [UNLUCKY]'; end
                local prefix = (resolved_name == 'Double-Up') and 'Double-Up: ' or '';
                text = prefix .. roll .. '  ' .. tostring(total) .. tag;
            end
            add_event('outgoing', 'ability', text, 'outgoing_abilities');
            return;
        end
    end

    local actor_name = nil;
    local aoe = (actor_is_me and not is_melee) and aoe_summary(act, self_id) or nil;

    for _, target in ipairs(act.targets or {}) do
        local target_id = tonumber(target.server_id);
        local target_is_me = target_id == tonumber(self_id);

        -- Strict self-only rule: either we performed the action or it targeted us.
        if actor_is_me or target_is_me then
            local target_name = target_is_me and 'You' or safe_entity_name(target_id);
            if actor_name == nil then
                actor_name = actor_is_me and 'You' or safe_entity_name(actor_id);
            end

            for _, action in ipairs(target.actions or {}) do
                debug_check_action(act, action, (not is_melee) and display_name or nil, actor_name, target_name);

                if is_melee then
                    emit_melee(act, action, actor_is_me, target_is_me, actor_name, target_name, target_id);
                elseif actor_is_me then
                    emit_own_finish(act, action, target_is_me, target_name, display_name, aoe ~= nil);
                else
                    emit_incoming_finish(act, action, actor_name, display_name);
                end
            end
        end
    end

    if aoe then
        emit_aoe_summary(act, aoe, display_name);
    end
end

-- Your own spell was interrupted (after the fact). Category 8 packets are
-- otherwise "starts casting" and are never shown; only the interruption code
-- of your own cast is read here.
local function handle_own_interrupt(e)
    local ok, act = pcall(parse_action_packet, e);
    if not ok or not act or tonumber(act.param) ~= CAST_INTERRUPTED then
        return;
    end
    local self_id = safe_player_server_id();
    if not self_id or tonumber(act.actor_id) ~= tonumber(self_id) then
        return;
    end
    local first = act.targets and act.targets[1] and act.targets[1].actions and act.targets[1].actions[1];
    local spell = first and safe_spell_name(tonumber(first.param) or 0) or nil;
    add_event('outgoing', 'miss', 'INTERRUPTED' .. (spell and ('  ' .. spell) or ''), 'spells');
end

-- 0x028 action packet entry point.
local function handle_action_packet(e)
    -- HorizonXI compliance: discard "readies" / "starts casting" /
    -- "starts using" / "starts aiming" packets immediately.
    local category = peek_action_category(e);
    if category == 8 then
        pcall(handle_own_interrupt, e);
        return;
    end
    if category == nil or START_CATEGORIES[category] or not FINISH_CATEGORIES[category] then
        return;
    end

    local ok, act = pcall(parse_action_packet, e);
    if not ok or not act then
        return;
    end

    -- Never allow one unexpected combat packet to unload the addon.
    pcall(emit_self_action, act);
end

return {
    handle_action_packet = handle_action_packet,
    START_CATEGORIES = START_CATEGORIES,
    FINISH_CATEGORIES = FINISH_CATEGORIES,
    SKILLCHAIN_MESSAGES = SKILLCHAIN_MESSAGES,
};
