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

local setupState = { previewLabel = nil, previewRemaining = 0, panelMissing = false }
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

function script.drawGlow(dt)
  if prefs.glow then
    glowView.draw(controller:signals(), controller.now, ac.getUI().windowSize, prefs)
  end
end
