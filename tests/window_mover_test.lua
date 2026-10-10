local t = require('tests/helper')
t.stubCsp()
local layout = require('src/layout')
local mover = require('src/window_mover')

local moved, accessed
local window = { size = function() return vec2(500, 100) end, move = function(_, pos) moved = pos end }
ac = {
  getAppWindows = function()
    return { { name = 'other', title = 'Other' }, { name = 'lua_panel', title = 'LMCC Flags' } }
  end,
  accessAppWindow = function(name) accessed = name; return window end,
}

t.check('finds window by title', mover.find('LMCC Flags') == window and accessed == 'lua_panel')
t.check('unknown title not found', mover.find('Nope') == nil)

local preset = layout.PRESETS[1]
t.check('snap moves window', mover.snap('LMCC Flags', preset, vec2(1920, 1080)))
local expected = layout.position(preset, vec2(1920, 1080), vec2(500, 100))
t.check('snap uses layout position', moved.x == expected.x and moved.y == expected.y)
t.check('snap fails when window missing', mover.snap('Nope', preset, vec2(1920, 1080)) == false)

t.finish()
