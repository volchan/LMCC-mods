# LMCC mods

Assetto Corsa mods (Custom Shaders Patch, Lua) for the LMCC championship drivers. Each mod is a folder under `apps/lua/`.

## LMCC Flags

Makes race flags impossible to miss. Folder `apps/lua/LMCC_Flags`.

It uses the flags and penalties the game already raises, so it works on any server without a plugin.

### What drivers get

- **Flag panel**: big HUD panel with the flag drawn in its colours and pattern, its name, what to do, and where the cause is. It opens by itself on every new flag, even if it was closed:
  - yellow family: `Incident 250 m ahead, Turn 1, J. Doe`
  - blue: every car about to lap you, closest first, with race position and gap: `Let 2 cars pass: P1 A. Fast 80 m, P3 B. Quick 240 m`
  - several signals at once are stacked by priority: the most urgent fills the panel, the next one is shown on an extra line with the count of the others (`+ DRIVE THROUGH: Drive through the pit lane, laps left: 2 (+1)`). A gas cut taken while a drive through is pending goes on top, since it must be done during the current lap.
- **Screen-edge strips**: solid strips in the flag colour along the top and bottom of the screen with the flag name scrolling across, in the style of the CMRT HUD flag banner. They slide in when a flag appears or changes, slide out when it clears and pulse for urgent flags, so the flag is seen without looking at the panel. Always on: drivers cannot turn them off.
- **Penalties shared between drivers**: every Flags client tells the others when one of its penalties starts (gas cut with its seconds, drive through, pit penalty, black flag) and when it is served. Only gas cuts are shown: **GAS CUT AHEAD** warns when a car close ahead (300 m by default) must lift off, with its position, gap and seconds left (`P5 Seygow 120 m, lift 4s`). A driver serving their own gas cut sees it on top, the alert right below and the cars ahead on the location line; once their gas cut is done the alert stays while cars ahead still serve one. It ranks above the driver's other penalties and below every other game flag that asks for action. Works on the original AC server (messages travel as hidden chat); every driver needs this version.
- **Sound cues**: a short sound when the flag changes. Four cues: caution (yellow, code 60, slippery, slow vehicle, ambulance), blue, severe (black, red, penalties), info (green, white, checkered, pit closed).
- **Flag history**: every flag of the session with lap, session time, duration and location.
- **Setup window**, in tabs:
  - Alerts: test any alert for 6 seconds (panel, strips and sound, with sample location text), never written to the history. Clicking more alerts during a test combines them as in a race (most urgent on top, the gas cut hiding the drive-through, the gas cut ahead right below the gas cut); Stop clears them. Buttons in the flag colours, grouped as race flags, penalties and server script flags. "Game data" shows the raw values the game reports.
  - Panel: reopen the panel window, lock it, and snap it to a screen position on a 3x3 grid.
  - Display: pulse urgent flags, show or hide the green flag (shown 5 seconds, since the game keeps it raised all session), strip height, blue flag search range (100 to 1000 m behind you), gas cut ahead range (100 to 1000 m ahead).
  - Sound: sound on or off, master volume, volume per cue with a test button (hover a cue name to see its alerts).
  - Network: checks that LMCC Flags clients can message each other on the server (needed to share alerts between drivers). "Send test ping" reaches every driver running the same version; each one answers and is listed with its round trip time. Also shows whether the server relays messages directly (custom server) or as hidden chat (original AC server). Alone on the server, the time your own ping takes to come back, compared with your ping, tells whether it went through the server or stayed a local copy.

Flags shown: green, yellow, blue, white, checkered, black, penalties: drive through (jump start, laps left to serve it), pit penalty (laps left to go through the pits), gas cut (track cut: lift off for the seconds left, read from the AC shared memory since it depends on the track, or drop below 35 km/h; reported by the game as its penalty flag), black flag. The game also defines red, code 60, slippery, slow vehicle, ambulance, mechanical, warning, pit closed and black flag withdrawn; those only appear if a server script raises them, and the app displays them correctly when it does.

#### How the blue flag list works

A car is listed when it is behind you on track within the search range and ahead of you in the race order, which means it is about to lap you. Cars in the pit lane, disconnected cars and hidden cars are ignored. When no car matches, the panel falls back to the single car the game reports.

### Install

Requires Custom Shaders Patch.

For drivers: drag `LMCC-mods-<release>.zip` into Content Manager, or extract it into the Assetto Corsa folder. It holds every mod (`apps/lua/LMCC_Flags`, ...): all of them are required.

#### Versions

- Each mod has its own version, `VERSION` in its `manifest.ini`, in SemVer: major when drivers or servers must change something together (online event keys, folder name, settings), minor for a feature, patch for a fix. It is written by hand and never changed by the build.
- A release has its own version, taken from the commit it is built from: `YYYY.MM.DD.<short hash>`, the commit date in UTC then its 7-character hash (`2026.10.15.29e530e`, tag `v2026.10.15.29e530e`). `scripts/version.sh [commit]` prints it.
- A mod whose files changed since the previous release must have a new `VERSION`, or the CI fails (`scripts/check_versions.sh`).

#### Build and release

```bash
task build                            # dist/LMCC-mods-<release>.zip from the committed mods, prints the server checksums
task release                          # tags the pushed main with its release version and pushes the tag
```

`task build` refuses uncommitted changes in `apps/lua`. `task release` refuses a dirty tree, a branch other than main, a HEAD not pushed, or a mod changed without a new version.

GitHub Actions runs the tests on LuaJIT, the mod version check and a build on every push and pull request (`ci.yml`). On a release tag (`release.yml`) it runs the same checks, verifies that the tag matches its commit, then publishes a GitHub release named `LMCC mods <release>` with the zip and the notes (`scripts/notes.sh`): a table of every mod with its version, whether it changed since the previous release, and the manifest MD5 servers need, then the changelog of each mod (breaking, feat, fix and perf commits touching its folder).

To install the mods from the repo, use the [Task](https://taskfile.dev) tasks (Windows, PowerShell 7). Each one acts on every mod of `apps/lua`, or on one with `MOD=<name>`; `AC_ROOT=<path>` targets another AC folder (default `D:\SteamLibrary\steamapps\common\assettocorsa`):

```powershell
task install:dev                      # dev copies, linked to the repo
task install:normal                   # committed files, as drivers get them
task uninstall:dev
task uninstall:normal
task install:dev MOD=Flags AC_ROOT="E:\Games\assettocorsa"
```

They call `install.ps1` (`-Mode dev|normal`, `-Uninstall`, `-Mod`, `-AcRoot`). Only folders made by the script are replaced or removed (it leaves a `.dev-install` or `.normal-install` file in them), so a mod installed from Content Manager is never touched. Both modes also remove links into the repo whose folder no longer exists (a renamed mod).

- **dev**: a copy named `<mod>_dev` (`apps/lua/LMCC_Flags_dev`) with ` (dev)` after every window name, so it sits next to a normal install of the same mod. Its subfolders (`src`, `sounds`) are junctions into the repo, so edits show up in game without copying. CSP loads `<folder>/<folder>.lua`, so the entry and `manifest.ini` are copies: install again after changing a manifest or a file at the root of a mod.
- **normal**: `apps/lua/<mod>` with the committed files of the mod, the same as the release zip. Uncommitted changes are left out, with a warning.

While the dev copy runs, the normal install stays silent (no panel, strips, sound, history or shared penalties; its setup says why) and takes over again about 2 seconds after the dev copy stops. Both still answer the network test ping.

In game, open from the app bar:

- **LMCC Flags**: the panel. Drag it to move it; drag the grip in its bottom-right corner (shown while the mouse is over it) to resize it, which scales everything; the size is kept between sessions. Right click locks it in place (a padlock animation, the same as the CMRT HUD, shows the change); right click again to unlock. The settings icon opens the setup.
- **LMCC Flags Setup**: tests and preferences.
- **LMCC Flags History**: the flag log.

The strips and sound work even when no window is open.

### Shared data for other mods

LMCC Flags sends its data with CSP online events (`ac.OnlineEvent`), so any other Lua app on the same server can read it. An event only matches when the key and the whole layout are identical: copy the layouts below exactly, field names and types included.

#### Penalties

Key `dazworks.flags.penalties`. Each client sends one message when one of its own penalties starts and one when it is served. Nothing is sent periodically, so a client that joins later does not learn about penalties already running.

```lua
local penaltyEvent = ac.OnlineEvent({
  ac.StructItem.key('dazworks.flags.penalties'),
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
| 4 | Retired, never sent (was the slow down penalty, never seen in game) | `0` |
| 5 | Black flag (flag or penalty) | `0` |
| 0 | Test, no penalty: sent by the **Send test penalty** button of the setup window (Network tab), never by a race. Skip it unless you are checking the chain | `0` |

Notes for readers:

- "Served" is decided by the sending client: pit penalties once its car has been through the pit lane, the gas cut when the game lowers it.
- A "served" message can be lost (rate limit, disconnection). LMCC Flags drops a gas cut 3 seconds after its length ends, or 10 seconds after it started when the length is unknown; do something similar.
- Previews from the setup window are never sent.
- LMCC Telemetry forwards every code to the stats site, the test one included; its own window has a **Send test penalty** button too, sent with `parameter` `1`, that only checks the trip from LMCC Telemetry to the site.

#### Flags

Key `dazworks.flags.flag`. Each client sends the race flag its game raises for it, every time the flag or the car that caused it changes. A clear track at the start is not sent; going back to a clear track is. Nothing is sent periodically either: a client that joins later learns a flag at its next change.

```lua
local flagEvent = ac.OnlineEvent({
  ac.StructItem.key('dazworks.flags.flag'),
  flag = ac.StructItem.byte(),
  cause = ac.StructItem.int32(),
}, function(sender, message)
  -- sender: ac.StateCar of the driver who sees the flag. Index 0 is your own game.
  if not sender then return end
  ac.log(ac.getDriverName(sender.index), message.flag, message.cause)
end)
```

| Field | Type | Meaning |
|---|---|---|
| `flag` | byte | The raw `ac.FlagType` (`0` none, `1` green, `2` yellow, `5` black, `8` gas cut, `12` blue, `13` checkered…), as the game raises it: not hidden like on the panel. |
| `cause` | int32 | Session ID (`ac.StateCar.sessionID`) of the car that caused it, `-1` when none. Car indexes differ from one game to the next, session IDs do not. |

Notes for readers:

- A yellow is local: every driver close to the incident sees it and sends it, each with the same cause.
- The game keeps green raised for the whole session and checkered until the session ends: decide yourself how long they matter.
- With the original AC server only the latest state is sent when the rate limit holds a change back: a short flag can be skipped.

#### Network test

Key `dazworks.flags.netTest`, used by the setup Network tab. Other mods normally have no reason to send these, but a reader must not answer them.

```lua
ac.OnlineEvent({
  ac.StructItem.key('dazworks.flags.netTest'),
  kind = ac.StructItem.byte(), -- 1 ping (to everybody), 2 pong (answer)
  id = ac.StructItem.uint16(), -- ping number, echoed by its pongs
  replyTo = ac.StructItem.int32(), -- pong: sessionID of the pinging car; ping: -1
}, callback)
```

#### Server limits

On the original AC server, CSP carries these messages as hidden chat: one message per 200 ms at most and 175 bytes each (`ac.getSim().directMessagingAvailable` is `true` on custom servers without those limits). LMCC Flags queues its messages to respect the rate; a mod sending on the same server shares that budget, so send rarely.

### Layout

```
apps/lua/LMCC_Flags/
  manifest.ini           windows and the fullscreen strips callback
  LMCC_Flags.lua         entry: loads src/main.lua
  src/main.lua           wiring only
  src/variant.lua        dev or release install, from the folder name
  src/presence.lua       dev install heartbeat, silences the release install
  sounds/*.wav           sound cues (generated by scripts/gen_sounds.js)
  src/flags.lua          catalog: every flag and penalty, look, instruction, priority, sound
  src/signal.lua         flag + penalty -> signals, most urgent first
  src/penalty.lua        decides when a penalty is served
  src/flag_filter.lua    hides flags the game keeps raised (green, checkered, served penalty flag)
  src/context.lua        distance, sector and driver of the flag cause
  src/blue.lua           cars about to lap the player
  src/tracker.lua        debounce, change events, history
  src/preview.lua        timed test of any flags, combined
  src/app.lua            per-frame flow, dependencies injected
  src/game.lua           the only module reading the sim
  src/sound.lua          plays cues
  src/settings.lua       preferences (ac.storage)
  src/layout.lua         screen position presets
  src/window_mover.lua   moves, opens and resizes the panel window
  src/lock.lua           panel lock state and padlock animation timeline
  src/panel_input.lua    right click lock, hover resize grip, move blocking
  src/panel_size.lua     panel size picked with the grip, saved and applied again
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
apps/lua/LMCC_Telemetry/
  manifest.ini           window, with its Status and Settings tabs
  icon.png               DazWorks logo, white, for the apps bar
  LMCC_Telemetry.lua     samples every car and sends the batches
  src/token.lua          the site's token, empty in git, filled in the release zip
scripts/gen_sounds.js    regenerates the wav files
scripts/lib.sh           helpers shared by the release scripts
scripts/version.sh       release version of a commit
scripts/check_versions.sh  fails when a changed mod kept its version
scripts/build.sh         builds the release zip and prints the server checksums
scripts/changelog.sh     changelog of one mod since the previous release
scripts/notes.sh         release notes: mod table and changelogs
scripts/test.sh          runs every test with LuaJIT
scripts/release.sh       tags and pushes a release
.github/workflows/       checks on every push, release on release tags
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
- The game can keep reporting a penalty after it is served, so the app clears it itself: pit penalties (DRIVE THROUGH, PIT PENALTY) once the car has been in the pit lane and left it. A black flag only clears when the game removes it.
- The game also keeps some flags raised long after they matter, so the app hides them: green after 5 seconds, checkered once you cross the line or enter the pit lane (shown at least 5 seconds), the gas cut flag when it is raised with a penalty not yet served (the game raises it with every penalty; the penalty has the exact instruction). A gas cut after a served penalty shows normally, and so does a gas cut taken before a penalty is served, while its lift seconds run. Yellow, blue, white and black are lowered by the game itself.

## LMCC Telemetry

Sends every car the game knows to the LMCC stats site (lmcc.seygow.fr), for the race direction: replays, contact clips and lap comparisons. Folder `apps/lua/LMCC_Telemetry`, ported from the site's own app (`telemetry-app/` of ac-championship-stats) with its address, token and server filter fixed for the league.

- **What is sent**, several times a second (20 by default, 5 to 30 in the window's settings): position, speed, gear, pedals, steering, rpm, lap and pit lane of every connected car (whether its driver runs the app or not), every penalty LMCC Flags announces (start and served, any driver), every flag a driver's LMCC Flags shares with its cause, the laps of your own car, and for your own car only its fuel, damage and tyres. **Never the chat**, neither the drivers' nor the server's.
- **Where**: only online, on a server whose name contains "DazWorks", never in a replay or solo session. The site refuses batches from any other server, and the app then stays silent until the game restarts.
- **Token**: never committed. `src/token.lua` is empty in git, so a dev or local install sends nothing; the release zip gets it from the `TELEMETRY_TOKEN` secret. It is not a secret (every install and release zip holds it): the site takes a batch only from a driver on the server, from the address that first spoke for them, at the app's pace.

Its window (LMCC Telemetry, optional) tells whether the batches get through.
