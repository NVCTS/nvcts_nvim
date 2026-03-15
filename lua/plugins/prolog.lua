-- ~/.config/nvim/lua/plugins/prolog.lua
-- Prolog development environment: LSP, keymaps, autocmds, formatter.
-- All keymaps use <localleader> (,) and are buffer-local to prolog files.

---@type LazySpec
return {
  ---------------------------------------------------------------------------
  -- 1. LSP: SWI-Prolog language server (swipl_ls)
  --    Prerequisite: swipl -g "pack_install(lsp_server)" -t halt
  ---------------------------------------------------------------------------
  {
    "AstroNvim/astrolsp",
    ---@type AstroLSPOpts
    opts = {
      servers = {
        "prolog_ls",
      },
      config = {
        prolog_ls = {
          cmd = { "swipl",
            "-g", "use_module(library(lsp_server)).",
            "-g", "lsp_server:main",
            "-t", "halt",
            "--", "stdio",
          },
          filetypes = { "prolog" },
          root_dir = function(fname)
            local util = require("lspconfig.util")
            return util.root_pattern("pack.pl", ".git", "Makefile")(fname)
              or util.path.dirname(fname)
          end,
          settings = {},
        },
      },
    },
  },

  ---------------------------------------------------------------------------
  -- 2. Keymaps & autocmds for Prolog buffers
  ---------------------------------------------------------------------------
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      autocmds = {
        prolog_setup = {
          {
            event = "FileType",
            pattern = "prolog",
            desc = "Set up Prolog keymaps and buffer options",
            callback = function(args)
              local bufnr = args.buf
              local prolog = require("user.prolog")
              local map = function(mode, lhs, rhs, desc)
                vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
              end

              -- Which-key group labels (desc-only for which-key menu)
              vim.keymap.set("n", "<localleader>d", "<Nop>", { buffer = bufnr, desc = "Debug" })

              -- REPL
              map("n", "<localleader>r", prolog.repl_toggle, "Toggle REPL")
              map("n", "<localleader>c", prolog.repl_consult, "Consult file")
              map("n", "<localleader>e", prolog.repl_send_line, "Send line to REPL")
              map("v", "<localleader>e", prolog.repl_send_selection, "Send selection to REPL")

              -- Query runner
              map("n", "<localleader>q", function() prolog.run_query(false) end, "Run query (first)")
              map("n", "<localleader>Q", function() prolog.run_query(true) end, "Run query (all)")

              -- Formatter
              map("n", "<localleader>f", prolog.format_buffer, "Format buffer")

              -- Predicate outline
              map("n", "<localleader>o", prolog.predicate_outline, "Predicate outline")

              -- Debug
              map("n", "<localleader>ds", prolog.debug_spy, "Spy predicate")
              map("n", "<localleader>dn", prolog.debug_nospy, "Nospy predicate")
              map("n", "<localleader>dt", prolog.debug_trace_toggle, "Toggle trace")
              map("n", "<localleader>dl", prolog.debug_leash, "Configure leash")

              -- Documentation
              map("n", "<localleader>K", prolog.doc_browser, "Open docs (browser)")
              map("n", "<localleader>h", prolog.doc_help, "Quick help (float)")

              -- Buffer options useful for Prolog
              vim.bo[bufnr].commentstring = "%% %s"
            end,
          },
        },
      },
    },
  },
}
