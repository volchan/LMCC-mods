-- CSP side of the online messaging test: carries `net_probe` messages over ac.OnlineEvent and
-- describes the results with driver names for the setup window.
local probe = require('src/net_probe')

local M = {}
M.__index = M

M.KEY = 'dazworks.flags.netTest'

---@class NetStatus
---@field online boolean
---@field direct boolean @Custom server with direct messaging; otherwise messages travel as chat.
---@field pinged boolean @A ping was sent.
---@field echoMs integer? @Own ping round trip, nil until it comes back.
---@field pingMs integer @Ping to the server, -1 when unknown.
---@field echoRoute string? @One of `net_probe.ECHO`.
---@field replies {name: string, ms: integer}[] @Closest first.
---@field pingsFrom {name: string, ago: integer}[] @Seconds since their last ping.

---@param clock fun(): number @Seconds.
function M.new(clock)
  local self = setmetatable({ probe = probe.new(), clock = clock }, M)
  self.send = ac.OnlineEvent({
    ac.StructItem.key(M.KEY),
    kind = ac.StructItem.byte(),
    id = ac.StructItem.uint16(),
    replyTo = ac.StructItem.int32(),
  }, function(sender, message) self:onMessage(sender, message) end)
  return self
end

---@private
function M:onMessage(sender, message)
  local me = ac.getCar(0)
  local reply = self.probe:receive(message, sender and sender.index, sender and sender.sessionID,
    me and me.sessionID or -1, self.clock())
  if reply then self.send(reply) end
end

function M:ping()
  local message = self.probe:ping(self.clock())
  if message then self.send(message) end
end

local function byValue(map, key, scale)
  local list = {}
  for index, value in pairs(map) do
    list[#list + 1] = { name = ac.getDriverName(index) or ('Car ' .. index), [key] = math.floor(value * scale + 0.5) }
  end
  table.sort(list, function(a, b) return a[key] < b[key] end)
  return list
end

---@return NetStatus
function M:status()
  local sim, now, p, me = ac.getSim(), self.clock(), self.probe, ac.getCar(0)
  local echoMs = p.echo and math.floor(p.echo * 1000 + 0.5)
  local pingMs = me and me.ping or -1
  local ages = {}
  for index, at in pairs(p.pingsFrom) do ages[index] = now - at end
  return {
    online = sim.isOnlineRace == true,
    direct = sim.directMessagingAvailable == true,
    pinged = p.pingId > 0,
    echoMs = echoMs,
    pingMs = pingMs,
    echoRoute = echoMs and probe.echoRoute(echoMs, pingMs),
    replies = byValue(p.replies, 'ms', 1000),
    pingsFrom = byValue(ages, 'ago', 1),
  }
end

return M
