--[[
    Azure Codex (orig BLUSpells) - Ashita v4 / HorizonXI
    Version 1.19.0

    Commands:
      /azurecodex
      /ac
      /bluspells   (legacy alias)
      /bsp         (legacy alias)
      /bsl         (legacy alias)
      /azurecodex config
      /ac config
      /acz          (Zone Info)
      /ac farm      (Farm Zones)
      /ac log       (Learned Log)


    Main goals:
      * Clean IzClock-style dark presentation.
      * Learned / missing / level-ready filtering.
      * Search across every visible data field with "|" OR searches.
      * Clickable sortable/resizable table headers.
      * Persistent filters/sort/search when desired.
      * Completion percentage/progress and missing count.
      * Selectable rows and newly-learned highlighting.
      * Configurable columns, colors, paging, spacing, font, window appearance.

    Files (all in this folder):
      azurecodex.lua    this file: addon info, then loads the files below
      spells.lua        the 106 HorizonXI Blue Magic spells
      locations.lua     where each spell is learned (zones / mobs)
      ac\core.lua       settings, defaults, shared state
      ac\pointer.lua    the visible mouse pointer
      ac\theme.lua      colors, themes, small widgets
      ac\data.lua       spell data, traits, game reads, search / filters
      ac\spelltable.lua the spell list table
      ac\config.lua     saving, resets, Config window tabs
      ac\bluprints.lua  BLUPrints: builds, equipping, traits, planner
      ac\zones.lua      Spell Locations, Zone Info, Farm Zones, Learned Log
      ac\targettag.lua  the Target Tag
      ac\pages.lua      About, BLUPrint-View, Azure Loadout, Config window
      ac\setcooldown.lua the spell set cooldown
      ac\mainwindow.lua sidebar and main window
      ac\events.lua     Ashita events (commands, drawing, packets)

    The ac\ files all run in one shared Azure Codex scope (not the global
    one), so they can use each other's functions and tables directly.
]]--

addon.name      = 'azurecodex';
addon.author    = 'Izumi (ShiroIzumi) / Kyrias (.kyri)';
addon.version   = '1.19.0';
addon.desc      = 'Azure Codex (orig BLUSpells) - HorizonXI Blue Magic learning, location, build, trait, and spell-set toolkit.';
addon.link      = '';

require 'common';

local FILES = {
    'core', 'pointer', 'theme', 'data', 'spelltable', 'config', 'bluprints',
    'zones', 'targettag', 'pages', 'setcooldown', 'mainwindow', 'events',
};

-- One shared scope for every Azure Codex file; reads fall back to the normal
-- globals (imgui constants, AshitaCore, ...), writes stay in this scope.
local scope = setmetatable({}, { __index = _G });

local base = tostring(addon.path or ''):gsub('[\\/]+$', '');
for _, name in ipairs(FILES) do
    local path = ('%s\\ac\\%s.lua'):format(base, name);
    local chunk, err = loadfile(path);
    if chunk == nil then
        error(('[Azure Codex] Could not load %s: %s'):format(path, tostring(err)));
    end
    setfenv(chunk, scope);
    chunk();
end
