--[[
    MogSuite - Crafting settings (pages in the MogSuite settings window).
]]

module_config_dirty = function() mark_dirty(); end

local ON = { default_on = true };
local ARMED = {};

local function config_window()
    ui.section('WINDOW');
    ui.check('Lock position and size', config, 'locked', 'Stops the Crafting window from being moved or resized.');
    ui.slider_f('Size', config, 'font_scale', 0.80, 2.00, '%.2fx', 'Text size of the Crafting window.');
    if ui.button('Reset window position', 'cr_resetpos', 'Puts the Crafting window back in the middle of the screen.') then module_reset_position(); end

    ui.section('RECIPES');
    ui.slider_i('Skill-up range', config, 'skillup_range', 1, 20, 'up to %d over your skill', 'On the Skills tab: how far above your skill a recipe still counts as "for skill-ups".');
    ui.info('Recipes: LandSandBoat (the server HorizonXI is built on), Horizon-era crafts only. HorizonXI may differ; the HorizonXI wiki is the final word.');
end

local function config_ledger()
    ui.section('SYNTHESIS LEDGER');
    ui.info('Every synth you make is counted per recipe (NQ / HQ1-3 / break, the day, the moon, which way you faced). Kept in config\\addons\\mogsuite\\synth_ledger.lua for all your characters.');
    ui.check('Keep the ledger', config.ledger, 'enabled', nil, ON);
    ui.check('A chat line after each synth', config.ledger, 'chat', 'Recipe, NQ / HQ / break and your rates for it so far.');
    if ui.want('clear ledger', 'delete forget synths') then
        if ui.danger('Clear the ledger', 'cr_clearledger', ARMED, 'Forgets every synth (all characters).') then
            LEDGER = {};
            save_ledger();
        end
    end
end

module_config_sections = {
    { key = 'window', label = 'Window', draw = config_window, desc = 'The Crafting window and recipes.' },
    { key = 'ledger', label = 'Ledger', draw = config_ledger, desc = 'Your synths: HQ and break rates per recipe.' },
};
