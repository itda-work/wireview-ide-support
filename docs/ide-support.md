# IDE Support for django-wireview

django-wireview provides IDE plugins for better developer experience with autocompletion, go-to-definition, and hover documentation.

## VSCode Extension

### Installation

1. Install from VSCode Marketplace (when published)
2. Or build from source:
   ```bash
   cd vscode-extension
   npm install
   npm run compile
   npm run package
   # Install the generated .vsix file
   ```

### Features

#### Component Autocompletion

When typing `{% component '`, the extension shows all available components:

```html
{% component 'Counter' count=10 %}
```

Three naming formats are supported:
- Simple: `Counter`
- FQN: `myapp.live.Counter`
- App prefix: `myapp:Counter`

#### Attribute Completion

After the component name, get Pydantic field suggestions with type information:

```html
{% component 'Counter' count=10 title="My Counter" %}
```

#### Event Handler Completion

Inside `{% on %}` tags, get method suggestions:

```html
{% on 'click' 'increment' amount=1 %}
```

Only async methods (event handlers) are suggested.

#### Event Modifiers

Type `.` after the event name for modifier suggestions:

```html
{% on 'click.prevent.debounce.300' 'search' %}
```

Available modifiers:
| Modifier | Description |
|----------|-------------|
| `prevent` | `event.preventDefault()` |
| `stop` | `event.stopPropagation()` |
| `debounce.{ms}` | Debounce handler |
| `throttle.{ms}` | Throttle handler |
| `ctrl`, `alt`, `shift`, `meta` | Key modifiers |
| `enter`, `tab`, `esc`, `space` | Key shortcuts |
| `up`, `down`, `left`, `right` | Arrow keys |

#### Go to Definition

- **Ctrl+Click** (or **Cmd+Click** on Mac) on component names to jump to Python class
- **Ctrl+Click** on handler names to jump to method definition

#### Hover Documentation

Hover over:
- **Component names** - Shows docstring, fields, slots
- **Handler names** - Shows signature, docstring
- **Attributes** - Shows type, default value
- **Modifiers** - Shows description

### Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `wireview.pythonPath` | `"python"` | Path to Python interpreter |
| `wireview.djangoSettingsModule` | `""` | Django settings module |
| `wireview.autoRefreshMetadata` | `true` | Auto-refresh on Python file changes |
| `wireview.metadataPath` | `".wireview/metadata.json"` | Metadata cache path |

### Commands

- **wireview: Refresh Metadata** - Manually refresh component metadata

## Neovim Plugin (Phase 2)

Coming soon! The Neovim plugin will provide similar features using Lua.

## How It Works

### Metadata Extraction

The IDE plugins use the `wireview_lsp` Django management command to extract component metadata:

```bash
python manage.py wireview_lsp --output=.wireview/metadata.json --pretty
```

This outputs JSON containing:
- All registered components
- Pydantic fields with types and defaults
- Async methods (event handlers) with signatures
- Slots definitions
- Event modifiers

### Metadata Schema

```json
{
  "version": "1.0",
  "generated_at": "2024-01-15T10:00:00Z",
  "components": {
    "Counter": {
      "name": "Counter",
      "fqn": "myapp.live.Counter",
      "app_key": "myapp:Counter",
      "module": "myapp.live",
      "file_path": "/path/to/live.py",
      "line_number": 15,
      "docstring": "A simple counter component.",
      "template_name": "myapp/counter.html",
      "fields": {
        "count": {
          "type": "int",
          "default": 0,
          "required": false
        }
      },
      "methods": {
        "increment": {
          "is_async": true,
          "parameters": {
            "amount": {"type": "int", "default": 1}
          },
          "docstring": "Increment the counter"
        }
      },
      "slots": {},
      "subscriptions": [],
      "subscriptions_is_dynamic": false
    }
  },
  "modifiers": {
    "prevent": {
      "description": "Calls event.preventDefault()",
      "has_argument": false
    },
    "debounce": {
      "description": "Debounce the event handler",
      "has_argument": true
    }
  }
}
```

### Component Registration

Components are discovered via:
1. `Component._all` - Simple names
2. `Component._by_fqn` - Fully qualified names
3. `Component._by_app` - App-prefixed names

Dynamic properties like `@property _subscriptions` are detected and flagged.

## Troubleshooting

### Metadata not loading

1. Check that `manage.py` is in your workspace root
2. Run `python manage.py wireview_lsp` manually to check for errors
3. Check the Output panel (View → Output → django-wireview)

### Completions not showing

1. Make sure you're in a `.html` file
2. Check that the file is recognized as Django HTML
3. Try running **wireview: Refresh Metadata** command

### Go to Definition not working

1. Verify the component file path is correct in metadata
2. Check that the file exists and is accessible
