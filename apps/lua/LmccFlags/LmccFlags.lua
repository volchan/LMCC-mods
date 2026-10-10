-- LMCC Flags: makes race flags impossible to miss for championship drivers.
-- Wiring only: the logic lives in src/.
local app = require('src/app')
local game = require('src/game')
local sound = require('src/sound')
local settings = require('src/settings')
local tracker = require('src/tracker')
local preview = require('src/preview')
local windowMover = require('src/window_mover')
local panelView = require('src/panel_view')
local panelInput = require('src/panel_input')
local lock = require('src/lock')
local lockView = require('src/lock_view')
local glowView = require('src/glow_view')
local historyView = require('src/history_view')
local setupView = require('src/setup_view')

-- Must match NAME of the panel window in manifest.ini.
local PANEL_TITLE = 'LMCC Flags'

local prefs = settings.load()
local controller = app.new({
  game = game, sound = sound, settings = prefs, tracker = tracker.new(), preview = preview.new(),
  panel = { show = function() windowMover.show(PANEL_TITLE) end },
})

-- Real time for the lock animation, so it plays even while the game is paused.
local panelLock = lock.new(prefs.panelLocked)
local panelActions = {
  toggleLock = function() prefs.panelLocked = panelLock:toggle(ui.time()) end,
  resize = function(size) windowMover.resize(PANEL_TITLE, size) end,
}

local setupState = { previewLabel = nil, previewRemaining = 0, panelMissing = false, raw = controller.snapshot }
local actions = {
  preview = function(option) controller:startPreview(option) end,
  stopPreview = function() controller:stopPreview() end,
  showPanel = function() setupState.panelMissing = not windowMover.show(PANEL_TITLE) end,
  snap = function(preset)
    setupState.panelMissing = not windowMover.snap(PANEL_TITLE, preset, ac.getUI().windowSize)
  end,
  testSound = function(cue) controller:playCue(cue) end,
}

local function clearHistory()
  controller.deps.tracker:clear()
end

function script.update(dt)
  controller:update()
end

function script.windowPanel(dt)
  panelView.draw(controller:signals(), controller:displayDetail(), controller.now)
  local hovered = panelInput.update(panelLock.locked, panelActions)
  lockView.draw(panelLock, ui.time(), hovered)
end

function script.windowHistory(dt)
  historyView.draw(controller.deps.tracker.history, clearHistory)
end

function script.windowSetup(dt)
  local p = controller.deps.preview
  local previewing = p:active(controller.now)
  setupState.previewLabel = previewing and previewing[1] and previewing[1].flag.label or nil
  setupState.previewRemaining = p:remaining(controller.now)
  setupView.draw(prefs, setupState, actions)
end

-- Always on: drivers cannot turn the strips off, so no flag goes unseen.
function script.drawGlow(dt)
  glowView.draw(controller:signals(), controller.now, ac.getUI().windowSize, prefs)
end
