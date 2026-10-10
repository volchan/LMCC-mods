-- Test mode: shows any flag or penalty for a few seconds so drivers can check how alerts
-- look and sound before a race. Preview signals are never written to the history.
local flags = require('src/flags')
local signal = require('src/signal')

local M = {}
M.__index = M

M.DURATION = 6 -- seconds
M.PENALTY_PARAMETER = 3 -- shown in penalty instructions, e.g. "Pit within 3 laps"

---@class PreviewOption
---@field label string
---@field flagType integer
---@field penaltyType integer
---@field priority integer

---Every distinct flag and penalty, most urgent first.
---@return PreviewOption[]
function M.options()
  local list, seen = {}, {}
  local function add(spec, flagType, penaltyType)
    if seen[spec] then return end
    seen[spec] = true
    list[#list + 1] = { label = spec.label, flagType = flagType, penaltyType = penaltyType, priority = spec.priority }
  end
  for _, flagType in pairs(flags.FLAG) do
    local spec = flags.forFlag(flagType)
    if spec then add(spec, flagType, flags.PENALTY.None) end
  end
  for _, penaltyType in pairs(flags.PENALTY) do
    local spec = flags.forPenalty(penaltyType)
    if spec then add(spec, flags.FLAG.None, penaltyType) end
  end
  table.sort(list, function(a, b)
    if a.priority ~= b.priority then return a.priority > b.priority end
    return a.label < b.label
  end)
  return list
end

function M.new()
  return setmetatable({ signals = nil, startedAt = 0 }, M)
end

---@param option PreviewOption
---@param now number @Seconds.
function M:start(option, now)
  self.signals = signal.resolve(option.flagType, option.penaltyType, M.PENALTY_PARAMETER)
  self.startedAt = now
end

function M:stop()
  self.signals = nil
end

---Seconds left, 0 when not previewing.
---@param now number
---@return number
function M:remaining(now)
  if not self.signals then return 0 end
  return math.max(0, M.DURATION - (now - self.startedAt))
end

---Preview signals while active, nil otherwise (expires automatically).
---@param now number
---@return Signal[]?
function M:active(now)
  if self.signals and self:remaining(now) <= 0 then self:stop() end
  return self.signals
end

return M
