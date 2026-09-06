# BLUSpells

**Version:** 1.9.12  
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
- Current Blue Magic skill display.
- Optional **Learn Skill** column showing the minimum skill reference for each spell.
- Current-zone progress showing **`# of # learned from this Zone`**.
- Dedicated **Zone Info** window for spells learnable in the current zone.
- Zone Info **Hide Known** filter for focusing only on missing spells.
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
- Persistent main, config, Zone Info, and Spell Location window geometry.
- Configurable font scale.
- Configurable background color and opacity.
- Configurable Known, Unknown, Header, and paging colors.
- Independent position/size locks for the main, Zone Info, and Spell Location windows.
- Shared optional title bar and border settings across the main, Zone Info, and Spell Location windows.
- Shared background color and opacity/transparency across those windows.
- When title bars are hidden, Zone Info and Spell Location retain an upper-right **X** close button.
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

- **Lock Window Position / Size** — main BLUSpells window
- **Lock Zone Info Position / Size**
- **Lock Spell Location Position / Size**
- Show Title Bar
- Show Border
- Window Color
- Background Opacity
- Reset Window Position / Size

**Show Title Bar**, **Show Border**, **Window Color**, and **Background Opacity** apply consistently to the main BLUSpells window, Zone Info, and Spell Location List.

When **Show Title Bar** is disabled, Zone Info and Spell Location List retain an **X** close button in the upper-right corner.

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
- Show/hide Learn Skill
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

## Blue Magic skill

When Blue Mage is the current main job and Ashita exposes the player combat-skill data, BLUSpells shows the character's current **BLU Skill** near the top of the main window.

The optional **Learn Skill** column provides the addon’s HorizonXI-oriented minimum learning-skill reference for each tracked spell.

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

The Spell Location List has its own independent position/size lock. It also follows the shared **Show Title Bar**, **Show Border**, **Window Color**, and **Background Opacity** settings. If the title bar is hidden, an **X** remains in the upper-right corner.

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

### Zone Info

The main BLUSpells window shows **Zone Info** directly after the **Missing #** count, above the learned-spell progress bar. It is followed by a live:

```text
# of # learned from this Zone
```

Click **Zone Info** to open a dedicated window for the current zone.

Zone Info:

- automatically follows the character's current zone,
- shows every tracked Blue Magic spell available from mobs in that zone,
- sorts spells alphabetically by spell name,
- displays **Spell | Lv | Status** on the spell header line,
- lists each mob that teaches the spell on its own line underneath,
- colors the spell/status according to **Known** or **Missing**,
- shows the current **# of # learned** total,
- includes **Hide Known** beside that total to show only missing spells,
- remembers its position and resized dimensions,
- has its own independent position/size lock.

Zone Info also follows the shared **Show Title Bar**, **Show Border**, **Window Color**, and **Background Opacity** settings. If the title bar is hidden, an **X** remains in the upper-right corner so the window can still be closed.

### Zone Info layout update (1.9.5)

- **Zone Info** now appears directly after the main **Missing #** count, above the progress bar.
- The current-zone text now reads **`# of # learned from this Zone`**.
- Zone Info is sorted alphabetically by spell name.
- Each entry now displays **Spell | Lv | Status** on one line, followed by the mobs that teach that spell beneath it.

### 1.9.6

Hotfix for the 1.9.5 Zone Info layout update. A duplicate `end` was left in `draw_zone_info_window`, causing Ashita to fail loading the addon with `<eof> expected near 'end'`. No feature behavior was changed.

### 1.9.7

Adjusted the main summary row so **Learned / Missing**, the **Zone Info** button, and **# of # learned from this Zone** are vertically aligned on the same visual baseline.

### 1.9.8

Fixed the remaining vertical misalignment on the main summary row. Both text sections now use ImGui's frame-padding alignment so **Learned / Missing**, **Zone Info**, and **# of # learned from this Zone** sit on the same baseline.

### 1.9.9

Added a **Hide Known** checkbox beside the **# of # learned** count in the Zone Info window. When enabled, learned spells are hidden and only missing spells for the current zone are shown.

### 1.9.10

Fixed **Lock Window Position / Size** so it now applies to all BLUSpells windows that should obey the lock:

- Main BLUSpells window
- Zone Info window
- Spell Location List window

When locked, Zone Info and Spell Location List can no longer be moved or resized. Unlocking restores normal movement and resizing.

### 1.9.11

The **Window** config tab now has three independent lock options, with the two new checkboxes placed directly under the original one:

- **Lock Window Position / Size** — main BLUSpells window
- **Lock Zone Info Position / Size**
- **Lock Spell Location Position / Size**

### 1.9.12

The shared appearance settings now apply consistently to the main BLUSpells window, Zone Info, and Spell Location List:

- **Show Title Bar**
- **Show Border**
- **Window Color**
- **Background Opacity / Transparency**

When **Show Title Bar** is disabled, Zone Info and Spell Location List each show an **X** close button in the upper-right corner.
