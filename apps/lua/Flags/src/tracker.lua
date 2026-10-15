-- Follows the most urgent signal over time: ignores flicker shorter than a hold time,
-- reports changes and keeps a history of past signals with their duration.
local signal = require('src/signal')

local M = {}
M.__index = M

M.DEFAULT_HOLD = 0.3
M.DEFAULT_MAX_HISTORY = 50

---@class HistoryEntry
---@field flag FlagSpec
---@field instruction string
---@field detail string?
---@field startedAt number @Seconds, same clock as `update`.
---@field duration number? @Seconds, nil while still active.
---@field lap integer?
---@field sessionTime number? @Seconds since session start.

---@class Stamp @Context captured when a signal starts. Callers may reuse the table every frame.
---@field lap integer?
---@field sessionTime number?
---@field detail string?

---@param options {hold: number?, maxHistory: integer?}?
function M.new(options)
  options = options or {}
  return setmetatable({
    hold = options.hold or M.DEFAULT_HOLD,
    maxHistory = options.maxHistory or M.DEFAULT_MAX_HISTORY,
    current = signal.NONE,
    candidate = signal.NONE,
    candidateSince = 0,
    ---@type HistoryEntry[] @Oldest first.
    history = {},
  }, M)
end

function M:clear()
  self.history = {}
end

---@private
function M:closeActive(now)
  local last = self.history[#self.history]
  if last and not last.duration then last.duration = now - last.startedAt end
end

---@private
---@param top Signal
---@param stamp Stamp?
function M:open(now, top, stamp)
  self.history[#self.history + 1] = {
    flag = top.flag, instruction = top.instruction, startedAt = now,
    detail = stamp and stamp.detail, lap = stamp and stamp.lap, sessionTime = stamp and stamp.sessionTime,
  }
  if #self.history > self.maxHistory then table.remove(self.history, 1) end
end

---Feeds the signals of one frame.
---@param now number @Seconds, monotonic.
---@param signals Signal[] @From `signal.resolve`, most urgent first.
---@param stamp Stamp?
---@return {from: string, to: string, signal: Signal?}? @Change event once the new signal held long enough.
function M:update(now, signals, stamp)
  local key = signal.key(signals)
  if key ~= self.candidate then
    self.candidate, self.candidateSince = key, now
  end
  if self.candidate == self.current or now - self.candidateSince < self.hold then return nil end

  local from = self.current
  self.current = key
  self:closeActive(now)
  if signals[1] then self:open(now, signals[1], stamp) end
  return { from = from, to = key, signal = signals[1] }
end

---The history entry of the signal currently shown, if any.
---@return HistoryEntry?
function M:active()
  local last = self.history[#self.history]
  if last and not last.duration then return last end
  return nil
end

return M
