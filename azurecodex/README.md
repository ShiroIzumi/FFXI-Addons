# Azure Codex

**Azure Codex (orig BLUSpells)** is an Ashita v4 addon built
specifically for **HorizonXI Blue Mage** players. It combines Blue Magic
progression tracking, spell-learning locations, build planning, trait
calculation, and saved spell loadouts in one interface.

Azure Codex is intentionally tailored to HorizonXI's current era and
content progression rather than modern retail FFXI.

**Authors:** Izumi (ShiroIzumi) / Kyrias\
**Special thanks:** Demiora for testing

------------------------------------------------------------------------

## Features

-   Tracks all **106 Blue Magic spells** currently supported by the
    addon.
-   Detects learned spells directly from the local character.
-   Displays **learned, learnable, and currently unlearnable** spells
    with configurable colors.
-   Uses your current **Blue Magic skill** and BLU level to show
    progression and learning readiness.
-   Shows learned count, missing count, completion percentage, BLU
    skill, and BLU point information.
-   Filters the spell list by **All**, **Known**, **Missing**, or **Up
    to your current BLU level**.
-   Searches across spell information with support for `|` OR searches.
-   Sortable spell table with Level, Points, Learn Skill, Type, Trait,
    and Mob Family data.
-   Configurable visible columns, row spacing, paging behavior, font
    scale, colors, and window appearance.
-   Optional persistence of search, filter, and sort settings.
-   Automatically highlights newly learned spells.

![Azure Codex main spell list](screenshots/main-spell-list.png)

## Spell Learning & Location Data

Select a spell to view HorizonXI-specific information about where it can
be learned.

-   Displays learning zones and the mobs that use the selected Blue
    Magic spell.
-   Supports multi-zone and multi-mob learning data.
-   Learned From information can open by **Click** or **Hover**.
-   Location windows retain their position and size.
-   Mob lists automatically use a compact multi-column layout where
    appropriate.
-   Location data is curated for HorizonXI's available content.

![Learned From window](screenshots/learned-from.png)

### Zone Info

The **Zone Info** window provides the reverse view: instead of asking
where a specific spell can be learned, it shows which tracked Blue Magic
spells can be learned from mobs in your current zone.

-   Automatically identifies the current zone.
-   Shows zone-specific learning progress.
-   Lists applicable spells and mobs.
-   Can hide already-known spells.
-   Can be opened independently of the main Azure Codex window.
-   Position and size can be locked from configuration.

![Zone Info window](screenshots/zone-info.png)

## BLUPrints

**BLUPrints** is the build-planning workspace for creating Blue Magic
spell sets before equipping them.

-   Select up to **20 learned spells**.
-   Enforces the character's current **BLU point cap**.
-   Shows the point cost of every spell.
-   Unknown spells remain visible for planning/reference but cannot be
    selected.
-   Uses the same Known / Learnable / Unlearnable colors configured for
    the main spell list.
-   Search within the available spell list.
-   Select the character's currently equipped Blue Magic.
-   Clear the current build or all checked spells.
-   Equip the planned build directly.
-   Name and save builds for later use.

The companion panel displays the active **Spell Card** and **Trait
Calculator** while BLUPrints is open.

### Trait Calculator

Azure Codex totals the trait values contributed by the selected spells
and shows progress toward each trait tier. This makes it possible to see
how a proposed build contributes to traits before equipping it.

![BLUPrints build planner and trait
calculator](screenshots/bluprints.png)

## Azure Loadout

**Azure Loadout** provides quick access to saved BLUPrints sets.

-   Reads saved Blue Magic builds from the addon's BLUPrints folder.
-   Refreshes the available loadout list on demand.
-   Loads and equips a saved spell set directly in game.
-   Keeps reusable spell configurations separate from the active
    build-planning workflow.

## Configuration

Azure Codex includes an in-game configuration window with controls for
the main UI and supporting windows.

### Font & Colors

Customize:

-   Font scale
-   Known spell color
-   Unknown / Learnable spell color
-   Unknown / Unlearnable spell color
-   Header / accent color
-   Paging button color
-   Window background and appearance options

![Font and color configuration](screenshots/config-colors.png)

### Display

Configure:

-   Compact or normal row spacing
-   Automatic or fixed rows per page
-   Visible spell-table columns:
    -   Level
    -   Points
    -   Learn Skill
    -   Type
    -   Trait
    -   Mob Family

![Display configuration](screenshots/config-display.png)

### Behavior

Configure:

-   Remember Search / Filter / Sort
-   Auto-highlight newly learned spells
-   Click or Hover interaction for Learned From information
-   Reset addon settings

![Behavior configuration](screenshots/config-behavior.png)

## Commands

  -----------------------------------------------------------------------
  Command                             Description
  ----------------------------------- -----------------------------------
  `/azurecodex`                       Toggle the main Azure Codex window.

  `/ac`                               Short alias for `/azurecodex`.

  `/azurecodex config`                Toggle the configuration window.

  `/ac config`                        Short alias for the configuration
                                      window.

  `/azurecodexzone`                   Toggle Zone Info directly.

  `/acz`                              Short alias for Zone Info.

  `/bluspells`, `/bsp`, `/bsl`        Legacy main-window aliases retained
                                      for compatibility.

  `/bluspellszone`, `/bsz`            Legacy Zone Info aliases retained
                                      for compatibility.
  -----------------------------------------------------------------------

## Installation

1.  Copy the `azurecodex` folder into your Ashita v4 `addons` directory.
2.  Start FFXI through Ashita.
3.  Load the addon with:

``` text
/addon load azurecodex
```

4.  Open Azure Codex with:

``` text
/ac
```

To load Azure Codex automatically, add the addon load command to your
normal Ashita startup configuration.

## Compatibility

Azure Codex is designed for:

-   **Ashita v4**
-   **HorizonXI**
-   HorizonXI's current Blue Mage era/content progression

Spell, trait, mob, and location information is HorizonXI-focused and
should not be treated as a modern retail FFXI database.

------------------------------------------------------------------------

## Credits

**Izumi (ShiroIzumi)** --- Original BLUSpells / Azure Codex development\
**Kyrias** --- Collaboration, BLUPrints, spell-set/build functionality,
and data development\
**Demiora** --- Testing

Azure Codex continues the original BLUSpells project under its new
collaborative name.
