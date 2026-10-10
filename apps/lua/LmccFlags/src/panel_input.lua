-- Mouse on the panel window: right click toggles the lock. Unlocked, a resize grip shows in the
-- bottom-right corner while the mouse is over the panel. Locked, an invisible button covers the
-- panel so dragging it does not move the window.
local M = {}

M.GRIP = 16 -- px
M.MIN_SIZE = vec2(260, 65) -- keep in sync with MIN_SIZE of the panel window in manifest.ini

local gripColor = rgbm(1, 1, 1, 0.5)

---@param locked boolean
---@param actions {toggleLock: fun(), resize: fun(size: vec2)}
---@return boolean @Whether the mouse is over the panel.
function M.update(locked, actions)
  local size = ui.windowSize()
  local hovered = ui.windowHovered()
  if hovered and ui.mouseClicked(ui.MouseButton.Right) then actions.toggleLock() end
  if locked then
    ui.setCursor(vec2(0, 0))
    ui.invisibleButton('##lmccLocked', size)
    return hovered
  end
  local corner = vec2(size.x - M.GRIP, size.y - M.GRIP)
  ui.setCursor(corner)
  ui.invisibleButton('##lmccResize', vec2(M.GRIP, M.GRIP))
  local dragging = ui.itemActive()
  if hovered or dragging then
    ui.drawTriangleFilled(vec2(size.x, corner.y), size, vec2(corner.x, size.y), gripColor)
  end
  if dragging then
    local d = ui.mouseDelta()
    actions.resize(vec2(math.max(M.MIN_SIZE.x, size.x + d.x), math.max(M.MIN_SIZE.y, size.y + d.y)))
  end
  return hovered
end

return M
