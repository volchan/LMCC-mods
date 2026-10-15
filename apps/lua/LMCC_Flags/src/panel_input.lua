-- Mouse on the panel window: right click toggles the lock. Unlocked, a resize grip shows in the
-- bottom-right corner while the mouse is over the panel. Locked, an invisible button covers the
-- panel so dragging it does not move the window.
local M = {}

M.GRIP = 16 -- px

local gripColor = rgbm(1, 1, 1, 0.5)

---@param locked boolean
---@param actions {toggleLock: fun(), resize: fun(delta: vec2)} @`resize` gets the mouse movement while the grip is dragged.
function M.update(locked, actions)
  local size = ui.windowSize()
  local hovered = ui.windowHovered()
  if hovered and ui.mouseClicked(ui.MouseButton.Right) then actions.toggleLock() end
  if locked then
    ui.setCursor(vec2(0, 0))
    ui.invisibleButton('##lmccLocked', size)
    return
  end
  local corner = vec2(size.x - M.GRIP, size.y - M.GRIP)
  ui.setCursor(corner)
  ui.invisibleButton('##lmccResize', vec2(M.GRIP, M.GRIP))
  local dragging = ui.itemActive()
  if hovered or dragging then
    ui.drawTriangleFilled(vec2(size.x, corner.y), size, vec2(corner.x, size.y), gripColor)
  end
  if dragging then
    actions.resize(ui.mouseDelta())
  end
end

return M
