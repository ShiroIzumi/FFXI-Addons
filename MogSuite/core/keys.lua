--[[
    MogSuite - core/keys.lua

    Open keys for the Character, Inventory and Actions windows. A key works
    only while you are not typing (chat box closed, no text box active).
    Ctrl / Alt / Shift are read from Windows each time, so they can never get
    stuck (for example after Alt+Tab).
]]

require('common');
local imgui = require('imgui');
local ffi = require('ffi');
local bit = require('bit');

pcall(ffi.cdef, 'short __stdcall GetAsyncKeyState(int vKey);');

local keys = {
    listening = nil,   -- which bind is waiting for a key press ('character' / ...)
};

local VK_NAMES = {
    [0x08] = 'Backspace', [0x09] = 'Tab', [0x0D] = 'Enter', [0x13] = 'Pause', [0x14] = 'Caps Lock',
    [0x1B] = 'Esc', [0x20] = 'Space', [0x21] = 'Page Up', [0x22] = 'Page Down', [0x23] = 'End',
    [0x24] = 'Home', [0x25] = 'Left', [0x26] = 'Up', [0x27] = 'Right', [0x28] = 'Down',
    [0x2D] = 'Insert', [0x2E] = 'Delete',
    [0x6A] = 'Num *', [0x6B] = 'Num +', [0x6D] = 'Num -', [0x6E] = 'Num .', [0x6F] = 'Num /',
    [0xBA] = ';', [0xBB] = '=', [0xBC] = ',', [0xBD] = '-', [0xBE] = '.', [0xBF] = '/',
    [0xC0] = '`', [0xDB] = '[', [0xDC] = '\\', [0xDD] = ']', [0xDE] = "'",
};

local MODIFIERS = {
    [0x10] = true, [0x11] = true, [0x12] = true, [0xA0] = true, [0xA1] = true,
    [0xA2] = true, [0xA3] = true, [0xA4] = true, [0xA5] = true, [0x5B] = true, [0x5C] = true,
};

function keys.vk_name(vk)
    vk = tonumber(vk) or 0;
    if vk == 0 then return 'None'; end
    if (vk >= 0x41 and vk <= 0x5A) or (vk >= 0x30 and vk <= 0x39) then return string.char(vk); end
    if vk >= 0x70 and vk <= 0x87 then return 'F' .. tostring(vk - 0x6F); end
    if vk >= 0x60 and vk <= 0x69 then return 'Num ' .. tostring(vk - 0x60); end
    return VK_NAMES[vk] or ('Key 0x%02X'):fmt(vk);
end

-- "Ctrl + Shift + B"
function keys.text(bind)
    if bind == nil or (tonumber(bind.key) or 0) == 0 then return 'None'; end
    local parts = {};
    if bind.ctrl then parts[#parts + 1] = 'Ctrl'; end
    if bind.alt then parts[#parts + 1] = 'Alt'; end
    if bind.shift then parts[#parts + 1] = 'Shift'; end
    parts[#parts + 1] = keys.vk_name(bind.key);
    return table.concat(parts, ' + ');
end

-- Is this key held right now (from Windows)?
function keys.down(vk)
    local ok, v = pcall(function() return ffi.C.GetAsyncKeyState(vk); end);
    if ok and v ~= nil then return bit.band(tonumber(v) or 0, 0x8000) ~= 0; end
    return false;
end

-- True while you are typing: the chat line is open or an ImGui text box has focus.
function keys.typing()
    local chat_open = false;
    pcall(function()
        local v = AshitaCore:GetChatManager():IsInputOpen();
        chat_open = (v == true) or ((tonumber(v) or 0) ~= 0);
    end);
    if chat_open then return true; end
    local wants = false;
    pcall(function() wants = imgui.GetIO().WantTextInput == true; end);
    return wants;
end

-- Handles one 'key' event. binds = { name = bind }; on_press(name) is
-- called for a matching key. on_capture(name, vk, ctrl, alt, shift) is
-- called when a key is captured for a bind. Returns true to block the key.
function keys.handle(e, binds, on_press, on_capture)
    local vk = tonumber(e.wparam) or 0;
    local lparam = tonumber(e.lparam) or 0;
    local down = bit.band(lparam, 0x80000000) == 0;
    local repeated = bit.band(lparam, 0x40000000) ~= 0;
    if MODIFIERS[vk] then return false; end
    if not down then return false; end

    if keys.listening ~= nil then
        if repeated then return true; end
        local name = keys.listening;
        keys.listening = nil;
        if vk ~= 0x1B then
            on_capture(name, vk, keys.down(0x11), keys.down(0x12), keys.down(0x10));
        end
        return true;
    end

    if keys.typing() then return false; end
    local ctrl, alt, shift = keys.down(0x11), keys.down(0x12), keys.down(0x10);
    for name, bind in pairs(binds) do
        if bind.enabled ~= false and (tonumber(bind.key) or 0) == vk
            and (bind.ctrl == true) == ctrl and (bind.alt == true) == alt and (bind.shift == true) == shift then
            if not repeated then on_press(name); end
            return true;
        end
    end
    return false;
end

return keys;
