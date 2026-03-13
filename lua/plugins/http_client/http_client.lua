-- ~/.config/nvim/lua/plugins/http_client/http_client.lua
-- Plugin spec for the HTTP client (IntelliJ-style .http files)
return {
  {
    "AstroNvim/AstroNvim",
    event = "VeryLazy",
    config = function()
      local http = require "user.http_client"

      -- Helper: parse "write" and env name from command args
      -- Supports: :HttpRun [env] [--write]  (order doesn't matter)
      local function parse_args(args_str)
        local write = false
        local env = nil
        for word in args_str:gmatch "%S+" do
          if word == "--write" or word == "-w" then
            write = true
          else
            env = word
          end
        end
        return { env = env, write = write }
      end

      -- :HttpRun [env] [--write]
      vim.api.nvim_create_user_command("HttpRun", function(opts)
        local parsed = parse_args(opts.args)
        http.execute_request(parsed)
      end, {
        nargs = "*",
        desc = "Execute HTTP request under cursor. Args: [env] [--write]",
      })

      -- :HttpRunAll [env] [--write]
      vim.api.nvim_create_user_command("HttpRunAll", function(opts)
        local parsed = parse_args(opts.args)
        http.execute_all_requests(parsed)
      end, {
        nargs = "*",
        desc = "Execute all HTTP requests in the file. Args: [env] [--write]",
      })

      -- :HttpRunEnv [--write]  (prompts for environment)
      vim.api.nvim_create_user_command("HttpRunEnv", function(opts)
        local parsed = parse_args(opts.args)
        http.execute_request_with_env { write = parsed.write }
      end, {
        nargs = "*",
        desc = "Execute HTTP request under cursor, prompting for environment. Args: [--write]",
      })

      -- :HttpRunAllEnv [--write]  (prompts for environment)
      vim.api.nvim_create_user_command("HttpRunAllEnv", function(opts)
        local parsed = parse_args(opts.args)
        http.execute_all_with_env { write = parsed.write }
      end, {
        nargs = "*",
        desc = "Execute all HTTP requests, prompting for environment. Args: [--write]",
      })

      -- Keymaps (only active in .http files)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "http",
        callback = function(ev)
          -- Register which-key group label
          local ok, wk = pcall(require, "which-key")
          if ok then wk.add {
            { "<leader>r", group = "🌐Requests", buffer = ev.buf },
          } end

          -- Run single request (display in buffer)
          vim.keymap.set(
            "n",
            "<leader>rr",
            function() http.execute_request() end,
            { buffer = ev.buf, desc = "[R]equest [R]un under cursor" }
          )

          -- Run single request (write to file)
          vim.keymap.set(
            "n",
            "<leader>rR",
            function() http.execute_request { write = true } end,
            { buffer = ev.buf, desc = "[R]equest [R]un and write to file" }
          )

          -- Run single request with environment prompt
          vim.keymap.set(
            "n",
            "<leader>re",
            function() http.execute_request_with_env() end,
            { buffer = ev.buf, desc = "[R]equest run with [E]nvironment" }
          )

          -- Run single request with environment prompt and write to file
          vim.keymap.set(
            "n",
            "<leader>rE",
            function() http.execute_request_with_env { write = true } end,
            { buffer = ev.buf, desc = "[R]equest run with [E]nvironment and write to file" }
          )

          -- Run all requests (display in buffers)
          vim.keymap.set(
            "n",
            "<leader>ra",
            function() http.execute_all_requests() end,
            { buffer = ev.buf, desc = "[R]equest run [A]ll" }
          )

          -- Run all requests (write to files)
          vim.keymap.set(
            "n",
            "<leader>rA",
            function() http.execute_all_requests { write = true } end,
            { buffer = ev.buf, desc = "[R]equest run [A]ll and write to files" }
          )
        end,
      })

      -- Register .http files as the "http" filetype
      vim.filetype.add {
        extension = {
          http = "http",
        },
      }
    end,
  },
}
