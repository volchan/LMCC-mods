-- Blue flag: which cars the player has to let pass. A car counts when it is behind on
-- track within range and ahead in the race order, so it is about to lap the player.
local context = require('src/context')

local M = {}

M.DEFAULT_RANGE = 400 -- metres behind the player
M.MAX_LISTED = 3 -- names shown in the summary line

---@class CarInfo
---@field index integer
---@field name string
---@field spline number @0..1
---@field racePosition integer @1 for the leader.
---@field running boolean @Connected, active and out of the pit lane.

---@class LappingCar
---@field name string
---@field racePosition integer
---@field gap number @Metres behind the player.

---Cars to let pass, closest first.
---@param me CarInfo? @Nil when the session has no car yet.
---@param cars CarInfo[]
---@param trackLength number @Metres.
---@param range number @Metres.
---@return LappingCar[]
function M.approaching(me, cars, trackLength, range)
  local list = {}
  if not me or trackLength <= 0 then return list end
  for _, c in ipairs(cars) do
    if c.index ~= me.index and c.running and c.racePosition < me.racePosition then
      local gap = context.forwardDistance(c.spline, me.spline, trackLength)
      if gap <= range then
        list[#list + 1] = { name = c.name, racePosition = c.racePosition, gap = gap }
      end
    end
  end
  table.sort(list, function(a, b) return a.gap < b.gap end)
  return list
end

---One line for the panel and history, nil when no car has to be let through.
---@param list LappingCar[]
---@return string?
function M.describe(list)
  if #list == 0 then return nil end
  local names = {}
  for i = 1, math.min(#list, M.MAX_LISTED) do
    local c = list[i]
    names[i] = string.format('P%d %s %s', c.racePosition, c.name, context.formatDistance(c.gap))
  end
  local more = #list > M.MAX_LISTED and string.format(' +%d more', #list - M.MAX_LISTED) or ''
  return string.format('Let %d car%s pass: %s%s', #list, #list == 1 and '' or 's', table.concat(names, ', '), more)
end

return M
