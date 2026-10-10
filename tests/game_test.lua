local t = require('tests/helper')
local game = require('src/game')

local sim = { time = 125000, raceFlagType = 2, raceFlagCause = 3, currentSessionIndex = 1, trackLengthM = 4000 }
local player = { index = 0, currentPenaltyType = 3, currentPenaltyParameter = 5, lapCount = 4, splinePosition = 0.10 }
local other = { index = 3, splinePosition = 0.15 }
local sessions = { [1] = { startTime = 5000 } }

ac = {
  getSim = function() return sim end,
  getCar = function(i) return ({ [0] = player, [3] = other })[i] end,
  getSession = function(i) return sessions[i] end,
  getDriverName = function(i) return 'Driver ' .. i end,
  getTrackSectorName = function(p) return p == 0.15 and 'Turn 4' or '' end,
}

local snap = {}
t.check('read returns the table it filled', game.read(snap) == snap)
t.check('time in seconds', snap.now == 125)
t.check('flag fields', snap.flagType == 2 and snap.flagCause == 3)
t.check('penalty fields', snap.penaltyType == 3 and snap.penaltyParameter == 5)
t.check('lap in progress is 1-based', snap.lap == 5)
t.check('session time from session start', snap.sessionTime == 120)

sessions[1] = nil
game.read(snap)
t.check('session time nil without session', snap.sessionTime == nil)

local cause = {}
t.check('cause returns the table it filled', game.cause(3, cause) == cause)
t.check('cause positions', cause.mySpline == 0.10 and cause.causeSpline == 0.15 and cause.trackLength == 4000)
t.check('cause name and sector', cause.causeName == 'Driver 3' and cause.causeSector == 'Turn 4')

t.check('no cause for -1', game.cause(-1, {}) == nil)
t.check('no cause for missing car', game.cause(7, {}) == nil)

local own = game.cause(0, {})
t.check('own car as cause has no name', own and own.causeName == nil)

ac.getSim = function() return nil end
t.check('read nil without sim', game.read({}) == nil)

t.finish()
