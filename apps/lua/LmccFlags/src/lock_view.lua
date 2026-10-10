-- Padlock over the panel: big and animated right after a lock toggle, small in the corner while
-- the mouse is over the panel, hidden otherwise.
local COLORS = require('src/theme').COLORS

local M = {}

M.SIZE = 0.5 -- animated padlock height, fraction of the panel height
M.HINT_SIZE = 0.18 -- corner padlock height, fraction of the panel height
M.HINT_ALPHA = 0.8

-- Reused every frame to avoid allocations.
local frame = {}
local color = rgbm(0, 0, 0, 0)

---Padlock centred on `center`.
---@param center vec2
---@param height number @Px.
---@param closed number @Shackle position, 0 open .. 1 closed.
---@param alpha number
function M.padlock(center, height, closed, alpha)
  local c = COLORS.textLight
  color.r, color.g, color.b, color.mult = c.r, c.g, c.b, alpha
  local half = height / 2
  local bodyTop = center.y + half - height * 0.55
  local width = height * 0.8
  ui.drawRectFilled(vec2(center.x - width / 2, bodyTop), vec2(center.x + width / 2, center.y + half), color, height * 0.08)
  -- Shackle: an arch whose right leg leaves the body as it lifts open.
  local radius, thickness = width * 0.3, height * 0.1
  local lift = (1 - closed) * height * 0.2
  local arcY = bodyTop - height * 0.2 - lift
  ui.pathClear()
  ui.pathArcTo(vec2(center.x, arcY), radius, math.pi, 2 * math.pi, 16)
  ui.pathStroke(color, false, thickness)
  ui.drawLine(vec2(center.x - radius, bodyTop), vec2(center.x - radius, arcY), color, thickness)
  ui.drawLine(vec2(center.x + radius, bodyTop - lift), vec2(center.x + radius, arcY), color, thickness)
end

---@param lock table @From `lock.new()`.
---@param now number @Seconds, same clock as the toggle.
---@param hovered boolean
function M.draw(lock, now, hovered)
  local size = ui.windowSize()
  local f = lock:frame(now, frame)
  if f then
    M.padlock(size / 2, size.y * M.SIZE * f.scale, f.closed, f.alpha)
  elseif hovered then
    local h = size.y * M.HINT_SIZE
    M.padlock(vec2(size.x - h, h), h, lock.locked and 1 or 0, M.HINT_ALPHA)
  end
end

return M
