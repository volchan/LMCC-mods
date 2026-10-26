-- Drawing primitives shared by all views: HUD font, clipped text, flag patterns.
local PATTERN = require('src/flags').PATTERN

local M = {}

M.CHECKER_COLS = 6
M.CHECKER_ROWS = 4
M.STRIPES = 6
M.DISC_RADIUS = 0.3 -- fraction of the shorter flag side

local font = nil
---Bahnschrift ships with Windows 10 and 11; DirectWrite falls back to Segoe UI otherwise.
function M.font()
  font = font or ui.DWriteFont('Bahnschrift'):weight(ui.DWriteFont.Weight.Bold)
    :stretch(ui.DWriteFont.Stretch.SemiCondensed)
  return font
end

---Whole-pixel font size: fractional sizes from the scaled panel make DirectWrite mix glyphs
---rasterized at neighbouring sizes, so some letters look bolder after a resize.
---@param size number
---@return integer
function M.fontSize(size)
  return math.floor(size + 0.5)
end

---@param align ui.Alignment? @Horizontal, default start.
function M.text(text, size, p1, p2, color, align)
  ui.dwriteDrawTextClipped(text, M.fontSize(size), p1, p2, align or ui.Alignment.Start, ui.Alignment.Center, false, color)
end

-- Reused every frame to avoid allocations.
local shade = rgbm(0, 0, 0, 0)

---Darkens an area; used to pulse anything already drawn.
---@param amount number @0 (no change) .. 1 (black).
function M.dim(p1, p2, amount, rounding)
  if amount <= 0 then return end
  shade.mult = amount
  ui.drawRectFilled(p1, p2, shade, rounding or 0)
end

local function checkered(flag, p1, p2)
  local w, h = (p2.x - p1.x) / M.CHECKER_COLS, (p2.y - p1.y) / M.CHECKER_ROWS
  for row = 0, M.CHECKER_ROWS - 1 do
    for col = 0, M.CHECKER_COLS - 1 do
      if (row + col) % 2 == 1 then
        local x, y = p1.x + col * w, p1.y + row * h
        ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), flag.accent)
      end
    end
  end
end

local function stripes(flag, p1, p2)
  local w = (p2.x - p1.x) / M.STRIPES
  for i = 1, M.STRIPES - 1, 2 do
    local x = p1.x + i * w
    ui.drawRectFilled(vec2(x, p1.y), vec2(x + w, p2.y), flag.accent)
  end
end

local function disc(flag, p1, p2)
  local r = math.min(p2.x - p1.x, p2.y - p1.y) * M.DISC_RADIUS
  ui.drawCircleFilled(vec2((p1.x + p2.x) / 2, (p1.y + p2.y) / 2), r, flag.accent, 32)
end

local function diagonal(flag, p1, p2)
  ui.drawTriangleFilled(p1, vec2(p2.x, p1.y), vec2(p1.x, p2.y), flag.accent)
end

local PAINTERS = {
  [PATTERN.checkered] = checkered,
  [PATTERN.stripes] = stripes,
  [PATTERN.disc] = disc,
  [PATTERN.diagonal] = diagonal,
}

---Draws a flag in its colours and pattern.
---@param flag FlagSpec
function M.flag(flag, p1, p2)
  ui.drawRectFilled(p1, p2, flag.color)
  local paint = PAINTERS[flag.pattern]
  if paint then paint(flag, p1, p2) end
end

return M
