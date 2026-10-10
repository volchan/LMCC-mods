-- Fake `ui` that records draw calls, shared by view tests.
local M = { calls = {} }

local function record(name)
  return function(...)
    M.calls[#M.calls + 1] = { name = name, args = { ... } }
  end
end

function M.install(windowSize)
  M.clicks, M.sliders = {}, {}
  M.hovered, M.mouseClicks, M.active, M.delta, M.time = false, {}, false, nil, 0
  M.itemHovered = false
  M.calls = {}
  M.windowSize = windowSize
  local fakeFont = {}
  function fakeFont:weight() return self end
  function fakeFont:stretch() return self end
  ui = {
    Alignment = { Start = -1, Center = 0, End = 1 },
    MouseButton = { Left = 0, Right = 1 },
    CornerFlags = { Bottom = 12 },
    StyleColor = { Text = 0, Button = 21, ButtonHovered = 22, ButtonActive = 23 },
    TreeNodeFlags = { None = 0 },
    -- Containers record themselves and always run their content so tests see every tab.
    tabBar = function(id, flags, content)
      M.calls[#M.calls + 1] = { name = 'tabBar', args = { id } }
      ;(content or flags)()
    end,
    tabItem = function(label, flags, content)
      M.calls[#M.calls + 1] = { name = 'tab', args = { label } }
      ;(content or flags)()
    end,
    treeNode = function(label, flags, content)
      M.calls[#M.calls + 1] = { name = 'tree', args = { label } }
      ;(content or flags)()
    end,
    pushStyleColor = record('pushStyleColor'),
    popStyleColor = record('popStyleColor'),
    availableSpaceX = function() return M.windowSize.x end,
    setNextItemWidth = record('setNextItemWidth'),
    itemHovered = function() return M.itemHovered end,
    setTooltip = record('tooltip'),
    alignTextToFramePadding = record('alignText'),
    frameHeight = function() return 20 end,
    textWrapped = function(text) M.calls[#M.calls + 1] = { name = 'text', args = { text } } end,
    pathLineTo = record('pathLineTo'),
    windowHovered = function() return M.hovered end,
    mouseClicked = function(button) return M.mouseClicks[button] == true end,
    itemActive = function() return M.active end,
    mouseDelta = function() return M.delta or vec2(0, 0) end,
    time = function() return M.time end,
    setCursor = record('setCursor'),
    invisibleButton = record('invisibleButton'),
    pathClear = record('pathClear'),
    pathStroke = record('pathStroke'),
    DWriteFont = setmetatable({ Weight = { Bold = 'Bold' }, Stretch = { SemiCondensed = 'SemiCondensed' } },
      { __call = function() return fakeFont end }),
    windowSize = function() return M.windowSize end,
    pushDWriteFont = record('pushDWriteFont'),
    popDWriteFont = record('popDWriteFont'),
    dwriteDrawTextClipped = record('text'),
    drawRectFilled = record('rect'),
    drawRectFilledMultiColor = record('gradient'),
    pushClipRect = record('pushClipRect'),
    popClipRect = record('popClipRect'),
    -- Half the font size per character is close enough for layout checks.
    measureDWriteText = function(text, size) return vec2(#text * size * 0.5, size) end,
    drawCircleFilled = record('circle'),
    drawTriangleFilled = record('triangle'),
    button = function(label, size) M.calls[#M.calls + 1] = { name = 'button', args = { label, size } }; return M.clicks[label] == true end,
    checkbox = function(label, value) M.calls[#M.calls + 1] = { name = 'checkbox', args = { label, value } }; return M.clicks[label] == true end,
    slider = function(label, value, min, max, format)
      M.calls[#M.calls + 1] = { name = 'slider', args = { label, value, min, max, format } }
      local v = M.sliders[label]
      if v ~= nil then return v, true end
      return value, false
    end,
    textColored = function(text, color) M.calls[#M.calls + 1] = { name = 'text', args = { text, nil, nil, nil, nil, nil, nil, color } } end,
    text = function(text) M.calls[#M.calls + 1] = { name = 'text', args = { text } } end,
    header = function(text) M.calls[#M.calls + 1] = { name = 'header', args = { text } } end,
    separator = record('separator'),
    sameLine = record('sameLine'),
    newLine = record('newLine'),
    dummy = record('dummy'),
    getCursor = function() return vec2(10, 20) end,
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
  M.clicks, M.sliders = {}, {}
  M.hovered, M.mouseClicks, M.active, M.delta = false, {}, false, nil
  M.itemHovered = false
  M.calls = {}
end

return M
