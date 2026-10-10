local t = require('tests/helper')
t.stubCsp()
local layout = require('src/layout')

local screen, size = vec2(1920, 1080), vec2(520, 130)
local function preset(id)
  for _, p in ipairs(layout.PRESETS) do
    if p.id == id then return p end
  end
end

local p = layout.position(preset('topLeft'), screen, size)
t.check('top left keeps margin', p.x == layout.MARGIN and p.y == layout.MARGIN)
p = layout.position(preset('topCenter'), screen, size)
t.check('top centre is centred horizontally', p.x == (1920 - 520) / 2 and p.y == layout.MARGIN)
p = layout.position(preset('bottomRight'), screen, size)
t.check('bottom right keeps margin', p.x == 1920 - 520 - layout.MARGIN and p.y == 1080 - 130 - layout.MARGIN)
p = layout.position(preset('center'), screen, size, 0)
t.check('centre with custom margin', p.x == 700 and p.y == 475)

local ids, unique = {}, true
for _, pr in ipairs(layout.PRESETS) do
  if ids[pr.id] then unique = false end
  ids[pr.id] = true
end
t.check('preset ids unique', unique and #layout.PRESETS == 7)

t.finish()
