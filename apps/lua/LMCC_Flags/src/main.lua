-- Wiring only: the logic lives in the other src/ modules. Loaded by LMCC_Flags.lua, and by the entry
-- of a dev install (install.ps1), which differs only by its folder name.
local app = require('src/app')
local game = require('src/game')
local sound = require('src/sound')
local settings = require('src/settings')
local tracker = require('src/tracker')
local preview = require('src/preview')
local windowMover = require('src/window_mover')
local panelView = require('src/panel_view')
local panelInput = require('src/panel_input')
local panelSize = require('src/panel_size')
local lock = require('src/lock')
local lockView = require('src/lock_view')
local glowView = require('src/glow_view')
local historyView = require('src/history_view')
local setupView = require('src/setup_view')
local net = require('src/net')
local share = require('src/share')
local flagShare = require('src/flag_share')
local variant = require('src/variant')
local presence = require('src/presence')

-- Must match NAME of the panel window in manifest.ini; install.ps1 adds the dev suffix there too.
local dev = variant.isDev(ac.dirname())
local PANEL_TITLE = variant.title('LMCC Flags', dev)

-- A release install stays silent while a dev install runs in the same session.
local devPresence = presence.new(dev, os.time, ac.store, ac.load)

local prefs = settings.load()
local penalties = share.new(os.preciseClock)
local controller = app.new({
  game = game, sound = sound, settings = prefs, tracker = tracker.new(), preview = preview.new(),
  panel = { show = function() windowMover.show(PANEL_TITLE) end },
  share = penalties,
  flagShare = flagShare.new(),
})

-- Real time for the lock animation, so it plays even while the game is paused.
local panelLock = lock.new(prefs.panelLocked)
local savedSize = panelSize.new(prefs)
local panelActions = {
  toggleLock = function() prefs.panelLocked = panelLock:toggle(ui.time()) end,
  -- Only saves: windowPanel applies the saved size every frame.
  resize = function(delta) savedSize:grow(savedSize:target() or ui.windowSize(), delta) end,
}

-- Online messaging test, real time so it works while paused.
local netTest = net.new(os.preciseClock)

local setupState = { previewLabel = nil, previewRemaining = 0, panelMissing = false, raw = controller.snapshot }
local actions = {
  preview = function(option) controller:startPreview(option) end,
  stopPreview = function() controller:stopPreview() end,
  showPanel = function() setupState.panelMissing = not windowMover.show(PANEL_TITLE) end,
  toggleLock = panelActions.toggleLock,
  snap = function(preset)
    setupState.panelMissing = not windowMover.snap(PANEL_TITLE, preset, ac.getUI().windowSize)
  end,
  testSound = function(cue) controller:playCue(cue) end,
  netPing = function() netTest:ping() end,
  testPenalty = function() penalties:test() end,
}

local function clearHistory()
  controller.deps.tracker:clear()
end

function script.update(dt)
  if devPresence:update() then return end
  controller:update()
end

function script.windowPanel(dt)
  if devPresence.silent then return end
  -- A FIXED_SIZE window keeps a size set from Lua for one frame only, then goes back to SIZE of
  -- manifest.ini: set it every frame, as the CMRT HUD does. Skipping a frame makes it flicker.
  local target = savedSize:target()
  if target then windowMover.resize(PANEL_TITLE, target) end
  panelView.draw(controller:signals(), controller:displayDetail(), controller.now)
  panelInput.update(panelLock.locked, panelActions)
  lockView.draw(panelLock, ui.time(), panelView.scale(ui.windowSize()))
end

function script.windowHistory(dt)
  if devPresence.silent then return end
  historyView.draw(controller.deps.tracker.history, clearHistory)
end

function script.windowSetup(dt)
  if devPresence.silent then
    setupView.drawSilent()
    return
  end
  local p = controller.deps.preview
  local previewing = p:active(controller.now)
  setupState.previewLabel = previewing and previewing[1] and previewing[1].flag.label or nil
  setupState.previewRemaining = p:remaining(controller.now)
  setupState.locked = panelLock.locked
  setupState.net = netTest:status()
  setupView.draw(prefs, setupState, actions)
end

-- Always on: drivers cannot turn the strips off, so no flag goes unseen.
function script.drawGlow(dt)
  if devPresence.silent then return end
  glowView.draw(controller:signals(), controller.now, ac.getUI().windowSize, prefs)
end
