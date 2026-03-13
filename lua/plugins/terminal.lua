-- ~/.config/nvim/lua/plugins/terminal.lua
-- Local terminal command: opens a floating terminal in the current file's directory
return {
  {
    "AstroNvim/AstroNvim",
    event = "VeryLazy",
    config = function()
      vim.api.nvim_create_user_command("LocalTerm", function()
        local current_file_dir = vim.fn.expand "%:p:h"
        if current_file_dir ~= "." and vim.fn.isdirectory(current_file_dir) == 1 then
          vim.cmd.lcd(current_file_dir)
          vim.notify("Terminal directory set to: " .. current_file_dir, vim.log.levels.INFO)
        end
        local Terminal = require("toggleterm.terminal").Terminal
        local term = Terminal:new {
          direction = "float",
          float_opts = {
            border = "curved",
          },
        }
        term:toggle()
      end, { desc = "Set terminal directory to the current buffer's directory" })
      vim.keymap.set("n", "<leader>tl", "<cmd>LocalTerm<cr>", {
        desc = "[T]erminal directory [L]ocal to file",
      })
    end,
  },
}
