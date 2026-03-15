-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.colorscheme.monokai-pro-nvim" },
  { import = "astrocommunity.diagnostics.trouble-nvim" },
  { import = "astrocommunity.motion.flash-nvim" },

  { import = "astrocommunity.editing-support.conform-nvim" },
  { import = "astrocommunity.lsp.nvim-lint" },
  { import = "astrocommunity.utility.noice-nvim" },
  { import = "astrocommunity.git.diffview-nvim" },
  { import = "astrocommunity.test.neotest" },

  -- Navigation & motion
  { import = "astrocommunity.motion.nvim-surround" },

  -- Editing support
  { import = "astrocommunity.editing-support.undotree" },
  {
    "mbbill/undotree",
    keys = {
      { "<Leader>U", desc = "Undotree" },
      { "<Leader>Ut", "<Cmd>UndotreeToggle<CR>", desc = "Toggle" },
      { "<Leader>Uh", "<Cmd>UndotreeHide<CR>", desc = "Hide" },
      { "<Leader>Us", "<Cmd>UndotreeShow<CR>", desc = "Show" },
      { "<Leader>Uf", "<Cmd>UndotreeFocus<CR>", desc = "Focus" },
      { "<Leader>Up", "<Cmd>UndotreePersistUndo<CR>", desc = "Persist undo" },
    },
  },
  { import = "astrocommunity.editing-support.nvim-treesitter-context" },
}
