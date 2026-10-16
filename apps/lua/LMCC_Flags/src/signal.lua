-- Turns the raw race flag and penalty of the player car into the list of signals to show,
-- most urgent first.
local flags = require('src/flags')

local M = {}

-- Key of the "no signal" state.
M.NONE = 'none'

---@class Signal
---@field flag FlagSpec
---@field instruction string
---@field parameter integer? @Raw game parameter (laps or seconds), nil when none or unknown.

---Signal for a spec, its instruction filled with the parameter.
---@param flag FlagSpec
---@param parameter integer?
---@return Signal
function M.of(flag, parameter)
  return { flag = flag, instruction = flags.instruction(flag, parameter), parameter = parameter }
end

---Most urgent first.
---@param signals Signal[]
function M.sort(signals)
  table.sort(signals, function(a, b) return a.flag.priority > b.flag.priority end)
end

---@param flagType integer @`ac.FlagType` value.
---@param penaltyType integer @`ac.PenaltyType` value.
---@param penaltyParameter integer?
---@param flagParameter integer? @Fills the flag instruction, e.g. gas cut seconds; nil when unknown.
---@return Signal[]
function M.resolve(flagType, penaltyType, penaltyParameter, flagParameter)
  local result = {}
  local flag = flags.forFlag(flagType)
  if flag then
    result[1] = M.of(flag, flagParameter)
  end
  local penalty = flags.forPenalty(penaltyType)
  -- A black flag penalty and a black race flag are the same signal: show it once.
  if penalty and penalty ~= flag then
    result[#result + 1] = M.of(penalty, penaltyParameter)
  end
  M.sort(result)
  return result
end

---Signals to show, from the driver's own ones (most urgent first). A gas cut replaces the other
---penalties until it is served, then they show again. The gas cut ahead alert goes right below
---the driver's own gas cut and above their other penalties: that car slows down now.
---@param own Signal[]
---@param ahead Signal? @Gas cut ahead alert, nil when none.
---@return Signal[]
function M.display(own, ahead)
  local gasCut = false
  for _, s in ipairs(own) do
    if s.flag == flags.GAS_CUT then gasCut = true end
  end
  local list = {}
  for _, s in ipairs(own) do
    local penalty = s.flag.kind == flags.KIND.penalty and s.flag ~= flags.GAS_CUT
    if ahead and (penalty or s.flag.priority < ahead.flag.priority) then
      list[#list + 1], ahead = ahead, nil
    end
    if not (gasCut and penalty) then list[#list + 1] = s end
    if ahead and s.flag == flags.GAS_CUT then
      list[#list + 1], ahead = ahead, nil
    end
  end
  list[#list + 1] = ahead
  return list
end

---Identifier of the most urgent signal, or `M.NONE` when the track is clear.
---@param signals Signal[]
---@return string
function M.key(signals)
  return signals[1] and signals[1].flag.id or M.NONE
end

return M
