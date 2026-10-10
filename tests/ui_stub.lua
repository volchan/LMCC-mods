-- Fake `ui` that records draw calls, shared by view tests.
local M = { calls = {} }

local function record(name)
  return function(...)
    M.calls[#M.calls + 1] = { name = name, args = { ... } }
  end
end

function M.install(windowSize)
  M.calls = {}
  M.windowSize = windowSize
  local fakeFont = {}
  function fakeFont:weight() return self end
  function fakeFont:stretch() return self end
  ui = {
    Alignment = { Start = -1, Center = 0, End = 1 },
    DWriteFont = setmetatable({ Weight = { Bold = 'Bold' }, Stretch = { SemiCondensed = 'SemiCondensed' } },
      { __call = function() return fakeFont end }),
    windowSize = function() return M.windowSize end,
    pushDWriteFont = record('pushDWriteFont'),
    popDWriteFont = record('popDWriteFont'),
    dwriteDrawTextClipped = record('text'),
    drawRectFilled = record('rect'),
    drawRectFilledMultiColor = record('gradient'),
    drawCircleFilled = record('circle'),
    drawTriangleFilled = record('triangle'),
    transparentWindow = function(id, pos, size, noPadding, inputs, content)
      M.calls[#M.calls + 1] = { name = 'window', args = { id, pos, size, noPadding, inputs } }
      content()
    end,
  }
end

---@return table[] @Calls with the given name.
function M.named(name)
  local out = {}
  for _, c in ipairs(M.calls) do
    if c.name == name then out[#out + 1] = c end
  end
  return out
end

---@return string[] @Every text drawn, in order.
function M.texts()
  local out = {}
  for _, c in ipairs(M.named('text')) do out[#out + 1] = c.args[1] end
  return out
end

function M.reset()
  M.calls = {}
end

return M
