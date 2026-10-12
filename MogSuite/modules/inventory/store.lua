--[[
    MogSuite - modules/inventory/store.lua

    Data files shared by all your characters (MogSuite\\data\\): every character's bags,
    learned vendor prices and your key item marks.
]]

-- ============================================================================
-- Data files (shared by all your characters): prices and inventories
--   data\characters.lua      last known bags of every character you play
--   data\prices_learned.lua  exact sell prices seen at vendors (HorizonXI)
--   item_basic.sql           LandSandBoat price list (optional, you add it)
-- ============================================================================

-- Collapses doubled backslashes (addon.path may already end with one).
function clean_path(p)
    return (tostring(p):gsub('\\\\+', '\\'));
end

DATA_DIR = clean_path(addon.path .. '\\data\\');

function ensure_data_dir()
    pcall(function()
        if ashita.fs.exists ~= nil and ashita.fs.exists(DATA_DIR) then return; end
        if ashita.fs.create_directory ~= nil then
            ashita.fs.create_directory(DATA_DIR);
        elseif ashita.fs.create_dir ~= nil then
            ashita.fs.create_dir(DATA_DIR);
        end
    end);
end

function serialize(value, indent)
    indent = indent or '';
    local t = type(value);
    if t == 'number' then return tostring(value); end
    if t == 'boolean' then return value and 'true' or 'false'; end
    if t == 'string' then return ('%q'):format(value); end
    if t ~= 'table' then return 'nil'; end
    local inner = indent .. '  ';
    local parts = {};
    for k, v in pairs(value) do
        local key;
        if type(k) == 'number' then key = ('[%d]'):format(k);
        else key = ('[%q]'):format(tostring(k)); end
        parts[#parts + 1] = inner .. key .. ' = ' .. serialize(v, inner);
    end
    if #parts == 0 then return '{}'; end
    return '{\n' .. table.concat(parts, ',\n') .. '\n' .. indent .. '}';
end

function load_lua_file(path)
    local ok, chunk = pcall(loadfile, path);
    if not ok or chunk == nil then return nil; end
    local ok2, data = pcall(chunk);
    if ok2 and type(data) == 'table' then return data; end
    return nil;
end

function write_lua_file(path, data)
    ensure_data_dir();
    local f = io.open(path, 'w');
    if f == nil then return false; end
    f:write('return ' .. serialize(data) .. '\n');
    f:close();
    return true;
end

prices = { base = {}, nosale = {}, ah = {}, loaded = false, count = 0, source = nil };
learned = load_lua_file(DATA_DIR .. 'prices_learned.lua') or {};
chars = load_lua_file(DATA_DIR .. 'characters.lua') or {};
-- Key item overrides you set with right-click (shared by all characters):
-- true = always TEMP, false = never TEMP. Anything not listed uses the
-- built-in list below.
ki_temp = load_lua_file(DATA_DIR .. 'key_items_temp.lua') or {};

-- Built-in key item categories, by key item ID. The game doesn't tell addons
-- which key items are temporary, so this list decides:
--   permanent: listed IDs and the job gestures (1738-1757)
--   other:     maps, claim slips, Voidwatch and Abyssea items (never TEMP)
--   temporary: everything else
KI_PERMANENT = {};
for _, id in ipairs({
    8, 9, 20, 21, 35, 36, 45, 46, 47, 56, 95, 116, 118, 136, 138, 142, 155, 162, 169, 195,
    347, 349, 351, 352, 353, 354, 355, 356, 357, 361, 365, 452, 455, 456, 457, 458, 459,
    595, 596, 604, 606, 619, 739, 740, 741, 742, 767, 771, 774, 781, 811, 812,
    829, 830, 831, 832, 833, 851, 852, 856, 857, 858, 859, 879, 880, 891, 909, 910,
}) do KI_PERMANENT[id] = true; end
for id = 1738, 1757 do KI_PERMANENT[id] = true; end

function ki_auto_category(id, name_lower)
    id = tonumber(id) or 0;
    if KI_PERMANENT[id] then return 'permanent'; end
    if id == 383 or (id >= 385 and id <= 447) or (id >= 1858 and id <= 1918) then return 'other'; end
    if name_lower ~= nil and name_lower:sub(1, 7) == 'map of ' then return 'other'; end
    if id >= 861 and id <= 875 then return 'other'; end   -- claim slips
    if id >= 366 and id <= 377 then return 'other'; end   -- Voidwatch
    if id >= 1283 and id <= 1737 then return 'other'; end -- Abyssea
    return 'temporary';
end

-- 'permanent', 'temporary' or 'other', with your right-click override applied.
function ki_category(id, name_lower)
    local auto = ki_auto_category(id, name_lower);
    local o = ki_temp[id];
    if o == true then return 'temporary', auto; end
    if o == false and auto == 'temporary' then return 'permanent', auto; end
    return auto, auto;
end
chars_dirty = false;
chars_saved_at = 0;
