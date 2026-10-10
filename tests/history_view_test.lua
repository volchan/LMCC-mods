local t = require('tests/helper')
t.stubCsp()
local uiStub = require('tests/ui_stub')
uiStub.install(vec2(400, 300))
local flags = require('src/flags')
local hv = require('src/history_view')
local F = flags.FLAG

-- formatting
t.check('clock unknown', hv.formatClock(nil) == '--:--' and hv.formatClock(-3) == '--:--')
t.check('clock minutes', hv.formatClock(754.9) == '12:34')
t.check('clock hours', hv.formatClock(3725) == '1:02:05')
t.check('duration active', hv.formatDuration({}) == hv.ACTIVE_TEXT)
t.check('duration rounded', hv.formatDuration({ duration = 7.6 }) == '8 s')

local yellow = flags.forFlag(F.Caution)
local entry = { flag = yellow, lap = 5, sessionTime = 754, duration = 8, detail = 'Incident 200 m ahead' }
t.check('title', hv.title(entry) == 'Lap 5  12:34  YELLOW  (8 s)')
t.check('title without lap', hv.title({ flag = yellow }) == 'Lap -  --:--  YELLOW  (active)')

-- draw empty
local cleared = false
hv.draw({}, function() cleared = true end)
t.check('empty history message', uiStub.texts()[1] == hv.EMPTY_TEXT and not cleared)

-- draw rows newest first, clear button
uiStub.reset()
uiStub.clicks['Clear'] = true
local blue = { flag = flags.forFlag(F.FasterCar), lap = 6, sessionTime = 800 }
hv.draw({ entry, blue }, function() cleared = true end)
local texts = uiStub.texts()
t.check('clear callback fired', cleared)
t.check('newest row first', texts[1] == hv.title(blue) and texts[2] == hv.title(entry) and texts[3] == entry.detail)
t.check('one chip per row', #uiStub.named('dummy') == 2 and #uiStub.named('rect') == 2)

t.finish()
