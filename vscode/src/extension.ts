/**
 * VSCode extension entry point for django-wireview.
 *
 * This extension provides IDE support for django-wireview components:
 * - Component name autocompletion
 * - Go to Definition
 * - Attribute completion (Pydantic fields)
 * - Event handler completion
 * - Hover documentation
 */

import * as path from "path";
import {
  ExtensionContext,
  workspace,
  window,
  commands,
  StatusBarAlignment,
  StatusBarItem,
} from "vscode";
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  TransportKind,
} from "vscode-languageclient/node";

let client: LanguageClient | undefined;
let statusBarItem: StatusBarItem;

export async function activate(context: ExtensionContext): Promise<void> {
  // Create status bar item
  statusBarItem = window.createStatusBarItem(StatusBarAlignment.Right, 100);
  statusBarItem.text = "$(sync~spin) wireview";
  statusBarItem.tooltip = "django-wireview: Loading...";
  statusBarItem.show();
  context.subscriptions.push(statusBarItem);

  // Server module path
  const serverModule = context.asAbsolutePath(
    path.join("out", "server", "server.js")
  );

  // Debug options for the server
  const debugOptions = { execArgv: ["--nolazy", "--inspect=6009"] };

  // Server options
  const serverOptions: ServerOptions = {
    run: { module: serverModule, transport: TransportKind.ipc },
    debug: {
      module: serverModule,
      transport: TransportKind.ipc,
      options: debugOptions,
    },
  };

  // Client options
  const clientOptions: LanguageClientOptions = {
    // Register for Django HTML files
    documentSelector: [
      { scheme: "file", language: "django-html" },
      { scheme: "file", language: "html", pattern: "**/*.html" },
    ],
    synchronize: {
      // Watch for Python file changes to refresh metadata
      fileEvents: workspace.createFileSystemWatcher("**/*.py"),
    },
  };

  // Create the language client
  client = new LanguageClient(
    "wireview",
    "django-wireview",
    serverOptions,
    clientOptions
  );

  // Register commands
  context.subscriptions.push(
    commands.registerCommand("wireview.refreshMetadata", async () => {
      if (client) {
        await client.sendRequest("wireview/refreshMetadata");
        window.showInformationMessage("wireview: Metadata refreshed");
      }
    })
  );

  // Start the client
  try {
    await client.start();
    statusBarItem.text = "$(check) wireview";
    statusBarItem.tooltip = "django-wireview: Ready";
  } catch (error) {
    statusBarItem.text = "$(error) wireview";
    statusBarItem.tooltip = `django-wireview: Error - ${error}`;
    window.showErrorMessage(`wireview: Failed to start - ${error}`);
  }
}

export async function deactivate(): Promise<void> {
  if (client) {
    await client.stop();
  }
}
