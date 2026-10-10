-- Motion of the screen-edge strips: slide in when a flag appears or changes, slide out
-- when it clears, and scroll the flag name along the strip. Pure, no drawing.
local M = {}
M.__index = M

M.SLIDE_TIME = 0.4 -- seconds to slide fully in or out
M.SCROLL_SPEED = 2.5 -- strip heights per second
M.TEXT_GAP = 1.2 -- space between repeated names, in text heights

---@return number @0..1 eased so the strip decelerates as it lands.
local function easeOut(t)
  return 1 - (1 - t) * (1 - t)
end

function M.new()
  return setmetatable({ flag = nil, on = false, changedAt = -math.huge }, M)
end

---Feeds the most urgent flag of this frame and returns what to draw.
---@param flag FlagSpec? @Nil when no signal is active.
---@param now number @Seconds.
---@return FlagSpec? flag @Flag to draw, nil when fully hidden.
---@return number fraction @Visible share of the strip length, 0..1.
function M:update(flag, now)
  if flag and (flag ~= self.flag or not self.on) then
    self.flag, self.on, self.changedAt = flag, true, now
  elseif not flag and self.on then
    self.on, self.changedAt = false, now
  end
  local eased = easeOut(math.min(1, math.max(0, (now - self.changedAt) / M.SLIDE_TIME)))
  local fraction = self.on and eased or 1 - eased
  if fraction <= 0 then return nil, 0 end
  return self.flag, fraction
end

---Start of the first repeated name, scrolling right to left without jumps.
---@param now number @Seconds.
---@param period number @Name width plus gap, px.
---@param speed number @Px per second.
---@return number @-period..0
function M.scrollOffset(now, period, speed)
  return (-now * speed) % period - period
end

return M
