-- Setup window: test alerts, place the panel, sound and glow preferences.
local COLORS = require('src/theme').COLORS
local flags = require('src/flags')
local layout = require('src/layout')
local preview = require('src/preview')
local settings = require('src/settings')

local M = {}

M.BUTTONS_PER_ROW = 3
M.SNAP_FAILED_TEXT = 'Open the LMCC Flags panel first, then pick a position.'

-- Cue names in display order.
local CUES = { flags.SOUND.caution, flags.SOUND.blue, flags.SOUND.severe, flags.SOUND.info }
local PREVIEW_OPTIONS = preview.options()

---@class SetupState
---@field previewLabel string? @Label of the alert being previewed.
---@field previewRemaining number @Seconds.
---@field snapFailed boolean

---@class SetupActions
---@field preview fun(option: PreviewOption)
---@field stopPreview fun()
---@field snap fun(preset: LayoutPreset)
---@field testSound fun(cue: string)

---Lays out buttons in rows; calls `onClick` with the item of the clicked button.
---@generic T
---@param items T[]
---@param label fun(item: T): string
---@param onClick fun(item: T)
local function buttonGrid(items, label, onClick)
  for i, item in ipairs(items) do
    if (i - 1) % M.BUTTONS_PER_ROW ~= 0 then ui.sameLine() end
    if ui.button(label(item)) then onClick(item) end
  end
end

---Toggles a boolean setting with a checkbox.
local function toggle(s, key, label)
  if ui.checkbox(label, s[key]) then s[key] = not s[key] end
end

---Percentage slider over a 0..1 setting.
local function percent(s, key, label)
  local value, changed = ui.slider('##' .. key, s[key] * 100, 0, 100, label .. ': %.0f%%')
  if changed then s[key] = value / 100 end
end

---@param cue string
---@return string
function M.cueLabel(cue)
  return cue:sub(1, 1):upper() .. cue:sub(2) .. ' (' .. table.concat(flags.labelsForSound(cue), ', ') .. ')'
end

---@param state SetupState
---@param actions SetupActions
local function drawAlerts(state, actions)
  ui.header('Test alerts')
  buttonGrid(PREVIEW_OPTIONS, function(o) return o.label end, actions.preview)
  if state.previewLabel then
    ui.textColored(string.format('Previewing %s, %d s left', state.previewLabel, math.ceil(state.previewRemaining)), COLORS.yellow)
    ui.sameLine()
    if ui.button('Stop') then actions.stopPreview() end
  end
end

local function drawPosition(state, actions)
  ui.header('Panel position')
  buttonGrid(layout.PRESETS, function(p) return p.label end, actions.snap)
  if state.snapFailed then ui.textColored(M.SNAP_FAILED_TEXT, COLORS.orange) end
end

local function drawSound(s, actions)
  ui.header('Sound')
  toggle(s, 'sound', 'Sound cues')
  percent(s, 'volume', 'Master volume')
  for _, cue in ipairs(CUES) do
    percent(s, settings.cueVolumeKey(cue), M.cueLabel(cue))
    ui.sameLine()
    if ui.button('Test##' .. cue) then actions.testSound(cue) end
  end
end

local function drawDisplay(s)
  ui.header('Display')
  toggle(s, 'glow', 'Screen-edge glow')
  toggle(s, 'glowPulse', 'Pulse urgent flags')
  local value, changed = ui.slider('##glowThickness', s.glowThickness * 100, 1, 15, 'Glow width: %.0f%% of screen')
  if changed then s.glowThickness = value / 100 end
  toggle(s, 'showGreen', 'Show green flag')
  local range, rangeChanged = ui.slider('##blueRange', s.blueRange, 100, 1000, 'Blue flag: list cars within %.0f m')
  if rangeChanged then s.blueRange = range end
end

---@param s table @Loaded settings, edited in place.
---@param state SetupState
---@param actions SetupActions
function M.draw(s, state, actions)
  drawAlerts(state, actions)
  drawPosition(state, actions)
  drawSound(s, actions)
  drawDisplay(s)
end

return M
