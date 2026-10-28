--[[
    MogSuite - Ashita v4 / HorizonXI

    Your character, your bags and everything you can do, in one suite:
      Character  (C)  stats, resistances, jobs, skills, currencies, gear stats
      Inventory  (B)  every bag, key items, item values, your other characters
      Actions    (P)  abilities, weapon skills, magic, pets and blood pacts
      Requests        popups for party / alliance invites and trade requests
      Calendar   (L)  Vana'diel days, moon, conquest, your timers and events (1.6.0)
      Crafting   (J)  skills, recipes, what you can make, your synth ledger (1.6.0)

    Commands: /ms (also /mog, /mogsuite)
      /ms             open / close the settings window
      /ms char        open / close the Character window
      /ms inv         open / close the Inventory window
      /ms act         open / close the Actions window
      /ms cal         open / close the Calendar window
      /ms craft       open / close the Crafting window
      /ms reset       move every window back to its default place
      /ms test party | alliance | trade   show a test request popup
      /ms help        list the commands

    Nothing is ever done for you: items, abilities and spells are only used
    when you click them.

    Layout:
      core/       theme, keys, module loader, the settings window (sidebar +
                  search, core/cfgui.lua), mouse pointer
      modules/    character, inventory, actions (one folder each)
      data/       shared data (your characters' bags, prices, key item marks)
]]

addon.name    = 'mogsuite';
addon.author  = 'Izumi (ShiroIzumi) / Kyrias (.kyri)';
addon.version = '1.6.9';
addon.desc    = 'MogSuite: your character, inventory, actions, calendar and crafting in one suite.';
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
local cfgui        = require('core.cfgui');
local fonts        = require('core.fonts');

-- Wrap imgui.Begin / popups before any window is drawn so the visible mouse
-- pointer knows when the mouse is over a MogSuite window.
cursor.install();
-- Tooltips follow Global > Fonts & Tooltips (size, colors, wrap).
fonts.install_tooltips();

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
        config_page = '',           -- last settings page ('module:page')
        config_window = T{ x = 180, y = 140, w = 780, h = 640 },
        -- Visible mouse pointer over MogSuite windows (FFXI hides the
        -- Windows one).
        mouse_cursor = true,
        mouse_cursor_size = 1.4,
        mouse_cursor_color = T{ 1.00, 0.10, 0.75, 1.00 },
        mouse_cursor_outline = T{ 0.05, 0.00, 0.05, 1.00 },
        mouse_cursor_shadow = true,
        esc_close = true,   -- Esc closes every MogSuite window (the game still gets Esc too)
        -- Fonts & tooltips (1.5.0). A Windows font is drawn at its real size,
        -- so it stays smooth at any UI scale; applies after a reload.
        font_family = 'tahoma',     -- see core/fonts.lua; 'default' = Ashita's pixel font
        font_custom = '',           -- 'custom': a .ttf file name in C:\Windows\Fonts, or a full path
        font_size = 15,             -- px at 100% (each window's own scale still applies)
        text_color_on = false,      -- use the colors below instead of the theme's
        text_color = T{ 0.93, 0.93, 0.95, 1.00 },
        muted_color = T{ 0.62, 0.62, 0.66, 1.00 },
        tooltip_custom = true,      -- apply the tooltip settings below
        tooltip_font = 'same',      -- 'same' = the window font, or a font key
        tooltip_size = 0,           -- px; 0 = the size of the window it belongs to
        tooltip_wrap = 0,           -- px; 0 = each tooltip's own width
        tooltip_padding = 8,
        tooltip_border = true,
        tooltip_text_color = T{ 0.95, 0.95, 0.97, 1.00 },
        tooltip_bg = T{ 0.04, 0.04, 0.05, 0.97 },
        keys = T{
            character = T{ enabled = true, key = 0x43, ctrl = false, alt = false, shift = false }, -- C
            inventory = T{ enabled = true, key = 0x42, ctrl = false, alt = false, shift = false }, -- B
            actions   = T{ enabled = true, key = 0x50, ctrl = false, alt = false, shift = false }, -- P
            calendar  = T{ enabled = true, key = 0x4C, ctrl = false, alt = false, shift = false }, -- L (1.6.0)
            crafting  = T{ enabled = true, key = 0x4A, ctrl = false, alt = false, shift = false }, -- J (1.6.0)
        },
    },
    character = loader.read('modules\\character\\defaults.lua'),
    inventory = loader.read('modules\\inventory\\defaults.lua'),
    actions   = loader.read('modules\\actions\\defaults.lua'),
    requests  = loader.read('modules\\requests\\defaults.lua'),
    calendar  = loader.read('modules\\calendar\\defaults.lua'),
    crafting  = loader.read('modules\\crafting\\defaults.lua'),
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
fonts.set_global(cfg.global);

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

-- Always opens (never closes) the settings window.
function MS.show_config(tab)
    configwindow.show(cfg.global, tab);
    mark_global_dirty();
end

-- A module's Config button: opens its settings, or closes the settings
-- window when it is already showing that module (1.5.1).
function MS.open_config(tab)
    local page = tostring(cfg.global.config_page or '');
    if tab ~= nil and configwindow.open[1] and page:match('^([^:]+)') == tab then
        configwindow.open[1] = false;
        cfg.global.config_visible = false;
    else
        configwindow.show(cfg.global, tab);
    end
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
        ui = cfgui,   -- settings-page widgets (search-aware), see core/cfgui.lua
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
    loader.load_module('character', { 'state', 'stats', 'layout', 'overview', 'skills', 'gearstats', 'currencies', 'recap', 'progress', 'equip', 'window', 'config', 'init' }, character_inject),
    loader.load_module('inventory', { 'state', 'items', 'store', 'prices', 'scan', 'actions', 'menus', 'views', 'extras', 'keyitems', 'window', 'lootlog', 'stacks', 'config', 'init' }, inject('inventory')),
    loader.load_module('actions', { 'state', 'data', 'scdata', 'player', 'lists', 'pets', 'use', 'draw', 'skillchain', 'rows', 'window', 'config', 'init' }, inject('actions')),
    loader.load_module('requests', { 'state', 'popup', 'config', 'init' }, inject('requests')),
    loader.load_module('calendar', { 'state', 'time', 'events', 'window', 'config', 'init' }, inject('calendar')),
    loader.load_module('crafting', { 'state', 'data', 'ledger', 'advice', 'window', 'config', 'init' }, inject('crafting')),
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
    fonts.set_global(cfg.global);
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
    print('[MogSuite] /ms cal - Calendar window     (key: ' .. keys.text(cfg.global.keys.calendar) .. ')');
    print('[MogSuite] /ms craft - Crafting window   (key: ' .. keys.text(cfg.global.keys.crafting) .. ')');
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
    elseif sub == 'cal' or sub == 'calendar' or sub == 'l' then
        call(by_key.calendar, 'module_toggle');
    elseif sub == 'craft' or sub == 'crafting' or sub == 'j' then
        call(by_key.crafting, 'module_toggle');
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

-- Esc closes every open MogSuite window: the settings window plus each
-- module's windows. Modules opt in by defining module_close_all() (every
-- module should; see the README's "Writing a module"). The key is never
-- blocked, so the game's own Esc (closing its menus) still works.
-- Ignored while you type (chat line open or a text box active) and while a
-- keybind is being captured.
local function close_all_windows()
    configwindow.open[1] = false;
    for _, env in ipairs(modules) do
        if type(env.module_close_all) == 'function' then
            call(env, 'module_close_all');
        end
    end
    mark_global_dirty();
end

local function is_esc_press(e)
    if (tonumber(e.wparam) or 0) ~= 0x1B then return false; end
    local lparam = tonumber(e.lparam) or 0;
    if bit.band(lparam, 0x80000000) ~= 0 then return false; end   -- key up
    if bit.band(lparam, 0x40000000) ~= 0 then return false; end   -- held (repeat)
    return true;
end

ashita.events.register('key', 'mogsuite_key_cb', function(e)
    if e == nil then return; end
    if cfg.global.esc_close ~= false and keys.listening == nil and is_esc_press(e) and not keys.typing() then
        close_all_windows();
        return;   -- not blocked: the game handles Esc as usual
    end
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

-- 1.6.0: a MogSuite key wins over the game. The 'key' event above stops the
-- window message; the game also reads the keyboard through DirectInput
-- (buffered events and the key state), so the same key is taken out there
-- too while it opens a MogSuite window.
local DIK = {
    [0x51] = 0x10, [0x57] = 0x11, [0x45] = 0x12, [0x52] = 0x13, [0x54] = 0x14, [0x59] = 0x15, [0x55] = 0x16, [0x49] = 0x17,
    [0x4F] = 0x18, [0x50] = 0x19, [0x41] = 0x1E, [0x53] = 0x1F, [0x44] = 0x20, [0x46] = 0x21, [0x47] = 0x22, [0x48] = 0x23,
    [0x4A] = 0x24, [0x4B] = 0x25, [0x4C] = 0x26, [0x5A] = 0x2C, [0x58] = 0x2D, [0x43] = 0x2E, [0x56] = 0x2F, [0x42] = 0x30,
    [0x4E] = 0x31, [0x4D] = 0x32,
    [0x31] = 0x02, [0x32] = 0x03, [0x33] = 0x04, [0x34] = 0x05, [0x35] = 0x06, [0x36] = 0x07, [0x37] = 0x08, [0x38] = 0x09,
    [0x39] = 0x0A, [0x30] = 0x0B,
    [0x70] = 0x3B, [0x71] = 0x3C, [0x72] = 0x3D, [0x73] = 0x3E, [0x74] = 0x3F, [0x75] = 0x40, [0x76] = 0x41, [0x77] = 0x42,
    [0x78] = 0x43, [0x79] = 0x44, [0x7A] = 0x57, [0x7B] = 0x58,
};

-- DirectInput codes of the MogSuite keys whose modifiers are held right now.
local function owned_diks()
    if keys.typing() then return nil; end
    local ctrl, alt, shift = keys.down(0x11), keys.down(0x12), keys.down(0x10);
    local out = nil;
    for _, bind in pairs(cfg.global.keys) do
        local dik = DIK[tonumber(bind.key) or 0];
        if dik ~= nil and bind.enabled ~= false and (bind.ctrl == true) == ctrl and (bind.alt == true) == alt and (bind.shift == true) == shift then
            out = out or {};
            out[dik] = true;
        end
    end
    return out;
end

ashita.events.register('key_data', 'mogsuite_keydata_cb', function(e)
    if e == nil or keys.listening ~= nil then return; end
    local own = owned_diks();
    if own ~= nil and own[tonumber(e.key) or -1] then e.blocked = true; end
end);

ashita.events.register('key_state', 'mogsuite_keystate_cb', function(e)
    if e == nil then return; end
    local own = owned_diks();
    if own == nil then return; end
    pcall(function()
        local p = ffi.cast('uint8_t*', e.data_modified_raw or e.data_raw);
        if p == nil then return; end
        for dik in pairs(own) do p[dik] = 0; end
    end);
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

-- Fonts are added to ImGui here (never while a frame is drawn).
ashita.events.register('load', 'mogsuite_load_cb', function()
    pcall(fonts.load, cfg.global);
end);

ashita.events.register('unload', 'mogsuite_unload_cb', function()
    for _, env in ipairs(modules) do call(env, 'module_unload'); end
    cfg.global.config_visible = configwindow.open[1] == true;
    settings.save();
end);
