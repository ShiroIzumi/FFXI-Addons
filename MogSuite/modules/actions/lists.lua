--[[
    MogSuite - modules/actions/lists.lua

    Builds the rows for the Abilities, Weapon Skills and Magic tabs.
]]

-- ============================================================================
-- Rows
--   row = { k = 'ja'|'pet'|'ws'|'ma', name, res, kind, status, note,
--           cd_key, cd, src, level, ... }
--   status: 'ready' (you have it), 'locked' (level / skill not reached),
--           'scroll' (spell not learned), 'na' (not available to you)
-- ============================================================================

function row_key(k, name) return k .. ':' .. name; end

function ability_row(me, a, job, lvl, src)
    local name, need, kind = a[1], a[2], a[3];
    local res = ability_by_name(name);
    local k = (kind == 'pet') and 'pet' or 'ja';
    local row = { k = k, name = name, res = res, kind = kind or 'ja', level = need, src = src, job = job };
    local have = nil;
    if kind ~= 'pet' then have = has_ability(me, res); end
    if kind == 'merit' then
        row.status = have and 'ready' or 'na';
        row.note = have and nil or 'Merit';
    elseif lvl >= need then
        if have == false then
            row.status, row.note = 'na', 'Not learned';
        else
            row.status = 'ready';
        end
    else
        row.status, row.note = 'locked', ('Lv %d'):fmt(need);
    end
    local timer = tonumber(res_field(res, 'RecastTimerId'));
    if timer ~= nil and (timer ~= 0 or kind == 'sp') then
        row.cd = state.ja_cd[timer] or 0;
        row.cd_key = 'ja' .. timer;
    end
    return row;
end

function build_abilities(me)
    local sections = {};
    local list = JOB_ABILITIES[me.job];
    if list ~= nil then
        local main, pets = {}, {};
        for _, a in ipairs(list) do
            local row = ability_row(me, a, me.job, me.lvl, 'main');
            if a[3] == 'pet' then pets[#pets + 1] = row; else main[#main + 1] = row; end
        end
        sections[#sections + 1] = { key = 'ja_main', title = JOB_NAMES[me.job] or '?', tag = JOB_SHORT[me.job], rows = main };
        if #pets > 0 then
            sections[#sections + 1] = { key = 'ja_pet', title = 'Pet commands', tag = JOB_SHORT[me.job], rows = pets };
        end
    end
    local sub = JOB_ABILITIES[me.sub];
    if sub ~= nil and me.sub > 0 then
        local rows = {};
        for _, a in ipairs(sub) do
            if a[3] ~= 'sp' and a[3] ~= 'merit' and a[2] <= SUB_MAX_LEVEL then
                if a[2] <= me.sublvl or config.show_sub_locked ~= false then
                    rows[#rows + 1] = ability_row(me, a, me.sub, me.sublvl, 'sub');
                end
            end
        end
        if #rows > 0 then
            sections[#sections + 1] = { key = 'ja_sub', title = (JOB_NAMES[me.sub] or '?') .. '  (support)', tag = JOB_SHORT[me.sub], rows = rows };
        end
    end
    -- Job traits (passive; HorizonXI levels). Shown after the abilities.
    local function trait_rows(job, lvl, cap)
        local rows = {};
        for _, t in ipairs(JOB_TRAITS[job] or {}) do
            local name, need, tag = t[1], t[2], t[3];
            if need <= cap and not (tag == 'merit' and cap < LEVEL_CAP) then
                local row = { k = 'trait', name = name, kind = 'trait', level = need, job = job, tag = tag };
                if tag == 'merit' then
                    row.status, row.note = 'na', 'Merit';
                elseif lvl >= need then
                    row.status = 'ready';
                else
                    row.status, row.note = 'locked', ('Lv %d'):fmt(need);
                end
                rows[#rows + 1] = row;
            end
        end
        return rows;
    end
    if config.show_traits ~= false then
        local tm = trait_rows(me.job, me.lvl, LEVEL_CAP);
        if #tm > 0 then
            sections[#sections + 1] = { key = 'tr_main', title = (JOB_NAMES[me.job] or '?') .. ' traits', tag = 'TRT', rows = tm, traits = true };
        end
        if me.sub ~= nil and me.sub > 0 then
            local ts = trait_rows(me.sub, me.sublvl, SUB_MAX_LEVEL);
            if #ts > 0 then
                sections[#sections + 1] = { key = 'tr_sub', title = (JOB_NAMES[me.sub] or '?') .. ' traits  (support)', tag = 'TRT', rows = ts, traits = true };
            end
        end
    end

    for _, s in ipairs(sections) do
        if s.traits then
            table.sort(s.rows, function(a, b)
                if a.level ~= b.level then return a.level < b.level; end
                return a.name < b.name;
            end);
        else
        table.sort(s.rows, function(a, b)
            if (a.kind == 'sp') ~= (b.kind == 'sp') then return a.kind == 'sp'; end
            if (a.kind == 'merit') ~= (b.kind == 'merit') then return b.kind == 'merit'; end
            if a.level ~= b.level then return a.level < b.level; end
            return a.name < b.name;
        end);
        end
    end
    return sections;
end

function weapon_section(me, slot, label)
    local id = equipped_item_id(slot);
    local skill = 0;
    if id > 0 then skill = item_skill(id); end
    if slot == 0 and id == 0 then skill = 1; end   -- bare hands
    local data = WS_DATA[skill];
    if data == nil then return nil; end

    local value, capped = combat_skill(me, skill);
    -- Calibrate HasWeaponSkill on the first weapon skill once you have the skill for it.
    if ws_mode == nil and value >= data[1][2] then
        local res = ability_by_name(data[1][1]);
        local wid = tonumber(res_field(res, 'Id'));
        if wid ~= nil then
            local ok, v = pcall(function() return me.player:HasWeaponSkill(wid); end);
            ws_mode = ok and v == true;
        end
    end

    local rows, next_row = {}, nil;
    for _, w in ipairs(data) do
        local name, need, tag = w[1], w[2], w[3];
        local res = ability_by_name(name);
        local have = nil;
        if ws_mode then
            local wid = tonumber(res_field(res, 'Id'));
            if wid ~= nil then
                local ok, v = pcall(function() return me.player:HasWeaponSkill(wid); end);
                have = ok and v == true;
            end
        end
        local row = { k = 'ws', name = name, res = res, kind = 'ws', skill = skill, need = need, tag = tag, level = need };
        if tag == 'relic' or tag == 'mythic' then
            if have then row.status = 'ready';
            else row.status, row.note = 'na', (tag == 'relic') and 'Relic' or 'Mythic'; end
            if have or config.show_special_ws == true then rows[#rows + 1] = row; end
        else
            if have == true or (have == nil and value >= need and tag == nil) then
                row.status = 'ready';
            elseif value >= need then
                row.status, row.note = 'na', (tag == 'quest') and 'Quest' or 'Not learned';
            else
                row.status, row.note = 'locked', ('Skill %d'):fmt(need);
                if next_row == nil then next_row = row; end
            end
            rows[#rows + 1] = row;
        end
    end
    return {
        key = 'ws_' .. slot, title = label .. ':  ' .. (SKILL_NAMES[skill] or '?'), tag = SKILL_SHORT[skill],
        rows = rows, weapon = (id > 0) and item_name(id) or ((slot == 0) and 'Bare hands' or nil),
        skill = skill, value = value, capped = capped, next_row = next_row,
    };
end

function build_ws(me)
    local sections = {};
    local main = weapon_section(me, 0, 'Main');
    if main ~= nil then sections[#sections + 1] = main; end
    local ranged = weapon_section(me, 2, 'Ranged');
    if ranged ~= nil then sections[#sections + 1] = ranged; end
    return sections;
end

-- Blue magic you have set, read from the same memory Ashita's blusets
-- helper (and AzureCodex) uses. Returns { [spell id] = true }.
blu_offset_ptr = nil;

function blu_set_spells(me)
    local set = {};
    if me.job ~= 16 and me.sub ~= 16 then return set; end
    pcall(function()
        if blu_offset_ptr == nil then
            local found = ashita.memory.find(0, 0, 'C1E1032BC8B0018D????????????B9????????F3A55F5E5B', 10, 0);
            if found == nil or found == 0 then blu_offset_ptr = false; return; end
            blu_offset_ptr = found;
        end
        if not blu_offset_ptr then return; end
        local offset = ffi.cast('uint32_t*', blu_offset_ptr);
        local buf = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('inventory'));
        if buf == 0 then return; end
        buf = ashita.memory.read_uint32(buf);
        if buf == 0 then return; end
        local base = buf + offset[0] + ((me.job == 16) and 0x04 or 0xA0);
        for _, v in ipairs(ashita.memory.read_array(base, 0x14)) do
            v = tonumber(v) or 0;
            if v ~= 0 then set[v + 512] = true; end
        end
    end);
    return set;
end

-- Static spell list for your jobs (rebuilt when job / sub / level changes).
function build_spell_cache(me)
    calibrate_spells();
    local list, seen_names = {}, {};
    local rm = AshitaCore:GetResourceManager();
    for i = 1, 1023 do
        local s = nil;
        pcall(function() s = rm:GetSpellById(i); end);
        if s ~= nil then
            local stype = tonumber(res_field(s, 'Type')) or 0;
            local name = res_string(res_field(s, 'Name'));
            if (SCHOOL_OF[stype] ~= nil) and name ~= '' and name ~= '.' and not NOT_ON_SERVER[name] then
                local lm = spell_level(s, me.job);
                local ls = spell_level(s, me.sub);
                -- HorizonXI level changes (the client data has retail levels).
                local fix = SPELL_LEVEL_FIX[name];
                if fix ~= nil then
                    if fix[me.job] ~= nil then lm = fix[me.job]; end
                    if me.sub ~= nil and fix[me.sub] ~= nil then ls = fix[me.sub]; end
                end
                if lm ~= nil and lm > LEVEL_CAP then lm = nil; end
                if ls ~= nil and ls > SUB_MAX_LEVEL then ls = nil; end
                if (lm ~= nil or ls ~= nil) and not seen_names[name] then
                    seen_names[name] = true;
                    local index = tonumber(res_field(s, 'Index')) or i;
                    local tool = nil;
                    if stype == 4 then
                        for _, t in ipairs(NIN_TOOLS) do
                            if name:sub(1, #t[1]) == t[1] then tool = t[2]; break; end
                        end
                    end
                    list[#list + 1] = {
                        res = s, name = name, index = index, id = i, type = stype, lm = lm, ls = ls,
                        mp = tonumber(res_field(s, 'ManaCost')) or 0,
                        element = tonumber(res_field(s, 'Element')), tool = tool,
                    };
                end
            end
        end
    end
    return list;
end

function count_tools()
    local counts = {};
    pcall(function()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local max = tonumber(inv:GetContainerCountMax(0)) or 0;
        for i = 1, max do
            local it = inv:GetContainerItem(0, i);
            local id = it and tonumber(it.Id) or 0;
            if id > 0 and id ~= 65535 then
                local n = item_name(id);
                if n ~= nil then counts[n] = (counts[n] or 0) + (tonumber(it.Count) or 0); end
            end
        end
    end);
    return counts;
end

function build_magic(me)
    local key = table.concat({ me.job, me.lvl, me.sub, me.sublvl }, ':');
    if state.spell_cache == nil or state.spell_cache_key ~= key then
        state.spell_cache = build_spell_cache(me);
        state.spell_cache_key = key;
    end
    local tools = (config.show_tools ~= false) and count_tools() or {};
    local blu_set = blu_set_spells(me);

    local by_type = {};
    for _, sp in ipairs(state.spell_cache) do
        local main_ok = sp.lm ~= nil and me.lvl >= sp.lm;
        local sub_ok = sp.ls ~= nil and me.sublvl >= sp.ls;
        local learned = has_spell(me, sp.id);
        local row = {
            k = 'ma', name = sp.name, res = sp.res, kind = 'ma', index = sp.id, type = sp.type,
            mp = sp.mp, element = sp.element, lm = sp.lm, ls = sp.ls,
            level = sp.lm or sp.ls or 99,
            src = main_ok and 'main' or (sub_ok and 'sub' or ((sp.lm ~= nil) and 'main' or 'sub')),
        };
        if sp.type == BLUE_MAGIC_TYPE then
            -- Blue magic: usable only while it's set.
            -- Set byte + 512 = the spell's resource id (GetSpellById), the
            -- same lookup AzureCodex uses to list your set spells.
            if blu_set[sp.id] then
                row.status = 'ready';
            elseif learned and (main_ok or sub_ok) then
                row.status, row.note = 'unset', 'Not set';
            elseif learned then
                row.status, row.note = 'locked', ('Lv %d'):fmt(sp.lm or sp.ls or 0);
            else
                row.status, row.note = 'na', 'Not learned';
            end
        elseif main_ok or sub_ok then
            if learned then row.status = 'ready';
            else row.status, row.note = 'scroll', 'Scroll'; end
        else
            local need = sp.lm or sp.ls;
            row.status, row.note = 'locked', ('Lv %d'):fmt(need);
        end
        if sp.tool ~= nil then
            row.tool, row.tool_count = sp.tool, tools[sp.tool] or 0;
        end
        row.cd = spell_recast(sp.id);
        row.cd_key = 'ma' .. sp.id;
        if not (config.hide_unknown_spells == true and row.status ~= 'ready') then
            by_type[sp.type] = by_type[sp.type] or {};
            table.insert(by_type[sp.type], row);
        end
    end

    local sections = {};
    for _, school in ipairs(SCHOOLS) do
        local rows = by_type[school.type];
        if rows ~= nil and #rows > 0 then
            table.sort(rows, function(a, b)
                if config.magic_sort == 'name' then return a.name < b.name; end
                if a.level ~= b.level then return a.level < b.level; end
                return a.name < b.name;
            end);
            sections[#sections + 1] = { key = 'ma_' .. school.key, title = school.label, rows = rows };
        end
    end
    return sections;
end
