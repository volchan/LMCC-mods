-- Per-frame flow: read the game, resolve signals, track changes, play cues, apply preview.
-- Dependencies are injected so the whole flow can be tested without the game.
local flags = require('src/flags')
local signal = require('src/signal')
local context = require('src/context')
local blue = require('src/blue')
local penalty = require('src/penalty')
local settingsLib = require('src/settings')

local M = {}
M.__index = M

M.DETAIL_INTERVAL = 0.25 -- seconds between distance updates
local GREEN_ID = flags.forFlag(flags.FLAG.Start).id

---@class AppDeps
---@field game {read: fun(out: table): table?, cause: fun(index: integer, out: table): table?, cars: fun(out: table): table}
---@field sound {play: fun(cue: string, volume: number)}
---@field settings table @Loaded settings.
---@field tracker table @From `tracker.new()`.
---@field preview table @From `preview.new()`.
---@field panel {show: fun()} @Opens the panel window, even after the driver closed it.

---@param deps AppDeps
function M.new(deps)
  return setmetatable({
    deps = deps,
    now = 0,
    snapshot = {}, cause = {}, stamp = {}, cars = {},
    visible = {}, -- real signals after hiding, most urgent first
    penalty = penalty.new(), -- clears penalties the game keeps reporting once served
    detail = nil, ---@type string?
    detailAt = -math.huge,
    detailKey = nil,
    -- Inputs of the last resolve, so signals are only rebuilt when something changed.
    lastFlag = nil, lastPenalty = nil, lastParameter = nil, lastShowGreen = nil,
  }, M)
end

---@private
function M:refreshVisible(snap)
  local s = self.deps.settings
  local penaltyType = self.penalty:effective(snap.penaltyType, snap.penaltyParameter, snap.inPitlane)
  if snap.flagType == self.lastFlag and penaltyType == self.lastPenalty
    and snap.penaltyParameter == self.lastParameter and s.showGreen == self.lastShowGreen then
    return
  end
  self.lastFlag, self.lastPenalty, self.lastParameter, self.lastShowGreen =
    snap.flagType, penaltyType, snap.penaltyParameter, s.showGreen
  local real = signal.resolve(snap.flagType, penaltyType, snap.penaltyParameter)
  self.visible = s.showGreen and real or signal.without(real, GREEN_ID)
end

---Location line for a signal: lapping cars under blue, otherwise the car that caused the flag.
---@private
---@param snap Snapshot
---@param top Signal?
---@return string?
function M:describe(snap, top)
  if not top then return nil end
  local deps = self.deps
  if top.flag.causeAt == flags.CAUSE.behind then
    local cars = deps.game.cars(self.cars)
    local lapping = blue.describe(blue.approaching(cars[1], cars, snap.trackLength, deps.settings.blueRange))
    if lapping then return lapping end
  end
  local cause = top.flag.causeAt and deps.game.cause(snap.flagCause, self.cause)
  return context.describe(top.flag, cause or nil)
end

---@private
function M:refreshDetail(snap)
  local key = signal.key(self.visible)
  if key == self.detailKey and self.now - self.detailAt < M.DETAIL_INTERVAL then return end
  self.detailKey, self.detailAt = key, self.now
  self.detail = self:describe(snap, self.visible[1])
end

---Brings a new flag to the driver's attention: opens the panel and plays the cue.
---@param flag FlagSpec
function M:announce(flag)
  self.deps.panel.show()
  self:playFlag(flag)
end

---Plays the cue of a flag at the configured volume.
---@param flag FlagSpec
function M:playFlag(flag)
  if flag.sound then self:playCue(flag.sound) end
end

---@param cue string @One of `flags.SOUND`.
function M:playCue(cue)
  local volume = settingsLib.volumeFor(self.deps.settings, cue)
  if volume > 0 then self.deps.sound.play(cue, volume) end
end

function M:update()
  local snap = self.deps.game.read(self.snapshot)
  if not snap then return end
  self.now = snap.now
  self:refreshVisible(snap)
  self:refreshDetail(snap)
  local stamp = self.stamp
  stamp.lap, stamp.sessionTime, stamp.detail = snap.lap, snap.sessionTime, self.detail
  local event = self.deps.tracker:update(self.now, self.visible, stamp)
  if event and event.signal then self:announce(event.signal.flag) end
end

---Signals to display: the preview while one runs, otherwise the real ones.
---@return Signal[]
function M:signals()
  return self.deps.preview:active(self.now) or self.visible
end

---Location line for the displayed signal; previews show sample data.
---@return string?
function M:displayDetail()
  if self.deps.preview:active(self.now) then return self.deps.preview.detail end
  return self.detail
end

---@param option PreviewOption
function M:startPreview(option)
  self.deps.preview:start(option, self.now)
  local top = self.deps.preview:active(self.now)[1]
  if top then self:announce(top.flag) end
end

function M:stopPreview()
  self.deps.preview:stop()
end

return M
