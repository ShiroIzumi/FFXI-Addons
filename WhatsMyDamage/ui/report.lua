--[[
    WhatsMyDamage - ui/report.lua

    Report to chat: a small window (from the speech-bubble icon or
    /wmd report) where you pick the channel, how many lines and which
    numbers, with a preview of exactly what will be said. Nothing is sent
    until you press Send; the lines then go out about one second apart so
    the game's spam filter doesn't eat them.

      WMD Damage Done - 3m 05s - 45,210 total - Acc 90.4%
      1. Izumi 12,345 (27.3%) Acc 91.2%
      2. Kotorfan 9,876 (21.8%) Acc 88.0%

    Damage Done reports add the overall accuracy (each player's, and the
    party's in the title line); it can be turned off.
]]

require('common');
local imgui = require('imgui');
local theme = require('core.theme');
local uifont = require('uifont');
local data = require('core.data');
local tracker = require('core.tracker');

local report = {
    open_flag = { false },
    mode = 'damage',
    pos = nil,
    queue = {},
    next_send = 0,
};

report.CHANNELS = {
    { key = 'p', label = 'Party', cmd = '/p' },
    { key = 'l', label = 'Linkshell', cmd = '/l' },
    { key = 'l2', label = 'Linkshell 2', cmd = '/l2' },
    { key = 's', label = 'Say', cmd = '/s' },
    { key = 'echo', label = 'Just me', cmd = '/echo' },
};

local function commas(n)
    local s = tostring(math.floor((tonumber(n) or 0) + 0.5));
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse();
    if out:sub(1, 1) == ',' then out = out:sub(2); end
    return out;
end

function report.open(mode, x, y)
    report.mode = mode or 'damage';
    report.pos = (x ~= nil and y ~= nil) and { x - 40, y + 16 } or nil;
    report.open_flag[1] = true;
end

-- Accuracy over the sources that can miss (not skillchains, additional
-- effects, spikes / counters): landed / (landed + missed + avoided + resisted).
local NO_ACC = { sc = true, add = true, spikes = true };
local function add_acc(acc, stat)
    for _, c in pairs(stat.cats) do
        if not NO_ACC[c.group] then
            acc.hits = acc.hits + c.hits;
            acc.tries = acc.tries + c.hits + c.misses + c.avoided + c.resisted;
        end
    end
end
local function acc_text(acc)
    if acc.tries <= 0 then return nil; end
    return ('%.1f%%'):format(acc.hits * 100 / acc.tries);
end

-- The lines that would be sent.
function report.lines(cfg, mode)
    local rc = cfg.report;
    local rows, total = tracker.rows(mode, { combine = cfg.combine_pets ~= false, alliance = cfg.alliance == true });
    local secs = tracker.elapsed();
    local out = {};
    out[1] = ('WMD %s - %dm %02ds - %s total'):format(data.MODE_LABEL[mode] or mode, math.floor(secs / 60), secs % 60, commas(total));
    -- Damage Done: overall accuracy, for the party in the title and for each
    -- player (with their combined pets) on their line.
    local with_acc = mode == 'damage' and rc.show_acc ~= false;
    if with_acc then
        local party = { hits = 0, tries = 0 };
        for _, r in ipairs(rows) do
            add_acc(party, r.a.damage);
            for _, p in ipairs(r.pets or {}) do add_acc(party, p.damage); end
        end
        local t = acc_text(party);
        if t ~= nil then out[1] = out[1] .. ' - Acc ' .. t; end
    end
    local n = math.max(1, math.floor(tonumber(rc.lines) or 5));
    for i = 1, math.min(n, #rows) do
        local r = rows[i];
        local name = tostring(r.name);
        if r.pet then name = name .. ' (' .. tostring(r.owner_name) .. ')'; end
        local line = ('%d. %s %s (%.1f%%)'):format(i, name, commas(r.value), r.pct);
        if rc.show_job and r.job and r.job ~= '' and not r.pet then line = ('%d. %s [%s] %s (%.1f%%)'):format(i, name, r.job, commas(r.value), r.pct); end
        if with_acc then
            local acc = { hits = 0, tries = 0 };
            add_acc(acc, r.a.damage);
            for _, p in ipairs(r.pets or {}) do add_acc(acc, p.damage); end
            local t = acc_text(acc);
            if t ~= nil then line = line .. ' Acc ' .. t; end
        end
        out[#out + 1] = line;
    end
    if #rows == 0 then out[#out + 1] = 'No data yet.'; end
    return out;
end

local function channel_cmd(key)
    for _, c in ipairs(report.CHANNELS) do
        if c.key == key then return c.cmd; end
    end
    return '/p';
end

function report.send(cfg, mode, channel)
    local cmd = channel_cmd(channel or cfg.report.channel);
    for _, line in ipairs(report.lines(cfg, mode or report.mode)) do
        report.queue[#report.queue + 1] = cmd .. ' ' .. line;
    end
end

-- Sends queued lines one at a time (call every frame).
function report.tick()
    if #report.queue == 0 then return; end
    local now = os.clock();
    if now < report.next_send then return; end
    local line = table.remove(report.queue, 1);
    pcall(function() AshitaCore:GetChatManager():QueueCommand(1, line); end);
    report.next_send = now + 1.1;
end

-- 1.1.0: a window's background (its own opacity when it has one).
local function look_bg(look)
    if look ~= nil and look.own_alpha then return theme.background(tonumber(look.alpha) or 0.97); end
    return theme.background();
end

function report.draw(cfg, ctx)
    if not report.open_flag[1] then return; end
    local rc = cfg.report;
    local look = cfg.look and cfg.look.report or {};
    local s = tonumber(look.scale) or tonumber(cfg.config_scale) or 1;
    if report.pos ~= nil then
        imgui.SetNextWindowPos(report.pos);
        report.pos = nil;
    end
    theme.push(look_bg(look), s, { border = true });
    uifont.push(s);
    local flags = bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoCollapse or 0, ImGuiWindowFlags_NoSavedSettings or 0, ImGuiWindowFlags_NoNav or 0);
    if imgui.Begin('Report to chat##wmd_report', report.open_flag, flags) then
        local ok, err = pcall(function()
            theme.align_label();
            imgui.TextColored(theme.UI_MUTED, 'What');
            imgui.SameLine(80 * s);
            local opts = {};
            for _, m in ipairs(data.MODES) do opts[#opts + 1] = { key = m.key, label = m.label }; end
            report.mode = theme.choice('wmd_rep_mode', report.mode, opts);

            theme.align_label();
            imgui.TextColored(theme.UI_MUTED, 'Where');
            imgui.SameLine(80 * s);
            local ch = theme.choice('wmd_rep_ch', rc.channel, report.CHANNELS);
            if ch ~= rc.channel then rc.channel = ch; ctx.dirty(); end

            theme.align_label();
            imgui.TextColored(theme.UI_MUTED, 'Lines');
            imgui.SameLine(80 * s);
            imgui.PushItemWidth(180 * s);
            local v = { math.floor(tonumber(rc.lines) or 5) };
            if imgui.SliderInt('##wmd_rep_lines', v, 1, 18) then rc.lines = v[1]; ctx.dirty(); end
            imgui.PopItemWidth();
            imgui.SameLine();
            local j = { rc.show_job == true };
            if imgui.Checkbox('Jobs##wmd_rep_job', j) then rc.show_job = j[1]; ctx.dirty(); end
            imgui.SameLine();
            local ac = { rc.show_acc ~= false };
            if imgui.Checkbox('Accuracy##wmd_rep_acc', ac) then rc.show_acc = ac[1]; ctx.dirty(); end
            theme.tip('Damage Done reports add each player\'s overall accuracy (and the party\'s in the title line).');

            theme.section_header('PREVIEW');
            local cmd = channel_cmd(rc.channel);
            for _, line in ipairs(report.lines(cfg, report.mode)) do
                imgui.TextColored(theme.UI_MUTED, cmd);
                imgui.SameLine();
                imgui.TextColored(theme.UI_TEXT, line);
            end
            imgui.Spacing();
            local busy = #report.queue > 0;
            if busy then
                imgui.TextColored(theme.UI_WARN, ('Sending... %d line(s) left'):format(#report.queue));
                imgui.SameLine();
                if imgui.SmallButton('Stop##wmd_rep_stop') then report.queue = {}; end
            else
                if imgui.Button('Send##wmd_rep_send', { 120 * s, 0 }) then
                    report.send(cfg, report.mode, rc.channel);
                    if rc.close_after ~= false then report.open_flag[1] = false; end
                end
                imgui.SameLine();
                if imgui.Button('Close##wmd_rep_close', { 90 * s, 0 }) then report.open_flag[1] = false; end
            end
        end);
        if not ok then ctx.error('report window', err); end
    end
    imgui.End();
    uifont.pop();
    theme.pop();
end

return report;
