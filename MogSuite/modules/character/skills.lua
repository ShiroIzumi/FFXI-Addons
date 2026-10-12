--[[
    MogSuite - modules/character/skills.lua

    The Skills tab: combat, magic and crafting skills (alphabetical) with caps and
    the skill-ups you gained this session.
]]

-- ============================================================================
-- Skills tab pieces
-- ============================================================================

-- Skill cap is the higher of the main job's cap at the main level and the
-- support job's cap at the support level (e.g. WAR/NIN can skill Katana).
function skill_cap(main_job, level, sub_job, sub_level, skill)
    local main_cap = skilldata.get_cap(skilldata.get_rank(main_job, skill.name), level);
    local sub_cap = skilldata.get_cap(skilldata.get_rank(sub_job, skill.name), sub_level);
    local cap = main_cap;
    if sub_cap ~= nil and (cap == nil or sub_cap > cap) then
        cap = sub_cap;
    end
    return cap;
end

function format_skill(value)
    value = tonumber(value) or 0;
    if value == math.floor(value) then return tostring(math.floor(value)); end
    return ('%.1f'):fmt(value);
end

-- ----------------------------------------------------------------------------
-- Skill-up session tracker. Fed by 0x029 messages 38 ("skill rises 0.1
-- points", param2 = tenths) / 53 ("reaches level"), with a chat-text
-- fallback. Session only; Reset clears it.
-- ----------------------------------------------------------------------------
CRAFT_SKILL_ID_BASE = 48; -- Fishing = 48 ... Cooking = 56

skill_names_by_id = nil;
function skill_lookup()
    if skill_names_by_id ~= nil then return skill_names_by_id; end
    skill_names_by_id = { by_id = {}, by_name = {} };
    local function add(id, name)
        skill_names_by_id.by_id[id] = name;
        skill_names_by_id.by_name[name:lower()] = id;
    end
    for _, sk in ipairs(skilldata.weapon_skills) do add(sk.index, sk.name); end
    for _, sk in ipairs(skilldata.magic_skills) do add(sk.index, sk.name); end
    for _, cr in ipairs(skilldata.craft_skills) do add(CRAFT_SKILL_ID_BASE + cr.index, cr.name); end
    return skill_names_by_id;
end

skillups = {
    started = os.time(),
    by_id = {},          -- [skill_id] = { tenths = n, count = n }
    total_tenths = 0,
    total_count = 0,
    last = nil,          -- { id, tenths, time }
    packet_at = {},      -- [skill_id] = os.clock() of the last packet skill-up
};

function reset_skillups()
    skillups.started = os.time();
    skillups.by_id = {};
    skillups.total_tenths = 0;
    skillups.total_count = 0;
    skillups.last = nil;
end

function record_skillup(skill_id, tenths)
    skill_id = tonumber(skill_id) or 0;
    tenths = tonumber(tenths) or 0;
    if skill_id <= 0 or tenths <= 0 or tenths > 50 then return; end

    local entry = skillups.by_id[skill_id];
    if entry == nil then
        entry = { tenths = 0, count = 0 };
        skillups.by_id[skill_id] = entry;
    end
    entry.tenths = entry.tenths + tenths;
    entry.count = entry.count + 1;
    skillups.total_tenths = skillups.total_tenths + tenths;
    skillups.total_count = skillups.total_count + 1;
    skillups.last = { id = skill_id, tenths = tenths, time = os.time() };
end

function skillup_gain_text(skill_id)
    local entry = skill_id and skillups.by_id[skill_id] or nil;
    if entry == nil or entry.tenths <= 0 then return nil; end
    return ('+%.1f'):fmt(entry.tenths / 10);
end

function format_ago(timestamp)
    local seconds = math.max(0, os.time() - (tonumber(timestamp) or os.time()));
    if seconds < 60 then return ('%ds ago'):fmt(seconds); end
    if seconds < 3600 then return ('%dm %02ds ago'):fmt(math.floor(seconds / 60), seconds % 60); end
    return ('%dh %02dm ago'):fmt(math.floor(seconds / 3600), math.floor((seconds % 3600) / 60));
end

function draw_skillup_summary()
    local scale = state.overall_scale[1];
    imgui.TextColored(state.muted_color, 'This session:');
    imgui.SameLine();
    if skillups.total_count == 0 then
        imgui.TextColored(state.muted_color, 'no skill-ups yet');
    else
        imgui.TextColored(state.good_color, ('%d skill-ups (+%.1f)'):fmt(skillups.total_count, skillups.total_tenths / 10));
        if skillups.last ~= nil then
            local name = skill_lookup().by_id[skillups.last.id] or ('Skill ' .. tostring(skillups.last.id));
            imgui.SameLine();
            imgui.TextColored(state.muted_color, ('  last: %s +%.1f, %s'):fmt(name, skillups.last.tenths / 10, format_ago(skillups.last.time)));
        end
    end
    imgui.SameLine();
    local label = 'Reset##cs_skillups_reset';
    if imgui.SmallButton(label) then
        reset_skillups();
    end
    require_width(text_width('This session:') + text_width('00 skill-ups (+0.0)') + 60 * scale);
end

-- Builds the rows for one section:
-- { name, current, cap, usable, capped_flag, skill_id }.
function combat_rows(player, main_job, level, sub_job, sub_level, list)
    local rows = {};
    for _, skill in ipairs(list) do
        local current = math.floor(skill_value(player, skill.index));
        local cap = skill_cap(main_job, level, sub_job, sub_level, skill);
        rows[#rows + 1] = { skill.name, current, cap, cap ~= nil, false, skill.index };
    end
    table.sort(rows, function(a, b) return a[1] < b[1]; end);
    return rows;
end

function craft_rows(player)
    local rows = {};
    for _, craft in ipairs(skilldata.craft_skills) do
        local current, capped_flag = craft_value(player, craft.index);
        local cap = craft.cap or 100;
        -- A craft you have never leveled counts as "unused". [5] = the
        -- client reports this craft as capped for its current rank.
        rows[#rows + 1] = { craft.name, current, cap, (current > 0) or capped_flag, capped_flag, CRAFT_SKILL_ID_BASE + craft.index };
    end
    table.sort(rows, function(a, b) return a[1] < b[1]; end);
    return rows;
end

function draw_skill_section(title, rows, width)
    local scale = state.overall_scale[1];
    local show_all = state.show_unusable[1] == true;

    local visible = {};
    local to_go = 0;
    local name_w = 0;
    for _, row in ipairs(rows) do
        if row[4] or show_all then
            visible[#visible + 1] = row;
            local gain = skillup_gain_text(row[6]);
            name_w = math.max(name_w, text_width(row[1]) + (gain and (text_width(gain) + 6 * scale) or 0));
        end
        if row[4] and row[3] ~= nil and row[2] < row[3] and not row[5] then
            to_go = to_go + 1;
        end
    end

    column_section(title, (to_go > 0) and (('%d to go'):fmt(to_go)) or 'all capped', width);

    if #visible == 0 then
        imgui.TextColored(state.muted_color, 'Nothing to show.');
        return;
    end

    local value_w = text_width('000.0 / 000');
    local gap = 10 * scale;
    name_w = name_w + gap;
    local bar_w = math.max(20 * scale, width - name_w - value_w - gap);
    local bar_h = 5 * scale;
    local lh = line_height();

    for _, row in ipairs(visible) do
        local name, current, cap, usable = row[1], row[2], row[3], row[4];
        local color, frac;
        if not usable or cap == nil then
            color = with_alpha(state.muted_color, 0.70);
            frac = 0;
        elseif current >= cap or row[5] then
            color = state.good_color;
            frac = (cap > 0) and math.min(1, current / cap) or 1;
            if current >= cap then frac = 1; end
        else
            color = state.warn_color;
            frac = (cap > 0) and (current / cap) or 0;
        end

        local base_x = imgui.GetCursorPosX();
        imgui.TextColored(usable and UI_BRIGHT or with_alpha(state.muted_color, 0.70), name);
        local gain = skillup_gain_text(row[6]);
        if gain ~= nil then
            imgui.SameLine(0, 6 * scale);
            imgui.TextColored(state.good_color, gain);
        end

        imgui.SameLine();
        local cy = imgui.GetCursorPosY();
        imgui.SetCursorPosX(base_x + name_w);
        imgui.SetCursorPosY(cy + math.max(0, (lh - bar_h) * 0.5));
        draw_bar(bar_w, bar_h, frac, color);

        imgui.SameLine();
        imgui.SetCursorPosY(cy);
        local display = cap and (('%s / %d'):fmt(format_skill(current), cap)) or (('%s / --'):fmt(format_skill(current)));
        text_right(display, color, base_x + width);
    end
end

function draw_skills_tab(player, main_job, main_level, sub_job, sub_level)
    local scale = state.overall_scale[1];

    -- Filter row.
    if draw_toggle_button('Combat', 'cs_f_combat', state.skill_combat[1] == true) then
        state.skill_combat[1] = not state.skill_combat[1];
        state.settings_dirty = true;
    end
    tip('Show weapon and combat skills');
    imgui.SameLine(0, 4);
    if draw_toggle_button('Magic', 'cs_f_magic', state.skill_magic[1] == true) then
        state.skill_magic[1] = not state.skill_magic[1];
        state.settings_dirty = true;
    end
    tip('Show magic skills');
    imgui.SameLine(0, 4);
    if draw_toggle_button('Crafting', 'cs_f_craft', state.skill_craft[1] == true) then
        state.skill_craft[1] = not state.skill_craft[1];
        state.settings_dirty = true;
    end
    tip('Show crafting skills');

    -- Measured on the fresh line (before SameLine) so it spans the window.
    local label = 'Show unusable';
    local start_x = imgui.GetCursorPosX();
    local full_w = avail_width();
    require_width(text_width('Combat') + text_width('Magic') + text_width('Crafting') + text_width(label) + 110 * scale);
    imgui.SameLine();
    local style_pad = 16 * scale;
    imgui.SetCursorPosX(math.max(imgui.GetCursorPosX() + 8 * scale, start_x + full_w - text_width(label) - style_pad));
    if draw_toggle_button(label, 'cs_f_all', state.show_unusable[1] == true) then
        state.show_unusable[1] = not state.show_unusable[1];
        state.settings_dirty = true;
    end
    tip('Also show skills your current jobs cannot use (greyed out)');
    draw_skillup_summary();
    imgui.Spacing();

    local sections = {};
    if state.skill_combat[1] then
        sections[#sections + 1] = { 'COMBAT', combat_rows(player, main_job, main_level, sub_job, sub_level, skilldata.weapon_skills) };
    end
    if state.skill_magic[1] then
        sections[#sections + 1] = { 'MAGIC', combat_rows(player, main_job, main_level, sub_job, sub_level, skilldata.magic_skills) };
    end
    if state.skill_craft[1] then
        sections[#sections + 1] = { 'CRAFTING', craft_rows(player) };
    end

    if #sections == 0 then
        imgui.TextColored(state.muted_color, 'Pick Combat, Magic or Crafting above.');
        return;
    end

    -- Side-by-side columns when the window is wide enough. The column width
    -- needed is measured from the longest visible skill name + value.
    local avail = avail_width();
    local gap = 22 * scale;
    local show_all = state.show_unusable[1] == true;
    local longest = text_width('Blue Magic');
    for _, sec in ipairs(sections) do
        for _, row in ipairs(sec[2]) do
            if row[4] or show_all then
                local gain = skillup_gain_text(row[6]);
                longest = math.max(longest, text_width(row[1]) + (gain and (text_width(gain) + 6 * scale) or 0));
            end
        end
        longest = math.max(longest, text_width(sec[1]) + text_width('00 to go') + 10 * scale);
    end
    local need = longest + 10 * scale + text_width('000.0 / 000') + 10 * scale + 40 * scale;
    require_width(need);
    local columns = math.max(1, math.min(#sections, math.floor((avail + gap) / (need + gap))));
    local col_w = (avail - gap * (columns - 1)) / columns;

    -- Which column each section goes in: one each, or the first alone and
    -- the rest stacked in column two.
    local groups = {};
    for c = 1, columns do groups[c] = {}; end
    for i, sec in ipairs(sections) do
        local c = math.min(i, columns);
        table.insert(groups[c], sec);
    end

    local base_x = imgui.GetCursorPosX();
    for c = 1, columns do
        if c > 1 then imgui.SameLine(); end
        imgui.SetCursorPosX(base_x + (c - 1) * (col_w + gap));
        imgui.BeginGroup();
        for k, sec in ipairs(groups[c]) do
            if k > 1 then imgui.Spacing(); imgui.Spacing(); end
            draw_skill_section(sec[1], sec[2], col_w);
        end
        imgui.EndGroup();
    end
end
