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

local penaltyOnly = signal.resolve(F.None, P.TeleportToPits, 3)
t.check('penalty alone', #penaltyOnly == 1 and penaltyOnly[1].flag.id == 'driveThrough')
t.check('slow down penalty shows nothing', #signal.resolve(F.None, P.SlowDown, 3) == 0)
local cut = signal.resolve(F.ReturnToPits, P.None, nil, 6)
t.check('flag parameter fills the flag instruction', cut[1].instruction == 'Lift off for 6s or drop below 35 km/h')
t.check('penalty instruction has parameter', penaltyOnly[1].instruction == 'Drive through the pit lane, laps left: 2')

local both = signal.resolve(F.FasterCar, P.TeleportToPits, 5)
t.check('penalty sorted before blue', #both == 2 and both[1].flag.id == 'driveThrough' and both[2].flag.id == 'blue')

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

local ids = function(signals)
  local out = {}
  for i, s in ipairs(signals) do out[i] = s.flag.id end
  return table.concat(out, ',')
end
local ahead = signal.of(flags.GAS_CUT_AHEAD)
local cutAndDrive = signal.resolve(F.ReturnToPits, P.TeleportToPits, 3, 5)
t.check('gas cut replaces the drive through', ids(signal.display(cutAndDrive)) == 'gasCut')
t.check('drive through back once the gas cut is served',
  ids(signal.display(signal.resolve(F.None, P.TeleportToPits, 3))) == 'driveThrough')
t.check('own gas cut above the gas cut ahead', ids(signal.display(cutAndDrive, ahead)) == 'gasCut,gasCutAhead')
t.check('gas cut ahead right below the own gas cut',
  ids(signal.display({ signal.of(flags.GAS_CUT, 3), signal.of(flags.forFlag(F.Caution)) }, ahead)) == 'gasCut,gasCutAhead,yellow')
t.check('gas cut ahead above the drive through', ids(signal.display(signal.resolve(F.None, P.TeleportToPits, 3), ahead)) == 'gasCutAhead,driveThrough')
t.check('yellow stays named above the gas cut ahead and the drive through',
  ids(signal.display(signal.resolve(F.Caution, P.TeleportToPits, 3), ahead)) == 'yellow,gasCutAhead,driveThrough')
t.check('black above the own gas cut and the gas cut ahead',
  ids(signal.display({ signal.of(flags.forFlag(F.Stop)), signal.of(flags.GAS_CUT, 3) }, ahead)) == 'black,gasCut,gasCutAhead')
t.check('gas cut ahead below a flag that is no penalty',
  ids(signal.display(signal.resolve(F.Stop, P.None), ahead)) == 'black,gasCutAhead')
t.check('gas cut ahead last when it is the most urgent', ids(signal.display(signal.resolve(F.OneLapLeft, P.None), ahead)) == 'gasCutAhead,white')
t.check('gas cut ahead alone', ids(signal.display({}, ahead)) == 'gasCutAhead')
t.check('nothing to display', #signal.display({}) == 0)

t.finish()
