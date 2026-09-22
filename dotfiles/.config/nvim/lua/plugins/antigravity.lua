return {
  {
    "NakLast/antigravity-cli.nvim",
    cmd = { "Antigravity" },
    keys = {
      { "<leader>ag", "<cmd>Antigravity<cr>", desc = "Toggle Antigravity Sidebar" },
      {
        "<leader>as",
        function()
          require("antigravity").ask_selection()
        end,
        mode = { "n", "v" },
        desc = "Send Selection to Antigravity",
      },
    },
    opts = {
      cmd = "antigravity-cli",
      style = "vsplit",
      width_ratio = 0.35,
    },
    config = function(_, opts)
      local ag = require("antigravity")
      ag.setup(opts)

      -- Move the vsplit window to the right side
      local orig_toggle = ag.toggle
      ag.toggle = function()
        local prev_win = vim.api.nvim_get_current_win()
        orig_toggle()
        local cur_win = vim.api.nvim_get_current_win()
        if cur_win ~= prev_win and vim.bo[vim.api.nvim_win_get_buf(cur_win)].buftype == "terminal" then
          vim.cmd("wincmd L")
          local width = math.floor(vim.o.columns * (ag.config.width_ratio or 0.35))
          vim.api.nvim_win_set_width(cur_win, width)
        end
      end
    end,
  },
}
