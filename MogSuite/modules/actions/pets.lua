--[[
    MogSuite - modules/actions/pets.lua

    Your pet (avatar, spirit, wyvern, automaton, beast), blood pacts and the pet tabs,
    and the list refresh.
]]

-- ============================================================================
-- Summons: your avatar / spirit and its blood pacts
-- ============================================================================

-- Your pet, if one is out: { name, hpp, mpp }.
function read_pet(me)
    local pet = nil;
    pcall(function()
        local mm = AshitaCore:GetMemoryManager();
        local ent = mm:GetEntity();
        local my_idx = tonumber(mm:GetParty():GetMemberTargetIndex(0)) or 0;
        if my_idx == 0 then return; end
        local pidx = tonumber(ent:GetPetTargetIndex(my_idx)) or 0;
        if pidx == 0 then return; end
        local name = ent:GetName(pidx);
        if name == nil or name == '' then return; end
        pet = { index = pidx, name = tostring(name), hpp = tonumber(ent:GetHPPercent(pidx)) };
    end);
    if pet ~= nil and me ~= nil then
        pcall(function() pet.mpp = tonumber(me.player:GetPetMPPercent()); end);
        pcall(function() pet.tp = tonumber(me.player:GetPetTP()); end);
    end
    return pet;
end

function has_buff(me, id)
    local yes = false;
    pcall(function()
        local buffs = me.player:GetBuffs();
        if type(buffs) == 'table' then
            for _, b in pairs(buffs) do
                if tonumber(b) == id then yes = true; return; end
            end
        else
            for i = 0, 31 do
                if tonumber(buffs[i]) == id then yes = true; return; end
            end
        end
    end);
    return yes;
end

-- Your summoner level for pacts / commands: main job, else support (cap 37).
function smn_level(me)
    if me.job == SMN_JOB then return me.lvl, me.job; end
    if me.sub == SMN_JOB then return math.min(me.sublvl, SUB_MAX_LEVEL), me.sub; end
    return 0, nil;
end

function bp_row(me, b, lvl, af_up)
    local name, need, bp, tag = b[1], b[2], b[3], b[4];
    local res = ability_by_name(name);
    local row = { k = 'bp', name = name, res = res, kind = (tag == 'af') and 'af' or bp, bp = bp, tag = tag,
        level = need, job = SMN_JOB, src = (me.job == SMN_JOB) and 'main' or 'sub' };
    if tag == 'af' then
        if lvl < need then row.status, row.note = 'locked', ('Lv %d'):fmt(need);
        elseif af_up then row.status = 'ready';
        else row.status, row.note = 'na', 'Astral Flow'; end
    elseif tag == 'merit' then
        local have = has_ability(me, res);
        if have and lvl >= need then row.status = 'ready';
        else row.status, row.note = 'na', 'Avatar trial'; end
    elseif lvl >= need then
        row.status = 'ready';
    else
        row.status, row.note = 'locked', ('Lv %d'):fmt(need);
    end
    local timer = tonumber(res_field(res, 'RecastTimerId'));
    if timer ~= nil and timer ~= 0 then
        row.cd = state.ja_cd[timer] or 0;
        row.cd_key = 'ja' .. timer;
    end
    row.mp = tonumber(res_field(res, 'ManaCost')) or 0;
    return row;
end

-- Which of your pet jobs this pet belongs to.
function pet_owner(me, pet)
    if pet == nil then return nil; end
    if BLOOD_PACTS[pet.name] or SPIRITS[pet.name] then return SMN_JOB; end
    for _, j in ipairs({ me.job, me.sub }) do
        if j ~= SMN_JOB and pet_job_active(me, j) then return j; end
    end
    return nil;
end

function sort_ability_rows(rows)
    table.sort(rows, function(a, b)
        if (a.kind == 'sp') ~= (b.kind == 'sp') then return a.kind == 'sp'; end
        if (a.kind == 'merit') ~= (b.kind == 'merit') then return b.kind == 'merit'; end
        if a.level ~= b.level then return a.level < b.level; end
        return a.name < b.name;
    end);
end

-- Wyvern / Automaton / Beast tabs: pet card + commands while your pet is
-- out, maneuvers (PUP), and the job's pet abilities.
function build_pet_job(me, job)
    local sections = {};
    local info = PET_JOBS[job];
    if not pet_job_active(me, job) then return sections; end
    local lvl, src;
    if me.job == job then lvl, src = me.lvl, 'main';
    else lvl, src = math.min(me.sublvl, SUB_MAX_LEVEL), 'sub'; end

    local cmds, mans, others = {}, {}, {};
    for _, a in ipairs(JOB_ABILITIES[job] or {}) do
        local kind = a[3];
        local want = kind == 'pet' or info.abilities == nil or info.abilities[a[1]] == true;
        if want and (src == 'main' or (kind ~= 'sp' and kind ~= 'merit' and a[2] <= SUB_MAX_LEVEL)) then
            if src == 'main' or a[2] <= me.sublvl or config.show_sub_locked ~= false then
                local row = ability_row(me, a, job, lvl, src);
                if kind == 'pet' then cmds[#cmds + 1] = row;
                elseif kind == 'man' then mans[#mans + 1] = row;
                else others[#others + 1] = row; end
            end
        end
    end
    sort_ability_rows(cmds);
    sort_ability_rows(mans);
    sort_ability_rows(others);

    local key = 'pj' .. job;
    local tag = JOB_SHORT[job];
    local title = (JOB_NAMES[job] or '?') .. ((src == 'sub') and '  (support)' or '');
    local pet = state.pet;
    if pet ~= nil and pet.owner == job then
        sections[#sections + 1] = { key = key .. '_pet', title = pet.name, tag = 'PET', rows = cmds, pet_card = true };
        if #mans > 0 then sections[#sections + 1] = { key = key .. '_man', title = 'Maneuvers', tag = tag, rows = mans }; end
        if #others > 0 then sections[#sections + 1] = { key = key .. '_ja', title = title, tag = tag, rows = others }; end
    else
        if #others > 0 then sections[#sections + 1] = { key = key .. '_ja', title = title, tag = tag, rows = others }; end
        if #cmds > 0 then sections[#sections + 1] = { key = key .. '_cmd', title = 'Pet commands', tag = tag, rows = cmds }; end
        if #mans > 0 then sections[#sections + 1] = { key = key .. '_man', title = 'Maneuvers', tag = tag, rows = mans }; end
    end
    return sections;
end

-- Summons tab: with a pet out, its commands and blood pacts first, then
-- every summon (collapsed). With no pet out, just the summons.
function build_summons(me, magic_sections)
    local sections = {};
    local lvl, job = smn_level(me);
    if job == nil or not pet_job_active(me, SMN_JOB) then return sections; end
    local pet = state.pet;
    if pet ~= nil and pet.owner ~= SMN_JOB then pet = nil; end

    local summon_rows = {};
    for _, sec in ipairs(magic_sections or {}) do
        if sec.key == 'ma_summon' then summon_rows = sec.rows; end
    end

    if pet ~= nil then
        local pacts = BLOOD_PACTS[pet.name];
        local is_spirit = SPIRITS[pet.name] == true;
        -- Pet commands.
        local cmds = {};
        for _, a in ipairs(JOB_ABILITIES[SMN_JOB]) do
            local n = a[1];
            local want = a[3] == 'pet'
                or (n == "Avatar's Favor" and pacts ~= nil)
                or (n == 'Elemental Siphon' and is_spirit);
            if want then
                local row = ability_row(me, a, job, lvl, (me.job == SMN_JOB) and 'main' or 'sub');
                if a[2] <= lvl or job == me.job then cmds[#cmds + 1] = row; end
            end
        end
        table.sort(cmds, function(a, b)
            if (a.kind == 'pet') ~= (b.kind == 'pet') then return a.kind == 'pet'; end
            if a.level ~= b.level then return a.level < b.level; end
            return a.name < b.name;
        end);
        sections[#sections + 1] = { key = 'sm_cmd', title = pet.name, tag = 'PET', rows = cmds, pet_card = true };
        if pacts ~= nil then
            local af_up = has_buff(me, ASTRAL_FLOW_BUFF);
            local rage, ward = {}, {};
            for _, b in ipairs(pacts) do
                local row = bp_row(me, b, lvl, af_up);
                if b[3] == 'ward' then ward[#ward + 1] = row; else rage[#rage + 1] = row; end
            end
            local function by_level(a, b)
                if (a.tag == 'af') ~= (b.tag == 'af') then return b.tag == 'af'; end
                if a.level ~= b.level then return a.level < b.level; end
                return a.name < b.name;
            end
            table.sort(rage, by_level);
            table.sort(ward, by_level);
            if #rage > 0 then sections[#sections + 1] = { key = 'sm_rage', title = 'Blood Pact: Rage', tag = 'RAGE', rows = rage }; end
            if #ward > 0 then sections[#sections + 1] = { key = 'sm_ward', title = 'Blood Pact: Ward', tag = 'WARD', rows = ward }; end
        end
        if #summon_rows > 0 then
            sections[#sections + 1] = { key = 'sm_summons_out', title = 'Summons', rows = summon_rows, split = true, default_collapsed = true };
        end
    elseif #summon_rows > 0 then
        sections[#sections + 1] = { key = 'sm_summons', title = 'Summons', rows = summon_rows, split = true };
    end
    return sections;
end

-- Rebuilds the lists about twice a second (recasts update every frame).
function refresh_lists(me)
    local key = table.concat({ me.job, me.lvl, me.sub, me.sublvl, equipped_item_id(0), equipped_item_id(2),
        tostring(config.show_sub_locked), tostring(config.show_special_ws), tostring(config.hide_unknown_spells),
        tostring(config.magic_sort), tostring(config.show_tools),
        state.pet and state.pet.name or '-', tostring(state.pet ~= nil and has_buff(me, ASTRAL_FLOW_BUFF)) }, ':');
    local now = os.clock();
    if state.lists_key == key and now - state.lists_at < 0.5 then
        -- Keep the recast numbers live between rebuilds.
        for _, tab in pairs(state.lists) do
            for _, sec in ipairs(tab) do
                for _, row in ipairs(sec.rows) do
                    if row.k == 'ma' then
                        row.cd = spell_recast(row.index);
                    elseif row.cd_key ~= nil then
                        local timer = tonumber(row.cd_key:sub(3));
                        row.cd = state.ja_cd[timer] or 0;
                    end
                end
            end
        end
        return;
    end
    calibrate_ja(me);
    local magic = build_magic(me);
    state.lists = {
        abilities = build_abilities(me),
        ws = build_ws(me),
        magic = magic,
        summons = build_summons(me, magic),
        wyvern = build_pet_job(me, DRG_JOB),
        automaton = build_pet_job(me, PUP_JOB),
        beast = build_pet_job(me, BST_JOB),
    };
    state.lists_key = key;
    state.lists_at = now;
end
