-- Loads the LMCC Telemetry entry script against stubbed CSP globals and drives every callback.
local t = require('tests/helper')
t.stubCsp()
local uiStub = require('tests/ui_stub')
uiStub.install(vec2(420, 165))

-- Small JSON encoder standing in for CSP's: arrays when the table has a first item.
local function encode(v)
  if type(v) == 'string' then return string.format('%q', v) end
  if type(v) == 'number' then return string.format('%.14g', v) end
  if type(v) ~= 'table' then return tostring(v) end
  local out = {}
  if v[1] ~= nil then
    for _, item in ipairs(v) do out[#out + 1] = encode(item) end
    return '[' .. table.concat(out, ',') .. ']'
  end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do out[#out + 1] = encode(k) .. ':' .. encode(v[k]) end
  return '{' .. table.concat(out, ',') .. '}'
end

local sim = { isOnlineRace = true, isReplayActive = false, carsCount = 2 }
local function newCar(index)
  return {
    index = index, isConnected = true, position = { x = 1.234, y = 2, z = 3 }, speedKmh = 100.06,
    splinePosition = 0.5, lapCount = 3, gear = 4, isInPitlane = false, gas = 1, brake = 0, steer = -12.34,
    rpm = 7000.6, wheelsOutside = 2, collidedWith = 1, acceleration = { x = 0.5, z = -1 },
    localAngularVelocity = { y = 0.1 }, absInAction = true, tractionControlInAction = false, clutch = 1,
    handbrake = 0, fuel = 50.5, damage = { [0] = 0, 0, 0, 0, 0.25 },
    wheels = { [0] = { tyreWear = 0.1, tyreCoreTemperature = 80, tyrePressure = 27.5 } },
  }
end
local cars = { [0] = newCar(0), [1] = newCar(1) }
for w = 1, 3 do cars[0].wheels[w] = cars[0].wheels[0] end
local serverName = 'DazWorks LMCC #1'
local posts = {}
local chat, lap, online

package.loaded['src/token'] = 'tok'
ac = {
  storage = function(layout) return layout end,
  getSim = function() return sim end,
  getCar = function(i) return cars[i] end,
  getDriverName = function(i) return 'Driver ' .. i end,
  getServerName = function() return serverName end,
  getTrackID = function() return 'spa' end,
  onChatMessage = function(cb) chat = cb end,
  onLapCompleted = function(_, cb) lap = cb end,
  StructItem = { key = function(k) return k end, byte = function() end, int32 = function() end },
  OnlineEvent = function(_, cb) online = cb end,
}
web = { post = function(url, headers, body, cb) posts[#posts + 1] = { url = url, headers = headers, body = body, cb = cb } end }
JSON = {
  stringify = encode,
  parse = function(s) return s:find('expected') and { expected = { server = 'DazWorks' } } or {} end,
}
script = {}

dofile('apps/lua/LMCC_Telemetry/LMCC_Telemetry.lua')

-- Draws the window, clicking or sliding first if asked; returns its lines.
local function status(clicks, sliders)
  uiStub.reset()
  uiStub.clicks, uiStub.sliders = clicks or {}, sliders or {}
  script.windowMain(0)
  return uiStub.texts()
end

-- Server name unknown at first: nothing recorded, asked again later.
serverName = nil
script.update(0.05)
t.check('nothing sampled without a server name', status()[2] == '0 frame(s) waiting')
serverName = 'DazWorks LMCC #1'

-- One sample a 1/20 s, one request a 0.2 s.
script.update(0.05)
t.check('one frame sampled', status()[2] == '1 frame(s) waiting')
chat('CUT DETECTED', -1)
chat('hello', 1)
lap(0, 90000, true, 0, 4)
online({ index = 1 }, { code = 2, active = 1, parameter = 5 })
for _ = 1, 3 do script.update(0.05) end
t.check('one request sent', #posts == 1)
local body = posts[1].body
t.check('authorised with the token', posts[1].headers.Authorization == 'Bearer tok')
t.check('own car row', body:find('[0,1.23,2.00,3.00,100.1,0.50000,3,4,0,1.00,0.00,2,-12.3,7000,0.50,-1.00,0.100,1,0,1.00,0.00,"Driver 1",50.50,0.000,0.000,0.000,0.000,0.250,0.1000,80.0,27.50', 1, true) ~= nil)
t.check('other car row', body:find('[1,1.23,2.00,3.00,100.1,0.50000,3,4,0,1.00,0.00,2,-12.3,7000,0.50,-1.00,0.100,1,0,1.00,0.00,"Driver 1"]', 1, true) ~= nil)
t.check('frames spliced into the body', body:find('"frames":[{"t":0.100,"cars":[[0,', 1, true) and body:sub(-5) == ']]}]}')
t.check('chat sent', body:find('"CUT DETECTED"', 1, true) and body:find('"hello"', 1, true))
t.check('lap sent', body:find('"lapTimeMs":90000', 1, true) ~= nil)
t.check('penalty sent', body:find('"parameter":5', 1, true) ~= nil)
t.check('names sent', body:find('"1":"Driver 1"', 1, true) ~= nil)

-- No second request while one is on its way.
for _ = 1, 4 do script.update(0.05) end
t.check('one request at a time', #posts == 1)

-- What arrives while a request is on its way goes after the failed batch.
online(nil, { code = 2, active = 1, parameter = 6 })
online({ index = 0 }, { code = 2, active = 1, parameter = 7 })
chat('late', 1)
lap(0, 91000, false, 1, 5)

-- A failed request puts its batch back in front, then waits a second.
posts[1].cb('timeout', nil)
t.check('error shown', status()[1] == 'error: timeout')
script.update(0.05)
t.check('retry waits', #posts == 1)
for _ = 1, 20 do script.update(0.05) end
t.check('retried', #posts == 2)
t.check('failed batch sent again', posts[2].body:find('"CUT DETECTED"', 1, true) ~= nil)
t.check('later items follow', posts[2].body:find('"hello".*"late"') and posts[2].body:find('"parameter":5.*"parameter":7')
  and posts[2].body:find('91000', 1, true))
t.check('penalties heard', status()[3] == 'Penalties heard: 3 (1 own, 1 from the server, 0 not recording), 0 sent')

-- Success: back to 0.2 s.
posts[2].cb(nil, { status = 200 })
t.check('sent', status(nil, { ['##rate'] = 5 })[1]:find('^sent at') ~= nil)

-- The test penalty button only while recording.
status({ ['Send test penalty'] = true })
for _ = 1, 4 do script.update(0.2) end
t.check('test penalty sent', posts[3].body:find('"code":0', 1, true) ~= nil)
posts[3].cb(nil, { status = 200 })

-- Answers the pending request, if any, once.
local function answer(err, response)
  local post = posts[#posts]
  local cb = post.cb
  post.cb = nil
  if cb then cb(err, response) end
end

-- A long outage at 5 samples a second: the backlog keeps the last minute.
for i = 1, 600 do
  chat('spam ' .. i, 1)
  script.update(0.2)
  answer('down', nil)
end
local waiting = tonumber(status()[2]:match('^(%d+)'))
t.check('backlog trimmed to a minute', waiting <= 60 * 5 and waiting > 60 * 4)

-- Back up: the backlog goes 25 frames at a time.
for _ = 1, 60 do script.update(0.2) end
answer(nil, { status = 200 })
script.update(0.2)
local _, rows = posts[#posts].body:gsub('"t":', '')
local _, texts = posts[#posts].body:gsub('"text":', '')
t.check('backlog sent in pieces', rows - texts == 25)
t.check('chat sent in pieces', texts == 25)

-- Drained: the chat kept is the newest 500 at most.
local sent, newest = texts, false
for _ = 1, 60 do
  answer(nil, { status = 200 })
  script.update(0.2)
  sent = sent + select(2, posts[#posts].body:gsub('"text":', ''))
  newest = newest or posts[#posts].body:find('"spam 600"', 1, true) ~= nil
end
t.check('chat backlog capped', sent > 400 and sent <= 500 and newest)

-- Drains the queue, then sends a chat line in a request of its own.
local function sendAlone(text)
  for _ = 1, 60 do
    answer(nil, { status = 200 })
    script.update(0.2)
  end
  answer(nil, { status = 200 })
  chat(text, 1)
  for _ = 1, 5 do script.update(0.2) end
end

-- Too many requests or a server error: the batch is kept. Refused: dropped.
local function retried(code)
  sendAlone('code ' .. code)
  answer(nil, { status = code })
  local refusedAt, found = #posts, false
  for _ = 1, 60 do
    script.update(0.2)
    found = found or #posts > refusedAt and posts[#posts].body:find('"code ' .. code .. '"', 1, true) ~= nil
    answer(nil, { status = 200 })
  end
  return found
end
t.check('429 retried', retried(429))
t.check('500 retried', retried(500))
t.check('400 dropped', not retried(400))

-- Another server than the league's: everything dropped, nothing more sent.
sendAlone('last')
answer(nil, { status = 409, body = '{"expected":{"server":"DazWorks"}}' })
t.check('other server shown', status()[1] == 'other server, ignored (expected: DazWorks)')
local count = #posts
for _ = 1, 10 do script.update(0.2) end
t.check('quiet once ignored', #posts == count)
t.check('nothing recorded once ignored', status()[1]:find('^other server') ~= nil)

-- Loads the script afresh with another token.
local function reload(token)
  package.loaded['src/token'] = token
  posts = {}
  dofile('apps/lua/LMCC_Telemetry/LMCC_Telemetry.lua')
end

reload('')
t.check('no token shown', status()[1] == 'No token: not a release build, nothing is sent')

-- A CSP without wheelsOutside reads 0; a field failing to read shows in the window.
reload('tok')
cars[0].wheelsOutside, cars[1].wheelsOutside = nil, nil
script.update(0.05)
local position = cars[1].position
cars[1].position = nil
script.update(0.05)
t.check('read error shown', status()[1]:find('^read error') ~= nil)
cars[1].position = position
for _ = 1, 2 do script.update(0.05) end
t.check('missing field reads 0', posts[1].body:find('[1,1.23,2.00,3.00,100.1,0.50000,3,4,0,1.00,0.00,0,', 1, true) ~= nil)

-- Offline, or on another server: nothing recorded, and the window says why.
sim.isOnlineRace = false
t.check('offline shown', status()[1] == 'Offline: nothing is sent')
sim.isOnlineRace = true
serverName = 'Other server'
reload('tok')
t.check('other server shown before sending', status()[1] == 'Not the league server: nothing is sent')
chat('ignored', 1)
lap(0, 1, true, 0, 1)
online({ index = 1 }, { code = 2, active = 1, parameter = 5 })
status({ ['Send test penalty'] = true })
for _ = 1, 10 do script.update(0.2) end
t.check('nothing sent off the league server', #posts == 0)
t.check('penalty not recorded', status()[3] == 'Penalties heard: 1 (0 own, 0 from the server, 1 not recording), 0 sent')

t.finish()
