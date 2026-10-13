# ScrollingCombatLog

**Version:** 1.3.2  
**Platform:** Ashita v4 / HorizonXI  
**Author:** Izumi (ShiroIzumi)

ScrollingCombatLog (SCL) is a self-focused scrolling combat text addon for Final Fantasy XI. It is designed to show **what you do** and **what happens to you** without becoming a full party/alliance damage parser.

It separates combat into configurable **Outgoing** and **Incoming** lanes and supports combat damage, abilities, spells, healing, statuses, progression/rewards, and several FFXI-specific combat mechanics.

## HorizonXI compliance: completed actions only

SCL never tells you that an action is *about* to happen. It only shows an
action after it has finished.

- Action packets that announce a start ("readies", "starts casting",
  "starts using", ranged "starts aiming" — categories 7, 8, 9 and 12) are
  thrown away before they are parsed. There is no setting that turns them on.
- The chat-text fallback reads reward lines only (EXP, gil, skill-ups, drops,
  wear-offs). It never reads or shows "readies" / "starts casting" lines.

Showing upcoming monster TP moves or spell casts would be an advantage that
HorizonXI does not allow, so this is a hard rule of the addon.

## Design philosophy

SCL intentionally focuses on the local player.

It is meant to answer questions such as:

- How much damage did I just deal?
- Was that hit a critical?
- What spell/ability did I use?
- What hit me and for how much?
- What status did I gain or lose?
- Did I create a skillchain or Magic Burst?
- How much EXP/gil/skill progression did I receive?

It is **not** intended to replace a full parser, chat log, buff tracker, or alliance statistics addon.

## Core features

### Outgoing combat

SCL can display:

- Melee damage
- Critical hits
- Ranged damage
- Weapon Skills
- Spells
- Magic Bursts
- Skillchains
- Job/other abilities
- Pet damage (melee and abilities of your own pet)
- Additional effects
- Counters, retaliation and spikes you deal
- Buff/self-buff actions
- Sneak Attack / Trick Attack tags when correlated with the next relevant attack
- Misses, when enabled
- Optional target names

### Incoming combat

SCL can display:

- Incoming melee/ranged damage, tagged [BLOCK] / [GUARD] / [CRIT] when applicable
- Counters and spikes that hit you
- Incoming abilities and monster TP moves
- Defensive outcomes: evade, parry, block, dodge, anticipate, and Utsusemi shadows absorbed
- Healing received
- MP recovery
- Drain/Aspir-style recovery
- Positive statuses
- Negative statuses
- Status removals
- KO / defeat messages
- Misses, when enabled
- Optional source names

### Rewards / progression

SCL can display:

- Experience Points
- Limit Points
- Capacity Points
- Exemplar-style point messages where supported
- Gil (your own only)
- Character level-up messages
- Skill-ups
- Item obtains/drops (your own only) detected by the text fallback

## Critical-hit behavior

Critical hits intentionally use the **same font size as normal melee damage**.

They are distinguished by:

- a leading `*`
- their own configurable color

Earlier builds experimented with critical-specific font scaling/pop effects, but changing FontManager font height during criticals caused noticeable hitching. That behavior was deliberately removed for smooth rendering.

## Self-only behavior

SCL does not attempt to show every party or alliance member's combat.

The normal rule is:

- show actions **performed by you**
- show actions **targeting you**
- optionally show actions performed by your owned pet when ownership can be determined safely

This keeps the display readable during parties and alliance content.

## Commands

| Command | Description |
|---|---|
| `/scl` | Toggle SCL on/off. |
| `/scl config` | Open/close the configuration windows. |
| `/scl test` | Display sample SCL events for visual testing. |
| `/scl lock` | Lock positions and hide draggable lane anchors. |
| `/scl unlock` | Unlock positions and immediately show draggable Incoming/Outgoing anchors. |
| `/scl pause` | Pause/resume combat capture. |
| `/scl clear` | Clear currently active scrolling text. |
| `/scl session` | Open/close the Session summary window (`/scl session reset` clears it). |
| `/scl debug` | Log unmapped action messages to `logs\debug_YYYY-MM-DD.log`. |
| `/scl help` | Display command help. |

`/scl move` is intentionally **not** used. Unlocking positions is what shows the draggable anchors.

## Configuration windows

Opening:

```text
/scl config
```

displays two windows.

### Main Config

Tabs:

#### General

Controls display/content behavior such as:

- Theme (Garnet / Copper / Amethyst)
- Display Time
- Scroll Speed
- Global Font scale
- Maximum Visible Events
- Event Symbols / Prefixes
- Show Outgoing Target Names
- Show Incoming Source Names
- Show 0 Damage / No-Damage Results
- Show Misses
- Combine Rapid Repeated Hits
- Lock Positions

#### Font Style

Controls:

- Performance renderer / Custom Font renderer
- Font Family
- Bold
- Italic
- Outline
- Normal Damage scale
- Abilities / WS scale
- Healing scale
- Rewards scale

The Custom Font renderer uses Ashita FontManager functionality and supports installed Windows font families.

#### Outgoing

Contains Show/Hide and color controls for outgoing categories plus outgoing lane layout/orientation.

#### Incoming

Contains Show/Hide and color controls for incoming categories and includes the **Rewards** section.

### Preview & Tools

The second config window contains:

- Live Preview
- Test Display
- Clear Active Text
- Reset Outgoing Position
- Reset Incoming Position
- Reset All Settings
- Command reference

Both config windows persist their own:

- X position
- Y position
- Width
- Height

## Positioning

SCL has two independent combat anchors:

- Outgoing
- Incoming

Use:

```text
/scl unlock
```

to show both draggable anchor windows.

Move them where you want, then use:

```text
/scl lock
```

to hide the anchors and keep the positions.

Positions persist through addon reloads.

## Renderer modes

### Performance

Draws all combat text directly on ImGui's background draw list (no per-event
windows). This is the smoothest/lowest-overhead option.

Custom font family/style options do not apply to this renderer.

### Custom Font

Uses Ashita's font system and supports:

- Font Family
- Bold
- Italic
- Outline

The addon intentionally avoids drop-shadow rendering because it previously added unnecessary rendering cost.

## Symbols / prefixes

Depending on enabled categories, SCL uses compact prefixes such as:

```text
*       Critical
[R]     Ranged
[WS]    Weapon Skill
[SP]    Spell
[SC]    Skillchain
[JA]    Ability
[PET]   Pet
[+]     Buff / additional effect
[COUNTER]
[MP]
[DRAIN]
[!]     Incoming ability / negative status
[DEF]   Defensive result
[SHADOW] Utsusemi shadow absorbed a hit
[-]     Status removed
[KO]
[XP]
[LEVEL]
[SKILL]
[DROP]   Item found in the treasure pool
[OBTAIN] Item you received
$
```

Symbols can be disabled globally from Config.

## Repeated-hit combining

When enabled, rapid hits from the same relevant source/target/category can be merged into a single line such as:

```text
140 (4 hits)
```

This is intended to reduce screen spam during multi-hit situations.

The combine window is intentionally short so unrelated attacks are not merged together.

## Skillchains

SCL reads the skillchain from the closing weapon skill's additional-effect message and displays the skillchain name and damage.

Examples include:

```text
[SC] Fusion 486
[SC] Light 812
```

## Magic Bursts

Certain spell-result message families are recognized as Magic Bursts.

A burst keeps the spell presentation and adds an MB marker, for example:

```text
[SP] Thunder II 843 -> Goblin [MB]
```

## Status effects

SCL can display incoming positive/negative status actions and status removal events.

Status removal names are resolved through Ashita's buff string resources where possible. If a server/client resource truly cannot resolve the ID, SCL falls back to:

```text
Status #<id>
```

## Skill-ups

Skill-ups primarily use incoming action-message packet data when available.

Supported output includes forms such as:

```text
[SKILL] Blue Magic +0.3
[SKILL] Blue Magic -> 99
```

A text fallback exists for server/chat paths that do not expose the expected packet form.

## EXP handling

The EXP packet (0x02D) is the authoritative source. Chat text and a
memory-based EXP watcher are fallbacks: they only display a gain when no
packet reported one, so each reward appears once. A level-down from death is
never shown as a gain.

## Gil

Gil rewards are detected from the supported action-message packet families and displayed as a personal reward.

## Search/parser scope and limitations

SCL uses a mixture of:

- FFXI action packets
- action-message packets
- Ashita memory values
- limited text fallback parsing

Because HorizonXI and retail can differ in message IDs/text, some unusual server-specific actions may require additional mapping.

## What SCL cannot do

SCL intentionally does **not** provide:

- full party DPS
- alliance DPS
- threat/enmity meters
- damage rankings
- encounter-history dashboards
- full combat-log replacement
- full buff-bar replacement
- monster encyclopedia/database
- gear tracking
- automatic combat actions
- automated targeting
- automated spell/ability execution

It also cannot guarantee every private-server custom action/message will classify perfectly without a corresponding packet/message mapping.

## Pet support

Your pet is identified through your player entity's pet index, the same way
other Ashita v4 addons do it. Only your own pet's actions are shown.

## Resist indicator limitation

SCL can identify some full resist/no-effect result families and display:

```text
[RESIST]
```

It intentionally does **not** invent fractional resist values such as `1/2`, `1/4`, or `1/8` when the packet does not provide enough information to determine them reliably.

## Configuration persistence

SCL uses Ashita's `settings` library to persist:

- event visibility
- event colors
- renderer mode
- font options
- font/category scales
- lane positions
- lane orientation/growth
- source/target display options
- miss/zero-damage options
- repeated-hit combining
- max-visible event count
- main config geometry
- Preview & Tools geometry

## Ashita v4 safety

The addon is written for current Ashita v4 behavior and follows several defensive rules:

- Player memory manager is checked before use.
- Entity manager is checked before use.
- Optional API methods are probed safely where needed.
- Action data is checked before dereferencing nested fields.
- No `ImGuiCond_*` values are used.
- Current ImGui geometry reads use numeric `x, y` and `w, h` return values.
- Resource lookup failures use safe fallbacks instead of crashing.

## Installation

Place the addon folder under:

```text
Ashita/
└─ addons/
   └─ scrollingcombatlog/
      ├─ scrollingcombatlog.lua   Ashita events and /scl commands
      ├─ README.md
      └─ scl/
         ├─ core.lua              settings, shared state, text helpers
         ├─ session.lua           session summary numbers
         ├─ debuglog.lua          /scl debug logger
         ├─ events.lua            event creation, colors, symbols, lanes
         ├─ resources.lua         entity / spell / ability / item / status names
         ├─ packets.lua           combat (0x028) packets
         ├─ rewards.lua           rewards, zone, chat fallback, EXP watch
         ├─ render.lua            lane drawing
         ├─ theme.lua             config theme and widgets
         └─ ui.lua                config, tools, session window, move handles
```

Then load it:

```text
/addon load scrollingcombatlog
```

Open configuration:

```text
/scl config
```

## Recommended first-time setup

1. Load SCL.
2. Run `/scl config`.
3. Choose Performance or Custom Font.
4. Adjust event colors/visibility.
5. Run `/scl unlock`.
6. Position Incoming and Outgoing anchors.
7. Run `/scl lock`.
8. Run `/scl test`.
9. Enter combat and confirm the categories you care about are visible.

## Troubleshooting

### Config windows do not appear where expected

SCL persists config geometry. If monitor layout or resolution changes substantially, reset settings/window geometry and reposition the windows.

### Status shows `Status #<id>`

The client/resource table could not resolve that status ID. If it is a normal known FFXI status, report the ID and context so the resource mapping can be checked.

### A HorizonXI action is classified incorrectly

Capture:

- the exact FancyChat/game chat line,
- the action name,
- whether it was outgoing or incoming,
- and, if possible, a screenshot.

Server-specific message IDs can then be mapped without redesigning the addon.

### Custom Font stutters

Criticals should not change font size in current builds. If hitching appears, compare against the Performance renderer and report the specific event category that triggers it.

## Notifications lane

A third, static lane in the center of the screen for the moments that matter.
Each can be switched on/off under **Display -> Notifications**:

- Level up
- Skillchains
- Magic Bursts
- Zone change
- Buff wearing off (the game's own "about to wear off" message)
- Big hits: a copy of any outgoing damage at or above the Big Hit Threshold

Move it with `/scl unlock` (the "Notifications (center)" handle marks the
center of the text).

## Session summary

`/scl session` (or **Session Summary** in Preview & Tools) shows your own
numbers since load or the last reset: EXP / Limit / Capacity per hour, gil per
hour, kills (you or your party), current-fight damage and DPS, total damage,
biggest hit, biggest weapon skill, biggest magic (any spell: WHM, BLM, BLU,
NIN, ...), biggest hit by your own pet, and items obtained. A Text Size slider
at the bottom scales the window's text.

Items obtained appear in a small panel attached to the Session window, so the
Session window keeps its size. The panel sizes itself to the list and adds a
column once a column is as tall as the Session window. It is hidden until you
obtain something. **Items Panel** (bottom of the Session window) picks Right
side (default), Left side, Below, or Inside window (the old in-window list).

## Debug log

`/scl debug` writes any action or message ID involving you that SCL does not
classify to `addons\scrollingcombatlog\logs\debug_YYYY-MM-DD.log` (each one
once per session, with a one-line notice in chat). Send that file to map
HorizonXI-specific messages.

## Display options

**Display** tab:

- Motion per lane: Scroll, Arc (curves sideways), Fade In (appears and drifts).
- Critical Pop: crits briefly grow then settle (Performance renderer).
- Element Colors: spells and additional effects use their element's color.
- Combine AoE Hits: one line such as `Firaga III  1840 (4 targets)`.

## Changes in 1.3.2

- The combined tick line is colored per part: the Regen part in the Regen Ticks color, the Refresh part in the Refresh Ticks color (Performance renderer; Custom Font shows the line in one color).
- Cast Regen / Refresh and Auto Regen / Auto Refresh at the same time: once SCL has seen your AUTO amount (a tick without the effect on you), it splits it off. The cast part shows on its own line, the AUTO parts on the next:
  `[REGEN] +23 HP`
  `[AUTO REGEN] +1 HP / [AUTO REFRESH] +1 MP`

## Changes in 1.3.1

- Regen and Refresh ticks that land together show on **one line**: `[REGEN] +24 HP / [REFRESH] +1 MP`.
- Ticks from a Regen / Refresh **effect on you** (a spell or ability) show as `[REGEN]` / `[REFRESH]`; ticks with no such effect (BLU Auto Regen / Auto Refresh, gear, food) show as `[AUTO REGEN]` / `[AUTO REFRESH]`. If both are active at once the game sends one combined amount, so it is labeled by the effect.

## Changes in 1.3.0 - More combat results

All of these are shown only after they happen.

**Outgoing**
- **Enfeebles that land:** `Paralyze -> Mob  [LANDED]` (with the status name when it differs from the spell).
- **Resists:** spells already showed `[RESIST]`; job abilities that get resisted do now too. Partial resists (1/2, 1/4) aren't shown, because the server doesn't send them.
- **Steal / Mug / Despoil:** `Steal  Beehive Chip -> Mob`, `Mug  320 gil -> Mob`, or `FAILED`.
- **Your cast interrupted:** `INTERRUPTED  Cure IV`. This is read from your own cast's interruption only. "Starts casting" is still never shown.
- **Phantom Roll / Double-Up:** `Corsair's Roll  5  [LUCKY]`, `[UNLUCKY]`, `[11!]` or `BUST`, as one line instead of one per party member.
- **Charm (BST):** `Charmed -> Mob` or `Charm FAILED -> Mob`.

**Incoming**
- **Your resists:** `RESIST  Paralyze <- Mob`, shown as a defense.
- **Stoneskin:** a hit that does 0 damage while Stoneskin is up shows `STONESKIN absorbed <- Mob`. Phalanx's reduction can't be seen, because the server sends only the final damage.
- **Low HP warning:** `LOW HP 23%` when your HP drops to the set percent (Incoming tab, default 25%). It goes to the center Notifications lane by default. It warns once, then again only after your HP climbs back above the limit + 10%.
- **Raise offered:** `RAISE OFFERED  Raise II <- Name`.

## Changes in 1.2.7 - Font Style options

- **Text Effect:** None, Outline, Thick Outline, Drop Shadow, Soft Shadow, Outline + Shadow, Glow. **Effect Color** (Black / Charcoal / Tinted / White), **Effect Strength**, **Shadow Distance** (1-6 px).
- **Backing Plate:** Off / Subtle / Dark / Tinted soft box behind each line, with opacity and rounding.
- **Text Opacity**, **ALL CAPS**, Bold now also works in Performance mode (faux bold).
- **Font Family** dropdown with 22 Windows fonts (Custom Font).
- **Custom Font hitching fixed:** font objects are now built once per style and reused; before, an object was re-rasterized whenever it switched between event sizes, which caused a stutter each time text appeared.
- Performance mode effects are only extra draw calls (no textures / font objects), so they do not cost frame time.
- Glow and the Backing Plate are Performance-only. Custom Font shadow uses a second font copy behind the text.

## Changes in 1.2.6

- `[REGEN]` / `[REFRESH]` ticks now show at all times, not only while resting, whenever they restore 1 or more (nothing shows when HP / MP is full). Turn them off with Incoming -> Regen Ticks / Refresh Ticks.

## Changes in 1.2.5

- Regen / Refresh (spells, gear, BLU Auto-Regen / Auto-Refresh) are split out of resting: `[REGEN] +1 HP` / `[REFRESH] +1 MP`, and `[REST]` only shows the real 10-second rest tick. The regen amount is learned from its 3-second beat, so the first few seconds after a regen effect starts may still count toward `[REST]`.
- Incoming -> **Regen Ticks** / **Refresh Ticks** toggles and colors, (1.2.6: they now always show).

## Changes in 1.2.4

- Resting (/heal): each tick shows in Incoming as `[REST] +20 HP / +15 MP / -100 TP` (TP only when TP was lost). Toggle / color: Incoming -> Resting (/heal) Ticks.

## Changes in 1.2.3

- Items Obtained moved to an attached panel beside the Session window (Right / Left / Below / Inside window).

## Changes in 1.2.2

- EXP gains show your progress: `+189 EXP (3,628/14,000)`.
- Session window: Biggest hit taken (melee, ranged, spells, TP moves, spikes / counters), Biggest heal done, Biggest heal taken.

## Changes in 1.2.1

- Session window: Biggest Magic, Biggest Pet Hit (your own pet), Text Size slider.

## Changes in 1.2.0

- Code split into `scl\*.lua` modules; `scrollingcombatlog.lua` is now the entry point only.
- Notifications lane, Session summary window, `/scl debug` logger.
- Lane motion styles, Critical Pop, Element Colors, Combine AoE Hits.
- Buff "about to wear off" warning (new Incoming option, also routable to Notifications).
- Fixed: when more events arrived than Maximum Visible Events, the newest rows were dropped instead of the oldest.

## Changes in 1.1.4

- Enemy spikes / counter / retaliation damage now shows in the Incoming lane (e.g. `-8  <-  Zircon Quadav [SPIKES]`). The action-packet spikes block was being read 4 bits short.

## Changes in 1.1.3

- `[OBTAIN]` now shows alongside `[DROP]` (the duplicate filter was treating them as the same event).
- Zone banner in the Incoming lane after zoning: `=== Area: Lower Jeuno ===` (toggle + color: Incoming -> Zone Change).
- Preview & Tools window grows to fit the live preview text.

## Changes in 1.1.2

- Config theme dropdown under General -> Display & Behavior: **Garnet** (default), **Copper**, **Amethyst**. Saved per character.
- Softer accent colors; headers and the selected tab use a lighter tint of the accent for readability.

## Changes in 1.1.1

- Zoning no longer shows your whole current EXP as a gain (EXP memory watch re-baselines after zoning).
- `[DROP]` = item found in the treasure pool, `[OBTAIN]` = item you actually received (own color / toggle).
- Stray `.1` after item names removed (FFXI inline 0x7F marker stripped).
- Custom Font live preview is visible again (the Tools window leaves the preview area unpainted).

## Changes in 1.1.0

- Hard block on start-of-action packets (readies / starts casting / starts using / aiming); dead text code that produced READY / CAST lines removed.
- Two identical hits in a row are both shown (packet events are no longer debounced).
- Utsusemi shadow absorbs show as `[SHADOW] 1 absorbed` instead of 1 damage.
- Blocked / guarded hits keep their damage number, tagged `[BLOCK]` / `[GUARD]`.
- Skillchains detected by message ID; no duplicate "additional effect" line.
- Pet damage works (pet found through the player entity's pet index).
- Counters, retaliation and spikes are shown in both directions.
- Heals on others show the amount (`Cure  120 -> Name`); your own heals on yourself show once.
- Status-inflicting TP moves / abilities no longer show the status ID as damage.
- EXP shown once per reward (packet first, text / memory fallback); no fake gain on level-down.
- Gil, drops, EXP text and status wear-off text are self-only.
- No more doubled signs (`- -24`, `+ +93 HP`).
- Sneak Attack / Trick Attack tag is spent by a miss.
- Faster entity-name lookups (direct index for monsters, party lookup for players, cached).
- Performance renderer draws on the background draw list instead of one window per event.
- Config windows restyled: black base, red accent, flat tabs, toggle buttons.
- Unused files removed from the release (`helpers.lua`, `configuration.lua`, `simplify.lua`, `lib/`, `config/`, old notes).
