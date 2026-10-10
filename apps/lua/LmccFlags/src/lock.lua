-- Panel lock: a locked panel cannot be moved or resized. Remembers when it was toggled so the
-- view can animate the change. Pure, no drawing.
local M = {}
M.__index = M

M.ANIMATION = 1.2 -- seconds the padlock stays on screen after a toggle
M.CLOSE_TIME = 0.3 -- seconds for the shackle to close or open
M.FADE_TIME = 0.4 -- seconds of fade out at the end of the animation
M.POP_SCALE = 1.3 -- padlock size at the start of the animation, shrinking to 1

---@param locked boolean?
function M.new(locked)
  return setmetatable({ locked = locked == true, changedAt = -math.huge }, M)
end

---@param now number @Seconds.
---@return boolean @New state.
function M:toggle(now)
  self.locked, self.changedAt = not self.locked, now
  return self.locked
end

---@class LockFrame
---@field closed number @Shackle position, 0 open .. 1 closed.
---@field scale number
---@field alpha number

---Padlock animation at `now`, nil once it is over.
---@param now number @Seconds.
---@param out LockFrame @Filled and returned, to avoid allocations.
---@return LockFrame?
function M:frame(now, out)
  local t = now - self.changedAt
  if t >= M.ANIMATION then return nil end
  local k = math.min(1, t / M.CLOSE_TIME)
  local eased = 1 - (1 - k) * (1 - k)
  out.closed = self.locked and eased or 1 - eased
  out.scale = M.POP_SCALE + (1 - M.POP_SCALE) * eased
  out.alpha = math.min(1, (M.ANIMATION - t) / M.FADE_TIME)
  return out
end

return M
