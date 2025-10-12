-- ~/.config/nvim/lua/plugins/lang_keymaps.lua
local wk = require "which-key"

-- Corrected mappings
local mappings = {
  j = {
    name = "Java", -- A descriptive group name
    r = { function() vim.cmd "!java %" end, "Run current Java file" },
  },
  js = {
    name = "JavaScript", -- A descriptive group name
    r = { function() vim.cmd "!node %" end, "Run current JavaScript file" },
  },
}

-- Register the corrected mappings
wk.register(mappings, { prefix = "<leader>", mode = "n" })
