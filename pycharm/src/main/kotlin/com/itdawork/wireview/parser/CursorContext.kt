package com.itdawork.wireview.parser

enum class TagType {
    COMPONENT,
    COMPONENT_BLOCK,
    ON,
    FILL,
    RENDER_SLOT
}

enum class CursorPosition {
    COMPONENT_NAME,
    ATTRIBUTE_NAME,
    ATTRIBUTE_VALUE,
    HANDLER_NAME,
    EVENT_NAME,
    MODIFIER,
    SLOT_NAME,
    OUTSIDE
}

data class CursorContext(
    val inWireviewTag: Boolean = false,
    val tagType: TagType? = null,
    val position: CursorPosition = CursorPosition.OUTSIDE,
    val componentName: String? = null,
    val currentValue: String? = null,
    val attributeName: String? = null,
    val eventName: String? = null
)
