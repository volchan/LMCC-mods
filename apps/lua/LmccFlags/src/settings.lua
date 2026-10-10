-- User preferences, persisted by CSP between sessions.
local SOUND = require('src/flags').SOUND

local M = {}

M.DEFAULTS = {
  glow = true,
  glowThickness = 0.05, -- fraction of the shorter screen side
  glowPulse = true,
  sound = true,
  volume = 0.8, -- master volume, multiplied by the volume of each cue
  showGreen = true, -- show the green flag at race start and when the track clears
}

---Settings key holding the volume of one cue, e.g. `volume_caution`.
---@param cue string @One of `flags.SOUND`.
---@return string
function M.cueVolumeKey(cue)
  return 'volume_' .. cue
end

for _, cue in pairs(SOUND) do
  M.DEFAULTS[M.cueVolumeKey(cue)] = 1
end

---@return typeof(M.DEFAULTS)
function M.load()
  return ac.storage(M.DEFAULTS)
end

---Volume to play a cue at: 0 when sound is off, otherwise master times cue volume.
---@param s table @Loaded settings.
---@param cue string
---@return number
function M.volumeFor(s, cue)
  if not s.sound then return 0 end
  return s.volume * (s[M.cueVolumeKey(cue)] or 1)
end

return M
