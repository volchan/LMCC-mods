local t = require('tests/helper')
local pulse = require('src/pulse')

t.check('no pulse is fully opaque', pulse.alpha(0.3, false) == 1)
t.check('pulse starts at full opacity', t.near(pulse.alpha(0, true), 1))
t.check('pulse reaches minimum at half period', t.near(pulse.alpha(pulse.PERIOD / 2, true), pulse.MIN))
t.check('pulse repeats every period', t.near(pulse.alpha(pulse.PERIOD * 3, true), 1))

local inRange = true
for i = 0, 100 do
  local a = pulse.alpha(i * 0.037, true)
  if a < pulse.MIN - 1e-9 or a > 1 + 1e-9 then inRange = false end
end
t.check('pulse stays within range', inRange)

t.finish()
