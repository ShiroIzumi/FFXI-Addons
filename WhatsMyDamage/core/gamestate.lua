--[[
    WhatsMyDamage - core/gamestate.lua (same as Triage)

    When WhatsMyDamage should stay out of the way:
      * not logged in (character select / title screen): your own character
        isn't drawn yet, so party memory can still hold old data
      * a cutscene / event is running (not for gathering points, which run
        as tiny events)
      * the game's interface is hidden
    Game menus do NOT hide WhatsMyDamage.

    The memory signatures are the same ones XIUI uses (credit: Velyn).
]]

require('common');

local gamestate = {};

local pEventSystem = 0;
local pInterfaceHidden = 0;
pcall(function()
    pEventSystem = ashita.memory.find('FFXiMain.dll', 0, 'A0????????84C0741AA1????????85C0741166A1????????663B05????????0F94C0C3', 0, 0) or 0;
end);
pcall(function()
    pInterfaceHidden = ashita.memory.find('FFXiMain.dll', 0, '8B4424046A016A0050B9????????E8????????F6D81BC040C3', 0, 0) or 0;
end);

local RENDER_VISIBLE = 0x200;
local RENDER_HIDDEN = 0x4000;

local GATHERING = {
    ['Clamming Point'] = true, ['Harvesting Point'] = true, ['Excavation Point'] = true,
    ['Logging Point'] = true, ['Mining Point'] = true,
};

-- Your character is in the world (not character select / loading).
function gamestate.logged_in()
    local ok, r = pcall(function()
        local idx = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
        if (tonumber(idx) or 0) == 0 then return false; end
        local flags = tonumber(AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags0(idx)) or 0;
        return bit.band(flags, RENDER_VISIBLE) == RENDER_VISIBLE and bit.band(flags, RENDER_HIDDEN) == 0;
    end);
    if not ok then return true; end   -- can't tell: don't hide
    return r == true;
end

local function targeting_gathering_point()
    local ok, r = pcall(function()
        local idx = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0);
        if (tonumber(idx) or 0) == 0 then return false; end
        local name = AshitaCore:GetMemoryManager():GetEntity():GetName(idx);
        return name ~= nil and GATHERING[name] == true;
    end);
    return ok and r == true;
end

-- A cutscene / event is running.
function gamestate.in_event()
    if pEventSystem == 0 then return false; end
    local ok, r = pcall(function()
        local ptr = ashita.memory.read_uint32(pEventSystem + 1);
        if ptr == 0 then return false; end
        return ashita.memory.read_uint8(ptr) == 1;
    end);
    if not ok or r ~= true then return false; end
    return not targeting_gathering_point();
end

-- The game's own interface is hidden.
function gamestate.interface_hidden()
    if pInterfaceHidden == 0 then return false; end
    local ok, r = pcall(function()
        local ptr = ashita.memory.read_uint32(pInterfaceHidden + 10);
        if ptr == 0 then return false; end
        return ashita.memory.read_uint8(ptr + 0xB4) == 1;
    end);
    return ok and r == true;
end

-- You are engaged (fighting).
function gamestate.engaged()
    local ok, r = pcall(function()
        local idx = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
        return (tonumber(AshitaCore:GetMemoryManager():GetEntity():GetStatus(idx)) or 0) == 1;
    end);
    return ok and r == true;
end

return gamestate;
