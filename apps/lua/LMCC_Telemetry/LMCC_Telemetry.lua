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

-- The only setting left to the driver (the cog of the window), kept between runs
local settings = ac.storage({
  -- Samples a second
  rate = 20,
})

-- Often enough for the live map to follow; one request at a time
local SEND_EVERY_S = 0.2
-- What is kept while the site cannot be reached, in seconds
local MAX_PENDING_S = 60

local clock = 0
local sinceSample = 0
local sinceSend = 0
local frames = {}
local messages = {}
local laps = {}
local penalties = {}
local sending = false
local status = 'waiting'
-- Set once the site has refused this server: nothing more sent until the
-- game is restarted on another one
local ignored = false

-- Every chat line the game receives, the server's included: a penalty such as
-- "CUT DETECTED, SLOW DOWN" may only ever reach the driver, never the Server
-- Manager. ponytail: a guess that it comes as a chat line; check the first
-- batch after a cut
ac.onChatMessage(function(message, senderCarIndex)
  if not recording() then
    return
  end

  messages[#messages + 1] = {
    t = round(clock, 3),
    driver = senderCarIndex >= 0 and ac.getDriverName(senderCarIndex) or nil,
    text = message,
  }
end)

-- Each lap this game's own car completes, valid or not: the game knows at
-- once what the server only learns, and only as a count, with the lap time.
-- ponytail: own car only, the others' cuts are judged by their own games
pcall(ac.onLapCompleted, 0, function(carIndex, lapTime, valid, cuts, lapsCount)
  if not recording() then
    return
  end

  laps[#laps + 1] = {
    t = round(clock, 3),
    driver = ac.getDriverName(carIndex),
    lapTimeMs = lapTime,
    valid = valid,
    cuts = cuts,
    laps = lapsCount,
  }
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
  -- nil: sent by the server, not a driver's penalty
  if not sender or not recording() then
    return
  end

  penalties[#penalties + 1] = {
    t = round(clock, 3),
    driver = ac.getDriverName(sender.index),
    code = message.code,
    active = message.active,
    parameter = message.parameter,
  }
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

  if sinceSend >= SEND_EVERY_S and not sending and (#frames > 0 or #messages > 0 or #laps > 0 or #penalties > 0) then
    sinceSend = 0
    send()
  end
end

function script.windowMain(dt)
  ui.text(statusLine())
  ui.text(string.format('%d frame(s) waiting', #frames))
end

function script.windowSettings(dt)
  settings.rate = ui.slider('##rate', settings.rate, 5, 30, 'Samples: %.0f a second', true)
end

-- ------------------------------------------------------------------------------
-- MARK: HELPERS
-- ------------------------------------------------------------------------------

-- Online on the league's server only: solo sessions, replays and other
-- servers are nobody's business. The site checks the server again and refuses
-- any other.
function recording()
  local sim = ac.getSim()

  if TOKEN == '' or ignored or not sim.isOnlineRace or sim.isReplayActive then
    return false
  end

  return ac.getServerName():lower():find(SERVER_FILTER, 1, true) ~= nil
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
function sample()
  local cars = {}

  for i = 0, ac.getSim().carsCount - 1 do
    local car = ac.getCar(i)

    if car and car.isConnected then
      cars[#cars + 1] = {
        i,
        round(car.position.x, 2),
        round(car.position.y, 2),
        round(car.position.z, 2),
        round(car.speedKmh, 1),
        round(car.splinePosition, 5),
        car.lapCount,
        car.gear,
        car.isInPitlane and 1 or 0,
        round(car.gas, 2),
        round(car.brake, 2),
        wheelsOutside(car),
        round(car.steer, 1),
        math.floor(car.rpm),
      }
      appendInputs(cars[#cars], car)

      if i == 0 then
        appendOwnCar(cars[#cars], car)
      end
    end
  end

  frames[#frames + 1] = { t = round(clock, 3), cars = cars }
  trim(frames)
end

-- `sender` is this game's own driver, car 0; `sentAt` dates the frames
-- against the arrival time
function send()
  local batch = frames
  local said = messages
  local completed = laps
  local announced = penalties
  frames = {}
  messages = {}
  laps = {}
  penalties = {}
  sending = true

  local body = JSON.stringify({
    sender = ac.getDriverName(0),
    server = ac.getServerName(),
    track = ac.getTrackID(),
    sentAt = round(clock, 3),
    drivers = driverNames(),
    frames = batch,
    messages = said,
    laps = completed,
    penalties = announced,
  })
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
      status = 'other server, ignored (expected: '
        .. tostring(expected.expected and expected.expected.server)
        .. ')'
      return
    end

    if err or not response or response.status >= 300 then
      status = 'error: ' .. tostring(err or (response and response.status))
      restore(batch, said, completed, announced)
      return
    end

    status = 'sent at ' .. os.date('%H:%M:%S')
  end)
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

-- A failed batch goes back in front of what was taken since
function restore(batch, said, completed, announced)
  for _, frame in ipairs(frames) do
    batch[#batch + 1] = frame
  end

  for _, message in ipairs(messages) do
    said[#said + 1] = message
  end

  for _, lap in ipairs(laps) do
    completed[#completed + 1] = lap
  end

  for _, penalty in ipairs(penalties) do
    announced[#announced + 1] = penalty
  end

  frames = batch
  messages = said
  laps = completed
  penalties = announced
  trim(frames)
end

-- The oldest frames go first once the site has been away too long
function trim(list)
  while #list > MAX_PENDING_S * settings.rate do
    table.remove(list, 1)
  end
end

-- How many wheels are off the track: what a cut is judged on. Exact for this
-- game's own car only, the others' physics run in their own games.
-- ponytail: 0 when this CSP version lacks the field
function wheelsOutside(car)
  local ok, count = pcall(function()
    return car.wheelsOutside
  end)
  return ok and tonumber(count) or 0
end

-- How the car moves and how it is driven, seen from any game
function appendInputs(row, car)
  local hit = safe(function()
    return car.collidedWith
  end, -1)
  row[#row + 1] = round(safe(function()
    return car.acceleration.x
  end, 0), 2)
  row[#row + 1] = round(safe(function()
    return car.acceleration.z
  end, 0), 2)
  row[#row + 1] = round(safe(function()
    return car.localAngularVelocity.y
  end, 0), 3)
  row[#row + 1] = safe(function()
    return car.absInAction
  end, false) and 1 or 0
  row[#row + 1] = safe(function()
    return car.tractionControlInAction
  end, false) and 1 or 0
  row[#row + 1] = round(safe(function()
    return car.clutch
  end, 0), 2)
  row[#row + 1] = round(safe(function()
    return car.handbrake
  end, 0), 2)
  row[#row + 1] = hit >= 0 and (ac.getDriverName(hit) or '') or ''
end

-- Only this game simulates its own car: the others get no fuel, damage nor
-- tyres over the network
function appendOwnCar(row, car)
  row[#row + 1] = round(safe(function()
    return car.fuel
  end, 0), 2)

  for part = 0, 4 do
    row[#row + 1] = round(safe(function()
      return car.damage[part]
    end, 0), 3)
  end

  for wheel = 0, 3 do
    row[#row + 1] = round(safe(function()
      return car.wheels[wheel].tyreWear
    end, 0), 4)
    row[#row + 1] = round(safe(function()
      return car.wheels[wheel].tyreCoreTemperature
    end, 0), 1)
    row[#row + 1] = round(safe(function()
      return car.wheels[wheel].tyrePressure
    end, 0), 2)
  end
end

-- ponytail: a field this CSP version lacks reads as the fallback, the frame
-- keeps its shape
function safe(read, fallback)
  local ok, value = pcall(read)

  if ok and value ~= nil then
    return value
  end

  return fallback
end

function round(value, decimals)
  local factor = 10 ^ decimals
  return math.floor(value * factor + 0.5) / factor
end
