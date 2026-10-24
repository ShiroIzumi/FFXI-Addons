--[[
    MogSuite - modules/actions/skillchain.lua (1.5.0)

    Skillchain helper: each weapon skill's skillchain properties (from
    LandSandBoat, scdata.lua), the magic burst elements they open, and
    which of your ready weapon skills chain into each other.
]]

-- [opener property][closer property] = result
SC_COMBOS = {
    Transfixion = { Compression = 'Compression', Scission = 'Distortion', Reverberation = 'Reverberation' },
    Compression = { Transfixion = 'Transfixion', Detonation = 'Detonation' },
    Liquefaction = { Scission = 'Scission', Impaction = 'Fusion' },
    Scission = { Liquefaction = 'Liquefaction', Reverberation = 'Reverberation', Detonation = 'Detonation' },
    Reverberation = { Induration = 'Induration', Impaction = 'Impaction' },
    Detonation = { Compression = 'Gravitation', Scission = 'Scission' },
    Induration = { Compression = 'Compression', Reverberation = 'Fragmentation', Impaction = 'Impaction' },
    Impaction = { Liquefaction = 'Liquefaction', Detonation = 'Detonation' },
    Gravitation = { Distortion = 'Darkness', Fragmentation = 'Fragmentation' },
    Distortion = { Gravitation = 'Darkness', Fusion = 'Fusion' },
    Fusion = { Gravitation = 'Gravitation', Fragmentation = 'Light' },
    Fragmentation = { Fusion = 'Light', Distortion = 'Distortion' },
    Light = { Light = 'Light' },
    Darkness = { Darkness = 'Darkness' },
};

SC_LEVEL = {
    Transfixion = 1, Compression = 1, Liquefaction = 1, Scission = 1, Reverberation = 1, Detonation = 1, Induration = 1, Impaction = 1,
    Gravitation = 2, Distortion = 2, Fusion = 2, Fragmentation = 2,
    Light = 3, Darkness = 3,
};

SC_BURST = {
    Liquefaction = { 'Fire' }, Scission = { 'Earth' }, Reverberation = { 'Water' }, Detonation = { 'Wind' },
    Induration = { 'Ice' }, Impaction = { 'Lightning' }, Transfixion = { 'Light' }, Compression = { 'Dark' },
    Fusion = { 'Fire', 'Light' }, Fragmentation = { 'Wind', 'Lightning' }, Gravitation = { 'Earth', 'Dark' }, Distortion = { 'Water', 'Ice' },
    Light = { 'Fire', 'Wind', 'Lightning', 'Light' }, Darkness = { 'Earth', 'Water', 'Ice', 'Dark' },
};

SC_COLOR = {
    Liquefaction = { 1.00, 0.45, 0.30, 1 }, Scission = { 0.85, 0.66, 0.36, 1 }, Reverberation = { 0.36, 0.66, 1.00, 1 },
    Detonation = { 0.45, 0.95, 0.55, 1 }, Induration = { 0.60, 0.88, 1.00, 1 }, Impaction = { 0.80, 0.58, 1.00, 1 },
    Transfixion = { 1.00, 0.95, 0.75, 1 }, Compression = { 0.62, 0.50, 0.75, 1 },
    Fusion = { 1.00, 0.62, 0.35, 1 }, Fragmentation = { 0.55, 0.95, 0.80, 1 }, Gravitation = { 0.70, 0.50, 0.40, 1 },
    Distortion = { 0.50, 0.80, 1.00, 1 }, Light = { 1.00, 0.95, 0.60, 1 }, Darkness = { 0.70, 0.45, 0.90, 1 },
};

function sc_key(name)
    return (tostring(name or ''):lower():gsub('[^%w]', ''));
end

function sc_props(name)
    if SC_PROPS == nil then return nil; end
    return SC_PROPS[sc_key(name)];
end

-- Best result of opener -> closer (highest level), or nil.
function sc_result(open_props, close_props)
    local best = nil;
    for _, o in ipairs(open_props or {}) do
        local row = SC_COMBOS[o];
        if row ~= nil then
            for _, c in ipairs(close_props or {}) do
                local r = row[c];
                if r ~= nil and (best == nil or SC_LEVEL[r] > SC_LEVEL[best]) then best = r; end
            end
        end
    end
    return best;
end

-- Your ready weapon skills (all weapon sections), unique by name.
function ready_ws_rows()
    local out, seen = {}, {};
    for _, sec in ipairs((state.lists and state.lists.ws) or {}) do
        for _, row in ipairs(sec.rows or {}) do
            if row.k == 'ws' and row.status == 'ready' and not seen[row.name] then
                seen[row.name] = true;
                out[#out + 1] = row;
            end
        end
    end
    return out;
end

local function colored_list(list, sep)
    for i, p in ipairs(list) do
        if i > 1 then imgui.SameLine(0, 4); imgui.TextColored(UI_MUTED, sep); imgui.SameLine(0, 4); end
        imgui.TextColored(SC_COLOR[p] or UI_TEXT, p);
    end
end

-- Lines for the weapon skill tooltip / details.
function draw_ws_skillchain(row)
    local props = sc_props(row.name);
    if props == nil or #props == 0 then return; end
    imgui.TextColored(UI_MUTED, 'Skillchain:');
    imgui.SameLine(0, 6);
    colored_list(props, '/');
    if config.show_sc_combos == false then return; end
    local opens, closes = {}, {};
    for _, other in ipairs(ready_ws_rows()) do
        if other.name ~= row.name then
            local op = sc_props(other.name);
            local r1 = sc_result(props, op);
            if r1 ~= nil then opens[#opens + 1] = { other.name, r1 }; end
            local r2 = sc_result(op, props);
            if r2 ~= nil then closes[#closes + 1] = { other.name, r2 }; end
        end
    end
    local function by_level(a, b)
        if SC_LEVEL[a[2]] ~= SC_LEVEL[b[2]] then return SC_LEVEL[a[2]] > SC_LEVEL[b[2]]; end
        return a[1] < b[1];
    end
    table.sort(opens, by_level);
    table.sort(closes, by_level);
    local function lines(title, list, first_is_me)
        if #list == 0 then return; end
        imgui.TextColored(UI_MUTED, title);
        for i, e in ipairs(list) do
            if i > 6 then imgui.TextColored(UI_MUTED, ('  ...and %d more'):fmt(#list - 6)); break; end
            imgui.TextColored(UI_TEXT, '  ' .. (first_is_me and (row.name .. ' > ' .. e[1]) or (e[1] .. ' > ' .. row.name)));
            imgui.SameLine(0, 6);
            imgui.TextColored(SC_COLOR[e[2]] or UI_TEXT, e[2]);
            imgui.SameLine(0, 6);
            imgui.TextColored(UI_MUTED, '(MB ' .. table.concat(SC_BURST[e[2]] or {}, ', ') .. ')');
        end
    end
    lines('Opens into:', opens, true);
    lines('Closes after:', closes, false);
end

-- Weapon Skills tab: every chain your ready weapon skills can make.
function draw_skillchain_panel(dl, width)
    if config.show_sc_panel == false then return; end
    local ws = ready_ws_rows();
    if #ws < 1 then return; end
    local pairs_list = {};
    for _, a in ipairs(ws) do
        for _, b in ipairs(ws) do
            local r = sc_result(sc_props(a.name), sc_props(b.name));
            if r ~= nil then pairs_list[#pairs_list + 1] = { a.name, b.name, r }; end
        end
    end
    table.sort(pairs_list, function(x, y)
        if SC_LEVEL[x[3]] ~= SC_LEVEL[y[3]] then return SC_LEVEL[x[3]] > SC_LEVEL[y[3]]; end
        if x[3] ~= y[3] then return x[3] < y[3]; end
        return x[1] < y[1];
    end);
    local collapsed = draw_sub_header(dl, 'ws_skillchains', 'Skillchains (your ready weapon skills)', #pairs_list, width, false);
    if collapsed then return; end
    if #pairs_list == 0 then
        imgui.TextDisabled('    Your ready weapon skills do not chain with each other. Party members can open or close for you.');
        return;
    end
    imgui.Indent(18);
    for _, p in ipairs(pairs_list) do
        imgui.TextColored(UI_TEXT, p[1]);
        imgui.SameLine(0, 4);
        imgui.TextColored(UI_MUTED, '>');
        imgui.SameLine(0, 4);
        imgui.TextColored(UI_TEXT, p[2]);
        imgui.SameLine(0, 8);
        imgui.TextColored(SC_COLOR[p[3]] or UI_TEXT, p[3]);
        imgui.SameLine(0, 6);
        imgui.TextColored(UI_MUTED, ('Lv%d  MB %s'):fmt(SC_LEVEL[p[3]], table.concat(SC_BURST[p[3]] or {}, ', ')));
    end
    imgui.Unindent(18);
end
