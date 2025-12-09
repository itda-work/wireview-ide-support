# django-wireview PyCharm Plugin

PyCharm/IntelliJ plugin for [django-wireview](https://github.com/itda-work/django-wireview) - IDE support for wireview components.

## Features

- **Autocompletion** for components, attributes, handlers, events, and modifiers
- **Go-to-definition** for components and handlers (Ctrl+Click / Ctrl+B)
- **Hover documentation** (Ctrl+Q)
- **Metadata refresh** from Python

## Requirements

- PyCharm 2024.1 or later (Community or Professional)
- Django project with [django-wireview](https://github.com/itda-work/django-wireview) installed

## Installation

### From JetBrains Marketplace

1. Open PyCharm
2. Go to **Settings/Preferences > Plugins**
3. Search for "django-wireview"
4. Click **Install**

### Manual Installation

1. Download the latest `.zip` from [Releases](https://github.com/itda-work/wireview-ide-support/releases)
2. Go to **Settings/Preferences > Plugins**
3. Click the gear icon and select **Install Plugin from Disk...**
4. Select the downloaded file

## Configuration

Go to **Settings/Preferences > Tools > django-wireview**:

| Option | Default | Description |
|--------|---------|-------------|
| Python path | `python` | Path to Python executable |
| Django settings module | (empty) | e.g., `myproject.settings` |
| Metadata path | `.wireview/metadata.json` | Path to metadata file |
| Auto refresh | enabled | Refresh metadata on project open |
| Refresh on save | enabled | Refresh when Python files are saved |
| Cache TTL | 300s | Metadata cache duration |

## Usage

### Autocompletion

In Django template files (`*.html`):

- `{% component '` - triggers component name completion
- After component name - triggers attribute completion
- `{% on 'click' '` - triggers handler completion
- `{% on '` - triggers event name completion
- `{% on 'click.` - triggers modifier completion
- `{% fill ` - triggers slot completion

### Go to Definition

- **Ctrl+Click** or **Ctrl+B** on component names to jump to Python class
- **Ctrl+Click** on handler names to jump to Python method

### Hover Documentation

- **Ctrl+Q** on any wireview element to see documentation

### Manual Refresh

- **Tools > Wireview > Refresh Metadata**

## Building from Source

```bash
cd pycharm
./gradlew buildPlugin
```

The plugin will be in `build/distributions/`.

## Development

```bash
# Run IDE with plugin
./gradlew runIde

# Run tests
./gradlew test

# Check compatibility
./gradlew verifyPlugin
```

## Related Projects

- [django-wireview](https://github.com/itda-work/django-wireview) - The Django library
- [VSCode Extension](../vscode/) - VSCode/Cursor extension
- [Neovim Plugin](../nvim/) - Neovim plugin

## License

MIT
