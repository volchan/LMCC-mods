local t = require('tests/helper')
t.stubCsp()
local flags = require('src/flags')
local signal = require('src/signal')
local F, P = flags.FLAG, flags.PENALTY

local none = signal.resolve(F.None, P.None)
t.check('clear track has no signal', #none == 0)
t.check('clear track key is none', signal.key(none) == signal.NONE)

local yellow = signal.resolve(F.Caution, P.None)
t.check('yellow alone', #yellow == 1 and yellow[1].flag.id == 'yellow')
t.check('yellow instruction', yellow[1].instruction == flags.forFlag(F.Caution).instruction)
t.check('yellow key', signal.key(yellow) == 'yellow')

local penaltyOnly = signal.resolve(F.None, P.SlowDown, 3)
t.check('penalty alone', #penaltyOnly == 1 and penaltyOnly[1].flag.id == 'slowDown')
local cut = signal.resolve(F.ReturnToPits, P.None, nil, 6)
t.check('flag parameter fills the flag instruction', cut[1].instruction == 'Lift off for 6s or drop below 35 km/h')
t.check('penalty instruction has parameter', penaltyOnly[1].instruction == 'Lift off for 3s or drop below 35 km/h')

local both = signal.resolve(F.FasterCar, P.SlowDown, 5)
t.check('penalty sorted before blue', #both == 2 and both[1].flag.id == 'slowDown' and both[2].flag.id == 'blue')

local yellowAndPit = signal.resolve(F.Caution, P.TeleportToPits, 2)
t.check('drive through sorted before yellow', yellowAndPit[1].flag.id == 'driveThrough' and yellowAndPit[2].flag.id == 'yellow')

local black = signal.resolve(F.Stop, P.BlackFlag)
t.check('black flag and black penalty shown once', #black == 1 and black[1].flag.id == 'black')

local released = signal.resolve(F.None, P.ReleaseBlackFlag)
t.check('released black flag shows nothing', #released == 0)

local made = signal.of(flags.forPenalty(P.TeleportToPits), 3)
t.check('signal of a spec keeps its parameter', made.parameter == 3 and made.instruction == 'Drive through the pit lane, laps left: 2')
t.check('resolved signals carry their parameter', signal.resolve(F.ReturnToPits, P.None, nil, 4)[1].parameter == 4)
local list = { signal.of(flags.GAS_CUT_AHEAD), signal.of(flags.forFlag(F.Caution)) }
signal.sort(list)
t.check('sort puts the most urgent first', list[1].flag.id == 'yellow')

t.finish()
