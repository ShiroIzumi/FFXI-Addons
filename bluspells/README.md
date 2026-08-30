# BLUSpells

**Version:** 1.6.0  
**Platform:** Ashita v4 / HorizonXI  
**Author:** Izumi (ShiroIzumi)

BLUSpells is a Blue Mage spell-learning tracker built around the HorizonXI spell set. It compares the spell database against the current character's learned spells and displays the results in a searchable, sortable, filterable UI.

## Required files

BLUSpells requires:

```text
bluspells.lua
spells.lua
```

`spells.lua` contains the spell metadata used by the UI.

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
- provide complete multi-monster learning-source databases beyond what is stored in `spells.lua`.

## Compatibility

If the local Ashita build does not expose ImGui table functions, BLUSpells contains a fallback renderer. Table-specific functionality such as resizable columns may therefore depend on the Ashita build.
