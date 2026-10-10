local t = require('tests/helper')
t.stubCsp()
local uiStub = require('tests/ui_stub')
uiStub.install(vec2(520, 130))
local lock = require('src/lock')
local view = require('src/lock_view')

-- Nothing without a recent toggle.
local l = lock.new()
view.draw(l, 0, 1)
t.check('hidden when idle', #uiStub.calls == 0)

-- Closed padlock: body, shackle path, rounded end, all clipped.
l:toggle(5)
uiStub.reset()
view.draw(l, 5 + lock.SHACKLE_TIME, 1)
local body = uiStub.named('rect')[1]
t.check('body drawn with rounded bottom', body and body.args[5] == ui.CornerFlags.Bottom)
t.check('body centred below the middle', t.near((body.args[1].x + body.args[2].x) / 2, 260)
  and (body.args[1].y + body.args[2].y) / 2 > 65)
local points = uiStub.named('pathLineTo')
t.check('shackle is one stroked path', #points == 18 and #uiStub.named('pathStroke') == 1)
t.check('shackle end rounded', #uiStub.named('circle') == 1)
t.check('clipped for the wipe', #uiStub.named('pushClipRect') == 1 and #uiStub.named('popClipRect') == 1)
local closedEnd = points[1].args[1].x

-- Open padlock: the loose leg end swings out to the other side.
uiStub.reset()
local unlocked = lock.new(true)
unlocked:toggle(30)
view.draw(unlocked, 30 + lock.SHACKLE_TIME, 1)
local openEnd = uiStub.named('pathLineTo')[1].args[1].x
t.check('open shackle end on the right of the closed one', openEnd > closedEnd)

-- Wipe slides the clip rect to the right.
uiStub.reset()
view.draw(unlocked, 30 + lock.WIPE_END, 1)
local clip = uiStub.named('pushClipRect')[1]
t.check('wipe moves the clip by twice the width', t.near(clip.args[1].x, 260 - 520 + 1040))

-- Small panels shrink the padlock, the panel scale grows it.
uiStub.install(vec2(30, 20))
local small = lock.new()
small:toggle(0)
view.draw(small, lock.SHACKLE_TIME, 1)
body = uiStub.named('rect')[1]
t.check('padlock fits a small panel', body.args[2].x - body.args[1].x < 30)
uiStub.install(vec2(520, 130))
view.draw(small, lock.SHACKLE_TIME, 2)
body = uiStub.named('rect')[1]
t.check('padlock follows the panel scale', t.near(body.args[2].x - body.args[1].x, 50 * 0.85 * 2))

t.finish()
