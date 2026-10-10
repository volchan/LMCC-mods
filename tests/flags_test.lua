local t = require('tests/helper')
t.stubCsp()
local flags = require('src/flags')

local function valueIn(map, value)
  for _, v in pairs(map) do
    if v == value then return true end
  end
  return false
end

-- Every flag type except None has a spec, and specs are well formed.
local ids = {}
local allValid = true
for name, value in pairs(flags.FLAG) do
  local f = flags.forFlag(value)
  if name == 'None' then
    t.check('no spec for None', f == nil)
  elseif not f then
    allValid = false
    print('missing spec for ' .. name)
  else
    if ids[f.id] then allValid = false; print('duplicate id ' .. f.id) end
    ids[f.id] = true
    if not valueIn(flags.PATTERN, f.pattern) then allValid = false; print('bad pattern ' .. f.id) end
    if f.sound and not valueIn(flags.SOUND, f.sound) then allValid = false; print('bad sound ' .. f.id) end
    if f.pattern ~= flags.PATTERN.solid and not f.accent then allValid = false; print('missing accent ' .. f.id) end
    if not (f.color and f.text and f.label ~= '' and f.instruction ~= '') then allValid = false; print('incomplete ' .. f.id) end
  end
end
t.check('every flag spec valid and unique', allValid)

-- Priorities: the most dangerous signals win.
local F = flags.FLAG
t.check('red beats black', flags.forFlag(F.SessionSuspended).priority > flags.forFlag(F.Stop).priority)
t.check('black beats yellow', flags.forFlag(F.Stop).priority > flags.forFlag(F.Caution).priority)
t.check('yellow beats blue', flags.forFlag(F.Caution).priority > flags.forFlag(F.FasterCar).priority)
t.check('blue beats white', flags.forFlag(F.FasterCar).priority > flags.forFlag(F.OneLapLeft).priority)

-- Cause direction.
t.check('yellow cause is ahead', flags.forFlag(F.Caution).causeAt == flags.CAUSE.ahead)
t.check('code 60 cause is ahead', flags.forFlag(F.Code60).causeAt == flags.CAUSE.ahead)
t.check('blue cause is behind', flags.forFlag(F.FasterCar).causeAt == flags.CAUSE.behind)
t.check('checkered has no cause', flags.forFlag(F.Finished).causeAt == nil)

-- Penalties.
local P = flags.PENALTY
t.check('no spec for no penalty', flags.forPenalty(P.None) == nil)
t.check('released black flag is not a signal', flags.forPenalty(P.ReleaseBlackFlag) == nil)
t.check('black flag penalty reuses black flag', flags.forPenalty(P.BlackFlag) == flags.forFlag(F.Stop))
local penaltiesValid = true
for _, value in pairs({ P.MandatoryPits, P.TeleportToPits, P.SlowDown }) do
  local f = flags.forPenalty(value)
  if not f or not f.instruction:find('%%d') then penaltiesValid = false end
end
t.check('parametrised penalties expect a number', penaltiesValid)

-- Labels per sound cue.
local blueLabels = flags.labelsForSound(flags.SOUND.blue)
t.check('blue cue used by blue flag only', #blueLabels == 1 and blueLabels[1] == 'BLUE')
local severe = flags.labelsForSound(flags.SOUND.severe)
local blackCount, sortedLabels = 0, true
for i, l in ipairs(severe) do
  if l == 'BLACK' then blackCount = blackCount + 1 end
  if i > 1 and severe[i - 1] > l then sortedLabels = false end
end
t.check('severe labels sorted and black listed once', blackCount == 1 and sortedLabels)
local everyCueUsed = true
for _, cue in pairs(flags.SOUND) do
  if #flags.labelsForSound(cue) == 0 then everyCueUsed = false end
end
t.check('every cue is used by a flag', everyCueUsed)

-- Instruction formatting.
t.check('instruction fills parameter', flags.instruction(flags.forPenalty(P.SlowDown), 5) == 'Lift off throttle for 5 s')
t.check('instruction defaults missing parameter to 0', flags.instruction(flags.forPenalty(P.MandatoryPits)) == 'Pit within 0 laps')
t.check('instruction without placeholder unchanged', flags.instruction(flags.forFlag(F.FasterCar), 3) == 'Faster car behind: let it pass')

t.finish()
