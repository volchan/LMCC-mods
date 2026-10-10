local t = require('tests/helper')
t.stubCsp()
local uiStub = require('tests/ui_stub')
uiStub.install(vec2(520, 130))
local lock = require('src/lock')
local view = require('src/lock_view')

-- Padlock primitive: body, arch and two legs; the right leg lifts when open.
view.padlock(vec2(100, 100), 40, 1, 0.5)
local rects, lines = uiStub.named('rect'), uiStub.named('line')
t.check('padlock body and shackle drawn', #rects == 1 and #uiStub.named('pathArcTo') == 1
  and #uiStub.named('pathStroke') == 1 and #lines == 2)
t.check('padlock uses the given alpha', rects[1].args[3].mult == 0.5)
t.check('closed shackle legs reach the body', lines[1].args[1].y == lines[2].args[1].y)
uiStub.reset()
view.padlock(vec2(100, 100), 40, 0, 1)
lines = uiStub.named('line')
t.check('open shackle right leg lifted', lines[2].args[1].y < lines[1].args[1].y)

-- Nothing without animation or hover.
local l = lock.new()
uiStub.reset()
view.draw(l, 0, false)
t.check('hidden when idle', #uiStub.calls == 0)

-- Hover shows a small padlock in the top-right corner, matching the state.
view.draw(l, 0, true)
local body = uiStub.named('rect')[1]
local h = 130 * view.HINT_SIZE
t.check('hover padlock in the corner', body.args[2].x > 520 - 2 * h and body.args[1].y < 2 * h)
t.check('hover padlock dimmed', body.args[3].mult == view.HINT_ALPHA)

-- Toggle animation: big padlock centred on the panel.
l:toggle(5)
uiStub.reset()
view.draw(l, 5 + lock.CLOSE_TIME, false)
body = uiStub.named('rect')[1]
local height = 130 * view.SIZE
t.check('animated padlock centred and full size', t.near(body.args[1].x, 260 - height * 0.4)
  and t.near(body.args[2].y, 65 + height / 2))

t.finish()
