local function load_prolog_file()
  vim.cmd("silent write")
  local file_name = vim.api.nvim_buf_get_name(0)
  local Terminal = require("toggleterm.terminal").Terminal

  local prolog_term = Terminal:new {
    cmd = 'swipl -f "' .. file_name .. '"',
    direction = "float",
    float_opts = { border = "curved" },
    close_on_exit = true,
    on_open = function(term)
      -- Close the floating terminal with Esc
      vim.keymap.set("t", "<Esc>", function()
        term:close()
      end, { buffer = term.bufnr, desc = "Close Prolog terminal" })
    end,
  }

  prolog_term:toggle()
end

vim.keymap.set("n", "<Leader>Pp", load_prolog_file, {
  desc = "[P]rolog: load file in swipl",
  buffer = 0,
})
