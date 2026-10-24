--[[
    MogSuite - modules/actions/rows.lua

    Rows, section headers, the right-click menu and the weapon / pet cards.
]]

function open_ctx(row)
    state.ctx = row;
    imgui.OpenPopup('##ab_ctx');
end

function draw_context_menu()
    if not imgui.BeginPopup('##ab_ctx') then return; end
    local row = state.ctx;
    if row == nil then imgui.EndPopup(); return; end
    imgui.TextColored(UI_ACCENT_TEXT, row.name);
    imgui.Separator();
    if row.k == 'trait' then
        imgui.TextDisabled((row.status == 'ready') and 'Job trait (always on)' or (row.note or 'Job trait'));
    elseif row.status == 'ready' then
        if imgui.Selectable(('Use  (%s)##ab_ctx_use'):fmt(default_target(row))) then use_row(row); end
        if row.k ~= 'ws' and can_target_self(row) and default_target(row) ~= '<me>' then
            if imgui.Selectable('Use on me##ab_ctx_me') then use_row(row, '<me>'); end
        end
        if row.k == 'ma' or row.k == 'ja' or row.k == 'bp' then
            local t = tonumber(res_field(row.res, 'Targets')) or 0;
            if bit.band(t, 0x06) ~= 0 then
                if imgui.Selectable('Use on a party member...##ab_ctx_stpc') then use_row(row, '<stpc>'); end
            end
            if bit.band(t, 0x20) ~= 0 then
                if imgui.Selectable('Use on a selected enemy...##ab_ctx_stnpc') then use_row(row, '<stnpc>'); end
            end
        end
        imgui.Separator();
        if imgui.Selectable('Copy macro line##ab_ctx_copy') then set_clipboard(macro_line(row)); end
    else
        imgui.TextDisabled(row.note or 'Not available');
    end
    if imgui.Selectable((is_pinned(row) and 'Unpin' or 'Pin to the top') .. '##ab_ctx_pin') then toggle_pin(row); end
    imgui.EndPopup();
end

function draw_row(dl, row, i, sec_key, width, row_h)
    local sx, sy = imgui.GetCursorScreenPos();
    local clicked = imgui.InvisibleButton(('##ab_row_%s_%s'):fmt(sec_key, row.name), { math.max(1, width), row_h });
    local hovered = imgui.IsItemHovered();
    if clicked then state.selected = { k = row.k, n = row.name }; end
    if hovered and imgui.IsMouseDoubleClicked(0) then use_row(row); end
    if hovered and imgui.IsMouseClicked(1) then open_ctx(row); end
    if imgui.IsItemVisible ~= nil and not imgui.IsItemVisible() then return; end

    local me = state.me;
    local have = row.status == 'ready';
    local dim = not have;
    local line_h = imgui.GetTextLineHeight();
    local ty = sy + (row_h - line_h) * 0.5;

    if i % 2 == 0 then
        dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32({ 1, 1, 1, 0.022 }), 3.0);
    end
    -- Cooldown fill (right to left as it runs out).
    local cd = row.cd or 0;
    if cd > 0 and row.cd_key ~= nil then
        local frac = cd_fraction(row.cd_key, cd);
        dl:AddRectFilled({ sx, sy }, { sx + width * frac, sy + row_h }, imgui.GetColorU32(accent(0.16)), 3.0);
    elseif row.cd_key ~= nil then
        cd_fraction(row.cd_key, 0);
    end
    if is_selected(row) then
        dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32(accent(0.20)), 3.0);
        dl:AddRect({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32(accent(0.55)), 3.0, 0, 1.0);
    elseif hovered then
        dl:AddRectFilled({ sx, sy }, { sx + width, sy + row_h }, imgui.GetColorU32(accent(0.12)), 3.0);
    end
    if row_ready_now(row) and row.k == 'ws' then
        dl:AddRectFilled({ sx, sy + 2 }, { sx + 3, sy + row_h - 2 }, imgui.GetColorU32(COL_TP), 1.0);
    end

    local x = sx + 6;
    if row.k == 'ma' then
        local el = ELEMENTS[tonumber(row.element) or -1] or NO_ELEMENT;
        local r = math.max(3.5, line_h * 0.30);
        draw_orb(dl, x + r + 1, sy + row_h * 0.5, r, el[2], dim);
        x = x + r * 2 + 10;
    else
        local label, col = row_badge(row);
        local bh = math.floor(line_h * 0.92);
        local bw = draw_badge(dl, x, sy + (row_h - bh) * 0.5, bh, label, col, dim);
        x = x + math.max(bw, text_w('ROLL') * 0.74 + 10) + 8;
    end

    local name_col = have and config.name_color or with_alpha(config.name_color, 0.42);
    draw_fx_text(dl, x, ty, name_col, row.name);
    x = x + text_w(row.name);
    if is_pinned(row) then
        local px = x + 7;
        dl:AddCircleFilled({ px, sy + row_h * 0.5 }, 2.5, imgui.GetColorU32(accent(0.9)), 10);
        x = px + 6;
    end
    -- "H": changed on HorizonXI (hover it for what changed).
    local hz = (config.show_horizon_marks ~= false) and horizon_note(row) or nil;
    if hz ~= nil then
        local hx = x + 6;
        local hh = math.floor(line_h * 0.80);
        local hw = draw_badge(dl, hx, sy + (row_h - hh) * 0.5, hh, 'H', HORIZON_MARK_COLOR, dim);
        local mx, my = imgui.GetMousePos();
        mx, my = tonumber(mx) or -1, tonumber(my) or -1;
        if hovered and mx >= hx and mx <= hx + hw and my >= sy and my <= sy + row_h and not imgui.IsPopupOpen('##ab_ctx') then
            imgui.BeginTooltip();
            imgui.TextColored(HORIZON_MARK_COLOR, 'Changed on HorizonXI');
            imgui.PushTextWrapPos(math.floor(320 * (tonumber(config.font_scale) or 1.0)));
            imgui.TextWrapped(hz);
            imgui.PopTextWrapPos();
            imgui.EndTooltip();
            hz = 'shown';
        end
        x = hx + hw + 2;
    end

    -- Right side, from the edge inwards.
    local right = sx + width - 8;
    local function right_text(s, col)
        local w = text_w(s);
        if right - w > x + 10 then
            draw_fx_text(dl, right - w, ty, col, s);
            right = right - w - 12;
        end
    end
    if cd > 0 then
        right_text(fmt_time(cd), UI_ACCENT_TEXT);
    elseif not have and row.note ~= nil then
        local col = (row.status == 'scroll' or row.status == 'unset') and COL_WARN or with_alpha(UI_MUTED, row.status == 'na' and 0.7 or 1.0);
        right_text(row.note, col);
    elseif row.k == 'ws' and me ~= nil and me.tp >= 1000 then
        right_text('Ready', COL_TP);
    end
    if row.k == 'ma' then
        local mp = row.mp or 0;
        if mp > 0 then
            local col = (me ~= nil and me.mp < mp and have) and UI_DANGER or (have and config.value_color or with_alpha(UI_MUTED, 0.7));
            right_text(('%d MP'):fmt(mp), col);
        end
        if row.tool ~= nil and have then
            right_text(('%s %d'):fmt(row.tool, row.tool_count or 0), (row.tool_count or 0) > 0 and UI_MUTED or UI_DANGER);
        end
    elseif row.k == 'bp' then
        local mp = row.mp or 0;
        if mp > 0 then
            local col = (me ~= nil and me.mp < mp and have) and UI_DANGER or (have and config.value_color or with_alpha(UI_MUTED, 0.7));
            right_text(('%d MP'):fmt(mp), col);
        end
    end

    if hovered and hz ~= 'shown' and config.show_details == false and not imgui.IsPopupOpen('##ab_ctx') then
        imgui.BeginTooltip();
        draw_details(row, true);
        imgui.EndTooltip();
    end
end

function draw_section_header(dl, sec, shown, ready, width)
    config.collapsed = config.collapsed or T{};
    local collapsed = config.collapsed[sec.key];
    if collapsed == nil then collapsed = sec.default_collapsed == true; end
    local line_h = imgui.GetTextLineHeight();
    local h = line_h + 8;
    local sx, sy = imgui.GetCursorScreenPos();
    if imgui.InvisibleButton('##ab_sec_' .. sec.key, { math.max(1, width), h }) then
        collapsed = not collapsed;
        if sec.default_collapsed ~= nil then
            config.collapsed[sec.key] = collapsed;
        else
            config.collapsed[sec.key] = collapsed or nil;
        end
        mark_dirty();
    end
    local hovered = imgui.IsItemHovered();
    dl:AddRectFilled({ sx, sy }, { sx + width, sy + h }, imgui.GetColorU32(accent(hovered and 0.26 or 0.13)), 4.0);
    dl:AddRectFilled({ sx, sy + h - 2 }, { sx + width, sy + h }, imgui.GetColorU32(accent(0.55)), 0.0);

    local ax, ay, a = sx + 10, sy + h * 0.5, math.max(3, line_h * 0.22);
    local acol = imgui.GetColorU32(UI_ACCENT_TEXT);
    if collapsed then
        dl:AddTriangleFilled({ ax - a * 0.6, ay - a }, { ax + a * 0.8, ay }, { ax - a * 0.6, ay + a }, acol);
    else
        dl:AddTriangleFilled({ ax - a, ay - a * 0.6 }, { ax + a, ay - a * 0.6 }, { ax, ay + a * 0.8 }, acol);
    end
    local tx = sx + 22;
    if sec.tag ~= nil then
        local bw = draw_badge(dl, tx, sy + (h - math.floor(line_h * 0.92)) * 0.5, math.floor(line_h * 0.92), sec.tag, UI_ACCENT_TEXT, false);
        tx = tx + bw + 8;
    end
    draw_fx_text(dl, tx, sy + 4, UI_ACCENT_TEXT, sec.title);
    local ct = ('%d / %d'):fmt(ready, shown);
    draw_fx_text(dl, sx + width - text_w(ct) - 8, sy + 4, UI_MUTED, ct);
    return collapsed;
end

-- Smaller sub-header inside a section (Usable / Unusable). Collapsed state
-- is stored as true / false so each can have its own default.
function draw_sub_header(dl, key, title, count, width, default_collapsed)
    config.collapsed = config.collapsed or T{};
    local collapsed = config.collapsed[key];
    if collapsed == nil then collapsed = default_collapsed; end
    local line_h = imgui.GetTextLineHeight();
    local h = line_h + 4;
    local sx, sy = imgui.GetCursorScreenPos();
    if imgui.InvisibleButton('##ab_sub_' .. key, { math.max(1, width), h }) then
        collapsed = not collapsed;
        config.collapsed[key] = collapsed;
        mark_dirty();
    end
    local hovered = imgui.IsItemHovered();
    local x0 = sx + 10;
    if hovered then
        dl:AddRectFilled({ x0, sy }, { sx + width, sy + h }, imgui.GetColorU32(accent(0.10)), 3.0);
    end
    dl:AddLine({ x0, sy + h - 1 }, { sx + width, sy + h - 1 }, imgui.GetColorU32(accent(0.25)), 1.0);
    local ax, ay, a = x0 + 8, sy + h * 0.5, math.max(2.5, line_h * 0.18);
    local acol = imgui.GetColorU32(UI_MUTED);
    if collapsed then
        dl:AddTriangleFilled({ ax - a * 0.6, ay - a }, { ax + a * 0.8, ay }, { ax - a * 0.6, ay + a }, acol);
    else
        dl:AddTriangleFilled({ ax - a, ay - a * 0.6 }, { ax + a, ay - a * 0.6 }, { ax, ay + a * 0.8 }, acol);
    end
    local col = (title == 'Usable') and UI_ACCENT_TEXT or UI_MUTED;
    draw_fx_text(dl, x0 + 18, sy + 2, col, title);
    draw_fx_text(dl, x0 + 18 + text_w(title) + 8, sy + 2, UI_MUTED, tostring(count));
    return collapsed;
end

-- Weapon card under a weapon skill section header.
function draw_weapon_card(sec, width)
    local dl = imgui.GetWindowDrawList();
    local line_h = imgui.GetTextLineHeight();
    local sx, sy = imgui.GetCursorScreenPos();
    local h = line_h * 2 + 14;
    imgui.Dummy({ math.max(1, width), h });
    dl:AddRectFilled({ sx, sy }, { sx + width, sy + h }, imgui.GetColorU32({ 1, 1, 1, 0.03 }), 4.0);
    local x = sx + 10;
    draw_fx_text(dl, x, sy + 5, config.name_color, sec.weapon or '(nothing equipped)');
    local st = ('Skill %d'):fmt(sec.value or 0);
    local stw = text_w(st);
    draw_fx_text(dl, sx + width - stw - 10, sy + 5, config.value_color, st);
    if sec.capped then
        draw_badge(dl, sx + width - stw - 18 - text_w('CAPPED') * 0.74 - 10, sy + 5, math.floor(line_h * 0.92), 'CAPPED', COL_GOOD, false);
    end
    local y2 = sy + 7 + line_h + 2;
    local nr = sec.next_row;
    local bar_w = width - 20;
    if nr ~= nil then
        local prev = 0;
        for _, r in ipairs(sec.rows) do
            if r.need ~= nil and r.need > 0 and r.need <= (sec.value or 0) and r.need > prev then prev = r.need; end
        end
        local span = math.max(1, nr.need - prev);
        local frac = ((sec.value or 0) - prev) / span;
        draw_bar(dl, x, y2 + 1, bar_w, line_h - 2, frac, UI_ACCENT,
            ('Next: %s at %d  (%d to go)'):fmt(nr.name, nr.need, math.max(0, nr.need - (sec.value or 0))));
    else
        draw_bar(dl, x, y2 + 1, bar_w, line_h - 2, 1, UI_ACCENT, 'Every weapon skill unlocked');
    end
    imgui.Dummy({ 1, 2 });
end

-- Pet card under the pet's section header: name, HP and MP.
function draw_pet_card(width)
    local pet = state.pet;
    if pet == nil then return; end
    local dl = imgui.GetWindowDrawList();
    local line_h = imgui.GetTextLineHeight();
    local sx, sy = imgui.GetCursorScreenPos();
    local h = line_h * 2 + 14;
    imgui.Dummy({ math.max(1, width), h });
    dl:AddRectFilled({ sx, sy }, { sx + width, sy + h }, imgui.GetColorU32({ 1, 1, 1, 0.03 }), 4.0);
    local x = sx + 10;
    draw_fx_text(dl, x, sy + 5, config.name_color, pet.name);
    local info = PET_JOBS[pet.owner or 0];
    local kind = BLOOD_PACTS[pet.name] and 'Avatar' or (SPIRITS[pet.name] and 'Spirit' or (info and info.kind or 'Pet'));
    draw_fx_text(dl, sx + width - text_w(kind) - 10, sy + 5, UI_MUTED, kind);
    local y2 = sy + 7 + line_h + 2;
    local gap = 6;
    local bar_w = width - 20;
    -- HP always; MP for avatars / spirits / automatons; TP for the others.
    local bars = { { (pet.hpp or 0) / 100, COL_HP, ('HP %d%%'):fmt(pet.hpp or 0) } };
    if pet.mpp ~= nil and (pet.owner == SMN_JOB or pet.owner == PUP_JOB) then
        bars[#bars + 1] = { pet.mpp / 100, COL_MP, ('MP %d%%'):fmt(pet.mpp) };
    end
    if pet.tp ~= nil and pet.owner ~= SMN_JOB then
        bars[#bars + 1] = { pet.tp / 3000, COL_TP, ('TP %d'):fmt(pet.tp), 1 / 3 };
    end
    local bw = (bar_w - gap * (#bars - 1)) / #bars;
    for i, b in ipairs(bars) do
        draw_bar(dl, x + (bw + gap) * (i - 1), y2 + 1, bw, line_h - 2, b[1], b[2], b[3], b[4]);
    end
    imgui.Dummy({ 1, 2 });
end

function draw_tab_lists(tab)
    local sections = state.lists[tab] or {};
    local dl = imgui.GetWindowDrawList();
    local line_h = imgui.GetTextLineHeight();
    local row_h = line_h + (tonumber(config.row_spacing) or 3) * 2;
    local any = false;

    for _, sec in ipairs(sections) do
        local rows, ready = {}, 0;
        for _, row in ipairs(sec.rows) do
            if row_passes(row, tab) then
                rows[#rows + 1] = row;
                if row.status == 'ready' then ready = ready + 1; end
            end
        end
        if #rows > 0 or sec.weapon ~= nil or sec.pet_card then
            any = true;
            local width = tonumber((imgui.GetContentRegionAvail())) or 300;
            local collapsed = draw_section_header(dl, sec, #rows, ready, width);
            if not collapsed then
                imgui.Dummy({ 1, 1 });
                if tab == 'ws' then draw_weapon_card(sec, width); end
                if sec.pet_card then draw_pet_card(width); end
                if tab == 'magic' or sec.split then
                    -- Usable (known, level reached) / Unusable (everything else).
                    local usable, unusable = {}, {};
                    for _, row in ipairs(rows) do
                        if row.status == 'ready' then usable[#usable + 1] = row; else unusable[#unusable + 1] = row; end
                    end
                    for _, part in ipairs({ { 'u', 'Usable', usable, false }, { 'x', 'Unusable', unusable, true } }) do
                        if #part[3] > 0 then
                            local key = sec.key .. '_' .. part[1];
                            if not draw_sub_header(dl, key, part[2], #part[3], width, part[4]) then
                                for i, row in ipairs(part[3]) do
                                    draw_row(dl, row, i, key, width, row_h);
                                end
                            end
                        end
                    end
                else
                    for i, row in ipairs(rows) do
                        draw_row(dl, row, i, sec.key, width, row_h);
                    end
                end
            end
            imgui.Dummy({ 1, 5 });
        end
    end
    if not any then
        local msg = 'Nothing here.';
        if tab == 'ws' then msg = 'No weapon skills for what you have equipped.'; end
        if tab == 'magic' then msg = 'Your jobs have no magic.'; end
        if tab == 'summons' then msg = 'No summons yet.'; end
        if tab == 'wyvern' or tab == 'automaton' or tab == 'beast' then msg = 'No pet abilities yet.'; end
        if tostring(state.search[1] or '') ~= '' then msg = 'Nothing matches the search.'; end
        imgui.TextDisabled(msg);
    end
    if tab == 'ws' then
        local ok, err = pcall(draw_skillchain_panel, dl, tonumber((imgui.GetContentRegionAvail())) or 300);
        if not ok then imgui.TextDisabled(tostring(err)); end
    end
    draw_context_menu();
end
