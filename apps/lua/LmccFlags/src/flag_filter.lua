-- Hides race flags the game keeps raised after they stopped meaning anything to the driver:
-- - green: kept all session, shown for BRIEF seconds;
-- - checkered: kept to session end, hidden once the player crosses the line or enters the
--   pit lane, after at least BRIEF seconds;
-- - gas cut flag (return to pits): the game also raises it alongside every real penalty, so a raise
--   that comes with an active penalty is hidden for as long as it lasts; the panel shows that
--   penalty's exact instruction instead. A new raise after the penalty is served is a gas cut.
-- Every other flag is lowered by the game itself.
local FLAG = require('src/flags').FLAG

local M = {}
M.__index = M

M.BRIEF = 5 -- seconds

function M.new()
  return setmetatable({ flag = nil, since = -math.huge, raisedLap = nil, withPenalty = false }, M)
end

---Flag to display, `FLAG.None` when the raw one is hidden.
---@param flagType integer @Raw `sim.raceFlagType`.
---@param now number @Seconds.
---@param lap integer @Lap in progress.
---@param inPitlane boolean
---@param showGreen boolean @Setting.
---@param penaltyActive boolean @A penalty not yet served is shown.
---@return integer
function M:effective(flagType, now, lap, inPitlane, showGreen, penaltyActive)
  if flagType ~= self.flag then
    self.flag, self.since, self.raisedLap, self.withPenalty = flagType, now, lap, false
  end
  -- Sticky for the whole raise: the penalty may arrive a frame later or be served first.
  self.withPenalty = self.withPenalty or penaltyActive
  local brief = now - self.since < M.BRIEF
  if flagType == FLAG.Start then
    if not showGreen or not brief then return FLAG.None end
  elseif flagType == FLAG.Finished then
    if not brief and (lap ~= self.raisedLap or inPitlane) then return FLAG.None end
  elseif flagType == FLAG.ReturnToPits then
    if self.withPenalty then return FLAG.None end
  end
  return flagType
end

return M
