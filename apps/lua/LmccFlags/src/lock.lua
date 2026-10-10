-- Panel lock: a locked panel cannot be moved or resized. Remembers when it was toggled and gives
-- the padlock animation timeline (same motion as the CMRT HUD lock). Pure, no drawing.
local M = {}
M.__index = M

M.ANIMATION = 1 -- seconds the padlock stays on screen after a toggle
M.SHACKLE_TIME = 0.2 -- seconds for the shackle to swing closed (or open, played backwards)
M.BOUNCE = 10 -- px the padlock dips while the shackle swings
M.WIPE_START, M.WIPE_END = 0.3, 0.8 -- seconds: the padlock is wiped away to the right

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

local function clamp01(x)
  return math.min(1, math.max(0, x))
end

---@class LockFrame
---@field angle number @Shackle swing around its vertical axis, pi open .. 0 closed.
---@field bounce number @Px down.
---@field wipe number @0 fully visible .. 1 wiped away.

---Padlock animation at `now`, nil once it is over.
---@param now number @Seconds.
---@param out LockFrame @Filled and returned, to avoid allocations.
---@return LockFrame?
function M:frame(now, out)
  local t = now - self.changedAt
  if t > M.ANIMATION then return nil end
  local swing = self.locked and t or M.SHACKLE_TIME - t
  local k = clamp01(swing / M.SHACKLE_TIME)
  out.angle = math.pi * (1 - k)
  out.bounce = M.BOUNCE * (clamp01(k / 0.5) - clamp01((k - 0.5) / 0.5))
  out.wipe = clamp01((t - M.WIPE_START) / (M.WIPE_END - M.WIPE_START))
  return out
end

return M
