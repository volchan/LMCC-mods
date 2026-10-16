local t = require('tests/helper')
t.stubCsp()

-- Fake ac.OnlineEvent: records sent messages, `limited` rejects sends. Car 3 has session ID 42.
local layout, sent, limited = nil, {}, false
ac = {
  StructItem = {
    key = function(k) return 'key:' .. k end,
    byte = function() return 'byte' end,
    int32 = function() return 'int32' end,
  },
  OnlineEvent = function(l)
    layout = l
    return function(message)
      if limited then return false end
      sent[#sent + 1] = { flag = message.flag, cause = message.cause }
      return true
    end
  end,
  getCar = function(index) return index == 3 and { sessionID = 42 } or nil end,
}
local F = require('src/flags').FLAG
local flagShare = require('src/flag_share')
local s = flagShare.new()

t.check('event keyed for flags', layout[1] == 'key:' .. flagShare.KEY and layout.flag == 'byte'
  and layout.cause == 'int32')

-- A clear track from the start says nothing.
s:announce(F.None, -1)
t.check('clear track not sent', #sent == 0)

-- A flag goes with its cause as a session ID, once.
s:announce(F.Caution, 3)
s:announce(F.Caution, 3)
t.check('yellow sent with the cause session ID', #sent == 1 and sent[1].flag == F.Caution and sent[1].cause == 42)
s:announce(F.Caution, 7)
t.check('unknown cause car sent as none', #sent == 2 and sent[2].cause == flagShare.NO_CAUSE)

-- Rate limited: only the latest state waits.
limited = true
s:announce(F.FasterCar, -1)
s:announce(F.None, -1)
t.check('latest state waits', #sent == 2 and s.waiting.flag == F.None)
limited = false
s:flush()
t.check('latest state sent once allowed', #sent == 3 and sent[3].flag == F.None and s.waiting == nil)

-- Back to the state that already left before the waiting one could: nothing sent.
limited = true
s:announce(F.Start, -1)
s:announce(F.None, -1)
limited = false
s:flush()
t.check('round trip while limited sends nothing', #sent == 3 and s.waiting == nil)

t.finish()
