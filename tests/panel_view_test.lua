local t = require('tests/helper')
t.stubCsp()
local uiStub = require('tests/ui_stub')
uiStub.install(vec2(520, 130))
local flags = require('src/flags')
local signal = require('src/signal')
local panel = require('src/panel_view')
local F, P = flags.FLAG, flags.PENALTY

-- model
t.check('no model without signal', panel.model({}, nil) == nil)
local yellow = signal.resolve(F.Caution, P.None)
local m = panel.model(yellow, 'Incident 200 m ahead')
t.check('model has label, instruction, detail', m.label == 'YELLOW' and m.instruction == yellow[1].instruction
  and m.detail == 'Incident 200 m ahead' and m.extra == nil)
local both = signal.resolve(F.FasterCar, P.SlowDown, 4)
m = panel.model(both, nil)
t.check('second signal shown as extra line', m.label == 'SLOW DOWN' and m.extra == '+ BLUE: ' .. both[2].instruction)
local three = { signal.of(flags.GAS_CUT, 3), signal.of(flags.forPenalty(P.TeleportToPits), 3), signal.of(flags.forFlag(F.Caution)) }
m = panel.model(three, nil)
t.check('signals below the second are counted', m.label == 'GAS CUT'
  and m.extra == '+ DRIVE THROUGH: ' .. three[2].instruction .. ' (+1)')

-- draw idle
panel.draw({}, nil, 0)
local texts = uiStub.texts()
t.check('idle shows placeholder', #texts == 1 and texts[1] == panel.IDLE_TEXT)
t.check('idle has no background', #uiStub.named('rect') == 0)
t.check('font pushed and popped', #uiStub.named('pushDWriteFont') == 1 and #uiStub.named('popDWriteFont') == 1)

-- draw yellow with detail: pulsing flag dims the chip
uiStub.reset()
panel.draw(yellow, 'Incident 200 m ahead', 0.4)
texts = uiStub.texts()
t.check('flag texts drawn in order', texts[1] == 'YELLOW' and texts[2] == yellow[1].instruction
  and texts[3] == 'Incident 200 m ahead' and #texts == 3)
local rects = uiStub.named('rect')
t.check('background, chip and pulse overlay drawn', #rects == 3)

-- draw a non-pulsing flag with an extra line: no overlay
uiStub.reset()
local white = signal.resolve(F.OneLapLeft, P.MandatoryPits, 2)
panel.draw(white, nil, 0.4)
texts = uiStub.texts()
t.check('extra line drawn', texts[#texts] == '+ WHITE: Last lap')
uiStub.reset()
panel.draw(signal.resolve(F.OneLapLeft, P.None), nil, 0.4)
t.check('non-pulsing flag has no overlay', #uiStub.named('rect') == 2)

-- layout scales with window width
uiStub.install(vec2(1040, 260))
panel.draw(yellow, nil, 0)
local labelCall = uiStub.named('text')[1]
t.check('text scales with window size', labelCall.args[2] == 80)

-- a wide, short window scales by height so the detail line stays visible
uiStub.install(vec2(1040, 130))
panel.draw(yellow, 'Incident 200 m ahead', 0)
local calls = uiStub.named('text')
t.check('wide window scales by height', calls[1].args[2] == 40)
t.check('detail line inside window', calls[3].args[1] == 'Incident 200 m ahead' and calls[3].args[4].y <= 130)

t.check('scale by the tighter side', panel.scale(vec2(1040, 130)) == 1 and panel.scale(vec2(1040, 260)) == 2)

t.finish()
