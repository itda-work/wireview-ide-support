package com.itdawork.wireview.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class WireviewMetadata(
    val version: String,
    @SerialName("generated_at")
    val generatedAt: String,
    val components: Map<String, ComponentMetadata> = emptyMap(),
    val modifiers: Map<String, ModifierInfo> = emptyMap()
)

@Serializable
data class ComponentMetadata(
    val name: String,
    val fqn: String,
    @SerialName("app_key")
    val appKey: String,
    val module: String = "",
    @SerialName("file_path")
    val filePath: String,
    @SerialName("line_number")
    val lineNumber: Int,
    val docstring: String? = null,
    @SerialName("template_name")
    val templateName: String? = null,
    val fields: Map<String, FieldInfo> = emptyMap(),
    val methods: Map<String, MethodInfo> = emptyMap(),
    val slots: Map<String, SlotInfo> = emptyMap(),
    val subscriptions: List<String> = emptyList(),
    @SerialName("subscriptions_is_dynamic")
    val subscriptionsIsDynamic: Boolean = false,
    @SerialName("temporary_assigns")
    val temporaryAssigns: List<String> = emptyList()
)

@Serializable
data class FieldInfo(
    val type: String? = null,
    val annotation: String? = null,
    val default: kotlinx.serialization.json.JsonElement? = null,
    val required: Boolean = false,
    val description: String? = null
)

@Serializable
data class MethodInfo(
    @SerialName("is_async")
    val isAsync: Boolean = false,
    val parameters: Map<String, ParameterInfo> = emptyMap(),
    val docstring: String? = null,
    @SerialName("line_number")
    val lineNumber: Int? = null
)

@Serializable
data class ParameterInfo(
    val type: String? = null,
    val default: kotlinx.serialization.json.JsonElement? = null,
    @SerialName("has_default")
    val hasDefault: Boolean = false,
    val kind: String? = null
)

@Serializable
data class SlotInfo(
    val required: Boolean = false,
    val doc: String = ""
)

@Serializable
data class ModifierInfo(
    val docstring: String? = null,
    val description: String = "",
    @SerialName("has_argument")
    val hasArgument: Boolean = false
)
