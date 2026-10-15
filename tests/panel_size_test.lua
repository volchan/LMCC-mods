local t = require('tests/helper')
t.stubCsp()
local panelSize = require('src/panel_size')

local prefs = { panelWidth = 0, panelHeight = 0 }
local s = panelSize.new(prefs)
t.check('no target before any resize', s:target() == nil)

local grown = s:grow(vec2(520, 130), vec2(30, 10))
t.check('grow adds the mouse movement', grown.x == 550 and grown.y == 140)
t.check('grown size saved', prefs.panelWidth == 550 and prefs.panelHeight == 140)
t.check('target is the saved size', s:target() == grown)
t.check('same table while unchanged', s:target() == s:target())

local clamped = s:grow(grown, vec2(-1000, -1000))
t.check('never below the minimum', clamped.x == panelSize.MIN_SIZE.x and clamped.y == panelSize.MIN_SIZE.y)

-- Size saved in an earlier session is applied from the start.
t.check('saved size loaded', panelSize.new({ panelWidth = 700, panelHeight = 175 }):target().x == 700)

t.finish()
