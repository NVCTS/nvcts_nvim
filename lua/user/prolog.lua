-- ~/.config/nvim/lua/user/prolog.lua
-- Core module for Prolog development: REPL, query runner, outline, docs, debug.

local M = {}

-------------------------------------------------------------------------------
-- REPL (toggleterm-based)
-------------------------------------------------------------------------------

local _repl_term = nil
local REPL_COUNT = 42 -- dedicated toggleterm count to avoid collisions

--- Get or create the persistent swipl REPL terminal.
---@return Terminal
local function get_repl()
  local Terminal = require("toggleterm.terminal").Terminal
  if not _repl_term then
    _repl_term = Terminal:new({
      cmd = "swipl",
      count = REPL_COUNT,
      direction = "vertical",
      display_name = "swipl REPL",
      hidden = true,
      close_on_exit = true,
      on_open = function(t)
        vim.keymap.set(
          "t",
          "<Esc>",
          function() t:close() end,
          { buffer = t.bufnr, desc = "Close Prolog REPL" }
        )
      end,
      on_exit = function()
        _repl_term = nil
      end,
    })
  end
  return _repl_term
end

--- Repl split size (50% of screen width).
---@return number
local function repl_size()
  return math.floor(vim.o.columns * 0.5)
end

--- Focus the REPL window and enter terminal insert mode.
---@param term Terminal
local function focus_repl(term)
  if term.window and vim.api.nvim_win_is_valid(term.window) then
    vim.api.nvim_set_current_win(term.window)
  end
  vim.cmd("startinsert")
end

--- Ensure the REPL is open (at half-screen width), focused, and interactive.
---@return Terminal
local function ensure_repl_open()
  local term = get_repl()
  if not term:is_open() then
    term:open(repl_size())
  end
  focus_repl(term)
  return term
end

--- Toggle the swipl REPL (opens at 50% screen width).
function M.repl_toggle()
  local term = get_repl()
  if term:is_open() then
    term:close()
  else
    term:open(repl_size())
    focus_repl(term)
  end
end

--- Consult (load) the current file in the REPL.
function M.repl_consult()
  local file = vim.fn.expand("%:p")
  if file == "" then
    vim.notify("No file to consult", vim.log.levels.WARN)
    return
  end
  local term = ensure_repl_open()
  -- Escape single quotes in file path
  file = file:gsub("'", "\\'")
  term:send(string.format("['%s'].", file), false)
  vim.notify("Consulted: " .. vim.fn.expand("%:t"), vim.log.levels.INFO)
end

--- Send text to the REPL.
---@param text string
local function repl_send(text)
  local term = ensure_repl_open()
  -- Strip leading/trailing whitespace
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  -- Ensure the text ends with a period for Prolog queries
  if not text:match("%.$") then
    text = text .. "."
  end
  term:send(text, false)
end

--- Send current line to the REPL.
function M.repl_send_line()
  local line = vim.api.nvim_get_current_line()
  repl_send(line)
end

--- Send visual selection to the REPL.
function M.repl_send_selection()
  -- Exit visual mode to update marks
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
  local start_pos = vim.api.nvim_buf_get_mark(0, "<")
  local end_pos = vim.api.nvim_buf_get_mark(0, ">")
  local lines = vim.api.nvim_buf_get_lines(0, start_pos[1] - 1, end_pos[1], false)
  if #lines == 0 then return end
  -- Trim the last line to the selection end column
  if #lines == 1 then
    lines[1] = lines[1]:sub(start_pos[2] + 1, end_pos[2] + 1)
  else
    lines[1] = lines[1]:sub(start_pos[2] + 1)
    lines[#lines] = lines[#lines]:sub(1, end_pos[2] + 1)
  end
  local text = table.concat(lines, " ")
  repl_send(text)
end

-------------------------------------------------------------------------------
-- Query Runner
-------------------------------------------------------------------------------

--- Parse a query from a line of text.
--- Supports lines like:
---   %?- member(X, [1,2,3]).
---   ?- member(X, [1,2,3]).
---   member(X, [1,2,3]).
---@param line string
---@return string?
local function parse_query(line)
  -- Strip comment prefix and query prompt
  local query = line:match("^%%?%s*%?%-%s*(.+)") or line:match("^%s*(.+)")
  if not query or query:match("^%s*$") then return nil end
  -- Strip trailing whitespace
  query = query:gsub("%s+$", "")
  -- Ensure it ends with a period
  if not query:match("%.$") then
    query = query .. "."
  end
  return query
end

--- Display text in a floating scratch buffer.
---@param title string
---@param lines string[]
local function show_float(title, lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "prolog"

  local width = 10
  for _, l in ipairs(lines) do
    width = math.max(width, #l)
  end
  width = math.min(width + 4, math.floor(vim.o.columns * 0.8))
  local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.6))

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })

  -- Press q or Esc to close
  local close = function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true })
end

--- Run a Prolog query and display results in a float.
---@param all_solutions boolean if true, find all solutions
function M.run_query(all_solutions)
  local line = vim.api.nvim_get_current_line()
  local query = parse_query(line)
  if not query then
    vim.notify("No query found on current line", vim.log.levels.WARN)
    return
  end

  local file = vim.fn.expand("%:p")
  local goal
  if all_solutions then
    -- Wrap in forall to print all solutions
    -- Strip trailing period for embedding
    local q = query:gsub("%.$", "")
    goal = string.format(
      "consult('%s'), forall((%s), (numbervars((%s), 0, _), writeln((%s)))), halt.",
      file:gsub("'", "\\'"), q, q, q
    )
  else
    -- Single solution
    local q = query:gsub("%.$", "")
    goal = string.format(
      "consult('%s'), ((%s) -> (numbervars((%s), 0, _), writeln((%s))) ; writeln('false')), halt.",
      file:gsub("'", "\\'"), q, q, q
    )
  end

  local stdout_lines = {}
  local stderr_lines = {}

  vim.fn.jobstart({ "swipl", "-g", goal, "-t", "halt" }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, l in ipairs(data) do
          if l ~= "" then table.insert(stdout_lines, l) end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, l in ipairs(data) do
          if l ~= "" then table.insert(stderr_lines, l) end
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        local result = {}
        if #stderr_lines > 0 then
          table.insert(result, "--- ERRORS ---")
          vim.list_extend(result, stderr_lines)
        end
        if #stdout_lines > 0 then
          if #result > 0 then table.insert(result, "") end
          vim.list_extend(result, stdout_lines)
        end
        if #result == 0 then
          if exit_code == 0 then
            result = { "true (no bindings)" }
          else
            result = { "Query failed (exit code: " .. exit_code .. ")" }
          end
        end
        local title = all_solutions and "All Solutions" or "Query Result"
        show_float(title, result)
      end)
    end,
  })
end

-------------------------------------------------------------------------------
-- Predicate Navigator / Outline (Telescope)
-------------------------------------------------------------------------------

--- Collect predicate definitions from the current buffer using treesitter.
---@return table[] list of {name, arity, lnum, col}
local function collect_predicates()
  local bufnr = vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(bufnr, "prolog")
  if not parser then return {} end

  local tree = parser:parse()[1]
  if not tree then return {} end

  local root = tree:root()
  local predicates = {}
  local seen = {} -- track name/arity to mark first occurrence

  -- Walk top-level children looking for clause nodes
  for child in root:iter_children() do
    local type = child:type()
    if type == "clause" or type == "directive_term" or type == "fact" then
      -- Try to extract the clause head
      local head = nil
      for sub in child:iter_children() do
        local stype = sub:type()
        if stype == "compound_term" or stype == "atom" or stype == "functional_notation" then
          head = sub
          break
        end
      end

      if head then
        local name_node = head
        local arity = 0

        if head:type() == "compound_term" or head:type() == "functional_notation" then
          -- First child is typically the functor name
          local functor = head:child(0)
          if functor then
            name_node = functor
          end
          -- Count argument nodes (look for argument lists)
          local args = head:field("arguments") or {}
          if #args > 0 then
            arity = #args
          else
            -- Fallback: count children that look like arguments
            local arg_count = 0
            for sub in head:iter_children() do
              local st = sub:type()
              if st ~= "atom" and st ~= "(" and st ~= ")" and st ~= "," and st ~= "functor" then
                arg_count = arg_count + 1
              end
            end
            if arg_count > 0 then arity = arg_count end
          end
        end

        local name = vim.treesitter.get_node_text(name_node, bufnr)
        local row, col = child:start()
        local key = name .. "/" .. arity
        local is_first = not seen[key]
        seen[key] = true

        table.insert(predicates, {
          name = name,
          arity = arity,
          lnum = row + 1,
          col = col + 1,
          key = key,
          is_first = is_first,
        })
      end
    end
  end

  return predicates
end

--- Open a Telescope picker to navigate predicates in the current buffer.
function M.predicate_outline()
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.notify("Telescope is required for predicate outline", vim.log.levels.ERROR)
    return
  end
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local predicates = collect_predicates()
  if #predicates == 0 then
    vim.notify("No predicates found in current buffer", vim.log.levels.INFO)
    return
  end

  -- Deduplicate to show unique name/arity with first occurrence line
  local unique = {}
  for _, p in ipairs(predicates) do
    if p.is_first then
      table.insert(unique, p)
    end
  end

  pickers
    .new({}, {
      prompt_title = "Prolog Predicates",
      finder = finders.new_table({
        results = unique,
        entry_maker = function(entry)
          local display = string.format("%s/%d", entry.name, entry.arity)
          return {
            value = entry,
            display = display,
            ordinal = display,
            lnum = entry.lnum,
            col = entry.col,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.grep_previewer({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            vim.api.nvim_win_set_cursor(0, { selection.lnum, selection.col - 1 })
          end
        end)
        return true
      end,
    })
    :find()
end

-------------------------------------------------------------------------------
-- Debug Helpers (spy, nospy, trace via REPL)
-------------------------------------------------------------------------------

--- Walk up the treesitter tree to find a compound_term or atom node.
---@param node TSNode
---@return TSNode?
local function find_predicate_node(node)
  local current = node
  while current do
    local ntype = current:type()
    if ntype == "compound_term" or ntype == "functional_notation" then
      return current
    end
    -- If we hit a clause or directive, the cursor wasn't on a predicate
    if ntype == "clause" or ntype == "directive_term" then
      -- Check if the first child is a compound_term (the head)
      local head = current:child(0)
      if head then
        local htype = head:type()
        if htype == "compound_term" or htype == "functional_notation" then
          return head
        end
        if htype == "atom" then
          return head
        end
      end
      return nil
    end
    current = current:parent()
  end
  return nil
end

--- Extract predicate name/arity under cursor (best-effort).
---@return string? name, number? arity
local function predicate_under_cursor()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Try treesitter first
  local ts_node = vim.treesitter.get_node()
  if ts_node then
    -- If cursor is directly on an atom that is a fact (zero-arity predicate)
    if ts_node:type() == "atom" then
      local parent = ts_node:parent()
      if parent and (parent:type() == "fact" or parent:type() == "clause" or parent:type() == "directive_term") then
        local name = vim.treesitter.get_node_text(ts_node, bufnr)
        return name, 0
      end
    end

    local pred_node = find_predicate_node(ts_node)
    if pred_node then
      local ntype = pred_node:type()
      if ntype == "atom" then
        local name = vim.treesitter.get_node_text(pred_node, bufnr)
        return name, 0
      end
      -- compound_term / functional_notation: first child is functor
      local functor = pred_node:child(0)
      if functor then
        local name = vim.treesitter.get_node_text(functor, bufnr)
        -- Count argument children (skip functor, parens, commas)
        local arity = 0
        local counting = false
        for child in pred_node:iter_children() do
          local ct = child:type()
          if ct == "(" then
            counting = true
          elseif ct == ")" then
            break
          elseif counting and ct ~= "," then
            arity = arity + 1
          end
        end
        return name, arity
      end
    end
  end

  -- Fallback: parse the line under the cursor with a regex
  local line = vim.api.nvim_get_current_line()
  local col = vim.fn.col(".") -- 1-indexed

  -- Find the predicate name that contains or precedes the cursor position
  -- Match identifiers: lowercase letter followed by word chars
  local best_name, best_arity
  for s, name, args in line:gmatch("()([a-z_][a-zA-Z0-9_]*)(%b())") do
    local e = s + #name + #args - 1
    if col >= s and col <= e then
      -- Count commas at top level for arity
      local inner = args:sub(2, -2) -- strip parens
      local depth, a = 0, 1
      for i = 1, #inner do
        local c = inner:sub(i, i)
        if c == "(" or c == "[" then depth = depth + 1 end
        if c == ")" or c == "]" then depth = depth - 1 end
        if c == "," and depth == 0 then a = a + 1 end
      end
      best_name, best_arity = name, a
      break
    end
  end
  if best_name then return best_name, best_arity end

  -- Try bare atom (no parens)
  for s, name in line:gmatch("()([a-z_][a-zA-Z0-9_]*)") do
    local e = s + #name - 1
    if col >= s and col <= e then
      return name, nil
    end
  end

  return nil, nil
end

--- Format a predicate spec string like "name/arity" or just "name".
---@param name string
---@param arity number?
---@return string
local function pred_spec(name, arity)
  if arity then
    return string.format("%s/%d", name, arity)
  end
  return name
end

--- Spy on the predicate under cursor.
function M.debug_spy()
  local name, arity = predicate_under_cursor()
  if not name then
    vim.notify("No predicate under cursor", vim.log.levels.WARN)
    return
  end
  local spec = pred_spec(name, arity)
  repl_send("spy(" .. spec .. ")")
  vim.notify("Spying: " .. spec, vim.log.levels.INFO)
end

--- Remove spy from the predicate under cursor.
function M.debug_nospy()
  local name, arity = predicate_under_cursor()
  if not name then
    vim.notify("No predicate under cursor", vim.log.levels.WARN)
    return
  end
  local spec = pred_spec(name, arity)
  repl_send("nospy(" .. spec .. ")")
  vim.notify("Nospy: " .. spec, vim.log.levels.INFO)
end

local _trace_on = false

--- Toggle trace mode in the REPL.
function M.debug_trace_toggle()
  _trace_on = not _trace_on
  if _trace_on then
    repl_send("trace")
    vim.notify("Trace: ON", vim.log.levels.INFO)
  else
    repl_send("notrace")
    vim.notify("Trace: OFF", vim.log.levels.INFO)
  end
end

--- Configure trace leashing.
function M.debug_leash()
  vim.ui.select(
    { "+call+exit+fail+redo", "+call+fail", "+all", "-all" },
    { prompt = "Leash mode:" },
    function(choice)
      if choice then
        repl_send("leash(" .. choice .. ")")
        vim.notify("Leash: " .. choice, vim.log.levels.INFO)
      end
    end
  )
end

-------------------------------------------------------------------------------
-- Documentation Lookup
-------------------------------------------------------------------------------

--- Open SWI-Prolog docs for the predicate under cursor in a browser.
function M.doc_browser()
  local name, arity = predicate_under_cursor()
  if not name then
    vim.notify("No predicate under cursor", vim.log.levels.WARN)
    return
  end
  local spec = pred_spec(name, arity)
  local url = "https://www.swi-prolog.org/pldoc/man?predicate=" .. spec
  -- Use vim.ui.open (Neovim 0.10+) or fallback to xdg-open
  if vim.ui.open then
    vim.ui.open(url)
  else
    vim.fn.jobstart({ "xdg-open", url }, { detach = true })
  end
  vim.notify("Opening docs: " .. spec, vim.log.levels.INFO)
end

--- Show quick help for predicate under cursor in a floating window.
function M.doc_help()
  local name, arity = predicate_under_cursor()
  if not name then
    vim.notify("No predicate under cursor", vim.log.levels.WARN)
    return
  end
  local spec = pred_spec(name, arity)
  local stdout_lines = {}
  local stderr_lines = {}
  local goal = string.format("help(%s), halt.", spec)

  vim.fn.jobstart({ "swipl", "-g", goal, "-t", "halt" }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, l in ipairs(data) do
          if l ~= "" then table.insert(stdout_lines, l) end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, l in ipairs(data) do
          if l ~= "" then table.insert(stderr_lines, l) end
        end
      end
    end,
    on_exit = function()
      vim.schedule(function()
        local result = {}
        vim.list_extend(result, stdout_lines)
        vim.list_extend(result, stderr_lines)
        if #result == 0 then
          result = { "No help found for: " .. spec }
        end
        show_float("Help: " .. spec, result)
      end)
    end,
  })
end

-------------------------------------------------------------------------------
-- Formatter
-------------------------------------------------------------------------------

--- Format buffer using swipl with separate stdout/stderr handling.
function M.format_buffer()
  local script = vim.fn.stdpath("config") .. "/lua/user/prolog_fmt.pl"
  if vim.fn.filereadable(script) == 0 then
    vim.notify("Formatter script not found: " .. script, vim.log.levels.ERROR)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local input = table.concat(lines, "\n") .. "\n"

  local stdout_lines = {}
  local stderr_lines = {}

  local job_id = vim.fn.jobstart({
    "swipl", "--quiet", "-l", script, "-g", "format_stdin", "-t", "halt",
  }, {
    stdin = "pipe",
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, l in ipairs(data) do
          table.insert(stdout_lines, l)
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, l in ipairs(data) do
          if l ~= "" then table.insert(stderr_lines, l) end
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code ~= 0 then
          vim.notify(
            "Prolog formatter failed:\n" .. table.concat(stderr_lines, "\n"),
            vim.log.levels.ERROR
          )
          return
        end
        -- Remove trailing empty strings from jobstart output
        while #stdout_lines > 0 and stdout_lines[#stdout_lines] == "" do
          table.remove(stdout_lines)
        end
        if #stdout_lines > 0 then
          local cursor = vim.api.nvim_win_get_cursor(0)
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, stdout_lines)
          local max_line = vim.api.nvim_buf_line_count(bufnr)
          cursor[1] = math.min(cursor[1], max_line)
          pcall(vim.api.nvim_win_set_cursor, 0, cursor)
          vim.notify("Formatted.", vim.log.levels.INFO)
        end
      end)
    end,
  })

  -- Send buffer contents via stdin and close it
  if job_id > 0 then
    vim.fn.chansend(job_id, input)
    vim.fn.chanclose(job_id, "stdin")
  else
    vim.notify("Failed to start swipl formatter", vim.log.levels.ERROR)
  end
end

return M
