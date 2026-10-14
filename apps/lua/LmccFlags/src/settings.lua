-- User preferences, persisted by CSP between sessions.
local SOUND = require('src/flags').SOUND
local blue = require('src/blue')
local gasCutAhead = require('src/gas_cut_ahead')

local M = {}

M.DEFAULTS = {
  glowThickness = 0.05, -- fraction of the shorter screen side
  glowPulse = true,
  sound = true,
  volume = 0.8, -- master volume, multiplied by the volume of each cue
  showGreen = true, -- show the green flag for a few seconds at race start and when the track clears
  blueRange = blue.DEFAULT_RANGE, -- metres behind the player to look for lapping cars
  gasCutRange = gasCutAhead.DEFAULT_RANGE, -- metres ahead to warn about cars serving a gas cut
  panelLocked = false, -- right click on the panel toggles it
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
