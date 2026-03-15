---@type LazySpec
return {

  -- == Examples of Adding Plugins ==


  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true,
    },
  },
  {
    "ray-x/lsp_signature.nvim",
    event = "BufRead",
    config = function() require("lsp_signature").setup() end,
  },

  -- == Examples of Overriding Plugins ==

  -- customize alpha options
  {
    "goolord/alpha-nvim",
    opts = function(_, opts)
      -- customize the dashboard header
      opts.section.header.val = {
        " █████  ███████ ████████ ██████   ██████",
        "██   ██ ██         ██    ██   ██ ██    ██",
        "███████ ███████    ██    ██████  ██    ██",
        "██   ██      ██    ██    ██   ██ ██    ██",
        "██   ██ ███████    ██    ██   ██  ██████",
        " ",
        "    ███    ██ ██    ██ ██ ███    ███",
        "    ████   ██ ██    ██ ██ ████  ████",
        "    ██ ██  ██ ██    ██ ██ ██ ████ ██",
        "    ██  ██ ██  ██  ██  ██ ██  ██  ██",
        "    ██   ████   ████   ██ ██      ██",
      }
      return opts
    end,
  },

  -- You can disable default plugins as follows:
  -- { "max397574/better-escape.nvim", enabled = false },

  -- You can also easily customize additional setup of plugins that is outside of the plugin's setup call
  {
    "L3MON4D3/LuaSnip",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.luasnip"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom luasnip configuration such as filetype extend or custom snippets
      local luasnip = require "luasnip"
      luasnip.filetype_extend("javascript", { "javascriptreact" })

      -- Prolog snippets
      local s = luasnip.snippet
      local t = luasnip.text_node
      local i = luasnip.insert_node
      local c = luasnip.choice_node
      local fmt = require("luasnip.extras.fmt").fmt

      luasnip.add_snippets("prolog", {
        -- Module declaration
        s("mod", fmt(":- module({}, [\n    {}\n]).", { i(1, "module_name"), i(2, "exported_pred/arity") })),

        -- Use module
        s("use", fmt(":- use_module(library({})).", { i(1, "lists") })),

        -- DCG rule
        s("dcg", fmt("{} -->\n    {}.", { i(1, "nonterminal"), i(2, "body") })),

        -- PLUnit test block
        s("test", fmt(
          ":- begin_tests({}).\n\ntest({}) :-\n    {}.\n\n:- end_tests({}).",
          { i(1, "suite_name"), i(2, "test_name"), i(3, "true"), i(4, "suite_name") }
        )),

        -- Single test case (for adding inside existing test block)
        s("tc", fmt("test({}) :-\n    {}.", { i(1, "test_name"), i(2, "true") })),

        -- Meta-predicate declaration
        s("meta", fmt(":- meta_predicate {}({}).", { i(1, "pred"), i(2, "+, -, ?") })),

        -- If-then-else
        s("ite", fmt(
          "(   {}\n->  {}\n;   {}\n)",
          { i(1, "Cond"), i(2, "Then"), i(3, "Else") }
        )),

        -- findall/3
        s("findall", fmt("findall({}, {}, {})", { i(1, "Template"), i(2, "Goal"), i(3, "List") })),

        -- aggregate_all/3
        s("agg", fmt("aggregate_all({}, {}, {})", { i(1, "Template"), i(2, "Goal"), i(3, "List") })),

        -- Documented predicate
        s("pred", fmt(
          "%!  {}({}) is {}.\n%\n%   {}\n%\n{}({}) :-\n    {}.",
          {
            i(1, "name"), i(2, "+Arg"),
            c(3, { t("det"), t("semidet"), t("nondet"), t("multi"), t("failure") }),
            i(4, "Description"),
            i(5, "name"), i(6, "Arg"),
            i(7, "true"),
          }
        )),

        -- Multi-clause predicate skeleton
        s("clause", fmt(
          "{}({}) :-\n    {}.\n{}({}) :-\n    {}.",
          { i(1, "name"), i(2, "Pattern1"), i(3, "body1"), i(4, "name"), i(5, "Pattern2"), i(6, "body2") }
        )),

        -- Fact
        s("fact", fmt("{}({}).", { i(1, "predicate"), i(2, "args") })),

        -- Directive
        s("dir", fmt(":- {}.", { i(1, "directive") })),

        -- maplist/2
        s("mapl", fmt("maplist({}, {})", { i(1, "Goal"), i(2, "List") })),

        -- maplist/3
        s("mapl3", fmt("maplist({}, {}, {})", { i(1, "Goal"), i(2, "List"), i(3, "Result") })),

        -- foldl/4
        s("fold", fmt("foldl({}, {}, {}, {})", { i(1, "Goal"), i(2, "List"), i(3, "V0"), i(4, "V") })),

        -- assertion
        s("assert", fmt("assertion({}).", { i(1, "Goal") })),
      })
    end,
  },

  {
    "windwp/nvim-autopairs",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.nvim-autopairs"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom autopairs configuration such as custom rules
      local npairs = require "nvim-autopairs"
      local Rule = require "nvim-autopairs.rule"
      local cond = require "nvim-autopairs.conds"
      npairs.add_rules(
        {
          Rule("$", "$", { "tex", "latex" })
            -- don't add a pair if the next character is %
            :with_pair(cond.not_after_regex "%%")
            -- don't add a pair if  the previous character is xxx
            :with_pair(
              cond.not_before_regex("xxx", 3)
            )
            -- don't move right when repeat character
            :with_move(cond.none())
            -- don't delete if the next character is xx
            :with_del(cond.not_after_regex "xx")
            -- disable adding a newline when you press <cr>
            :with_cr(cond.none()),
        },
        -- disable for .vim files, but it work for another filetypes
        Rule("a", "a", "-vim")
      )
    end,
  },
}
