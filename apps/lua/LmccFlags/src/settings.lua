-- User preferences, persisted by CSP between sessions.
local M = {}

M.DEFAULTS = {
  glow = true,
  glowThickness = 0.05, -- fraction of the shorter screen side
  glowPulse = true,
  sound = true,
  volume = 0.8,
  showGreen = true, -- show the green flag at race start and when the track clears
}

---@return typeof(M.DEFAULTS)
function M.load()
  return ac.storage(M.DEFAULTS)
end

return M
