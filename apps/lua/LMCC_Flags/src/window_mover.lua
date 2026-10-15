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

-- Accessors found by `M.access`, by title: the size is checked every frame and listing windows allocates.
local cache = {}

---Like `M.find`, but keeps the accessor while it stays valid.
---@param title string
---@return ac.AppWindowAccessor?
function M.access(title)
  local window = cache[title]
  if window and window:valid() then return window end
  window = M.find(title)
  cache[title] = window
  return window
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
  local window = M.access(title)
  if not window then return false end
  window:resize(size)
  return true
end

---@param title string
---@return vec2? @Nil when the window was not found.
function M.size(title)
  local window = M.access(title)
  return window and window:size() or nil
end

---Resizes the window back to `size` when something else changed it.
---@param title string
---@param size vec2
function M.keepSize(title, size)
  local window = M.access(title)
  if window and not layout.sameSize(window:size(), size) then window:resize(size) end
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
