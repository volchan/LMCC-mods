local t = require('tests/helper')
t.stubCsp()
local lock = require('src/lock')

local l = lock.new()
t.check('unlocked by default', l.locked == false)
t.check('starts locked when saved locked', lock.new(true).locked == true)
t.check('no animation before any toggle', l:frame(0, {}) == nil)

-- Locking: shackle closes, padlock pops then fades.
t.check('toggle returns the new state', l:toggle(10) == true and l.locked)
local f = l:frame(10, {})
t.check('lock starts open at pop size', f.closed == 0 and f.scale == lock.POP_SCALE and f.alpha == 1)
f = l:frame(10 + lock.CLOSE_TIME / 2, {})
t.check('shackle half way eased', t.near(f.closed, 0.75))
f = l:frame(10 + lock.CLOSE_TIME, {})
t.check('lock closed at normal size', f.closed == 1 and f.scale == 1 and f.alpha == 1)
f = l:frame(10 + lock.ANIMATION - lock.FADE_TIME / 2, {})
t.check('fades out at the end', t.near(f.alpha, 0.5))
t.check('animation over', l:frame(10 + lock.ANIMATION + 1e-6, {}) == nil)

-- Unlocking: shackle opens.
local out = {}
l:toggle(20)
t.check('unlock starts closed', l:frame(20, out).closed == 1 and not l.locked)
t.check('unlock ends open', l:frame(20 + lock.CLOSE_TIME, out).closed == 0)
t.check('frame fills the given table', l:frame(20, out) == out)

t.finish()
