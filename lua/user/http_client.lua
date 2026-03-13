-- ~/.config/nvim/lua/user/http_client.lua
-- A Neovim HTTP client inspired by IntelliJ's .http file format.

local M = {}

-- Content-Type to file extension mapping
local content_type_extensions = {
  ["application/json"] = "json",
  ["application/xml"] = "xml",
  ["text/xml"] = "xml",
  ["text/html"] = "html",
  ["text/plain"] = "txt",
  ["text/css"] = "css",
  ["text/csv"] = "csv",
  ["application/javascript"] = "js",
  ["application/pdf"] = "pdf",
  ["image/png"] = "png",
  ["image/jpeg"] = "jpg",
  ["image/svg+xml"] = "svg",
}

--- Load variables from http-client.env.json.
--- Searches for the file starting from the directory of the current buffer,
--- walking up to the project root (where .git is) or filesystem root.
---@param env_name string|nil The environment name to use (e.g. "dev", "prod"). Defaults to "dev".
---@return table<string, string> A map of variable names to their values.
function M.load_env_variables(env_name)
  env_name = env_name or "dev"
  local buf_dir = vim.fn.expand "%:p:h"
  local dir = buf_dir

  while true do
    local env_file = dir .. "/http-client.env.json"
    local stat = (vim.uv or vim.loop).fs_stat(env_file)
    if stat then
      local content = vim.fn.readfile(env_file)
      local ok, decoded = pcall(vim.json.decode, table.concat(content, "\n"))
      if ok and type(decoded) == "table" then
        local vars = {}
        -- Merge the common/shared environment first, then the specific one
        if decoded["_common"] and type(decoded["_common"]) == "table" then
          for k, v in pairs(decoded["_common"]) do
            vars[k] = tostring(v)
          end
        end
        if decoded[env_name] and type(decoded[env_name]) == "table" then
          for k, v in pairs(decoded[env_name]) do
            vars[k] = tostring(v)
          end
        end
        return vars
      else
        vim.notify("http_client: failed to parse " .. env_file, vim.log.levels.WARN)
        return {}
      end
    end

    -- Check if we've hit a project root or filesystem root
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then break end -- filesystem root
    local git_dir = dir .. "/.git"
    local git_stat = (vim.uv or vim.loop).fs_stat(git_dir)
    if git_stat then
      -- We're at project root and didn't find the file
      break
    end
    dir = parent
  end

  return {}
end

--- Substitute {{variable}} placeholders in a string using the provided variables.
---@param text string
---@param vars table<string, string>
---@return string
function M.substitute_variables(text, vars)
  local result = text:gsub("{{(.-)}}", function(var_name)
    local trimmed = vim.trim(var_name)
    if vars[trimmed] then
      return vars[trimmed]
    end
    vim.notify("http_client: unresolved variable {{" .. trimmed .. "}}", vim.log.levels.WARN)
    return "{{" .. trimmed .. "}}"
  end)
  return result
end

--- Parse a single request block (lines between ### markers).
---@param lines string[] The lines of the request block.
---@return table|nil Parsed request with fields: method, url, headers, body, label
function M.parse_request_block(lines)
  if #lines == 0 then return nil end

  local label = nil
  local request_line = nil
  local headers = {}
  local body_lines = {}
  local state = "start" -- start -> headers -> body

  for _, line in ipairs(lines) do
    if state == "start" then
      -- Look for the ### label or the request line
      local label_match = line:match "^###%s*(.*)"
      if label_match then
        label = vim.trim(label_match)
        if label == "" then label = nil end
      elseif line:match "^%s*$" then
        -- skip blank lines before request line
      elseif line:match "^#" then
        -- skip comment lines
      else
        -- This should be the request line: METHOD URL
        request_line = line
        state = "headers"
      end
    elseif state == "headers" then
      if line:match "^%s*$" then
        -- Empty line signals transition to body
        state = "body"
      else
        -- Check if it's a header (Key: Value)
        local key, value = line:match "^([%w%-_]+):%s*(.*)"
        if key then
          headers[key] = value
        else
          -- Could be a continuation or malformed; treat as end of headers
          state = "body"
          table.insert(body_lines, line)
        end
      end
    elseif state == "body" then
      table.insert(body_lines, line)
    end
  end

  if not request_line then return nil end

  -- Parse METHOD and URL from the request line
  local method, url = request_line:match "^(%u+)%s+(.+)$"
  if not method or not url then
    vim.notify("http_client: invalid request line: " .. request_line, vim.log.levels.ERROR)
    return nil
  end

  url = vim.trim(url)

  -- Join body lines, trim trailing whitespace
  local body = nil
  if #body_lines > 0 then
    body = table.concat(body_lines, "\n")
    body = body:gsub("%s+$", "")
    if body == "" then body = nil end
  end

  return {
    method = method,
    url = url,
    headers = headers,
    body = body,
    label = label,
  }
end

--- Find the request block surrounding the cursor position.
---@return string[]|nil lines The lines of the request block
function M.get_request_block_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local total = #all_lines

  -- Find the start of the current block: search backward for ### or start of file
  local block_start = 1
  for i = cursor_line, 1, -1 do
    if all_lines[i]:match "^###" and i < cursor_line then
      block_start = i
      break
    end
  end

  -- Find the end of the current block: search forward for ### or end of file
  local block_end = total
  for i = cursor_line + 1, total do
    if all_lines[i]:match "^###" then
      block_end = i - 1
      break
    end
  end

  -- Extract the block
  local block_lines = {}
  for i = block_start, block_end do
    table.insert(block_lines, all_lines[i])
  end

  return block_lines
end

--- Get all request blocks from the current buffer.
---@return string[][] A list of request blocks, each being a list of lines.
function M.get_all_request_blocks()
  local bufnr = vim.api.nvim_get_current_buf()
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local total = #all_lines
  local blocks = {}
  local current_block = {}

  for i = 1, total do
    local line = all_lines[i]
    if line:match "^###" then
      -- A ### line starts a new block. Save the previous block if it has content.
      if #current_block > 0 then
        table.insert(blocks, current_block)
      end
      current_block = { line }
    else
      table.insert(current_block, line)
    end
  end

  -- Don't forget the last block
  if #current_block > 0 then
    table.insert(blocks, current_block)
  end

  return blocks
end

--- Build a curl command table from a parsed request.
---@param request table Parsed request from parse_request_block
---@return string[] The curl command as a list of arguments
function M.build_curl_command(request)
  local cmd = { "curl", "-s", "-w", "\n__HTTP_STATUS__%{http_code}", "-X", request.method }

  -- Add headers
  for key, value in pairs(request.headers) do
    table.insert(cmd, "-H")
    table.insert(cmd, key .. ": " .. value)
  end

  -- Add body
  if request.body then
    table.insert(cmd, "-d")
    table.insert(cmd, request.body)
  end

  table.insert(cmd, request.url)
  return cmd
end

--- Determine the file extension from a Content-Type header value.
---@param content_type string|nil
---@return string
function M.get_extension_from_content_type(content_type)
  if not content_type then return "txt" end
  -- Strip parameters like charset
  local base = content_type:match "^([^;]+)"
  if base then
    base = vim.trim(base):lower()
    return content_type_extensions[base] or "txt"
  end
  return "txt"
end

--- Generate the output file path for a response.
---@param request table Parsed request
---@param response_content_type string|nil The Content-Type from the response
---@return string The absolute file path for the response
function M.get_output_filepath(request, response_content_type)
  local buf_dir = vim.fn.expand "%:p:h"
  local ext = M.get_extension_from_content_type(response_content_type)

  local filename
  if request.label and request.label ~= "" then
    -- Sanitize the label: lowercase, replace spaces/special chars with underscores
    filename = request.label:lower():gsub("[^%w]+", "_"):gsub("_+$", ""):gsub("^_+", "")
  else
    -- Fallback: use method + sanitized URL path
    local url_path = request.url:match "://[^/]+(.*)" or request.url
    url_path = url_path:gsub("[^%w]+", "_"):gsub("_+$", ""):gsub("^_+", "")
    if url_path == "" then url_path = "response" end
    filename = request.method:lower() .. "_" .. url_path
  end

  return buf_dir .. "/" .. filename .. "." .. ext
end

--- Detect content type heuristically from the response body.
---@param body string The response body text
---@return string|nil The detected content type, or nil
local function detect_content_type(body)
  local trimmed = vim.trim(body)
  if trimmed:match "^[{%[]" then
    return "application/json"
  elseif trimmed:match "^<%?xml" or trimmed:match "^<!" then
    if trimmed:match "^<!DOCTYPE html" or trimmed:match "<html" then
      return "text/html"
    else
      return "application/xml"
    end
  end
  return nil
end

--- Pretty-print JSON body using jq if available, otherwise return as-is.
---@param body string
---@return string
local function pretty_print_json(body)
  local jq_result = vim.fn.system("echo " .. vim.fn.shellescape(body) .. " | jq . 2>/dev/null")
  if vim.v.shell_error == 0 and jq_result ~= "" then
    return jq_result:gsub("%s+$", "")
  end
  return body
end

--- Build formatted output lines from a response.
---@param request table The parsed request
---@param status_code string|nil The HTTP status code
---@param body_output string The raw response body
---@param response_content_type string|nil The detected content type
---@return string[] The formatted output lines
local function build_output_lines(request, status_code, body_output, response_content_type)
  local output_lines = {}
  table.insert(output_lines, "// HTTP " .. (status_code or "???") .. " " .. request.method .. " " .. request.url)
  table.insert(output_lines, "")

  -- If JSON, try to pretty-print with jq
  if response_content_type == "application/json" then
    body_output = pretty_print_json(body_output)
  end

  for line in (body_output .. "\n"):gmatch "(.-)\n" do
    table.insert(output_lines, line)
  end

  return output_lines
end

--- Display response in a scratch buffer in a vertical split.
---@param output_lines string[] The formatted output lines
---@param response_content_type string|nil The content type for syntax highlighting
---@param request table The parsed request (for buffer naming)
local function display_in_buffer(output_lines, response_content_type, request)
  -- Create a scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, output_lines)

  -- Set buffer options
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false

  -- Set filetype for syntax highlighting
  local ext = M.get_extension_from_content_type(response_content_type)
  local ft_map = { json = "json", xml = "xml", html = "html", js = "javascript", css = "css" }
  if ft_map[ext] then
    vim.bo[buf].filetype = ft_map[ext]
  end

  -- Name the buffer
  local name = request.label or (request.method .. " " .. request.url)
  -- Avoid duplicate buffer name errors
  local ok = pcall(vim.api.nvim_buf_set_name, buf, "[HTTP] " .. name)
  if not ok then
    pcall(vim.api.nvim_buf_set_name, buf, "[HTTP] " .. name .. " " .. os.time())
  end

  -- Open in vertical split
   vim.cmd "split"
  vim.api.nvim_win_set_buf(0, buf)
end

--- Write response to a file and open it in a vertical split.
---@param output_lines string[] The formatted output lines
---@param filepath string The file path to write to
local function write_to_file(output_lines, filepath)
  vim.fn.writefile(output_lines, filepath)
  vim.notify(
    "http_client: response saved to " .. vim.fn.fnamemodify(filepath, ":t"),
    vim.log.levels.INFO
  )
  vim.cmd("split " .. vim.fn.fnameescape(filepath))
end

--- Process a curl result: parse the output, format it, and display or write it.
---@param result table The vim.system result
---@param request table The parsed request
---@param opts table Options: { write = boolean }
local function handle_response(result, request, opts)
  if result.code ~= 0 then
    vim.notify(
      "http_client: curl failed (exit " .. result.code .. "): " .. (result.stderr or ""),
      vim.log.levels.ERROR
    )
    return
  end

  local output = result.stdout or ""

  -- Extract status code from our sentinel
  local status_code = output:match "__HTTP_STATUS__(%d+)$"
  local body_output = output:gsub("\n__HTTP_STATUS__%d+$", "")

  -- Detect content type
  local response_content_type = detect_content_type(body_output)

  -- Build formatted output
  local output_lines = build_output_lines(request, status_code, body_output, response_content_type)

  local status_msg = " (HTTP " .. (status_code or "???") .. ")"

  if opts.write then
    local filepath = M.get_output_filepath(request, response_content_type)
    write_to_file(output_lines, filepath)
    vim.notify("http_client: response written to " .. vim.fn.fnamemodify(filepath, ":t") .. status_msg, vim.log.levels.INFO)
  else
    display_in_buffer(output_lines, response_content_type, request)
    vim.notify("http_client: " .. request.method .. " " .. request.url .. status_msg, vim.log.levels.INFO)
  end
end

--- Prepare a raw block (substitute variables, parse, preserve original label).
---@param block_lines string[] Raw lines of a request block
---@param vars table<string, string> Environment variables
---@return table|nil The parsed and substituted request
local function prepare_request(block_lines, vars)
  local substituted_lines = {}
  for _, line in ipairs(block_lines) do
    table.insert(substituted_lines, M.substitute_variables(line, vars))
  end

  local request = M.parse_request_block(substituted_lines)
  if not request then return nil end

  -- Preserve the original label (before variable substitution might have changed it)
  local orig_block = M.parse_request_block(block_lines)
  if orig_block and orig_block.label then
    request.label = orig_block.label
  end

  return request
end

--- Execute the HTTP request under the cursor.
---@param opts table|nil Options: { env = string|nil, write = boolean|nil }
function M.execute_request(opts)
  opts = opts or {}
  local write = opts.write or false
  local env_name = opts.env

  -- Get the block at cursor
  local block_lines = M.get_request_block_at_cursor()
  if not block_lines then
    vim.notify("http_client: no request block found at cursor", vim.log.levels.ERROR)
    return
  end

  -- Load env variables and prepare request
  local vars = M.load_env_variables(env_name)
  local request = prepare_request(block_lines, vars)
  if not request then
    vim.notify("http_client: failed to parse request block", vim.log.levels.ERROR)
    return
  end

  -- Build and execute the curl command
  local cmd = M.build_curl_command(request)
  vim.notify("http_client: executing " .. request.method .. " " .. request.url, vim.log.levels.INFO)

  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      handle_response(result, request, { write = write })
    end)
  end)
end

--- Execute all HTTP requests in the current buffer.
---@param opts table|nil Options: { env = string|nil, write = boolean|nil }
function M.execute_all_requests(opts)
  opts = opts or {}
  local write = opts.write or false
  local env_name = opts.env

  local blocks = M.get_all_request_blocks()
  if #blocks == 0 then
    vim.notify("http_client: no request blocks found in file", vim.log.levels.WARN)
    return
  end

  local vars = M.load_env_variables(env_name)

  -- Parse all requests first to validate and count them
  local requests = {}
  for _, block_lines in ipairs(blocks) do
    local request = prepare_request(block_lines, vars)
    if request then
      table.insert(requests, request)
    end
  end

  if #requests == 0 then
    vim.notify("http_client: no valid requests found in file", vim.log.levels.WARN)
    return
  end

  vim.notify("http_client: executing " .. #requests .. " request(s)...", vim.log.levels.INFO)

  -- Execute requests sequentially to avoid overwhelming the output
  local idx = 0
  local function run_next()
    idx = idx + 1
    if idx > #requests then
      vim.notify("http_client: all " .. #requests .. " request(s) completed", vim.log.levels.INFO)
      return
    end

    local request = requests[idx]
    local cmd = M.build_curl_command(request)
    local label = request.label or (request.method .. " " .. request.url)
    vim.notify("http_client: [" .. idx .. "/" .. #requests .. "] " .. label, vim.log.levels.INFO)

    vim.system(cmd, { text = true }, function(result)
      vim.schedule(function()
        handle_response(result, request, { write = write })
        -- Small delay before next request so splits don't pile up instantly
        vim.defer_fn(run_next, 100)
      end)
    end)
  end

  run_next()
end

--- Select environment and execute request under cursor
---@param opts table|nil Options: { write = boolean|nil }
function M.execute_request_with_env(opts)
  opts = opts or {}
  vim.ui.input({ prompt = "Environment (default: dev): " }, function(input)
    if input == nil then return end -- cancelled
    local env = vim.trim(input)
    if env == "" then env = "dev" end
    M.execute_request { env = env, write = opts.write }
  end)
end

--- Select environment and execute all requests
---@param opts table|nil Options: { write = boolean|nil }
function M.execute_all_with_env(opts)
  opts = opts or {}
  vim.ui.input({ prompt = "Environment (default: dev): " }, function(input)
    if input == nil then return end -- cancelled
    local env = vim.trim(input)
    if env == "" then env = "dev" end
    M.execute_all_requests { env = env, write = opts.write }
  end)
end

return M
