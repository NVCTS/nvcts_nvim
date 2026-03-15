# Neovim Config

Personal Neovim configuration built on [AstroNvim v4](https://github.com/AstroNvim/AstroNvim) with [lazy.nvim](https://github.com/folke/lazy.nvim).

## Structure

```
lua/
  lazy_setup.lua        -- lazy.nvim bootstrap, loads AstroNvim + plugins
  community.lua         -- AstroCommunity imports (Lua pack, Monokai Pro)
  polish.lua            -- Post-setup hooks
  plugins/              -- Plugin specs
  user/                 -- Custom modules (http client, sticky notes, etc.)
ftplugin/               -- Filetype-specific settings (Python, Prolog)
syntax/                 -- Custom syntax files (HTTP)
```

## Notable Customizations

Most AstroNvim defaults are kept as-is. Customization is focused on:

- **Theme:** Monokai Pro (with a configured but inactive Catppuccin Mocha setup)
- **HTTP Client:** IntelliJ-style `.http` file runner with environment variables, curl execution, and `jq` formatting
- **Sticky Notes:** Floating window note system with tabs, todo checkboxes, and JSON persistence
- **Yank History:** Enhanced yank ring via yanky.nvim with a Telescope picker and in-prompt commands
- **Language runners** (`<Leader>Pp` / `<Alt-x>`): Python, JavaScript, Prolog

## Key Bindings

Leader: `<Space>` | Local leader: `,`

| Binding | Description |
|---|---|
| `<Leader>rr` | Run HTTP request under cursor (`.http` files) |
| `<Leader>re` | Run HTTP request with environment prompt |
| `<Leader>Pn` | Toggle sticky note window |
| `<Leader>fy` / `<Leader>Py` | Open yank history (Telescope) |
| `<Leader>tl` / `<Alt-t>` | Floating terminal in current file's directory |
| `<Leader>jr` | Run current Java file |
| `<Leader>jsr` | Run current JS file |
| `<Leader>Pp` / `<Alt-x>` | Run file (Python, JavaScript, Prolog) |
