-- Screen-edge strips in the flag colour with the flag name scrolling along them: the top
-- one slides in from the right, the bottom one from the left. Visible in peripheral vision.
local pulse = require('src/pulse')
local draw = require('src/draw')
local strip = require('src/strip')

local M = {}

M.WINDOW_ID = 'lmccFlagsGlow'
M.STRENGTH = 0.85 -- strip background opacity
M.TEXT_SIZE = 0.6 -- flag name height, fraction of the strip height

-- Slide state; replaced in tests.
M.motion = strip.new()

-- Reused every frame to avoid allocations.
local fill = rgbm(0, 0, 0, 0)

---Height in px of each strip.
---@param screen vec2
---@param fraction number @Of the shorter screen side.
---@return number
function M.thickness(screen, fraction)
  return math.min(screen.x, screen.y) * fraction
end

local function drawStrip(flag, now, p1, p2, screenWidth)
  ui.drawRectFilled(p1, p2, fill)
  local height = p2.y - p1.y
  local size = height * M.TEXT_SIZE
  local width = ui.measureDWriteText(flag.label, size).x
  local period = width + size * strip.TEXT_GAP
  ui.pushClipRect(p1, p2)
  local x = strip.scrollOffset(now, period, height * strip.SCROLL_SPEED)
  while x < screenWidth do
    draw.text(flag.label, size, vec2(x, p1.y), vec2(x + width, p2.y), flag.text)
    x = x + period
  end
  ui.popClipRect()
end

---Draws the strips for the most urgent signal, sliding them out once it clears.
---@param signals Signal[]
---@param now number @Seconds, drives the slide, scroll and pulse.
---@param screen vec2 @Screen size in UI pixels.
---@param options {glowThickness: number, glowPulse: boolean}
function M.draw(signals, now, screen, options)
  local top = signals[1]
  local flag, fraction = M.motion:update(top and top.flag, now)
  if not flag then return end
  local c = flag.color
  fill.r, fill.g, fill.b = c.r, c.g, c.b
  fill.mult = M.STRENGTH * pulse.alpha(now, options.glowPulse and flag.pulse)
  local t = M.thickness(screen, options.glowThickness)
  local length = screen.x * fraction
  ui.transparentWindow(M.WINDOW_ID, vec2(0, 0), screen, true, false, function()
    ui.pushDWriteFont(draw.font())
    drawStrip(flag, now, vec2(screen.x - length, 0), vec2(screen.x, t), screen.x)
    drawStrip(flag, now, vec2(0, screen.y - t), vec2(length, screen.y), screen.x)
    ui.popDWriteFont()
  end)
end

return M
