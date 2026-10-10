local t = require('tests/helper')
t.stubCsp()
local blue = require('src/blue')

local me = { index = 0, name = 'Me', spline = 0.50, racePosition = 6, running = true }
local function car(index, name, spline, pos, running)
  return { index = index, name = name, spline = spline, racePosition = pos, running = running ~= false }
end
local cars = {
  me,
  car(1, 'A. Fast', 0.48, 1),            -- 80 m behind, leader: lapping
  car(2, 'B. Quick', 0.44, 3),           -- 240 m behind: lapping
  car(3, 'Slow Guy', 0.49, 9),           -- behind but behind in race: ignore
  car(4, 'Far Away', 0.30, 2),           -- 800 m behind: out of range
  car(5, 'Ahead', 0.55, 2),              -- ahead on track: ignore
  car(6, 'Pitting', 0.49, 4, false),     -- not running: ignore
}

local list = blue.approaching(me, cars, 4000, blue.DEFAULT_RANGE)
t.check('two cars to let pass', #list == 2)
t.check('closest first', list[1].name == 'A. Fast' and list[2].name == 'B. Quick')
t.check('gap in metres', t.near(list[1].gap, 80) and list[1].racePosition == 1)

t.check('wraps over the line', #blue.approaching({ index = 0, spline = 0.01, racePosition = 5 },
  { car(1, 'X', 0.99, 1) }, 4000, 100) == 1)
t.check('no list without track length', #blue.approaching(me, cars, 0, 400) == 0)
t.check('no list without player car', #blue.approaching(nil, cars, 4000, 400) == 0)

t.check('describe nothing', blue.describe({}) == nil)
t.check('describe one car', blue.describe({ { name = 'A. Fast', racePosition = 1, gap = 80 } })
  == 'Let 1 car pass: P1 A. Fast 80 m')
t.check('describe two cars', blue.describe(list) == 'Let 2 cars pass: P1 A. Fast 80 m, P3 B. Quick 240 m')

local many = {}
for i = 1, 5 do many[i] = { name = 'C' .. i, racePosition = i, gap = i * 50 } end
t.check('describe caps names', blue.describe(many)
  == 'Let 5 cars pass: P1 C1 50 m, P2 C2 100 m, P3 C3 150 m +2 more')

t.finish()
