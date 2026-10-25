# FFXI-Addons

Ashita v4 addons for **Final Fantasy XI on HorizonXI**, written by Izumi (ShiroIzumi), with Kyrias (.kyri) co-developing MogSuite and AzureCodex.

> [!IMPORTANT]
> **These addons are written for HorizonXI only.**
> They are built around HorizonXI's level-75 era, its rules and its server data. They are not made for retail FFXI or any other private server. They may not work correctly anywhere else, and **I have no intention of troubleshooting or updating them for retail or other servers.**

> [!WARNING]
> HorizonXI only allows addons it has approved. Every addon below is marked with its approval status. **Using an addon that is not yet approved is at your own risk.** Check HorizonXI's current addon rules before you use one.

| Addon | What it is | HorizonXI status |
|---|---|---|
| [AzureCodex](azurecodex) | Blue Mage spell codex and build planner | ✅ **APPROVED ON HORIZONXI** |
| [MogSuite](MogSuite) | Character, inventory, actions, calendar and crafting windows in one addon | ⚠️ **NOT YET APPROVED ON HORIZONXI** |
| [MobHunt](MobHunt) | Kill, death and drop statistics for every mob you fight | ⚠️ **NOT YET APPROVED ON HORIZONXI** |
| [ScrollingCombatLog](scrollingcombatlog) | Scrolling combat text for your own actions | ⚠️ **NOT YET APPROVED ON HORIZONXI** |
| [IzClock](izclock) | A configurable Vana'diel clock with days, moon, guilds and ships | ⚠️ **NOT YET APPROVED ON HORIZONXI** |

---

## AzureCodex
✅ **APPROVED ON HORIZONXI** · `/ac` · [Full README](azurecodex/README.md)

AzureCodex (formerly BLUSpells) is an all-in-one window for Blue Mages:

- **Spell list:** all 106 HorizonXI Blue Magic spells, colored Known, Learnable or Unlearnable based on your live Blue Magic skill. Search and filter it.
- **Learning:** every zone and mob that teaches each spell. **Zone Info** shows what you can learn where you are, and **Farm Zones** ranks zones by how many spells you are still missing.
- **BLUPrints:** a build planner with a trait calculator that uses HorizonXI's own trait point values and tier caps, plus a trait planner and saved spell sets.
- **Target Tag:** shows whether the mob you're targeting teaches a spell, and whether you already know it.
- **Learned Log:** records when and where you learned each spell.

## MogSuite
⚠️ **NOT YET APPROVED ON HORIZONXI** · `/ms` · [Full README](MogSuite/README.md)

MogSuite is one addon with several themed windows. They share one searchable settings window.

- **Character (C):**
  - Equipment, attributes, resistances, haste, jobs, skills, currencies and gear stats.
  - Missions, conquest and fame progress.
  - A gear panel that shows charges and finds upgrades.
  - A death recap.
- **Inventory (B):**
  - Every bag in tabs, key items, and item values.
  - A loot log, and your other characters' bags.
  - A stacking helper that shows what to move where to free slots.
  - A watch list that warns you when an item runs low.
- **Actions (P):** your abilities, weapon skills, magic, pets and blood pacts, with recast timers and a skillchain helper.
- **Calendar (L):**
  - Vana'diel days and the moon on a calendar.
  - Conquest results, your own cooldown timers (Dynamis, Limbus, ENM ...) and events, with a login summary.
  - Airships, ferries and guild hours.
- **Crafting (J):**
  - Your crafting skills and recipes, and what you can make from your bags.
  - Your success and HQ odds, and what to craft next for skill-ups.
  - Your own synth ledger of NQ, HQ and break rates.
- **Requests:** a popup when someone invites you to a party or alliance or asks to trade. Nothing is accepted unless you click.

## MobHunt
⚠️ **NOT YET APPROVED ON HORIZONXI** · `/mhunt` · [Full README](MobHunt/README.md)

MobHunt keeps lifetime records for each mob, by zone and name, and shows them when you target that mob:

- Fights, kills, deaths, kill streaks, and average EXP and fight length.
- Session stats and kills per hour.
- Treasure-pool drops with observed drop rates.
- Which abilities and spells the mob uses, and how often they get interrupted. These are only shown once the mob is dead.
- A searchable History window and Mob Details.
- Full and Mini target views.

## ScrollingCombatLog
⚠️ **NOT YET APPROVED ON HORIZONXI** · `/scl` · [Full README](scrollingcombatlog/README.md)

ScrollingCombatLog (SCL) is scrolling combat text in the style of WoW's MikScrollingBattleText. It only shows **what you do** and **what happens to you**; it is not a party damage parser.

- **Outgoing and Incoming lanes:** damage, crits, abilities, spells, healing, Regen / Refresh ticks, buffs and debuffs, skill-ups and rewards, each in its own lanes and colors.
- **Notifications:** things like "X wore off" and food running out.
- **Layout:** centered on your character or free placement, with a live preview while you move it.
- **History:** a window with your recent events.
- **Look:** fonts, outlines, colors and per-lane growth direction are all configurable.

## IzClock
⚠️ **NOT YET APPROVED ON HORIZONXI** · `/ic` · [Full README](izclock/README.md)

IzClock is a small Vana'diel clock that you can configure completely:

- **On the clock:** the current and next elemental day, the countdown to the next day, the moon phase, your local time and Japan time. You choose which parts show and their order, labels and colors.
- **Hover:** the week, the moon, crafting, guild hours and ship times.
- **Click:** an info window with all of that in one place.
- **Optional:** a second clock and a day-change alert.

---

## Installation

1. Download this repository: **Code → Download ZIP**.
2. Copy the addon folder you want into `C:\HorizonXI\HorizonXI\Game\addons\`.
3. In game, type `/addon load <name>`, for example `/addon load mogsuite`.
4. To load it every time you start the game, add the same line to your Ashita startup script (`scripts\default.txt`).

Each addon's own README has its full command list, settings and changelog.

## Rules these addons follow

- **No automation:** nothing acts on its own. Every action happens only when you click or press a key.
- **No early warnings about enemies:** nothing warns you when a mob starts an ability or a spell. Enemy actions are only shown after they finish, as HorizonXI requires.
- **Your data stays on your PC:** everything the addons remember is saved on your own computer and is never sent anywhere.

## Support

Issues and suggestions are welcome **for HorizonXI only**. Reports from retail or other private servers will be closed.
