# wireview-ide-support

IDE plugins for [django-wireview](https://github.com/itda-work/django-wireview) - Phoenix LiveView-style real-time components for Django.

## Plugins

| IDE | Status | Location |
|-----|--------|----------|
| VSCode | Phase 1 (In Progress) | `vscode/` |
| Neovim | Phase 2 (Planned) | `nvim/` |
| PyCharm | Future | `pycharm/` |

## Features

- **Component Autocompletion**: `{% component 'Name' %}`
- **Go to Definition**: Jump to Python class from template
- **Attribute Completion**: Pydantic fields with types
- **Event Handler Completion**: `{% on 'click' 'handler' %}`
- **Hover Documentation**: Docstrings, fields, slots

## Prerequisites

- Django project with `django-wireview` installed
- Run `python manage.py wireview_lsp` to generate metadata

## VSCode Extension

```bash
cd vscode
npm install
npm run compile
```

See [vscode/README.md](vscode/README.md) for details.

## License

MIT
