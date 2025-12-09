/**
 * Type definitions for wireview metadata.
 *
 * These types match the JSON schema output by the Python wireview_lsp command.
 */

export interface FieldInfo {
  type: string;
  annotation: string | null;
  default: unknown;
  required: boolean;
  description: string | null;
}

export interface ParameterInfo {
  type: string | null;
  default: unknown;
  has_default: boolean;
  kind: string;
}

export interface MethodInfo {
  is_async: boolean;
  parameters: Record<string, ParameterInfo>;
  docstring: string | null;
  line_number: number;
}

export interface SlotInfo {
  required: boolean;
  doc: string;
}

export interface ModifierInfo {
  docstring: string | null;
  description: string;
  has_argument: boolean;
}

export interface ComponentMetadata {
  name: string;
  fqn: string;
  app_key: string;
  module: string;
  file_path: string;
  line_number: number;
  docstring: string | null;
  template_name: string;
  fields: Record<string, FieldInfo>;
  methods: Record<string, MethodInfo>;
  slots: Record<string, SlotInfo>;
  subscriptions: string[];
  subscriptions_is_dynamic: boolean;
  temporary_assigns: string[];
}

export interface WireviewMetadata {
  version: string;
  generated_at: string;
  components: Record<string, ComponentMetadata>;
  modifiers: Record<string, ModifierInfo>;
}
