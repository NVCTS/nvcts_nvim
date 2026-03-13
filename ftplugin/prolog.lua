local function load_prolog_file()
  -- Get file name in the current buffer
  local file_name = vim.api.nvim_buf_get_name(0)

  -- Get terminal codes for running swipl with the current file
  -- ("i" to enter insert before typing rest of the command)
  local swipl_cmd = vim.api.nvim_replace_termcodes('iswipl -f "' .. file_name .. '"<cr>', true, false, true)

  -- Determine terminal window split and launch terminal
  local percent_of_win = 0.4
  local curr_win_height = vim.api.nvim_win_get_height(0)
  local term_height = math.floor(curr_win_height * percent_of_win)
  vim.cmd(":below " .. term_height .. "split | term")

  -- Press keys to run swipl command on current file
  vim.api.nvim_feedkeys(swipl_cmd, "t", false)
end

vim.keymap.set("n", "<Leader>Pp", load_prolog_file, {
  desc = "[P]rolog: load file in swipl",
  buffer = 0,
})
