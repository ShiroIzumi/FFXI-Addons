# MobHunt

**Version:** 1.0.13  
**Platform:** Ashita v4 / HorizonXI  
**Author:** Izumi (ShiroIzumi)

MobHunt tracks monster hunting statistics by **Zone + Mob Name** and displays them when you target a monster.

## v1.0.1

- Fixed player / party / alliance members being treated as monsters.
- MobHunt now validates monster entities using the entity spawn flags before creating encounter records or showing target statistics.
- Added **Mini Target Window** mode.
- Full and Mini layouts keep their own saved positions and sizes.
- Added a **Mini** button to the Full window and a **Full** button to the Mini window.
- Added `/mh mini`.
- Added a Mini-mode toggle to Config -> Window.


## Version 1.0.2

- Added **Delete Record** to the selected History entry with a confirmation step.
- Fixed treasure attribution when `0x0D2` arrives after the killed mob has despawned or no longer reports monster spawn flags.
- Treasure now prefers the already-known encounter / recent-death record instead of re-validating the corpse as a live monster.
- Increased recent-death association window to 30 seconds (runtime cleanup at 35 seconds).
- Added diagnostics for **Treasure packets seen**, **Drops counted**, and **Drops ignored/unassociated**.
- `/mh debug` now prints the parsed treasure packet and whether it was recorded or could not be associated.
- Item id `65535` is labeled **Gil**.

## Features

- Tracks fights / encounters
- Tracks kills
- Tracks deaths to the mob
- Party/alliance kills count after you personally participated
- Stores lifetime records by Zone + Mob Name
- Current-session fights, kills, deaths, and kills/hour
- Tracks treasure-pool drops, occurrences, quantities, and observed drop percentages
- Searchable History window by mob, zone, or drop name
- Current and best kill streaks
- First seen / last kill / last death timestamps
- Full and Mini target layouts
- Persistent window positions and sizes
- Independent window locks
- Font scaling
- Background/opacity and color controls
- Optional title bars and borders
- `ImGuiWindowFlags_NoNav` so Tab does not navigate addon controls
- No `ImGuiCond_*` usage

## Tracking Rules

Targeting a monster does **not** count as a fight.

An encounter starts when you engage or act on a monster, or when that monster acts on you. If a party/alliance member kills that monster after you have participated, the kill is credited to the encounter.

Players, party members, alliance members, trusts, and normal NPCs are not valid MobHunt monster records.

## Mini Mode

Toggle Mini mode with:

```text
/mh mini
```

or use **Config -> Window -> Mini Target Window**.

Mini mode shows a compact target summary:

```text
Mob Name [In Combat]
Zone
F: 12   K: 10   D: 2   Win: 83.3%
Session  F: 4   K: 4   D: 0
```

Full and Mini modes remember separate position/size settings.

## Commands

| Command | Description |
|---|---|
| `/mobhunt` | Toggle target window |
| `/mh` | Short alias |
| `/mh mini` | Toggle Full / Mini target view |
| `/mh history` | Toggle searchable History |
| `/mh config` | Toggle Config |
| `/mh session` | Reset current-session statistics |
| `/mh debug` | Toggle debug/tracking messages |
| `/mh help` | Show commands |

## Version 1.0.4 Drop Tracking Fix

MobHunt now handles both FFXI loot delivery paths:

- `0x0D2` treasure-pool items (party/shared pool)
- direct-to-inventory item assignment / count changes (`0x01F` and `0x01E`)

The direct-inventory fallback is only active for a very short window after a MobHunt-recorded kill that did not produce a treasure-pool packet. This keeps ordinary inventory activity from being treated as monster loot and prevents pool items from being counted again when they are later awarded to inventory. Existing-stack quantity increases are also tracked.

Config -> Tracking diagnostics now show treasure packets, inventory packets, and direct-inventory drops separately.

## Installation

Copy the `MobHunt` folder to:

```text
Ashita\addons\MobHunt\
```

Then:

```text
/addon load MobHunt
```

If replacing v1.0.0, replace `mobhunt.lua` and reload the addon.

## Testing v1.0.1

1. Reload MobHunt.
2. Target a party member. The MobHunt target window should hide when Target Only is enabled; no fight record should be created.
3. Target and engage an actual monster. The target window should appear and the fight counter should increment once.
4. Participate in the fight and let a party member finish the monster. The kill should still count.
5. Use `/mh mini`, move/resize Mini mode, switch back to Full, and verify both layouts remember their own geometry.


## v1.0.3

- Added **Current Zone** and **All** scope buttons to the History window.
- **Current Zone** filters saved mob records to the zone the player is currently in.
- **All** restores the complete cross-zone history list.
- The selected scope is saved between sessions.


## 1.0.5

- Fixed a crash on inventory packet `0x01E` / `0x01F` where newly-added diagnostic counters were not initialized.
- Initialized `inventory_packets` and `direct_drops`.
- Hardened all runtime diagnostic counter increments against nil values so diagnostics cannot unload the addon.


## v1.0.6 Drop Tracking Fix

HorizonXI was observed sending `0x0D2` data whose field layout did not match the retail/Windower layout MobHunt had been parsing. In live debug output this produced impossible values such as an item id of `0`.

MobHunt 1.0.6 no longer trusts `0x0D2` to identify the item.

For treasure-pool loot it now reads Ashita's live treasure-pool memory using:

```lua
AshitaCore:GetMemoryManager():GetInventory():GetTreasurePoolItem(slot)
```

and watches the ten treasure-pool slots for newly appearing `ItemId` values.

Existing treasure already present when the addon loads is baselined and is not attributed to a new kill.

New pool items are associated with the most recent MobHunt-recorded kill within a short attribution window. The corresponding kill is marked as having generated treasure so a later inventory award does not get counted a second time.

`0x0D2` remains available as a debug signal but is no longer authoritative for item identity on HorizonXI.


## v1.0.7 Reload-Safe Encounters

Fixed an accounting issue where reloading MobHunt during an active fight caused the next combat packet to count the same fight a second time.

MobHunt now persists a lightweight active-encounter marker containing:

- mob server id
- mob name
- zone
- record key
- encounter start time
- last activity time

After an addon reload, if the same mob encounter is still active and the marker is fresh, MobHunt restores the runtime encounter instead of incrementing the lifetime `Fights` counter again.

Markers are removed when:

- the mob is killed,
- the encounter expires,
- the associated History record is deleted,
- or the player zones.

Session statistics still begin fresh when the addon reloads. A restored active encounter is represented once in the new runtime session so a kill immediately after reload does not produce an impossible session value such as `Fights: 0 / Kills: 1`.


## v1.0.8 Death and Drop-Rate Corrections

### Death Tracking

MobHunt now uses multiple guarded signals for player deaths:

1. Death action messages from packet `0x029`.
2. Death message IDs found directly inside parsed action packet `0x028`.
3. A local-player HP transition from `> 0` to `0` as a HorizonXI fallback.

The HP fallback attributes the KO to the most recent tracked hostile mob that acted on the player. If that is unavailable, it only falls back when exactly one MobHunt encounter is active, avoiding unsafe guesses when several monsters are involved.

Death events are deduplicated so the same KO cannot increment the counter through more than one detection path.

A player death now **ends the current encounter**. If the player is raised and re-engages, that is a new fight.

### Drop Rate Semantics

Drop percentages now mean:

```text
kills where the item appeared / total recorded kills
```

Multiple copies of the same item from one kill count as **one occurrence** for drop-rate purposes while still increasing the stored **quantity**.

Example:

- 1 Nitro Cluster kill
- 3 Fire Crystals from that kill

MobHunt stores:

```text
Fire Crystal
Occurrences: 1
Quantity: 3
Drop Rate: 100.0%
```

It will no longer display `300%` simply because three copies dropped from one kill.


## v1.0.9

Corrects the actual live source for two issues:

- Per-kill drop occurrences: multiple copies of the same item from one kill increase quantity, but only one drop occurrence.
- Player deaths: HP transition fallback plus most-recent-hostile attribution, death deduplication, and encounter closure while dead.

A KO clears active encounters and prevents new fights from starting until HP becomes positive again.


## v1.0.10 StatusTimers-Style Window Update

MobHunt's target window now follows the StatusTimers presentation more closely:

- stock background changed to translucent black at roughly 45% opacity
- rounded 7px window corners
- tighter compact item spacing
- existing custom backgrounds are preserved; only the original MobHunt stock background is migrated automatically

### Automatic Target-Window Growth

The Full and Mini target windows now use content-driven auto sizing.

The selected width is retained, while height is calculated every frame from the visible contents. Adding new observed-drop rows therefore grows the MobHunt window automatically. Targeting a mob with fewer rows shrinks it automatically.

Manual height resizing is no longer required.

### `/mh`

Bare:

```text
/mh
```

or:

```text
/mobhunt
```

now opens both the **History** and **Config** windows together.

Existing subcommands such as `/mh history`, `/mh config`, `/mh mini`, `/mh session`, and `/mh debug` remain available.


## v1.0.11 Drop Table Spacing

Adjusted the Observed Drops layout so longer item names have more room.

- `Item` is now the stretch/flexible column.
- `Drops` uses a fixed-width column.
- `Rate` uses a fixed-width column.
- The Full target window minimum width increased slightly.
- Automatic height growth/shrink behavior remains unchanged.


## v1.0.12 Stat Layout Cleanup

- Fights, Kills, and Deaths now use three evenly-spaced columns in both lifetime and session summaries.
- Removed Streak and Best from the visible MobHunt summary.
- Existing streak data remains stored for compatibility but is no longer displayed.


## v1.0.13 Opacity Slider

Added a dedicated **Opacity** slider under **Config -> Window -> Background / Opacity**.

- Range: 0% to 100%
- Updates the MobHunt window background live while dragging
- Saves with the existing appearance settings
- Continues to use the existing RGB background controls independently
