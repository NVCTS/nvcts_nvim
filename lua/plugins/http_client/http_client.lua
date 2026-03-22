-- kulala.nvim - A fully-featured REST client for Neovim
-- https://github.com/mistweaverco/kulala.nvim

-- Neovim doesn't detect .http/.rest filetypes natively — register them
-- so lazy.nvim's `ft` trigger can load kulala.
vim.filetype.add {
  extension = {
    http = "http",
    rest = "rest",
  },
}

return {
  {
    "mistweaverco/kulala.nvim",
    ft = { "http", "rest" },
    opts = {
      -- Enable default keymaps, all scoped to http/rest via ft.
      -- The prefix <leader>H is prepended automatically to each key.
      global_keymaps = true,
      global_keymaps_prefix = "<leader>H",
      kulala_keymaps_prefix = "",
    },
  },
}
