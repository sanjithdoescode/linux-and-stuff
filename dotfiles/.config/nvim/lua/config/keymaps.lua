-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Toggle bottom terminal
vim.keymap.set({ "n", "t" }, "<C-`>", function()
  Snacks.terminal(nil, { win = { position = "bottom", height = 0.3 } })
end, { desc = "Toggle Terminal (Bottom)" })

-- Fresh terminal in a new tab
vim.keymap.set({ "n", "t", "i" }, "<C-A-t>", function()
  vim.cmd("tabnew | terminal")
  vim.cmd("startinsert")
end, { desc = "Terminal (New Tab)" })
