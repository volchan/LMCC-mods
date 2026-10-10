-- Plays the sound cue of a flag. Cue files live in sounds/<name>.wav next to the script.
local M = {}

local current = nil ---@type ac.AudioEvent?

---@param name string @One of `flags.SOUND`.
---@return string
function M.path(name)
  return ac.dirname() .. '/sounds/' .. name .. '.wav'
end

---Starts a cue, stopping the previous one so cues never overlap.
---@param name string
---@param volume number @0..1
function M.play(name, volume)
  -- A non-looping file event is only valid for one play: dispose it and create a new one.
  if current then current:dispose() end
  current = ac.AudioEvent.fromFile({ filename = M.path(name), use3D = false, loop = false }, false)
  current.volume = volume
  current:start()
end

return M
