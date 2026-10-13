--[[
    Azure Codex - ac/spelltable.lua

    The spell list table: headers, learning-location tooltip and rows.
]]

function draw_table_headers()
    imgui.TableNextRow();

    -- Solid header strip so the sortable column titles read as a header row.
    if imgui.TableSetBgColor ~= nil and ImGuiTableBgTarget_RowBg0 ~= nil then
        imgui.TableSetBgColor(ImGuiTableBgTarget_RowBg0, imgui.GetColorU32(TABLE_HEADER));
    end

    imgui.TableNextColumn();
    draw_sort_header('Spell', 'name');

    if state.columns.level[1] then
        imgui.TableNextColumn();
        draw_sort_header('Lvl', 'level');
    end

    if state.columns.points[1] then
        imgui.TableNextColumn();
        draw_sort_header('Points', 'points');
    end

    if state.columns.learn_skill[1] then
        imgui.TableNextColumn();
        draw_sort_header('Learn', 'learn_skill');
    end

    if state.columns.type[1] then
        imgui.TableNextColumn();
        draw_sort_header('Type', 'type');
    end

    if state.columns.trait[1] then
        imgui.TableNextColumn();
        draw_sort_header('Trait', 'trait');
    end

    if state.columns.mob_family[1] then
        imgui.TableNextColumn();
        draw_sort_header('Mob Family', 'mob_family');
    end
end

function draw_learning_tooltip(spell)
    if state.location_interaction ~= 'hover' then return; end
    if not imgui.IsItemHovered() then return; end

    local entries = locations.get(spell.name);
    if not entries then return; end

    imgui.BeginTooltip();
    imgui.TextColored(state.header_color, spell.name);
    imgui.Separator();

    imgui.TextColored(MUTED, 'Mob Family:');
    imgui.SameLine();
    imgui.Text(tostring(spell.mob_family or '--'));

    imgui.Spacing();
    imgui.TextColored(state.header_color, 'Learned From');
    imgui.Separator();

    if #entries == 0 then
        imgui.TextColored(MUTED, 'No learning locations available.');
    else
        -- Keep large learning lists readable by flowing them into additional
        -- columns instead of allowing a tooltip to grow beyond the screen.
        -- A zone and its mobs are kept together whenever possible.
        local max_rows_per_column = 50;
        local columns = { {} };
        local current_column = columns[1];
        local current_rows = 0;

        for _, entry in ipairs(entries) do
            local mobs = entry.mobs or {};
            local block_rows = 1 + #mobs;

            if current_rows > 0 and (current_rows + block_rows) > max_rows_per_column then
                current_column = {};
                table.insert(columns, current_column);
                current_rows = 0;
            end

            table.insert(current_column, {
                kind = 'zone',
                text = locations.get_zone_name(entry.zone),
            });
            current_rows = current_rows + 1;

            for _, mob in ipairs(mobs) do
                table.insert(current_column, {
                    kind = 'mob',
                    text = tostring(mob),
                });
                current_rows = current_rows + 1;
            end
        end

        if #columns == 1 or imgui.BeginTable == nil then
            for column_index, column in ipairs(columns) do
                if column_index > 1 then
                    imgui.Spacing();
                    imgui.Separator();
                end
                for _, line in ipairs(column) do
                    if line.kind == 'zone' then
                        imgui.TextColored(state.header_color, line.text);
                    else
                        imgui.Text('  - ' .. line.text);
                    end
                end
            end
        else
            local flags = 0;
            if ImGuiTableFlags_SizingFixedFit ~= nil then
                flags = bit.bor(flags, ImGuiTableFlags_SizingFixedFit);
            end

            if imgui.BeginTable('##bluspells_learning_locations', #columns, flags) then
                local tallest = 0;
                for _, column in ipairs(columns) do
                    if #column > tallest then tallest = #column; end
                end

                for row = 1, tallest do
                    imgui.TableNextRow();
                    for column_index, column in ipairs(columns) do
                        imgui.TableNextColumn();
                        local line = column[row];
                        if line then
                            if line.kind == 'zone' then
                                imgui.TextColored(state.header_color, line.text);
                            else
                                imgui.Text('  - ' .. line.text);
                            end
                        end
                    end
                end

                imgui.EndTable();
            end
        end
    end

    imgui.EndTooltip();
end

function draw_spell_table_row(spell)
    local known = is_known(spell.name);
    local selected = state.selected_spell == spell.name;
    local _, color = get_spell_display_state(spell);

    local line_h = imgui.GetTextLineHeightWithSpacing();
    local row_h = state.row_spacing == 'normal' and (line_h + 5) or (line_h + 1);

    imgui.TableNextRow(0, row_h);
    imgui.TableNextColumn();

    local selectable_flags = ImGuiSelectableFlags_SpanAllColumns or 0;

    if selected and os.clock() <= state.learned_flash_until then
        imgui.PushStyleColor(ImGuiCol_Header, { 0.18, 0.38, 0.20, 0.90 });
        imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 0.20, 0.46, 0.23, 0.95 });
        imgui.PushStyleColor(ImGuiCol_HeaderActive, { 0.22, 0.54, 0.26, 1.00 });
    end

    imgui.PushStyleColor(ImGuiCol_Text, color);
    if imgui.Selectable(spell.name .. '##spell_' .. normalize_name(spell.name), selected, selectable_flags) then
        state.selected_spell = spell.name;
        if state.location_interaction == 'click' then
            if state.location_open[1] and state.location_spell and state.location_spell.name == spell.name then
                state.location_open[1] = false;
                state.location_spell = nil;
            else
                state.location_spell = spell;
        state.location_reset_scroll = true;
                state.location_open[1] = true;
                state.location_apply_default_size = not state.location_size_initialized;
            end
        end
    end
    draw_learning_tooltip(spell);
    imgui.PopStyleColor(1);

    if selected and os.clock() <= state.learned_flash_until then
        imgui.PopStyleColor(3);
    end

    if state.columns.level[1] then
        imgui.TableNextColumn();
        imgui.Text(tostring(spell.level));
    end

    if state.columns.points[1] then
        imgui.TableNextColumn();
        imgui.Text(tostring(spell.points or '--'));
    end

    if state.columns.learn_skill[1] then
        imgui.TableNextColumn();
        imgui.Text(tostring(blue_magic_learn_skill(spell)));
    end

    if state.columns.type[1] then
        imgui.TableNextColumn();
        imgui.Text(tostring(spell.type or '--'));
    end

    if state.columns.trait[1] then
        imgui.TableNextColumn();
        if spell.trait == nil or spell.trait == '' or spell.trait == 'None' then
            imgui.TextColored(MUTED, 'None');
        else
            imgui.Text(spell.trait);
        end
    end

    if state.columns.mob_family[1] then
        imgui.TableNextColumn();
        if spell.mob_family == nil or spell.mob_family == '' then
            imgui.TextColored(MUTED, '--');
        else
            imgui.Text(spell.mob_family);
        end
    end
end

-- Fallback for an Ashita build without ImGui tables.
function draw_fallback_rows(filtered, first, last)
    local x = 300;

    imgui.TextColored(state.header_color, 'Spell');

    if state.columns.level[1] then
        imgui.SameLine(); imgui.SetCursorPosX(x); imgui.TextColored(state.header_color, 'Lvl');
        x = x + 55;
    end
    if state.columns.points[1] then
        imgui.SameLine(); imgui.SetCursorPosX(x); imgui.TextColored(state.header_color, 'Points');
        x = x + 65;
    end
    if state.columns.learn_skill[1] then
        imgui.SameLine(); imgui.SetCursorPosX(x); imgui.TextColored(state.header_color, 'Learn Skill');
        x = x + 95;
    end
    if state.columns.type[1] then
        imgui.SameLine(); imgui.SetCursorPosX(x); imgui.TextColored(state.header_color, 'Type');
        x = x + 155;
    end
    if state.columns.trait[1] then
        imgui.SameLine(); imgui.SetCursorPosX(x); imgui.TextColored(state.header_color, 'Trait');
        x = x + 215;
    end
    if state.columns.mob_family[1] then
        imgui.SameLine(); imgui.SetCursorPosX(x); imgui.TextColored(state.header_color, 'Mob Family');
    end
    imgui.Separator();

    for i = first, last do
        local spell = filtered[i];
        local known = is_known(spell.name);
        local selected = state.selected_spell == spell.name;
        local _, color = get_spell_display_state(spell);

        imgui.PushStyleColor(ImGuiCol_Text, color);
        if imgui.Selectable(spell.name .. '##fallback_' .. normalize_name(spell.name), selected) then
            state.selected_spell = spell.name;
            if state.location_interaction == 'click' then
                if state.location_open[1] and state.location_spell and state.location_spell.name == spell.name then
                    state.location_open[1] = false;
                    state.location_spell = nil;
                else
                    state.location_spell = spell;
                    state.location_reset_scroll = true;
                    state.location_open[1] = true;
                    state.location_apply_default_size = not state.location_size_initialized;
                end
            end
        end
        draw_learning_tooltip(spell);
        imgui.PopStyleColor(1);

        x = 300;
        if state.columns.level[1] then
            imgui.SameLine(); imgui.SetCursorPosX(x); imgui.Text(tostring(spell.level));
            x = x + 55;
        end
        if state.columns.points[1] then
            imgui.SameLine(); imgui.SetCursorPosX(x); imgui.Text(tostring(spell.points or '--'));
            x = x + 65;
        end
        if state.columns.learn_skill[1] then
            imgui.SameLine(); imgui.SetCursorPosX(x); imgui.Text(tostring(blue_magic_learn_skill(spell)));
            x = x + 95;
        end
        if state.columns.type[1] then
            imgui.SameLine(); imgui.SetCursorPosX(x); imgui.Text(tostring(spell.type or '--'));
            x = x + 155;
        end
        if state.columns.trait[1] then
            imgui.SameLine(); imgui.SetCursorPosX(x); imgui.Text(tostring(spell.trait or 'None'));
            x = x + 215;
        end
        if state.columns.mob_family[1] then
            imgui.SameLine(); imgui.SetCursorPosX(x); imgui.Text(tostring(spell.mob_family or '--'));
        end
    end
end
