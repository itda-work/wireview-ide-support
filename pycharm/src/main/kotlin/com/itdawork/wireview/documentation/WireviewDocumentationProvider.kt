package com.itdawork.wireview.documentation

import com.intellij.lang.documentation.AbstractDocumentationProvider
import com.intellij.openapi.editor.Editor
import com.intellij.psi.PsiElement
import com.intellij.psi.PsiFile
import com.itdawork.wireview.models.ComponentMetadata
import com.itdawork.wireview.models.FieldInfo
import com.itdawork.wireview.models.MethodInfo
import com.itdawork.wireview.models.ModifierInfo
import com.itdawork.wireview.parser.CursorPosition
import com.itdawork.wireview.parser.TemplateParser
import com.itdawork.wireview.services.MetadataService

class WireviewDocumentationProvider : AbstractDocumentationProvider() {

    override fun generateDoc(element: PsiElement?, originalElement: PsiElement?): String? {
        val psiFile = originalElement?.containingFile ?: element?.containingFile ?: return null
        val project = psiFile.project
        val metadataService = MetadataService.getInstance(project)

        if (!metadataService.isLoaded) {
            return null
        }

        val offset = originalElement?.textOffset ?: element?.textOffset ?: return null
        val text = psiFile.text

        val context = TemplateParser.getCursorContextFromString(text, offset)

        if (!context.inWireviewTag) {
            return null
        }

        return when (context.position) {
            CursorPosition.COMPONENT_NAME -> {
                context.currentValue?.let { name ->
                    metadataService.getComponent(name)?.let { buildComponentDoc(it) }
                }
            }
            CursorPosition.ATTRIBUTE_NAME, CursorPosition.ATTRIBUTE_VALUE -> {
                val componentName = context.componentName
                val attrName = context.attributeName ?: context.currentValue
                if (componentName != null && attrName != null) {
                    val component = metadataService.getComponent(componentName)
                    component?.fields?.get(attrName)?.let { buildFieldDoc(attrName, it) }
                } else null
            }
            CursorPosition.HANDLER_NAME -> {
                val componentName = context.componentName
                val handlerName = context.currentValue
                if (componentName != null && handlerName != null) {
                    val component = metadataService.getComponent(componentName)
                    component?.methods?.get(handlerName)?.let { buildMethodDoc(handlerName, it) }
                } else null
            }
            CursorPosition.MODIFIER -> {
                context.currentValue?.let { name ->
                    metadataService.getModifier(name)?.let { buildModifierDoc(name, it) }
                }
            }
            CursorPosition.EVENT_NAME -> {
                context.currentValue?.let { buildEventDoc(it) }
            }
            else -> null
        }
    }

    override fun getQuickNavigateInfo(element: PsiElement?, originalElement: PsiElement?): String? {
        return generateDoc(element, originalElement)?.let { doc ->
            // Strip HTML for quick navigate info
            doc.replace(Regex("<[^>]+>"), "").take(200)
        }
    }

    override fun getCustomDocumentationElement(
        editor: Editor,
        file: PsiFile,
        contextElement: PsiElement?,
        targetOffset: Int
    ): PsiElement? {
        return contextElement
    }

    private fun buildComponentDoc(component: ComponentMetadata): String {
        return buildString {
            append("<html><body>")
            append("<h2>${component.name}</h2>")
            append("<p><code>${component.fqn}</code></p>")

            component.docstring?.let {
                append("<p>$it</p>")
            }

            component.templateName?.let {
                append("<p><b>Template:</b> <code>$it</code></p>")
            }

            // Fields
            if (component.fields.isNotEmpty()) {
                append("<h3>Fields</h3><ul>")
                for ((name, field) in component.fields) {
                    val type = field.type ?: "any"
                    val required = if (field.required) " <i>(required)</i>" else ""
                    val default = field.default?.let { " = $it" } ?: ""
                    append("<li><code>$name</code>: $type$default$required</li>")
                }
                append("</ul>")
            }

            // Event Handlers
            val asyncMethods = component.methods.filter { (name, method) ->
                method.isAsync && !MetadataService.EXCLUDED_METHODS.contains(name)
            }
            if (asyncMethods.isNotEmpty()) {
                append("<h3>Event Handlers</h3><ul>")
                for ((name, method) in asyncMethods) {
                    val params = method.parameters.entries.joinToString(", ") { (pName, pInfo) ->
                        val pType = pInfo.type?.let { ": $it" } ?: ""
                        val pDefault = if (pInfo.hasDefault) " = ${pInfo.default}" else ""
                        "$pName$pType$pDefault"
                    }
                    append("<li><code>$name($params)</code></li>")
                }
                append("</ul>")
            }

            // Slots
            if (component.slots.isNotEmpty()) {
                append("<h3>Slots</h3><ul>")
                for ((name, slot) in component.slots) {
                    val required = if (slot.required) " <i>(required)</i>" else ""
                    val doc = if (slot.doc.isNotEmpty()) ": ${slot.doc}" else ""
                    append("<li><code>$name</code>$required$doc</li>")
                }
                append("</ul>")
            }

            append("</body></html>")
        }
    }

    private fun buildFieldDoc(name: String, field: FieldInfo): String {
        return buildString {
            append("<html><body>")
            append("<h3>$name</h3>")
            append("<pre>${field.type ?: "any"}</pre>")

            if (field.required) {
                append("<p><b>Required</b></p>")
            }

            field.default?.let {
                append("<p><b>Default:</b> $it</p>")
            }

            field.description?.let {
                append("<p>$it</p>")
            }

            append("</body></html>")
        }
    }

    private fun buildMethodDoc(name: String, method: MethodInfo): String {
        return buildString {
            append("<html><body>")

            val params = method.parameters.entries.joinToString(", ") { (pName, pInfo) ->
                val pType = pInfo.type?.let { ": $it" } ?: ""
                val pDefault = if (pInfo.hasDefault) " = ${pInfo.default}" else ""
                "$pName$pType$pDefault"
            }

            append("<pre>async def $name($params)</pre>")

            method.docstring?.let {
                append("<p>$it</p>")
            }

            append("</body></html>")
        }
    }

    private fun buildModifierDoc(name: String, modifier: ModifierInfo): String {
        return buildString {
            append("<html><body>")
            append("<h3>$name</h3>")
            append("<p>${modifier.description}</p>")

            if (modifier.hasArgument) {
                append("<p><i>Requires an argument (e.g., <code>$name.300</code>)</i></p>")
            }

            append("</body></html>")
        }
    }

    private fun buildEventDoc(eventName: String): String {
        return buildString {
            append("<html><body>")
            append("<h3>$eventName</h3>")
            append("<p>DOM event</p>")
            append("</body></html>")
        }
    }
}
