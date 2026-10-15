-- Screen positions drivers can snap the flag panel to, and window size comparison.
local M = {}

M.MARGIN = 24 -- px from the screen edge

---@class LayoutPreset
---@field id string
---@field label string
---@field x number @0 left, 0.5 centre, 1 right.
---@field y number @0 top, 0.5 middle, 1 bottom.

---@type LayoutPreset[]
M.PRESETS = {
  { id = 'topLeft', label = 'Top left', x = 0, y = 0 },
  { id = 'topCenter', label = 'Top centre', x = 0.5, y = 0 },
  { id = 'topRight', label = 'Top right', x = 1, y = 0 },
  { id = 'center', label = 'Centre', x = 0.5, y = 0.5 },
  { id = 'bottomLeft', label = 'Bottom left', x = 0, y = 1 },
  { id = 'bottomCenter', label = 'Bottom centre', x = 0.5, y = 1 },
  { id = 'bottomRight', label = 'Bottom right', x = 1, y = 1 },
}

local function axis(anchor, screen, size, margin)
  -- Keeps the margin on the anchored side; centred windows ignore it.
  return margin + (screen - size - 2 * margin) * anchor
end

---Top-left corner that places a window of `size` at `preset` on a `screen`.
---@param preset LayoutPreset
---@param screen vec2
---@param size vec2
---@param margin number? @Default `M.MARGIN`.
---@return vec2
function M.position(preset, screen, size, margin)
  margin = margin or M.MARGIN
  return vec2(axis(preset.x, screen.x, size.x, margin), axis(preset.y, screen.y, size.y, margin))
end

M.SIZE_TOLERANCE = 1 -- px, rounding of window sizes

---Whether two window sizes match within `M.SIZE_TOLERANCE`.
---@param a vec2
---@param b vec2
---@return boolean
function M.sameSize(a, b)
  return math.abs(a.x - b.x) <= M.SIZE_TOLERANCE and math.abs(a.y - b.y) <= M.SIZE_TOLERANCE
end

return M
