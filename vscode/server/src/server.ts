/**
 * LSP server for django-wireview.
 *
 * Provides language features for Django templates using wireview components:
 * - Completion for component names, attributes, and event handlers
 * - Go to Definition for components and methods
 * - Hover information
 */

import {
  createConnection,
  TextDocuments,
  ProposedFeatures,
  InitializeParams,
  InitializeResult,
  TextDocumentSyncKind,
  CompletionItem,
  CompletionItemKind,
  Definition,
  Hover,
  MarkupKind,
} from "vscode-languageserver/node";
import { TextDocument } from "vscode-languageserver-textdocument";

import { MetadataManager, WireviewMetadata } from "./metadata/manager.js";
import { TemplateParser, CursorContext } from "./parser/template.js";
import { getCompletions } from "./handlers/completion.js";
import { getDefinition } from "./handlers/definition.js";
import { getHover } from "./handlers/hover.js";

// Create connection
const connection = createConnection(ProposedFeatures.all);

// Document manager
const documents: TextDocuments<TextDocument> = new TextDocuments(TextDocument);

// Metadata manager (initialized on connection)
let metadataManager: MetadataManager;

// Template parser
const parser = new TemplateParser();

// Settings interface
interface WireviewSettings {
  pythonPath: string;
  djangoSettingsModule: string;
  autoRefreshMetadata: boolean;
  metadataPath: string;
}

// Default settings
const defaultSettings: WireviewSettings = {
  pythonPath: "python",
  djangoSettingsModule: "",
  autoRefreshMetadata: true,
  metadataPath: ".wireview/metadata.json",
};

let globalSettings: WireviewSettings = defaultSettings;

connection.onInitialize((params: InitializeParams): InitializeResult => {
  const workspaceFolders = params.workspaceFolders;
  const workspaceRoot = workspaceFolders?.[0]?.uri.replace("file://", "") || "";

  // Initialize metadata manager
  metadataManager = new MetadataManager(workspaceRoot, globalSettings);

  return {
    capabilities: {
      textDocumentSync: TextDocumentSyncKind.Incremental,
      completionProvider: {
        triggerCharacters: ["'", '"', " ", "."],
        resolveProvider: true,
      },
      definitionProvider: true,
      hoverProvider: true,
    },
  };
});

connection.onInitialized(async () => {
  // Load metadata on startup
  try {
    await metadataManager.refresh();
    connection.console.log("wireview: Metadata loaded successfully");
  } catch (error) {
    connection.console.error(`wireview: Failed to load metadata - ${error}`);
  }
});

// Handle configuration changes
connection.onDidChangeConfiguration((change) => {
  globalSettings = {
    ...defaultSettings,
    ...(change.settings?.wireview || {}),
  };

  if (metadataManager) {
    metadataManager.updateSettings(globalSettings);
  }
});

// Handle metadata refresh request
connection.onRequest("wireview/refreshMetadata", async () => {
  if (metadataManager) {
    await metadataManager.refresh();
    return { success: true };
  }
  return { success: false, error: "Metadata manager not initialized" };
});

// Completion handler
connection.onCompletion((params): CompletionItem[] => {
  const document = documents.get(params.textDocument.uri);
  if (!document) return [];

  const metadata = metadataManager?.getMetadata();
  if (!metadata) return [];

  const text = document.getText();
  const offset = document.offsetAt(params.position);
  const context = parser.getCursorContext(text, offset);

  return getCompletions(context, metadata);
});

// Completion resolve handler
connection.onCompletionResolve((item: CompletionItem): CompletionItem => {
  // Add additional details if needed
  return item;
});

// Definition handler
connection.onDefinition((params): Definition | null => {
  const document = documents.get(params.textDocument.uri);
  if (!document) return null;

  const metadata = metadataManager?.getMetadata();
  if (!metadata) return null;

  const text = document.getText();
  const offset = document.offsetAt(params.position);
  const context = parser.getCursorContext(text, offset);

  return getDefinition(context, metadata);
});

// Hover handler
connection.onHover((params): Hover | null => {
  const document = documents.get(params.textDocument.uri);
  if (!document) return null;

  const metadata = metadataManager?.getMetadata();
  if (!metadata) return null;

  const text = document.getText();
  const offset = document.offsetAt(params.position);
  const context = parser.getCursorContext(text, offset);

  return getHover(context, metadata);
});

// Watch for document changes
documents.onDidChangeContent((change) => {
  // Could add validation/diagnostics here
});

// Listen for document events
documents.listen(connection);

// Start listening
connection.listen();
