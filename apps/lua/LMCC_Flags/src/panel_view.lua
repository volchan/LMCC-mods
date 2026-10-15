-- Big HUD panel: flag chip on the left, flag name, instruction and location on the right.
local COLORS = require('src/theme').COLORS
local draw = require('src/draw')
local pulse = require('src/pulse')

local M = {}

-- Layout in px at BASE_WIDTH x BASE_HEIGHT; everything scales by the tighter side so
-- all lines stay inside the window whatever its aspect.
M.BASE_WIDTH = 520
M.BASE_HEIGHT = 130
local PAD = 12
local ROUNDING = 8
local LABEL_SIZE = 40
local INSTRUCTION_SIZE = 20
local SMALL_SIZE = 15
M.IDLE_TEXT = 'NO FLAG'

---@class PanelModel
---@field label string
---@field instruction string
---@field detail string?
---@field extra string? @Second active signal, with the count of the ones below it.

---Text content of the panel, nil when no signal is active.
---@param signals Signal[]
---@param detail string?
---@return PanelModel?
function M.model(signals, detail)
  local top = signals[1]
  if not top then return nil end
  local second = signals[2]
  local more = #signals > 2 and string.format(' (+%d)', #signals - 2) or ''
  return {
    label = top.flag.label,
    instruction = top.instruction,
    detail = detail,
    extra = second and ('+ ' .. second.flag.label .. ': ' .. second.instruction .. more) or nil,
  }
end

-- No background without a flag: only a faint label so the panel can still be found and moved.
---Panel scale for a window size: 1 at the base size, by the tighter side.
---@param size vec2
---@return number
function M.scale(size)
  return math.min(size.x / M.BASE_WIDTH, size.y / M.BASE_HEIGHT)
end

local function drawIdle(width, height, s)
  draw.text(M.IDLE_TEXT, SMALL_SIZE * s, vec2(0, 0), vec2(width, height), COLORS.dim, ui.Alignment.Center)
end

---@param signals Signal[]
---@param detail string?
---@param now number @Seconds, drives the pulse.
function M.draw(signals, detail, now)
  local size = ui.windowSize()
  local width, height = size.x, size.y
  local s = M.scale(size)
  ui.pushDWriteFont(draw.font())

  local model = M.model(signals, detail)
  if not model then
    drawIdle(width, height, s)
    ui.popDWriteFont()
    return
  end

  local flag = signals[1].flag
  local pad = PAD * s
  ui.drawRectFilled(vec2(0, 0), vec2(width, height), COLORS.panel, ROUNDING * s)

  -- Chip: square flag, pulsing when the flag asks for attention.
  local chip = height - 2 * pad
  local c1, c2 = vec2(pad, pad), vec2(pad + chip, pad + chip)
  draw.flag(flag, c1, c2)
  draw.dim(c1, c2, 1 - pulse.alpha(now, flag.pulse))

  -- Text column.
  local x1, x2 = pad * 2 + chip, width - pad
  local y = pad
  local function line(text, fontSize, color)
    local h = fontSize * 1.25
    draw.text(text, fontSize, vec2(x1, y), vec2(x2, y + h), color)
    y = y + h
  end
  line(model.label, LABEL_SIZE * s, COLORS.textLight)
  line(model.instruction, INSTRUCTION_SIZE * s, COLORS.textLight)
  if model.detail then line(model.detail, SMALL_SIZE * s, COLORS.dim) end
  if model.extra then line(model.extra, SMALL_SIZE * s, COLORS.orange) end

  ui.popDWriteFont()
end

return M
