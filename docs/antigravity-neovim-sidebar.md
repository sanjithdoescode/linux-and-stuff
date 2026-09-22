# Antigravity AI Assistant Neovim Sidebar

## Purpose
Integrates Google's **Antigravity CLI** directly into Neovim as a persistent, full-height **right-side sidebar**. This provides an embedded AI pair programming companion alongside your code, preserving session context across toggles and allowing seamless code references to be sent to the AI.

## Upstream Credit & Acknowledgements
This integration is powered by the Neovim plugin [`antigravity-cli.nvim`](https://github.com/NakLast/antigravity-cli.nvim) developed by **[NakLast](https://github.com/NakLast)**. Full credit goes to NakLast for creating the underlying terminal session management, buffer lifecycle, and visual line selection referencing logic.

## Implementation Details

### Files Modified & Added
* [~/.config/nvim/lua/plugins/antigravity.lua](file:///home/sanjith/.config/nvim/lua/plugins/antigravity.lua) (Plugin specification & right-side toggle wrapper)
* [~/.config/nvim/lazy-lock.json](file:///home/sanjith/.config/nvim/lazy-lock.json) (Pinned plugin commit)
* [~/.local/bin/antigravity-cli](file:///home/sanjith/.local/bin/antigravity-cli) (Executable symlink resolving to `agy`)

### 1. Neovim Plugin Specification (`antigravity.lua`)
Upstream `antigravity-cli.nvim` implements `style = "vsplit"` using `topleft vsplit`, which by default positions the split on the far left. To create an ergonomic right-side sidebar similar to modern IDEs (Cursor/Windsurf/VS Code), a toggle wrapper was added to automatically shift newly opened terminal splits to the far right using Neovim's `wincmd L` and lock its width:

```lua
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
      width_ratio = 0.35, -- 35% of editor width for sidebar
    },
    config = function(_, opts)
      local ag = require("antigravity")
      ag.setup(opts)

      -- Upstream uses "topleft vsplit" (left side). Wrap toggle to place on the right side.
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
```

### 2. CLI Executable Resolution
The Antigravity CLI binary on Omarchy is installed as `agy` at `~/.local/bin/agy`. A portable symlink was added:
```sh
ln -sf agy ~/.local/bin/antigravity-cli
```
This ensures the plugin's default executable name (`antigravity-cli`) resolves immediately without requiring additional path overrides.

---

## Features & Keybindings

| Keymap / Command | Mode | Description |
| :--- | :---: | :--- |
| `<leader>ag` | Normal | Toggle the Antigravity right sidebar open or closed |
| `:Antigravity` | Command | Command-line toggle for the sidebar |
| `<leader>as` | Normal / Visual | Send the current file and line range reference (e.g. `@src/main.rs lines:[10-25]`) to the Antigravity chat |
| `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | Terminal / Normal | Navigate between editor splits and the Antigravity sidebar |
| `<Esc><Esc>` | Terminal | Exit Neovim terminal insert mode to scroll or copy text |

---

## Usage Workflow

1. **Toggle Sidebar**:
   Press `<leader>ag` to open the Antigravity AI assistant in the right 35% of your screen.
2. **Context Retention**:
   Toggle `<leader>ag` at any time to hide the sidebar while running tests or reviewing code. When toggled back open, your entire conversation state, running tasks, and history remain intact.
3. **Send Code Reference to AI**:
   Highlight lines in visual mode (`v` or `V`) and press `<leader>as`. It switches focus to the sidebar and sends a formatted reference (e.g. `@app.lua lines:[40-52]`), ready for your prompt.
