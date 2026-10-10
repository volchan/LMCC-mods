-- Catalog of every flag and penalty the game can raise: how it looks, what the driver
-- must do, how urgent it is and which sound it plays. Pure data, no game access.
local C = require('src/theme').COLORS

local M = {}

-- Mirrors `ac.FlagType` (lua-sdk lib.lua). Kept here so pure modules and tests do not need CSP.
M.FLAG = {
  None = 0, Start = 1, Caution = 2, Slippery = 3, PitLaneClosed = 4, Stop = 5, SlowVehicle = 6,
  Ambulance = 7, ReturnToPits = 8, MechanicalFailure = 9, Unsportsmanlike = 10, StopCancel = 11,
  FasterCar = 12, Finished = 13, OneLapLeft = 14, SessionSuspended = 15, Code60 = 16,
}

-- Mirrors `ac.PenaltyType`.
M.PENALTY = { None = 0, MandatoryPits = 1, TeleportToPits = 2, SlowDown = 3, BlackFlag = 4, ReleaseBlackFlag = 5 }

-- Sound cue names, one wav file each in sounds/.
M.SOUND = { caution = 'caution', blue = 'blue', severe = 'severe', info = 'info' }

-- Drawing patterns understood by the views.
M.PATTERN = { solid = 'solid', checkered = 'checkered', stripes = 'stripes', disc = 'disc', diagonal = 'diagonal' }

---@class FlagSpec
---@field id string @Stable identifier, used in history and tests.
---@field label string @Short name shown in big letters.
---@field instruction string @What the driver must do; may contain one `%d` filled with the penalty parameter.
---@field color rgbm @Main colour.
---@field accent rgbm? @Second colour for patterned flags.
---@field text rgbm @Readable text colour on top of `color`.
---@field pattern string @One of `M.PATTERN`.
---@field priority integer @Higher wins when several signals are active.
---@field sound string? @One of `M.SOUND`, nil for silent.
---@field pulse boolean @Whether views should pulse it to draw attention.
---@field causeAt string? @One of `M.CAUSE` when the game reports which car caused the flag.
---@field instructionUnknown string? @Used instead of `instruction` when its parameter is unknown.
---@field parameterOffset integer? @Added to the game parameter before display (never below 0).

local function spec(id, label, instruction, color, text, priority, sound, pulse, pattern, accent)
  return { id = id, label = label, instruction = instruction, color = color, text = text, priority = priority,
           sound = sound, pulse = pulse, pattern = pattern or M.PATTERN.solid, accent = accent }
end

local S, P = M.SOUND, M.PATTERN

-- A gas cut clears after lifting off for the time the game sets (depends on the track), or at
-- once below GAS_CUT_CLEAR_KMH.
M.GAS_CUT_CLEAR_KMH = 35

---@type table<integer, FlagSpec>
M.BY_FLAG = {
  [M.FLAG.Start] = spec('green', 'GREEN', 'Track clear, race on', C.green, C.textLight, 20, S.info, false),
  [M.FLAG.Caution] = spec('yellow', 'YELLOW', 'Danger ahead: slow down, no overtaking', C.yellow, C.textDark, 60, S.caution, true),
  [M.FLAG.Slippery] = spec('slippery', 'SLIPPERY', 'Oil or water on track', C.yellow, C.textDark, 50, S.caution, true, P.stripes, C.red),
  [M.FLAG.PitLaneClosed] = spec('pitClosed', 'PIT CLOSED', 'Pit lane closed', C.red, C.textLight, 40, S.info, false),
  [M.FLAG.Stop] = spec('black', 'BLACK', 'Disqualified: return to pits', C.black, C.textLight, 90, S.severe, true),
  [M.FLAG.SlowVehicle] = spec('slowVehicle', 'SLOW VEHICLE', 'Slow vehicle on track', C.white, C.textDark, 55, S.caution, true),
  [M.FLAG.Ambulance] = spec('ambulance', 'AMBULANCE', 'Emergency vehicle on track', C.white, C.textDark, 65, S.caution, true),
  -- Checked in game: raised alone for a gas cut after cutting the track, and alongside every real penalty.
  [M.FLAG.ReturnToPits] = spec('gasCut', 'GAS CUT', string.format('Lift off for %%ds or drop below %d km/h', M.GAS_CUT_CLEAR_KMH), C.black, C.textLight, 85, S.severe, true, P.disc, C.orange),
  [M.FLAG.MechanicalFailure] = spec('mechanical', 'MECHANICAL', 'Car damaged: pit now', C.black, C.textLight, 80, S.severe, true, P.disc, C.orange),
  [M.FLAG.Unsportsmanlike] = spec('warning', 'WARNING', 'Unsportsmanlike behaviour', C.black, C.textLight, 70, S.severe, true, P.diagonal, C.white),
  [M.FLAG.StopCancel] = spec('blackCancelled', 'BLACK CANCELLED', 'Black flag withdrawn', C.grey, C.textLight, 30, S.info, false),
  [M.FLAG.FasterCar] = spec('blue', 'BLUE', 'Faster car behind: let it pass', C.blue, C.textLight, 45, S.blue, true),
  [M.FLAG.Finished] = spec('checkered', 'CHECKERED', 'Session over: finish the lap and return to pits', C.white, C.textDark, 35, S.info, false, P.checkered, C.black),
  [M.FLAG.OneLapLeft] = spec('white', 'WHITE', 'Last lap', C.white, C.textDark, 25, S.info, false),
  [M.FLAG.SessionSuspended] = spec('red', 'RED', 'Session stopped: slow down, return to pits', C.red, C.textLight, 100, S.severe, true),
  [M.FLAG.Code60] = spec('code60', 'CODE 60', 'Slow to 60 km/h, no overtaking', C.purple, C.textLight, 75, S.caution, true),
}

-- Lift time unknown (shared memory unavailable): give the speed rule alone.
M.BY_FLAG[M.FLAG.ReturnToPits].instructionUnknown = string.format('Lift off or drop below %d km/h', M.GAS_CUT_CLEAR_KMH)

-- Where the car that caused a flag (`ac.getSim().raceFlagCause`) is relative to the player.
M.CAUSE = { ahead = 'ahead', behind = 'behind' }
for flagType, causeAt in pairs({
  [M.FLAG.Caution] = M.CAUSE.ahead, [M.FLAG.Slippery] = M.CAUSE.ahead, [M.FLAG.SlowVehicle] = M.CAUSE.ahead,
  [M.FLAG.Ambulance] = M.CAUSE.ahead, [M.FLAG.Code60] = M.CAUSE.ahead, [M.FLAG.FasterCar] = M.CAUSE.behind,
}) do
  M.BY_FLAG[flagType].causeAt = causeAt
end

-- What the game really reports (checked in game, the SDK names do not match):
-- - TeleportToPits: a drive-through. The parameter is one more than the laps left: on a jump start
--   the game reports 3 while its own message says "2 laps remaining". Unserved means disqualification.
-- - MandatoryPits: a pit penalty with the same laps parameter (not yet seen in game).
-- - SlowDown: lift off for parameter seconds after cutting the track (RACE_GAS_PENALTY_DISABLED=0),
--   or drop below GAS_CUT_CLEAR_KMH to clear it at once (not yet seen in game).
---@type table<integer, FlagSpec>
M.BY_PENALTY = {
  [M.PENALTY.MandatoryPits] = spec('pitPenalty', 'PIT PENALTY', 'Go through the pits, laps left: %d', C.black, C.textLight, 80, S.severe, true, P.disc, C.orange),
  [M.PENALTY.TeleportToPits] = spec('driveThrough', 'DRIVE THROUGH', 'Drive through the pit lane, laps left: %d', C.black, C.textLight, 80, S.severe, true, P.disc, C.orange),
  [M.PENALTY.SlowDown] = spec('slowDown', 'SLOW DOWN', string.format('Lift off for %%ds or drop below %d km/h', M.GAS_CUT_CLEAR_KMH), C.black, C.textLight, 85, S.severe, true, P.disc, C.orange),
  [M.PENALTY.BlackFlag] = M.BY_FLAG[M.FLAG.Stop],
}
M.BY_PENALTY[M.PENALTY.MandatoryPits].parameterOffset = -1
M.BY_PENALTY[M.PENALTY.TeleportToPits].parameterOffset = -1

---@param flagType integer
---@return FlagSpec?
function M.forFlag(flagType)
  return M.BY_FLAG[flagType]
end

---@param penaltyType integer
---@return FlagSpec?
function M.forPenalty(penaltyType)
  return M.BY_PENALTY[penaltyType]
end

---Name of an enum value, e.g. `FasterCar`, or the number as text when unknown.
---@param enum table<string, integer> @`M.FLAG` or `M.PENALTY`.
---@param value integer?
---@return string
function M.nameOf(enum, value)
  for name, v in pairs(enum) do
    if v == value then return name end
  end
  return tostring(value)
end

---Labels of every flag and penalty using a sound cue, sorted, without duplicates.
---@param cue string @One of `M.SOUND`.
---@return string[]
function M.labelsForSound(cue)
  local seen, labels = {}, {}
  for _, catalog in ipairs({ M.BY_FLAG, M.BY_PENALTY }) do
    for _, spec in pairs(catalog) do
      if spec.sound == cue and not seen[spec.label] then
        seen[spec.label] = true
        labels[#labels + 1] = spec.label
      end
    end
  end
  table.sort(labels)
  return labels
end

---Instruction text with the penalty parameter filled in, when the spec expects one.
---@param flag FlagSpec
---@param parameter integer?
---@return string
function M.instruction(flag, parameter)
  if flag.instruction:find('%%d') then
    if parameter == nil and flag.instructionUnknown then return flag.instructionUnknown end
    return string.format(flag.instruction, math.max(0, (parameter or 0) + (flag.parameterOffset or 0)))
  end
  return flag.instruction
end

return M
