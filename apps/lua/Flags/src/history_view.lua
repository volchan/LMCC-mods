-- Flag history window: newest first, with lap, session time, duration and location.
local COLORS = require('src/theme').COLORS
local draw = require('src/draw')

local M = {}

M.CHIP = 18 -- px
M.EMPTY_TEXT = 'No flags yet this session'
M.ACTIVE_TEXT = 'active'

---@param seconds number?
---@return string @`m:ss`, `h:mm:ss`, or `--:--` when unknown.
function M.formatClock(seconds)
  if not seconds or seconds < 0 then return '--:--' end
  local s = math.floor(seconds)
  local h, m = math.floor(s / 3600), math.floor(s % 3600 / 60)
  if h > 0 then return string.format('%d:%02d:%02d', h, m, s % 60) end
  return string.format('%d:%02d', m, s % 60)
end

---@param entry HistoryEntry
---@return string
function M.formatDuration(entry)
  if not entry.duration then return M.ACTIVE_TEXT end
  return string.format('%d s', math.floor(entry.duration + 0.5))
end

---@param entry HistoryEntry
---@return string
function M.title(entry)
  local lap = entry.lap and ('Lap ' .. entry.lap) or 'Lap -'
  return string.format('%s  %s  %s  (%s)', lap, M.formatClock(entry.sessionTime), entry.flag.label, M.formatDuration(entry))
end

---@param history HistoryEntry[] @Oldest first.
---@param onClear fun()
function M.draw(history, onClear)
  if ui.button('Clear') then onClear() end
  if #history == 0 then
    ui.textColored(M.EMPTY_TEXT, COLORS.dim)
    return
  end
  local chip = vec2(M.CHIP, M.CHIP)
  for i = #history, 1, -1 do
    local entry = history[i]
    local p = ui.getCursor()
    draw.flag(entry.flag, p, p + chip)
    ui.dummy(chip)
    ui.sameLine()
    ui.textColored(M.title(entry), COLORS.textLight)
    if entry.detail then ui.textColored(entry.detail, COLORS.dim) end
  end
end

return M
