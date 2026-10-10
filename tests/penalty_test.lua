local t = require('tests/helper')
t.stubCsp()
local flags = require('src/flags')
local penalty = require('src/penalty')
local P = flags.PENALTY

-- No penalty passes through.
local p = penalty.new()
t.check('no penalty', p:effective(P.None, 0, false) == P.None)

-- Mandatory pits: shown until the car drives through the pit lane.
t.check('pit penalty shown', p:effective(P.MandatoryPits, 2, false) == P.MandatoryPits)
t.check('pit penalty shown with 0 laps left', p:effective(P.MandatoryPits, 0, false) == P.MandatoryPits)
t.check('still shown in the pit lane', p:effective(P.MandatoryPits, 0, true) == P.MandatoryPits)
t.check('cleared after leaving the pit lane', p:effective(P.MandatoryPits, 0, false) == P.None)
t.check('stays cleared while the game keeps it', p:effective(P.MandatoryPits, 0, false) == P.None)

-- A new penalty of the same type with more laps is shown again.
t.check('new pit penalty shown again', p:effective(P.MandatoryPits, 3, false) == P.MandatoryPits)

-- Teleport to pits: the car starts in the pit lane and serves it by driving out.
p = penalty.new()
t.check('pit stop shown in the pits', p:effective(P.TeleportToPits, 30, true) == P.TeleportToPits)
t.check('pit stop shown while seconds count down', p:effective(P.TeleportToPits, 10, true) == P.TeleportToPits)
t.check('pit stop cleared at 0 seconds', p:effective(P.TeleportToPits, 0, true) == P.None)
p = penalty.new()
p:effective(P.TeleportToPits, 30, true)
t.check('pit stop cleared when leaving the pits', p:effective(P.TeleportToPits, 30, false) == P.None)

-- Slow down: timed, not served in the pits.
p = penalty.new()
t.check('slow down shown', p:effective(P.SlowDown, 5, false) == P.SlowDown)
t.check('slow down ignores the pit lane', p:effective(P.SlowDown, 5, true) == P.SlowDown
  and p:effective(P.SlowDown, 5, false) == P.SlowDown)
t.check('slow down cleared at 0 seconds', p:effective(P.SlowDown, 0, false) == P.None)

-- Black flag: only the game clears it.
p = penalty.new()
p:effective(P.BlackFlag, 0, true)
t.check('black flag not served in the pits', p:effective(P.BlackFlag, 0, false) == P.BlackFlag)

-- Switching type resets the served state.
p = penalty.new()
p:effective(P.MandatoryPits, 1, true)
p:effective(P.MandatoryPits, 1, false)
t.check('other penalty after a served one is shown', p:effective(P.SlowDown, 3, false) == P.SlowDown)

t.finish()
