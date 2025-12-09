/**
 * Go to Definition handler for wireview components.
 *
 * Provides navigation to:
 * - Component class definitions
 * - Event handler method definitions
 */

import { Definition, Location } from "vscode-languageserver/node";
import { URI } from "vscode-uri";

import { CursorContext } from "../parser/template.js";
import { WireviewMetadata, ComponentMetadata } from "../metadata/types.js";

/**
 * Get definition location based on cursor context.
 */
export function getDefinition(
  context: CursorContext,
  metadata: WireviewMetadata
): Definition | null {
  switch (context.position) {
    case "component_name":
      return getComponentDefinition(metadata, context.currentValue);
    case "handler_name":
      return getHandlerDefinition(
        metadata,
        context.componentName,
        context.currentValue
      );
    default:
      return null;
  }
}

/**
 * Get definition location for a component name.
 */
function getComponentDefinition(
  metadata: WireviewMetadata,
  componentName?: string
): Definition | null {
  if (!componentName) return null;

  const component = findComponent(metadata, componentName);
  if (!component || !component.file_path) return null;

  return {
    uri: URI.file(component.file_path).toString(),
    range: {
      start: { line: component.line_number - 1, character: 0 },
      end: { line: component.line_number - 1, character: 0 },
    },
  };
}

/**
 * Get definition location for an event handler method.
 */
function getHandlerDefinition(
  metadata: WireviewMetadata,
  componentName?: string,
  handlerName?: string
): Definition | null {
  if (!componentName || !handlerName) return null;

  const component = findComponent(metadata, componentName);
  if (!component || !component.file_path) return null;

  const method = component.methods[handlerName];
  if (!method) return null;

  // Use the method's line number if available
  const lineNumber = method.line_number || component.line_number;

  return {
    uri: URI.file(component.file_path).toString(),
    range: {
      start: { line: lineNumber - 1, character: 0 },
      end: { line: lineNumber - 1, character: 0 },
    },
  };
}

/**
 * Find a component by name (simple, FQN, or app prefix).
 */
function findComponent(
  metadata: WireviewMetadata,
  name: string
): ComponentMetadata | undefined {
  // Direct lookup
  if (metadata.components[name]) {
    return metadata.components[name];
  }

  // FQN or app prefix lookup
  for (const component of Object.values(metadata.components)) {
    if (component.fqn === name || component.app_key === name) {
      return component;
    }
  }

  return undefined;
}
