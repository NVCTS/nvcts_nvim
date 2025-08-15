-- ~/.config/nvim/lua/user/init.lua

return {
  -- This is a special field for custom commands and functions
  -- This will be executed on startup.
  ["user.commands"] = function()
    -- Your custom commands and functions go here
    vim.api.nvim_create_user_command("LocalTerm", function()
      vim.cmd "lcd %:p:h"
      vim.cmd "ToggleTerm"
    end, {})
  end,
}
