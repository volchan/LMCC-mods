local t = require('tests/helper')
local settings = require('src/settings')

local storedLayout
ac = { storage = function(layout) storedLayout = layout; return { stored = true } end }

local s = settings.load()
t.check('settings come from ac.storage', s.stored and storedLayout == settings.DEFAULTS)
t.check('defaults enable glow and sound', settings.DEFAULTS.glow and settings.DEFAULTS.sound)

t.finish()
