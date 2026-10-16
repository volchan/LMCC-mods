-- Setup window, in tabs: test alerts, place and lock the panel, display and sound preferences,
-- online messaging test.
local COLORS = require('src/theme').COLORS
local flags = require('src/flags')
local layout = require('src/layout')
local preview = require('src/preview')
local settings = require('src/settings')

local M = {}

M.GAP = 4 -- px between grid buttons
M.ALERT_COLUMNS = 3
M.CUE_NAME_WIDTH = 70 -- px, column of cue names in the sound tab
M.TEST_WIDTH = 50 -- px, sound test buttons
M.SHOW_PANEL_LABEL = 'Show panel'
M.LOCK_LABEL = 'Lock panel (or right click it)'
M.TEST_HINT = string.format('Click an alert to show it for %d s with its sound. Click more during the test to '
  .. 'combine them as in a race; Stop clears them. Tests are not saved in the history.', preview.DURATION)
M.NO_GAME_DATA_TEXT = 'Waiting for the game...'
M.PANEL_MISSING_TEXT = 'LMCC Flags panel not found: open it once from the apps bar.'
M.NET_PING_LABEL = 'Send test ping'
M.NET_PENALTY_LABEL = 'Send test penalty'
M.NET_PENALTY_HELP = 'Sends a test penalty (code 0) as a real one would be: other LMCC Flags ignore it, '
  .. 'LMCC Telemetry counts it as heard and forwards it to the stats site.'
M.SILENT_TEXT = 'A dev install of LMCC Flags is running: this one stays silent until it stops.'
M.NET_HELP = 'Checks that LMCC Flags clients can message each other on this server. Every other driver '
  .. 'running this version answers the ping; their replies prove alerts could be shared between drivers.'
M.NET_OFFLINE_TEXT = 'Offline session: join a server to test with other drivers.'
M.NET_DIRECT_TEXT = 'Server: custom, direct messaging between clients.'
M.NET_CHAT_TEXT = 'Server: original AC, messages travel as hidden chat (max one per 200 ms).'
M.NET_NONE_TEXT = 'None yet'
M.NET_ECHO_TEXT = {
  server = 'It made the trip to the server and back: the server relays messages.',
  ['local'] = 'It came back instantly, as a local copy: the server is not proven.',
  unsure = 'Cannot tell: with this ping a local copy arriving a frame later looks the same. Test with a second driver.',
}

-- Cue names in display order.
local CUES = { flags.SOUND.caution, flags.SOUND.blue, flags.SOUND.severe, flags.SOUND.info }

-- Test buttons grouped by how drivers meet the alert, each group most urgent first.
M.GROUPS = {
  { kind = flags.KIND.race, title = 'Race flags' },
  { kind = flags.KIND.penalty, title = 'Penalties' },
  { kind = flags.KIND.others, title = 'Other drivers (shared by their LMCC Flags)' },
  { kind = flags.KIND.server, title = 'Server script flags', collapsed = true },
}
for _, group in ipairs(M.GROUPS) do
  group.options = {}
  for _, option in ipairs(preview.options()) do
    if option.flag.kind == group.kind then group.options[#group.options + 1] = option end
  end
end

-- Presets placed like on the screen: GRID[row][column], nil for empty cells.
local GRID = { {}, {}, {} }
for _, preset in ipairs(layout.PRESETS) do
  GRID[preset.y * 2 + 1][preset.x * 2 + 1] = preset
end

---@class SetupState
---@field previewLabel string? @Label of the alert being previewed.
---@field previewRemaining number @Seconds.
---@field panelMissing boolean
---@field locked boolean
---@field raw Snapshot? @Last raw game values, to check what the game really reports.
---@field net NetStatus? @Online messaging test results.

---@class SetupActions
---@field preview fun(option: PreviewOption)
---@field stopPreview fun()
---@field showPanel fun()
---@field toggleLock fun()
---@field snap fun(preset: LayoutPreset)
---@field testSound fun(cue: string)
---@field netPing fun()
---@field testPenalty fun()

---Width of one cell when `columns` cells share the line.
local function cellWidth(columns)
  return (ui.availableSpaceX() - M.GAP * (columns - 1)) / columns
end

---Toggles a boolean setting with a checkbox.
local function toggle(s, key, label)
  if ui.checkbox(label, s[key]) then s[key] = not s[key] end
end

---Percentage slider over a 0..1 setting, full width unless `width` is given.
local function percent(s, key, label, width)
  ui.setNextItemWidth(width or ui.availableSpaceX())
  local value, changed = ui.slider('##' .. key, s[key] * 100, 0, 100, label .. ': %.0f%%')
  if changed then s[key] = value / 100 end
end

-- Hover colours, one per flag colour, created once.
local hoverColors = {}
local function hoverColor(c)
  local h = hoverColors[c]
  if not h then
    h = rgbm(math.min(1, c.r * 1.2 + 0.08), math.min(1, c.g * 1.2 + 0.08), math.min(1, c.b * 1.2 + 0.08), c.mult)
    hoverColors[c] = h
  end
  return h
end

---Button painted in the colours of its flag.
---@param option PreviewOption
---@return boolean
local function flagButton(option, width)
  local f = option.flag
  ui.pushStyleColor(ui.StyleColor.Button, f.color)
  ui.pushStyleColor(ui.StyleColor.ButtonHovered, hoverColor(f.color))
  ui.pushStyleColor(ui.StyleColor.ButtonActive, f.color)
  ui.pushStyleColor(ui.StyleColor.Text, f.text)
  local clicked = ui.button(option.label, vec2(width, 0))
  ui.popStyleColor(4)
  return clicked
end

local function drawAlertGroup(group, actions)
  local width = cellWidth(M.ALERT_COLUMNS)
  for i, option in ipairs(group.options) do
    if (i - 1) % M.ALERT_COLUMNS ~= 0 then ui.sameLine(0, M.GAP) end
    if flagButton(option, width) then actions.preview(option) end
  end
end

-- Raw values as the game reports them, so a wrong alert can be traced to its source.
---@param raw Snapshot?
local function drawGameData(raw)
  if not raw or raw.flagType == nil then
    ui.text(M.NO_GAME_DATA_TEXT)
    return
  end
  ui.text(string.format('Flag: %s (%d), cause car %d', flags.nameOf(flags.FLAG, raw.flagType), raw.flagType, raw.flagCause))
  ui.text(string.format('Penalty: %s (%d), parameter %d', flags.nameOf(flags.PENALTY, raw.penaltyType),
    raw.penaltyType, raw.penaltyParameter))
  ui.text(string.format('Lap: %d, in pit lane: %s', raw.lap or 0, raw.inPitlane and 'yes' or 'no'))
  ui.text(string.format('Penalty time: %.1f s', raw.penaltyTime or 0))
end

---@param state SetupState
---@param actions SetupActions
local function drawAlerts(state, actions)
  ui.textWrapped(M.TEST_HINT)
  for _, group in ipairs(M.GROUPS) do
    if group.collapsed then
      ui.treeNode(group.title, ui.TreeNodeFlags.None, function() drawAlertGroup(group, actions) end)
    else
      ui.header(group.title)
      drawAlertGroup(group, actions)
    end
  end
  if state.previewLabel then
    ui.alignTextToFramePadding()
    ui.textColored(string.format('Showing %s, %d s left', state.previewLabel, math.ceil(state.previewRemaining)), COLORS.yellow)
    ui.sameLine()
    if ui.button('Stop') then actions.stopPreview() end
  end
  ui.treeNode('Game data (what the game reports)', ui.TreeNodeFlags.None, function() drawGameData(state.raw) end)
end

local function drawPanel(state, actions)
  if ui.button(M.SHOW_PANEL_LABEL) then actions.showPanel() end
  ui.sameLine(0, 12)
  if ui.checkbox(M.LOCK_LABEL, state.locked) then actions.toggleLock() end
  if state.panelMissing then ui.textColored(M.PANEL_MISSING_TEXT, COLORS.orange) end
  ui.header('Position on screen')
  local width = cellWidth(3)
  for row = 1, 3 do
    for column = 1, 3 do
      if column > 1 then ui.sameLine(0, M.GAP) end
      local preset = GRID[row][column]
      if preset then
        if ui.button(preset.label, vec2(width, 0)) then actions.snap(preset) end
      else
        ui.dummy(vec2(width, ui.frameHeight()))
      end
    end
  end
end

local function drawDisplay(s)
  ui.header('Alerts')
  toggle(s, 'glowPulse', 'Pulse urgent flags')
  toggle(s, 'showGreen', 'Show the green flag (5 s)')
  ui.header('Screen strips')
  ui.setNextItemWidth(ui.availableSpaceX())
  local value, changed = ui.slider('##glowThickness', s.glowThickness * 100, 1, 15, 'Strip height: %.0f%% of screen')
  if changed then s.glowThickness = value / 100 end
  ui.header('Blue flag')
  ui.setNextItemWidth(ui.availableSpaceX())
  local range, rangeChanged = ui.slider('##blueRange', s.blueRange, 100, 1000, 'List cars within %.0f m behind')
  if rangeChanged then s.blueRange = range end
  ui.header('Gas cut ahead')
  ui.setNextItemWidth(ui.availableSpaceX())
  local cutRange, cutChanged = ui.slider('##gasCutRange', s.gasCutRange, 100, 1000, 'Warn about cars within %.0f m ahead')
  if cutChanged then s.gasCutRange = cutRange end
end

---@param cue string
---@return string @Short name, e.g. `Caution`.
function M.cueName(cue)
  return cue:sub(1, 1):upper() .. cue:sub(2)
end

---@param cue string
---@return string @Alerts using the cue, for its tooltip.
function M.cueFlags(cue)
  return table.concat(flags.labelsForSound(cue), ', ')
end

local function drawSound(s, actions)
  toggle(s, 'sound', 'Sound cues')
  percent(s, 'volume', 'Master volume')
  ui.header('Cues (hover a name to see its alerts)')
  for _, cue in ipairs(CUES) do
    ui.alignTextToFramePadding()
    ui.text(M.cueName(cue))
    if ui.itemHovered() then ui.setTooltip(M.cueFlags(cue)) end
    ui.sameLine(M.CUE_NAME_WIDTH)
    percent(s, settings.cueVolumeKey(cue), 'Volume', ui.availableSpaceX() - M.TEST_WIDTH - M.GAP)
    ui.sameLine(0, M.GAP)
    if ui.button('Test##' .. cue, vec2(M.TEST_WIDTH, 0)) then actions.testSound(cue) end
  end
end

---Lines of a result list, or a placeholder when empty.
local function drawList(items, format)
  if #items == 0 then ui.textDisabled(M.NET_NONE_TEXT) end
  for _, item in ipairs(items) do ui.text(format(item)) end
end

---@param net NetStatus
local function drawNetwork(net, actions)
  ui.textWrapped(M.NET_HELP)
  if not net.online then ui.textColored(M.NET_OFFLINE_TEXT, COLORS.orange) end
  ui.text(net.direct and M.NET_DIRECT_TEXT or M.NET_CHAT_TEXT)
  if ui.button(M.NET_PING_LABEL) then actions.netPing() end
  ui.textWrapped(M.NET_PENALTY_HELP)
  if ui.button(M.NET_PENALTY_LABEL) then actions.testPenalty() end
  if net.pinged then
    if net.echoMs then
      ui.text(string.format('Own ping came back after %d ms (your ping to the server: %s)', net.echoMs,
        net.pingMs >= 0 and net.pingMs .. ' ms' or 'unknown'))
      ui.textWrapped(M.NET_ECHO_TEXT[net.echoRoute])
    else
      ui.text('Own ping came back: not yet')
    end
    ui.header(string.format('Replies (%d)', #net.replies))
    drawList(net.replies, function(r) return string.format('%s: %d ms', r.name, r.ms) end)
  end
  ui.header('Pings received from other drivers')
  drawList(net.pingsFrom, function(p) return string.format('%s, %d s ago', p.name, p.ago) end)
end

---Setup content of a release install silenced by a running dev install.
function M.drawSilent()
  ui.textWrapped(M.SILENT_TEXT)
end

---@param s table @Loaded settings, edited in place.
---@param state SetupState
---@param actions SetupActions
function M.draw(s, state, actions)
  ui.tabBar('lmccSetup', function()
    ui.tabItem('Alerts', function() drawAlerts(state, actions) end)
    ui.tabItem('Panel', function() drawPanel(state, actions) end)
    ui.tabItem('Display', function() drawDisplay(s) end)
    ui.tabItem('Sound', function() drawSound(s, actions) end)
    if state.net then ui.tabItem('Network', function() drawNetwork(state.net, actions) end) end
  end)
end

return M
