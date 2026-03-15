local function run_js_file()
  vim.cmd("silent write")
  local file_name = vim.api.nvim_buf_get_name(0)
  local Terminal = require("toggleterm.terminal").Terminal

  local term = Terminal:new {
    cmd = 'node "' .. file_name .. '"',
    direction = "float",
    float_opts = { border = "curved" },
    close_on_exit = false,
    on_open = function(t)
      vim.keymap.set("t", "<Esc>", function()
        t:close()
      end, { buffer = t.bufnr, desc = "Close JavaScript terminal" })
    end,
  }
  term:toggle()
end

vim.keymap.set("n", "<Leader>Pp", run_js_file, {
  desc = "[J]avaScript: run file with node",
  buffer = 0,
})
vim.keymap.set("n", "<A-x>", run_js_file, {
  desc = "[J]avaScript: run file with node",
  buffer = 0,
})
