-- LMCC Telemetry: every car the game knows, sampled several times a second and
-- sent in batches to the LMCC stats site (lmcc.seygow.fr), which keeps them
-- with the session recording. The game receives the other cars far more often
-- than the Server Manager reports them: this is the fine-grained trace for the
-- stewards. Several drivers may run it at once: the site keeps each one's
-- batches and merges them.
-- Ported from the site's own app (ac-championship-stats, telemetry-app/), with
-- its address, token and server filter fixed for the league.

local ENDPOINT = 'https://lmcc.seygow.fr/api/telemetry'
-- Written into the release zip by scripts/build.sh, empty in git
local TOKEN = require('src/token')
-- A piece of the league server's name: anywhere else, nothing is sent at all
local SERVER_FILTER = 'dazworks'

-- The only setting left to the driver (the Settings tab), kept between runs
local settings = ac.storage({
  -- Samples a second
  rate = 20,
})

-- Often enough for the live map to follow; one request at a time
local SEND_EVERY_S = 0.2
-- What is kept while the site cannot be reached, in seconds
local MAX_PENDING_S = 60
-- Chat lines, laps, penalties and flags kept at most while the site cannot
-- be reached: a driver spamming the chat cannot grow them without end
local MAX_PENDING_EVENTS = 500
-- Items of each list a request carries at most: after an outage the backlog
-- goes in small pieces, never all at once in a frame
local MAX_PER_SEND = 25
-- Seconds between tries while the site fails, doubling up to this
local MAX_RETRY_S = 10
-- One car's row up to its inputs, the closing bracket left out for the own
-- car's extra values (see sample)
local ROW = '[%d,%.2f,%.2f,%.2f,%.1f,%.5f,%d,%d,%d,%.2f,%.2f,%d,%.1f,%d,%.2f,%.2f,%.3f,%d,%d,%.2f,%.2f,%s'

local clock = 0
local sinceSample = 0
local sinceSend = 0
-- Seconds between two requests: SEND_EVERY_S, longer while the site fails
local sendEvery = SEND_EVERY_S
local frames = {}
local messages = {}
local laps = {}
local penalties = {}
local raisedFlags = {}
-- LMCC Flags' announcements this app heard and sent, shown in the window:
-- whether they reach it at all
local heard = { total = 0, own = 0, server = 0, notRecording = 0, sent = 0 }
local flagsHeard = { total = 0, sent = 0 }
local sending = false
local status = 'waiting'
-- Set once the site has refused this server: nothing more sent until the
-- game is restarted on another one
local ignored = false
-- Whether this is the league's server, checked once: the name never changes
-- within a game
local onLeagueServer = nil
-- Which of the optional fields this CSP version has (see detectFields)
local fields = nil
-- Code of LMCC Flags' test penalty (src/penalty_share.lua): no penalty, it
-- proves the chain without a race. Its parameter tells who made it: 0 LMCC
-- Flags (its Setup, Network tab), 1 this window
local TEST_PENALTY = 0

-- Every chat line the game receives, the server's included: a penalty such as
-- "CUT DETECTED, SLOW DOWN" may only ever reach the driver, never the Server
-- Manager. ponytail: a guess that it comes as a chat line; check the first
-- batch after a cut
ac.onChatMessage(function(message, senderCarIndex)
  if not recording() then
    return
  end

  messages = enqueue(messages, {
    t = round(clock, 3),
    driver = senderCarIndex >= 0 and ac.getDriverName(senderCarIndex) or nil,
    text = message,
  })
end)

-- Each lap this game's own car completes, valid or not: the game knows at
-- once what the server only learns, and only as a count, with the lap time.
-- ponytail: own car only, the others' cuts are judged by their own games
pcall(ac.onLapCompleted, 0, function(carIndex, lapTime, valid, cuts, lapsCount)
  if not recording() then
    return
  end

  laps = enqueue(laps, {
    t = round(clock, 3),
    driver = ac.getDriverName(carIndex),
    lapTimeMs = lapTime,
    valid = valid,
    cuts = cuts,
    laps = lapsCount,
  })
end)

-- Every penalty LMCC Flags announces, this driver's own included (its copy
-- comes back as car 0): start and served, for the stewards. Same key and
-- layout as LMCC Flags (src/share.lua), or no message matches.
ac.OnlineEvent({
  ac.StructItem.key('dazworks.flags.penalties'),
  code = ac.StructItem.byte(),
  active = ac.StructItem.byte(),
  parameter = ac.StructItem.int32(),
}, function(sender, message)
  heard.total = heard.total + 1

  -- nil: sent by the server, not a driver's penalty
  if not sender then
    heard.server = heard.server + 1
    return
  end

  if sender.index == 0 then
    heard.own = heard.own + 1
  end

  if not recording() then
    heard.notRecording = heard.notRecording + 1
    return
  end

  -- Plain numbers, whatever the struct hands over, for the JSON
  penalties = enqueue(penalties, {
    t = round(clock, 3),
    driver = ac.getDriverName(sender.index),
    code = tonumber(message.code),
    active = tonumber(message.active),
    parameter = tonumber(message.parameter),
  })
end)

-- The race flag each LMCC Flags game raises for its driver, this one's
-- included: the yellows and blues no Server Manager reports, for the stream
-- overlays and the stewards. Same key and layout as LMCC Flags
-- (src/flag_share.lua). `cause` is a session ID: the same in every game, unlike
-- car indexes
ac.OnlineEvent({
  ac.StructItem.key('dazworks.flags.flag'),
  flag = ac.StructItem.byte(),
  cause = ac.StructItem.int32(),
}, function(sender, message)
  -- nil: sent by the server, not a driver's flag
  if not sender or not recording() then
    return
  end

  flagsHeard.total = flagsHeard.total + 1
  raisedFlags = enqueue(raisedFlags, {
    t = round(clock, 3),
    driver = ac.getDriverName(sender.index),
    flag = tonumber(message.flag),
    cause = driverBySession(tonumber(message.cause)),
  })
end)

function script.update(dt)
  clock = clock + dt
  sinceSample = sinceSample + dt
  sinceSend = sinceSend + dt

  if not recording() then
    return
  end

  if sinceSample >= 1 / settings.rate then
    sinceSample = 0
    -- A field this CSP version lacks fails here: shown in the window, not fatal
    local ok, err = pcall(sample)

    if not ok then
      status = 'read error: ' .. tostring(err)
    end
  end

  if sinceSend >= sendEvery and not sending and (#frames > 0 or #messages > 0 or #laps > 0 or #penalties > 0 or #raisedFlags > 0) then
    sinceSend = 0
    send()
  end
end

-- One window, two tabs: what is sent, and the setting
function script.windowMain(dt)
  ui.tabBar('lmccTelemetry', function()
    ui.tabItem('Status', drawStatus)
    ui.tabItem('Settings', drawSettings)
  end)
end

-- ------------------------------------------------------------------------------
-- MARK: HELPERS
-- ------------------------------------------------------------------------------

function drawStatus()
  ui.text(statusLine())
  ui.text(string.format('%d frame(s) waiting', #frames))
  ui.text(string.format('Penalties heard: %d (%d own, %d from the server, %d not recording), %d sent',
    heard.total, heard.own, heard.server, heard.notRecording, heard.sent))
  ui.text(string.format('Flags heard: %d, %d sent', flagsHeard.total, flagsHeard.sent))

  -- Only this app to the site: LMCC Flags' own test button checks the rest
  if ui.button('Send test penalty') then
    addTestPenalty()
  end
end

function drawSettings()
  settings.rate = ui.slider('##rate', settings.rate, 5, 30, 'Samples: %.0f a second', true)
end

-- Online on the league's server only: solo sessions, replays and other
-- servers are nobody's business. The site checks the server again and refuses
-- any other.
function recording()
  local sim = ac.getSim()

  if TOKEN == '' or ignored or not sim.isOnlineRace or sim.isReplayActive then
    return false
  end

  if onLeagueServer == nil then
    local name = ac.getServerName()

    -- Nil until the game knows it: asked again next frame, never cached
    if not name then
      return false
    end

    onLeagueServer = name:lower():find(SERVER_FILTER, 1, true) ~= nil
  end

  return onLeagueServer
end

function statusLine()
  if TOKEN == '' then
    return 'No token: not a release build, nothing is sent'
  end

  if not ac.getSim().isOnlineRace then
    return 'Offline: nothing is sent'
  end

  if not recording() and not ignored then
    return 'Not the league server: nothing is sent'
  end

  return status
end

-- One frame: [index, x, y, z, km/h, spline, laps, gear, in pit lane, gas, brake,
-- wheels off track, steering wheel angle in degrees, rpm, lateral G,
-- longitudinal G, yaw rate (rad/s), ABS acting (0/1), traction control acting
-- (0/1), clutch, handbrake, driver last hit ('' for none)], then for this
-- game's own car only, what the others' games do not know: [fuel (litres),
-- damage front, rear, left, right, centre, then for each tyre (front left,
-- front right, rear left, rear right) its wear, core temperature (°C) and
-- pressure (psi)] per connected car, positions in the track's world coordinates as the Server
-- Manager reports them. Indexes are this game's own: the names go with the
-- batch.
-- Each frame is JSON text from the start: no table per car for the collector,
-- and no stringify of the whole batch in the frame that sends it.
function sample()
  local cars = {}
  fields = fields or detectFields(ac.getCar(0))

  for i = 0, ac.getSim().carsCount - 1 do
    local car = ac.getCar(i)

    if car and car.isConnected then
      local p = car.position
      local row = string.format(ROW, i, p.x, p.y, p.z, car.speedKmh, car.splinePosition, car.lapCount, car.gear,
        car.isInPitlane and 1 or 0, car.gas, car.brake, wheelsOutside(car), car.steer, math.floor(car.rpm),
        inputs(car))
      cars[#cars + 1] = (i == 0 and row .. ownCar(car) or row) .. ']'
    end
  end

  frames[#frames + 1] = string.format('{"t":%.3f,"cars":[%s]}', clock, table.concat(cars, ','))
  frames = trimFrames(frames)
end

-- Off the league server nothing is recorded: the status line says why
function addTestPenalty()
  if not recording() then
    return
  end

  penalties = enqueue(penalties, {
    t = round(clock, 3),
    driver = ac.getDriverName(0),
    code = TEST_PENALTY,
    active = 1,
    parameter = 1,
  })
end

-- `sender` is this game's own driver, car 0; `sentAt` dates the frames
-- against the arrival time
function send()
  local batch, said, completed, announced, raised
  batch, frames = take(frames)
  said, messages = take(messages)
  completed, laps = take(laps)
  announced, penalties = take(penalties)
  raised, raisedFlags = take(raisedFlags)
  sending = true

  local head = JSON.stringify({
    sender = ac.getDriverName(0),
    server = ac.getServerName(),
    track = ac.getTrackID(),
    sentAt = round(clock, 3),
    drivers = driverNames(),
    messages = said,
    laps = completed,
    penalties = announced,
    flags = raised,
  })
  -- The frames are JSON text already: spliced in before the closing brace
  local body = head:sub(1, -2) .. ',"frames":[' .. table.concat(batch, ',') .. ']}'
  local headers = {
    ['Authorization'] = 'Bearer ' .. TOKEN,
    ['Content-Type'] = 'application/json',
  }

  web.post(ENDPOINT, headers, body, function(err, response)
    sending = false

    -- Another server than the league's: dropped, and the app goes quiet
    if response and response.status == 409 then
      -- What the site expected, should a name merely differ in its spelling
      local expected = JSON.parse(response.body or '{}') or {}
      ignored = true
      frames = {}
      messages = {}
      laps = {}
      penalties = {}
      raisedFlags = {}
      status = 'other server, ignored (expected: '
        .. tostring(expected.expected and expected.expected.server)
        .. ')'
      return
    end

    if err or not response or response.status >= 300 then
      status = 'error: ' .. tostring(err or (response and response.status))
      sendEvery = math.min(math.max(sendEvery * 2, 1), MAX_RETRY_S)

      -- The site refusing this batch: sent again, it would block the queue.
      -- 429 is "too many", worth a retry.
      local refused = response and response.status >= 400 and response.status < 500 and response.status ~= 429

      if not refused then
        restore(batch, said, completed, announced, raised)
      end

      return
    end

    sendEvery = SEND_EVERY_S
    heard.sent = heard.sent + #announced
    flagsHeard.sent = flagsHeard.sent + #raised
    status = 'sent at ' .. os.date('%H:%M:%S')
  end)
end

-- The oldest items of a list, MAX_PER_SEND at most, and the rest, which waits
-- its turn
function take(list)
  if #list <= MAX_PER_SEND then
    return list, {}
  end

  local batch = {}
  local rest = {}

  for index, item in ipairs(list) do
    if index <= MAX_PER_SEND then
      batch[#batch + 1] = item
    else
      rest[#rest + 1] = item
    end
  end

  return batch, rest
end

function driverNames()
  local names = {}

  for i = 0, ac.getSim().carsCount - 1 do
    local car = ac.getCar(i)

    if car and car.isConnected then
      names[tostring(i)] = ac.getDriverName(i)
    end
  end

  return names
end

-- The name of the car with this session ID, nil for none or a car gone
function driverBySession(sessionID)
  if not sessionID or sessionID < 0 then
    return nil
  end

  for i = 0, ac.getSim().carsCount - 1 do
    local car = ac.getCar(i)

    if car and car.sessionID == sessionID then
      return ac.getDriverName(i)
    end
  end

  return nil
end

-- A failed batch goes back in front of what was taken since
function restore(batch, said, completed, announced, raised)
  frames = trimFrames(append(batch, frames))
  messages = trim(append(said, messages), MAX_PENDING_EVENTS, MAX_PER_SEND)
  laps = trim(append(completed, laps), MAX_PENDING_EVENTS, MAX_PER_SEND)
  penalties = trim(append(announced, penalties), MAX_PENDING_EVENTS, MAX_PER_SEND)
  raisedFlags = trim(append(raised, raisedFlags), MAX_PENDING_EVENTS, MAX_PER_SEND)
end

-- A chat line, lap, penalty or flag at the end of its list, kept to the newest
-- MAX_PENDING_EVENTS: they may arrive faster than requests carry them
function enqueue(list, item)
  list[#list + 1] = item
  return trim(list, MAX_PENDING_EVENTS, MAX_PER_SEND)
end

function append(list, items)
  for _, item in ipairs(items) do
    list[#list + 1] = item
  end

  return list
end

-- The last minute of frames, with a second of slack so the trim runs once a
-- second at most
function trimFrames(list)
  return trim(list, MAX_PENDING_S * settings.rate, settings.rate)
end

-- The oldest items go first once the site has been away too long: `slack`
-- more than needed, in one pass, so this does not run on every new item
function trim(list, limit, slack)
  if #list <= limit then
    return list
  end

  local kept = {}

  for index = #list - limit + slack + 1, #list do
    kept[#kept + 1] = list[index]
  end

  return kept
end

-- Which of the fields read below this CSP version has, found once on the own
-- car: they are then read straight, rather than through a closure and a pcall
-- per field, car and sample, the garbage the collector stutters on.
-- ponytail: a field missing reads 0, the frame keeps its shape
function detectFields(car)
  return {
    wheelsOutside = has(function()
      return car.wheelsOutside
    end),
    collidedWith = has(function()
      return car.collidedWith
    end),
    acceleration = has(function()
      return car.acceleration.z
    end),
    angularVelocity = has(function()
      return car.localAngularVelocity.y
    end),
    abs = has(function()
      return car.absInAction
    end),
    tractionControl = has(function()
      return car.tractionControlInAction
    end),
    clutch = has(function()
      return car.clutch
    end),
    handbrake = has(function()
      return car.handbrake
    end),
    fuel = has(function()
      return car.fuel
    end),
    damage = has(function()
      return car.damage[4]
    end),
    tyres = has(function()
      local wheel = car.wheels[3]
      return wheel.tyreWear and wheel.tyreCoreTemperature and wheel.tyrePressure
    end),
  }
end

function has(read)
  local ok, value = pcall(read)
  return ok and value ~= nil
end

-- How many wheels are off the track: what a cut is judged on. Exact for this
-- game's own car only, the others' physics run in their own games.
function wheelsOutside(car)
  if not fields.wheelsOutside then
    return 0
  end

  return tonumber(car.wheelsOutside) or 0
end

-- How the car moves and how it is driven, seen from any game: the last 8
-- values of ROW
function inputs(car)
  local hit = fields.collidedWith and car.collidedWith or -1
  local acceleration = fields.acceleration and car.acceleration

  return acceleration and acceleration.x or 0,
    acceleration and acceleration.z or 0,
    fields.angularVelocity and car.localAngularVelocity.y or 0,
    fields.abs and car.absInAction and 1 or 0,
    fields.tractionControl and car.tractionControlInAction and 1 or 0,
    fields.clutch and car.clutch or 0,
    fields.handbrake and car.handbrake or 0,
    -- A driver's name may hold quotes: the JSON library escapes it
    hit >= 0 and JSON.stringify(ac.getDriverName(hit) or '') or '""'
end

-- Only this game simulates its own car: the others get no fuel, damage nor
-- tyres over the network
function ownCar(car)
  local damage = fields.damage and car.damage
  local text = string.format(',%.2f', fields.fuel and car.fuel or 0)

  for part = 0, 4 do
    text = text .. string.format(',%.3f', damage and damage[part] or 0)
  end

  for wheel = 0, 3 do
    local tyre = fields.tyres and car.wheels[wheel]
    text = text .. string.format(',%.4f,%.1f,%.2f', tyre and tyre.tyreWear or 0,
      tyre and tyre.tyreCoreTemperature or 0, tyre and tyre.tyrePressure or 0)
  end

  return text
end

function round(value, decimals)
  local factor = 10 ^ decimals
  return math.floor(value * factor + 0.5) / factor
end
