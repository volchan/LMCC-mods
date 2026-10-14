local t = require('tests/helper')
t.stubCsp()
local ahead = require('src/gas_cut_ahead')

local me = { index = 0, name = 'Me', spline = 0.50, racePosition = 5, running = true }
local cars = {
  me,
  { index = 1, name = 'Close', spline = 0.53, racePosition = 4, running = true }, -- 120 m ahead
  { index = 2, name = 'Far', spline = 0.70, racePosition = 2, running = true }, -- 800 m ahead
  { index = 3, name = 'Behind', spline = 0.45, racePosition = 6, running = true },
  { index = 4, name = 'Pits', spline = 0.52, racePosition = 7, running = false },
  { index = 5, name = 'Wrap', spline = 0.02, racePosition = 3, running = true },
}
local cuts = { { carIndex = 2, secondsLeft = 3 }, { carIndex = 1, secondsLeft = 4 }, { carIndex = 3, secondsLeft = 2 },
  { carIndex = 4, secondsLeft = 1 }, { carIndex = 9, secondsLeft = 1 } }

local list = ahead.nearby(me, cars, cuts, 4000, 300)
t.check('only cars ahead in range and running', #list == 1 and list[1].name == 'Close' and t.near(list[1].gap, 120)
  and list[1].secondsLeft == 4 and list[1].racePosition == 4)
t.check('wider range, closest first', #ahead.nearby(me, cars, cuts, 4000, 1000) == 2
  and ahead.nearby(me, cars, cuts, 4000, 1000)[2].name == 'Far')
local nearLine = { index = 0, spline = 0.98, running = true }
t.check('ahead across the line', ahead.nearby(nearLine, cars, { { carIndex = 5 } }, 4000, 300)[1].name == 'Wrap')
t.check('own car never listed', #ahead.nearby(me, cars, { { carIndex = 0, secondsLeft = 1 } }, 4000, 300) == 0)
t.check('no list without player car', #ahead.nearby(nil, cars, cuts, 4000, 300) == 0)
t.check('no list without track length', #ahead.nearby(me, cars, cuts, 0, 300) == 0)

t.check('describe nothing', ahead.describe({}) == nil)
t.check('describe one car', ahead.describe({ { name = 'A', racePosition = 3, gap = 150, secondsLeft = 4 } })
  == 'P3 A 150 m, lift 4s')
t.check('describe without seconds', ahead.describe({ { name = 'A', racePosition = 3, gap = 150 } }) == 'P3 A 150 m')
local many = {}
for i = 1, 5 do many[i] = { name = 'C' .. i, racePosition = i, gap = i * 10 } end
t.check('describe caps names', ahead.describe(many) == 'P1 C1 10 m; P2 C2 20 m; P3 C3 30 m +2 more')

t.finish()
