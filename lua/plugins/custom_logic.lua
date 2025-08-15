-- ~/.config/nvim/lua/plugins/custom_logic.lua

return {
  -- This is a "dummy" plugin spec. It doesn't install a plugin,
  -- but it lets us run code on a specific event.
  {
    "AstroNvim/AstroNvim", -- An anchor to signify this is part of your AstroNvim config
    event = "VeryLazy", -- This is the key: run this code after startup is complete
    config = function()
      -- All the code inside this function will run on the "VeryLazy" event
      vim.api.nvim_create_user_command("LocalTerm", function()
        local current_file_dir = vim.fn.expand "%:p:h"

        -- Check if we are in a buffer with an associated file path
        if current_file_dir ~= "." and vim.fn.isdirectory(current_file_dir) == 1 then
          vim.cmd.lcd(current_file_dir)
          -- Use vim.notify for a cleaner, non-blocking message
          vim.notify("Terminal directory set to: " .. current_file_dir, vim.log.levels.INFO)
        end

        -- Now, call ToggleTerm. This will trigger lazy.nvim to load
        -- the toggleterm.nvim plugin if it hasn't been loaded yet.
        vim.cmd.ToggleTerm()
      end, { desc = "Set terminal directory to the current buffer's directory" })
      vim.keymap.set("n", "<leader>tl", "<cmd>LocalTerm<cr>", {
        desc = "[T]erminal directory [L]ocal to file",
      })
    end,
  },
}
