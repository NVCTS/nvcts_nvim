vim.filetype.add {
  extension = {
    pl = "prolog",
  },
}

return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    mappings = {
      n = {
        -- Java mappings
        ["<Leader>j"] = { desc = "☕Java/JavaScript" },
        ["<Leader>jr"] = { function() vim.cmd "!java %" end, desc = "Run current Java file" },
        -- JavaScript mappings
        ["<Leader>js"] = { desc = "JavaScript" },
        ["<Leader>jsr"] = { function() vim.cmd "!node %" end, desc = "Run current JavaScript file" },
        -- Plugins group
        ["<Leader>P"] = { desc = "🔌Plugins" },
        ["<Leader>Pn"] = { function() require("user.stickynote").toggle() end, desc = "Sticky [N]ote" },
      },
    },
  },
}
