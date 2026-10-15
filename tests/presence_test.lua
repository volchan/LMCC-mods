local t = require('tests/helper')
local presence = require('src/presence')

local now = 100
local shared, writes = {}, 0
local function clock() return now end
local function store(k, v) shared[k] = v; writes = writes + 1 end
local function load(k) return shared[k] end

local dev = presence.new(true, clock, store, load)
local release = presence.new(false, clock, store, load)

t.check('release alone is active', release:update() == false and release.silent == false)
t.check('dev is never silent', dev:update() == false)
t.check('dev heartbeat stored', shared[presence.KEY] == 100)
dev:update()
t.check('heartbeat written once per second', writes == 1)
t.check('release silent while dev runs', release:update() == true and release.silent == true)

now = 100 + presence.TIMEOUT
t.check('still silent within the timeout', release:update() == true)
now = 101 + presence.TIMEOUT
t.check('active again once the heartbeat is stale', release:update() == false)
dev:update()
t.check('heartbeat refreshed when the second changes', writes == 2 and shared[presence.KEY] == now)
shared[presence.KEY] = 'garbage'
t.check('unreadable heartbeat ignored', release:update() == false)

t.finish()
