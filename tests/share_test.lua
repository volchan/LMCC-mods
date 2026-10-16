local t = require('tests/helper')
t.stubCsp()

-- Fake ac.OnlineEvent: records sent messages, `deliver` plays incoming ones, `limited` rejects sends.
local layout, deliver, sent, limited = nil, nil, {}, false
ac = {
  StructItem = {
    key = function(k) return 'key:' .. k end,
    byte = function() return 'byte' end,
    int32 = function() return 'int32' end,
  },
  OnlineEvent = function(l, callback)
    layout, deliver = l, callback
    return function(message)
      if limited then return false end
      sent[#sent + 1] = message
      return true
    end
  end,
}
local flags = require('src/flags')
local signal = require('src/signal')
local share = require('src/share')
local now = 0
local s = share.new(function() return now end)

t.check('event keyed for penalties', layout[1] == 'key:' .. share.KEY and layout.code == 'byte'
  and layout.active == 'byte' and layout.parameter == 'int32')

-- Own penalty changes are sent; unchanged signals send nothing.
s:announce(signal.resolve(flags.FLAG.ReturnToPits, flags.PENALTY.None, nil, 5))
t.check('gas cut announced', #sent == 1 and sent[1].active == 1 and sent[1].parameter == 5)
s:announce(signal.resolve(flags.FLAG.ReturnToPits, flags.PENALTY.None, nil, 5))
t.check('nothing new, nothing sent', #sent == 1)

-- Rate limited: kept in order, sent on a later flush.
limited = true
s:announce({})
t.check('rate limited message kept', #sent == 1 and #s.queue == 1)
s:flush()
t.check('still waiting while limited', #s.queue == 1)
limited = false
s:flush()
t.check('sent once allowed', #sent == 2 and sent[2].active == 0 and #s.queue == 0)

-- Test penalty: sent like a real one, with the test code.
local penaltyShare = require('src/penalty_share')
s:test()
t.check('test penalty sent', #sent == 3 and sent[3].code == penaltyShare.TEST and sent[3].active == 1
  and sent[3].parameter == 0)

-- Incoming: other drivers fill the board; own copies and server messages do not.
now = 50
deliver({ index = 2 }, { code = 1, active = 1, parameter = 6 })
deliver({ index = 0 }, { code = 1, active = 1, parameter = 6 })
deliver(nil, { code = 1, active = 1, parameter = 6 })
now = 51
local cuts = s:gasCuts()
t.check('other driver gas cut on the board', #cuts == 1 and cuts[1].carIndex == 2 and cuts[1].secondsLeft == 5)
deliver({ index = 3 }, { code = penaltyShare.TEST, active = 1, parameter = 0 })
t.check('test penalties stay off the board', s.board.cars[3] == nil)

t.finish()
