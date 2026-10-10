local t = require('tests/helper')
t.stubCsp()
local lock = require('src/lock')

local l = lock.new()
t.check('unlocked by default', l.locked == false)
t.check('starts locked when saved locked', lock.new(true).locked == true)
t.check('no animation before any toggle', l:frame(0, {}) == nil)

-- Locking: shackle swings from open to closed while the padlock dips and comes back.
t.check('toggle returns the new state', l:toggle(10) == true and l.locked)
local f = l:frame(10, {})
t.check('lock starts open, not bounced, visible', t.near(f.angle, math.pi) and f.bounce == 0 and f.wipe == 0)
f = l:frame(10 + lock.SHACKLE_TIME / 2, {})
t.check('half way: half swung, lowest point', t.near(f.angle, math.pi / 2) and t.near(f.bounce, lock.BOUNCE))
f = l:frame(10 + lock.SHACKLE_TIME, {})
t.check('closed and back up', t.near(f.angle, 0) and t.near(f.bounce, 0))

-- Wipe away after the swing.
t.check('not wiped before the wipe starts', t.near(l:frame(10 + lock.WIPE_START, {}).wipe, 0))
t.check('half wiped', t.near(l:frame(10 + (lock.WIPE_START + lock.WIPE_END) / 2, {}).wipe, 0.5))
t.check('fully wiped at the end', t.near(l:frame(10 + lock.WIPE_END, {}).wipe, 1))
t.check('animation over', l:frame(10 + lock.ANIMATION + 1e-6, {}) == nil)

-- Unlocking: the swing plays backwards, closed to open.
local out = {}
l:toggle(20)
t.check('unlock starts closed', t.near(l:frame(20, out).angle, 0) and not l.locked)
t.check('unlock ends open', t.near(l:frame(20 + lock.SHACKLE_TIME, out).angle, math.pi))
t.check('frame fills the given table', l:frame(20, out) == out)

t.finish()
