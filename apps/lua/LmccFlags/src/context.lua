-- Where the cause of a flag is relative to the player: distance along the track,
-- sector name and driver name. Pure maths on spline positions.
local CAUSE = require('src/flags').CAUSE

local M = {}

---@class FlagCause
---@field mySpline number @Player position along the track, 0..1.
---@field causeSpline number @Position of the car that caused the flag, 0..1.
---@field trackLength number @Metres.
---@field causeName string?
---@field causeSector string?

---Distance in metres from `from` to `to` going forward along the track (wraps over the line).
---@param from number @0..1
---@param to number @0..1
---@param trackLength number
---@return number
function M.forwardDistance(from, to, trackLength)
  return ((to - from) % 1) * trackLength
end

---@param metres number
---@return string
function M.formatDistance(metres)
  if metres < 1000 then
    return string.format('%d m', math.floor(metres / 10 + 0.5) * 10)
  end
  return string.format('%.1f km', metres / 1000)
end

---@param first string
---@param ... string? @Optional extra parts, skipped when nil or empty.
---@return string
local function join(first, ...)
  local parts = { first }
  for i = 1, select('#', ...) do
    local p = select(i, ...)
    if p and p ~= '' then parts[#parts + 1] = p end
  end
  return table.concat(parts, ', ')
end

---One line describing where the cause is, or nil when the flag has no located cause.
---@param flag FlagSpec
---@param cause FlagCause?
---@return string?
function M.describe(flag, cause)
  if not cause or not cause.trackLength or cause.trackLength <= 0 then return nil end
  if flag.causeAt == CAUSE.ahead then
    local d = M.forwardDistance(cause.mySpline, cause.causeSpline, cause.trackLength)
    return join('Incident ' .. M.formatDistance(d) .. ' ahead', cause.causeSector, cause.causeName)
  end
  if flag.causeAt == CAUSE.behind then
    local d = M.forwardDistance(cause.causeSpline, cause.mySpline, cause.trackLength)
    return join('Faster car ' .. M.formatDistance(d) .. ' behind', cause.causeName)
  end
  return nil
end

return M
