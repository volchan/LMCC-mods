-- Decides when the player's penalty is served. The game can keep reporting a penalty after
-- it was served, so the app clears it itself:
-- - pit penalties once the car has been in the pit lane and left it again;
-- - timed penalties once their seconds reach 0.
local PENALTY = require('src/flags').PENALTY

local M = {}
M.__index = M

-- Served by going through the pit lane.
M.PIT = { [PENALTY.MandatoryPits] = true, [PENALTY.TeleportToPits] = true }
-- Parameter counts seconds; 0 means nothing left to serve.
M.TIMED = { [PENALTY.TeleportToPits] = true, [PENALTY.SlowDown] = true }

function M.new()
  return setmetatable({ type = PENALTY.None, parameter = 0, visitedPit = false, served = false }, M)
end

---Penalty to display, `PENALTY.None` once the raw one is served.
---@param penaltyType integer @Raw `car.currentPenaltyType`.
---@param parameter integer
---@param inPitlane boolean
---@return integer
function M:effective(penaltyType, parameter, inPitlane)
  -- A different type or a bigger parameter is a new penalty.
  if penaltyType ~= self.type or parameter > self.parameter then
    self.visitedPit, self.served = false, false
  end
  self.type, self.parameter = penaltyType, parameter
  if M.PIT[penaltyType] then
    if inPitlane then
      self.visitedPit = true
    elseif self.visitedPit then
      self.served = true
    end
  end
  if self.served or (M.TIMED[penaltyType] and parameter <= 0) then return PENALTY.None end
  return penaltyType
end

return M
