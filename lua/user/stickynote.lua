-- ~/.config/nvim/lua/user/stickynote.lua
-- Sticky note floating window with tabs, todo checkboxes, and persistence.

local M = {}

-- State
local win_id = nil
local buf_id = nil
local help_win_id = nil
local help_buf_id = nil
local data = { tabs = {}, active_tab = 1 }
local data_dir = vim.fn.stdpath("data") .. "/stickynote"
local data_file = data_dir .. "/notes.json"
local save_timer = nil

-- ── Persistence ──────────────────────────────────────────────────────

local function ensure_data_dir()
  if vim.fn.isdirectory(data_dir) == 0 then
    vim.fn.mkdir(data_dir, "p")
  end
end

local function save()
  if not buf_id or not vim.api.nvim_buf_is_valid(buf_id) then return end

  -- Sync current buffer content into the active tab before saving
  local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  if data.tabs[data.active_tab] then
    data.tabs[data.active_tab].lines = lines
  end

  ensure_data_dir()
  local json = vim.fn.json_encode(data)
  local f = io.open(data_file, "w")
  if f then
    f:write(json)
    f:close()
  end
end

local function load()
  if vim.fn.filereadable(data_file) == 0 then
    data = { tabs = { { name = "Notes", lines = {} } }, active_tab = 1 }
    return
  end
  local f = io.open(data_file, "r")
  if not f then
    data = { tabs = { { name = "Notes", lines = {} } }, active_tab = 1 }
    return
  end
  local content = f:read("*a")
  f:close()
  local ok, decoded = pcall(vim.fn.json_decode, content)
  if ok and decoded and decoded.tabs and #decoded.tabs > 0 then
    data = decoded
    -- Clamp active_tab
    if data.active_tab < 1 or data.active_tab > #data.tabs then
      data.active_tab = 1
    end
  else
    data = { tabs = { { name = "Notes", lines = {} } }, active_tab = 1 }
  end
end

-- Debounced save: coalesces rapid edits into a single write
local function schedule_save()
  if save_timer then
    save_timer:stop()
  end
  save_timer = vim.defer_fn(function()
    save()
    save_timer = nil
  end, 500)
end

-- ── Window helpers ───────────────────────────────────────────────────

local function build_title()
  local tab = data.tabs[data.active_tab]
  local name = tab and tab.name or "Notes"
  return string.format(" %s (%d/%d) ", name, data.active_tab, #data.tabs)
end

local help_lines = {
  " q/Esc  Close",
  " Tab    Next tab",
  " S-Tab  Prev tab",
  " A      Add tab",
  " D      Del/Clr tab",
  " R      Rename tab",
  " X      Clear tab",
  " Enter  Toggle [ ]",
}

local help_width = 0
for _, l in ipairs(help_lines) do
  if #l > help_width then help_width = #l end
end
help_width = help_width + 1 -- padding

local function win_config()
  local width = math.floor(vim.o.columns * 0.4)
  local height = math.floor(vim.o.lines * 0.5)
  -- Shift the main window slightly left to make room for the help panel
  local total_width = width + help_width + 3 -- 3 for borders/gap
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - total_width) / 2)
  return {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "single",
    title = build_title(),
    title_pos = "center",
  }
end

local function help_win_config()
  local cfg = win_config()
  local help_height = #help_lines
  return {
    relative = "editor",
    width = help_width,
    height = help_height,
    row = cfg.row,
    col = cfg.col + cfg.width + 2, -- 2 for border
    style = "minimal",
    border = "single",
    title = " Keymap ",
    title_pos = "center",
    focusable = false,
  }
end

local function open_help_panel()
  if help_win_id and vim.api.nvim_win_is_valid(help_win_id) then return end

  help_buf_id = vim.api.nvim_create_buf(false, true)
  vim.bo[help_buf_id].buftype = "nofile"
  vim.bo[help_buf_id].bufhidden = "wipe"
  vim.bo[help_buf_id].swapfile = false
  vim.api.nvim_buf_set_lines(help_buf_id, 0, -1, false, help_lines)
  vim.bo[help_buf_id].modifiable = false

  help_win_id = vim.api.nvim_open_win(help_buf_id, false, help_win_config())
  vim.wo[help_win_id].wrap = false
  vim.wo[help_win_id].cursorline = false
  vim.wo[help_win_id].number = false
  vim.wo[help_win_id].relativenumber = false
  vim.wo[help_win_id].signcolumn = "no"
end

local function close_help_panel()
  if help_win_id and vim.api.nvim_win_is_valid(help_win_id) then
    vim.api.nvim_win_close(help_win_id, true)
  end
  help_win_id = nil
  help_buf_id = nil
end

local function set_buf_content(lines)
  vim.bo[buf_id].modifiable = true
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines or {})
  vim.bo[buf_id].modified = false
end

local function update_title()
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_win_set_config(win_id, { title = build_title(), title_pos = "center" })
  end
end

-- ── Tab management ───────────────────────────────────────────────────

local function sync_current_tab()
  if buf_id and vim.api.nvim_buf_is_valid(buf_id) and data.tabs[data.active_tab] then
    data.tabs[data.active_tab].lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  end
end

local function switch_tab(index)
  if index < 1 or index > #data.tabs then return end
  sync_current_tab()
  data.active_tab = index
  set_buf_content(data.tabs[data.active_tab].lines)
  update_title()
end

local function next_tab()
  local next = data.active_tab + 1
  if next > #data.tabs then next = 1 end
  switch_tab(next)
end

local function prev_tab()
  local prev = data.active_tab - 1
  if prev < 1 then prev = #data.tabs end
  switch_tab(prev)
end

local function add_tab()
  sync_current_tab()
  vim.ui.input({ prompt = "Tab name: " }, function(name)
    if not name or name == "" then return end
    table.insert(data.tabs, { name = name, lines = {} })
    data.active_tab = #data.tabs
    set_buf_content({})
    update_title()
    save()
  end)
end

local function delete_tab()
  local tab_name = data.tabs[data.active_tab].name
  if #data.tabs <= 1 then
    -- Last tab: clear its content instead of deleting
    vim.ui.input({ prompt = string.format('Clear tab "%s"? (y/N): ', tab_name) }, function(input)
      if not input or input:lower() ~= "y" then return end
      set_buf_content({})
      data.tabs[data.active_tab].lines = {}
      save()
    end)
    return
  end
  vim.ui.input({ prompt = string.format('Delete tab "%s"? (y/N): ', tab_name) }, function(input)
    if not input or input:lower() ~= "y" then return end
    table.remove(data.tabs, data.active_tab)
    if data.active_tab > #data.tabs then
      data.active_tab = #data.tabs
    end
    set_buf_content(data.tabs[data.active_tab].lines)
    update_title()
    save()
  end)
end

local function rename_tab()
  local current_name = data.tabs[data.active_tab].name
  vim.ui.input({ prompt = "Rename tab: ", default = current_name }, function(name)
    if not name or name == "" then return end
    data.tabs[data.active_tab].name = name
    update_title()
    save()
  end)
end

-- ── Checkbox toggle ──────────────────────────────────────────────────

local function toggle_checkbox()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(buf_id, row - 1, row, false)[1]
  if not line then return end

  local new_line
  if line:match("%- %[x%]") then
    -- Checked -> unchecked
    new_line = line:gsub("%- %[x%]", "- [ ]", 1)
  elseif line:match("%- %[ %]") then
    -- Unchecked -> checked
    new_line = line:gsub("%- %[ %]", "- [x]", 1)
  elseif vim.trim(line) == "" then
    -- Empty line: insert a new checkbox
    new_line = line .. "- [ ] "
  else
    -- No checkbox: prepend one
    local indent = line:match("^(%s*)")
    local content = line:gsub("^%s*", "")
    new_line = indent .. "- [ ] " .. content
  end

  vim.api.nvim_buf_set_lines(buf_id, row - 1, row, false, { new_line })

  -- Place cursor at end of line for convenience
  vim.api.nvim_win_set_cursor(0, { row, #new_line })
end

-- ── Clear ────────────────────────────────────────────────────────────

local function clear_tab()
  local tab_name = data.tabs[data.active_tab].name
  vim.ui.input({ prompt = string.format('Clear tab "%s"? (y/N): ', tab_name) }, function(input)
    if not input or input:lower() ~= "y" then return end
    set_buf_content({})
    data.tabs[data.active_tab].lines = {}
    save()
  end)
end

-- ── Buffer keymaps ───────────────────────────────────────────────────

local function set_buf_keymaps()
  local opts = { buffer = buf_id, noremap = true, silent = true }

  -- Close
  vim.keymap.set("n", "q", function() M.close() end, vim.tbl_extend("force", opts, { desc = "Close sticky note" }))
  vim.keymap.set("n", "<Esc>", function() M.close() end, vim.tbl_extend("force", opts, { desc = "Close sticky note" }))

  -- Tabs
  vim.keymap.set("n", "<Tab>", next_tab, vim.tbl_extend("force", opts, { desc = "Next tab" }))
  vim.keymap.set("n", "<S-Tab>", prev_tab, vim.tbl_extend("force", opts, { desc = "Previous tab" }))
  vim.keymap.set("n", "A", add_tab, vim.tbl_extend("force", opts, { desc = "Add tab" }))
  vim.keymap.set("n", "D", delete_tab, vim.tbl_extend("force", opts, { desc = "Delete/Clear tab" }))
  vim.keymap.set("n", "R", rename_tab, vim.tbl_extend("force", opts, { desc = "Rename tab" }))

  -- Checkbox toggle
  vim.keymap.set("n", "<CR>", toggle_checkbox, vim.tbl_extend("force", opts, { desc = "Toggle checkbox" }))

  -- Clear
  vim.keymap.set("n", "X", clear_tab, vim.tbl_extend("force", opts, { desc = "Clear tab" }))
end

-- ── Buffer autocmds ──────────────────────────────────────────────────

local augroup = vim.api.nvim_create_augroup("StickyNote", { clear = true })

local function set_buf_autocmds()
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = augroup,
    buffer = buf_id,
    callback = schedule_save,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    buffer = buf_id,
    callback = function()
      save()
      win_id = nil
      close_help_panel()
    end,
  })
end

-- ── Public API ───────────────────────────────────────────────────────

function M.open()
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_set_current_win(win_id)
    return
  end

  load()

  -- Create buffer
  buf_id = vim.api.nvim_create_buf(false, true)
  vim.bo[buf_id].buftype = "nofile"
  vim.bo[buf_id].filetype = "markdown"
  vim.bo[buf_id].swapfile = false
  vim.bo[buf_id].bufhidden = "wipe"

  -- Load content
  set_buf_content(data.tabs[data.active_tab].lines)

  -- Open window
  win_id = vim.api.nvim_open_win(buf_id, true, win_config())
  vim.wo[win_id].wrap = true
  vim.wo[win_id].linebreak = true
  vim.wo[win_id].cursorline = true
  vim.wo[win_id].number = false
  vim.wo[win_id].relativenumber = false
  vim.wo[win_id].signcolumn = "no"
  vim.wo[win_id].spell = false

  set_buf_keymaps()
  set_buf_autocmds()
  open_help_panel()
end

function M.close()
  close_help_panel()
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    save()
    vim.api.nvim_win_close(win_id, true)
    win_id = nil
  end
end

function M.toggle()
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    M.close()
  else
    M.open()
  end
end

function M.clear()
  if not buf_id or not vim.api.nvim_buf_is_valid(buf_id) then
    vim.notify("Open the sticky note first", vim.log.levels.WARN)
    return
  end
  clear_tab()
end

return M
