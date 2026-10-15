-- Shared test helpers. Run tests from the repo root.
package.path = './apps/lua/Flags/?.lua;./?.lua;' .. package.path

local M = { failures = 0 }

function M.check(name, cond)
  if cond then
    print('ok   ' .. name)
  else
    M.failures = M.failures + 1
    print('FAIL ' .. name)
  end
end

function M.near(a, b, eps) return a ~= nil and b ~= nil and math.abs(a - b) <= (eps or 1e-6) end

-- Minimal stand-ins for CSP value types used at module load time.
function M.stubCsp()
  rgbm = rgbm or function(r, g, b, m) return { r = r, g = g, b = b, mult = m } end
  if not vec2 then
    local mt = {}
    vec2 = function(x, y) return setmetatable({ x = x, y = y }, mt) end
    local function lift(v) return type(v) == 'number' and vec2(v, v) or v end
    mt.__add = function(a, b) a, b = lift(a), lift(b); return vec2(a.x + b.x, a.y + b.y) end
    mt.__sub = function(a, b) a, b = lift(a), lift(b); return vec2(a.x - b.x, a.y - b.y) end
    mt.__mul = function(a, b) a, b = lift(a), lift(b); return vec2(a.x * b.x, a.y * b.y) end
    mt.__div = function(a, b) a, b = lift(a), lift(b); return vec2(a.x / b.x, a.y / b.y) end
  end
end

function M.finish()
  if M.failures > 0 then
    print(M.failures .. ' failure(s)')
    os.exit(1)
  end
  print('all passed')
end

return M
