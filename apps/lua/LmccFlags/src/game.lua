-- The only module that reads race state from the game. Fills reusable tables so the
-- per-frame path does not allocate.
local M = {}

---@class Snapshot
---@field now number @Seconds since AC start.
---@field flagType integer
---@field flagCause integer @0-based car index, or -1.
---@field penaltyType integer
---@field penaltyParameter integer
---@field lap integer @Lap in progress, 1-based.
---@field sessionTime number? @Seconds since session start, nil when unknown.

---@param out Snapshot
---@return Snapshot?
function M.read(out)
  local sim, car = ac.getSim(), ac.getCar(0)
  if not sim or not car then return nil end
  out.now = sim.time / 1000
  out.flagType = sim.raceFlagType
  out.flagCause = sim.raceFlagCause
  out.penaltyType = car.currentPenaltyType
  out.penaltyParameter = car.currentPenaltyParameter
  out.lap = car.lapCount + 1
  local session = ac.getSession(sim.currentSessionIndex)
  out.sessionTime = session and (sim.time - session.startTime) / 1000 or nil
  return out
end

---Positions and name of the car that caused the current flag.
---@param causeIndex integer
---@param out FlagCause
---@return FlagCause?
function M.cause(causeIndex, out)
  if causeIndex < 0 then return nil end
  local sim, car, other = ac.getSim(), ac.getCar(0), ac.getCar(causeIndex)
  if not car or not other then return nil end
  out.mySpline = car.splinePosition
  out.causeSpline = other.splinePosition
  out.trackLength = sim.trackLengthM
  out.causeName = causeIndex ~= car.index and ac.getDriverName(causeIndex) or nil
  out.causeSector = ac.getTrackSectorName(other.splinePosition)
  return out
end

return M
