return {
  "iamcco/markdown-preview.nvim",
  cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
  ft = "markdown",
  build = function() vim.fn.system({ "bash", vim.fn.stdpath("data") .. "/lazy/markdown-preview.nvim/app/install.sh" }) end,
  keys = {
    { "<Leader>m", "<Cmd>MarkdownPreviewToggle<CR>", desc = "Toggle Markdown Preview", ft = "markdown" },
  },
}
