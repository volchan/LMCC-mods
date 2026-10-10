-- Turns the raw race flag and penalty of the player car into the list of signals to show,
-- most urgent first.
local flags = require('src/flags')

local M = {}

-- Key of the "no signal" state.
M.NONE = 'none'

---@class Signal
---@field flag FlagSpec
---@field instruction string

---@param flagType integer @`ac.FlagType` value.
---@param penaltyType integer @`ac.PenaltyType` value.
---@param penaltyParameter integer?
---@return Signal[]
function M.resolve(flagType, penaltyType, penaltyParameter)
  local result = {}
  local flag = flags.forFlag(flagType)
  if flag then
    result[1] = { flag = flag, instruction = flags.instruction(flag) }
  end
  local penalty = flags.forPenalty(penaltyType)
  -- A black flag penalty and a black race flag are the same signal: show it once.
  if penalty and penalty ~= flag then
    result[#result + 1] = { flag = penalty, instruction = flags.instruction(penalty, penaltyParameter) }
  end
  table.sort(result, function(a, b) return a.flag.priority > b.flag.priority end)
  return result
end

---Identifier of the most urgent signal, or `M.NONE` when the track is clear.
---@param signals Signal[]
---@return string
function M.key(signals)
  return signals[1] and signals[1].flag.id or M.NONE
end


return M
