# MogSuite

**MogSuite** is an Ashita v4 addon for **HorizonXI** that puts your character, your bags and everything you can do into three clean, themed windows, with one settings window for all of them.

| Window | Key | What it shows |
|---|---|---|
| **Character** | `C` | Equipment, attributes, resistances, haste, jobs, skills, currencies and gear stats |
| **Inventory** | `B` | Every bag in tabs, key items, item values, a loot log and your other characters' bags |
| **Actions** | `P` | Abilities, weapon skills, magic, pets and blood pacts, with recast timers |

**Version:** 1.0.0
**Authors:** Izumi (ShiroIzumi) / Kyrias (.kyri)

---

## Installation

1. Copy the `MogSuite` folder into `C:\HorizonXI\HorizonXI\Game\addons\`.
2. In game: `/addon load mogsuite`
3. Press **C**, **B** or **P**, or type `/ms` for the settings.

To load it every time, add `/addon load mogsuite` to your Ashita startup script (`scripts\default.txt`).

## Commands

`/ms`, `/mog` and `/mogsuite` all work the same.

| Command | What it does |
|---|---|
| `/ms` | Open / close the settings window |
| `/ms char` | Open / close the Character window |
| `/ms inv` | Open / close the Inventory window |
| `/ms act` | Open / close the Actions window |
| `/ms reset` | Move every window back to its default place |
| `/ms help` | List the commands in chat |

The open keys do nothing while the chat box is open or you are typing in a text box. Change them in **Settings > Global > Keybinds**.

## Nothing is done for you

MogSuite never uses anything on its own. Items, abilities, weapon skills and spells are only used when you click them, the same as a macro would. It only shows information after the game has sent it to you.

---

## Character

- **Header:** your name, jobs and levels (and your base level when you are level synced), with HP / MP / TP bars.
- **Overview:** your equipped items as icons (hover for the item description), attributes with gear bonuses, ATK / DEF, resistances, gear and active haste, and every job's level.
- **Skills:** combat, magic and crafting skills in alphabetical order, each with a bar toward its cap for your jobs and level. Skill-ups gained this session show next to the skill.
- **Currencies:** conquest points, seals, crests, guild points, Imperial Standing and more. The ones you have come first, then the ones at zero, each alphabetical, with a search box. Open **Main Menu > Currencies** in game once to load them; MogSuite remembers them for that character. The game only sends this list when you open that menu, so open it again to refresh.
- **Gear Stats:** accuracy, attack, haste, Store TP, Fast Cast, Cure Potency and more, totaled from your equipped gear's descriptions. Pet, latent, set and enchantment lines are not counted as your own stats.

## Inventory

- **Bag tabs:** All, Inventory, Safe, Satchel, Safe 2, Wardrobes 1-8, Storage, Locker, Sack, Case, then **Characters** and **Key Items**. Bags you don't have are not shown. Tabs of the same kind share a color.
- **Views:** List (icon, name, quantity and E / Rare / Ex tags), Grid (icons with the quantity in the corner) and Categories (Favorites, New, Equipped, Weapons, Armor, Ammo, Usable, Crystals, Rare / Ex, Materials, in your order).
- **Pop-out windows:** **Shift+Click** any tab to open it in its own window, with its own size, view, sort and search. Shift+Click it again to close it.
- **Search, sort and filter:** sort by slot, name, type, quantity or newest; filter by Weapons, Armor, Usable, Crystals, Materials, Rare / Ex or Favorites.
- **Item values:** what an NPC vendor pays, per item and for a full stack, plus the item's Auction House category. A price list for every item is built in. When a shop appraises an item, MogSuite saves the exact price HorizonXI gave you and uses it from then on.
- **Favorites:** right-click > Add to favorites. They get a star, can sit at the top, and can't be dropped.
- **New items** are highlighted until you hover them or close the window. Zoning does not count as new.
- **Right-click menu:** Use, Equip (with the slot for rings and earrings), Drop (with a quantity slider; Rare / Ex items need a second click) and Favorite.
- **Key Items:** every key item you have, read from the game's own key item list. Temporary ones get a **TEMP** tag; right-click to change that.
- **Characters:** the last known bags of every character you have logged in with MogSuite, so you can find which mule has what.
- **Mog House storage:** Safe, Storage and Locker are saved when the game loads them and can be viewed anywhere (marked as a snapshot).
- **Loot log (Log button):** everything you gained this session, gil gained per hour and today, and the value of your loot.
- **Inventory full warning:** a banner at the top of the screen when an item comes in and you are almost full.

## Actions

- **Header:** your jobs and HP / MP / TP bars (the TP bar has a mark at 1000).
- **Tabs:** Abilities, Weapon Skills, Magic, and a pet tab for each pet job you are: **Summons** (SMN), **Wyvern** (DRG, main job only), **Automaton** (PUP) and **Beast** (BST).
- **Search and filters:** Ready now / Castable now, Learned, Not yet, and Missing scrolls on Magic.
- **Recast timers** on every row, and a **details pane** with the description, costs, cast and recast time, target and the macro line (Copy / Use / Pin).
- **Pinned actions:** right-click > Pin to the top. Click a pinned action to use it.
- **Abilities:** main job (two-hour first, then by level), pet commands and support job abilities, with badges (SP, JA, PET, ROLL, QD, MAN, MRT).
- **Weapon Skills:** for your main and ranged weapon, with your skill level, a CAPPED tag, and a bar to the next weapon skill.
- **Magic:** every spell your jobs can use, by school, split into Usable and Unusable, with element, MP cost and the scrolls you are still missing. Blue Magic shows the spells you have set. Ninjutsu shows your tool counts.
- **Pets:** your pet's HP / MP / TP while it is out, its commands, and for Summoner every blood pact (Rage / Ward) of the avatar that is out.
- **Using:** double-click a row, click a pinned action, or right-click for Use on me / a party member / a selected enemy.

---

## Settings (`/ms`)

One window with a tab for each part of the suite:

| Tab | Sections |
|---|---|
| **Character** | Window (lock, border, title bar, UI scale), Tabs (which skills to show, zero stats, zero currencies), Colors |
| **Inventory** | Window and layout, Items (quantity format, favorites, warnings, new items), Colors, Value (price list, learned prices), Categories (section order), Bags (hide tabs) |
| **Actions** | Window and layout, Colors, Lists (support abilities, relic / mythic weapon skills, spells, sorting) |
| **Global** | Appearance (theme, background, opacity), Text effect, Keybinds, Windows (lock all, reset all), About |

Themes: **Copper**, **Garnet**, **Silver** (default), **Amethyst**, **Emerald** and **Midnight**.

Settings are saved per character. Your characters' bags, learned vendor prices and key item marks are shared by all your characters, in `addons\MogSuite\data\`.

## Files

```
MogSuite/
  mogsuite.lua          entry point: settings, commands, keys, events
  core/                 theme, keys, module loader, the settings window
  modules/character/    the Character window
  modules/inventory/    the Inventory window
  modules/actions/      the Actions window
  data/                 shared data (bags, learned prices, key item marks, built-in price list)
```

Each module folder has an `init.lua` (how the suite talks to it), a `config.lua` (its settings tab) and a `defaults.lua` (its default settings). The files of one module share one module scope, so they can use each other's functions; modules are separate from each other.

## Credits

- Item sell prices and Auction House categories come from [LandSandBoat](https://github.com/LandSandBoat/server)'s `sql/item_basic.sql`. Put a newer `item_basic.sql` in the MogSuite folder and press **Reload price list** (Settings > Inventory > Value) to use it instead.
- Made for the HorizonXI community.

## Changelog

### 1.0.0
- First release: Character, Inventory and Actions in one suite, with one settings window, six themes, colored tabs and an open key for each window.
