-- Customize Treesitter

---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
      "lua",
      "vim",
      "prolog",
    },
    highlight = {
      disable = { "http", "rest", "kulala_http" },
    },
  },
}
