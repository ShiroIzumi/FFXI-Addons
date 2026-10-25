--[[
    SCL - scl/history.lua (1.4.1)

    The History window (/scl history): the last events of each lane, so you
    can look back at what scrolled by.

        +---------------------------------------------------------+
        | HISTORY   [Pause] [Clear] [filter....]   Config   X     |
        | NOTIFICATIONS (top)                                     |
        |   12:41:05  Skillchain: Distortion 412                  |
        +----------------------------+----------------------------+
        | INCOMING (left)            | OUTGOING (right)           |
        |   12:41:06  Goblin hits 34 |   12:41:06  Wasp Sting 210 |
        +----------------------------+----------------------------+

    Same sides as the floating text (Incoming left, Outgoing right,
    Notifications at the top). Lines use the event colors. Newest first.
    50 per lane by default (Config > History).
]]

require('common');
local imgui = require('imgui');
local core_mod = require('scl.core');
local events_mod = require('scl.events');
local theme_mod = require('scl.theme');
local uifont = require('scl.uifont');

local settings = core_mod.settings;
local state = core_mod.state;
local clamp = core_mod.clamp;
local event_color = events_mod.event_color;
local push_theme = theme_mod.push_theme;
local pop_theme = theme_mod.pop_theme;
local UI_ACCENT_TEXT = theme_mod.UI_ACCENT_TEXT;
local UI_MUTED = theme_mod.UI_MUTED;
local UI_TEXT = theme_mod.UI_TEXT;
local UI_CONTROL = theme_mod.UI_CONTROL;
local ui_accent = theme_mod.ui_accent;

local history = {
    open = { false },
    placed = false,
    filter = { '' },
    paused_at = nil,      -- a frozen copy while paused
};

local LANES = {
    notify = { label = 'NOTIFICATIONS', tip = 'Skillchains, magic bursts, level ups, zone changes, warnings, big hits.' },
    incoming = { label = 'INCOMING', tip = 'What happened to you: damage taken, heals, buffs, rewards.' },
    outgoing = { label = 'OUTGOING', tip = 'What you did: hits, weapon skills, spells, abilities.' },
};

function history.toggle()
    history.open[1] = not history.open[1];
    history.placed = false;
    local H = settings.history;
    if H ~= nil then H.visible = history.open[1]; end
    core_mod.save_settings();
end

function history.clear()
    state.history = { outgoing = {}, incoming = {}, notify = {} };
    history.paused_at = nil;
end

local function list_of(lane)
    local src = history.paused_at or state.history or {};
    return src[lane] or {};
end

local function draw_lane(lane, id, height)
    local H = settings.history or {};
    local L = LANES[lane];
    local list = list_of(lane);
    local q = tostring(history.filter[1] or ''):lower();

    -- Header strip.
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    x, y = tonumber(x) or 0, tonumber(y) or 0;
    local avail = tonumber((imgui.GetContentRegionAvail())) or 300;
    local lh = imgui.GetTextLineHeight();
    dl:AddRectFilled({ x, y }, { x + avail, y + lh + 6 }, imgui.GetColorU32(ui_accent(0.14)), 4.0);
    dl:AddRectFilled({ x, y + lh + 4 }, { x + avail, y + lh + 6 }, imgui.GetColorU32(ui_accent(0.55)), 0.0);
    dl:AddText({ x + 8, y + 3 }, imgui.GetColorU32(UI_ACCENT_TEXT), L.label);
    local count = tostring(#list);
    dl:AddText({ x + 8 + (tonumber((imgui.CalcTextSize(L.label))) or 0) + 8, y + 3 }, imgui.GetColorU32(UI_MUTED), count);
    imgui.Dummy({ avail, lh + 8 });
    if imgui.IsItemHovered() then imgui.SetTooltip(L.tip); end

    imgui.BeginChild('##scl_hist_' .. id, { 0, height }, 0);
    if #list == 0 then
        imgui.TextDisabled('Nothing yet.');
    end
    local first, last, step = #list, 1, -1;
    if H.newest_first == false then first, last, step = 1, #list, 1; end
    local shown = 0;
    for i = first, last, step do
        local ev = list[i];
        local text = tostring(ev.text or '');
        if q == '' or text:lower():find(q, 1, true) then
            shown = shown + 1;
            if H.show_time ~= false then
                imgui.TextColored(UI_MUTED, os.date('%H:%M:%S', ev.at or os.time()));
                imgui.SameLine(0, 8);
            end
            local ok, col = pcall(event_color, ev);
            imgui.TextColored((ok and col) or UI_TEXT, text);
            if imgui.IsItemHovered() then
                imgui.SetTooltip(('%s\n%s  -  %s'):fmt(text, tostring(ev.event_type or ''):gsub('_', ' '),
                    os.date('%H:%M:%S', ev.at or os.time())));
            end
        end
    end
    if q ~= '' and shown == 0 and #list > 0 then imgui.TextDisabled('Nothing matches the filter.'); end
    imgui.EndChild();
end

function history.draw()
    local H = settings.history;
    if H == nil then return; end
    if not history.open[1] and H.visible == true and not history.loaded then
        history.open[1] = true;
    end
    history.loaded = true;
    if not history.open[1] then return; end

    if not history.placed then
        local w, h = tonumber(H.w) or 820, tonumber(H.h) or 560;
        local x, y = tonumber(H.x) or -1, tonumber(H.y) or -1;
        if x < 0 or y < 0 then
            local io = imgui.GetIO();
            local dw = io and io.DisplaySize and tonumber(io.DisplaySize.x) or 1920;
            local dh = io and io.DisplaySize and tonumber(io.DisplaySize.y) or 1080;
            x, y = math.max(0, (dw - w) / 2), math.max(0, (dh - h) / 3);
        end
        imgui.SetNextWindowPos({ x, y });
        imgui.SetNextWindowSize({ w, h });
        history.placed = true;
    end
    imgui.SetNextWindowSizeConstraints({ 420, 300 }, { 4000, 4000 });

    -- 1.6.0: its own opacity (on by default, as before), or the shared one.
    push_theme();
    local BG = theme_mod.UI_BG;
    local hist_alpha = (H.own_alpha ~= false) and clamp(tonumber(H.opacity) or 0.92, 0.10, 1.00) or BG[4];
    imgui.PushStyleColor(ImGuiCol_WindowBg, { BG[1], BG[2], BG[3], hist_alpha });
    uifont.push(1.0);
    if imgui.Begin('SCL History##scl_history', history.open, bit.bor(ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoCollapse or 0)) then
        -- 1.4.1: text size of the window contents (Config > History).
        uifont.push(clamp(tonumber(H.font_scale) or 1.0, 0.60, 2.50));
        -- Toolbar.
        imgui.TextColored(UI_ACCENT_TEXT, 'COMBAT HISTORY');
        imgui.SameLine();
        imgui.TextColored(UI_MUTED, ('last %d per side'):fmt(math.floor(tonumber(H.size) or 50)));
        imgui.SameLine(0, 16);
        local paused = history.paused_at ~= nil;
        if theme_mod.draw_toggle_button(paused and 'Paused' or 'Pause', 'scl_hist_pause', paused) then
            if paused then
                history.paused_at = nil;
            else
                local copy = {};
                for lane, list in pairs(state.history or {}) do
                    copy[lane] = {};
                    for i, e in ipairs(list) do copy[lane][i] = e; end
                end
                history.paused_at = copy;
            end
        end
        if imgui.IsItemHovered() then imgui.SetTooltip('Freeze the lists while you read them (new events are still kept).'); end
        imgui.SameLine(0, 4);
        if imgui.Button('Clear##scl_hist_clear') then history.clear(); end
        if imgui.IsItemHovered() then imgui.SetTooltip('Empty all three lists.'); end
        imgui.SameLine(0, 12);
        imgui.PushItemWidth(180);
        imgui.InputText('##scl_hist_filter', history.filter, 64);
        imgui.PopItemWidth();
        if (history.filter[1] or '') == '' and not imgui.IsItemActive() then
            local x1, y1 = imgui.GetItemRectMin();
            if x1 ~= nil then
                imgui.GetWindowDrawList():AddText({ tonumber(x1) + 6, tonumber(y1) + 3 }, imgui.GetColorU32(UI_MUTED), 'Filter...');
            end
        end
        if imgui.IsItemHovered() and not imgui.IsItemActive() then imgui.SetTooltip('Only lines with this text (all three sides).'); end
        imgui.SameLine(0, 12);
        if imgui.Button('Config##scl_hist_cfg') then
            state.config_open[1] = not state.config_open[1];
        end

        if H.enabled == false then
            imgui.TextColored({ 1.00, 0.70, 0.30, 1.00 }, 'History is off (Config > History). Nothing new is kept.');
        end

        -- Layout: Notifications on top (full width), Incoming left, Outgoing right.
        local _, avail_h = imgui.GetContentRegionAvail();
        avail_h = tonumber(avail_h) or 400;
        local lh = imgui.GetTextLineHeight();
        local top_h = math.max(lh * 3, avail_h * clamp(tonumber(H.notify_height) or 0.28, 0.10, 0.60)) - (lh + 10);
        draw_lane('notify', 'notify', top_h);
        imgui.Spacing();

        local _, rest_h = imgui.GetContentRegionAvail();
        rest_h = (tonumber(rest_h) or 300) - (lh + 10);
        local avail_w = tonumber((imgui.GetContentRegionAvail())) or 600;
        local col_w = (avail_w - 8) / 2;
        imgui.BeginChild('##scl_hist_left', { col_w, 0 }, 0);
        draw_lane('incoming', 'incoming', rest_h);
        imgui.EndChild();
        imgui.SameLine(0, 8);
        imgui.BeginChild('##scl_hist_right', { 0, 0 }, 0);
        draw_lane('outgoing', 'outgoing', rest_h);
        imgui.EndChild();

        -- Remember where it is.
        if not imgui.IsMouseDown(0) then
            local px, py = imgui.GetWindowPos();
            local sw, sh = imgui.GetWindowSize();
            px, py, sw, sh = tonumber(px), tonumber(py), tonumber(sw), tonumber(sh);
            if px ~= nil and (math.abs(px - (H.x or 0)) >= 1 or math.abs(py - (H.y or 0)) >= 1
                or math.abs(sw - (H.w or 0)) >= 1 or math.abs(sh - (H.h or 0)) >= 1) then
                H.x, H.y, H.w, H.h = px, py, sw, sh;
                history.dirty_at = os.clock();
            end
        end
        uifont.pop();
    end
    imgui.End();
    uifont.pop();
    imgui.PopStyleColor(1);
    pop_theme();

    if H.visible ~= history.open[1] then
        H.visible = history.open[1];
        core_mod.save_settings();
    end
    if history.dirty_at ~= nil and os.clock() - history.dirty_at > 1.0 then
        history.dirty_at = nil;
        core_mod.save_settings();
    end
end

return history;
