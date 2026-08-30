-- configuration.lua
-- Settings loader/saver with JSON-safe normalization for non-string keyed tables.

local helpers = require('helpers')

local M = {}

-- utils -----------------------------------------------------------------------
local function deep_copy(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local out = {}
    for k, v in pairs(tbl) do out[k] = deep_copy(v) end
    return out
end

local function deep_merge(dst, src)
    for k, v in pairs(src or {}) do
        if type(v) == 'table' then
            if type(dst[k]) ~= 'table' then dst[k] = {} end
            deep_merge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function is_array(t)
    if type(t) ~= 'table' then return false end
    local n = #t
    local c = 0
    for k, _ in pairs(t) do
        if type(k) ~= 'number' then return false end
        c = c + 1
    end
    return c == n
end

-- Normalize filters.mode_whitelist --------------------------------------------
local function wl_array_to_set(arr)
    local set = {}
    if type(arr) ~= 'table' then return set end
    for _, v in ipairs(arr) do
        local n = tonumber(v)
        if n then set[n] = true end
    end
    return set
end

local function wl_any_to_set(t)
    -- Accept either {"28":true,"29":true} or {28=true,29=true} or {28,29,...}
    if type(t) ~= 'table' then return {} end
    if is_array(t) then
        return wl_array_to_set(t)
    end
    local set = {}
    for k, v in pairs(t) do
        if v then
            local n = tonumber(k)
            if n then set[n] = true end
        end
    end
    return set
end

local function wl_set_to_array(set)
    local arr = {}
    if type(set) ~= 'table' then return arr end
    for k, v in pairs(set) do
        if v and type(k) == 'number' then
            arr[#arr + 1] = k
        elseif v and type(k) == 'string' and tonumber(k) then
            arr[#arr + 1] = tonumber(k)
        end
    end
    table.sort(arr) -- stable, human-friendly order
    return arr
end

-- public ----------------------------------------------------------------------
function M.load(path, defaults)
    local cfg = deep_copy(defaults or {})

    local raw = helpers.read_all(path)
    if raw and raw ~= '' then
        local parsed = helpers.json_decode(raw)
        if type(parsed) == 'table' then
            deep_merge(cfg, parsed)
        end
    end

    -- JSON-safe normalization: rebuild whitelist as a Lua set
    if cfg.filters and cfg.filters.mode_whitelist then
        cfg.filters.mode_whitelist = wl_any_to_set(cfg.filters.mode_whitelist)
    end

    -- Ensure directory exists and persist a normalized copy
    helpers.ensure_dir(path:match('^(.*)\\[^\\]+$') or '')
    M.save(path, cfg)
    return cfg
end

function M.save(path, cfg)
    local out = deep_copy(cfg or {})

    -- Convert set -> array so the JSON lib doesn’t choke on non-string keys
    if out.filters and out.filters.mode_whitelist then
        out.filters.mode_whitelist = wl_set_to_array(out.filters.mode_whitelist)
    end

    local blob = helpers.json_encode(out)
    helpers.write_all(path, blob)
end

return M
