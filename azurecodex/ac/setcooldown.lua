--[[
    Azure Codex - ac/setcooldown.lua

    Spell set cooldown: the 60-second wait after setting new Blue Magic.
]]

-- ----------------------------------------------------------------------------
-- Spell set cooldown: after you set new Blue Magic (from Azure Codex or the
-- in-game menu), the newly set spells can't be cast for a while. The server
-- doesn't send that wait to the game's recast timers, so Azure Codex times it
-- itself from the moment each new spell appears in your set (60 seconds).
-- Normal recasts after casting a spell are not shown.
-- ----------------------------------------------------------------------------
SET_SPELL_WAIT = 60;
setcd = { sig = nil, checked_at = 0, added_at = {}, total = 0, remaining = 0, cooling = {}, placed = false };

function spell_recast_seconds(spell)
    local id = state.resource_ids[spell._key or normalize_name(spell.name)];
    if id == nil then return 0; end
    local ok, value = pcall(function()
        return AshitaCore:GetMemoryManager():GetRecast():GetSpellTimer(id);
    end);
    if not ok then return 0; end
    return math.max(0, (tonumber(value) or 0) / 60);
end

function update_set_cooldown()
    local now = os.clock();
    if now - setcd.checked_at < 0.25 then return; end
    setcd.checked_at = now;
    build_resource_cache();

    local list = get_equipped_spells();
    local keys, present = {}, {};
    for _, spell in ipairs(list) do
        local k = tostring(spell._key or spell.name);
        keys[#keys + 1] = k;
        present[k] = true;
    end
    table.sort(keys);
    local sig = table.concat(keys, ',');

    if setcd.sig ~= sig then
        local old = setcd.sig;
        setcd.sig = sig;
        -- The first read, zoning (an empty set) and job changes are not
        -- spell changes: only time spells added to an existing set.
        if old ~= nil and old ~= '' and sig ~= '' then
            local before = {};
            for k in old:gmatch('[^,]+') do before[k] = true; end
            for _, k in ipairs(keys) do
                if not before[k] then setcd.added_at[k] = now; end
            end
        end
        for k in pairs(setcd.added_at) do
            if not present[k] then setcd.added_at[k] = nil; end
        end
    end

    -- Remaining wait per newly set spell (only the 60s set-change wait; normal
    -- spell recasts after casting are left to your hotbar / timers).
    local longest, cooling = 0, {};
    for _, spell in ipairs(list) do
        local k = tostring(spell._key or spell.name);
        local left = 0;
        local t = setcd.added_at[k];
        if t ~= nil then
            left = SET_SPELL_WAIT - (now - t);
            if left <= 0 then setcd.added_at[k] = nil; left = 0; end
        end
        if left > 0 then
            cooling[#cooling + 1] = { name = spell.name, left = left };
            if left > longest then longest = left; end
        end
    end
    table.sort(cooling, function(x, y) return x.left > y.left; end);
    setcd.cooling = cooling;
    setcd.remaining = longest;
    if longest <= 0 then
        setcd.total = 0;
    elseif longest > setcd.total then
        setcd.total = longest;
    end
end

function set_cooldown_active()
    return setcd.remaining > 0 and setcd.total > 0;
end

-- Tag like the "Teaches:" one, shown only while newly set spells are on
-- cooldown. Drag it anywhere; it starts just under the Teaches tag.
function draw_set_cooldown_window()
    if not set_cooldown_active() then return; end

    if not setcd.placed then
        local scale = tonumber(state.font_scale[1]) or 1.0;
        imgui.SetNextWindowPos({ state.target_tag_x, state.target_tag_y + math.floor(38 * scale) }, { 0, 0 });
        setcd.placed = true;
    end
    window_drag_apply('setcd');

    push_theme();
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, state.border[1] and 1.0 or 0.0);
    local flags = bit.bor(ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoFocusOnAppearing or 0);
    if imgui.Begin('Azure Codex - Spell Set Cooldown###azure_set_cooldown', nil, flags) then
        local scale = tonumber(state.font_scale[1]) or 1.0;
        imgui.PushFont(nil, imgui.GetFontSize() * scale);

        imgui.TextColored(state.header_color, 'Spells ready in:');
        imgui.SameLine();
        imgui.TextColored(state.unknown_color, ('%ds'):fmt(math.ceil(setcd.remaining)));

        local bar_w = math.floor(240 * scale);
        local sx, sy = imgui.GetCursorScreenPos();
        local dl = imgui.GetWindowDrawList();
        local frac = math.max(0, math.min(1, setcd.remaining / math.max(0.01, setcd.total)));
        dl:AddRectFilled({ sx, sy + 2 }, { sx + bar_w, sy + 6 }, imgui.GetColorU32({ 1.0, 1.0, 1.0, 0.08 }), 2.0);
        dl:AddRectFilled({ sx, sy + 2 }, { sx + math.max(3, bar_w * frac), sy + 6 }, imgui.GetColorU32(accent()), 2.0);
        imgui.Dummy({ bar_w, 8 });

        window_drag('setcd', false);
        imgui.PopFont();
    end
    imgui.End();
    imgui.PopStyleVar(1);
    pop_theme();
end
