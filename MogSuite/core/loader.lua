--[[
    MogSuite - core/loader.lua

    Loads a module (Character, Inventory, Actions) from its folder. Every
    file of a module runs in one shared module scope, so the files can use
    each other's functions and tables without long import lists, while the
    modules stay separate from each other and from other addons.
]]

require('common');

local loader = {};

-- addon.path may or may not end with a backslash; join and tidy it.
function loader.path(...)
    local p = table.concat({ addon.path, ... }, '\\');
    p = p:gsub('[\\/]+', '\\');
    return p;
end

-- Runs a Lua file and returns what it returns (used for data / defaults).
function loader.read(relative)
    local path = loader.path(relative);
    local chunk, err = loadfile(path);
    if chunk == nil then error(('[MogSuite] Could not load %s: %s'):fmt(path, tostring(err))); end
    return chunk();
end

-- Creates a module scope with the given values and runs the module's files
-- in order inside it. Returns the scope.
function loader.load_module(folder, files, inject)
    local env = setmetatable({}, { __index = _G });
    for k, v in pairs(inject or {}) do env[k] = v; end
    for _, file in ipairs(files) do
        local path = loader.path('modules', folder, file .. '.lua');
        local chunk, err = loadfile(path);
        if chunk == nil then error(('[MogSuite] Could not load %s: %s'):fmt(path, tostring(err))); end
        setfenv(chunk, env);
        local ok, run_err = pcall(chunk);
        if not ok then error(('[MogSuite] Error in %s: %s'):fmt(path, tostring(run_err))); end
    end
    return env;
end

return loader;
