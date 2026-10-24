require('common');
local core_mod = require('scl.core');
local MAX_EVENTS = core_mod.MAX_EVENTS;
local clamp = core_mod.clamp;
local settings = core_mod.settings;
local state = core_mod.state;
local session = require('scl.session');

-- Element colors (FFXI element ids: 0 Fire, 1 Ice, 2 Wind, 3 Earth,
-- 4 Lightning, 5 Water, 6 Light, 7 Dark).
local ELEMENT_COLORS = {
    [0] = { 1.00, 0.46, 0.26, 1.00 },
    [1] = { 0.56, 0.86, 1.00, 1.00 },
    [2] = { 0.46, 0.94, 0.56, 1.00 },
    [3] = { 0.86, 0.72, 0.38, 1.00 },
    [4] = { 0.78, 0.58, 1.00, 1.00 },
    [5] = { 0.38, 0.62, 1.00, 1.00 },
    [6] = { 1.00, 0.97, 0.78, 1.00 },
    [7] = { 0.72, 0.46, 0.86, 1.00 },
};

-- Event types that move to the center Notifications lane when enabled.
local NOTIFY_EVENT_TYPES = {
    level_up = true,
    skillchains = true,
    magic_bursts = true,
    zone_change = true,
    wear_warning = true,
    low_hp = true,
    status_removed = true,
    food_warning = true,
};

local function routes_to_notify(event_type)
    return NOTIFY_EVENT_TYPES[event_type] == true
        and settings.notify ~= nil
        and settings.notify[event_type] == true;
end

local function rgba_to_argb(color, alpha_mul)
    local r = math.floor(clamp((tonumber(color[1]) or 1.0), 0.0, 1.0) * 255);
    local g = math.floor(clamp((tonumber(color[2]) or 1.0), 0.0, 1.0) * 255);
    local b = math.floor(clamp((tonumber(color[3]) or 1.0), 0.0, 1.0) * 255);
    local a = math.floor(clamp((tonumber(color[4]) or 1.0) * (alpha_mul or 1.0), 0.0, 1.0) * 255);

    return bit.bor(
        bit.lshift(a, 24),
        bit.lshift(r, 16),
        bit.lshift(g, 8),
        b
    );
end

local function default_event_type(direction, kind)
    if kind == 'critical' then return 'criticals'; end
    if kind == 'heal' then return 'healing_received'; end
    if kind == 'xp' then return 'exp'; end
    if kind == 'gil' then return 'gil'; end
    if direction == 'incoming' then return 'incoming_damage'; end
    return 'melee_damage';
end

local function get_event_option(event_type)
    if settings.event_options and settings.event_options[event_type] then
        return settings.event_options[event_type];
    end
    return nil;
end

local function event_visible(event_type)
    local opt = get_event_option(event_type);
    return not opt or opt.show ~= false;
end

local function event_color(ev)
    if ev.element ~= nil and settings.element_colors == true then
        local element_color = ELEMENT_COLORS[ev.element];
        if element_color then
            return element_color;
        end
    end

    local opt = get_event_option(ev.event_type);
    if opt and opt.color then
        return opt.color;
    end

    -- Legacy fallback.
    if ev.kind == 'heal' then return settings.colors.heal; end
    if ev.kind == 'xp' then return settings.colors.xp; end
    if ev.kind == 'gil' then return settings.colors.gil; end
    if ev.kind == 'miss' then return settings.colors.miss; end
    if ev.kind == 'ability' then return settings.colors.ability; end
    if ev.kind == 'critical' then return settings.colors.critical; end
    if ev.direction == 'incoming' then return settings.colors.incoming; end
    return settings.colors.outgoing;
end

local function event_symbol(ev)
    if settings.show_symbols ~= true then
        return '';
    end

    -- Per-event symbol override (for example [SHADOW] on a defense event).
    if ev.symbol ~= nil then
        return ev.symbol;
    end

    if ev.event_type == 'criticals' then return '* '; end
    if ev.event_type == 'ranged_damage' then return '[R] '; end
    if ev.event_type == 'weapon_skills' then return '[WS] '; end
    if ev.event_type == 'spells' then return '[SP] '; end
    if ev.event_type == 'magic_bursts' then return '[SP] '; end
    if ev.event_type == 'skillchains' then return '[SC] '; end
    if ev.event_type == 'outgoing_abilities' then return '[JA] '; end
    if ev.event_type == 'pet_damage' then return '[PET] '; end
    if ev.event_type == 'additional_effects' then return '[+] '; end
    if ev.event_type == 'counters' then return '[COUNTER] '; end
    -- Healing and incoming damage text already carries its own +/- sign.
    if ev.event_type == 'healing_received' then return ''; end
    if ev.event_type == 'mp_recovery' then return '[MP] '; end
    -- Resting ticks carry "[REST]" in their own text.
    if ev.event_type == 'resting' then return ''; end
    if ev.event_type == 'regen_ticks' then return ''; end
    if ev.event_type == 'refresh_ticks' then return ''; end
    if ev.event_type == 'drain_aspir' then return '[DRAIN] '; end
    if ev.event_type == 'buffs' then return '[+] '; end
    if ev.event_type == 'status_positive' then return '[+] '; end
    if ev.event_type == 'status_negative' then return '[!] '; end
    if ev.event_type == 'status_removed' then return '[-] '; end
    if ev.event_type == 'food_warning' then return '[!] '; end
    if ev.event_type == 'incoming_damage' then return ''; end
    if ev.event_type == 'incoming_abilities' then return '[!] '; end
    if ev.event_type == 'defenses' then return '[DEF] '; end
    if ev.event_type == 'ko' then return '[KO] '; end
    if ev.event_type == 'low_hp' then return '[!] '; end
    if ev.event_type == 'exp' then return '[XP] '; end
    if ev.event_type == 'gil' then return '$ '; end
    if ev.event_type == 'level_up' then return '[LEVEL] '; end
    if ev.event_type == 'skill_ups' then return '[SKILL] '; end
    if ev.event_type == 'item_drops' then return '[DROP] '; end
    if ev.event_type == 'item_obtained' then return '[OBTAIN] '; end
    return '';
end

local function rendered_event_text(ev)
    return event_symbol(ev) .. tostring(ev.text or '');
end

local function event_scale(ev, age)
    local global_scale = tonumber(settings.font_scale) or 1.35;
    local mult = tonumber(settings.melee_scale) or 1.00;

    if ev.event_type == 'criticals' then
        -- Criticals intentionally use the exact same font size as normal melee.
        -- They are distinguished by the leading * symbol and their own color.
        mult = tonumber(settings.melee_scale) or 1.00;

    elseif ev.event_type == 'weapon_skills'
        or ev.event_type == 'spells'
        or ev.event_type == 'magic_bursts'
        or ev.event_type == 'skillchains'
        or ev.event_type == 'outgoing_abilities'
        or ev.event_type == 'pet_damage'
        or ev.event_type == 'additional_effects'
        or ev.event_type == 'counters'
        or ev.event_type == 'buffs'
        or ev.event_type == 'status_positive'
        or ev.event_type == 'status_negative'
        or ev.event_type == 'status_removed'
        or ev.event_type == 'incoming_abilities'
        or ev.event_type == 'defenses'
        or ev.event_type == 'ko' then
        mult = tonumber(settings.ability_scale) or 1.00;

    elseif ev.event_type == 'healing_received'
        or ev.event_type == 'mp_recovery'
        or ev.event_type == 'resting'
        or ev.event_type == 'regen_ticks'
        or ev.event_type == 'refresh_ticks'
        or ev.event_type == 'drain_aspir' then
        mult = tonumber(settings.heal_scale) or 1.00;

    elseif ev.event_type == 'exp'
        or ev.event_type == 'gil'
        or ev.event_type == 'level_up'
        or ev.event_type == 'skill_ups'
        or ev.event_type == 'item_drops'
        or ev.event_type == 'item_obtained'
        or ev.event_type == 'zone_change' then
        mult = tonumber(settings.reward_scale) or 1.00;
    end

    if ev.lane == 'notify' then
        mult = mult * (tonumber(settings.notify_scale) or 1.30);
    end

    return global_scale * mult;
end

local recent_events = {};
local recent_events_last_cleanup = 0;

-- opts.debounce: only chat-text fallbacks set this. Packet-driven events are
-- never debounced, because two identical hits in a row are two real hits.
local function should_suppress_event(direction, kind, value, debounce, event_type)
    if value == nil or value == '' then
        return true;
    end

    local lower = tostring(value):lower();

    -- Never display Lua userdata / debug-like garbage.
    if lower:find('userdata:', 1, true) then
        return true;
    end

    if debounce ~= true then
        return false;
    end

    local key = direction .. '|' .. kind .. '|' .. tostring(event_type) .. '|' .. tostring(value);
    local now = os.clock();
    local last = recent_events[key];

    recent_events[key] = now;

    if (now - recent_events_last_cleanup) > 2.0 then
        recent_events_last_cleanup = now;
        for k, ts in pairs(recent_events) do
            if (now - ts) > 2.0 then
                recent_events[k] = nil;
            end
        end
    end

    return last ~= nil and (now - last) < 1.0;
end

-- opts (optional):
--   debounce = true   suppress an identical text-fallback event within 1s
--   symbol   = '...'  override the event-type symbol for this one event
local function add_event(direction, kind, text, event_type, opts)
    if state.paused or not settings.enabled then return end

    event_type = event_type or default_event_type(direction, kind);
    if not event_visible(event_type) then return end
    if should_suppress_event(direction, kind, text, opts and opts.debounce, event_type) then return end

    local now = os.clock();
    local lane = routes_to_notify(event_type) and 'notify' or direction;

    -- 1.4.0: the History window keeps the last events of each lane.
    local H = settings.history;
    if H ~= nil and H.enabled ~= false then
        state.history = state.history or { outgoing = {}, incoming = {}, notify = {} };
        local list = state.history[lane];
        if list ~= nil then
            list[#list + 1] = {
                direction = direction, lane = lane, kind = kind, event_type = event_type,
                text = text, element = opts and opts.element or nil, at = os.time(),
            };
            local keep = math.floor(clamp(tonumber(H.size) or 50, 10, 500));
            while #list > keep do table.remove(list, 1); end
            state.history_rev = (state.history_rev or 0) + 1;
        end
    end

    state.events[#state.events + 1] = {
        id = state.next_id,
        direction = direction,
        lane = lane,
        kind = kind,
        event_type = event_type,
        text = text,
        symbol = opts and opts.symbol or nil,
        -- Optional colored parts: { { text, event_type }, ... } (Performance
        -- renderer; Custom Font shows the whole line in the first color).
        segments = opts and opts.segments or nil,
        element = opts and opts.element or nil,
        created = now,
    };
    state.next_id = state.next_id + 1;

    -- Big hits: a copy of large outgoing damage also goes to Notifications.
    local amount = opts and tonumber(opts.amount) or nil;
    local threshold = tonumber(settings.big_hit_threshold) or 0;
    if amount and direction == 'outgoing' and lane ~= 'notify' and threshold > 0
        and amount >= threshold and settings.notify and settings.notify.big_hits == true then
        state.events[#state.events + 1] = {
            id = state.next_id,
            direction = direction,
            lane = 'notify',
            kind = kind,
            event_type = event_type,
            text = 'BIG HIT  ' .. tostring(text),
            symbol = '',
            element = opts and opts.element or nil,
            created = now,
        };
        state.next_id = state.next_id + 1;
    end
    -- The cap applies to each lane on its own, so a burst of outgoing hits
    -- can't push an incoming line (a skill-up, a reward) out before it shows.
    local cap = math.floor(clamp(tonumber(settings.max_visible_events) or 14, 4, MAX_EVENTS));
    local counts = {};
    for _, ev in ipairs(state.events) do
        counts[ev.lane] = (counts[ev.lane] or 0) + 1;
    end
    for lane_key, n in pairs(counts) do
        local i = 1;
        while n > cap and i <= #state.events do
            if state.events[i].lane == lane_key then
                table.remove(state.events, i);
                n = n - 1;
            else
                i = i + 1;
            end
        end
    end
end


-- Rewards can be reported by more than one source (packet, chat text,
-- memory). Each reward kind keeps a short memory of what was shown so the
-- same reward is never displayed twice, while identical rewards from later
-- kills (several seconds apart) still display.
local function add_progression_event(kind, value, event_type)
    if not value or value == '' then
        return;
    end

    -- The " (current/needed)" EXP progress can differ between two reports of
    -- the same reward, so it is left out of the duplicate check.
    local key = kind .. '|' .. tostring(value):gsub(' %(%d[%d,]*/%d[%d,]*%)', '');
    local now = os.clock();
    local last = state.progression_seen[key];

    if last and (now - last) < 1.5 then
        return;
    end

    state.progression_seen[key] = now;

    for k, stamp in pairs(state.progression_seen) do
        if (now - stamp) > 5.0 then
            state.progression_seen[k] = nil;
        end
    end

    -- Session totals count every reward once, even when its line is hidden.
    session.record_reward_text(kind, value);

    add_event('incoming', kind, value, event_type or (kind == 'gil' and 'gil' or 'exp'));
end




local function target_suffix(name)
    if settings.show_target_names == false then
        return '';
    end
    return '  ->  ' .. tostring(name or 'Unknown');
end

local function source_suffix(name)
    if settings.show_source_names == false then
        return '';
    end
    return '  <-  ' .. tostring(name or 'Unknown');
end

local function event_is_active(ev)
    for _, active_event in ipairs(state.events) do
        if active_event == ev then
            return true;
        end
    end
    return false;
end

-- tag: optional trailing text such as ' [BLOCK]' or ' [SA]'.
local function add_combat_number(direction, kind, amount, other_name, event_type, prefix, combine_key, tag)
    amount = tonumber(amount) or 0;
    if amount == 0 and settings.show_zero_damage ~= true then
        return nil;
    end

    tag = tag or '';

    local function compose(value_text)
        if direction == 'incoming' then
            return value_text .. source_suffix(other_name) .. tag;
        end
        return value_text .. target_suffix(other_name) .. tag;
    end

    if settings.combine_repeated_hits == true and combine_key and amount > 0 then
        local now = os.clock();
        local key = direction .. '|' .. tostring(event_type) .. '|' .. tostring(combine_key);
        local slot = state.combine[key];
        local window = clamp(tonumber(settings.combine_window) or 0.22, 0.08, 0.60);

        if slot and (now - slot.time) <= window and slot.event and event_is_active(slot.event) then
            slot.total = slot.total + amount;
            slot.hits = slot.hits + 1;
            slot.time = now;
            slot.event.created = now;
            slot.event.text = compose((prefix or '') .. tostring(slot.total) .. ' (' .. tostring(slot.hits) .. ' hits)');
            return slot.event;
        end

        state.combine[key] = nil;

        local before_id = state.next_id;
        add_event(direction, kind, compose((prefix or '') .. tostring(amount)), event_type, { amount = amount });
        if state.next_id ~= before_id then
            local ev = state.events[#state.events];
            state.combine[key] = {
                event = ev,
                total = amount,
                hits = 1,
                time = now,
            };
            return ev;
        end
        return nil;
    end

    local before_id = state.next_id;
    add_event(direction, kind, compose((prefix or '') .. tostring(amount)), event_type, { amount = amount });
    if state.next_id ~= before_id then
        return state.events[#state.events];
    end
    return nil;
end

return {
    rgba_to_argb = rgba_to_argb,
    default_event_type = default_event_type,
    get_event_option = get_event_option,
    event_visible = event_visible,
    event_color = event_color,
    event_symbol = event_symbol,
    rendered_event_text = rendered_event_text,
    event_scale = event_scale,
    add_event = add_event,
    add_progression_event = add_progression_event,
    target_suffix = target_suffix,
    source_suffix = source_suffix,
    add_combat_number = add_combat_number,
};
