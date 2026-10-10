-- Test mode: shows any flag or penalty for a few seconds so drivers can check how alerts
-- look and sound before a race. Preview signals are never written to the history.
local flags = require('src/flags')
local signal = require('src/signal')
local context = require('src/context')
local blue = require('src/blue')

local M = {}
M.__index = M

M.DURATION = 6 -- seconds
M.PENALTY_PARAMETER = 3 -- game parameter for penalty previews (laps or seconds)

-- Fake surroundings so previews show a realistic location line.
M.SAMPLE_CAUSE = { mySpline = 0.10, causeSpline = 0.1625, trackLength = 4000, causeName = 'Sample Driver', causeSector = 'Turn 1' }
-- Blue previews list a random number of these, closest first.
M.SAMPLE_LAPPING = {
  { name = 'Leader', racePosition = 1, gap = 80 },
  { name = 'Second', racePosition = 2, gap = 240 },
  { name = 'Third', racePosition = 3, gap = 390 },
}

---@class PreviewOption
---@field label string
---@field flag FlagSpec
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
    list[#list + 1] = { label = spec.label, flag = spec, flagType = flagType, penaltyType = penaltyType, priority = spec.priority }
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

---Location line a real flag of this kind would show, built from sample data.
---@param flag FlagSpec
---@param lapping integer @Sample cars to let pass, 1..#SAMPLE_LAPPING.
---@return string?
function M.sampleDetail(flag, lapping)
  if flag.causeAt == flags.CAUSE.behind then
    local list = {}
    for i = 1, lapping do list[i] = M.SAMPLE_LAPPING[i] end
    return blue.describe(list)
  end
  return context.describe(flag, M.SAMPLE_CAUSE)
end

---@param random (fun(m: integer, n: integer): integer)? @Picks the sample car count, `math.random` by default.
function M.new(random)
  return setmetatable({ signals = nil, detail = nil, startedAt = 0, random = random or math.random }, M)
end

---@param option PreviewOption
---@param now number @Seconds.
function M:start(option, now)
  self.signals = signal.resolve(option.flagType, option.penaltyType, M.PENALTY_PARAMETER)
  self.detail = M.sampleDetail(self.signals[1].flag, self.random(1, #M.SAMPLE_LAPPING))
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
