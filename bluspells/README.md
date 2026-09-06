# BLUSpells

**Version:** 1.9.3  
**Platform:** Ashita v4 / HorizonXI  
**Author:** Izumi (ShiroIzumi)

BLUSpells is a Blue Mage spell-learning tracker built around the HorizonXI spell set. It compares the spell database against the current character's learned spells and displays the results in a searchable, sortable, filterable UI.

## Required files

BLUSpells requires:

```text
bluspells.lua
spells.lua
locations.lua
```

`spells.lua` contains the spell metadata used by the UI.

`locations.lua` contains the Horizon-era learning-location reference used by both Click and Hover location views.

## Features

- Learned spells shown in a configurable Known color.
- Missing spells shown in a configurable Unknown color.
- Learned count.
- Missing count.
- Completion percentage.
- Completion progress bar.
- Search across:
  - Spell name
  - Level
  - Type
  - Trait
  - Mob Family
- OR searching with `|`.
- Filters:
  - All
  - Known
  - Missing
  - Ready
- Clickable sortable headers.
- Ascending/descending sorting.
- Sort by:
  - Spell
  - Level
  - Type
  - Trait
  - Mob Family
- Selectable/highlightable rows.
- Newly learned spell detection.
- Optional auto-highlight of newly learned spells.
- Automatic page jump to a newly learned spell.
- Auto or fixed rows per page.
- Configurable row spacing.
- Configurable visible columns.
- Resizable table columns where supported by the Ashita ImGui build.
- Optional persistence of search/filter/sort.
- Persistent main and config window geometry.
- Configurable font scale.
- Configurable background color and opacity.
- Configurable Known, Unknown, Header, and paging colors.
- Lockable window.
- Optional title bar and border.
- Horizon-era **Learned From** reference for all 106 tracked spells.
- **Click mode** (default): click a spell name to open a dedicated **BLU Spell Locations** window.
- Click the currently open spell again to close the location window.
- Click a different spell to reuse the same location window for the newly selected spell.
- Shared location-window position and size are retained while switching between spells.
- Each zone in the Click view divides its monster list evenly into two columns.
- Optional **Hover mode** for high-resolution displays.
- Hover mode uses a large quick-view tooltip and flows long location lists into additional columns at approximately 50 rows per column.
- Learning-location data is filtered to HorizonXI's supported era: original Final Fantasy XI, Rise of the Zilart, Chains of Promathia, and Treasures of Aht Urhgan.

## Commands

| Command | Description |
|---|---|
| `/bluspells` | Toggle the main BLUSpells window. |
| `/bsp` | Short alias for `/bluspells`. |
| `/bluspells config` | Toggle the config window. |
| `/bsp config` | Short alias for the config window. |

## Filters

### All

Shows all spells in the database.

### Known

Shows only spells the current character has learned.

### Missing

Shows only spells the current character has not learned.

### Ready

Shows unknown spells whose listed level is less than or equal to the current BLU main-job level.

The Ready filter is only enabled when Ashita can safely determine that the current main job is Blue Mage and can read the current BLU level.

Ready does **not** guarantee that:

- the required monster is currently accessible,
- the spell is available in the current content progression,
- every server-specific prerequisite is met.

It is a level-readiness filter only.

## Search

Search is case-insensitive and checks all spell metadata fields.

Examples:

```text
refresh
goblin
magic attack bonus
piercing
```

Use `|` for OR searches:

```text
refresh|regen
goblin|orc
piercing|slashing
```

## Sorting

Click a column header to sort by that column.

Click the active header again to reverse the sort order.

The current sort direction is shown with an indicator.

## Newly learned spells

While the addon is open, BLUSpells keeps a snapshot of learned spell state.

When a previously unknown spell becomes learned and **Auto-highlight Newly Learned Spell** is enabled, BLUSpells:

1. Selects the spell.
2. Highlights it briefly.
3. Jumps to the page containing it.

## Configuration

### Window tab

- Lock Window Position / Size
- Show Title Bar
- Show Border
- Window Color
- Background Opacity
- Reset Window Position / Size

### Font & Colors tab

- Font Scale
- Known Spells color
- Unknown Spells color
- Header / Accent color
- Paging Buttons color
- Reset Appearance

### Display tab

- Compact / Normal row spacing
- Auto / Fixed rows per page
- Fixed row count
- Show/hide Level
- Show/hide Type
- Show/hide Trait
- Show/hide Mob Family

The Spell column is always visible.

### Behavior tab

- Remember Search / Filter / Sort
- Auto-highlight Newly Learned Spell
- **Learning Locations: Click / Hover**
  - **Click** is the default and opens the dedicated location window.
  - **Hover** shows the large quick-view tooltip and is intended primarily for higher-resolution displays.
- Reset All Settings

## Learned-spell detection

BLUSpells builds a resource cache matching the names in `spells.lua` to Ashita spell resource IDs. Learned state is then checked with Ashita's player spell data.

The Player and ResourceManager objects are checked before use.

## What it cannot do

BLUSpells does not:

- automatically download current HorizonXI data,
- automatically discover monster locations,
- provide zone coordinates or route guidance,
- guarantee a spell is learnable only because your level is high enough,
- automate combat or spell learning,
- target or claim monsters,
- build or equip Blue Magic spell sets,
- manage Blue Magic set points,
- provide MP cost/recast/descriptions unless those fields are explicitly added to the data/UI,
- guarantee that every monster/location entry is permanently accurate if HorizonXI changes its content or spawn data.

## Compatibility

If the local Ashita build does not expose ImGui table functions, BLUSpells contains a fallback renderer. Table-specific functionality such as resizable columns may therefore depend on the Ashita build.

## Learning Locations

BLUSpells includes a learning-location reference for the **106 spells tracked by the HorizonXI ledger**. The reference is stored separately in `locations.lua`.

The data is intentionally restricted to content from the eras currently represented by HorizonXI:

- Original Final Fantasy XI
- Rise of the Zilart
- Chains of Promathia
- Treasures of Aht Urhgan

Later retail content such as **[S] / Wings of the Goddess areas, Abyssea, Adoulin-era zones, Escha, Reisenjima**, and other post-ToAU locations is excluded so the addon does not present misleading learning locations.

### Click mode

**Click** is the default Learning Locations behavior.

Click a spell name to open the dedicated **BLU Spell Locations** window. The window shows:

- Spell name
- Mob Family
- Zone names
- Monsters available in each zone

Each zone's monster list is divided evenly between **two columns**. For example:

- 8 monsters -> 4 / 4
- 15 monsters -> 8 / 7
- 23 monsters -> 12 / 11

Clicking the same spell again closes the location window. Clicking another spell while the window is open switches the existing window to that spell.

The location window uses a shared ImGui window identity, so its position and resized dimensions remain consistent while switching between spells.

### Hover mode

Users with larger/high-resolution displays can select **Hover** under:

```text
Config -> Behavior -> Learning Locations
```

Hovering a spell name then displays the large **Learned From** quick-view tooltip.

For spells with very large source lists, the Hover view flows the list into additional columns at approximately **50 rows per column** instead of producing one extremely tall tooltip.

## Screenshots

### Main BLUSpells Window

![BLUSpells main window](screenshots/screenshot6.png)

### Learning Location Modes

**Hover mode**

![BLUSpells Learned From hover view](screenshots/screenshot8.png)

**Click mode and Learning Locations configuration**

![BLUSpells Click location window and configuration](screenshots/screenshot7.png)

## Version 1.9.x Changes

### 1.9.0

- Added the dedicated **BLU Spell Locations** window.
- Made **Click** the default Learning Locations behavior.
- Added **Click / Hover** selection under Config -> Behavior.
- Added two-column monster layouts per zone in Click mode.
- Retained the high-resolution Hover quick-view option.

### 1.9.1

- Clicking the currently selected spell again now closes the location window.
- Clicking a different spell switches the open window to the new spell.

### 1.9.2

- Location windows now share one window identity/position rather than remembering a separate position for every spell.

### 1.9.3

- Resized location-window dimensions are now retained when closing, reopening, or switching spells instead of reverting to the default size.

## Location Data Changes Since 1.8.0

- Added `locations.lua` as a BLUSpells-specific learning-location dataset.
- Matched location records only to the 106 spells tracked by BLUSpells.
- Added Horizon-specific spell handling where required.
- Removed later retail-era locations that are not appropriate for HorizonXI.
- Added multi-column handling to the Hover view.
- Increased Hover column length from 30 -> 40 -> **50 rows** based on high-resolution testing.

