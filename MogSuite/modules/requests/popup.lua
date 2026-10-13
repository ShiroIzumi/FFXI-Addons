--[[
    MogSuite - modules/requests/popup.lua

    The popup for party / alliance invites and trade requests. Nothing is
    answered for you: /join, /decline and the trade response are only sent
    when you click a button.
]]

local ACCEPT  = { 0.10, 0.40, 0.22, 1.00 };
local ACCEPT_HOVER  = { 0.13, 0.52, 0.28, 1.00 };
local ACCEPT_ACTIVE = { 0.15, 0.62, 0.33, 1.00 };
local DECLINE = { 0.55, 0.14, 0.16, 1.00 };
local DECLINE_HOVER  = { 0.70, 0.18, 0.20, 1.00 };
local DECLINE_ACTIVE = { 0.82, 0.22, 0.24, 1.00 };

local KIND_INFO = {
    party    = { title = 'PARTY INVITE',    color = 'water', text = '%s is inviting you to join the party.',    accept = 'Join Party' },
    alliance = { title = 'ALLIANCE INVITE', color = 'thunder', text = '%s is inviting you to join the alliance.', accept = 'Join Alliance' },
    trade    = { title = 'TRADE REQUEST',   color = 'earth', text = '%s wants to trade with you.',            accept = 'Accept Trade' },
};

-- Name of the entity at a target index, or the fallback.
function entity_name(index, fallback)
    local name = nil;
    pcall(function()
        local v = AshitaCore:GetMemoryManager():GetEntity():GetName(index);
        if v ~= nil and tostring(v) ~= '' then name = tostring(v); end
    end);
    return name or fallback;
end

-- Text up to the first zero byte.
function trim_zero(value)
    if value == nil then return ''; end
    return tostring(value):match('^[^%z]*') or '';
end

function close_popup()
    local p = state.popup;
    p.active, p.kind, p.name, p.trade_id, p.trade_index = false, nil, '', 0, 0;
end

-- kind: 'party' | 'alliance' | 'trade'
function show_popup(kind, name, trade_id, trade_index, test)
    if not test and ((kind == 'trade' and config.trade == false) or (kind ~= 'trade' and config.party == false)) then return; end
    local p = state.popup;
    p.active = true;
    p.kind = kind;
    p.name = (name ~= nil and name ~= '') and name or 'Someone';
    p.opened_at = os.clock();
    p.trade_id = tonumber(trade_id) or 0;
    p.trade_index = tonumber(trade_index) or 0;
    p.test = test == true;
    state.apply_geometry = true;
end

-- Outgoing 0x033 (answer to a trade request): 0 = accept (opens the trade
-- window), 1 = cancel. The same packet the game sends from its own menu.
function send_trade_response(response_type)
    local ok = pcall(function()
        local packet = struct.pack('bbxxLL', 0x33, 0x06, tonumber(response_type) or 0, 0):totable();
        AshitaCore:GetPacketManager():AddOutgoingPacket(0x33, packet);
    end);
    return ok;
end

local function queue_command(command)
    pcall(function() AshitaCore:GetChatManager():QueueCommand(1, command); end);
end

local function capture_geometry()
    local x, y = imgui.GetWindowPos();
    local w, h = imgui.GetWindowSize();
    x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h);
    if x == nil or w == nil then return; end
    local g = config.window;
    if math.abs(x - g.x) >= 1 or math.abs(y - g.y) >= 1 or math.abs(w - g.w) >= 1 or math.abs(h - g.h) >= 1 then
        g.x, g.y, g.w, g.h = x, y, w, h;
        mark_dirty();
    end
end

function draw_popup()
    local p = state.popup;
    if not p.active then return; end
    local info = KIND_INFO[p.kind] or KIND_INFO.party;
    local scale = tonumber(config.font_scale) or 1.2;

    local g = config.window;
    if state.apply_geometry then
        local w, h = tonumber(g.w) or 470, tonumber(g.h) or 160;
        local x, y = tonumber(g.x) or -1, tonumber(g.y) or -1;
        if x < 0 or y < 0 then
            -- First time: center it on the screen.
            local ds = imgui.GetIO().DisplaySize;
            x = math.floor(((tonumber(ds.x) or 1920) - w) * 0.5);
            y = math.floor(((tonumber(ds.y) or 1080) - h) * 0.40);
            g.x, g.y = x, y;
            mark_dirty();
        end
        imgui.SetNextWindowPos({ x, y }, { 0, 0 });
        imgui.SetNextWindowSize({ w, h });
        state.apply_geometry = false;
    end
    if imgui.SetNextWindowSizeConstraints ~= nil then
        imgui.SetNextWindowSizeConstraints({ 300, 110 }, { 1600, 800 });
    end

    local flags = bit.bor(ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoCollapse or 0);
    if config.locked then flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoResize); end
    if not config.title_bar then flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar); end

    push_theme();
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, config.border ~= false and 1.0 or 0.0);
    if imgui.Begin('MogSuite  -  Request##ms_request_popup', nil, flags) then
        imgui.PushFont(nil, imgui.GetFontSize() * scale);
        local width = tonumber((imgui.GetContentRegionAvail())) or 440;
        local color = COLORS[info.color];

        -- Header: colored kind label, the time left, and X.
        imgui.AlignTextToFramePadding();
        imgui.TextColored(color, info.title .. (p.test and '  (test)' or ''));
        local frame_h = imgui.GetFrameHeight();
        local right = '';
        local limit = tonumber(config.auto_close) or 0;
        if limit > 0 then
            right = ('closes in %ds'):fmt(math.max(0, math.ceil(limit - (os.clock() - p.opened_at))));
        end
        local base_x = tonumber(imgui.GetCursorPosX()) or 0;
        imgui.SameLine();
        local x_w = frame_h + 2;
        imgui.SetCursorPosX(math.max(imgui.GetCursorPosX() + 8, base_x + width - text_w(right) - x_w - 10));
        imgui.TextDisabled(right);
        imgui.SameLine();
        imgui.SetCursorPosX(math.max(imgui.GetCursorPosX() + 4, base_x + width - frame_h));
        if imgui.Button('X##ms_request_close', { frame_h, frame_h }) then close_popup(); end
        tip('Hide this popup (the request stays open in the game)');

        -- Colored line under the header.
        local sx, sy = imgui.GetCursorScreenPos();
        imgui.GetWindowDrawList():AddRectFilled({ sx, sy }, { sx + width, sy + 2 }, imgui.GetColorU32({ color[1], color[2], color[3], 0.65 }), 1.0);
        imgui.Dummy({ width, 4 });

        imgui.Spacing();
        imgui.PushTextWrapPos(0);
        imgui.TextWrapped(info.text:fmt(p.name));
        imgui.PopTextWrapPos();
        imgui.Spacing();
        imgui.Spacing();

        local gap = 10;
        local button_w = math.max(100, (width - gap) / 2);
        local button_h = math.floor(imgui.GetTextLineHeight() * 2.2);

        imgui.PushStyleColor(ImGuiCol_Button, ACCEPT);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, ACCEPT_HOVER);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, ACCEPT_ACTIVE);
        if imgui.Button(info.accept .. '##ms_request_accept', { button_w, button_h }) then
            if p.test then
                close_popup();
            elseif p.kind == 'trade' then
                if send_trade_response(0) then close_popup(); end
            else
                queue_command('/join');
                close_popup();
            end
        end
        imgui.PopStyleColor(3);
        if p.kind == 'trade' then tip('Opens the trade window'); else tip('Sends /join'); end

        imgui.SameLine(0, gap);
        imgui.PushStyleColor(ImGuiCol_Button, DECLINE);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, DECLINE_HOVER);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, DECLINE_ACTIVE);
        if imgui.Button('Decline##ms_request_decline', { button_w, button_h }) then
            if not p.test then
                if p.kind == 'trade' then send_trade_response(1); else queue_command('/decline'); end
            end
            close_popup();
        end
        imgui.PopStyleColor(3);
        if p.kind == 'trade' then tip('Turns the trade down'); else tip('Sends /decline'); end

        imgui.PopFont();
        if not config.locked then capture_geometry(); end
    end
    imgui.End();
    imgui.PopStyleVar(1);
    pop_theme();
end
