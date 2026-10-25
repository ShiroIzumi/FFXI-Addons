--[[
    WhatsMyDamage - core/roster.lua

    Who counts: you (always, also solo), your party (slots 1-5), and the
    alliance (slots 6-17) when that option is on, plus their pets. Read from
    party memory at most 4 times a second; the tracker asks it for every
    action packet.
]]

require('common');
local data = require('core.data');

local roster = {
    members = {},     -- server id -> { name, job, slot, alliance, me }
    pets = {},        -- pet server id -> owner server id
    pet_names = {},   -- pet server id -> pet name
    me = 0,
    zone = 0,
    next = 0,
    alliance = false, -- track alliance members (setting)
};

function roster.update(force)
    local now = os.clock();
    if not force and now < roster.next then return; end
    roster.next = now + 0.25;
    local members, pets, pet_names = {}, {}, {};
    pcall(function()
        local mm = AshitaCore:GetMemoryManager();
        local p = mm:GetParty();
        local em = mm:GetEntity();
        roster.me = tonumber(p:GetMemberServerId(0)) or 0;
        roster.zone = tonumber(p:GetMemberZone(0)) or 0;
        local last = roster.alliance and 17 or 5;
        for slot = 0, last do
            if slot == 0 or p:GetMemberIsActive(slot) == 1 then
                local sid = tonumber(p:GetMemberServerId(slot)) or 0;
                local name = p:GetMemberName(slot);
                if sid ~= 0 and type(name) == 'string' and name ~= '' then
                    local job = data.job(p:GetMemberMainJob(slot));
                    local m = { name = name, job = job, slot = slot, alliance = slot >= 6, me = slot == 0 };
                    members[sid] = m;
                    -- Their pet (only when the game has their entity loaded).
                    local tidx = tonumber(p:GetMemberTargetIndex(slot)) or 0;
                    if tidx > 0 then
                        pcall(function()
                            local pidx = tonumber(em:GetPetTargetIndex(tidx)) or 0;
                            if pidx > 0 then
                                local psid = tonumber(em:GetServerId(pidx)) or 0;
                                if psid ~= 0 then
                                    pets[psid] = sid;
                                    local pn = em:GetName(pidx);
                                    if type(pn) == 'string' and pn ~= '' then pet_names[psid] = pn; end
                                end
                            end
                        end);
                    end
                end
            end
        end
    end);
    roster.members = members;
    -- Pets stay known after they are released (their damage was already counted).
    for k, v in pairs(pets) do roster.pets[k] = v; end
    for k, v in pairs(pet_names) do roster.pet_names[k] = v; end
end

-- Is this server id one of ours (a tracked member or one of their pets)?
-- Returns 'member' | 'pet' | nil.
function roster.kind(sid)
    if roster.members[sid] ~= nil then return 'member'; end
    local owner = roster.pets[sid];
    if owner ~= nil and roster.members[owner] ~= nil then return 'pet'; end
    return nil;
end

-- A monster: a non-player server id that isn't one of our pets.
function roster.is_mob(sid)
    sid = tonumber(sid) or 0;
    if sid < 0x01000000 then return false; end
    if roster.pets[sid] ~= nil then return false; end
    return true;
end

function roster.reset_pets()
    roster.pets, roster.pet_names = {}, {};
end

return roster;
