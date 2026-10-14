local t = require('tests/helper')
t.stubCsp()
local flags = require('src/flags')
local signal = require('src/signal')
local share = require('src/penalty_share')
local F, P = flags.FLAG, flags.PENALTY

local function codeOf(spec)
  for code, s in ipairs(flags.SHARED) do
    if s == spec then return code end
  end
end
local GAS, DRIVE = codeOf(flags.GAS_CUT), codeOf(flags.forPenalty(P.TeleportToPits))
t.check('every penalty is shared', GAS and DRIVE and codeOf(flags.forPenalty(P.MandatoryPits))
  and codeOf(flags.forPenalty(P.SlowDown)) and codeOf(flags.forFlag(F.Stop)))

-- Sender: start and served messages only on changes.
local sender = share.newSender()
t.check('nothing to say on a clear track', #sender:update({}) == 0)
local out = sender:update(signal.resolve(F.ReturnToPits, P.None, nil, 5))
t.check('gas cut start with its seconds', #out == 1 and out[1].code == GAS and out[1].active == 1 and out[1].parameter == 5)
t.check('no repeat while unchanged', #sender:update(signal.resolve(F.ReturnToPits, P.None, nil, 4)) == 0)
out = sender:update(signal.resolve(F.None, P.TeleportToPits, 3))
t.check('gas cut served and drive-through started', #out == 2
  and out[1].code == GAS and out[1].active == 0 and out[2].code == DRIVE and out[2].active == 1 and out[2].parameter == 3)
out = sender:update(signal.resolve(F.Caution, P.None))
t.check('non-shared flags are not announced', #out == 1 and out[1].code == DRIVE and out[1].active == 0)
out = sender:update(signal.resolve(F.ReturnToPits, P.None))
t.check('unknown length sent as 0', out[1].parameter == 0)

-- Board: gas cuts counted down, removed when served or stale.
local board = share.newBoard()
board:receive(3, { code = GAS, active = 1, parameter = 5 }, 100)
board:receive(4, { code = DRIVE, active = 1, parameter = 2 }, 100)
local cuts = board:gasCuts(101.5)
t.check('only gas cuts listed, counted down', #cuts == 1 and cuts[1].carIndex == 3 and cuts[1].secondsLeft == 4)
t.check('seconds never below 0', board:gasCuts(105 + share.GRACE / 2)[1].secondsLeft == 0)
t.check('stale gas cut dropped', #board:gasCuts(105 + share.GRACE) == 0)
board:receive(3, { code = GAS, active = 1, parameter = 5 }, 200)
board:receive(3, { code = GAS, active = 0, parameter = 0 }, 201)
t.check('served gas cut removed', #board:gasCuts(201) == 0)
board:receive(5, { code = GAS, active = 1, parameter = 0 }, 300)
cuts = board:gasCuts(300 + share.GAS_CUT_UNKNOWN)
t.check('unknown length kept a while, without seconds', #cuts == 1 and cuts[1].secondsLeft == nil)
t.check('unknown length dropped later', #board:gasCuts(300 + share.GAS_CUT_UNKNOWN + share.GRACE) == 0)
board:receive(6, { code = 99, active = 1, parameter = 1 }, 400)
t.check('unknown codes from newer versions ignored', board.cars[6] == nil)

t.finish()
