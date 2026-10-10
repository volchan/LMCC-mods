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
t.check('options start with the red flag', options[1].label == 'RED')
t.check('black flag listed once despite penalty alias', labels['BLACK'] == 1)
t.check('penalties listed', labels['SLOW DOWN'] == 1 and labels['PIT PENALTY'] == 1)

local flagCount = 0
for _, v in pairs(flags.FLAG) do
  if flags.forFlag(v) then flagCount = flagCount + 1 end
end
t.check('every flag plus three penalties', #options == flagCount + 3)

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

local slowDown
for _, o in ipairs(options) do
  if o.label == 'SLOW DOWN' then slowDown = o end
end
p:start(slowDown, 10)
local sig = p:active(11)
t.check('preview resolves the option', sig and sig[1].flag.id == 'slowDown')
t.check('penalty preview uses sample parameter', sig[1].instruction == 'Lift off throttle for ' .. preview.PENALTY_PARAMETER .. ' s')
t.check('remaining time counts down', t.near(p:remaining(12), preview.DURATION - 2))
t.check('expires after duration', p:active(10 + preview.DURATION) == nil and p:remaining(30) == 0)
t.check('penalty preview has no location', p.detail == nil)

local F = flags.FLAG
t.check('yellow sample describes an incident', preview.sampleDetail(flags.forFlag(F.Caution)) == 'Incident 250 m ahead, Turn 1, Sample Driver')
t.check('blue sample lists lapping cars', preview.sampleDetail(flags.forFlag(F.FasterCar)) == 'Let 2 cars pass: P1 Leader 80 m, P2 Second 240 m')
t.check('white sample has no location', preview.sampleDetail(flags.forFlag(F.OneLapLeft)) == nil)

p:start(options[1], 0)
p:stop()
t.check('stop ends preview', p:active(0) == nil)

t.finish()
