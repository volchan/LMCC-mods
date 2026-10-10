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
local window = { size = function() return vec2(520, 130) end, move = function(_, p) moved = p end }
local windows = {}
local audio = 0
ac = {
  storage = function(layout)
    storage = {}
    for k, v in pairs(layout) do storage[k] = v end
    return storage
  end,
  getSim = function() return sim end,
  getCar = function(i) return i == 0 and car or nil end,
  getSession = function() return { startTime = 0 } end,
  getUI = function() return { windowSize = vec2(1920, 1080) } end,
  getAppWindows = function() return windows end,
  accessAppWindow = function() return window end,
  dirname = function() return 'app' end,
  AudioEvent = { fromFile = function()
    audio = audio + 1
    return { start = function() end, dispose = function() end }
  end },
}
script = {}

dofile('apps/lua/LmccFlags/LmccFlags.lua')
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
t.check('strips drawn when enabled', #uiStub.named('window') == 1 and #uiStub.named('rect') == 2)
storage.glow = false
uiStub.reset()
script.drawGlow(0)
t.check('strips skipped when disabled', #uiStub.calls == 0)

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
  if tx:find('Previewing RED') then previewing = true end
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
  if tx == require('src/setup_view').SNAP_FAILED_TEXT then failed = true end
end
t.check('snap fails while panel window is unknown', failed and moved == nil)

windows[1] = { name = 'panel', title = 'LMCC Flags' }
uiStub.reset()
uiStub.clicks[layout.PRESETS[1].label] = true
script.windowSetup(0)
t.check('snap moves the panel', moved ~= nil and moved.x == layout.MARGIN)

t.finish()
