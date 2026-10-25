--[[
    WhatsMyDamage - core/icons.lua

    Job icons: the PNGs that come with XIUI (addons\XIUI\assets\jobs\<set>\),
    read from that folder, not copied (same as Triage). Without XIUI (or a
    missing file) the meter draws a small colored job badge instead.
]]

require('common');
local ffi = require('ffi');
local d3d = require('d3d8');

local icons = { jobs = {}, keep = {} };

local device = nil;
local function get_device()
    if device == nil then pcall(function() device = d3d.get_device(); end); end
    return device;
end

local function read_file(path)
    local f = io.open(path, 'rb');
    if f == nil then return nil; end
    local data = f:read('*a');
    f:close();
    return data;
end

-- ImGui texture id for a job icon, or nil.
function icons.job(job, set)
    if job == nil or job == '' then return nil; end
    set = set or 'Classic';
    local key = set .. '|' .. job:lower();
    local c = icons.jobs[key];
    if c ~= nil then return c or nil; end
    local result = false;
    pcall(function()
        local dev = get_device();
        if dev == nil then return; end
        local base = tostring(AshitaCore:GetInstallPath() or '');
        if base ~= '' and base:sub(-1) ~= '\\' and base:sub(-1) ~= '/' then base = base .. '\\'; end
        local data = read_file(base .. 'addons\\XIUI\\assets\\jobs\\' .. set .. '\\' .. job:lower() .. '.png');
        if data == nil or #data == 0 then return; end
        local ptr = ffi.new('IDirect3DTexture8*[1]');
        local C = ffi.C;
        if C.D3DXCreateTextureFromFileInMemoryEx(dev, data, #data,
            0xFFFFFFFF, 0xFFFFFFFF, 1, 0, C.D3DFMT_A8R8G8B8, C.D3DPOOL_MANAGED,
            C.D3DX_DEFAULT, C.D3DX_DEFAULT, 0, nil, nil, ptr) ~= C.S_OK then
            return;
        end
        local tex = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
        icons.keep[key] = tex;
        result = tonumber(ffi.cast('uint32_t', tex));
    end);
    icons.jobs[key] = result;
    return result or nil;
end

function icons.reset() icons.jobs = {}; end

return icons;
