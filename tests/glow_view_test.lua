local t = require('tests/helper')
t.stubCsp()
local uiStub = require('tests/ui_stub')
uiStub.install(vec2(300, 100))
local flags = require('src/flags')
local signal = require('src/signal')
local pulse = require('src/pulse')
local strip = require('src/strip')
local glow = require('src/glow_view')
local F, P = flags.FLAG, flags.PENALTY

local screen = vec2(1920, 1080)
local options = { glowThickness = 0.05, glowPulse = true }
local settled = strip.SLIDE_TIME * 2

t.check('thickness from shorter side', glow.thickness(screen, 0.05) == 54)

glow.draw({}, 0, screen, options)
t.check('nothing drawn without signal', #uiStub.calls == 0)

-- yellow fully slid in, at the dimmest point of the pulse
local yellow = signal.resolve(F.Caution, P.None)
local yellowSpec = flags.forFlag(F.Caution)
glow.draw(yellow, 0, screen, options)
uiStub.reset()
glow.draw(yellow, settled + pulse.PERIOD / 2, screen, options)
local win = uiStub.named('window')[1]
t.check('fullscreen transparent window without inputs', win and win.args[1] == glow.WINDOW_ID
  and win.args[3] == screen and win.args[4] == true and win.args[5] == false)
local rects = uiStub.named('rect')
t.check('top and bottom strips', #rects == 2)
local fill = rects[1].args[3]
t.check('strip uses flag colour', fill.r == yellowSpec.color.r and fill.b == yellowSpec.color.b)
t.check('pulsing flag dims the strip', t.near(fill.mult, glow.STRENGTH * pulse.MIN))
t.check('top strip spans width at thickness', rects[1].args[1].x == 0 and rects[1].args[1].y == 0
  and rects[1].args[2].x == 1920 and rects[1].args[2].y == 54)
t.check('bottom strip on the bottom edge', rects[2].args[1].y == 1080 - 54 and rects[2].args[2].y == 1080)
t.check('text clipped to each strip', #uiStub.named('pushClipRect') == 2 and #uiStub.named('popClipRect') == 2)
t.check('font pushed and popped', #uiStub.named('pushDWriteFont') == 1 and #uiStub.named('popDWriteFont') == 1)

local texts = uiStub.named('text')
local size = 54 * glow.TEXT_SIZE
local width = #yellowSpec.label * size * 0.5
local period = width + size * strip.TEXT_GAP
local perStrip = #texts / 2
local first = texts[1]
t.check('name in flag text colour and size', first.args[1] == yellowSpec.label and first.args[2] == size
  and first.args[8] == yellowSpec.text)
t.check('first name starts left of the screen', first.args[3].x <= 0 and first.args[3].x > -period)
t.check('last name reaches the right edge', texts[perStrip].args[4].x >= 1920)

-- sliding in: top strip enters from the right, bottom from the left
glow.motion = strip.new()
glow.draw(yellow, 100, screen, options)
uiStub.reset()
glow.draw(yellow, 100 + strip.SLIDE_TIME / 2, screen, options)
rects = uiStub.named('rect')
t.check('top strip enters from the right', t.near(rects[1].args[1].x, 1920 * 0.25) and rects[1].args[2].x == 1920)
t.check('bottom strip enters from the left', rects[2].args[1].x == 0 and t.near(rects[2].args[2].x, 1920 * 0.75))

uiStub.reset()
glow.draw(yellow, 200, screen, { glowThickness = 0.05, glowPulse = false })
t.check('pulse disabled keeps full strength', t.near(uiStub.named('rect')[1].args[3].mult, glow.STRENGTH))

local white = signal.resolve(F.OneLapLeft, P.None)
glow.draw(white, 300, screen, options)
uiStub.reset()
glow.draw(white, 300 + settled + pulse.PERIOD / 2, screen, options)
t.check('non-pulsing flag keeps full strength', t.near(uiStub.named('rect')[1].args[3].mult, glow.STRENGTH))

-- clearing slides the strips out, then nothing is drawn
uiStub.reset()
glow.draw({}, 400, screen, options)
uiStub.reset()
glow.draw({}, 400 + strip.SLIDE_TIME / 2, screen, options)
t.check('strips slide out after clear', #uiStub.named('rect') == 2)
uiStub.reset()
glow.draw({}, 400 + settled, screen, options)
t.check('nothing drawn once slid out', #uiStub.calls == 0)

t.finish()
