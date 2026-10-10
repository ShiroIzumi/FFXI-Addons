# Azure Codex

**Azure Codex** (formerly *BLUSpells*) is an Ashita v4 addon for **Blue Mage players on HorizonXI**. It brings spell tracking, learning locations, build planning, trait calculation and saved spell sets together in one in-game window.

All spell, trait, mob and zone data is tailored to **HorizonXI's level-75 era**. It is not a retail FFXI database.

**Version:** 1.13.3  
**Authors:** Izumi (ShiroIzumi) · Kyrias  
**Testing:** Demiora

![Azure Codex main window](Screenshots/main.png)

---

## Contents

- [Features at a Glance](#features-at-a-glance)
- [Installation](#installation)
- [Commands](#commands)
- [Spell List](#spell-list)
- [Learning Locations](#learning-locations)
- [Zone Info](#zone-info)
- [Farm Zones](#farm-zones)
- [BLUPrints – Build Planner](#bluprints--build-planner)
- [Trait Calculator & Trait Planner](#trait-calculator--trait-planner)
- [BLUPrint-View & Azure Loadout](#bluprint-view--azure-loadout)
- [Target Tag](#target-tag)
- [Learned Log](#learned-log)
- [Themes & Configuration](#themes--configuration)
- [HorizonXI Rules Used](#horizonxi-rules-used)
- [Compatibility](#compatibility)
- [Credits](#credits)
- [Changelog](#changelog)

---

## Features at a Glance

| | |
|---|---|
| **Spell tracking** | All 106 HorizonXI Blue Magic spells, colored as Known, Learnable or Unlearnable based on your live Blue Magic skill. |
| **Search & filters** | Search every column at once; use `\|` to match any of several terms. Quick filters: All, Known, Missing, Up to my level. |
| **Learning locations** | Every zone and mob that teaches each spell, for HorizonXI-era zones only. |
| **Zone Info** | The spells you can learn in your current zone, and from which mobs. |
| **Farm Zones** | Zones ranked by how many spells you are still missing there. |
| **BLUPrints** | Plan a spell set within your real point and slot limits, then save it or equip it in game. |
| **Trait Calculator** | Trait tiers for a build, following HorizonXI's 75-era rules. |
| **Trait Planner** | The cheapest spells you know that reach each trait's next tier. |
| **Target Tag** | Shows "Teaches: …" when your target teaches a spell you are missing. |
| **Learned Log** | A per-character history of every spell you learn: when, where, and from which mob. |
| **Themes** | Midnight, Abyss, Twilight, Golden, Garnet and Silver, all fully customizable. |

---

## Installation

1. Copy the `azurecodex` folder into your HorizonXI addons folder:
   ```
   C:\HorizonXI\HorizonXI\Game\addons\azurecodex\
   ```
2. Start HorizonXI through Ashita.
3. Load the addon:
   ```
   /addon load azurecodex
   ```
4. Open Azure Codex:
   ```
   /ac
   ```

The folder contains `azurecodex.lua`, `spells.lua`, `locations.lua`, a `BLUPrints` folder (saved builds) and `Screenshots`.

---

## Commands

| Command | Description |
|---|---|
| `/ac` · `/azurecodex` | Open or close the main window |
| `/ac config` | Open or close the Config window |
| `/acz` · `/azurecodexzone` | Open or close Zone Info |
| `/ac farm` | Open or close Farm Zones |
| `/ac log` | Open or close the Learned Log |
| `/bluspells` · `/bsp` · `/bsl` | Legacy aliases for the main window |
| `/bluspellszone` · `/bsz` | Legacy aliases for Zone Info |

---

## Spell List

The main window has a **sidebar** on the left and the spell list on the right.

- **Sidebar:** your Blue Magic skill, set points (and spells set), overall learned progress and the current zone's progress, each with a progress bar. Below them: **Spells**, **BLUPrints** and **BLUPrint-View**, then **Zone Info**, **Farm Zones**, **Learned Log**, and **Config** at the bottom.
- **Main area:** the search box, the filters and the current page. Below the list: Prev / Next paging, how many spells match, and the color legend.

The spell list shows every Blue Magic spell with its **Level, Points, Learn (skill needed), Type, Trait and Mob Family**.

- **Colors:** Known, Learnable (your current Blue Magic skill is high enough) and Unlearnable.
- **Sort:** click any column header; click again to reverse the order.
- **Search:** checks every column. Use `|` for OR searches, e.g. `refresh|regen|goblin` (hover the box for a reminder).
- **Filters:** **All**, **Known**, **Missing**, **Up to Lv N** (missing spells at or below your BLU level).
- **New spells:** a newly learned spell is selected and highlighted for a few seconds.

**Learn** is the minimum Blue Magic skill needed to learn the spell. On HorizonXI that is the A+ skill cap at the spell's level, minus 31.

---

## Learning Locations

Click a spell name to open its **Spell Locations** window. It lists every HorizonXI-era zone and mob that teaches the spell, with the spell's mob family in the header. Only the list scrolls, so the header and close button stay in place. On high-resolution screens you can switch to a hover tooltip instead (Config → Behavior).

![Spell Locations window](Screenshots/mobinfo.png)

---

## Zone Info

**Zone Info** (`/acz` or **Zone Info** in the sidebar) shows every spell you can learn in your current zone. Each entry shows the required Blue Magic skill, the spell level, your status (Known / Learnable / Unlearnable) and the mobs that teach it. Tick **Hide Known** to see only what is left. Only the list scrolls, so the header, Hide Known and the close button stay in place.

Zone Info and Spell Locations can be dragged from any empty spot, with or without the title bar. If a window won't move, check its lock in Config → Window.

![Zone Info window](Screenshots/zoneinfo.png)

---

## Farm Zones

**Farm Zones** (`/ac farm` or **Farm Zones** in the sidebar) ranks HorizonXI-era zones by how many spells you are still missing there. Zones with spells you can learn right now are listed first.

- Click a zone to expand it and see each missing spell with the mobs that teach it.
- **Learnable only** hides spells your Blue Magic skill can't learn yet.
- Your current zone is marked *(here)*.

![Farm Zones window](Screenshots/zonestofarm.png)

---

## BLUPrints – Build Planner

Click **BLUPrints** in the sidebar to plan a spell set. A **Spell Card** opens beside the main window and shows the build slot by slot, with its points and traits.

- Only spells you have learned can be selected.
- Limits follow your level: points and spell slots come from the live game value when available, otherwise from the HorizonXI level table (see [HorizonXI Rules Used](#horizonxi-rules-used)).
- **Equip This Build** sets the spells in game.
- **Select Currently Equipped** loads your current set into the planner.
- **Save Current Build** writes the set to the `BLUPrints` folder.
- **VS Equipped** shows which spells a build would add or remove compared with your current set.

![BLUPrints build planner with Spell Card and Trait Calculator](Screenshots/traits.png)

---

## Trait Calculator & Trait Planner

The **Trait Calculator** (below the Spell Card) shows each trait in the build with its current tier, its points toward the next tier, and a progress bar. Hover **(?)** for a summary of the rules.

The **Trait Planner** lists the cheapest spells you know that would reach each trait's next tier. When those spells fit your limits, an **Add** button selects them for you. Tick **All traits** to plan traits that aren't in the build yet.

Spells that count extra toward their trait show the multiplier, e.g. *Auto Refresh x2*.

---

## BLUPrint-View & Azure Loadout

- **BLUPrint-View** (sidebar) opens a saved BLUPrint and shows its spells, points, traits and its difference from your current set. From there you can **Equip** it, **Import** it into BLUPrints, or **Delete** it (asks first).
- **Azure Loadout** (top of BLUPrints) is a quick dropdown of your saved sets. Choosing one asks for confirmation, then equips it.

---

## Target Tag

While Blue Mage is your main job, a small **"Teaches:"** tag appears when your current target teaches a spell you are still missing in this zone. The spell name uses your Learnable or Unlearnable color.

- Drag the tag anywhere you like.
- Lock it, or turn it off, in Config → Behavior.
- It only reads your target and the addon's own location data.

---

## Learned Log

The **Learned Log** (`/ac log` or **Learned Log** in the sidebar) records every spell you learn from now on: the date and time, the zone, and the mob you defeated. It is saved separately for each character and can be cleared from the window.

---

## Themes & Configuration

Open **Config** from the bottom of the sidebar or with `/ac config`.

| Tab | Options |
|---|---|
| **Window** | Lock each window, title bar, border, window color and opacity, reset position |
| **Font & Colors** | **Theme**, font scale, and colors for Known / Learnable / Unlearnable, Header / Accent and the paging buttons |
| **Display** | Compact or normal rows, automatic or fixed rows per page, visible columns |
| **Behavior** | Remember search / filter / sort, highlight new spells, click or hover for locations, **Assimilation merits**, **Target Tag**, reset all settings |
| **About** | Version and credits |

**Themes:** Midnight (default) · Abyss · Twilight · Golden · Garnet · Silver. Picking a theme sets the window surfaces, the window color and the accent color. You can still adjust any of them afterwards. In Garnet, trait names on the Spell Card and Trait Planner are sand-colored and unreached traits are amber, so they stand apart from the red accent.

![Theme selection in Config](Screenshots/theme.png)

Search boxes are skipped by the Tab key, so pressing Tab in game to target never jumps into Azure Codex. Click a box to type in it.

---

## HorizonXI Rules Used

**Blue Magic set limits by level** (the live game value is used when the client provides it):

| Level | Blue Magic Points | Spells |
|---|---|---|
| 1–10 | 10 | 6 |
| 11–20 | 15 | 8 |
| 21–30 | 20 | 10 |
| 31–40 | 25 | 12 |
| 41–50 | 30 | 14 |
| 51–60 | 35 | 16 |
| 61–70 | 40 | 18 |
| 71–75 | 45 (+ Assimilation merits) | 20 |

**Traits** (HorizonXI / LandSandBoat 75-era rules):

- Each set spell gives **4 trait points** to its trait. The in-game description shows this as e.g. "Job Trait: Auto Refresh (4)".
- Most traits gain a tier every **8 points**.
- **Auto Refresh** needs **32 points**. **Resist Gravity** tiers are 8 / 12 / 16.
- Spells that count extra: Self-Destruct, Frightful Roar, Light of Penance **x2** · Voracious Trunk **x3** · Actinic Burst, Plasma Charge, Winds of Promyvion **x4**.
- Each trait has its own maximum tier.

---

## Compatibility

- **Ashita v4** on **HorizonXI**.
- Equipping uses Ashita's `blusets` helper when it is installed, and a built-in fallback otherwise.
- Data is HorizonXI-specific (level-75 era) and is not meant for retail FFXI.

---

## Credits

- **Izumi (ShiroIzumi)**: original BLUSpells / Azure Codex development
- **Kyrias**: collaboration, BLUPrints, spell-set / build functionality, data development
- **Demiora**: testing

Azure Codex continues the original BLUSpells project under its new collaborative name.

---

## Changelog

### 1.13.3
- Zone Info and Spell Locations: only the list scrolls now (like Farm Zones), so the header and close button stay in place.
- Their lists no longer use ImGui tables (measured columns instead), the same as the windows that already drag fine.

### 1.13.2
- Zone Info and Spell Locations can be dragged from any empty spot, with or without the title bar.
- Spell Locations header: spell name and mob family on the left, close button on the right (no overlap).
- Spell list columns: Lvl, Points and Learn (was "Learn Skill") are narrow fixed columns; Spell, Type, Trait and Mob Family share the rest equally.
- Garnet theme: trait names on the Spell Card / Trait Planner use a sand color and unreached traits / over-limit picks use amber, so they no longer blend into the red accent. Other themes are unchanged.

### 1.13.1
- Fixed: 1.13.0 failed to load on newer Ashita builds (error in BeginChild).

### 1.13.0
- New main-window layout: a sidebar with progress bars (Blue Magic skill, set points and spells, learned, current zone) and the navigation (Spells, BLUPrints, BLUPrint-View, Zone Info, Farm Zones, Learned Log, Config). The search box, filters and spell list fill the right side.
- The whole main window follows the font scale, not just the table.
- Pager and color legend tidied up; the close button (title bar hidden) sits at the end of the search row.

### 1.12.3
- Zone Info can be dragged by its header, even with the title bar hidden.
- Zone Info header no longer overlaps: name, zone ID and progress on the left, Hide Known and the close button on the right, at any font scale.
- Zone Info level / status columns size to the font scale.

### 1.12.2
- Pressing Tab in game no longer focuses the Azure Codex search box.

### 1.12.1
- New themes: Golden, Garnet and Silver.
- Farm Zones and the Learned Log keep their header and close button in place while the list scrolls.

### 1.12.0
- **Trait Calculator fixed** (it never counted anything) and rebuilt on HorizonXI 75-era rules, in both BLUPrints and BLUPrint-View.
- **Point and slot limits follow your level** (they were fixed at 50 / 20), with an Assimilation merit setting. Builds over the limit are kept but can't be equipped.
- BLU Points shows your equipped total against the level limit when the client doesn't report live points.
- Clicking a filter while on BLUPrint-View returns to the spell list.
- Azure Loadout asks before equipping.
- Performance: the BLUPrints folder is no longer read every frame, the spell list and zone progress are cached, and the equipped-set memory lookup runs once.
- New: Trait Planner, VS Equipped, Farm Zones, Target Tag, Learned Log, Theme dropdown.
- Version number fixed.

### 1.11 and earlier
- Restyled to a flat look with tabs and accent underlines; default midnight blue background (`#010022`).
- BLUPrints, Azure Loadout, Zone Info, spell locations, filters, search and config windows.
