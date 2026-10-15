-- Online messaging test: this client pings every other Flags client and records who
-- answers, and answers their pings. Pure: messages come in and go out as plain values.
local M = {}
M.__index = M

M.KIND = { ping = 1, pong = 2 }
M.MIN_INTERVAL = 1 -- seconds between pings; the original AC server allows one message per 200 ms
M.NO_TARGET = -1 -- replyTo of a ping
M.LOCAL_MS = 5 -- an echo this fast never left this machine
-- A local copy can still arrive a frame or two later (about 8 ms each at 120 fps), so the echo
-- only proves the trip to the server when the ping is well above that.
M.MIN_PING_MS = 30
M.ECHO = { server = 'server', ['local'] = 'local', unsure = 'unsure' }

---@class NetMessage
---@field kind integer @One of `M.KIND`.
---@field id integer @Ping number, echoed by its pongs.
---@field replyTo integer @Session ID of the pinging client, `M.NO_TARGET` for pings.

function M.new()
  return setmetatable({
    pingId = 0,
    sentAt = -math.huge,
    echo = nil, ---@type number? @Seconds for the own ping to come back, nil until it does.
    replies = {}, ---@type table<integer, number> @Car index -> round trip in seconds.
    pingsFrom = {}, ---@type table<integer, number> @Car index -> time their last ping arrived.
  }, M)
end

---Starts a new ping round, nil when the last one was too recent.
---@param now number @Seconds.
---@return NetMessage?
function M:ping(now)
  if now - self.sentAt < M.MIN_INTERVAL then return nil end
  self.pingId = self.pingId % 65535 + 1 -- fits the uint16 field
  self.sentAt, self.echo, self.replies = now, nil, {}
  return { kind = M.KIND.ping, id = self.pingId, replyTo = M.NO_TARGET }
end

---Handles an incoming message.
---@param message NetMessage
---@param senderIndex integer? @Car index, 0 for this client, nil when the server sent it.
---@param senderSession integer? @Session ID of the sender.
---@param mySession integer @Session ID of this client.
---@param now number @Seconds.
---@return NetMessage? @Pong to send back, if any.
function M:receive(message, senderIndex, senderSession, mySession, now)
  if senderIndex == nil then return nil end
  if senderIndex == 0 then
    if message.kind == M.KIND.ping and message.id == self.pingId and not self.echo then self.echo = now - self.sentAt end
    return nil
  end
  if message.kind == M.KIND.ping then
    self.pingsFrom[senderIndex] = now
    return { kind = M.KIND.pong, id = message.id, replyTo = senderSession }
  end
  if message.kind == M.KIND.pong and message.replyTo == mySession and message.id == self.pingId then
    self.replies[senderIndex] = now - self.sentAt
  end
  return nil
end

---Where the own ping went, judged from its echo time against the ping to the server: with a
---ping of at least MIN_PING_MS, an echo of at least half the ping made the trip to the server
---and back. With a lower ping a delayed local copy looks the same, so it stays unsure.
---@param echoMs integer
---@param pingMs integer @-1 when unknown.
---@return string @One of `M.ECHO`.
function M.echoRoute(echoMs, pingMs)
  if pingMs >= M.MIN_PING_MS and echoMs >= pingMs / 2 then return M.ECHO.server end
  if echoMs < M.LOCAL_MS then return M.ECHO['local'] end
  return M.ECHO.unsure
end

return M
