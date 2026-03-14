local function safe_put(type)
  return function(prompt_bufnr)
    local action_state = require "telescope.actions.state"
    local telescope_actions = require "telescope.actions"
    local yanky_picker = require "yanky.picker"
    local yanky_mapping = require "yanky.telescope.mapping"

    local selection = action_state.get_selected_entry()
    if not selection then
      if vim.api.nvim_buf_is_valid(prompt_bufnr) then
        telescope_actions.close(prompt_bufnr)
      end
      return
    end
    if vim.api.nvim_buf_is_valid(prompt_bufnr) then
      telescope_actions.close(prompt_bufnr)
    end

    local cursor_pos = nil
    if vim.api.nvim_get_mode().mode == "i" then
      cursor_pos = vim.api.nvim_win_get_cursor(0)
    end

    vim.schedule(function()
      if nil ~= cursor_pos then
        vim.api.nvim_win_set_cursor(0, { cursor_pos[1], math.max(cursor_pos[2] - 1, 0) })
      end
      yanky_picker.actions.put(type, yanky_mapping.state.is_visual)(selection.value)
    end)
  end
end

local function open_yank_history()
  local telescope_actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local yanky_mapping = require "yanky.telescope.mapping"
  local utils = require "yanky.utils"

  require("telescope").extensions.yank_history.yank_history {
    attach_mappings = function(prompt_bufnr, map)
      -- <Esc> in insert mode closes the picker directly
      map("i", "<Esc>", telescope_actions.close)

      -- Replace default <CR> action: intercept :q/:quit/:clear in prompt
      telescope_actions.select_default:replace(function()
        local ok, picker = pcall(action_state.get_current_picker, prompt_bufnr)
        local prompt = ok and picker and picker:_get_prompt() or ""

        if prompt:match "^:q%s*$" or prompt:match "^:quit%s*$" then
          telescope_actions.close(prompt_bufnr)
          return
        end

        if prompt:match "^:clear%s*$" then
          require("yanky.history").clear()
          telescope_actions.close(prompt_bufnr)
          vim.notify("Yank history cleared", vim.log.levels.INFO)
          return
        end

        safe_put("p")(prompt_bufnr)
      end)

      -- Insert mode mappings
      map("i", "<C-k>", safe_put "P")
      map("i", "<C-x>", yanky_mapping.delete())
      map("i", "<C-r>", yanky_mapping.set_register(utils.get_default_register()))

      -- Normal mode mappings
      map("n", "p", safe_put "p")
      map("n", "P", safe_put "P")
      map("n", "d", yanky_mapping.delete())
      map("n", "r", yanky_mapping.set_register(utils.get_default_register()))

      -- Keep default telescope mappings (<CR>, <Esc> in normal, etc.)
      return true
    end,
  }
end

return {
  {
    "gbprod/yanky.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    event = "User AstroFile",
    opts = {
      ring = {
        history_length = 10, -- number of yanks to keep in history
      },
      highlight = {
        on_put = true,
        on_yank = true,
        timer = 200,
      },
    },
    config = function(_, opts)
      require("yanky").setup(opts)
      require("telescope").load_extension "yank_history"
      vim.api.nvim_create_user_command("YankHistoryClear", function()
        require("yanky.history").clear()
        vim.notify("Yank history cleared", vim.log.levels.INFO)
      end, { desc = "Clear yank history" })
    end,
  },
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      mappings = {
        n = {
          ["<Leader>fy"] = {
            open_yank_history,
            desc = "Find yank history",
          },
        },
      },
    },
  },
}
