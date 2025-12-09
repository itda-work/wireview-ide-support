/**
 * Completion handler for wireview components.
 *
 * Provides autocompletion for:
 * - Component names
 * - Component attributes (Pydantic fields)
 * - Event handlers (async methods)
 * - Event modifiers
 * - Slot names
 */

import {
  CompletionItem,
  CompletionItemKind,
  InsertTextFormat,
  MarkupKind,
} from "vscode-languageserver/node";

import { CursorContext } from "../parser/template.js";
import { WireviewMetadata, ComponentMetadata } from "../metadata/types.js";

/**
 * Get completion items based on cursor context.
 */
export function getCompletions(
  context: CursorContext,
  metadata: WireviewMetadata
): CompletionItem[] {
  switch (context.position) {
    case "component_name":
      return getComponentCompletions(metadata, context.currentValue);
    case "attribute_name":
      return getAttributeCompletions(metadata, context.componentName);
    case "handler_name":
      return getHandlerCompletions(metadata, context.componentName);
    case "event_name":
      return getEventCompletions();
    case "modifier":
      return getModifierCompletions(metadata, context.currentValue);
    case "slot_name":
      return getSlotCompletions(metadata, context.componentName);
    default:
      return [];
  }
}

/**
 * Get component name completions.
 */
function getComponentCompletions(
  metadata: WireviewMetadata,
  prefix?: string
): CompletionItem[] {
  const items: CompletionItem[] = [];
  const lowerPrefix = prefix?.toLowerCase() || "";

  for (const [name, component] of Object.entries(metadata.components)) {
    // Filter by prefix
    if (lowerPrefix && !name.toLowerCase().startsWith(lowerPrefix)) {
      continue;
    }

    // Simple name completion
    items.push({
      label: name,
      kind: CompletionItemKind.Class,
      detail: component.fqn,
      documentation: {
        kind: MarkupKind.Markdown,
        value: buildComponentDoc(component),
      },
      insertText: name,
      sortText: `0${name}`, // Prioritize simple names
    });

    // FQN completion
    if (
      !lowerPrefix ||
      component.fqn.toLowerCase().startsWith(lowerPrefix)
    ) {
      items.push({
        label: component.fqn,
        kind: CompletionItemKind.Class,
        detail: "Fully Qualified Name",
        documentation: {
          kind: MarkupKind.Markdown,
          value: buildComponentDoc(component),
        },
        insertText: component.fqn,
        sortText: `1${component.fqn}`, // Lower priority than simple names
      });
    }

    // App prefix completion
    if (
      !lowerPrefix ||
      component.app_key.toLowerCase().startsWith(lowerPrefix)
    ) {
      items.push({
        label: component.app_key,
        kind: CompletionItemKind.Class,
        detail: "App-prefixed name",
        documentation: {
          kind: MarkupKind.Markdown,
          value: buildComponentDoc(component),
        },
        insertText: component.app_key,
        sortText: `2${component.app_key}`, // Lowest priority
      });
    }
  }

  return items;
}

/**
 * Get attribute completions for a component.
 */
function getAttributeCompletions(
  metadata: WireviewMetadata,
  componentName?: string
): CompletionItem[] {
  if (!componentName) return [];

  const component = findComponent(metadata, componentName);
  if (!component) return [];

  const items: CompletionItem[] = [];

  for (const [name, field] of Object.entries(component.fields)) {
    const defaultStr = field.default !== null ? ` = ${JSON.stringify(field.default)}` : "";
    const requiredStr = field.required ? " (required)" : "";

    items.push({
      label: name,
      kind: CompletionItemKind.Property,
      detail: `${field.type}${defaultStr}${requiredStr}`,
      documentation: field.description || undefined,
      insertText: `${name}=`,
      insertTextFormat: InsertTextFormat.PlainText,
    });
  }

  return items;
}

/**
 * Get event handler completions for a component.
 */
function getHandlerCompletions(
  metadata: WireviewMetadata,
  componentName?: string
): CompletionItem[] {
  if (!componentName) return [];

  const component = findComponent(metadata, componentName);
  if (!component) return [];

  const items: CompletionItem[] = [];

  // Filter to only user-defined async methods (event handlers)
  const excludedMethods = new Set([
    // Base Component methods
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
    // Pydantic methods
    "model_copy",
    "model_dump",
    "model_dump_json",
    "model_json_schema",
    "model_parametrized_name",
    "model_post_init",
    "model_rebuild",
    "model_validate",
    "model_validate_json",
    "model_validate_strings",
    "model_construct",
    "copy",
    "dict",
    "json",
    "parse_obj",
    "parse_raw",
    "parse_file",
    "from_orm",
    "construct",
    "new",
  ]);

  for (const [name, method] of Object.entries(component.methods)) {
    // Skip base class methods
    if (excludedMethods.has(name)) continue;

    // Only include async methods (event handlers should be async)
    if (!method.is_async) continue;

    const params = Object.entries(method.parameters)
      .map(([pname, pinfo]) => {
        const typeStr = pinfo.type ? `: ${pinfo.type}` : "";
        const defaultStr = pinfo.has_default ? ` = ${JSON.stringify(pinfo.default)}` : "";
        return `${pname}${typeStr}${defaultStr}`;
      })
      .join(", ");

    items.push({
      label: name,
      kind: CompletionItemKind.Method,
      detail: `async (${params})`,
      documentation: method.docstring
        ? {
            kind: MarkupKind.Markdown,
            value: method.docstring,
          }
        : undefined,
      insertText: name,
    });
  }

  return items;
}

/**
 * Get common DOM event name completions.
 */
function getEventCompletions(): CompletionItem[] {
  const events = [
    { name: "click", desc: "Mouse click event" },
    { name: "dblclick", desc: "Mouse double-click event" },
    { name: "mousedown", desc: "Mouse button pressed" },
    { name: "mouseup", desc: "Mouse button released" },
    { name: "mouseover", desc: "Mouse enters element" },
    { name: "mouseout", desc: "Mouse leaves element" },
    { name: "mousemove", desc: "Mouse moves over element" },
    { name: "input", desc: "Input value changed" },
    { name: "change", desc: "Input value changed (on blur)" },
    { name: "submit", desc: "Form submitted" },
    { name: "keydown", desc: "Key pressed down" },
    { name: "keyup", desc: "Key released" },
    { name: "keypress", desc: "Key pressed (deprecated)" },
    { name: "focus", desc: "Element received focus" },
    { name: "blur", desc: "Element lost focus" },
    { name: "scroll", desc: "Element scrolled" },
    { name: "load", desc: "Element loaded" },
    { name: "error", desc: "Error occurred" },
  ];

  return events.map((event) => ({
    label: event.name,
    kind: CompletionItemKind.Event,
    detail: event.desc,
    insertText: event.name,
  }));
}

/**
 * Get event modifier completions.
 */
function getModifierCompletions(
  metadata: WireviewMetadata,
  prefix?: string
): CompletionItem[] {
  const items: CompletionItem[] = [];
  const lowerPrefix = prefix?.toLowerCase() || "";

  for (const [name, modifier] of Object.entries(metadata.modifiers)) {
    // Skip internal modifiers
    if (name.startsWith("_") || name === "inlinejs") continue;

    // Filter by prefix
    if (lowerPrefix && !name.toLowerCase().startsWith(lowerPrefix)) {
      continue;
    }

    let insertText = name;
    if (modifier.has_argument) {
      insertText = `${name}.\${1:300}`; // Snippet with placeholder
    }

    items.push({
      label: name,
      kind: CompletionItemKind.Keyword,
      detail: modifier.description,
      documentation: modifier.docstring || undefined,
      insertText,
      insertTextFormat: modifier.has_argument
        ? InsertTextFormat.Snippet
        : InsertTextFormat.PlainText,
    });
  }

  return items;
}

/**
 * Get slot name completions for a component.
 */
function getSlotCompletions(
  metadata: WireviewMetadata,
  componentName?: string
): CompletionItem[] {
  if (!componentName) return [];

  const component = findComponent(metadata, componentName);
  if (!component) return [];

  const items: CompletionItem[] = [];

  for (const [name, slot] of Object.entries(component.slots)) {
    const requiredStr = slot.required ? " (required)" : "";

    items.push({
      label: name,
      kind: CompletionItemKind.Field,
      detail: `Slot${requiredStr}`,
      documentation: slot.doc || undefined,
      insertText: name,
    });
  }

  return items;
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

  if (component.docstring) {
    parts.push(component.docstring);
    parts.push("");
  }

  parts.push(`**Template**: \`${component.template_name}\``);
  parts.push("");

  // Fields
  const fieldEntries = Object.entries(component.fields);
  if (fieldEntries.length > 0) {
    parts.push("**Fields**:");
    for (const [name, field] of fieldEntries) {
      const defaultStr = field.default !== null ? ` = ${JSON.stringify(field.default)}` : "";
      const requiredStr = field.required ? " (required)" : "";
      parts.push(`- \`${name}\`: ${field.type}${defaultStr}${requiredStr}`);
    }
    parts.push("");
  }

  // Slots
  const slotEntries = Object.entries(component.slots);
  if (slotEntries.length > 0) {
    parts.push("**Slots**:");
    for (const [name, slot] of slotEntries) {
      const requiredStr = slot.required ? " (required)" : "";
      parts.push(`- \`${name}\`${requiredStr}: ${slot.doc || ""}`);
    }
  }

  return parts.join("\n");
}
