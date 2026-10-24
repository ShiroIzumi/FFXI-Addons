--[[
    MogSuite - modules/crafting/state.lua
]]

state = {
    visible = { false },
    apply_geometry = true,
    settings_dirty = false,
    last_save = 0,
    search = { '' },
    selected = nil,            -- recipe shown on the right
    counts = {},               -- [item id] = how many you have (all bags)
    where = {},                -- [item id] = { [bag] = n }
    counts_at = 0,
    skills = {},               -- [craft name] = level
    confirm = {},
    list_cache = nil,
    list_key = nil,
};

function mark_dirty() state.settings_dirty = true; end
