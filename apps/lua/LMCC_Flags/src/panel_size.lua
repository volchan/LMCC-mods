-- Panel size the driver picked with the resize grip. CSP brings a FIXED_SIZE window back to SIZE
-- of manifest.ini, so the size is kept in the settings and applied again every frame. Pure: the
-- settings table is injected.
local M = {}
M.__index = M

M.MIN_SIZE = vec2(260, 65) -- keep in sync with MIN_SIZE of the panel window in manifest.ini

---@param prefs {panelWidth: number, panelHeight: number} @Loaded settings; 0 means never resized.
function M.new(prefs)
  return setmetatable({ prefs = prefs, size = nil, width = nil, height = nil }, M)
end

---Saved size, nil until the driver resizes the panel. Same table while unchanged.
---@return vec2?
function M:target()
  local w, h = self.prefs.panelWidth, self.prefs.panelHeight
  if w <= 0 or h <= 0 then return nil end
  if w ~= self.width or h ~= self.height then
    self.size, self.width, self.height = vec2(w, h), w, h
  end
  return self.size
end

---Grows `current` by the mouse movement, never below the minimum, and saves it.
---@param current vec2
---@param delta vec2
---@return vec2 @New size.
function M:grow(current, delta)
  self.prefs.panelWidth = math.max(M.MIN_SIZE.x, current.x + delta.x)
  self.prefs.panelHeight = math.max(M.MIN_SIZE.y, current.y + delta.y)
  return self:target()
end

return M
