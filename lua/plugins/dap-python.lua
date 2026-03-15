---@type LazySpec
return {
  {
    "mfussenegger/nvim-dap-python",
    dependencies = {
      "mfussenegger/nvim-dap",
    },
    config = function()
      -- Uses debugpy. Install it via:
      --   pip install debugpy
      -- or specify a custom path:
      --   require("dap-python").setup("/path/to/virtualenv/bin/python")
      require("dap-python").setup("python")

      -- Default test runner (pytest, unittest, or django)
      require("dap-python").test_runner = "pytest"
    end,
    -- stylua: ignore
    keys = {
      { "<Leader>dPt", function() require("dap-python").test_method() end,  desc = "Debug test method",  ft = "python" },
      { "<Leader>dPc", function() require("dap-python").test_class() end,   desc = "Debug test class",   ft = "python" },
      { "<Leader>dPs", function() require("dap-python").debug_selection() end, desc = "Debug selection", ft = "python", mode = "v" },
    },
  },
}
