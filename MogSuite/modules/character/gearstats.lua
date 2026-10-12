--[[
    MogSuite - modules/character/gearstats.lua

    The Gear Stats tab, and the compact window style of the Character window.
]]

-- ============================================================================
-- Gear Stats tab
-- ============================================================================

-- { title, { { label, field, cap, suffix }, ... } }
GEAR_CARDS = {
    { 'OFFENSE', {
        { 'Accuracy', 'accuracy' },
        { 'Attack', 'attack' },
        { 'Ranged Accuracy', 'ranged_accuracy' },
        { 'Ranged Attack', 'ranged_attack' },
    } },
    { 'TP / MULTI-ATTACK', {
        { 'Store TP', 'store_tp' },
        { 'Subtle Blow', 'subtle_blow', 50 },
        { 'Double Attack', 'double_attack', nil, '%' },
        { 'Triple Attack', 'triple_attack', nil, '%' },
    } },
    { 'MAGIC', {
        { 'Magic Accuracy', 'magic_accuracy' },
        { 'Magic Attack Bonus', 'magic_attack' },
        { 'Fast Cast', 'fast_cast', nil, '%' },
        { 'Cure Potency', 'cure_potency', nil, '%' },
    } },
    { 'DEFENSE / ENMITY', {
        { 'Evasion', 'evasion' },
        { 'Magic Evasion', 'magic_evasion' },
        { 'Counter', 'counter', nil, '%' },
        { 'Enmity', 'enmity' },
    } },
    { 'RECOVERY / UTILITY', {
        { 'Regen', 'regen' },
        { 'Refresh', 'refresh' },
        { 'Spell Interrupt Down', 'spell_interrupt', nil, '%' },
        { 'Movement Speed', 'movement', nil, '%' },
    } },
    { 'SPEED', {
        { 'Gear Haste', 'haste', 25, '%' },
    } },
};

function draw_gear_tab(gear)
    local scale = state.overall_scale[1];

    if draw_toggle_button('Hide zero stats', 'cs_hide_zero', state.hide_zero[1] == true) then
        state.hide_zero[1] = not state.hide_zero[1];
        state.settings_dirty = true;
    end
    tip('Only show stats your gear actually gives');
    help_marker('Totals are read from the descriptions of the gear you have equipped (your own stats only). Pet / Avatar / Automaton / Wyvern lines, latent effects, set bonuses and enchantments are not counted.');
    imgui.Spacing();

    local cards = {};
    local hidden = {};
    for _, spec in ipairs(GEAR_CARDS) do
        local rows = {};
        for _, r in ipairs(spec[2]) do
            local value = gear and gear[r[2]] or nil;
            local n = tonumber(value) or 0;
            if (not state.hide_zero[1]) or n ~= 0 then
                rows[#rows + 1] = { r[1], value, r[3], r[4], false };
            end
        end
        if #rows > 0 then
            cards[#cards + 1] = { spec[1], rows };
        else
            hidden[#hidden + 1] = spec[1];
        end
    end

    if #cards == 0 then
        imgui.TextColored(state.muted_color, 'No stats found on your equipped gear.');
        return;
    end

    local avail = avail_width();
    local gap = 8 * scale;
    local need = 0;
    for _, card in ipairs(cards) do
        need = math.max(need, text_width(card[1]) + 20 * scale);
        for _, row in ipairs(card[2]) do
            need = math.max(need, text_width(row[1]) + text_width(format_metric(row[2], row[3], row[4])) + 34 * scale);
        end
    end
    require_width(need);
    local columns = math.max(1, math.min(3, math.floor((avail + gap) / (need + gap))));
    local card_w = (avail - gap * (columns - 1)) / columns;
    local lh = line_height();
    local row_h = lh + 2 * scale;

    local i = 1;
    while i <= #cards do
        local max_rows = 0;
        for k = i, math.min(#cards, i + columns - 1) do
            max_rows = math.max(max_rows, #cards[k][2]);
        end
        local card_h = row_h * (max_rows + 1) + 18 * scale;

        for k = i, math.min(#cards, i + columns - 1) do
            if k > i then imgui.SameLine(0, gap); end
            draw_advanced_card('gear_card_' .. tostring(k) .. '##charsheet', cards[k][1], card_w, card_h, cards[k][2]);
        end
        imgui.Spacing();
        i = i + columns;
    end

    if #hidden > 0 and state.hide_zero[1] then
        imgui.TextColored(state.muted_color, ('Hidden (all 0): %s'):fmt(table.concat(hidden, ', ')));
    end
end

-- Sheet theme: full suite theme, then the Character window's compact spacing on
-- top so the stat layout stays dense.
push_sheet_theme = function(scale)
    push_theme(nil, nil, scale);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 9.0 * scale, 7.0 * scale });
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 6.0 * scale, 2.0 * scale });
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 5.0 * scale, 2.0 * scale });
end

pop_sheet_theme = function()
    imgui.PopStyleVar(3);
    pop_theme();
end
