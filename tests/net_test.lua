local t = require('tests/helper')
t.stubCsp()

-- Fake ac.OnlineEvent: records the layout and sent messages; `deliver` plays incoming ones.
local layout, deliver, sent = nil, nil, {}
local sim = { isOnlineRace = true, directMessagingAvailable = false }
local names = { [2] = 'Alice', [3] = 'Bob' }
ac = {
  StructItem = {
    key = function(k) return 'key:' .. k end,
    byte = function() return 'byte' end,
    uint16 = function() return 'uint16' end,
    int32 = function() return 'int32' end,
  },
  OnlineEvent = function(l, callback)
    layout, deliver = l, callback
    return function(message) sent[#sent + 1] = message; return true end
  end,
  getCar = function(i) return i == 0 and { sessionID = 7, ping = 40 } or nil end,
  getDriverName = function(i) return names[i] end,
  getSim = function() return sim end,
}
local now = 0
local net = require('src/net')
local probe = require('src/net_probe')
local n = net.new(function() return now end)

t.check('event keyed for this app', layout[1] == 'key:' .. net.KEY and layout.kind == 'byte'
  and layout.id == 'uint16' and layout.replyTo == 'int32')
local s = n:status()
t.check('status before any ping', s.online and not s.direct and not s.pinged and s.echoMs == nil and s.echoRoute == nil
  and s.pingMs == 40 and #s.replies == 0)

-- Ping, own echo, two replies, a ping from someone else answered.
now = 10
n:ping()
t.check('ping sent', #sent == 1 and sent[1].kind == probe.KIND.ping)
n:ping()
t.check('second ping throttled', #sent == 1)
now = 10.03
deliver({ index = 0, sessionID = 7 }, sent[1])
now = 10.12
deliver({ index = 3, sessionID = 9 }, { kind = probe.KIND.pong, id = sent[1].id, replyTo = 7 })
now = 10.05
deliver({ index = 2, sessionID = 8 }, { kind = probe.KIND.pong, id = sent[1].id, replyTo = 7 })
deliver({ index = 5, sessionID = 11 }, { kind = probe.KIND.ping, id = 4, replyTo = -1 })
t.check('ping from another client answered', #sent == 2 and sent[2].kind == probe.KIND.pong and sent[2].replyTo == 11)
deliver(nil, { kind = probe.KIND.ping, id = 1, replyTo = -1 })
t.check('server message not answered', #sent == 2)

now = 13
s = n:status()
t.check('echo timed and judged against the ping', s.pinged and s.echoMs == 30 and s.echoRoute == probe.ECHO.server)
t.check('replies named, fastest first', #s.replies == 2 and s.replies[1].name == 'Alice' and s.replies[1].ms == 50
  and s.replies[2].name == 'Bob' and s.replies[2].ms == 120)
t.check('unknown driver gets a car label', #s.pingsFrom == 1 and s.pingsFrom[1].name == 'Car 5' and s.pingsFrom[1].ago == 3)

-- Without a player car the session is unknown: pongs are not taken as ours.
ac.getCar = function() return nil end
n:ping()
deliver({ index = 2, sessionID = 8 }, { kind = probe.KIND.pong, id = n.probe.pingId, replyTo = 7 })
t.check('no player car, no reply matched', next(n.probe.replies) == nil)
sim.directMessagingAvailable = true
s = n:status()
t.check('direct messaging reported', s.direct)
t.check('unknown ping without a player car', s.pingMs == -1)

t.finish()
