local t = require('tests/helper')
t.stubCsp()
local uiStub = require('tests/ui_stub')
uiStub.install(vec2(400, 600))
local flags = require('src/flags')
local layout = require('src/layout')
local preview = require('src/preview')
local settings = require('src/settings')
local setup = require('src/setup_view')

t.check('cue label lists its flags', setup.cueLabel('blue') == 'Blue (BLUE)')

local function freshSettings()
  local s = {}
  for k, v in pairs(settings.DEFAULTS) do s[k] = v end
  return s
end

local calls = {}
local actions = {
  preview = function(o) calls.preview = o end,
  stopPreview = function() calls.stop = true end,
  showPanel = function() calls.show = true end,
  snap = function(p) calls.snap = p end,
  testSound = function(cue) calls.test = cue end,
}

-- Idle state: every preview option and preset gets a button, no status lines.
local s = freshSettings()
setup.draw(s, { previewRemaining = 0, panelMissing = false }, actions)
local buttons = {}
for _, c in ipairs(uiStub.named('button')) do buttons[c.args[1]] = true end
local allPreviews = true
for _, o in ipairs(preview.options()) do
  if not buttons[o.label] then allPreviews = false end
end
t.check('a button per preview option', allPreviews)
t.check('a button per position preset', buttons[layout.PRESETS[1].label] and buttons[layout.PRESETS[#layout.PRESETS].label])
t.check('a test button per cue', buttons['Test##caution'] and buttons['Test##info'])
t.check('no stop button when idle', not buttons['Stop'])
t.check('five sections', #uiStub.named('header') == 5)
local rowBreaks = #uiStub.named('sameLine')
t.check('buttons wrapped in rows', rowBreaks > 0)

-- Clicks reach the actions.
uiStub.reset()
uiStub.clicks['RED'] = true
uiStub.clicks[layout.PRESETS[2].label] = true
uiStub.clicks['Test##blue'] = true
uiStub.clicks[setup.SHOW_PANEL_LABEL] = true
setup.draw(s, { previewRemaining = 0, panelMissing = false }, actions)
t.check('preview action gets the option', calls.preview and calls.preview.label == 'RED')
t.check('snap action gets the preset', calls.snap == layout.PRESETS[2])
t.check('test action gets the cue', calls.test == flags.SOUND.blue)
t.check('show panel action fired', calls.show == true)

-- Active preview and failed snap show status lines.
uiStub.reset()
uiStub.clicks['Stop'] = true
setup.draw(s, { previewLabel = 'YELLOW', previewRemaining = 3.2, panelMissing = true }, actions)
local texts = uiStub.texts()
local hasPreview, hasSnap = false, false
for _, tx in ipairs(texts) do
  if tx == 'Previewing YELLOW, 4 s left' then hasPreview = true end
  if tx == setup.PANEL_MISSING_TEXT then hasSnap = true end
end
t.check('preview status shown', hasPreview)
t.check('stop button works', calls.stop)
t.check('missing panel explained', hasSnap)

-- Checkboxes toggle settings.
uiStub.reset()
uiStub.clicks['Sound cues'] = true
setup.draw(s, { previewRemaining = 0, panelMissing = false }, actions)
t.check('sound toggled off', s.sound == false)
t.check('no strips toggle', s.glow == nil)

-- Sliders write back 0..1 values.
uiStub.reset()
uiStub.sliders['##volume'] = 40
uiStub.sliders['##volume_severe'] = 75
uiStub.sliders['##glowThickness'] = 8
setup.draw(s, { previewRemaining = 0, panelMissing = false }, actions)
t.check('master volume written', t.near(s.volume, 0.4))
t.check('cue volume written', t.near(s.volume_severe, 0.75))
t.check('strip height written', t.near(s.glowThickness, 0.08))
t.check('blue range untouched', s.blueRange == settings.DEFAULTS.blueRange)
uiStub.reset()
uiStub.sliders['##blueRange'] = 600
setup.draw(s, { previewRemaining = 0, panelMissing = false }, actions)
t.check('blue range written', s.blueRange == 600)
local unchanged = s.volume_blue == 1
t.check('untouched sliders keep value', unchanged)

-- Game data: raw values with enum names, or a waiting line before the first read.
local function hasText(text)
  for _, tx in ipairs(uiStub.texts()) do
    if tx == text then return true end
  end
  return false
end
uiStub.reset()
setup.draw(s, { previewRemaining = 0, panelMissing = false, raw = {} }, actions)
t.check('game data waits for the game', hasText(setup.NO_GAME_DATA_TEXT))
uiStub.reset()
setup.draw(s, { previewRemaining = 0, panelMissing = false,
  raw = { flagType = 8, flagCause = -1, penaltyType = 1, penaltyParameter = 3, inPitlane = true, penaltyTime = 4.2 } }, actions)
t.check('game data shows the flag', hasText('Flag: ReturnToPits (8), cause car -1'))
t.check('game data shows the penalty', hasText('Penalty: MandatoryPits (1), parameter 3'))
t.check('game data shows the pit lane', hasText('In pit lane: yes'))
t.check('game data shows the penalty time', hasText('Penalty time: 4.2 s'))
uiStub.reset()
setup.draw(s, { previewRemaining = 0, panelMissing = false,
  raw = { flagType = 0, flagCause = -1, penaltyType = 0, penaltyParameter = 0, inPitlane = false } }, actions)
t.check('game data outside the pit lane', hasText('In pit lane: no'))

t.finish()
