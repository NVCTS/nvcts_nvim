local function run_python_with_params()
  vim.cmd("silent write")
  local file_name = vim.api.nvim_buf_get_name(0)

  vim.ui.input({ prompt = "Parameters: " }, function(params)
    if params == nil then return end -- user cancelled
    local Terminal = require("toggleterm.terminal").Terminal
    local cmd = 'python "' .. file_name .. '"'
    if params ~= "" then
      cmd = cmd .. " " .. params
    end

    local term = Terminal:new {
      cmd = cmd,
      direction = "float",
      float_opts = { border = "curved" },
      close_on_exit = false,
      on_open = function(t)
        vim.keymap.set("t", "<Esc>", function()
          t:close()
        end, { buffer = t.bufnr, desc = "Close Python terminal" })
      end,
    }
    term:toggle()
  end)
end

vim.keymap.set("n", "<Leader>Pp", run_python_with_params, {
  desc = "[p]ython: run file with parameters",
  buffer = 0,
})
vim.keymap.set("n", "<A-x>", run_python_with_params, {
  desc = "[p]ython: run file with parameters",
  buffer = 0,
})
