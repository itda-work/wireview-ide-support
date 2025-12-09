package com.itdawork.wireview.parser

import com.intellij.openapi.editor.Editor
import com.intellij.psi.PsiFile

object TemplateParser {
    private val TAG_PATTERN = Regex("""\{%\s*(\w+)""")
    private val COMPONENT_NAME_PATTERN = Regex("""\{%-?\s*component(?:_block)?\s+['"]([^'"]+)['"]""")
    private val EVENT_NAME_PATTERN = Regex("""\{%-?\s*on\s+['"]([^'"\.]+)""")
    private val HANDLER_NAME_PATTERN = Regex("""\{%-?\s*on\s+['"][^'"]+['"]\s+['"]([^'"]+)['"]""")
    private val FILL_SLOT_PATTERN = Regex("""\{%-?\s*fill\s+['"]?(\w+)['"]?""")

    private val TAG_TYPES = setOf("component", "component_block", "on", "fill", "render_slot")

    fun getCursorContext(editor: Editor, psiFile: PsiFile): CursorContext {
        val document = editor.document
        val offset = editor.caretModel.offset
        val text = document.text

        return getCursorContextFromString(text, offset)
    }

    fun getCursorContextFromString(content: String, offset: Int): CursorContext {
        val defaultContext = CursorContext()

        // Find enclosing tag
        val tagInfo = findEnclosingTag(content, offset) ?: return defaultContext
        val (tagContent, tagStart) = tagInfo
        val cursorInTag = offset - tagStart

        // Detect tag type
        val tagType = detectTagType(tagContent) ?: return defaultContext

        return when (tagType) {
            TagType.COMPONENT, TagType.COMPONENT_BLOCK -> parseComponentTag(tagContent, cursorInTag, content, offset)
            TagType.ON -> parseOnTag(tagContent, cursorInTag, content, offset)
            TagType.FILL -> parseFillTag(tagContent, cursorInTag)
            TagType.RENDER_SLOT -> parseRenderSlotTag(tagContent, cursorInTag)
        }
    }

    private fun findEnclosingTag(content: String, offset: Int): Pair<String, Int>? {
        var searchPos = 0
        while (searchPos < content.length) {
            val tagStart = content.indexOf("{%", searchPos)
            if (tagStart == -1) break

            val tagEnd = content.indexOf("%}", tagStart)
            if (tagEnd == -1) break

            val actualEnd = tagEnd + 2
            if (offset in tagStart until actualEnd) {
                return Pair(content.substring(tagStart, actualEnd), tagStart)
            }

            searchPos = actualEnd
        }
        return null
    }

    private fun detectTagType(tagContent: String): TagType? {
        val match = TAG_PATTERN.find(tagContent) ?: return null
        val tagName = match.groupValues[1]

        return when (tagName) {
            "component" -> TagType.COMPONENT
            "component_block" -> TagType.COMPONENT_BLOCK
            "on" -> TagType.ON
            "fill" -> TagType.FILL
            "render_slot" -> TagType.RENDER_SLOT
            else -> null
        }
    }

    private fun parseComponentTag(tagContent: String, cursorInTag: Int, fullContent: String, offset: Int): CursorContext {
        val beforeCursor = tagContent.substring(0, minOf(cursorInTag, tagContent.length))

        // Extract component name
        val compMatch = COMPONENT_NAME_PATTERN.find(tagContent)
        val componentName = compMatch?.groupValues?.get(1)

        // Check if cursor is in component name position
        val inNameSingle = Regex("""\{%-?\s*component(?:_block)?\s+'([^']*)$""").find(beforeCursor)
        val inNameDouble = Regex("""\{%-?\s*component(?:_block)?\s+"([^"]*)$""").find(beforeCursor)

        if (inNameSingle != null) {
            return CursorContext(
                inWireviewTag = true,
                tagType = detectTagType(tagContent),
                position = CursorPosition.COMPONENT_NAME,
                currentValue = inNameSingle.groupValues[1]
            )
        }

        if (inNameDouble != null) {
            return CursorContext(
                inWireviewTag = true,
                tagType = detectTagType(tagContent),
                position = CursorPosition.COMPONENT_NAME,
                currentValue = inNameDouble.groupValues[1]
            )
        }

        // Check if in attribute section
        val afterName = Regex("""['"](\s+.*)$""").find(beforeCursor)?.groupValues?.get(1)
        if (afterName != null) {
            // Check for attribute value: name=|
            val attrWithEquals = Regex("""(\w+)\s*=\s*$""").find(afterName)
            if (attrWithEquals != null) {
                return CursorContext(
                    inWireviewTag = true,
                    tagType = detectTagType(tagContent),
                    position = CursorPosition.ATTRIBUTE_VALUE,
                    componentName = componentName,
                    attributeName = attrWithEquals.groupValues[1],
                    currentValue = ""
                )
            }

            // Check for attribute value with quote: name='|
            val attrWithQuote = Regex("""(\w+)\s*=\s*['"]([^'"]*)$""").find(afterName)
            if (attrWithQuote != null) {
                return CursorContext(
                    inWireviewTag = true,
                    tagType = detectTagType(tagContent),
                    position = CursorPosition.ATTRIBUTE_VALUE,
                    componentName = componentName,
                    attributeName = attrWithQuote.groupValues[1],
                    currentValue = attrWithQuote.groupValues[2]
                )
            }

            // In attribute name position
            val partialAttr = Regex("""(\w*)$""").find(afterName)
            return CursorContext(
                inWireviewTag = true,
                tagType = detectTagType(tagContent),
                position = CursorPosition.ATTRIBUTE_NAME,
                componentName = componentName,
                currentValue = partialAttr?.groupValues?.get(1) ?: ""
            )
        }

        return CursorContext(
            inWireviewTag = true,
            tagType = detectTagType(tagContent),
            position = CursorPosition.OUTSIDE,
            componentName = componentName
        )
    }

    private fun parseOnTag(tagContent: String, cursorInTag: Int, fullContent: String, offset: Int): CursorContext {
        val beforeCursor = tagContent.substring(0, minOf(cursorInTag, tagContent.length))

        // Extract event name
        val eventMatch = EVENT_NAME_PATTERN.find(tagContent)
        val eventName = eventMatch?.groupValues?.get(1)

        // Check if in event name position
        val inEventSingle = Regex("""\{%-?\s*on\s+'([^']*)$""").find(beforeCursor)
        val inEventDouble = Regex("""\{%-?\s*on\s+"([^"]*)$""").find(beforeCursor)

        if (inEventSingle != null) {
            val value = inEventSingle.groupValues[1]
            return if (value.contains(".")) {
                CursorContext(
                    inWireviewTag = true,
                    tagType = TagType.ON,
                    position = CursorPosition.MODIFIER,
                    eventName = value.substringBefore("."),
                    currentValue = value.substringAfterLast(".")
                )
            } else {
                CursorContext(
                    inWireviewTag = true,
                    tagType = TagType.ON,
                    position = CursorPosition.EVENT_NAME,
                    currentValue = value
                )
            }
        }

        if (inEventDouble != null) {
            val value = inEventDouble.groupValues[1]
            return if (value.contains(".")) {
                CursorContext(
                    inWireviewTag = true,
                    tagType = TagType.ON,
                    position = CursorPosition.MODIFIER,
                    eventName = value.substringBefore("."),
                    currentValue = value.substringAfterLast(".")
                )
            } else {
                CursorContext(
                    inWireviewTag = true,
                    tagType = TagType.ON,
                    position = CursorPosition.EVENT_NAME,
                    currentValue = value
                )
            }
        }

        // Check if in handler name position
        val inHandlerSingle = Regex("""['"]\s+['"]([^']*)$""").find(beforeCursor)
        val inHandlerDouble = Regex("""['"]\s+"([^"]*)$""").find(beforeCursor)

        if (inHandlerSingle != null || inHandlerDouble != null) {
            val handlerValue = inHandlerSingle?.groupValues?.get(1) ?: inHandlerDouble?.groupValues?.get(1) ?: ""

            // Find parent component
            val parentComponent = findParentComponent(fullContent, offset)

            return CursorContext(
                inWireviewTag = true,
                tagType = TagType.ON,
                position = CursorPosition.HANDLER_NAME,
                componentName = parentComponent,
                eventName = eventName,
                currentValue = handlerValue
            )
        }

        // Check if after event, expecting handler
        if (Regex("""['"]\s+$""").containsMatchIn(beforeCursor)) {
            val parentComponent = findParentComponent(fullContent, offset)
            return CursorContext(
                inWireviewTag = true,
                tagType = TagType.ON,
                position = CursorPosition.HANDLER_NAME,
                componentName = parentComponent,
                eventName = eventName,
                currentValue = ""
            )
        }

        return CursorContext(
            inWireviewTag = true,
            tagType = TagType.ON,
            position = CursorPosition.OUTSIDE,
            eventName = eventName
        )
    }

    private fun parseFillTag(tagContent: String, cursorInTag: Int): CursorContext {
        val beforeCursor = tagContent.substring(0, minOf(cursorInTag, tagContent.length))

        val inSlotBare = Regex("""\{%-?\s*fill\s+(\w*)$""").find(beforeCursor)
        val inSlotSingle = Regex("""\{%-?\s*fill\s+'([^']*)$""").find(beforeCursor)
        val inSlotDouble = Regex("""\{%-?\s*fill\s+"([^"]*)$""").find(beforeCursor)

        val slotValue = inSlotBare?.groupValues?.get(1)
            ?: inSlotSingle?.groupValues?.get(1)
            ?: inSlotDouble?.groupValues?.get(1)

        return if (slotValue != null) {
            CursorContext(
                inWireviewTag = true,
                tagType = TagType.FILL,
                position = CursorPosition.SLOT_NAME,
                currentValue = slotValue
            )
        } else {
            CursorContext(
                inWireviewTag = true,
                tagType = TagType.FILL,
                position = CursorPosition.OUTSIDE
            )
        }
    }

    private fun parseRenderSlotTag(tagContent: String, cursorInTag: Int): CursorContext {
        val beforeCursor = tagContent.substring(0, minOf(cursorInTag, tagContent.length))

        val inSlotBare = Regex("""\{%-?\s*render_slot\s+(\w*)$""").find(beforeCursor)
        val inSlotSingle = Regex("""\{%-?\s*render_slot\s+'([^']*)$""").find(beforeCursor)
        val inSlotDouble = Regex("""\{%-?\s*render_slot\s+"([^"]*)$""").find(beforeCursor)

        val slotValue = inSlotBare?.groupValues?.get(1)
            ?: inSlotSingle?.groupValues?.get(1)
            ?: inSlotDouble?.groupValues?.get(1)

        return if (slotValue != null) {
            CursorContext(
                inWireviewTag = true,
                tagType = TagType.RENDER_SLOT,
                position = CursorPosition.SLOT_NAME,
                currentValue = slotValue
            )
        } else {
            CursorContext(
                inWireviewTag = true,
                tagType = TagType.RENDER_SLOT,
                position = CursorPosition.OUTSIDE
            )
        }
    }

    private fun findParentComponent(content: String, offset: Int): String? {
        val searchContent = content.substring(0, offset)
        val componentStack = mutableListOf<String>()

        val openPattern = Regex("""\{%-?\s*component_block\s+['"]([^'"]+)['"]""")
        val closePattern = Regex("""\{%-?\s*endcomponent_block\s*%}""")

        var pos = 0
        while (pos < searchContent.length) {
            val openMatch = openPattern.find(searchContent, pos)
            val closeMatch = closePattern.find(searchContent, pos)

            val openStart = openMatch?.range?.first ?: Int.MAX_VALUE
            val closeStart = closeMatch?.range?.first ?: Int.MAX_VALUE

            when {
                openStart < closeStart && openMatch != null -> {
                    componentStack.add(openMatch.groupValues[1])
                    pos = openMatch.range.last + 1
                }
                closeStart < openStart && closeMatch != null -> {
                    if (componentStack.isNotEmpty()) {
                        componentStack.removeLast()
                    }
                    pos = closeMatch.range.last + 1
                }
                else -> break
            }
        }

        return componentStack.lastOrNull()
    }
}
