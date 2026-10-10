-- Moves, opens and resizes one of the app's own windows, found by its title from manifest.ini.
local layout = require('src/layout')

local M = {}

---@param title string
---@return ac.AppWindowAccessor?
function M.find(title)
  for _, w in ipairs(ac.getAppWindows()) do
    if w.title == title then return ac.accessAppWindow(w.name) end
  end
  return nil
end

---Opens a window that was closed from the apps bar.
---@param title string
---@return boolean @False when the window was not found.
function M.show(title)
  local window = M.find(title)
  if not window then return false end
  window:setVisible(true)
  return true
end

---@param title string
---@param size vec2
---@return boolean @False when the window was not found.
function M.resize(title, size)
  local window = M.find(title)
  if not window then return false end
  window:resize(size)
  return true
end

---Snaps a window to a layout preset and opens it, since moving a hidden window shows nothing.
---@param title string
---@param preset LayoutPreset
---@param screen vec2
---@return boolean @False when the window was not found.
function M.snap(title, preset, screen)
  local window = M.find(title)
  if not window then return false end
  window:setVisible(true)
  window:move(layout.position(preset, screen, window:size()))
  return true
end

return M
