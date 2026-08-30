-- helpers.lua
-- Small utilities with safety guards to match your known Ashita v4 rules.

require('common')

local M = {}

-- Get addon base path (…\addons\scrollingcombatlog)
function M.get_addon_path()
    local base = AshitaCore and AshitaCore:GetInstallPath() or '.'
    return (base .. '\\addons\\' .. addon.name)
end

-- Make directory if not exists (Lua io doesn't have mkdir; use os.execute fallback).
function M.ensure_dir(path)
    if not path or path == '' then return end
    os.execute(string.format('mkdir "%s" 2> NUL', path))
end

-- Robust player name with nil-safety and API fallbacks.
function M.safe_player_name()
    local mgr = AshitaCore and AshitaCore:GetMemoryManager()
    if not mgr then return nil end

    -- 1) Try Player manager (some builds expose GetName, some don't).
    local okP, player = pcall(function() return mgr:GetPlayer() end)
    if okP and player then
        local okName, name = pcall(function() return player.GetName and player:GetName() or nil end)
        if okName and type(name) == 'string' and name ~= '' then
            return name
        end
    end

    -- 2) Try Entity manager (more universal).
    local okE, ent = pcall(function() return mgr:GetEntity() end)
    if okE and ent then
        -- Get the local player index if available
        local okIdx, meIdx = pcall(function()
            return (ent.GetLocalPlayerIndex and ent:GetLocalPlayerIndex())
                or (ent.GetLocalPlayer and ent:GetLocalPlayer())  -- some builds
                or nil
        end)
        if okIdx and meIdx and meIdx > 0 then
            local okNm, nm = pcall(function()
                return ent.GetName and ent:GetName(meIdx) or nil
            end)
            if okNm and type(nm) == 'string' and nm ~= '' then
                return nm
            end
        end
    end

    -- Could not determine name.
    return nil
end

-- Server ID with nil safety (prevents Nil GetServerId() crash).
function M.safe_server_id()
    local mgr = AshitaCore and AshitaCore:GetMemoryManager()
    if not mgr then return nil end
    local player = mgr:GetPlayer()
    if not player then return nil end
    local ok, sid = pcall(function() return player:GetServerId() end)
    if ok and sid then return sid end
    return nil
end

-- Read entire file (returns string or nil).
function M.read_all(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local d = f:read('*a')
    f:close()
    return d
end

-- Write entire file (returns true/false).
function M.write_all(path, data)
    local f = io.open(path, 'wb')
    if not f then return false end
    f:write(data or '')
    f:close()
    return true
end

-- JSON encode/decode shim.
local has_json, json = pcall(require, 'json')

local function tiny_json_encode(val)
    local t = type(val)
    if t == 'nil' then return 'null' end
    if t == 'number' then return tostring(val) end
    if t == 'boolean' then return val and 'true' or 'false' end
    if t == 'string' then
        local s = val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r')
        return '"' .. s .. '"'
    end
    if t == 'table' then
        local is_array, idx = true, 1
        for k, _ in pairs(val) do
            if k ~= idx then is_array = false; break end
            idx = idx + 1
        end
        if is_array then
            local parts = {}
            for i = 1, #val do parts[#parts+1] = tiny_json_encode(val[i]) end
            return '[' .. table.concat(parts, ',') .. ']'
        else
            local parts = {}
            for k, v in pairs(val) do
                parts[#parts+1] = '"' .. tostring(k) .. '":' .. tiny_json_encode(v)
            end
            return '{' .. table.concat(parts, ',') .. '}'
        end
    end
    return 'null'
end

local function tiny_json_decode(_)
    return nil, 'no-decoder'
end

function M.json_encode(tbl)
    if has_json and json and json.encode then
        return json.encode(tbl)
    end
    return tiny_json_encode(tbl)
end

function M.json_decode(str)
    if has_json and json and json.decode then
        local ok, val = pcall(json.decode, str)
        if ok then return val end
        return nil
    end
    return tiny_json_decode(str)
end

return M
