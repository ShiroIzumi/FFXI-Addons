require('common');
local core_mod = require('scl.core');
local state = core_mod.state;

-- ============================================================================
-- /scl debug — unmapped message logger
-- ============================================================================
-- When enabled, any action / message packet involving the local player whose
-- message ID SCL does not classify is written to:
--   <Ashita>\addons\scrollingcombatlog\logs\debug_YYYY-MM-DD.log
-- Each distinct signature is logged once per session and announced once in
-- chat, so the file stays short and readable.

local seen = {};
local seen_count = 0;
local folder_ready = false;

local function log_folder()
    local base = '.';
    pcall(function()
        base = AshitaCore:GetInstallPath();
    end);
    base = tostring(base or '.'):gsub('[\\/]+$', '');
    return base .. '\\addons\\' .. addon.name .. '\\logs';
end

local function ensure_folder(folder)
    if folder_ready then return end
    folder_ready = true;

    if ashita and ashita.fs then
        local exists = false;
        pcall(function() exists = ashita.fs.exists(folder) == true; end);
        if not exists then
            pcall(function() ashita.fs.create_directory(folder); end);
            pcall(function() ashita.fs.create_dir(folder); end);
        end
    end
end

local function write_line(text)
    local folder = log_folder();
    ensure_folder(folder);

    local path = folder .. '\\debug_' .. os.date('%Y-%m-%d') .. '.log';
    local file = io.open(path, 'a');
    if not file then
        -- The logs folder could not be created: fall back to the addon folder.
        path = folder:gsub('\\logs$', '') .. '\\scl_debug_' .. os.date('%Y-%m-%d') .. '.log';
        file = io.open(path, 'a');
    end
    if not file then
        return false;
    end
    file:write(os.date('[%H:%M:%S] ') .. text .. '\n');
    file:close();
    return true;
end

local function enabled()
    return state.debug == true;
end

-- signature: unique key for this kind of event (logged once per session)
-- summary:   short text for the chat notice
-- details:   full line for the log file
local function report(signature, summary, details)
    if state.debug ~= true then return end
    if seen[signature] then return end

    if seen_count > 2000 then
        seen = {};
        seen_count = 0;
    end
    seen[signature] = true;
    seen_count = seen_count + 1;

    local ok = write_line(details);
    print(('[SCL debug] %s%s'):fmt(summary, ok and '' or ' (could not write log file)'));
end

local function set_enabled(value)
    state.debug = value == true;
    if state.debug then
        write_line('--- debug logging started (SCL ' .. tostring(addon.version) .. ') ---');
        print('[SCL] Debug logging ON. Unmapped messages go to addons\\scrollingcombatlog\\logs\\');
    else
        print('[SCL] Debug logging OFF.');
    end
end

return {
    enabled = enabled,
    report = report,
    set_enabled = set_enabled,
};
