-- Online messaging test: this client pings every other LMCC Flags client and records who
-- answers, and answers their pings. Pure: messages come in and go out as plain values.
local M = {}
M.__index = M

M.KIND = { ping = 1, pong = 2 }
M.MIN_INTERVAL = 1 -- seconds between pings; the original AC server allows one message per 200 ms
M.NO_TARGET = -1 -- replyTo of a ping

---@class NetMessage
---@field kind integer @One of `M.KIND`.
---@field id integer @Ping number, echoed by its pongs.
---@field replyTo integer @Session ID of the pinging client, `M.NO_TARGET` for pings.

function M.new()
  return setmetatable({
    pingId = 0,
    sentAt = -math.huge,
    echo = false, -- own ping came back to this client
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
  self.sentAt, self.echo, self.replies = now, false, {}
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
    if message.kind == M.KIND.ping and message.id == self.pingId then self.echo = true end
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

return M
