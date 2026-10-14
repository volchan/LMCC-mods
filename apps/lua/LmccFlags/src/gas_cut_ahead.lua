-- Gas cuts of cars close ahead of the player, from the penalties other drivers share: those cars
-- are about to slow down. Pure.
local context = require('src/context')

local M = {}

M.DEFAULT_RANGE = 300 -- metres ahead of the player
M.MAX_LISTED = 3 -- names shown in the summary line

---@class GasCutAhead
---@field name string
---@field racePosition integer
---@field gap number @Metres ahead of the player.
---@field secondsLeft integer? @Nil when the length is unknown.

---Cars ahead within range that are serving a gas cut, closest first.
---@param me CarInfo? @Nil when the session has no car yet.
---@param cars CarInfo[]
---@param gasCuts SharedGasCut[]
---@param trackLength number @Metres.
---@param range number @Metres.
---@return GasCutAhead[]
function M.nearby(me, cars, gasCuts, trackLength, range)
  local list = {}
  if not me or trackLength <= 0 then return list end
  for _, cut in ipairs(gasCuts) do
    for _, c in ipairs(cars) do
      if c.index == cut.carIndex and c.index ~= me.index and c.running then
        local gap = context.forwardDistance(me.spline, c.spline, trackLength)
        if gap <= range then
          list[#list + 1] = { name = c.name, racePosition = c.racePosition, gap = gap, secondsLeft = cut.secondsLeft }
        end
      end
    end
  end
  table.sort(list, function(a, b) return a.gap < b.gap end)
  return list
end

---One line for the panel and history, nil when no car ahead is serving a gas cut.
---@param list GasCutAhead[]
---@return string?
function M.describe(list)
  if #list == 0 then return nil end
  return context.joinCapped(list, M.MAX_LISTED, '; ', function(c)
    local left = c.secondsLeft and string.format(', lift %ds', c.secondsLeft) or ''
    return string.format('P%d %s %s%s', c.racePosition, c.name, context.formatDistance(c.gap), left)
  end)
end

return M
