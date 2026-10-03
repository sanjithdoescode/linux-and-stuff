-- Omarchy dynamic theme loader for Neovim / LazyVim
-- Dynamically loads the active Omarchy theme spec from ~/.local/state/omarchy/current/theme/neovim.lua

local uv = vim.uv or vim.loop
local theme_file = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")

if not uv.fs_stat(theme_file) then
  local legacy_file = vim.fn.expand("~/.config/omarchy/current/theme/neovim.lua")
  if uv.fs_stat(legacy_file) then
    theme_file = legacy_file
  end
end

if uv.fs_stat(theme_file) then
  local ok, spec = pcall(dofile, theme_file)
  if ok and type(spec) == "table" then
    return spec
  end
end

return {}
