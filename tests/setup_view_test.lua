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
  snap = function(p) calls.snap = p end,
  testSound = function(cue) calls.test = cue end,
}

-- Idle state: every preview option and preset gets a button, no status lines.
local s = freshSettings()
setup.draw(s, { previewRemaining = 0, snapFailed = false }, actions)
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
t.check('four sections', #uiStub.named('header') == 4)
local rowBreaks = #uiStub.named('sameLine')
t.check('buttons wrapped in rows', rowBreaks > 0)

-- Clicks reach the actions.
uiStub.reset()
uiStub.clicks['RED'] = true
uiStub.clicks[layout.PRESETS[2].label] = true
uiStub.clicks['Test##blue'] = true
setup.draw(s, { previewRemaining = 0, snapFailed = false }, actions)
t.check('preview action gets the option', calls.preview and calls.preview.label == 'RED')
t.check('snap action gets the preset', calls.snap == layout.PRESETS[2])
t.check('test action gets the cue', calls.test == flags.SOUND.blue)

-- Active preview and failed snap show status lines.
uiStub.reset()
uiStub.clicks['Stop'] = true
setup.draw(s, { previewLabel = 'YELLOW', previewRemaining = 3.2, snapFailed = true }, actions)
local texts = uiStub.texts()
local hasPreview, hasSnap = false, false
for _, tx in ipairs(texts) do
  if tx == 'Previewing YELLOW, 4 s left' then hasPreview = true end
  if tx == setup.SNAP_FAILED_TEXT then hasSnap = true end
end
t.check('preview status shown', hasPreview)
t.check('stop button works', calls.stop)
t.check('snap failure explained', hasSnap)

-- Checkboxes toggle settings.
uiStub.reset()
uiStub.clicks['Sound cues'] = true
uiStub.clicks['Screen-edge glow'] = true
setup.draw(s, { previewRemaining = 0, snapFailed = false }, actions)
t.check('sound toggled off', s.sound == false)
t.check('glow toggled off', s.glow == false)

-- Sliders write back 0..1 values.
uiStub.reset()
uiStub.sliders['##volume'] = 40
uiStub.sliders['##volume_severe'] = 75
uiStub.sliders['##glowThickness'] = 8
setup.draw(s, { previewRemaining = 0, snapFailed = false }, actions)
t.check('master volume written', t.near(s.volume, 0.4))
t.check('cue volume written', t.near(s.volume_severe, 0.75))
t.check('glow width written', t.near(s.glowThickness, 0.08))
t.check('blue range untouched', s.blueRange == settings.DEFAULTS.blueRange)
uiStub.reset()
uiStub.sliders['##blueRange'] = 600
setup.draw(s, { previewRemaining = 0, snapFailed = false }, actions)
t.check('blue range written', s.blueRange == 600)
local unchanged = s.volume_blue == 1
t.check('untouched sliders keep value', unchanged)

t.finish()
