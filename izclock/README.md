# IzClock

**Version:** 2.8.0  
**Platform:** Ashita v4 / HorizonXI  
**Author:** Izumi (ShiroIzumi)

IzClock is a configurable Vana'diel clock for Final Fantasy XI. It calculates Vana'diel time locally from Unix time and can display the current elemental day, next-day countdown, upcoming day rotation, moon phase, and local computer time.

## Features

- Current Vana'diel time.
- Current elemental day.
- Element-specific day colors.
- Optional elemental text icons.
- Countdown until the next Vana'diel day.
- Next elemental day.
- Full upcoming seven-day elemental rotation.
- Moon phase.
- Moon illumination percentage.
- Optional local computer time.
- 12-hour or 24-hour local time.
- Optional local seconds.
- Full mode.
- Mini mode.
- Compact one-line mode.
- Left or right alignment.
- Adjustable font scale.
- Configurable background color.
- Configurable transparency.
- Optional title bar.
- Optional border.
- Lockable position/size.
- Persistent window geometry.

## Commands

| Command | Description |
|---|---|
| `/ic` | Toggle the IzClock display. |
| `/izclock` | Same as `/ic`. |
| `/icconfig` | Toggle the IzClock configuration window. |

## How Vana'diel time is calculated

IzClock does not depend on packet `0x5C`.

The clock uses the fixed relationship between Earth time and Vana'diel time:

```text
1 Vana'diel day  = 3456 Earth seconds
1 Vana'diel hour = 144 Earth seconds
```

The addon calculates:

```text
Unix time + Vana'diel epoch offset
```

and derives the current hour, minute, elemental day, and time remaining until the next day.

Because no time packet is required, the clock can display immediately after loading.

## Display modes

### Full

Shows:

- optional Local Time
- Vana'diel Time
- Current Day
- Next Day countdown
- optional Moon
- complete upcoming seven-day elemental rotation

### Mini

Shows the essential clock information plus the next day, but not the full seven-day rotation.

### Compact One-Line

Places the selected information on a single line.

Compact mode overrides the normal Full/Mini presentation.

## Moon phase

IzClock models the standard 84-Vana-day FFXI lunar cycle and displays:

- New Moon
- Waxing Crescent
- First Quarter Moon
- Waxing Gibbous
- Full Moon
- Waning Gibbous
- Last Quarter Moon
- Waning Crescent

It also displays the calculated illumination percentage.

## Local time

Local Time uses the computer's local operating-system time.

Options:

- Show Local Time
- 24hr Format
- Seconds

Windows handles the local timezone and daylight-saving adjustment used by `os.date()`.

## Elemental icons

The optional icons are simple text markers:

```text
[Fi] [Ea] [Wa] [Wi] [Ic] [Li] [Ls] [Da]
```

They do not require image files.

## Configuration options

The config window contains:

- Font Size
- Transparency
- Background Color
- Mini Mode
- Compact One-Line
- Lock Window
- Hide Title Bar
- Hide Border
- Show Moon Phase
- Elemental Icons
- Show Local Time
- 24hr Format
- Seconds
- Left / Right alignment

## Persistence

IzClock saves:

- display visibility,
- config visibility,
- font scale,
- transparency,
- background color,
- layout options,
- local-time options,
- moon/icon options,
- alignment,
- lock state,
- window position,
- window size.

## What it cannot do

IzClock does not:

- change Vana'diel time,
- alter server time,
- synchronize the server clock,
- provide elemental weather forecasts,
- predict weather,
- track crafting bonuses,
- guarantee compatibility with a private server that deliberately changes FFXI's standard time/moon rules,
- correct an inaccurate operating-system clock.

## Accuracy note

Because the clock is calculated from the computer's Unix time, a substantially incorrect system clock will also make the displayed Vana'diel time incorrect.

## Ashita v4 compatibility

IzClock avoids deprecated window-font scaling methods and does not use `ImGuiCond_*`. Current geometry capture uses the numeric x/y and width/height values returned by current Ashita v4 ImGui bindings.
