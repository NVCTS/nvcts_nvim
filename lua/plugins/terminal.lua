-- ~/.config/nvim/lua/plugins/terminal.lua
-- Local terminal command: opens a floating terminal in the current file's directory

local function open_local_term()
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
    on_open = function(t)
      vim.keymap.set("t", "<Esc>", function() t:close() end, { buffer = t.bufnr, desc = "Close local terminal" })
    end,
  }
  term:toggle()
end

vim.api.nvim_create_user_command("LocalTerm", open_local_term, {
  desc = "Set terminal directory to the current buffer's directory",
})

return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    mappings = {
      n = {
        ["<Leader>tl"] = { open_local_term, desc = "[t]erminal [l]ocal to file" },
        ["<A-t>"] = { open_local_term, desc = "Terminal local to file" },
      },
    },
  },
}
