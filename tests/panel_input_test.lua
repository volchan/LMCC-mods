local t = require('tests/helper')
t.stubCsp()
local uiStub = require('tests/ui_stub')
uiStub.install(vec2(520, 130))
local input = require('src/panel_input')

local toggles, resized = 0, nil
local actions = { toggleLock = function() toggles = toggles + 1 end, resize = function(s) resized = s end }

-- Unlocked, mouse away: grip area reserved but not drawn.
input.update(false, actions)
t.check('grip hidden without hover', #uiStub.named('triangle') == 0 and #uiStub.named('invisibleButton') == 1)
local cursor = uiStub.named('setCursor')[1].args[1]
t.check('grip in the bottom-right corner', cursor.x == 520 - input.GRIP and cursor.y == 130 - input.GRIP)

-- Hovered: grip drawn, right click toggles the lock.
uiStub.reset()
uiStub.hovered = true
uiStub.mouseClicks[ui.MouseButton.Right] = true
input.update(false, actions)
t.check('grip drawn on hover', #uiStub.named('triangle') == 1)
t.check('right click toggles the lock', toggles == 1)
t.check('no resize without drag', resized == nil)

-- Dragging the grip resizes by the mouse movement, never below the minimum size.
uiStub.reset()
uiStub.active, uiStub.delta = true, vec2(30, 10)
input.update(false, actions)
t.check('drag resizes the panel', resized.x == 550 and resized.y == 140)
t.check('grip stays drawn while dragging', #uiStub.named('triangle') == 1)
uiStub.reset()
uiStub.active, uiStub.delta = true, vec2(-1000, -1000)
input.update(false, actions)
t.check('resize clamped to the minimum', resized.x == input.MIN_SIZE.x and resized.y == input.MIN_SIZE.y)

-- Locked: full-size invisible button blocks moving, no grip even when hovered.
uiStub.reset()
uiStub.hovered = true
resized = nil
input.update(true, actions)
local button = uiStub.named('invisibleButton')[1]
t.check('locked panel covered by a button', button.args[2].x == 520 and button.args[2].y == 130)
t.check('no grip when locked', #uiStub.named('triangle') == 0 and resized == nil)
uiStub.mouseClicks[ui.MouseButton.Right] = true
input.update(true, actions)
t.check('right click unlocks too', toggles == 2)

t.finish()
