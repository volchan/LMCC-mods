local t = require('tests/helper')
t.stubCsp()
local flags = require('src/flags')
local settings = require('src/settings')

local storedLayout
ac = { storage = function(layout) storedLayout = layout; return { stored = true } end }

local s = settings.load()
t.check('settings come from ac.storage', s.stored and storedLayout == settings.DEFAULTS)
t.check('defaults enable sound', settings.DEFAULTS.sound)
t.check('panel unlocked by default', settings.DEFAULTS.panelLocked == false)
t.check('strips cannot be turned off', settings.DEFAULTS.glow == nil)
t.check('default blue range', settings.DEFAULTS.blueRange == require('src/blue').DEFAULT_RANGE)

t.check('cue volume key', settings.cueVolumeKey('blue') == 'volume_blue')
local allCues = true
for _, cue in pairs(flags.SOUND) do
  if settings.DEFAULTS[settings.cueVolumeKey(cue)] ~= 1 then allCues = false end
end
t.check('every cue has a default volume of 1', allCues)

local prefs = { sound = true, volume = 0.5, volume_blue = 0.4 }
t.check('volume is master times cue', t.near(settings.volumeFor(prefs, 'blue'), 0.2))
t.check('missing cue volume counts as full', t.near(settings.volumeFor(prefs, 'info'), 0.5))
prefs.sound = false
t.check('sound off mutes everything', settings.volumeFor(prefs, 'blue') == 0)

t.finish()
