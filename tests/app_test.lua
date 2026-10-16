local t = require('tests/helper')
t.stubCsp()
local flags = require('src/flags')
local settings = require('src/settings')
local tracker = require('src/tracker')
local preview = require('src/preview')
local app = require('src/app')
local F, P = flags.FLAG, flags.PENALTY

-- Fake game driven by `state`; counts cause lookups.
local state = { now = 0, flagType = F.None, flagCause = -1, penaltyType = P.None, penaltyParameter = 0, penaltyTime = 0, lap = 2, sessionTime = 60,
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

-- Fake penalty sharing: records announced signals, serves canned gas cuts.
local sharedCuts, announced, flushes = {}, {}, 0
local share = {
  announce = function(_, signals) announced[#announced + 1] = signals end,
  flush = function() flushes = flushes + 1 end,
  gasCuts = function() return sharedCuts end,
}

-- Fake flag sharing: records the raw flags and causes it is given.
local flagsAnnounced, flagFlushes = {}, 0
local flagShare = {
  announce = function(_, flagType, cause) flagsAnnounced[#flagsAnnounced + 1] = { flagType, cause } end,
  flush = function() flagFlushes = flagFlushes + 1 end,
}

local panelShown = 0
local panel = { show = function() panelShown = panelShown + 1 end }

local a = app.new({ game = game, sound = sound, settings = s, tracker = tracker.new({ hold = 0 }),
  preview = preview.new(function() return 2 end), panel = panel, share = share,
  flagShare = flagShare })

-- Clear track.
a:update()
t.check('no signal on clear track', #a:signals() == 0 and a:displayDetail() == nil and #played == 0)
t.check('panel not opened on clear track', panelShown == 0)

-- Yellow with a located cause.
state.now, state.flagType, state.flagCause = 1, F.Caution, 3
a:update()
t.check('yellow displayed', a:signals()[1].flag.id == 'yellow')
t.check('detail describes the incident', a:displayDetail() == 'Incident 200 m ahead, J. Doe')
t.check('caution cue played at master volume', #played == 1 and played[1].cue == 'caution' and played[1].volume == 0.5)
t.check('panel opened on new flag', panelShown == 1)
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
t.check('panel not reopened while unchanged', panelShown == 1)

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
state.now = 3 + require('src/flag_filter').BRIEF - 0.1
a:update()
t.check('green still shown just before it expires', a:signals()[1].flag.id == 'green')
state.now = 3 + require('src/flag_filter').BRIEF
a:update()
t.check('green hidden after its duration while the game keeps it', #a:signals() == 0)

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
a:stopPreview()
for _, o in ipairs(preview.options()) do
  if o.label == 'BLUE' then a:startPreview(o) end
end
t.check('blue preview shows sample lapping cars', a:displayDetail() == preview.sampleDetail(flags.forFlag(F.FasterCar), 2))
a:startPreview(red)
t.check('preview cue played', played[#played].cue == 'severe')
local shownBefore = panelShown
a:startPreview(red)
t.check('preview opens the panel', panelShown == shownBefore + 1)
t.check('preview not in history', #a.deps.tracker.history == historySize)
a:stopPreview()
t.check('real signal back after stop', a:signals()[1].flag.id == 'blue')

-- Test sound uses the cue volume.
s.volume_info = 0.5
a:playCue('info')
t.check('test cue volume is master times cue', t.near(played[#played].volume, 0.25))

-- Jump start as the game reports it: penalty flag plus TeleportToPits with 3 laps. The panel
-- shows the drive-through alone, and both disappear once served through the pit lane.
state.flagType, state.penaltyType, state.penaltyParameter, state.inPitlane = F.ReturnToPits, P.TeleportToPits, 3, false
state.now = 50
a:update()
local jump = a:signals()
t.check('jump start shows a drive through alone', #jump == 1 and jump[1].flag.id == 'driveThrough'
  and jump[1].instruction == 'Drive through the pit lane, laps left: 2')
-- Track cut before serving it: the gas cut must be done now, so it replaces the drive-through.
state.now, state.penaltyTime = 50.5, 2.5
a:update()
local stack = a:signals()
t.check('gas cut replaces the drive through', #stack == 1 and stack[1].flag.id == 'gasCut'
  and stack[1].instruction == 'Lift off for 3s or drop below 35 km/h')
t.check('drive through still shared during the gas cut', a.own[2] and a.own[2].flag.id == 'driveThrough')
state.now, state.penaltyTime = 50.8, 0
a:update()
t.check('drive through alone again once the gas cut is done', #a:signals() == 1
  and a:signals()[1].flag.id == 'driveThrough')
state.now, state.inPitlane = 51, true
a:update()
state.now, state.inPitlane = 52, false
a:update()
t.check('pit penalty and its flag gone after the pit lane', #a:signals() == 0)
state.now, state.flagType = 53, F.None
a:update()

-- Gas cut after that served drive-through, while the game still reports the old penalty.
state.now, state.flagType = 60, F.ReturnToPits
a:update()
local cut = a:signals()
t.check('gas cut without a known time gives the speed rule', #cut == 1 and cut[1].flag.id == 'gasCut'
  and cut[1].instruction == 'Lift off or drop below 35 km/h')
state.now, state.penaltyTime = 60.5, 4.2
a:update()
t.check('gas cut gives the seconds left', a:signals()[1].instruction == 'Lift off for 5s or drop below 35 km/h')
state.now, state.penaltyTime = 61.5, 3.2
a:update()
t.check('gas cut seconds count down', a:signals()[1].instruction == 'Lift off for 4s or drop below 35 km/h')
state.penaltyTime = 0
state.flagType, state.penaltyType, state.penaltyParameter = F.None, P.None, 0

-- Own signals are announced to other drivers when they change, and queued messages flushed each frame.
t.check('own signals announced on change', #announced > 0 and announced[#announced] == a.own)
t.check('share flushed every update', flushes > 0)
t.check('raw flag shared and flushed every update', #flagsAnnounced > 0 and flagFlushes == #flagsAnnounced)
local caution = false
for _, f in ipairs(flagsAnnounced) do
  if f[1] == F.Caution and f[2] == 3 then caution = true end
end
t.check('yellow shared with its cause', caution)
state.now = 69
a:update()
local announcedBefore = #announced
state.now = 70
a:update()
t.check('nothing announced while unchanged', #announced == announcedBefore)

-- Another driver close ahead serves a gas cut: alert shown with the car list, then removed.
carList = {
  { index = 0, name = 'Me', spline = 0.50, racePosition = 6, running = true },
  { index = 4, name = 'Seygow', spline = 0.53, racePosition = 5, running = true },
}
sharedCuts = { { carIndex = 4, secondsLeft = 4 } }
state.now = 71
a:update()
local top = a:signals()[1]
t.check('gas cut ahead alert shown', top.flag == flags.GAS_CUT_AHEAD and a:displayDetail() == 'P5 Seygow 120 m, lift 4s')
t.check('alert is not announced as an own penalty', #announced == announcedBefore)
s.gasCutRange = 50
state.now = 71 + app.DETAIL_INTERVAL
a:update()
t.check('out of range: alert removed', #a:signals() == 0)
s.gasCutRange = settings.DEFAULTS.gasCutRange
state.now = 71 + 2 * app.DETAIL_INTERVAL
a:update()
state.flagType = F.Caution
state.now = 71 + 3 * app.DETAIL_INTERVAL
a:update()
local both = a:signals()
t.check('own flag ranks above the gas cut ahead', #both == 2 and both[1].flag.id == 'yellow' and both[2].flag == flags.GAS_CUT_AHEAD)
state.flagType, state.penaltyTime = F.ReturnToPits, 3
state.now = 71 + 4 * app.DETAIL_INTERVAL
a:update()
local cutAndAhead = a:signals()
t.check('own gas cut on top, gas cut ahead below', #cutAndAhead == 2 and cutAndAhead[1].flag.id == 'gasCut'
  and cutAndAhead[2].flag == flags.GAS_CUT_AHEAD)
t.check('cars ahead on the location line of the own gas cut', a:displayDetail() == 'P5 Seygow 120 m, lift 4s')
state.flagType, state.penaltyTime = F.None, 0
state.now = 71 + 5 * app.DETAIL_INTERVAL
a:update()
t.check('gas cut ahead still shown once the own gas cut is done', #a:signals() == 1
  and a:signals()[1].flag == flags.GAS_CUT_AHEAD and a:displayDetail() == 'P5 Seygow 120 m, lift 4s')
sharedCuts = {}
state.flagType = F.None
state.now = 71 + 6 * app.DETAIL_INTERVAL
a:update()
t.check('alert cleared when the gas cut ends', #a:signals() == 0)

-- The gas cut time never leaks into other flags.
state.flagType, state.penaltyTime = F.Stop, 4.2
state.now = 90
a:update()
t.check('black flag carries no gas cut seconds', a:signals()[1].flag.id == 'black' and a:signals()[1].parameter == nil)
state.flagType, state.penaltyTime = F.None, 0
state.now = 91
a:update()

-- No game state: nothing changes.
readsNil = true
state.now = 99
a:update()
t.check('update ignored without game state', a.now ~= 99)

t.finish()
