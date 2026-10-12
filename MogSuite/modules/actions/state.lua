--[[
    MogSuite - modules/actions/state.lua

    Runtime state of the Actions window.
]]

-- ============================================================================
-- State
-- ============================================================================

state = {
    visible = { config.visible ~= false },
    apply_geometry = true,
    settings_dirty = false,
    last_save = 0,
    search = { '' },

    me = nil,                   -- player snapshot (refreshed every frame)
    lists = {},                 -- built rows per tab
    lists_key = nil,
    lists_at = 0,
    spell_cache = nil,          -- static spell list for the current jobs
    spell_cache_key = nil,
    ja_cd = {},                 -- [recast timer id] = seconds left
    cd_max = {},                -- [cooldown key] = longest seen (for the bar)
    selected = nil,             -- { k, n }
    ctx = nil,                  -- row for the right-click menu
    copied_at = 0,
    pet = nil,                  -- your avatar / spirit, when one is out
};

function mark_dirty() state.settings_dirty = true; end
