-- CSP side of flag sharing: sends the race flag the game raises for this driver over
-- ac.OnlineEvent, for the apps that follow the whole field (LMCC Telemetry, the stream overlays).
-- Only the latest state matters: a change the server rate limit holds back replaces the waiting one.

local M = {}
M.__index = M

local same -- helper, below

M.KEY = 'dazworks.flags.flag'
M.NONE = 0 -- `ac.FlagType.None`: the track is clear
M.NO_CAUSE = -1 -- cause of a flag no car raised

---@class FlagMessage
---@field flag integer @Raw `ac.FlagType`, `M.NONE` when the track is clear.
---@field cause integer @Session ID of the car that caused it, `M.NO_CAUSE` when none.

function M.new()
  local self = setmetatable({
    -- A clear track goes without saying: nothing is sent until a flag is raised
    sent = { flag = M.NONE, cause = M.NO_CAUSE }, ---@type FlagMessage @Last state that left.
    waiting = nil, ---@type FlagMessage? @Newer state held back by the rate limit.
  }, M)
  -- Nothing to do with the others' flags here: each game raises its own
  self.send = ac.OnlineEvent({
    ac.StructItem.key(M.KEY),
    flag = ac.StructItem.byte(),
    cause = ac.StructItem.int32(),
  }, function() end)
  return self
end

---Sends the flag when it or its cause changed. Cheap when nothing changed.
---@param flagType integer @Raw `sim.raceFlagType`.
---@param causeIndex integer @Raw `sim.raceFlagCause`: this game's car index, -1 when none.
function M:announce(flagType, causeIndex)
  local cause = M.causeSession(causeIndex)
  if same(self.waiting or self.sent, flagType, cause) then
    return
  end

  -- Back to what already left before the waiting change could: nothing to send
  if same(self.sent, flagType, cause) then
    self.waiting = nil
    return
  end

  self.waiting = { flag = flagType, cause = cause }
  self:flush()
end

---Sends the waiting state as soon as the server allows.
function M:flush()
  if not self.waiting then
    return
  end

  -- Rate limited: retried next frame
  if self.send(self.waiting) == false then
    return
  end

  self.sent, self.waiting = self.waiting, nil
end

-- ------------------------------------------------------------------------------
-- MARK: HELPERS
-- ------------------------------------------------------------------------------

---Car indexes differ from one game to the next; session IDs are the same everywhere.
---@param causeIndex integer?
---@return integer
function M.causeSession(causeIndex)
  if causeIndex == nil or causeIndex < 0 then
    return M.NO_CAUSE
  end

  local car = ac.getCar(causeIndex)
  return car and car.sessionID or M.NO_CAUSE
end

---@param message FlagMessage
same = function(message, flagType, cause)
  return message.flag == flagType and message.cause == cause
end

return M
