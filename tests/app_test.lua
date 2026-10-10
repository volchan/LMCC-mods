local t = require('tests/helper')
t.stubCsp()
local flags = require('src/flags')
local settings = require('src/settings')
local tracker = require('src/tracker')
local preview = require('src/preview')
local app = require('src/app')
local F, P = flags.FLAG, flags.PENALTY

-- Fake game driven by `state`; counts cause lookups.
local state = { now = 0, flagType = F.None, flagCause = -1, penaltyType = P.None, penaltyParameter = 0, lap = 2, sessionTime = 60,
  trackLength = 4000 }
local carList = {}
local causeLookups = 0
local readsNil = false
local game = {
  read = function(out)
    if readsNil then return nil end
    for k, v in pairs(state) do out[k] = v end
    return out
  end,
  cause = function(index, out)
    causeLookups = causeLookups + 1
    if index < 0 then return nil end
    out.mySpline, out.causeSpline, out.trackLength, out.causeName, out.causeSector = 0.1, 0.15, 4000, 'J. Doe', nil
    return out
  end,
  cars = function(out)
    for i = #out, 1, -1 do out[i] = nil end
    for i, c in ipairs(carList) do out[i] = c end
    return out
  end,
}
local played = {}
local sound = { play = function(cue, volume) played[#played + 1] = { cue = cue, volume = volume } end }

local s = {}
for k, v in pairs(settings.DEFAULTS) do s[k] = v end
s.volume = 0.5

local a = app.new({ game = game, sound = sound, settings = s, tracker = tracker.new({ hold = 0 }), preview = preview.new() })

-- Clear track.
a:update()
t.check('no signal on clear track', #a:signals() == 0 and a:displayDetail() == nil and #played == 0)

-- Yellow with a located cause.
state.now, state.flagType, state.flagCause = 1, F.Caution, 3
a:update()
t.check('yellow displayed', a:signals()[1].flag.id == 'yellow')
t.check('detail describes the incident', a:displayDetail() == 'Incident 200 m ahead, J. Doe')
t.check('caution cue played at master volume', #played == 1 and played[1].cue == 'caution' and played[1].volume == 0.5)
t.check('history stamped with lap and detail', a.deps.tracker:active().lap == 2
  and a.deps.tracker:active().detail == 'Incident 200 m ahead, J. Doe')

-- Same inputs: signals reused, detail throttled.
local list = a:signals()
local lookups = causeLookups
state.now = 1.1
a:update()
t.check('signals not rebuilt when unchanged', a:signals() == list)
t.check('detail throttled', causeLookups == lookups)
state.now = 1.1 + app.DETAIL_INTERVAL
a:update()
t.check('detail refreshed after interval', causeLookups == lookups + 1)
t.check('no repeated cue', #played == 1)

-- Flags without cause have no detail and no lookup.
lookups = causeLookups
state.now, state.flagType = 2, F.OneLapLeft
a:update()
t.check('white flag has no detail', a:displayDetail() == nil and causeLookups == lookups)

-- Green hidden when the setting is off.
state.now, state.flagType = 3, F.Start
s.showGreen = false
a:update()
t.check('green hidden', #a:signals() == 0)
s.showGreen = true
state.now = 3.1
a:update()
t.check('green shown again when enabled', a:signals()[1].flag.id == 'green')

-- Sound off: no cue.
local count = #played
s.sound = false
state.now, state.flagType = 4, F.FasterCar
a:update()
t.check('no cue when sound off', #played == count)
s.sound = true

-- Blue flag without lapping cars falls back to the car reported by the game.
t.check('blue falls back to flag cause', a:displayDetail() == 'Faster car 3.8 km behind, J. Doe')

-- Blue flag lists the cars about to lap the player.
carList = {
  { index = 0, name = 'Me', spline = 0.50, racePosition = 6, running = true },
  { index = 1, name = 'A. Fast', spline = 0.48, racePosition = 1, running = true },
}
state.now = 4 + app.DETAIL_INTERVAL
a:update()
t.check('blue lists lapping cars', a:displayDetail() == 'Let 1 car pass: P1 A. Fast 80 m')
s.blueRange = 50
state.now = 4 + 2 * app.DETAIL_INTERVAL
a:update()
t.check('blue range setting respected', a:displayDetail() == 'Faster car 3.8 km behind, J. Doe')
s.blueRange = settings.DEFAULTS.blueRange

-- Silent flags play nothing.
count = #played
a:playFlag({ sound = nil })
t.check('silent flag plays nothing', #played == count)

-- Preview overrides display and plays its cue, without touching history.
local historySize = #a.deps.tracker.history
local red = preview.options()[1]
a:startPreview(red)
t.check('preview displayed', a:signals()[1].flag.id == 'red' and a:displayDetail() == nil)
t.check('preview cue played', played[#played].cue == 'severe')
t.check('preview not in history', #a.deps.tracker.history == historySize)
a:stopPreview()
t.check('real signal back after stop', a:signals()[1].flag.id == 'blue')

-- Test sound uses the cue volume.
s.volume_info = 0.5
a:playCue('info')
t.check('test cue volume is master times cue', t.near(played[#played].volume, 0.25))

-- No game state: nothing changes.
readsNil = true
state.now = 99
a:update()
t.check('update ignored without game state', a.now ~= 99)

t.finish()
