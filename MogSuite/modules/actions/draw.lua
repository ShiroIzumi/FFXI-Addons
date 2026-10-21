--[[
    MogSuite - modules/actions/draw.lua

    Drawing helpers (badges, element orbs, bars) and the details pane.
]]

COL_GOOD   = { 0.45, 0.88, 0.50, 1.0 };
COL_WARN   = { 0.98, 0.72, 0.30, 1.0 };
COL_HP     = { 0.86, 0.36, 0.36, 1.0 };
COL_MP     = { 0.40, 0.62, 1.00, 1.0 };
COL_TP     = { 0.98, 0.80, 0.35, 1.0 };

function with_alpha(col, a)
    return { col[1], col[2], col[3], (col[4] or 1.0) * a };
end

-- Small pill with a short label (JA, SP, PET, SWD ...). Returns its width.
function draw_badge(dl, x, y, h, label, col, dim)
    local font, size = imgui.GetFont(), imgui.GetFontSize() * 0.74;
    local tw = text_w(label) * 0.74;
    local w = math.max(h * 1.2, tw + 10);
    local a = dim and 0.40 or 1.0;
    dl:AddRectFilled({ x, y }, { x + w, y + h }, imgui.GetColorU32(with_alpha(col, 0.20 * a)), h * 0.5);
    dl:AddRect({ x, y }, { x + w, y + h }, imgui.GetColorU32(with_alpha(col, 0.70 * a)), h * 0.5, 0, 1.0);
    dl:AddText(font, size, { x + (w - tw) * 0.5, y + (h - size) * 0.5 - 0.5 }, imgui.GetColorU32(with_alpha(col, a)), label);
    return w;
end

-- Element orb for spells.
function draw_orb(dl, cx, cy, r, col, dim)
    local a = dim and 0.40 or 1.0;
    dl:AddCircleFilled({ cx, cy }, r + 2, imgui.GetColorU32(with_alpha(col, 0.18 * a)), 20);
    dl:AddCircleFilled({ cx, cy }, r, imgui.GetColorU32(with_alpha(col, 0.85 * a)), 20);
    dl:AddCircleFilled({ cx - r * 0.35, cy - r * 0.35 }, r * 0.35, imgui.GetColorU32({ 1, 1, 1, 0.45 * a }), 12);
end

-- Rounded bar with a label inside.
function draw_bar(dl, x, y, w, h, frac, col, label, marker)
    frac = math.max(0, math.min(1, tonumber(frac) or 0));
    dl:AddRectFilled({ x, y }, { x + w, y + h }, imgui.GetColorU32({ 1, 1, 1, 0.06 }), h * 0.5);
    if frac > 0 then
        dl:AddRectFilled({ x, y }, { x + math.max(h, w * frac), y + h }, imgui.GetColorU32(with_alpha(col, 0.75)), h * 0.5);
    end
    if marker ~= nil then
        local mx = x + w * marker;
        dl:AddLine({ mx, y + 1 }, { mx, y + h - 1 }, imgui.GetColorU32({ 1, 1, 1, 0.35 }), 1.0);
    end
    if label ~= nil then
        local font, size = imgui.GetFont(), imgui.GetFontSize() * 0.80;
        local tw = text_w(label) * 0.80;
        local tx, ty = x + (w - tw) * 0.5, y + (h - size) * 0.5;
        dl:AddText(font, size, { tx + 1, ty + 1 }, imgui.GetColorU32({ 0, 0, 0, 0.8 }), label);
        dl:AddText(font, size, { tx, ty }, imgui.GetColorU32(UI_WHITE), label);
    end
end

function row_badge(row)
    if row.k == 'ws' then
        return SKILL_SHORT[row.skill] or 'WS', UI_ACCENT_TEXT;
    end
    local b = KIND_BADGE[row.kind] or KIND_BADGE.ja;
    return b[1], b[2] or UI_ACCENT_TEXT;
end

function row_ready_now(row)
    if row.status ~= 'ready' then return false; end
    if (row.cd or 0) > 0 then return false; end
    if row.k == 'ws' then return state.me ~= nil and state.me.tp >= 1000; end
    if row.k == 'ma' or row.k == 'bp' then return state.me ~= nil and state.me.mp >= (row.mp or 0); end
    return true;
end

function row_passes(row, tab)
    local f = (config.filter and config.filter[tab]) or 'all';
    if f == 'ready' and not row_ready_now(row) then return false; end
    if f == 'have' and row.status ~= 'ready' and row.status ~= 'unset' then return false; end
    if f == 'locked' and row.status == 'ready' then return false; end
    if f == 'missing' and row.status ~= 'scroll' then return false; end
    local q = tostring(state.search[1] or ''):lower():gsub('^%s+', ''):gsub('%s+$', '');
    if q ~= '' and row.name:lower():find(q, 1, true) == nil then return false; end
    return true;
end

function is_selected(row)
    local s = state.selected;
    return s ~= nil and s.k == row.k and s.n == row.name;
end

function set_clipboard(text)
    local ok = pcall(function() imgui.SetClipboardText(text); end);
    if ok then state.copied_at = os.clock(); end
end

function job_level_text(job, lvl)
    return ('%s Lv %d'):fmt(JOB_SHORT[job] or '?', lvl);
end

-- ============================================================================
-- Details (pane or tooltip)
-- ============================================================================

function target_text(row)
    if row.k == 'trait' then return ('%s Lv %d'):fmt(JOB_SHORT[row.job] or '?', row.level or 0); end
    if row.k == 'ws' then return 'Enemy'; end
    if row.k == 'pet' then return PET_ENEMY[row.name] and 'Enemy' or 'Pet'; end
    local t = tonumber(res_field(row.res, 'Targets')) or 0;
    if row.k == 'bp' and t == 0 then return (row.bp == 'rage') and 'Enemy' or 'Self or party'; end
    if bit.band(t, 0x20) ~= 0 then return 'Enemy'; end
    if t == 0 or bit.band(t, 0xFE) == 0 then return 'Self'; end
    if bit.band(t, 0x04) ~= 0 or bit.band(t, 0x02) ~= 0 then return 'Self or party'; end
    return 'Self';
end

function draw_details(row, as_tooltip)
    local me = state.me;
    imgui.TextColored(UI_ACCENT_TEXT, row.name);
    imgui.SameLine(0, 10);
    local kind = ({ ja = 'Job ability', sp = 'Special ability (two-hour)', merit = 'Merit ability', pet = 'Pet command',
        roll = 'Phantom Roll', shot = 'Quick Draw', man = 'Maneuver', ws = 'Weapon skill', ma = 'Magic',
        rage = 'Blood Pact: Rage', ward = 'Blood Pact: Ward', af = 'Blood Pact (Astral Flow)', trait = 'Job trait (passive)' })[row.kind] or '';
    if row.k == 'ma' then
        local school = SCHOOL_OF[row.type];
        kind = school and school.label or 'Magic';
    end
    local el = ELEMENTS[tonumber(row.element) or -1];
    imgui.TextColored(UI_MUTED, kind .. ((row.k == 'ma' and el) and ('  -  ' .. el[1]) or '') .. '  -  ' .. target_text(row));

    local desc = clean_desc(res_string(res_field(row.res, 'Description')));
    if desc ~= '' then
        imgui.PushTextWrapPos(as_tooltip and math.floor(360 * (tonumber(config.font_scale) or 1.0)) or 0);
        imgui.TextWrapped(desc);
        imgui.PopTextWrapPos();
    end
    local hz = horizon_note(row);
    if hz ~= nil then
        imgui.PushTextWrapPos(as_tooltip and math.floor(360 * (tonumber(config.font_scale) or 1.0)) or 0);
        imgui.TextColored(HORIZON_MARK_COLOR, 'Horizon change: ' .. hz);
        imgui.PopTextWrapPos();
    end

    -- Cost / timing.
    local parts = {};
    if row.k == 'ma' then
        local mp = row.mp or 0;
        parts[#parts + 1] = { ('%d MP'):fmt(mp), (me ~= nil and me.mp < mp) and UI_DANGER or config.value_color };
        local cast = tonumber(res_field(row.res, 'CastTime'));
        local rec = tonumber(res_field(row.res, 'RecastDelay'));
        if cast ~= nil and cast > 0 then parts[#parts + 1] = { ('Cast %.1fs'):fmt(cast / 4), UI_MUTED }; end
        if rec ~= nil and rec > 0 then parts[#parts + 1] = { ('Recast %.1fs'):fmt(rec / 4), UI_MUTED }; end
        if row.tool ~= nil then
            parts[#parts + 1] = { ('%s x%d'):fmt(row.tool, row.tool_count or 0), (row.tool_count or 0) > 0 and UI_MUTED or UI_DANGER };
        end
    elseif row.k == 'ws' then
        if row.need and row.need > 0 then
            parts[#parts + 1] = { ('%s skill %d'):fmt(SKILL_NAMES[row.skill] or '', row.need), UI_MUTED };
        end
        if row.tag == 'quest' then parts[#parts + 1] = { 'Weapon skill quest', COL_WARN }; end
        if row.tag == 'relic' then parts[#parts + 1] = { 'Relic weapon', COL_WARN }; end
        if row.tag == 'mythic' then parts[#parts + 1] = { 'Mythic weapon', COL_WARN }; end
        if me ~= nil then parts[#parts + 1] = { ('TP %d'):fmt(me.tp), me.tp >= 1000 and COL_TP or UI_MUTED }; end
    else
        local tp = tonumber(res_field(row.res, 'TPCost')) or 0;
        local mp = tonumber(res_field(row.res, 'ManaCost')) or 0;
        if mp > 0 then parts[#parts + 1] = { ('%d MP'):fmt(mp), config.value_color }; end
        if tp > 0 and tp < 0xFFFF then parts[#parts + 1] = { ('%d TP'):fmt(tp), COL_TP }; end
    end
    if (row.cd or 0) > 0 then parts[#parts + 1] = { 'Ready in ' .. fmt_time(row.cd), UI_ACCENT_TEXT }; end
    for i, p in ipairs(parts) do
        if i > 1 then imgui.SameLine(0, 4); imgui.TextColored(UI_MUTED, '-'); imgui.SameLine(0, 4); end
        imgui.TextColored(p[2], p[1]);
    end

    -- Where it comes from.
    if row.k == 'ma' and me ~= nil then
        local src = {};
        if row.lm ~= nil then src[#src + 1] = job_level_text(me.job, row.lm); end
        if row.ls ~= nil then src[#src + 1] = job_level_text(me.sub, row.ls) .. ' (support)'; end
        local t = table.concat(src, '  -  ');
        if row.status == 'scroll' then t = t .. '  -  scroll not learned yet'; end
        if row.status == 'unset' then t = t .. '  -  learned, not set (set it with AzureCodex)'; end
        if row.type == BLUE_MAGIC_TYPE and row.status == 'na' then t = t .. '  -  not learned yet'; end
        imgui.TextColored((row.status == 'scroll' or row.status == 'unset') and COL_WARN or UI_MUTED, t);
    elseif (row.k == 'ja' or row.k == 'pet') and row.job ~= nil then
        local t;
        if row.kind == 'merit' then t = 'Merit point ability';
        else t = job_level_text(row.job, row.level) .. (row.src == 'sub' and ' (support)' or ''); end
        if row.status == 'na' and row.kind ~= 'merit' then t = t .. '  -  not learned'; end
        imgui.TextColored(UI_MUTED, t);
    elseif row.k == 'bp' and me ~= nil then
        local t;
        if row.tag == 'af' then t = 'Only while Astral Flow is up';
        elseif row.tag == 'merit' then t = 'Merit point blood pact';
        else t = job_level_text(SMN_JOB, row.level) .. (row.src == 'sub' and ' (support)' or ''); end
        imgui.TextColored(UI_MUTED, t);
    end

    if row.status == 'ready' then
        local line = macro_line(row);
        imgui.TextColored(UI_MUTED, 'Macro:');
        imgui.SameLine(0, 6);
        imgui.TextColored(config.value_color, line);
        if not as_tooltip then
            imgui.SameLine(0, 10);
            if imgui.Button((os.clock() - state.copied_at < 1.2 and 'Copied' or 'Copy') .. '##ab_copy') then set_clipboard(line); end
            imgui.SameLine(0, 4);
            if imgui.Button('Use##ab_use_det') then use_row(row); end
            imgui.SameLine(0, 4);
            if imgui.Button((is_pinned(row) and 'Unpin' or 'Pin') .. '##ab_pin_det') then toggle_pin(row); end
        end
    end
end

-- ============================================================================
-- Rows and sections
-- ============================================================================
