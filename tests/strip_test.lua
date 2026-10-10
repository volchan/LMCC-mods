local t = require('tests/helper')
t.stubCsp()
local flags = require('src/flags')
local strip = require('src/strip')
local F = flags.FLAG

local yellow, blue = flags.forFlag(F.Caution), flags.forFlag(F.FasterCar)
local half = strip.SLIDE_TIME / 2

-- update: hidden until a flag appears
local m = strip.new()
local flag, fraction = m:update(nil, 0)
t.check('hidden without flag', flag == nil and fraction == 0)

-- slide in, eased
flag, fraction = m:update(yellow, 10)
t.check('starts hidden on appear', flag == nil and fraction == 0)
flag, fraction = m:update(yellow, 10 + half)
t.check('eased half way', flag == yellow and t.near(fraction, 0.75))
flag, fraction = m:update(yellow, 10 + strip.SLIDE_TIME * 3)
t.check('fully in after slide time', flag == yellow and fraction == 1)

-- a different flag slides in again
m:update(blue, 20)
flag, fraction = m:update(blue, 20 + half)
t.check('new flag slides in again', flag == blue and t.near(fraction, 0.75))

-- clearing slides out with the last flag
m:update(nil, 30)
flag, fraction = m:update(nil, 30 + half)
t.check('slides out showing last flag', flag == blue and t.near(fraction, 0.25))
flag, fraction = m:update(nil, 30 + strip.SLIDE_TIME)
t.check('hidden after slide out', flag == nil and fraction == 0)

-- the same flag coming back slides in again
m:update(blue, 40)
flag, fraction = m:update(blue, 40 + half)
t.check('returning flag slides in', flag == blue and t.near(fraction, 0.75))

-- scrollOffset
t.check('offset starts one period left', strip.scrollOffset(0, 100, 50) == -100)
t.check('offset moves left over time', t.near(strip.scrollOffset(1, 100, 50), -50))
t.check('offset wraps each period', t.near(strip.scrollOffset(2, 100, 50), -100))
local o = strip.scrollOffset(123.456, 100, 50)
t.check('offset stays within one period', o >= -100 and o <= 0)

t.finish()
