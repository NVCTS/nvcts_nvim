local function run_curr_python_file()
    -- Get file name in the current buffer
    local file_name = vim.api.nvim_buf_get_name(0)

    -- Get terminal codes for running python file
    -- ("i" to enter insert before typing rest of the command)
    local py_cmd = vim.api.nvim_replace_termcodes("ipython \"" .. file_name .. "\"<cr>", true, false, true)

    -- Determine terminal window split and launch terminal
    local percent_of_win = 0.4
    local curr_win_height = vim.api.nvim_win_get_height(0) -- Current window height
    local term_height = math.floor(curr_win_height * percent_of_win) -- Terminal height
    vim.cmd(":below " .. term_height .. "split | term") -- Launch terminal (horizontal split)

    -- Press keys to run python command on current file
    vim.api.nvim_feedkeys(py_cmd, "t", false)
end

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

vim.keymap.set({'n'}, '<A-p>', '', {
    desc = "Run .py file via Neovim built-in terminal",
    callback = run_curr_python_file
})

vim.keymap.set("n", "<Leader>Pp", run_python_with_params, {
  desc = "[P]ython: run file with parameters",
  buffer = 0,
})
