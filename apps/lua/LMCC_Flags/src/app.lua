-- Per-frame flow: read the game, resolve signals, track changes, play cues, apply preview.
-- Dependencies are injected so the whole flow can be tested without the game.
local flags = require('src/flags')
local signal = require('src/signal')
local context = require('src/context')
local blue = require('src/blue')
local gasCutAhead = require('src/gas_cut_ahead')
local penalty = require('src/penalty')
local flagFilter = require('src/flag_filter')
local settingsLib = require('src/settings')

local M = {}
M.__index = M

M.DETAIL_INTERVAL = 0.25 -- seconds between distance updates

---@class AppDeps
---@field game {read: fun(out: table): table?, cause: fun(index: integer, out: table): table?, cars: fun(out: table): table}
---@field sound {play: fun(cue: string, volume: number)}
---@field settings table @Loaded settings.
---@field tracker table @From `tracker.new()`.
---@field preview table @From `preview.new()`.
---@field panel {show: fun()} @Opens the panel window, even after the driver closed it.
---@field share {announce: fun(self, signals: Signal[]), flush: fun(self), gasCuts: fun(self): SharedGasCut[]} @Penalties shared between drivers.
---@field flagShare {announce: fun(self, flagType: integer, causeIndex: integer), flush: fun(self)} @Race flag shared with the apps following the field.

---@param deps AppDeps
function M.new(deps)
  return setmetatable({
    deps = deps,
    now = 0,
    snapshot = {}, cause = {}, stamp = {}, cars = {},
    own = {}, -- this driver's signals after hiding, most urgent first
    visible = {}, -- own signals plus alerts about other drivers
    aheadDetail = nil, ---@type string? @Gas cuts close ahead, nil when none.
    aheadAt = -math.huge,
    aheadSignal = signal.of(flags.GAS_CUT_AHEAD),
    penalty = penalty.new(), -- clears penalties the game keeps reporting once served
    flagFilter = flagFilter.new(), -- hides flags the game keeps raised for too long
    detail = nil, ---@type string?
    detailAt = -math.huge,
    detailKey = nil,
    -- Inputs of the last resolve, so signals are only rebuilt when something changed.
    lastFlag = nil, lastPenalty = nil, lastParameter = nil, lastFlagParameter = nil,
  }, M)
end

---@private
function M:refreshVisible(snap)
  local penaltyType = self.penalty:effective(snap.penaltyType, snap.penaltyParameter, snap.inPitlane)
  local penaltyActive = flags.forPenalty(penaltyType) ~= nil
  local flagType = self.flagFilter:effective(snap.flagType, snap.now, snap.lap, snap.inPitlane,
    self.deps.settings.showGreen, penaltyActive, snap.penaltyTime > 0)
  -- Gas cut seconds only, in whole seconds so signals are rebuilt once per second while they count down.
  local gasCut = flags.forFlag(flagType) == flags.GAS_CUT
  local flagParameter = gasCut and snap.penaltyTime > 0 and math.ceil(snap.penaltyTime) or nil
  if flagType == self.lastFlag and penaltyType == self.lastPenalty and snap.penaltyParameter == self.lastParameter
    and flagParameter == self.lastFlagParameter then
    return
  end
  self.lastFlag, self.lastPenalty, self.lastParameter, self.lastFlagParameter =
    flagType, penaltyType, snap.penaltyParameter, flagParameter
  self.own = signal.resolve(flagType, penaltyType, snap.penaltyParameter, flagParameter)
  self.deps.share:announce(self.own)
  self:compose()
end

---Visible signals: own ones, plus the gas cut ahead alert while a car ahead serves one.
---@private
function M:compose()
  self.visible = signal.display(self.own, self.aheadDetail and self.aheadSignal)
end

---Gas cuts other drivers share, kept only for cars close ahead. 4 Hz like the location line.
---@private
function M:refreshAhead(snap)
  if self.now - self.aheadAt < M.DETAIL_INTERVAL then return end
  self.aheadAt = self.now
  local cuts, detail = self.deps.share:gasCuts(), nil
  if #cuts > 0 then
    local cars = self.deps.game.cars(self.cars)
    detail = gasCutAhead.describe(gasCutAhead.nearby(cars[1], cars, cuts, snap.trackLength,
      self.deps.settings.gasCutRange))
  end
  local changed = (detail == nil) ~= (self.aheadDetail == nil)
  self.aheadDetail = detail
  if changed then self:compose() end
end

---Location line for a signal: lapping cars under blue, otherwise the car that caused the flag.
---@private
---@param snap Snapshot
---@param top Signal?
---@return string?
function M:describe(snap, top)
  if not top then return nil end
  if top.flag == flags.GAS_CUT_AHEAD then return self.aheadDetail end
  local deps = self.deps
  if top.flag.causeAt == flags.CAUSE.behind then
    local cars = deps.game.cars(self.cars)
    local lapping = blue.describe(blue.approaching(cars[1], cars, snap.trackLength, deps.settings.blueRange))
    if lapping then return lapping end
  end
  local cause = top.flag.causeAt and deps.game.cause(snap.flagCause, self.cause)
  -- No location of its own (e.g. the driver's gas cut): show the cars ahead serving one, if any.
  return context.describe(top.flag, cause or nil) or self.aheadDetail
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
  self:refreshAhead(snap)
  self:refreshDetail(snap)
  self.deps.share:flush()
  -- The raw flag, not the hidden one: what the game raised, for whoever follows the field
  self.deps.flagShare:announce(snap.flagType, snap.flagCause)
  self.deps.flagShare:flush()
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

---Adds an alert to the preview and plays its cue.
---@param option PreviewOption
function M:startPreview(option)
  self.deps.preview:start(option, self.now)
  self:announce(option.flag)
end

function M:stopPreview()
  self.deps.preview:stop()
end

return M
