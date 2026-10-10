local t = require('tests/helper')
local sound = require('src/sound')

local events = {}
ac = {
  dirname = function() return 'C:/AC/apps/lua/LmccFlags' end,
  AudioEvent = {
    fromFile = function(params, reverb)
      local ev = { params = params, reverb = reverb, started = false, disposed = false }
      function ev:start() self.started = true end
      function ev:dispose() self.disposed = true end
      events[#events + 1] = ev
      return ev
    end,
  },
}

t.check('cue path next to script', sound.path('blue') == 'C:/AC/apps/lua/LmccFlags/sounds/blue.wav')

sound.play('caution', 0.5)
local first = events[1]
t.check('first cue started as 2D one-shot', first.started and first.params.use3D == false and first.params.loop == false
  and first.params.filename == sound.path('caution') and first.reverb == false)
t.check('volume applied', first.volume == 0.5)

sound.play('severe', 1)
t.check('previous cue disposed', first.disposed and events[2].started and not events[2].disposed)

t.finish()
