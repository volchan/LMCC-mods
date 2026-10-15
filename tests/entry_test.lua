-- Loads the real entry script against stubbed CSP globals and drives every callback.
local t = require('tests/helper')
t.stubCsp()
local uiStub = require('tests/ui_stub')
uiStub.install(vec2(520, 130))
local flags = require('src/flags')
local F, P = flags.FLAG, flags.PENALTY

local sim = { time = 10000, raceFlagType = F.Caution, raceFlagCause = -1, currentSessionIndex = 0, trackLengthM = 4000 }
local car = { index = 0, currentPenaltyType = P.None, currentPenaltyParameter = 0, lapCount = 0, splinePosition = 0.2 }
local storage
local moved = nil
local shown = false
local window = {
  size = function() return vec2(520, 130) end,
  move = function(_, p) moved = p end,
  setVisible = function(_, v) shown = v end,
  resize = function() end,
}
local windows = {}
local audio = 0
netSent = {}
os.preciseClock = function() return 100 end
local wallClock = 1000
os.time = function() return wallClock end
local shared = {}
local dir = 'app'
ac = {
  storage = function(layout)
    storage = {}
    for k, v in pairs(layout) do storage[k] = v end
    return storage
  end,
  getSim = function() return sim end,
  getCar = function(i) return i == 0 and car or nil end,
  getSession = function() return { startTime = 0 } end,
  getUI = function() return { windowSize = vec2(1920, 1080), uiScale = 2 } end,
  getAppWindows = function() return windows end,
  accessAppWindow = function() return window end,
  dirname = function() return dir end,
  store = function(k, v) shared[k] = v end,
  load = function(k) return shared[k] end,
  StructItem = { key = function(k) return k end, byte = function() end, uint16 = function() end, int32 = function() end },
  -- Only the network test event is recorded; penalty sharing has its own key.
  OnlineEvent = function(layout)
    return function(message)
      if layout[1] == require('src/net').KEY then netSent[#netSent + 1] = message end
    end
  end,
  getDriverName = function() return 'Me' end,
  AudioEvent = { fromFile = function()
    audio = audio + 1
    return { start = function() end, dispose = function() end }
  end },
}
script = {}

dofile('apps/lua/LMCC_Flags/LMCC_Flags.lua')
t.check('callbacks registered', script.update and script.windowPanel and script.windowHistory
  and script.windowSetup and script.drawGlow)

-- Yellow held past the debounce: tracked and a cue played.
script.update(0)
sim.time = 11000
script.update(0)
t.check('cue played on yellow', audio == 1)

uiStub.reset()
script.windowPanel(0)
t.check('panel shows yellow', uiStub.texts()[1] == 'YELLOW')

-- First frame starts the slide in; strips show once time moves on.
script.drawGlow(0)
sim.time = 12000
script.update(0)
uiStub.reset()
script.drawGlow(0)
t.check('strips drawn', #uiStub.named('window') == 1 and #uiStub.named('rect') == 2)
storage.glow = false
uiStub.reset()
script.drawGlow(0)
t.check('strips ignore a stored off value', #uiStub.named('rect') == 2)

uiStub.reset()
script.windowHistory(0)
t.check('history lists the yellow flag', uiStub.texts()[1]:find('YELLOW') ~= nil)
uiStub.reset()
uiStub.clicks['Clear'] = true
script.windowHistory(0)
uiStub.reset()
script.windowHistory(0)
t.check('clear empties history', uiStub.texts()[1] == require('src/history_view').EMPTY_TEXT)

-- Setup: preview, stop, test sound, snap.
uiStub.reset()
uiStub.clicks['RED'] = true
script.windowSetup(0)
uiStub.reset()
script.windowSetup(0)
local previewing = false
for _, tx in ipairs(uiStub.texts()) do
  if tx:find('Showing RED') then previewing = true end
end
t.check('preview status shown in setup', previewing and audio == 2)
uiStub.reset()
uiStub.clicks['Stop'] = true
script.windowSetup(0)
uiStub.reset()
script.windowPanel(0)
t.check('panel back to real flag after stop', uiStub.texts()[1] == 'YELLOW')

uiStub.reset()
uiStub.clicks['Test##blue'] = true
script.windowSetup(0)
t.check('test sound plays', audio == 3)

local layout = require('src/layout')
uiStub.reset()
uiStub.clicks[layout.PRESETS[1].label] = true
script.windowSetup(0)
uiStub.reset()
script.windowSetup(0)
local failed = false
for _, tx in ipairs(uiStub.texts()) do
  if tx == require('src/setup_view').PANEL_MISSING_TEXT then failed = true end
end
t.check('snap fails while panel window is unknown', failed and moved == nil)

windows[1] = { name = 'panel', title = 'LMCC Flags' }
uiStub.reset()
uiStub.clicks[layout.PRESETS[1].label] = true
script.windowSetup(0)
t.check('snap moves the panel', moved ~= nil and moved.x == layout.MARGIN)

shown = false
uiStub.reset()
uiStub.clicks[require('src/setup_view').SHOW_PANEL_LABEL] = true
script.windowSetup(0)
t.check('show panel opens the window', shown == true)

-- A new flag reopens a closed panel.
shown = false
sim.raceFlagType = F.Stop
sim.time = 20000
script.update(0)
sim.time = 21000
script.update(0)
t.check('new flag opens the panel', shown == true)

-- Right click on the panel locks it and saves the state; the padlock animation plays.
uiStub.reset()
uiStub.hovered = true
uiStub.mouseClicks[ui.MouseButton.Right] = true
script.windowPanel(0)
t.check('right click locks the panel', storage.panelLocked == true)
uiStub.reset()
uiStub.time = 0.5
script.windowPanel(0)
t.check('lock animation drawn', #uiStub.named('pathStroke') == 1)
t.check('locked panel blocks moving', uiStub.named('invisibleButton')[1].args[1] == '##lmccLocked')

-- Unlocked again, dragging the grip saves the size; the next frames apply it in screen pixels.
uiStub.reset()
uiStub.hovered = true
uiStub.mouseClicks[ui.MouseButton.Right] = true
script.windowPanel(0)
local resizedTo
window.resize = function(_, s) resizedTo = s end
window.valid = function() return true end
uiStub.reset()
uiStub.active, uiStub.delta = true, vec2(10, 0)
script.windowPanel(0)
t.check('grip drag saves the size', storage.panelLocked == false and resizedTo == nil
  and storage.panelWidth == 530 and storage.panelHeight == 130)
uiStub.reset()
uiStub.active, uiStub.delta = true, vec2(10, 0)
script.windowPanel(0)
t.check('saved size applied scaled by the UI', resizedTo.x == 1060 and resizedTo.y == 260)
t.check('drags add up from the saved size', storage.panelWidth == 540)

-- A FIXED_SIZE window goes back to its manifest size: the saved size is set every frame.
for _ = 1, 2 do
  resizedTo = nil
  uiStub.reset()
  script.windowPanel(0)
  t.check('saved size set again', resizedTo.x == 1080 and resizedTo.y == 260)
end


-- Network tab: the ping button sends through the online event.
uiStub.reset()
uiStub.clicks[require('src/setup_view').NET_PING_LABEL] = true
script.windowSetup(0)
t.check('network ping sent', #netSent == 1)

-- A dev install running in the same session silences this release install.
local presence = require('src/presence')
local setupView = require('src/setup_view')
shared[presence.KEY] = wallClock
script.update(0)
uiStub.reset()
script.windowPanel(0)
script.windowHistory(0)
script.drawGlow(0)
t.check('silent release draws nothing', #uiStub.calls == 0)
script.windowSetup(0)
t.check('silent release explains why in setup', uiStub.texts()[1] == setupView.SILENT_TEXT)
wallClock = wallClock + presence.TIMEOUT + 1
script.update(0)
uiStub.reset()
script.windowPanel(0)
t.check('release back once the dev install stops', #uiStub.calls > 0)

-- The same entry in a dev folder announces itself and uses the dev window titles.
shared = {}
dir = 'C:/AC/apps/lua/LMCC_Flags_dev'
package.loaded['src/main'] = nil
script = {}
dofile('apps/lua/LMCC_Flags/LMCC_Flags.lua')
script.update(0)
t.check('dev install leaves a heartbeat', shared[presence.KEY] == wallClock)
shown = false
windows[1] = { name = 'panel', title = 'LMCC Flags (dev)' }
uiStub.reset()
uiStub.clicks[setupView.SHOW_PANEL_LABEL] = true
script.windowSetup(0)
t.check('dev install opens its own panel', shown == true)

t.finish()
