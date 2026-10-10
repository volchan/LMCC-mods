-- Coloured glow along the four screen edges, visible in peripheral vision.
local pulse = require('src/pulse')

local M = {}

M.WINDOW_ID = 'lmccFlagsGlow'
M.STRENGTH = 0.85 -- opacity at the very edge

-- Reused every frame to avoid allocations: same colour, opaque edge and transparent inner side.
local edge, clear = rgbm(0, 0, 0, 0), rgbm(0, 0, 0, 0)

local function setColors(color, alpha)
  edge.r, edge.g, edge.b, edge.mult = color.r, color.g, color.b, alpha
  clear.r, clear.g, clear.b, clear.mult = color.r, color.g, color.b, 0
end

---Thickness in px of the glow band.
---@param screen vec2
---@param fraction number @Of the shorter screen side.
---@return number
function M.thickness(screen, fraction)
  return math.min(screen.x, screen.y) * fraction
end

local function drawEdges(screen, t)
  local w, h = screen.x, screen.y
  -- Corner colours: top-left, top-right, bottom-right, bottom-left.
  ui.drawRectFilledMultiColor(vec2(0, 0), vec2(w, t), edge, edge, clear, clear)
  ui.drawRectFilledMultiColor(vec2(0, h - t), vec2(w, h), clear, clear, edge, edge)
  ui.drawRectFilledMultiColor(vec2(0, 0), vec2(t, h), edge, clear, clear, edge)
  ui.drawRectFilledMultiColor(vec2(w - t, 0), vec2(w, h), clear, edge, edge, clear)
end

---Draws the glow for the most urgent signal, if any.
---@param signals Signal[]
---@param now number @Seconds, drives the pulse.
---@param screen vec2 @Screen size in UI pixels.
---@param options {glowThickness: number, glowPulse: boolean}
function M.draw(signals, now, screen, options)
  local top = signals[1]
  if not top then return end
  local flag = top.flag
  setColors(flag.color, M.STRENGTH * pulse.alpha(now, options.glowPulse and flag.pulse))
  local t = M.thickness(screen, options.glowThickness)
  ui.transparentWindow(M.WINDOW_ID, vec2(0, 0), screen, true, false, function()
    drawEdges(screen, t)
  end)
end

return M
