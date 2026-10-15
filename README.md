# LMCC mods

Assetto Corsa mods (Custom Shaders Patch, Lua) for the LMCC championship drivers. Each mod is a folder under `apps/lua/`.

## Flags

Makes race flags impossible to miss.

It uses the flags and penalties the game already raises, so it works on any server without a plugin.

### What drivers get

- **Flag panel**: big HUD panel with the flag drawn in its colours and pattern, its name, what to do, and where the cause is. It opens by itself on every new flag, even if it was closed:
  - yellow family: `Incident 250 m ahead, Turn 1, J. Doe`
  - blue: every car about to lap you, closest first, with race position and gap: `Let 2 cars pass: P1 A. Fast 80 m, P3 B. Quick 240 m`
  - a second active signal (for example a penalty during a blue flag) is shown on an extra line.
- **Screen-edge strips**: solid strips in the flag colour along the top and bottom of the screen with the flag name scrolling across, in the style of the CMRT HUD flag banner. They slide in when a flag appears or changes, slide out when it clears and pulse for urgent flags, so the flag is seen without looking at the panel. Always on: drivers cannot turn them off.
- **Penalties shared between drivers**: every Flags client tells the others when one of its penalties starts (gas cut with its seconds, drive through, pit penalty, slow down, black flag) and when it is served. Only gas cuts are shown: **GAS CUT AHEAD** warns when a car close ahead (300 m by default) must lift off, with its position, gap and seconds left (`P5 Seygow 120 m, lift 4s`). It ranks below every game flag. Works on the original AC server (messages travel as hidden chat); every driver needs this version.
- **Sound cues**: a short sound when the flag changes. Four cues: caution (yellow, code 60, slippery, slow vehicle, ambulance), blue, severe (black, red, penalties), info (green, white, checkered, pit closed).
- **Flag history**: every flag of the session with lap, session time, duration and location.
- **Setup window**, in tabs:
  - Alerts: test any alert for 6 seconds (panel, strips and sound, with sample location text), never written to the history. Buttons in the flag colours, grouped as race flags, penalties and server script flags. "Game data" shows the raw values the game reports.
  - Panel: reopen the panel window, lock it, and snap it to a screen position on a 3x3 grid.
  - Display: pulse urgent flags, show or hide the green flag (shown 5 seconds, since the game keeps it raised all session), strip height, blue flag search range (100 to 1000 m behind you), gas cut ahead range (100 to 1000 m ahead).
  - Sound: sound on or off, master volume, volume per cue with a test button (hover a cue name to see its alerts).
  - Network: checks that Flags clients can message each other on the server (needed to share alerts between drivers). "Send test ping" reaches every driver running the same version; each one answers and is listed with its round trip time. Also shows whether the server relays messages directly (custom server) or as hidden chat (original AC server). Alone on the server, the time your own ping takes to come back, compared with your ping, tells whether it went through the server or stayed a local copy.

Flags shown: green, yellow, blue, white, checkered, black, penalties: drive through (jump start, laps left to serve it), pit penalty (laps left to go through the pits), gas cut (track cut: lift off for the seconds left, read from the AC shared memory since it depends on the track, or drop below 35 km/h; reported by the game as its penalty flag), black flag. The game also defines red, code 60, slippery, slow vehicle, ambulance, mechanical, warning, pit closed and black flag withdrawn; those only appear if a server script raises them, and the app displays them correctly when it does.

#### How the blue flag list works

A car is listed when it is behind you on track within the search range and ahead of you in the race order, which means it is about to lap you. Cars in the pit lane, disconnected cars and hidden cars are ignored. When no car matches, the panel falls back to the single car the game reports.

### Install

Requires Custom Shaders Patch.

For drivers: drag `Flags-<version>.zip` into Content Manager, or extract it into the Assetto Corsa folder (it holds `apps/lua/Flags`).

To build that zip from the committed tree (refuses uncommitted app changes; prints the server checksum):

```bash
scripts/build.sh                      # version from manifest.ini -> dist/Flags-<version>.zip
scripts/build.sh 1.2.3                # sets VERSION in the zipped manifest only
```

Releases: push a version tag and GitHub Actions (Linux) runs the tests on LuaJIT, builds the zip with the tag as version, and publishes a GitHub release with the zip, the server checksum and the changelog (feat, fix and perf commits since the previous tag):

```bash
git tag v1.2.3
git push origin v1.2.3
```

For development, link the folder instead of copying it:

```powershell
./install.ps1                         # junction into D:\SteamLibrary\...\assettocorsa\apps\lua
./install.ps1 -AcRoot "E:\Games\assettocorsa"
./install.ps1 -Uninstall              # removes the link only
```

In game, open from the app bar:

- **Flags**: the panel. Drag it to move it; drag the grip in its bottom-right corner (shown while the mouse is over it) to resize it, which scales everything. Right click locks it in place (a padlock animation, the same as the CMRT HUD, shows the change); right click again to unlock. The settings icon opens the setup.
- **Flags Setup**: tests and preferences.
- **Flags History**: the flag log.

The strips and sound work even when no window is open.

### Shared data for other mods

Flags sends its data with CSP online events (`ac.OnlineEvent`), so any other Lua app on the same server can read it. An event only matches when the key and the whole layout are identical: copy the layouts below exactly, field names and types included.

#### Penalties

Key `volchan.lmccFlags.penalties`. Each client sends one message when one of its own penalties starts and one when it is served. Nothing is sent periodically, so a client that joins later does not learn about penalties already running.

```lua
local penaltyEvent = ac.OnlineEvent({
  ac.StructItem.key('volchan.lmccFlags.penalties'),
  code = ac.StructItem.byte(),
  active = ac.StructItem.byte(),
  parameter = ac.StructItem.int32(),
}, function(sender, message)
  -- sender: ac.StateCar of the car the penalty belongs to (sender.index is its local car index),
  -- nil when the server sent it. Index 0 is a copy of your own message: skip it.
  if not sender or sender.index == 0 then return end
  ac.log(ac.getDriverName(sender.index), message.code, message.active, message.parameter)
end)
```

| Field | Type | Meaning |
|---|---|---|
| `code` | byte | Which penalty, see below. Ignore codes you do not know: new ones may be added at the end. |
| `active` | byte | `1` the penalty started, `0` it was served. |
| `parameter` | int32 | When started: the value below, `0` when unknown. When served: always `0`. |

| Code | Penalty | `parameter` when started |
|---|---|---|
| 1 | Gas cut (lift off after cutting the track, clears below 35 km/h) | Seconds of lifting left, rounded up; `0` if the game did not report it |
| 2 | Drive-through (jump start), reported by the game as `ac.PenaltyType.TeleportToPits` | Raw game value: laps left to serve it plus one (3 means "2 laps remaining") |
| 3 | Pit penalty (`ac.PenaltyType.MandatoryPits`) | Raw game value, same convention as code 2 |
| 4 | Slow down (`ac.PenaltyType.SlowDown`) | Seconds |
| 5 | Black flag (flag or penalty) | `0` |

Notes for readers:

- "Served" is decided by the sending client: pit penalties once its car has been through the pit lane, the gas cut when the game lowers it, the slow down when its seconds reach 0.
- A "served" message can be lost (rate limit, disconnection). Flags drops a gas cut 3 seconds after its length ends, or 10 seconds after it started when the length is unknown; do something similar.
- Previews from the setup window are never sent.

#### Network test

Key `volchan.lmccFlags.netTest`, used by the setup Network tab. Other mods normally have no reason to send these, but a reader must not answer them.

```lua
ac.OnlineEvent({
  ac.StructItem.key('volchan.lmccFlags.netTest'),
  kind = ac.StructItem.byte(), -- 1 ping (to everybody), 2 pong (answer)
  id = ac.StructItem.uint16(), -- ping number, echoed by its pongs
  replyTo = ac.StructItem.int32(), -- pong: sessionID of the pinging car; ping: -1
}, callback)
```

#### Server limits

On the original AC server, CSP carries these messages as hidden chat: one message per 200 ms at most and 175 bytes each (`ac.getSim().directMessagingAvailable` is `true` on custom servers without those limits). Flags queues its messages to respect the rate; a mod sending on the same server shares that budget, so send rarely.

### Layout

```
apps/lua/Flags/
  manifest.ini           windows and the fullscreen strips callback
  Flags.lua              entry: wiring only
  sounds/*.wav           sound cues (generated by scripts/gen_sounds.js)
  src/flags.lua          catalog: every flag and penalty, look, instruction, priority, sound
  src/signal.lua         flag + penalty -> signals, most urgent first
  src/penalty.lua        decides when a penalty is served
  src/flag_filter.lua    hides flags the game keeps raised (green, checkered, served penalty flag)
  src/context.lua        distance, sector and driver of the flag cause
  src/blue.lua           cars about to lap the player
  src/tracker.lua        debounce, change events, history
  src/preview.lua        timed test of any flag
  src/app.lua            per-frame flow, dependencies injected
  src/game.lua           the only module reading the sim
  src/sound.lua          plays cues
  src/settings.lua       preferences (ac.storage)
  src/layout.lua         screen position presets
  src/window_mover.lua   moves, opens and resizes the panel window
  src/lock.lua           panel lock state and padlock animation timeline
  src/panel_input.lua    right click lock, hover resize grip, move blocking
  src/pulse.lua          shared blink
  src/draw.lua           font, text, flag patterns
  src/theme.lua          colours
  src/panel_view.lua     panel
  src/lock_view.lua      padlock animation over the panel (ported from CMRT)
  src/net_probe.lua      ping and pong logic of the network test
  src/net.lua            network test over ac.OnlineEvent
  src/penalty_share.lua  own penalty start and served messages, board of other drivers' penalties
  src/share.lua          penalty sharing over ac.OnlineEvent
  src/gas_cut_ahead.lua  gas cuts of cars close ahead
  src/strip.lua          slide and scroll motion of the strips
  src/glow_view.lua      screen-edge strips
  src/history_view.lua   history window
  src/setup_view.lua     setup window
scripts/gen_sounds.js    regenerates the wav files
scripts/build.sh         builds the release zip and prints the server checksum
scripts/changelog.sh     release changelog from commits since the previous tag
.github/workflows/       release on version tags
tests/                   one *_test.lua per module, helper.lua and ui_stub.lua shared
```

### Development

- VS Code with the *Lua* extension (sumneko). `.luarc.json` points to the CSP SDK definitions in the AC install for autocomplete.
- Tests run with any Lua 5.1+ or LuaJIT interpreter, from the repo root:
  ```
  lua tests/<name>_test.lua
  ```
- Regenerate sounds after changing a cue: `node scripts/gen_sounds.js`.
- Debug in game with CSP's **Lua Debug** app (`ac.log`, `ac.debug`).

### Known limits

- Flags come from the game only. Championship-specific signals (full course yellow, safety car) need a server script that raises the matching game flag.
- The blue flag list uses race order, so in practice and qualifying (ordered by best lap) it can list cars that are simply faster.
- Very long location lines are clipped to the panel width; widen the panel if needed.
- The game can keep reporting a penalty after it is served, so the app clears it itself: pit penalties (DRIVE THROUGH, PIT PENALTY) once the car has been in the pit lane and left it, SLOW DOWN when its seconds reach 0. A black flag only clears when the game removes it.
- The game also keeps some flags raised long after they matter, so the app hides them: green after 5 seconds, checkered once you cross the line or enter the pit lane (shown at least 5 seconds), the gas cut flag when it is raised with a penalty not yet served (the game raises it with every penalty; the penalty has the exact instruction). A gas cut after a served penalty shows normally. Yellow, blue, white and black are lowered by the game itself.
