# django-wireview VSCode Extension

IDE support for [django-wireview](https://github.com/itda-work/django-wireview) - Phoenix LiveView-style real-time components for Django.

## Features

### Component Autocompletion

Type `{% component '` to see available components:

![Component completion](docs/images/component-completion.png)

- **Simple names**: `Counter`
- **FQN names**: `myapp.live.Counter`
- **App prefix**: `myapp:Counter`

### Attribute Completion

After the component name, get Pydantic field suggestions:

```html
{% component 'Counter' count=10 title="My Counter" %}
```

### Event Handler Completion

Inside `{% on %}` tags, get method suggestions:

```html
{% on 'click' 'increment' amount=1 %}
```

### Event Modifiers

Type `.` after the event name for modifier suggestions:

```html
{% on 'click.prevent.debounce.300' 'search' %}
```

Available modifiers:
- `prevent` - `event.preventDefault()`
- `stop` - `event.stopPropagation()`
- `debounce.{ms}` - Debounce handler
- `throttle.{ms}` - Throttle handler
- `ctrl`, `alt`, `shift`, `meta` - Key modifiers
- `enter`, `tab`, `esc`, etc. - Key shortcuts

### Go to Definition

- **Ctrl+Click** on component names to jump to Python class
- **Ctrl+Click** on handler names to jump to method definition

### Hover Documentation

Hover over components, handlers, or attributes to see documentation.

## Requirements

- Python 3.10+
- Django project with `django-wireview` installed
- `manage.py` in your workspace

## Installation

1. Install the extension from VSCode Marketplace
2. Open your Django project
3. The extension will automatically detect `manage.py` and load component metadata

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `wireview.pythonPath` | `"python"` | Path to Python interpreter |
| `wireview.djangoSettingsModule` | `""` | Django settings module |
| `wireview.autoRefreshMetadata` | `true` | Auto-refresh on Python file changes |
| `wireview.metadataPath` | `".wireview/metadata.json"` | Metadata cache path |

## Commands

- **wireview: Refresh Metadata** - Manually refresh component metadata

## How It Works

1. The extension runs `python manage.py wireview_lsp` to extract component metadata
2. Metadata is cached in `.wireview/metadata.json`
3. The LSP server provides completions based on this metadata

## Development

```bash
cd vscode-extension

# Install dependencies
npm install
cd server && npm install && cd ..

# Compile
npm run compile

# Watch mode
npm run watch

# Debug
# Press F5 in VSCode to launch Extension Development Host
```

## License

MIT
