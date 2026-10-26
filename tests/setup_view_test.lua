local t = require('tests/helper')
t.stubCsp()
local uiStub = require('tests/ui_stub')
uiStub.install(vec2(400, 600))
local flags = require('src/flags')
local layout = require('src/layout')
local preview = require('src/preview')
local settings = require('src/settings')
local setup = require('src/setup_view')

t.check('cue name is short', setup.cueName('caution') == 'Caution')
t.check('cue flags listed for the tooltip', setup.cueFlags('blue') == 'BLUE')

local function freshSettings()
  local s = {}
  for k, v in pairs(settings.DEFAULTS) do s[k] = v end
  return s
end

local function idle(extra)
  local state = { previewRemaining = 0, panelMissing = false, locked = false }
  for k, v in pairs(extra or {}) do state[k] = v end
  return state
end

local function hasText(text)
  for _, tx in ipairs(uiStub.texts()) do
    if tx == text then return true end
  end
  return false
end

local calls = {}
local actions = {
  preview = function(o) calls.preview = o end,
  stopPreview = function() calls.stop = true end,
  showPanel = function() calls.show = true end,
  toggleLock = function() calls.lock = (calls.lock or 0) + 1 end,
  snap = function(p) calls.snap = p end,
  testSound = function(cue) calls.test = cue end,
  netPing = function() calls.ping = true end,
  testPenalty = function() calls.penalty = true end,
}

-- Layout: four tabs, every alert and preset gets a button, no status lines when idle.
local s = freshSettings()
setup.draw(s, idle(), actions)
local tabs = {}
for _, c in ipairs(uiStub.named('tab')) do tabs[#tabs + 1] = c.args[1] end
t.check('four tabs', table.concat(tabs, ',') == 'Alerts,Panel,Display,Sound')
local buttons = {}
for _, c in ipairs(uiStub.named('button')) do buttons[c.args[1]] = c.args[2] or true end
local allPreviews = true
for _, o in ipairs(preview.options()) do
  if not buttons[o.label] then allPreviews = false end
end
t.check('a button per alert', allPreviews)
t.check('a button per position preset', buttons[layout.PRESETS[1].label] and buttons[layout.PRESETS[#layout.PRESETS].label])
t.check('a test button per cue', buttons['Test##caution'] and buttons['Test##info'])
t.check('no stop button when idle', not buttons['Stop'])
t.check('test hint shown', hasText(setup.TEST_HINT))

-- Alerts: grouped by kind, equal width, painted in their flag colours.
local function groupLabels(kind)
  for _, g in ipairs(setup.GROUPS) do
    if g.kind == kind then
      local labels = {}
      for _, o in ipairs(g.options) do labels[o.label] = true end
      return labels
    end
  end
end
local race, penalties, server = groupLabels(flags.KIND.race), groupLabels(flags.KIND.penalty), groupLabels(flags.KIND.server)
t.check('race flags group', race['GREEN'] and race['YELLOW'] and race['BLUE'] and race['BLACK'] and not race['RED'])
t.check('penalties group holds the gas cut', penalties['GAS CUT'] and penalties['DRIVE THROUGH'] and penalties['PIT PENALTY'])
t.check('server flags group', server['RED'] and server['CODE 60'] and not server['GREEN'])
t.check('other drivers group', groupLabels(flags.KIND.others)['GAS CUT AHEAD'])
t.check('server flags in a collapsible node', #uiStub.named('tree') == 2)
local w = (400 - setup.GAP * (setup.ALERT_COLUMNS - 1)) / setup.ALERT_COLUMNS
t.check('alert buttons share the width', t.near(buttons['GREEN'].x, w) and t.near(buttons['RED'].x, w))
local optionCount = #preview.options()
t.check('each alert button pushes its colours', #uiStub.named('pushStyleColor') == optionCount * 4
  and #uiStub.named('popStyleColor') == optionCount)
local firstColor = uiStub.named('pushStyleColor')[1].args
t.check('button colour comes from the flag', firstColor[1] == ui.StyleColor.Button
  and firstColor[2] == setup.GROUPS[1].options[1].flag.color)

-- Panel: presets laid out on a 3x3 grid, two empty cells on the middle row.
t.check('position grid has two empty cells', #uiStub.named('dummy') == 2)

-- Clicks reach the actions.
uiStub.reset()
uiStub.clicks['RED'] = true
uiStub.clicks[layout.PRESETS[2].label] = true
uiStub.clicks['Test##blue'] = true
uiStub.clicks[setup.SHOW_PANEL_LABEL] = true
uiStub.clicks[setup.LOCK_LABEL] = true
setup.draw(s, idle(), actions)
t.check('preview action gets the option', calls.preview and calls.preview.label == 'RED')
t.check('snap action gets the preset', calls.snap == layout.PRESETS[2])
t.check('test action gets the cue', calls.test == flags.SOUND.blue)
t.check('show panel action fired', calls.show == true)
t.check('lock checkbox toggles the lock', calls.lock == 1)

-- Active preview and missing panel show status lines.
uiStub.reset()
uiStub.clicks['Stop'] = true
setup.draw(s, idle({ previewLabel = 'YELLOW', previewRemaining = 3.2, panelMissing = true }), actions)
t.check('preview status shown', hasText('Showing YELLOW, 4 s left'))
t.check('stop button works', calls.stop)
t.check('missing panel explained', hasText(setup.PANEL_MISSING_TEXT))

-- Hovering a cue name shows its alerts.
uiStub.reset()
uiStub.itemHovered = true
setup.draw(s, idle(), actions)
t.check('cue tooltip on hover', #uiStub.named('tooltip') == 4)

-- Checkboxes toggle settings.
uiStub.reset()
uiStub.clicks['Sound cues'] = true
uiStub.clicks['Pulse urgent flags'] = true
uiStub.clicks['Scroll the flag name'] = true
setup.draw(s, idle(), actions)
t.check('sound toggled off', s.sound == false)
t.check('pulse toggled off', s.glowPulse == false)
t.check('scroll toggled off', s.glowScroll == false)
t.check('no strips toggle', s.glow == nil)

-- Sliders write back their values.
uiStub.reset()
uiStub.sliders['##volume'] = 40
uiStub.sliders['##volume_severe'] = 75
uiStub.sliders['##glowThickness'] = 8
setup.draw(s, idle(), actions)
t.check('master volume written', t.near(s.volume, 0.4))
t.check('cue volume written', t.near(s.volume_severe, 0.75))
t.check('strip height written', t.near(s.glowThickness, 0.08))
t.check('blue range untouched', s.blueRange == settings.DEFAULTS.blueRange)
uiStub.reset()
uiStub.sliders['##blueRange'] = 600
setup.draw(s, idle(), actions)
t.check('blue range written', s.blueRange == 600)
local function sliderMin(label)
  for _, c in ipairs(uiStub.named('slider')) do
    if c.args[1] == label then return c.args[3] end
  end
end
t.check('strip height at least 3%', sliderMin('##glowThickness') == 3)
t.check('blue range at least 200 m', sliderMin('##blueRange') == 200)
uiStub.reset()
uiStub.sliders['##gasCutRange'] = 450
setup.draw(s, idle(), actions)
t.check('gas cut ahead range written', s.gasCutRange == 450)
t.check('untouched sliders keep value', s.volume_blue == 1)

-- Game data: raw values with enum names, or a waiting line before the first read.
uiStub.reset()
setup.draw(s, idle({ raw = {} }), actions)
t.check('game data waits for the game', hasText(setup.NO_GAME_DATA_TEXT))
uiStub.reset()
setup.draw(s, idle({ raw = { flagType = 8, flagCause = -1, penaltyType = 1, penaltyParameter = 3, inPitlane = true,
  penaltyTime = 4.2, lap = 1 } }), actions)
t.check('game data shows the flag', hasText('Flag: ReturnToPits (8), cause car -1'))
t.check('game data shows the penalty', hasText('Penalty: MandatoryPits (1), parameter 3'))
t.check('game data shows the lap and pit lane', hasText('Lap: 1, in pit lane: yes'))
t.check('game data shows the penalty time', hasText('Penalty time: 4.2 s'))
uiStub.reset()
setup.draw(s, idle({ raw = { flagType = 0, flagCause = -1, penaltyType = 0, penaltyParameter = 0, inPitlane = false } }), actions)
t.check('game data outside the pit lane', hasText('Lap: 0, in pit lane: no'))

-- Network tab: only with a status, explains the server type and lists results.
local function hasHeader(text)
  for _, c in ipairs(uiStub.named('header')) do
    if c.args[1] == text then return true end
  end
  return false
end
uiStub.reset()
setup.draw(s, idle(), actions)
t.check('no network tab without status', #uiStub.named('tab') == 4)
local net = { online = false, direct = false, pinged = false, pingMs = -1, replies = {}, pingsFrom = {} }
uiStub.reset()
uiStub.clicks[setup.NET_PING_LABEL] = true
uiStub.clicks[setup.NET_PENALTY_LABEL] = true
setup.draw(s, idle({ net = net }), actions)
t.check('network tab shown', #uiStub.named('tab') == 5)
t.check('ping button fires', calls.ping == true)
t.check('test penalty button fires', calls.penalty == true)
t.check('offline and chat server explained', hasText(setup.NET_OFFLINE_TEXT) and hasText(setup.NET_CHAT_TEXT))
t.check('empty lists say so', hasText(setup.NET_NONE_TEXT) and not hasText('Own ping came back: not yet'))
net = { online = true, direct = true, pinged = true, echoMs = 30, pingMs = 40, echoRoute = 'server',
  replies = { { name = 'Alice', ms = 50 } }, pingsFrom = { { name = 'Bob', ago = 3 } } }
uiStub.reset()
setup.draw(s, idle({ net = net }), actions)
t.check('direct server explained', hasText(setup.NET_DIRECT_TEXT) and not hasText(setup.NET_OFFLINE_TEXT))
t.check('echo time and verdict shown', hasText('Own ping came back after 30 ms (your ping to the server: 40 ms)')
  and hasText(setup.NET_ECHO_TEXT.server))
t.check('replies listed', hasHeader('Replies (1)') and hasText('Alice: 50 ms'))
t.check('received pings listed', hasText('Bob, 3 s ago'))
net.echoMs, net.echoRoute, net.replies = nil, nil, {}
uiStub.reset()
setup.draw(s, idle({ net = net }), actions)
t.check('echo pending shown', hasText('Own ping came back: not yet') and hasHeader('Replies (0)'))
net.echoMs, net.pingMs, net.echoRoute = 1, -1, 'local'
uiStub.reset()
setup.draw(s, idle({ net = net }), actions)
t.check('local echo explained, ping unknown', hasText('Own ping came back after 1 ms (your ping to the server: unknown)')
  and hasText(setup.NET_ECHO_TEXT['local']))


-- Release install silenced by a dev install.
uiStub.reset()
setup.drawSilent()
t.check('silent install explained', hasText(setup.SILENT_TEXT))

t.finish()
