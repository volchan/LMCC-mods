local t = require('tests/helper')
t.stubCsp()
local flags = require('src/flags')
local context = require('src/context')
local F = flags.FLAG
local yellow, blue, code60 = flags.forFlag(F.Caution), flags.forFlag(F.FasterCar), flags.forFlag(F.Code60)

-- forwardDistance
t.check('distance ahead', t.near(context.forwardDistance(0.10, 0.15, 4000), 200))
t.check('distance wraps over the line', t.near(context.forwardDistance(0.95, 0.05, 4000), 400))
t.check('same position is zero', t.near(context.forwardDistance(0.5, 0.5, 4000), 0))

-- formatDistance
t.check('metres rounded to 10', context.formatDistance(347) == '350 m')
t.check('small distance', context.formatDistance(4) == '0 m')
t.check('kilometres above 1000 m', context.formatDistance(1250) == '1.3 km')

local cause = { mySpline = 0.10, causeSpline = 0.15, trackLength = 4000, causeName = 'J. Doe', causeSector = 'Turn 4' }

t.check('yellow describes incident ahead with sector and driver',
  context.describe(yellow, cause) == 'Incident 200 m ahead, Turn 4, J. Doe')
t.check('code 60 uses the same description', context.describe(code60, cause) == context.describe(yellow, cause))

local unnamed = { mySpline = 0.10, causeSpline = 0.15, trackLength = 4000, causeSector = '' }
t.check('empty sector and missing name skipped', context.describe(yellow, unnamed) == 'Incident 200 m ahead')

local behind = { mySpline = 0.50, causeSpline = 0.48, trackLength = 5000, causeName = 'A. Fast' }
t.check('blue describes faster car behind', context.describe(blue, behind) == 'Faster car 100 m behind, A. Fast')
behind.causeName = nil
t.check('blue without name', context.describe(blue, behind) == 'Faster car 100 m behind')

t.check('no description without cause', context.describe(yellow, nil) == nil)
t.check('no description without track length', context.describe(yellow, { mySpline = 0, causeSpline = 0.1, trackLength = 0 }) == nil)
t.check('no description for flags without a located cause', context.describe(flags.forFlag(F.Finished), cause) == nil)

t.finish()
