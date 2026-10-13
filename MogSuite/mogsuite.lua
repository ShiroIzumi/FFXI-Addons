--[[
    MogSuite - Ashita v4 / HorizonXI

    Your character, your bags and everything you can do, in one suite:
      Character  (C)  stats, resistances, jobs, skills, currencies, gear stats
      Inventory  (B)  every bag, key items, item values, your other characters
      Actions    (P)  abilities, weapon skills, magic, pets and blood pacts
      Requests        popups for party / alliance invites and trade requests

    Commands: /ms (also /mog, /mogsuite)
      /ms             open / close the settings window
      /ms char        open / close the Character window
      /ms inv         open / close the Inventory window
      /ms act         open / close the Actions window
      /ms reset       move every window back to its default place
      /ms test party | alliance | trade   show a test request popup
      /ms help        list the commands

    Nothing is ever done for you: items, abilities and spells are only used
    when you click them.

    Layout:
      core/       theme, keys, module loader, the config window, mouse pointer
      modules/    character, inventory, actions (one folder each)
      data/       shared data (your characters' bags, prices, key item marks)
]]

addon.name    = 'mogsuite';
addon.author  = 'Izumi (ShiroIzumi) / Kyrias (.kyri)';
addon.version = '1.2.0';
addon.desc    = 'MogSuite: your character, inventory and actions in one suite.';
addon.link    = '';

require('common');
local imgui    = require('imgui');
local settings = require('settings');
local ffi      = require('ffi');
local bit      = require('bit');
local d3d      = require('d3d8');

local theme        = require('core.theme');
local keys         = require('core.keys');
local loader       = require('core.loader');
local configwindow = require('core.configwindow');
local cursor       = require('core.cursor');

-- Wrap imgui.Begin / popups before any window is drawn so the visible mouse
-- pointer knows when the mouse is over a MogSuite window.
cursor.install();

-- ============================================================================
-- Settings (saved per character): Global + one table per module
-- ============================================================================

local defaults = T{
    global = T{
        theme = 'silver',
        use_theme_bg = true,
        background = T{ 0.035, 0.035, 0.040 },
        opacity = 0.94,
        text_effect = 'shadow',     -- none | shadow | outline | both | glow
        effect_color = T{ 0.0, 0.0, 0.0 },
        effect_opacity = 0.85,
        config_scale = 1.0,
        config_visible = false,
        config_tab = 'character',
        config_section = T{},
        config_window = T{ x = 180, y = 140, w = 640, h = 620 },
        -- Visible mouse pointer over MogSuite windows (FFXI hides the
        -- Windows one).
        mouse_cursor = true,
        mouse_cursor_size = 1.4,
        mouse_cursor_color = T{ 1.00, 0.10, 0.75, 1.00 },
        mouse_cursor_outline = T{ 0.05, 0.00, 0.05, 1.00 },
        mouse_cursor_shadow = true,
        keys = T{
            character = T{ enabled = true, key = 0x43, ctrl = false, alt = false, shift = false }, -- C
            inventory = T{ enabled = true, key = 0x42, ctrl = false, alt = false, shift = false }, -- B
            actions   = T{ enabled = true, key = 0x50, ctrl = false, alt = false, shift = false }, -- P
        },
    },
    character = loader.read('modules\\character\\defaults.lua'),
    inventory = loader.read('modules\\inventory\\defaults.lua'),
    actions   = loader.read('modules\\actions\\defaults.lua'),
    requests  = loader.read('modules\\requests\\defaults.lua'),
};

local function is_list(t)
    return type(t) == 'table' and t[1] ~= nil;
end

local function copy(v)
    if type(v) ~= 'table' then return v; end
    local out = T{};
    for k, x in pairs(v) do out[k] = copy(x); end
    return out;
end

-- Adds anything missing from the saved settings (for example a newer
-- option), without touching what is there.
local function fill_defaults(dst, def)
    for k, v in pairs(def) do
        if dst[k] == nil then
            dst[k] = copy(v);
        elseif type(v) == 'table' and type(dst[k]) == 'table' and not is_list(v) then
            fill_defaults(dst[k], v);
        end
    end
end

local cfg = settings.load(defaults);
fill_defaults(cfg, defaults);
theme.set_global(cfg.global);

local suite = {
    dirty = false,
    last_save = 0,
    errors = {},
    state = {},
};

local function mark_global_dirty() suite.dirty = true; end

-- ============================================================================
-- Modules
-- ============================================================================

-- What MogSuite gives every module (shared look, keys, settings).
local MS = {
    version = addon.version,
};

function MS.open_config(tab)
    configwindow.show(cfg.global, tab);
    mark_global_dirty();
end

local module_settings = {
    save = function() settings.save(); end,
};

local function inject(name)
    local t = {
        imgui = imgui, ffi = ffi, bit = bit, d3d = d3d, keys = keys,
        settings = module_settings, MS = MS,
        config = cfg[name], G = cfg.global,
        COLORS = theme.COLORS, EFFECTS = theme.EFFECTS,
        accent = theme.accent, ui_accent = theme.accent,
        push_theme = theme.push, pop_theme = theme.pop,
        draw_item_underline = theme.draw_item_underline,
        styled_tab = theme.styled_tab, draw_styled_tab = theme.styled_tab,
        color_tab = theme.color_tab, chip = theme.chip,
        toggle_button = theme.toggle_button, draw_toggle_button = theme.toggle_button,
        tab_row = theme.tab_row, draw_tab_row = theme.tab_row,
        section_header = theme.section_header, help_marker = theme.help_marker, tip = theme.tip,
        text_w = theme.text_w, align_label = theme.align_label, begin_child = theme.begin_child,
        color_edit = theme.color_edit, draw_fx_text = theme.draw_fx_text,
    };
    for _, n in ipairs({ 'UI_TITLE', 'UI_TITLE_ACTIVE', 'UI_POPUP', 'UI_BORDER', 'UI_CONTROL', 'UI_CONTROL_HOVER',
        'UI_CONTROL_ACTIVE', 'UI_TEXT', 'UI_MUTED', 'UI_ACCENT', 'UI_ACCENT_TEXT', 'UI_TRANSPARENT', 'UI_WHITE', 'UI_DANGER' }) do
        t[n] = theme[n];
    end
    return t;
end

local character_inject = inject('character');
character_inject.skilldata = loader.read('modules\\character\\skilldata.lua');

local modules = {
    loader.load_module('character', { 'state', 'stats', 'layout', 'overview', 'skills', 'gearstats', 'currencies', 'window', 'config', 'init' }, character_inject),
    loader.load_module('inventory', { 'state', 'items', 'store', 'prices', 'scan', 'actions', 'menus', 'views', 'keyitems', 'window', 'lootlog', 'config', 'init' }, inject('inventory')),
    loader.load_module('actions', { 'state', 'data', 'player', 'lists', 'pets', 'use', 'draw', 'rows', 'window', 'config', 'init' }, inject('actions')),
    loader.load_module('requests', { 'state', 'popup', 'config', 'init' }, inject('requests')),
};
local by_key = {};
for _, env in ipairs(modules) do by_key[env.module_info.key] = env; end

-- Calls a module function; an error is printed once instead of every frame.
local function call(env, fn_name, ...)
    local fn = env[fn_name];
    if fn == nil then return; end
    local ok, err = pcall(fn, ...);
    if not ok then
        local key = env.module_info.key .. ':' .. tostring(err);
        if not suite.errors[key] then
            suite.errors[key] = true;
            print(('[MogSuite] %s error: %s'):fmt(env.module_info.label, tostring(err)));
        end
    end
end

if cfg.global.config_visible then configwindow.open[1] = true; end

print(('[MogSuite] v%s loaded. %s Character, %s Inventory, %s Actions. /ms for settings, /ms help for commands.'):fmt(
    addon.version, keys.text(cfg.global.keys.character), keys.text(cfg.global.keys.inventory), keys.text(cfg.global.keys.actions)));

-- Ashita replaces the settings after login / a character change.
settings.register('settings', 'mogsuite_settings_update', function(s)
    if s == nil then return; end
    cfg = s;
    fill_defaults(cfg, defaults);
    theme.set_global(cfg.global);
    configwindow.open[1] = cfg.global.config_visible == true;
    configwindow.apply_geometry = true;
    keys.listening = nil;
    for _, env in ipairs(modules) do
        local key = env.module_info.key;
        env.config = cfg[key];
        env.G = cfg.global;
        call(env, 'module_settings_changed');
    end
end);

local function config_ctx()
    return { G = cfg.global, modules = modules, dirty = mark_global_dirty, version = addon.version, state = suite.state };
end

-- ============================================================================
-- Commands
-- ============================================================================

local function print_help()
    print('[MogSuite] /ms - open / close the settings window');
    print('[MogSuite] /ms char - Character window   (key: ' .. keys.text(cfg.global.keys.character) .. ')');
    print('[MogSuite] /ms inv - Inventory window    (key: ' .. keys.text(cfg.global.keys.inventory) .. ')');
    print('[MogSuite] /ms act - Actions window      (key: ' .. keys.text(cfg.global.keys.actions) .. ')');
    print('[MogSuite] /ms reset - move every window back to its default place');
    print('[MogSuite] /ms test party | alliance | trade - show a test request popup');
    print('[MogSuite] /mog and /mogsuite work the same as /ms.');
end

ashita.events.register('command', 'mogsuite_command_cb', function(e)
    local args = e.command:args();
    if #args == 0 or not args[1]:any('/ms', '/mog', '/mogsuite') then return; end
    e.blocked = true;

    local sub = args[2] and tostring(args[2]):lower() or '';
    if sub == '' or sub == 'config' or sub == 'cfg' or sub == 'settings' then
        if configwindow.open[1] then configwindow.open[1] = false; else configwindow.show(cfg.global, nil); end
        mark_global_dirty();
    elseif sub == 'char' or sub == 'character' or sub == 'c' or sub == 'sheet' then
        call(by_key.character, 'module_toggle');
    elseif sub == 'inv' or sub == 'inventory' or sub == 'i' or sub == 'bags' or sub == 'b' then
        call(by_key.inventory, 'module_toggle');
    elseif sub == 'act' or sub == 'actions' or sub == 'a' or sub == 'p' then
        call(by_key.actions, 'module_toggle');
    elseif sub == 'test' then
        local kind = args[3] and tostring(args[3]):lower() or 'party';
        if kind ~= 'alliance' and kind ~= 'trade' then kind = 'party'; end
        if by_key.requests ~= nil then call(by_key.requests, 'show_test', kind); end
    elseif sub == 'reset' then
        for _, env in ipairs(modules) do call(env, 'module_reset_position'); end
        print('[MogSuite] Every window was moved back to its default place.');
    else
        print_help();
    end
end);

-- ============================================================================
-- Keys
-- ============================================================================

ashita.events.register('key', 'mogsuite_key_cb', function(e)
    if e == nil then return; end
    local blocked = keys.handle(e, cfg.global.keys,
        function(name)
            local env = by_key[name];
            if env ~= nil then call(env, 'module_toggle'); end
        end,
        function(name, vk, ctrl, alt, shift)
            local bind = cfg.global.keys[name];
            if bind == nil then return; end
            bind.key, bind.ctrl, bind.alt, bind.shift, bind.enabled = vk, ctrl, alt, shift, true;
            mark_global_dirty();
        end);
    if blocked then e.blocked = true; end
end);

-- ============================================================================
-- Game events
-- ============================================================================

ashita.events.register('packet_in', 'mogsuite_packet_in_cb', function(e)
    if e == nil then return; end
    for _, env in ipairs(modules) do call(env, 'module_packet_in', e); end
end);

ashita.events.register('packet_out', 'mogsuite_packet_out_cb', function(e)
    if e == nil then return; end
    for _, env in ipairs(modules) do call(env, 'module_packet_out', e); end
end);

ashita.events.register('text_in', 'mogsuite_text_in_cb', function(e)
    if e == nil then return; end
    for _, env in ipairs(modules) do call(env, 'module_text_in', e); end
end);

ashita.events.register('d3d_present', 'mogsuite_present_cb', function()
    for _, env in ipairs(modules) do call(env, 'module_present'); end
    configwindow.draw(config_ctx());

    -- Last, so it sits above every MogSuite window.
    cursor.draw(cfg.global);

    if suite.dirty and (os.clock() - suite.last_save) > 0.6 and not imgui.IsAnyItemActive() then
        suite.dirty = false;
        suite.last_save = os.clock();
        cfg.global.config_visible = configwindow.open[1] == true;
        settings.save();
    end
end);

ashita.events.register('unload', 'mogsuite_unload_cb', function()
    for _, env in ipairs(modules) do call(env, 'module_unload'); end
    cfg.global.config_visible = configwindow.open[1] == true;
    settings.save();
end);
