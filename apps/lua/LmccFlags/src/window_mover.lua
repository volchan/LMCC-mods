-- Moves one of the app's own windows, found by its title from manifest.ini.
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

---Snaps a window to a layout preset.
---@param title string
---@param preset LayoutPreset
---@param screen vec2
---@return boolean @False when the window was not found (never opened).
function M.snap(title, preset, screen)
  local window = M.find(title)
  if not window then return false end
  window:move(layout.position(preset, screen, window:size()))
  return true
end

return M
