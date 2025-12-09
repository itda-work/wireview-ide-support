.PHONY: all install build lsp clean

# Default target
all: install build

# Path to django-wireview (sibling directory)
WIREVIEW_PATH ?= ../django-wireview

# =============================================================================
# Installation
# =============================================================================

install:
	cd vscode && npm install

# =============================================================================
# Build
# =============================================================================

build:
	cd vscode && npm run compile

watch:
	cd vscode && npm run watch

# =============================================================================
# LSP Metadata Generation
# =============================================================================

# Generate LSP metadata from django-wireview test project
lsp:
	cd $(WIREVIEW_PATH)/tests && uv run python manage.py wireview_lsp --pretty

# Save LSP metadata to .wireview/
lsp-save:
	mkdir -p .wireview
	cd $(WIREVIEW_PATH)/tests && uv run python manage.py wireview_lsp --output=$(CURDIR)/.wireview/metadata.json
	@echo "Metadata saved to .wireview/metadata.json"

# =============================================================================
# VSCode Extension
# =============================================================================

# Package VSCode extension
package:
	cd vscode && npm run package

# =============================================================================
# Cleanup
# =============================================================================

clean:
	rm -rf vscode/out vscode/node_modules vscode/server/node_modules
	rm -rf .wireview

# =============================================================================
# Help
# =============================================================================

help:
	@echo "wireview-ide-support Makefile"
	@echo ""
	@echo "Installation:"
	@echo "  make install          - Install npm dependencies"
	@echo ""
	@echo "Build:"
	@echo "  make build            - Build VSCode extension"
	@echo "  make watch            - Watch mode for development"
	@echo ""
	@echo "LSP Metadata:"
	@echo "  make lsp              - Generate metadata (stdout)"
	@echo "  make lsp-save         - Save metadata to .wireview/"
	@echo ""
	@echo "Packaging:"
	@echo "  make package          - Package VSCode extension (.vsix)"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean            - Remove build artifacts"
