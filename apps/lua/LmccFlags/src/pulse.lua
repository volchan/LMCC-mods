-- Attention pulse shared by the panel and the screen glow, so both blink in sync.
local M = {}

M.PERIOD = 0.8 -- seconds per blink
M.MIN = 0.35 -- lowest opacity during a pulse

---Opacity multiplier at time `now`: constant 1 when pulsing is off.
---@param now number @Seconds.
---@param pulsing boolean
---@return number @M.MIN..1
function M.alpha(now, pulsing)
  if not pulsing then return 1 end
  local wave = 0.5 + 0.5 * math.cos(2 * math.pi * now / M.PERIOD)
  return M.MIN + (1 - M.MIN) * wave
end

return M
