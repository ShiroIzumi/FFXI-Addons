--[[
    MogSuite - modules/requests/state.lua

    Runtime state of the request popup.
]]

state = {
    popup = {
        active = false,
        kind = nil,             -- 'party' | 'alliance' | 'trade'
        name = '',
        opened_at = 0,
        trade_id = 0,
        trade_index = 0,
    },
    apply_geometry = true,
    settings_dirty = false,
    last_save = 0,
};

function mark_dirty() state.settings_dirty = true; end
