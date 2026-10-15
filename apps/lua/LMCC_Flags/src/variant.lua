-- Tells a dev install (linked by install.ps1 as <mod>_dev) from a release install, so both can
-- sit in the AC folder at once with their own window titles.
local M = {}

-- Keep in sync with install.ps1.
M.FOLDER_SUFFIX = '_dev'
M.TITLE_SUFFIX = ' (dev)'

---@param dir string @Script folder, from ac.dirname().
---@return boolean
function M.isDev(dir)
  local trimmed = dir:gsub('[/\\]+$', '')
  return trimmed:sub(-#M.FOLDER_SUFFIX) == M.FOLDER_SUFFIX
end

---@param title string @Window title of the release install.
---@param dev boolean
---@return string
function M.title(title, dev)
  return dev and title .. M.TITLE_SUFFIX or title
end

return M
