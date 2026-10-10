local t = require('tests/helper')
t.stubCsp()
local flags = require('src/flags')
local signal = require('src/signal')
local tracker = require('src/tracker')
local F, P = flags.FLAG, flags.PENALTY

local YELLOW = signal.resolve(F.Caution, P.None)
local BLUE = signal.resolve(F.FasterCar, P.None)
local CLEAR = signal.resolve(F.None, P.None)

local tr = tracker.new()
t.check('defaults', tr.hold == tracker.DEFAULT_HOLD and tr.maxHistory == tracker.DEFAULT_MAX_HISTORY)
t.check('starts clear', tr.current == signal.NONE and tr:active() == nil)

-- Debounce: a flag must hold before it is reported.
t.check('new flag not reported immediately', tr:update(0.0, YELLOW) == nil)
t.check('still within hold', tr:update(0.2, YELLOW) == nil)
local ev = tr:update(0.31, YELLOW, { lap = 3, sessionTime = 120, detail = 'Incident 200 m ahead' })
t.check('reported after hold', ev and ev.from == signal.NONE and ev.to == 'yellow' and ev.signal == YELLOW[1])
t.check('no repeat while unchanged', tr:update(0.5, YELLOW) == nil)

local active = tr:active()
t.check('history entry opened with stamp', active and active.flag.id == 'yellow' and active.lap == 3
  and active.sessionTime == 120 and active.detail == 'Incident 200 m ahead' and active.startedAt == 0.31)

-- Flicker shorter than the hold is ignored.
tr:update(1.0, CLEAR)
t.check('short clear ignored', tr:update(1.1, YELLOW) == nil and tr.current == 'yellow')

-- Change to another flag closes the previous entry.
tr:update(2.0, BLUE)
ev = tr:update(2.4, BLUE)
t.check('change reported', ev and ev.from == 'yellow' and ev.to == 'blue')
t.check('previous entry closed with duration', t.near(tr.history[1].duration, 2.4 - 0.31))
t.check('blue entry without stamp', tr:active().flag.id == 'blue' and tr:active().lap == nil)

-- Clearing the track closes the entry and opens nothing.
tr:update(3.0, CLEAR)
ev = tr:update(3.5, CLEAR)
t.check('clear reported', ev and ev.to == signal.NONE and ev.signal == nil)
t.check('nothing active after clear', tr:active() == nil and #tr.history == 2)

-- History is capped.
local small = tracker.new({ hold = 0, maxHistory = 2 })
small:update(0, YELLOW)
small:update(1, BLUE)
small:update(2, YELLOW)
t.check('history capped to max', #small.history == 2 and small.history[1].flag.id == 'blue')

small:clear()
t.check('clear empties history', #small.history == 0 and small:active() == nil)

t.finish()
