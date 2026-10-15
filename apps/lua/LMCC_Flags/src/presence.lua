-- A running dev install leaves a heartbeat in the session store; a release install of the same mod
-- stays silent while it is fresh, so a flag is never shown, played or shared twice.
local M = {}
M.__index = M

-- Leading dot: temporary value, hidden from the Lua Debug app.
M.KEY = '.dazworks.flags.devAlive'
-- Seconds without a heartbeat before the release install takes over again. The clock is whole
-- seconds (shared by every script, unlike os.preciseClock), so allow one tick of slack.
M.TIMEOUT = 2

---@param dev boolean
---@param clock fun(): integer @Seconds, the same for every script.
---@param store fun(key: string, value: number)
---@param load fun(key: string): any
function M.new(dev, clock, store, load)
  return setmetatable({ dev = dev, clock = clock, store = store, load = load, beat = nil, silent = false }, M)
end

---Call once per frame.
---@return boolean @True while this install must stay silent.
function M:update()
  local now = self.clock()
  if self.dev then
    -- Written only when the second changes: the store is shared, keep frames cheap.
    if now ~= self.beat then
      self.beat = now
      self.store(M.KEY, now)
    end
    return false
  end
  local beat = tonumber(self.load(M.KEY))
  self.silent = beat ~= nil and now - beat <= M.TIMEOUT
  return self.silent
end

return M
