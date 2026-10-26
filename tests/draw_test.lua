local t = require('tests/helper')
t.stubCsp()
local uiStub = require('tests/ui_stub')
uiStub.install(vec2(400, 200))
local flags = require('src/flags')
local draw = require('src/draw')
local F = flags.FLAG

t.check('font is cached', draw.font() == draw.font())

draw.text('YELLOW', 20, vec2(0, 0), vec2(100, 30), 'c')
local call = uiStub.named('text')[1]
t.check('text defaults to start alignment, centred vertically', call.args[1] == 'YELLOW' and call.args[5] == ui.Alignment.Start
  and call.args[6] == ui.Alignment.Center and call.args[8] == 'c')
uiStub.reset()
draw.text('X', 10, vec2(0, 0), vec2(1, 1), 'c', ui.Alignment.End)
t.check('text alignment override', uiStub.named('text')[1].args[5] == ui.Alignment.End)
uiStub.reset()
draw.text('X', 13.6, vec2(0, 0), vec2(1, 1), 'c')
t.check('text size rounded to whole pixels', uiStub.named('text')[1].args[2] == 14)
t.check('font size rounds half up', draw.fontSize(12.5) == 13 and draw.fontSize(12.4) == 12)

-- dim
uiStub.reset()
draw.dim(vec2(0, 0), vec2(10, 10), 0)
t.check('no dim draws nothing', #uiStub.calls == 0)
draw.dim(vec2(0, 0), vec2(10, 10), 0.4, 3)
local rect = uiStub.named('rect')[1]
t.check('dim draws translucent black with rounding', rect and rect.args[3].mult == 0.4 and rect.args[4] == 3)
draw.dim(vec2(0, 0), vec2(10, 10), 0.2)
t.check('dim rounding defaults to 0', uiStub.named('rect')[2].args[4] == 0)

local function drawFlag(flagType)
  uiStub.reset()
  draw.flag(flags.forFlag(flagType), vec2(0, 0), vec2(60, 40))
  return uiStub.named('rect'), uiStub.named('circle'), uiStub.named('triangle')
end

local rects, circles, triangles = drawFlag(F.Caution)
t.check('solid flag is one rect in its colour', #rects == 1 and rects[1].args[3] == flags.forFlag(F.Caution).color
  and #circles == 0 and #triangles == 0)

rects = drawFlag(F.Finished)
t.check('checkered draws half the cells in accent', #rects == 1 + draw.CHECKER_COLS * draw.CHECKER_ROWS / 2
  and rects[2].args[3] == flags.forFlag(F.Finished).accent)

rects = drawFlag(F.Slippery)
t.check('stripes draw every other stripe', #rects == 1 + draw.STRIPES / 2)

rects, circles = drawFlag(F.MechanicalFailure)
t.check('disc centred with radius from shorter side', #circles == 1 and circles[1].args[1].x == 30
  and circles[1].args[1].y == 20 and circles[1].args[2] == 40 * draw.DISC_RADIUS)

rects, circles, triangles = drawFlag(F.Unsportsmanlike)
t.check('diagonal draws accent triangle', #triangles == 1 and triangles[1].args[4] == flags.forFlag(F.Unsportsmanlike).accent)

t.finish()
