local t = require('tests/helper')
t.stubCsp()
local flags = require('src/flags')
local filter = require('src/flag_filter')
local F = flags.FLAG
local B = filter.BRIEF

-- Flags the game lowers itself pass through for as long as they are raised.
local f = filter.new()
t.check('yellow passes through', f:effective(F.Caution, 0, 1, false, true, false) == F.Caution
  and f:effective(F.Caution, 600, 3, true, true, false) == F.Caution)
t.check('blue passes through', f:effective(F.FasterCar, 700, 3, false, true, false) == F.FasterCar)
t.check('black passes through', f:effective(F.Stop, 800, 3, true, true, true) == F.Stop)
t.check('no flag passes through', f:effective(F.None, 900, 3, false, true, false) == F.None)

-- Green: brief, then hidden although the game keeps it.
f = filter.new()
t.check('green shown when raised', f:effective(F.Start, 10, 1, false, true, false) == F.Start)
t.check('green shown just before expiry', f:effective(F.Start, 10 + B - 0.1, 1, false, true, false) == F.Start)
t.check('green hidden after brief time', f:effective(F.Start, 10 + B, 1, false, true, false) == F.None)
t.check('green hidden by the setting', filter.new():effective(F.Start, 0, 1, false, false, false) == F.None)
f:effective(F.Caution, 20, 1, false, true, false)
t.check('green raised again is shown again', f:effective(F.Start, 30, 1, false, true, false) == F.Start)

-- Checkered: shown at least briefly, then until the line or the pit lane.
f = filter.new()
t.check('checkered shown when raised', f:effective(F.Finished, 100, 7, false, true, false) == F.Finished)
t.check('checkered kept on the last lap', f:effective(F.Finished, 100 + 60, 7, false, true, false) == F.Finished)
t.check('checkered hidden after the line', f:effective(F.Finished, 100 + 61, 8, false, true, false) == F.None)
f = filter.new()
f:effective(F.Finished, 200, 7, false, true, false)
t.check('checkered kept briefly when raised on the line', f:effective(F.Finished, 200 + 1, 8, false, true, false) == F.Finished)
t.check('checkered then hidden', f:effective(F.Finished, 200 + B, 8, false, true, false) == F.None)
f = filter.new()
f:effective(F.Finished, 300, 7, false, true, false)
t.check('checkered hidden in the pit lane', f:effective(F.Finished, 300 + B, 7, true, true, false) == F.None)

-- Gas cut flag: shown alone, hidden while a real penalty is reported.
f = filter.new()
t.check('gas cut shown alone', f:effective(F.ReturnToPits, 0, 1, false, true, false) == F.ReturnToPits)
t.check('gas cut flag hidden behind an active penalty', f:effective(F.ReturnToPits, 1, 1, false, true, true) == F.None)
t.check('same raise stays hidden after the penalty is served', f:effective(F.ReturnToPits, 2, 1, false, true, false) == F.None)
f:effective(F.None, 3, 1, false, true, false)
t.check('new raise after the penalty is a gas cut', f:effective(F.ReturnToPits, 4, 1, false, true, false) == F.ReturnToPits)

t.finish()
