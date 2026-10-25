--[[
    WhatsMyDamage - ui/newparty.lua

    Notices when you join a new party and, if the meters have numbers in
    them, asks whether to reset them:

        New party
        You joined a new party. Reset the meters?
        (now: 45,210 damage, 12m 30s)
        [ Reset ]  [ Keep ]
        Next time:  Ask | Always reset | Always keep

    "A new party" means: you were on your own (for at least 5 seconds, so
    zoning blips don't count) and now have party members, or every member
    you see is someone who wasn't in your party before (you switched
    parties). Someone joining the party you're already in does not count.

    Setting new_party: 'ask' (default) | 'reset' | 'keep'. The question goes
    away by itself after a minute (keeps the numbers).
]]

require('common');
local imgui = require('imgui');
local theme = require('core.theme');
local roster = require('core.roster');
local tracker = require('core.tracker');

local newparty = {
    open_flag = { false },
    opened_at = 0,
    prev = nil,          -- names of the other members last seen (set)
    solo_since = nil,
    pos = nil,
};

local SOLO_GRACE = 5.0;     -- seconds alone before it counts as "left the party"
local AUTO_CLOSE = 60.0;

local function commas(n)
    local s = tostring(math.floor((tonumber(n) or 0) + 0.5));
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse();
    if out:sub(1, 1) == ',' then out = out:sub(2); end
    return out;
end

-- Other members of your own party (slots 1-5), by name.
local function others()
    local set, n = {}, 0;
    for _, m in pairs(roster.members) do
        if m.slot ~= nil and m.slot >= 1 and m.slot <= 5 and m.name ~= nil then
            set[m.name] = true;
            n = n + 1;
        end
    end
    return set, n;
end

-- Is there anything to reset?
local function has_data()
    for _, a in pairs(tracker.real.actors) do
        if a.damage.total > 0 or a.heal.total > 0 or a.taken.total > 0 then return true; end
    end
    return false;
end

local function party_total()
    local t = 0;
    for _, a in pairs(tracker.real.actors) do t = t + a.damage.total; end
    return t;
end

-- Call every frame while logged in (after roster.update).
function newparty.check(cfg, ctx)
    local now = os.clock();
    local set, n = others();
    if newparty.prev == nil then
        newparty.prev = set;      -- first look after loading: nothing to compare
        return;
    end
    if n == 0 then
        newparty.solo_since = newparty.solo_since or now;
        if now - newparty.solo_since >= SOLO_GRACE then newparty.prev = {}; end
        return;
    end
    newparty.solo_since = nil;

    local was_solo = next(newparty.prev) == nil;
    local overlap = false;
    for name in pairs(set) do
        if newparty.prev[name] then overlap = true; break; end
    end
    newparty.prev = set;
    if not was_solo and overlap then return; end   -- same party, someone joined / left

    -- A new party.
    if tracker.test or not has_data() then return; end
    local what = cfg.new_party or 'ask';
    if what == 'reset' then
        tracker.reset();
        ctx.say('New party: meters reset.');
    elseif what == 'ask' then
        newparty.open_flag[1] = true;
        newparty.opened_at = now;
        newparty.pos = nil;
    end
end

local CHOICES = {
    { key = 'ask', label = 'Ask', tip = 'Ask every time you join a new party.' },
    { key = 'reset', label = 'Always reset', tip = 'Reset the meters without asking.' },
    { key = 'keep', label = 'Always keep', tip = 'Never reset; don\'t ask.' },
};

function newparty.draw(cfg, ctx, meter_rect)
    if not newparty.open_flag[1] then return; end
    if os.clock() - newparty.opened_at > AUTO_CLOSE then
        newparty.open_flag[1] = false;
        return;
    end
    local s = tonumber(cfg.config_scale) or 1;
    -- Show it right above the first meter (or near the middle of the screen).
    if newparty.pos == nil then
        if meter_rect ~= nil then
            newparty.pos = { meter_rect.x, math.max(10, meter_rect.y - 130 * s) };
        else
            local dw, dh = 1280, 720;
            pcall(function() dw, dh = imgui.GetIO().DisplaySize.x, imgui.GetIO().DisplaySize.y; end);
            newparty.pos = { dw / 2 - 170 * s, dh / 3 };
        end
        imgui.SetNextWindowPos(newparty.pos);
    end
    theme.push(nil, s, { border = true });
    imgui.PushFont(nil, imgui.GetFontSize() * s);
    local flags = bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoCollapse or 0,
        ImGuiWindowFlags_NoSavedSettings or 0, ImGuiWindowFlags_NoFocusOnAppearing or 0);
    if imgui.Begin('New party##wmd_newparty', newparty.open_flag, flags) then
        local ok, err = pcall(function()
            imgui.TextColored(theme.UI_ACCENT_TEXT, 'You joined a new party.');
            imgui.Text('Reset the meters?');
            local secs = tracker.elapsed();
            imgui.TextColored(theme.UI_MUTED, ('Now: %s damage, %dm %02ds'):format(commas(party_total()), math.floor(secs / 60), secs % 60));
            imgui.Spacing();
            if theme.toggle_button('Reset', 'wmd_np_reset', true, { 110 * s, 0 }) then
                tracker.reset();
                newparty.open_flag[1] = false;
                ctx.say('Meters reset for the new party.');
            end
            imgui.SameLine();
            if imgui.Button('Keep##wmd_np_keep', { 110 * s, 0 }) then
                newparty.open_flag[1] = false;
            end
            theme.tip('Keep counting on top of what is there.');
            imgui.Spacing();
            theme.align_label();
            imgui.TextColored(theme.UI_MUTED, 'Next time:');
            imgui.SameLine();
            local new = theme.choice('wmd_np_next', cfg.new_party or 'ask', CHOICES);
            if new ~= (cfg.new_party or 'ask') then
                cfg.new_party = new;
                ctx.dirty();
            end
            local left = math.max(0, math.ceil(AUTO_CLOSE - (os.clock() - newparty.opened_at)));
            imgui.TextColored(theme.with_alpha(theme.UI_MUTED, 0.6), ('Closes in %ds (keeps the numbers).'):format(left));
        end);
        if not ok then ctx.error('new party question', err); end
    end
    imgui.End();
    imgui.PopFont();
    theme.pop();
end

-- Test from the settings window.
function newparty.test()
    newparty.open_flag[1] = true;
    newparty.opened_at = os.clock();
    newparty.pos = nil;
end

return newparty;
