# wireview.nvim

Neovim plugin for [django-wireview](https://github.com/itda-work/django-wireview) - IDE support for wireview components.

## Features

- **Autocompletion** for components, attributes, handlers, events, and modifiers
- **Go-to-definition** for components and handlers
- **Hover documentation** with floating windows
- **Telescope integration** for component search
- **which-key integration** for keybinding discovery

## Requirements

- Neovim >= 0.9.0
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) for autocompletion
- Django project with [django-wireview](https://github.com/itda-work/django-wireview) installed

### Optional Dependencies

- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for component picker
- [which-key.nvim](https://github.com/folke/which-key.nvim) for keybinding guide

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "itda-work/wireview-ide-support",
  ft = { "htmldjango", "html" },
  dependencies = {
    "hrsh7th/nvim-cmp",
    "nvim-telescope/telescope.nvim", -- optional
    "folke/which-key.nvim", -- optional
  },
  opts = {
    python_path = "python",
    django_settings = "", -- e.g., "myproject.settings"
    auto_refresh = true,
  },
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "itda-work/wireview-ide-support",
  requires = {
    "hrsh7th/nvim-cmp",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("wireview").setup({
      python_path = "python",
      auto_refresh = true,
    })
  end,
}
```

## Configuration

```lua
require("wireview").setup({
  -- Python executable path
  python_path = "python",

  -- Django settings module (optional)
  django_settings = "",

  -- Path to metadata JSON file
  metadata_path = ".wireview/metadata.json",

  -- Auto refresh metadata on startup
  auto_refresh = true,

  -- Refresh metadata when Python files are saved
  refresh_on_save = true,

  -- Cache TTL in seconds (5 minutes default)
  cache_ttl = 300,

  -- Enable features
  enable_completion = true,
  enable_hover = true,
  enable_definition = true,

  -- Debug logging
  debug = false,
})
```

## nvim-cmp Setup

Add wireview as a completion source:

```lua
require("cmp").setup({
  sources = {
    { name = "wireview" },
    { name = "nvim_lsp" },
    { name = "buffer" },
    -- other sources...
  },
})
```

## Keymaps

Default keymaps in `htmldjango` and `html` files:

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `K` | Show hover documentation |

### which-key Integration

```lua
-- Enable which-key integration with custom prefix
require("wireview.whichkey").setup({
  prefix = "<leader>w", -- default
})
```

This adds the following keymaps:

| Key | Action |
|-----|--------|
| `<leader>wr` | Refresh metadata |
| `<leader>ws` | Show status |
| `<leader>wd` | Go to definition |
| `<leader>wh` | Show hover |
| `<leader>wf` | Find components (Telescope) |

## Commands

| Command | Description |
|---------|-------------|
| `:WireviewStatus` | Show plugin status and metadata info |
| `:WireviewRefresh` | Refresh metadata from Python |
| `:WireviewGotoDefinition` | Go to component/handler definition |
| `:WireviewHover` | Show hover documentation |

## Telescope

Search components with Telescope:

```vim
:Telescope wireview
:Telescope wireview components
```

Or from Lua:

```lua
require("wireview.telescope").components()
```

## Completion

The plugin provides autocompletion for:

- **Component names** - `{% component 'Counter' %}`
- **Attributes** - `{% component 'Counter' count=0 %}`
- **Event handlers** - `{% on 'click' 'increment' %}`
- **Events** - `{% on 'click' ... %}`
- **Modifiers** - `{% on 'click.prevent.debounce.300' ... %}`
- **Slots** - `{% fill header %}`

Trigger characters: `'`, `"`, ` ` (space), `.`

## Troubleshooting

### Metadata not loading

1. Ensure `manage.py` exists in your project
2. Run `:WireviewStatus` to check configuration
3. Run `:WireviewRefresh` to manually refresh
4. Check `:messages` for errors

### "wireview_lsp command not found"

Install django-wireview:

```bash
pip install django-wireview
```

### Debug mode

Enable debug logging:

```lua
require("wireview").setup({
  debug = true,
})
```

## Related Projects

- [django-wireview](https://github.com/itda-work/django-wireview) - The Django library
- [VSCode Extension](../vscode/) - VSCode/Cursor extension for wireview

## License

MIT
