--[[
    MogSuite - modules/actions/use.lua

    Using actions (only ever when you click), macro lines and pinned actions.
]]

-- ============================================================================
-- Using things (only ever on click)
-- ============================================================================

function command_prefix(row)
    if row.k == 'pet' or row.k == 'bp' then return '/pet'; end
    if row.k == 'ws' then return '/ws'; end
    if row.k == 'ma' then return '/ma'; end
    return '/ja';
end

-- Targets bits: 0x01 self, 0x02 player, 0x04 party, 0x08 alliance,
-- 0x10 NPC, 0x20 enemy.
function default_target(row)
    if row.k == 'ws' then return '<t>'; end
    if row.k == 'pet' then return PET_ENEMY[row.name] and '<t>' or '<me>'; end
    local t = tonumber(res_field(row.res, 'Targets')) or 0;
    if row.k == 'bp' and t == 0 then return (row.bp == 'rage') and '<t>' or '<me>'; end
    if bit.band(t, 0x20) ~= 0 then return '<t>'; end
    if t == 0 or bit.band(t, 0xFE) == 0 then return '<me>'; end
    return has_target() and '<t>' or '<me>';
end

function can_target_self(row)
    if row.k == 'ws' then return false; end
    if row.k == 'pet' then return not PET_ENEMY[row.name]; end
    local t = tonumber(res_field(row.res, 'Targets')) or 0;
    if row.k == 'bp' and t == 0 then return row.bp ~= 'rage'; end
    return t == 0 or bit.band(t, 0x01) ~= 0;
end

function macro_line(row, target)
    return ('%s "%s" %s'):fmt(command_prefix(row), row.name, target or default_target(row));
end

function use_row(row, target)
    if row == nil or row.status ~= 'ready' then return; end
    AshitaCore:GetChatManager():QueueCommand(1, macro_line(row, target));
end

function is_pinned(row)
    for _, p in ipairs(config.pinned or {}) do
        if p.k == row.k and p.n == row.name then return true; end
    end
    return false;
end

function toggle_pin(row)
    config.pinned = config.pinned or T{};
    for i, p in ipairs(config.pinned) do
        if p.k == row.k and p.n == row.name then
            table.remove(config.pinned, i);
            mark_dirty();
            return;
        end
    end
    table.insert(config.pinned, T{ k = row.k, n = row.name });
    mark_dirty();
end

-- Finds the live row for a pinned / selected entry.
function find_row(k, name)
    for _, tab in pairs(state.lists) do
        for _, sec in ipairs(tab) do
            for _, row in ipairs(sec.rows) do
                if row.k == k and row.name == name then return row; end
            end
        end
    end
    return nil;
end

function capture_geometry(geom)
    local x, y = imgui.GetWindowPos();
    local w, h = imgui.GetWindowSize();
    x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h);
    if x == nil or w == nil then return; end
    if math.abs(x - geom.x) >= 1 or math.abs(y - geom.y) >= 1 or math.abs(w - geom.w) >= 1 or math.abs(h - geom.h) >= 1 then
        geom.x, geom.y, geom.w, geom.h = x, y, w, h;
        mark_dirty();
    end
end
