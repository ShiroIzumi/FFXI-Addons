# ScrollingCombatLog

**Version:** 1.0.5  
**Platform:** Ashita v4 / HorizonXI  
**Author:** Izumi (ShiroIzumi)

ScrollingCombatLog (SCL) is a self-focused scrolling combat text addon for Final Fantasy XI. It is designed to show **what you do** and **what happens to you** without becoming a full party/alliance damage parser.

It separates combat into configurable **Outgoing** and **Incoming** lanes and supports combat damage, abilities, spells, healing, statuses, progression/rewards, and several FFXI-specific combat mechanics.

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
- Pet damage where the local Ashita build exposes safe pet ownership data
- Additional effects
- Counter / retaliation-style events
- Buff/self-buff actions
- Sneak Attack / Trick Attack tags when correlated with the next relevant attack
- Misses, when enabled
- Optional target names

### Incoming combat

SCL can display:

- Incoming melee/ranged damage
- Incoming abilities and monster TP moves
- Defensive outcomes such as evade/parry/block-style results
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
- Gil
- Character level-up messages
- Skill-ups
- Item obtains/drops detected by the supported text fallback

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

Uses ImGui rendering and is intended to be the smoothest/lowest-overhead option.

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
[-]     Status removed
[KO]
[XP]
[LEVEL]
[SKILL]
[DROP]
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

SCL can detect skillchain added effects from action packet data and display the skillchain name and damage when available.

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

HorizonXI EXP chat/packet behavior can differ from retail, so SCL also maintains a memory-based EXP progression path using the player's current/needed EXP values.

This allows reliable detection of normal EXP increases and level rollover without depending entirely on chat text.

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

## Pet support limitation

Pet damage is displayed only when the current Ashita v4 environment exposes a safe method that allows the addon to determine the local player's pet server ID.

If that API is unavailable, pet ownership detection is skipped rather than using unsafe assumptions.

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
      ├─ scrollingcombatlog.lua
      └─ <any companion Lua files included with the release>
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
