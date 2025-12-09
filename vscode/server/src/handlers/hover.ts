/**
 * Hover handler for wireview components.
 *
 * Provides hover documentation for:
 * - Component names (shows docstring, fields, slots)
 * - Event handlers (shows signature, docstring)
 * - Attributes (shows type, default value)
 * - Modifiers (shows description)
 */

import { Hover, MarkupKind } from "vscode-languageserver/node";

import { CursorContext } from "../parser/template.js";
import { WireviewMetadata, ComponentMetadata } from "../metadata/types.js";

/**
 * Get hover information based on cursor context.
 */
export function getHover(
  context: CursorContext,
  metadata: WireviewMetadata
): Hover | null {
  switch (context.position) {
    case "component_name":
      return getComponentHover(metadata, context.currentValue);
    case "handler_name":
      return getHandlerHover(
        metadata,
        context.componentName,
        context.currentValue
      );
    case "attribute_name":
      return getAttributeHover(
        metadata,
        context.componentName,
        context.currentValue
      );
    case "modifier":
      return getModifierHover(metadata, context.currentValue);
    case "slot_name":
      return getSlotHover(metadata, context.componentName, context.currentValue);
    default:
      return null;
  }
}

/**
 * Get hover information for a component name.
 */
function getComponentHover(
  metadata: WireviewMetadata,
  componentName?: string
): Hover | null {
  if (!componentName) return null;

  const component = findComponent(metadata, componentName);
  if (!component) return null;

  const content = buildComponentDoc(component);

  return {
    contents: {
      kind: MarkupKind.Markdown,
      value: content,
    },
  };
}

/**
 * Get hover information for an event handler.
 */
function getHandlerHover(
  metadata: WireviewMetadata,
  componentName?: string,
  handlerName?: string
): Hover | null {
  if (!componentName || !handlerName) return null;

  const component = findComponent(metadata, componentName);
  if (!component) return null;

  const method = component.methods[handlerName];
  if (!method) return null;

  const parts: string[] = [];

  // Signature
  const params = Object.entries(method.parameters)
    .map(([name, info]) => {
      const typeStr = info.type ? `: ${info.type}` : "";
      const defaultStr = info.has_default
        ? ` = ${JSON.stringify(info.default)}`
        : "";
      return `${name}${typeStr}${defaultStr}`;
    })
    .join(", ");

  const asyncStr = method.is_async ? "async " : "";
  parts.push(`\`\`\`python\n${asyncStr}def ${handlerName}(${params})\n\`\`\``);

  // Docstring
  if (method.docstring) {
    parts.push("");
    parts.push(method.docstring);
  }

  return {
    contents: {
      kind: MarkupKind.Markdown,
      value: parts.join("\n"),
    },
  };
}

/**
 * Get hover information for an attribute.
 */
function getAttributeHover(
  metadata: WireviewMetadata,
  componentName?: string,
  attributeName?: string
): Hover | null {
  if (!componentName || !attributeName) return null;

  const component = findComponent(metadata, componentName);
  if (!component) return null;

  const field = component.fields[attributeName];
  if (!field) return null;

  const parts: string[] = [];

  // Type and default
  const defaultStr =
    field.default !== null ? ` = ${JSON.stringify(field.default)}` : "";
  const requiredStr = field.required ? " (required)" : "";

  parts.push(`\`\`\`python\n${attributeName}: ${field.type}${defaultStr}\n\`\`\``);

  if (field.required) {
    parts.push("");
    parts.push("**Required field**");
  }

  if (field.description) {
    parts.push("");
    parts.push(field.description);
  }

  return {
    contents: {
      kind: MarkupKind.Markdown,
      value: parts.join("\n"),
    },
  };
}

/**
 * Get hover information for an event modifier.
 */
function getModifierHover(
  metadata: WireviewMetadata,
  modifierName?: string
): Hover | null {
  if (!modifierName) return null;

  const modifier = metadata.modifiers[modifierName];
  if (!modifier) return null;

  const parts: string[] = [];

  parts.push(`**${modifierName}**`);
  parts.push("");

  if (modifier.description) {
    parts.push(modifier.description);
  }

  if (modifier.has_argument) {
    parts.push("");
    parts.push("*Requires an argument* (e.g., `.debounce.300`)");
  }

  return {
    contents: {
      kind: MarkupKind.Markdown,
      value: parts.join("\n"),
    },
  };
}

/**
 * Get hover information for a slot name.
 */
function getSlotHover(
  metadata: WireviewMetadata,
  componentName?: string,
  slotName?: string
): Hover | null {
  if (!componentName || !slotName) return null;

  const component = findComponent(metadata, componentName);
  if (!component) return null;

  const slot = component.slots[slotName];
  if (!slot) return null;

  const parts: string[] = [];

  parts.push(`**Slot: ${slotName}**`);
  parts.push("");

  if (slot.required) {
    parts.push("*Required slot*");
    parts.push("");
  }

  if (slot.doc) {
    parts.push(slot.doc);
  }

  return {
    contents: {
      kind: MarkupKind.Markdown,
      value: parts.join("\n"),
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

/**
 * Build markdown documentation for a component.
 */
function buildComponentDoc(component: ComponentMetadata): string {
  const parts: string[] = [];

  parts.push(`## ${component.name}`);
  parts.push("");
  parts.push(`\`${component.fqn}\``);
  parts.push("");

  if (component.docstring) {
    parts.push(component.docstring);
    parts.push("");
  }

  parts.push(`**Template**: \`${component.template_name}\``);
  parts.push("");

  // Fields
  const fieldEntries = Object.entries(component.fields);
  if (fieldEntries.length > 0) {
    parts.push("### Fields");
    parts.push("");
    for (const [name, field] of fieldEntries) {
      const defaultStr =
        field.default !== null ? ` = ${JSON.stringify(field.default)}` : "";
      const requiredStr = field.required ? " *(required)*" : "";
      parts.push(`- \`${name}\`: ${field.type}${defaultStr}${requiredStr}`);
    }
    parts.push("");
  }

  // Event handlers
  const handlers = Object.entries(component.methods).filter(
    ([name, method]) => method.is_async && !isBaseMethod(name)
  );
  if (handlers.length > 0) {
    parts.push("### Event Handlers");
    parts.push("");
    for (const [name, method] of handlers) {
      const params = Object.keys(method.parameters).join(", ");
      parts.push(`- \`${name}(${params})\``);
    }
    parts.push("");
  }

  // Slots
  const slotEntries = Object.entries(component.slots);
  if (slotEntries.length > 0) {
    parts.push("### Slots");
    parts.push("");
    for (const [name, slot] of slotEntries) {
      const requiredStr = slot.required ? " *(required)*" : "";
      parts.push(`- \`${name}\`${requiredStr}: ${slot.doc || ""}`);
    }
  }

  return parts.join("\n");
}

/**
 * Check if a method name is a base Component method.
 */
function isBaseMethod(name: string): boolean {
  const baseMethods = new Set([
    "joined",
    "leaving",
    "notification",
    "mutation",
    "params_changed",
    "handle_hook_event",
    "broadcast",
    "deffer",
    "destroy",
    "focus_on",
    "skip_render",
    "force_render",
    "freeze",
    "dom",
    "stream",
    "stream_insert",
    "stream_delete",
    "assign_async",
    "allow_upload",
    "cancel_upload",
    "consume_uploads",
  ]);
  return baseMethods.has(name);
}
