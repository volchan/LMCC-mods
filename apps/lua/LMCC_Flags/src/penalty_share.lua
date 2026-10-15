-- Penalties shared between drivers. The sender turns this driver's own signals into "started"
-- and "served" messages; the board keeps the penalties other drivers announced. Pure.
local flags = require('src/flags')

local M = {}

M.GAS_CUT_UNKNOWN = 10 -- seconds a gas cut of unknown length is kept without a "served" message
M.GRACE = 3 -- seconds a gas cut is kept past its length, waiting for the "served" message

---@class ShareMessage
---@field code integer @Index in `flags.SHARED`.
---@field active integer @1 started, 0 served.
---@field parameter integer @Seconds or laps when started, 0 when unknown.

-- Code of each shared spec, from its position in `flags.SHARED`.
local CODES = {}
for code, spec in ipairs(flags.SHARED) do CODES[spec] = code end

local Sender = {}
Sender.__index = Sender

function M.newSender()
  return setmetatable({ active = {} }, Sender)
end

---Messages announcing what changed since the last call, in a stable order.
---@param signals Signal[] @This driver's real signals (never previews).
---@return ShareMessage[]
function Sender:update(signals)
  local now = {}
  for _, s in ipairs(signals) do
    local code = CODES[s.flag]
    if code then now[code] = s.parameter or 0 end
  end
  local out = {}
  for code = 1, #flags.SHARED do
    if now[code] and not self.active[code] then
      out[#out + 1] = { code = code, active = 1, parameter = now[code] }
    elseif self.active[code] and not now[code] then
      out[#out + 1] = { code = code, active = 0, parameter = 0 }
    end
  end
  self.active = now
  return out
end

local Board = {}
Board.__index = Board

function M.newBoard()
  return setmetatable({ cars = {} }, Board) ---@type table<integer, table<integer, {since: number, parameter: integer}>>
end

---@param carIndex integer @Sender.
---@param message ShareMessage
---@param now number @Seconds.
function Board:receive(carIndex, message, now)
  if not flags.SHARED[message.code] then return end -- from a newer version
  local car = self.cars[carIndex] or {}
  self.cars[carIndex] = car
  car[message.code] = message.active == 1 and { since = now, parameter = message.parameter } or nil
end

---@class SharedGasCut
---@field carIndex integer
---@field secondsLeft integer? @Nil when the length is unknown.

---Gas cuts other drivers are serving at `now`; stale ones are dropped.
---@param now number @Seconds.
---@return SharedGasCut[]
function Board:gasCuts(now)
  local code, out = CODES[flags.GAS_CUT], {}
  for carIndex, car in pairs(self.cars) do
    local entry = car[code]
    if entry then
      local length = entry.parameter > 0 and entry.parameter or M.GAS_CUT_UNKNOWN
      local elapsed = now - entry.since
      if elapsed >= length + M.GRACE then
        car[code] = nil
      else
        out[#out + 1] = { carIndex = carIndex,
          secondsLeft = entry.parameter > 0 and math.max(0, math.ceil(entry.parameter - elapsed)) or nil }
      end
    end
  end
  return out
end

return M
