-- CSP side of penalty sharing: sends this driver's penalty changes over ac.OnlineEvent and fills
-- a board with the penalties other drivers announce.
local penaltyShare = require('src/penalty_share')

local M = {}
M.__index = M

M.KEY = 'volchan.lmccFlags.penalties'

---@param clock fun(): number @Seconds, same clock as `gasCuts`.
function M.new(clock)
  local self = setmetatable({
    sender = penaltyShare.newSender(),
    board = penaltyShare.newBoard(),
    queue = {}, ---@type ShareMessage[] @Waiting for the server rate limit.
    clock = clock,
  }, M)
  self.send = ac.OnlineEvent({
    ac.StructItem.key(M.KEY),
    code = ac.StructItem.byte(),
    active = ac.StructItem.byte(),
    parameter = ac.StructItem.int32(),
  }, function(sender, message) self:onMessage(sender, message) end)
  return self
end

---@private
function M:onMessage(sender, message)
  -- Own copies (index 0) and server messages (nil sender) are not other drivers.
  if sender and sender.index ~= 0 then self.board:receive(sender.index, message, self.clock()) end
end

---Queues what changed in this driver's penalties. Call when the signals change.
---@param signals Signal[] @This driver's real signals.
function M:announce(signals)
  for _, message in ipairs(self.sender:update(signals)) do self.queue[#self.queue + 1] = message end
  self:flush()
end

---Sends queued messages as fast as the server allows. Cheap when nothing is queued.
function M:flush()
  while self.queue[1] do
    if self.send(self.queue[1]) == false then return end -- rate limited: retry next frame
    table.remove(self.queue, 1)
  end
end

---@return SharedGasCut[]
function M:gasCuts()
  return self.board:gasCuts(self.clock())
end

return M
