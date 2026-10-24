--[[
    MogSuite - modules/calendar/state.lua
]]

state = {
    visible = { false },
    apply_geometry = true,
    settings_dirty = false,
    last_save = 0,
    vana_month = nil,          -- shown Vana'diel month (index from year 0), nil = now
    earth_month = nil,         -- { y, m } shown, nil = now
    earth_day = nil,           -- { y, m, d } picked in the Earth month
    login_at = nil,            -- os.clock() of the last login
    login_shown = false,
    login_lines = nil,
    toast = nil,               -- { lines, until }
    ready_seen = {},           -- [timer id] = true once its "ready" was announced
    event_seen = {},           -- [event key] = true once announced
    form = nil,                -- the event / timer being added or edited
    confirm = {},
};

function mark_dirty() state.settings_dirty = true; end
