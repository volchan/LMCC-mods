local t = require('tests/helper')
t.stubCsp()
local uiStub = require('tests/ui_stub')
uiStub.install(vec2(300, 100))
local flags = require('src/flags')
local signal = require('src/signal')
local pulse = require('src/pulse')
local glow = require('src/glow_view')
local F, P = flags.FLAG, flags.PENALTY

local screen = vec2(1920, 1080)
local options = { glowThickness = 0.05, glowPulse = true }

t.check('thickness from shorter side', glow.thickness(screen, 0.05) == 54)

glow.draw({}, 0, screen, options)
t.check('nothing drawn without signal', #uiStub.calls == 0)

local yellow = signal.resolve(F.Caution, P.None)
glow.draw(yellow, pulse.PERIOD / 2, screen, options)
local win = uiStub.named('window')[1]
t.check('fullscreen transparent window without inputs', win and win.args[1] == glow.WINDOW_ID
  and win.args[3] == screen and win.args[4] == true and win.args[5] == false)
local bands = uiStub.named('gradient')
t.check('four edge bands', #bands == 4)
local edge = bands[1].args[3]
t.check('edge uses flag colour', edge.r == flags.forFlag(F.Caution).color.r and edge.b == flags.forFlag(F.Caution).color.b)
t.check('pulsing flag dims the edge', t.near(edge.mult, glow.STRENGTH * pulse.MIN))
t.check('inner side transparent', bands[1].args[5].mult == 0)
t.check('top band spans width at thickness', bands[1].args[2].x == 1920 and bands[1].args[2].y == 54)
t.check('right band starts at width minus thickness', bands[4].args[1].x == 1920 - 54)

uiStub.reset()
glow.draw(yellow, pulse.PERIOD / 2, screen, { glowThickness = 0.05, glowPulse = false })
t.check('pulse disabled keeps full strength', t.near(uiStub.named('gradient')[1].args[3].mult, glow.STRENGTH))

uiStub.reset()
glow.draw(signal.resolve(F.OneLapLeft, P.None), pulse.PERIOD / 2, screen, options)
t.check('non-pulsing flag keeps full strength', t.near(uiStub.named('gradient')[1].args[3].mult, glow.STRENGTH))

t.finish()
