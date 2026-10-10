-- Hides race flags the game keeps raised after they stopped meaning anything to the driver:
-- - green: kept all session, shown for BRIEF seconds;
-- - checkered: kept to session end, hidden once the player crosses the line or enters the
--   pit lane, after at least BRIEF seconds;
-- - penalty flag (return to pits): hidden once the penalty behind it is served.
-- Every other flag is lowered by the game itself.
local FLAG = require('src/flags').FLAG

local M = {}
M.__index = M

M.BRIEF = 5 -- seconds

function M.new()
  return setmetatable({ flag = nil, since = -math.huge, raisedLap = nil }, M)
end

---Flag to display, `FLAG.None` when the raw one is hidden.
---@param flagType integer @Raw `sim.raceFlagType`.
---@param now number @Seconds.
---@param lap integer @Lap in progress.
---@param inPitlane boolean
---@param showGreen boolean @Setting.
---@param penaltyServed boolean @The game still reports a penalty the app considers served.
---@return integer
function M:effective(flagType, now, lap, inPitlane, showGreen, penaltyServed)
  if flagType ~= self.flag then
    self.flag, self.since, self.raisedLap = flagType, now, lap
  end
  local brief = now - self.since < M.BRIEF
  if flagType == FLAG.Start then
    if not showGreen or not brief then return FLAG.None end
  elseif flagType == FLAG.Finished then
    if not brief and (lap ~= self.raisedLap or inPitlane) then return FLAG.None end
  elseif flagType == FLAG.ReturnToPits then
    if penaltyServed then return FLAG.None end
  end
  return flagType
end

return M
