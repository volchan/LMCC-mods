local t = require('tests/helper')
t.stubCsp()
local probe = require('src/net_probe')
local K = probe.KIND

local p = probe.new()
local ping = p:ping(10)
t.check('ping message', ping.kind == K.ping and ping.id == 1 and ping.replyTo == probe.NO_TARGET)
t.check('pings throttled', p:ping(10 + probe.MIN_INTERVAL / 2) == nil)

-- Own ping comes back: echo, no reply.
t.check('own ping not answered', p:receive(ping, 0, 7, 7, 10.1) == nil)
t.check('own ping echo timed', t.near(p.echo, 0.1))
p:receive(ping, 0, 7, 7, 10.5)
t.check('later copies keep the first echo time', t.near(p.echo, 0.1))

-- Another client pings: remembered and answered to its session only.
local pong = p:receive({ kind = K.ping, id = 42, replyTo = probe.NO_TARGET }, 3, 12, 7, 11)
t.check('ping answered with a pong', pong.kind == K.pong and pong.id == 42 and pong.replyTo == 12)
t.check('ping sender remembered', p.pingsFrom[3] == 11)

-- Pongs for our ping record the round trip; others are ignored.
p:receive({ kind = K.pong, id = 1, replyTo = 7 }, 2, 9, 7, 10.25)
t.check('reply recorded with round trip', t.near(p.replies[2], 0.25))
p:receive({ kind = K.pong, id = 1, replyTo = 8 }, 4, 9, 7, 10.3)
t.check('pong for another client ignored', p.replies[4] == nil)
p:receive({ kind = K.pong, id = 99, replyTo = 7 }, 5, 9, 7, 10.3)
t.check('pong for an old ping ignored', p.replies[5] == nil)
t.check('server messages ignored', p:receive({ kind = K.ping, id = 1, replyTo = -1 }, nil, nil, 7, 10.3) == nil)
t.check('own pong copy ignored', p:receive({ kind = K.pong, id = 1, replyTo = 7 }, 0, 7, 7, 10.3) == nil
  and p.replies[0] == nil)

-- A new round clears the previous results.
local second = p:ping(12)
t.check('new round', second.id == 2 and p.echo == nil and next(p.replies) == nil)
p.pingId = 65535
t.check('ping id wraps within uint16', p:ping(20).id == 1)

-- Echo route: compared with the ping to the server.
t.check('echo near the ping went through the server', probe.echoRoute(40, 60) == probe.ECHO.server)
t.check('instant echo is a local copy', probe.echoRoute(2, 60) == probe.ECHO['local'])
t.check('instant echo without ping is local', probe.echoRoute(0, -1) == probe.ECHO['local'])
t.check('slowish echo without ping is unsure', probe.echoRoute(20, -1) == probe.ECHO.unsure)
t.check('echo well under the ping is unsure', probe.echoRoute(10, 60) == probe.ECHO.unsure)
t.check('low ping proves nothing', probe.echoRoute(13, 2) == probe.ECHO.unsure
  and probe.echoRoute(20, probe.MIN_PING_MS - 1) == probe.ECHO.unsure)

t.finish()
