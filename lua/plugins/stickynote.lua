-- ~/.config/nvim/lua/plugins/stickynote.lua
-- Sticky note floating window: persistent notes with tabs and todo checkboxes.
return {
  {
    "AstroNvim/AstroNvim",
    event = "VeryLazy",
    config = function()
      local stickynote = require("user.stickynote")

      vim.api.nvim_create_user_command("StickyNote", function() stickynote.toggle() end, {
        desc = "Toggle sticky note window",
      })
      vim.api.nvim_create_user_command("StickyNoteClear", function() stickynote.clear() end, {
        desc = "Clear current sticky note tab",
      })


    end,
  },
}
