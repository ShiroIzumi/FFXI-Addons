--[[
    Azure Codex - ac/targettag.lua

    Target Tag: "Teaches:" / "Already Know:" for the targeted mob, and
    "... and has been used!" (on both lines) once that mob has used the spell.
]]

-- Small tag for the current target: "Teaches: <spell>" for spells you are
-- missing and "Already Know: <spell>" (green) for spells you have learned.
-- Reads only your target and the static location data; BLU main only.
-- Returns the target's name, server id and target index (nil when it is
-- not a mob).
function get_target_mob_name()
    local ok, name, server_id, target_index = pcall(function()
        local mm = AshitaCore:GetMemoryManager();
        local target = mm:GetTarget();
        local index = 0;
        if target:GetIsSubTargetActive() ~= 0 then
            index = target:GetTargetIndex(1);
        else
            index = target:GetTargetIndex(0);
        end
        index = tonumber(index) or 0;
        if index <= 0 then return nil; end
        local entity = mm:GetEntity();
        local flags = tonumber(entity:GetSpawnFlags(index)) or 0;
        if bit.band(flags, 0x10) == 0 then return nil; end
        return entity:GetName(index), tonumber(entity:GetServerId(index)) or 0, index;
    end);
    if not ok or name == nil or tostring(name) == '' then return nil; end
    return tostring(name), server_id, target_index;
end

-- ----------------------------------------------------------------------------
-- "and has been used!": spells a mob has actually used. Read from the 0x028
-- action packet, category 11 only (a mob FINISHED a TP move). Readying /
-- starting packets are ignored, so this only ever shows after the move was
-- used. Cleared when you change zones.
-- ----------------------------------------------------------------------------
mob_used = { zone = nil, by_mob = {} };

local USED_COLOR = { 1.00, 0.62, 0.20, 1.00 };

local function mob_used_reset_if_zoned()
    local zone_id = safe_current_zone_id();
    if mob_used.zone ~= zone_id then
        mob_used.zone = zone_id;
        mob_used.by_mob = {};
    end
end

-- Monster TP move name from the action id (monster skills use a +256 offset).
local function mob_ability_name(id)
    id = tonumber(id) or 0;
    local rm = AshitaCore:GetResourceManager();
    if rm == nil then return nil; end
    if id >= 256 then
        local ok, name = pcall(function() return rm:GetString('monsters.abilities', id - 256); end);
        if ok and type(name) == 'string' and name ~= '' then return name; end
    end
    local ok, name = pcall(function() return rm:GetString('monsters.abilities', id); end);
    if ok and type(name) == 'string' and name ~= '' then return name; end
    return nil;
end

-- 0x028: actor id at bit 40 (32 bits), category at bit 82 (4 bits), action
-- id at bit 86 (17 bits). Passive read only.
function note_mob_ability(e)
    local data = e.data_raw or e.data_modified or e.data;
    if data == nil then return; end
    local ok, actor, category, param = pcall(function()
        return ashita.bits.unpack_be(data, 0, 40, 32), ashita.bits.unpack_be(data, 0, 82, 4), ashita.bits.unpack_be(data, 0, 86, 17);
    end);
    if not ok or category ~= 11 then return; end
    local name = mob_ability_name(param);
    if name == nil then return; end

    mob_used_reset_if_zoned();
    local key = normalize_name(name);
    local used = mob_used.by_mob[actor];
    if used == nil then
        used = {};
        mob_used.by_mob[actor] = used;
    end
    used[key] = true;
end

-- A mob that dies respawns with the same server id, so its record is
-- dropped when it is defeated (0x029) ...
function mob_used_forget(server_id)
    server_id = tonumber(server_id);
    if server_id ~= nil then mob_used.by_mob[server_id] = nil; end
end

-- ... and whenever it is targeted unclaimed at full HP (a fresh spawn, for
-- example one killed by someone outside your party).
local function mob_used_check_fresh(server_id, target_index)
    if server_id == nil or server_id == 0 or mob_used.by_mob[server_id] == nil then return; end
    local ok, fresh = pcall(function()
        local entity = AshitaCore:GetMemoryManager():GetEntity();
        local hpp = tonumber(entity:GetHPPercent(target_index)) or 0;
        local claim = tonumber(entity:GetClaimStatus(target_index)) or 0;
        return hpp >= 100 and claim == 0;
    end);
    if ok and fresh then mob_used.by_mob[server_id] = nil; end
end

local function mob_has_used(server_id, spell)
    if server_id == nil or server_id == 0 then return false; end
    mob_used_reset_if_zoned();
    local used = mob_used.by_mob[server_id];
    return used ~= nil and used[spell._key or normalize_name(spell.name)] == true;
end

-- Every spell each mob teaches, by zone, known or not. The location data is
-- static, so this is built once; known / missing is checked when drawn.
teach_index = nil;

function get_teach_index()
    if teach_index ~= nil then return teach_index; end
    local by_mob = {};
    for _, spell in ipairs(spells) do
        for _, entry in ipairs(locations.get(spell.name) or {}) do
            local zone_id = tonumber(entry.zone);
            if zone_id ~= nil then
                by_mob[zone_id] = by_mob[zone_id] or {};
                for _, mob in ipairs(entry.mobs or {}) do
                    local mob_key = tostring(mob):lower();
                    local list = by_mob[zone_id][mob_key];
                    if list == nil then
                        list = {};
                        by_mob[zone_id][mob_key] = list;
                    end
                    local dup = false;
                    for _, existing in ipairs(list) do
                        if existing == spell then dup = true; break; end
                    end
                    if not dup then list[#list + 1] = spell; end
                end
            end
        end
    end
    teach_index = by_mob;
    return teach_index;
end

KNOWN_TAG_BG   = { 0.10, 0.40, 0.18, 0.94 };
KNOWN_TAG_TEXT = { 0.86, 1.00, 0.88, 1.00 };
KNOWN_TAG_HEAD = { 0.62, 0.95, 0.66, 1.00 };

function draw_target_tag()
    if not state.target_tag[1] then return; end
    if safe_blu_level() == nil then return; end

    local zone_id = safe_current_zone_id();
    if zone_id == nil then return; end
    local name, server_id, target_index = get_target_mob_name();
    if name == nil then return; end
    mob_used_check_fresh(server_id, target_index);

    local zone_mobs = get_teach_index()[zone_id];
    local list = zone_mobs and zone_mobs[name:lower()] or nil;
    if list == nil or #list == 0 then return; end

    -- Split into spells you are missing and spells you already know.
    local missing, known = {}, {};
    for _, spell in ipairs(list) do
        if is_known(spell.name) then
            known[#known + 1] = spell;
        else
            missing[#missing + 1] = spell;
        end
    end

    if state.target_tag_apply_pos then
        imgui.SetNextWindowPos({ state.target_tag_x, state.target_tag_y });
        state.target_tag_apply_pos = false;
    end

    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoFocusOnAppearing or 0, ImGuiWindowFlags_NoSavedSettings or 0);
    if state.target_tag_locked[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoInputs or 0);
    end

    -- Everything already known: the whole tag turns green.
    local all_known = #missing == 0;

    push_theme();
    if all_known then imgui.PushStyleColor(ImGuiCol_WindowBg, KNOWN_TAG_BG); end
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);
    if imgui.Begin('Azure Codex - Target Tag###azure_target_tag', nil, flags) then
        imgui.PushFont(nil, imgui.GetFontSize() * state.font_scale[1]);

        if #missing > 0 then
            imgui.TextColored(state.header_color, 'Teaches:');
            for _, spell in ipairs(missing) do
                imgui.SameLine();
                local learnable = get_spell_display_state(spell) == 'learnable';
                local color = learnable and state.learnable_color or state.unknown_color;
                imgui.TextColored(color, tostring(spell.name));
                -- Only after this mob has actually used it.
                if mob_has_used(server_id, spell) then
                    imgui.SameLine();
                    imgui.TextColored(USED_COLOR, 'and has been used!');
                end
            end
        end

        if #known > 0 then
            if not all_known then
                -- Some missing, some known: a green strip behind this line.
                local sx, sy = imgui.GetCursorScreenPos();
                local line_h = imgui.GetTextLineHeight();
                local spacing = 8;
                pcall(function() spacing = tonumber(imgui.GetStyle().ItemSpacing.x) or 8; end);
                local width = tonumber((imgui.CalcTextSize('Already Know:'))) or 0;
                local used_w = tonumber((imgui.CalcTextSize('and has been used!'))) or 0;
                for _, spell in ipairs(known) do
                    width = width + spacing + (tonumber((imgui.CalcTextSize(tostring(spell.name)))) or 0);
                    if mob_has_used(server_id, spell) then width = width + spacing + used_w; end
                end
                imgui.GetWindowDrawList():AddRectFilled({ sx - 4, sy - 1 }, { sx + width + 4, sy + line_h + 1 },
                    imgui.GetColorU32(KNOWN_TAG_BG), 3.0);
            end
            imgui.TextColored(KNOWN_TAG_HEAD, 'Already Know:');
            for _, spell in ipairs(known) do
                imgui.SameLine();
                imgui.TextColored(KNOWN_TAG_TEXT, tostring(spell.name));
                -- Helping someone farm it: shows once this mob has used it.
                if mob_has_used(server_id, spell) then
                    imgui.SameLine();
                    imgui.TextColored(USED_COLOR, 'and has been used!');
                end
            end
        end

        imgui.PopFont();

        local x, y = imgui.GetWindowPos();
        x, y = tonumber(x), tonumber(y);
        if x and y and (math.abs(x - state.target_tag_x) >= 1 or math.abs(y - state.target_tag_y) >= 1) then
            state.target_tag_x, state.target_tag_y = x, y;
            state.settings_dirty = true;
        end
    end
    imgui.End();
    imgui.PopStyleVar(1);
    if all_known then imgui.PopStyleColor(1); end
    pop_theme();
end
