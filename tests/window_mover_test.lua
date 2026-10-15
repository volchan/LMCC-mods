local t = require('tests/helper')
t.stubCsp()
local layout = require('src/layout')
local mover = require('src/window_mover')

local moved, accessed, visible, resized
local ui = { uiScale = 1 }
local window = {
  size = function() return vec2(500, 100) end,
  move = function(_, pos) moved = pos end,
  setVisible = function(_, v) visible = v end,
  resize = function(_, s) resized = s end,
  valid = function() return true end,
}
ac = {
  getAppWindows = function()
    return { { name = 'other', title = 'Other' }, { name = 'lua_panel', title = 'LMCC Flags' } }
  end,
  accessAppWindow = function(name) accessed = name; return window end,
  getUI = function() return ui end,
}

t.check('finds window by title', mover.find('LMCC Flags') == window and accessed == 'lua_panel')
t.check('unknown title not found', mover.find('Nope') == nil)

t.check('show opens the window', mover.show('LMCC Flags') and visible == true)
t.check('show fails when window missing', mover.show('Nope') == false)

visible = nil
local preset = layout.PRESETS[1]
t.check('snap moves window', mover.snap('LMCC Flags', preset, vec2(1920, 1080)))
local expected = layout.position(preset, vec2(1920, 1080), vec2(500, 100))
t.check('snap uses layout position', moved.x == expected.x and moved.y == expected.y)
t.check('snap opens the window', visible == true)
t.check('resize sets the window size', mover.resize('LMCC Flags', vec2(600, 150)) and resized.x == 600)
ui.uiScale = 1.5
mover.resize('LMCC Flags', vec2(600, 150))
t.check('resize turns IMGUI units into screen pixels', resized.x == 900 and resized.y == 225)
t.check('resize fails when window missing', mover.resize('Nope', vec2(600, 150)) == false)
t.check('snap fails when window missing', mover.snap('Nope', preset, vec2(1920, 1080)) == false)

-- The accessor is kept while valid, looked up again once it is not.
local lookups = 0
local listWindows = ac.getAppWindows
ac.getAppWindows = function() lookups = lookups + 1; return listWindows() end
mover.access('LMCC Flags')
lookups = 0
t.check('valid accessor reused', mover.access('LMCC Flags') == window and lookups == 0)
window.valid = function() return false end
mover.access('LMCC Flags')
t.check('invalid accessor looked up again', lookups == 1)

t.finish()
