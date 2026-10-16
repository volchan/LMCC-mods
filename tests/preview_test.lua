local t = require('tests/helper')
t.stubCsp()
local flags = require('src/flags')
local preview = require('src/preview')

local options = preview.options()
local labels, sorted = {}, true
for i, o in ipairs(options) do
  labels[o.label] = (labels[o.label] or 0) + 1
  if i > 1 and options[i - 1].priority < o.priority then sorted = false end
end
t.check('options sorted by priority', sorted)
t.check('options carry their flag spec', options[1].flag == flags.forFlag(flags.FLAG.SessionSuspended))
t.check('options start with the red flag', options[1].label == 'RED')
t.check('black flag listed once despite penalty alias', labels['BLACK'] == 1)
t.check('penalties listed', labels['GAS CUT'] == 1 and labels['DRIVE THROUGH'] == 1 and labels['PIT PENALTY'] == 1)

local flagCount = 0
for _, v in pairs(flags.FLAG) do
  if flags.forFlag(v) then flagCount = flagCount + 1 end
end
t.check('every flag, two penalties and the gas cut ahead', #options == flagCount + 3)
local aheadOption
for _, o in ipairs(options) do
  if o.flag == flags.GAS_CUT_AHEAD then aheadOption = o end
end
local ap = preview.new()
ap:start(aheadOption, 0)
t.check('gas cut ahead preview shows a sample car', ap:active(1)[1].flag == flags.GAS_CUT_AHEAD
  and ap.detail == 'P4 Sample Driver 150 m, lift 4s')

-- tie-break on label keeps order stable
local samePriority = {}
for _, o in ipairs(options) do
  samePriority[o.priority] = samePriority[o.priority] or {}
  table.insert(samePriority[o.priority], o.label)
end
local tiesOrdered = true
for _, group in pairs(samePriority) do
  for i = 2, #group do
    if group[i - 1] > group[i] then tiesOrdered = false end
  end
end
t.check('equal priorities ordered by label', tiesOrdered)

local p = preview.new()
t.check('inactive at start', p:active(0) == nil and p:remaining(0) == 0)

local gasCut
for _, o in ipairs(options) do
  if o.label == 'GAS CUT' then gasCut = o end
end
p:start(gasCut, 10)
local sig = p:active(11)
t.check('preview resolves the option', sig and sig[1].flag.id == 'gasCut')
t.check('gas cut preview shows sample seconds', sig[1].instruction == 'Lift off for ' .. preview.PENALTY_PARAMETER .. 's or drop below 35 km/h')
t.check('remaining time counts down', t.near(p:remaining(12), preview.DURATION - 2))
t.check('expires after duration', p:active(10 + preview.DURATION) == nil and p:remaining(30) == 0)
t.check('penalty preview has no location', p.detail == nil)

local F = flags.FLAG
t.check('yellow sample describes an incident', preview.sampleDetail(flags.forFlag(F.Caution), 1) == 'Incident 250 m ahead, Turn 1, Sample Driver')
local blueSpec = flags.forFlag(F.FasterCar)
t.check('blue sample lists one car', preview.sampleDetail(blueSpec, 1) == 'Let 1 car pass: P1 Leader 80 m')
t.check('blue sample lists three cars', preview.sampleDetail(blueSpec, 3) == 'Let 3 cars pass: P1 Leader 80 m, P2 Second 240 m, P3 Third 390 m')
t.check('white sample has no location', preview.sampleDetail(flags.forFlag(F.OneLapLeft), 1) == nil)

-- blue preview picks 1..3 cars through the injected random
local blueOption
for _, o in ipairs(options) do
  if o.label == 'BLUE' then blueOption = o end
end
local asked
local fixed = preview.new(function(m, n) asked = { m, n }; return 2 end)
fixed:start(blueOption, 0)
t.check('random asked for 1 to 3 cars', asked[1] == 1 and asked[2] == 3)
t.check('blue preview uses the random count', fixed.detail == preview.sampleDetail(blueSpec, 2))
local counts = {}
local seeded = preview.new()
for _ = 1, 200 do
  seeded:start(blueOption, 0)
  counts[tonumber(seeded.detail:match('Let (%d)'))] = true
end
t.check('default random covers 1 to 3 cars', counts[1] and counts[2] and counts[3] and not counts[4])

p:start(options[1], 0)
p:stop()
t.check('stop ends preview', p:active(0) == nil and p:label() == nil)

-- Several alerts combined, as the game would show them.
local byLabel = {}
for _, o in ipairs(options) do byLabel[o.label] = o end
p = preview.new(function() return 1 end)
p:start(byLabel['BLUE'], 0)
p:start(byLabel['YELLOW'], 2)
t.check('second click adds an alert, most urgent first', p:label() == 'YELLOW + BLUE')
t.check('adding restarts the time', t.near(p:remaining(3), preview.DURATION - 1))
t.check('location follows the top alert', p.detail == preview.sampleDetail(flags.forFlag(F.Caution), 1))
p:start(byLabel['YELLOW'], 3)
t.check('same alert not added twice', p:label() == 'YELLOW + BLUE')
p:start(byLabel['DRIVE THROUGH'], 3)
p:start(byLabel['GAS CUT'], 3)
t.check('gas cut hides the drive through', p:label() == 'GAS CUT + YELLOW + BLUE')
p:start(byLabel['GAS CUT AHEAD'], 3)
t.check('gas cut ahead right below the own gas cut', p:label() == 'GAS CUT + GAS CUT AHEAD + YELLOW + BLUE')
t.check('gas cut ahead cars on the location line', p.detail == 'P4 Sample Driver 150 m, lift 4s')
p:stop()
p:start(byLabel['WHITE'], 4)
t.check('a new test starts empty', p:label() == 'WHITE')

t.finish()
