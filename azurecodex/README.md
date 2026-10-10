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
-   Filters by **All**, **Known**, **Missing**, or **Up to your current
    BLU level**.
-   Searches across spell information with support for `|` OR searches.
-   Sortable spell table with Level, Points, Learn Skill, Type, Trait,
    and Mob Family data.
-   Configurable visible columns, row spacing, paging behavior, font
    scale, colors, and window appearance.
-   Optional persistence of search, filter, and sort settings.
-   Automatically highlights newly learned spells.

![Azure Codex main spell list](Screenshots/Screenshot%202026-09-16%20202509.png)

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

![Learned From window](Screenshots/Screenshot%202026-09-16%20202544.png)

### Zone Info

The **Zone Info** window provides the reverse view: it shows which
tracked Blue Magic spells can be learned from mobs in your current zone.

-   Automatically identifies the current zone.
-   Shows zone-specific learning progress.
-   Lists applicable spells and mobs.
-   Can hide already-known spells.
-   Can be opened independently of the main Azure Codex window.
-   Position and size can be locked from configuration.

![Zone Info window](Screenshots/Screenshot%202026-09-16%20202556.png)

## BLUPrints

**BLUPrints** is the build-planning workspace for creating Blue Magic
spell sets before equipping them.

-   Select up to **20 learned spells**.
-   Enforces the character's current **BLU point cap**.
-   Shows the point cost of every spell.
-   Unknown spells remain visible for reference but cannot be selected.
-   Uses the configured Known / Learnable / Unlearnable colors.
-   Search within the available spell list.
-   Select the character's currently equipped Blue Magic.
-   Clear the current build or all checked spells.
-   Equip the planned build directly.
-   Name and save builds for later use.

The companion panel displays the active **Spell Card** and **Trait
Calculator** while BLUPrints is open.

### Trait Calculator

Azure Codex totals the traits given by the selected spells using the
HorizonXI / LandSandBoat 75-era rules and shows each trait's tier and
progress toward the next one.

-   Each spell gives 4 points to its trait (8 points = a tier for most
    traits). Some spells count more: Self-Destruct, Frightful Roar,
    Light of Penance x2; Voracious Trunk x3; Actinic Burst, Plasma
    Charge, Winds of Promyvion x4 (shown as "x2" etc. next to the trait).
-   Auto Refresh needs 32 points; Resist Gravity tiers are 8 / 12 / 16;
    each trait has its own maximum tier.
-   **Trait Planner** lists the cheapest known spells that reach each
    trait's next tier, with an **Add** button when they fit your limits.
    Tick **All traits** to plan traits not in the build yet.
-   **VS Equipped** shows which spells a build would add or remove
    compared with your currently set spells.

Point and slot limits follow your BLU level (HorizonXI table: 10 points /
6 spells at Lv1-10 up to 45 / 20 at Lv71-75). If the client exposes live
Blue Magic Points, those are used instead.

![BLUPrints build planner and trait
calculator](Screenshots/Screenshot%202026-09-16%20202526.png)

## Azure Loadout

**Azure Loadout** provides quick access to saved BLUPrints sets.

-   Reads saved Blue Magic builds from the addon's BLUPrints folder.
-   Refreshes the available loadout list on demand.
-   Loads and equips a saved spell set directly in game (asks to confirm
    first).
-   Keeps reusable spell configurations separate from the active
    build-planning workflow.

## Configuration

Azure Codex includes an in-game configuration window for the main UI and
supporting windows.

### Font & Colors

Pick a **Theme** (Midnight - default, Abyss, Twilight, Golden, Garnet, Silver), then customize
font scale, spell-state colors, header/accent color, paging color, and
window appearance.

![Font and color configuration](Screenshots/Screenshot%202026-09-16%20202615.png)

### Display

Configure compact/normal row spacing, automatic/fixed rows per page, and
visible spell-table columns including Level, Points, Learn Skill, Type,
Trait, and Mob Family.

![Display configuration](Screenshots/Screenshot%202026-09-16%20202628.png)

### Behavior

Configure remembered Search / Filter / Sort state, newly learned spell
highlighting, Click/Hover Learned From interaction, the **Target Tag**,
and settings reset.

## Farm Zones, Target Tag and Learned Log (1.12.0)

-   **Farm Zones** (`/ac farm` or the toolbar button): era zones ranked
    by how many spells you are missing there, learnable ones first.
    Click a zone to see the spells and the mobs that teach them.
-   **Target Tag**: while BLU is your main job, a small "Teaches:" tag
    appears when your target teaches a spell you are missing in the
    current zone (Learnable color = you can learn it now, Unlearnable color = skill too low).
    Drag it where you like; lock it in Behavior.
-   **Learned Log** (`/ac log`): every spell you learn from now on, with
    the date, zone and the mob you defeated, saved per character.

![Behavior configuration](Screenshots/Screenshot%202026-09-16%20202620.png)

## Commands

  -----------------------------------------------------------------------
  Command                             Description
  ----------------------------------- -----------------------------------
  `/azurecodex`                       Toggle the main Azure Codex window.

  `/ac`                               Short alias for `/azurecodex`.

  `/azurecodex config`                Toggle the configuration window.

  `/ac config`                        Short alias for the configuration
                                      window.

  `/ac farm`                          Toggle the Farm Zones window.

  `/ac log`                           Toggle the Learned Log window.

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
3.  Load the addon:

``` text
/addon load azurecodex
```

4.  Open Azure Codex:

``` text
/ac
```

## Compatibility

Azure Codex is designed for **Ashita v4** and **HorizonXI**. Spell,
trait, mob, and location information is HorizonXI-focused and should not
be treated as a modern retail FFXI database.

------------------------------------------------------------------------

## Credits

**Izumi (ShiroIzumi)** --- Original BLUSpells / Azure Codex development\
**Kyrias** --- Collaboration, BLUPrints, spell-set/build functionality,
and data development\
**Demiora** --- Testing

Azure Codex continues the original BLUSpells project under its new
collaborative name.

------------------------------------------------------------------------

## Changes in 1.12.1

-   Three more themes: Golden (XIUI-style), Garnet (SCL's subtle red), Silver.
-   Farm Zones and Learned Log keep their header (and close button) in place while the list scrolls.

## Changes in 1.12.0

-   Trait Calculator fixed (it never counted anything) and rebuilt on
    HorizonXI / LandSandBoat 75-era trait rules, in BLUPrints and
    BLUPrint-View. New Trait Planner and VS Equipped.
-   Point / slot limits now follow your BLU level (they were fixed at 50 /
    20); BLU Points shows equipped total / level limit when the client
    does not expose live points.
-   Clicking a filter while on BLUPrint-View returns to the spell list.
-   Azure Loadout asks before equipping.
-   Faster: the BLUPrints folder is no longer read from disk every frame,
    known spells / zone progress / the filtered list are cached, and the
    equipped-set memory pattern is scanned once.
-   New: Theme dropdown, Farm Zones, Target Tag, Learned Log.
-   Version number fixed (header and addon both 1.12.0).
