-- Padlock drawn over the panel after a lock toggle, ported from the CMRT HUD: a white body, a
-- shackle swinging closed in 3D, a small bounce, then a wipe to the right.
local COLORS = require('src/theme').COLORS

local M = {}

-- Padlock geometry in px at scale 1.
local BODY = vec2(50, 40) * 0.85
local HEIGHT_OFFSET = 10 -- body below the centre
local WIDTH = 8 -- shackle thickness
local RADIUS = BODY.x / 2 - WIDTH / 2
local CENTER_OFFSET = 25 -- shackle arc centre above the body centre
local LEG_DEPTH = 10 -- right leg end below the body top
local FULL = BODY + vec2(0, HEIGHT_OFFSET + RADIUS)
local POINTS = 16

-- Reused every frame to avoid allocations.
local frame = {}

---@param lock table @From `lock.new()`.
---@param now number @Seconds, same clock as the toggle.
---@param scale number @Panel scale, 1 at its base size.
function M.draw(lock, now, scale)
  local f = lock:frame(now, frame)
  if not f then return end
  local size = ui.windowSize()
  -- Shrink to fit a small panel, never grow.
  local fit = math.min(1, math.min(FULL.x, size.x) / FULL.x, math.min(FULL.y, size.y) / FULL.y) * scale
  local body, offset, radius, width = BODY * fit, HEIGHT_OFFSET * fit, RADIUS * fit, WIDTH * fit
  local white = COLORS.white
  local center = size / 2 + vec2(0, f.bounce)

  local clip = vec2(f.wipe * size.x * 2, 0)
  ui.pushClipRect(center - size + clip, center + size + clip)
  local bodyCenter = center + vec2(0, offset)
  ui.drawRectFilled(bodyCenter - body / 2, bodyCenter + body / 2, white, 10 * fit, ui.CornerFlags.Bottom)

  -- Rotating the arch around its vertical axis only narrows it: x scales by cos(angle).
  local c = math.cos(f.angle)
  local arcCenter = center + vec2(radius - radius * c, offset - CENTER_OFFSET * fit)
  local loose = center + vec2(radius - 2 * radius * c, 0)
  ui.pathClear()
  ui.pathLineTo(loose)
  for i = 0, POINTS - 1 do
    local a = -math.pi + math.pi * i / (POINTS - 1)
    ui.pathLineTo(arcCenter + vec2(radius * math.cos(a) * c, radius * math.sin(a)))
  end
  ui.pathLineTo(center + vec2(body.x / 2 - width / 2, offset - body.y / 2 + LEG_DEPTH * fit))
  ui.pathStroke(white, false, width)
  ui.drawCircleFilled(loose, width / 2, white)
  ui.popClipRect()
end

return M
