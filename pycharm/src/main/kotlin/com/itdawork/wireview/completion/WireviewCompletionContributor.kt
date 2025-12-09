package com.itdawork.wireview.completion

import com.intellij.codeInsight.completion.*
import com.intellij.codeInsight.lookup.LookupElementBuilder
import com.intellij.icons.AllIcons
import com.intellij.openapi.project.Project
import com.intellij.patterns.PlatformPatterns
import com.intellij.psi.PsiElement
import com.intellij.util.ProcessingContext
import com.itdawork.wireview.models.ComponentMetadata
import com.itdawork.wireview.models.FieldInfo
import com.itdawork.wireview.models.MethodInfo
import com.itdawork.wireview.models.ModifierInfo
import com.itdawork.wireview.parser.CursorPosition
import com.itdawork.wireview.parser.TemplateParser
import com.itdawork.wireview.services.MetadataService
import javax.swing.Icon

class WireviewCompletionContributor : CompletionContributor() {
    init {
        extend(
            CompletionType.BASIC,
            PlatformPatterns.psiElement(),
            WireviewCompletionProvider()
        )
    }
}

class WireviewCompletionProvider : CompletionProvider<CompletionParameters>() {

    private val domEvents = listOf(
        "click", "dblclick", "mousedown", "mouseup", "mouseover", "mouseout",
        "mousemove", "mouseenter", "mouseleave", "input", "change", "submit",
        "keydown", "keyup", "keypress", "focus", "blur", "scroll", "load",
        "error", "resize", "contextmenu", "drag", "dragstart", "dragend",
        "dragover", "dragenter", "dragleave", "drop", "touchstart", "touchend",
        "touchmove", "touchcancel"
    )

    override fun addCompletions(
        parameters: CompletionParameters,
        processingContext: ProcessingContext,
        result: CompletionResultSet
    ) {
        val project = parameters.position.project
        val metadataService = MetadataService.getInstance(project)

        if (!metadataService.isLoaded) {
            return
        }

        val editor = parameters.editor
        val document = editor.document
        val offset = parameters.offset
        val text = document.text

        val context = TemplateParser.getCursorContextFromString(text, offset)

        if (!context.inWireviewTag) {
            return
        }

        when (context.position) {
            CursorPosition.COMPONENT_NAME -> {
                addComponentCompletions(metadataService, context.currentValue, result)
            }
            CursorPosition.ATTRIBUTE_NAME -> {
                context.componentName?.let { componentName ->
                    addAttributeCompletions(metadataService, componentName, context.currentValue, result)
                }
            }
            CursorPosition.HANDLER_NAME -> {
                context.componentName?.let { componentName ->
                    addHandlerCompletions(metadataService, componentName, context.currentValue, result)
                }
            }
            CursorPosition.EVENT_NAME -> {
                addEventCompletions(context.currentValue, result)
            }
            CursorPosition.MODIFIER -> {
                addModifierCompletions(metadataService, context.currentValue, result)
            }
            CursorPosition.SLOT_NAME -> {
                context.componentName?.let { componentName ->
                    addSlotCompletions(metadataService, componentName, context.currentValue, result)
                }
            }
            else -> {}
        }
    }

    private fun addComponentCompletions(
        metadataService: MetadataService,
        prefix: String?,
        result: CompletionResultSet
    ) {
        val lowerPrefix = prefix?.lowercase() ?: ""

        for ((name, component) in metadataService.getAllComponents()) {
            val matches = lowerPrefix.isEmpty() ||
                    name.lowercase().startsWith(lowerPrefix) ||
                    component.fqn.lowercase().startsWith(lowerPrefix) ||
                    component.appKey.lowercase().startsWith(lowerPrefix)

            if (matches) {
                // Simple name
                result.addElement(
                    LookupElementBuilder.create(name)
                        .withIcon(AllIcons.Nodes.Class)
                        .withTypeText(component.fqn)
                        .withTailText(" (${countFields(component)} fields)", true)
                        .withPriority(100.0)
                )

                // FQN
                result.addElement(
                    LookupElementBuilder.create(component.fqn)
                        .withIcon(AllIcons.Nodes.Class)
                        .withTypeText("Fully qualified")
                        .withPriority(90.0)
                )

                // App key
                result.addElement(
                    LookupElementBuilder.create(component.appKey)
                        .withIcon(AllIcons.Nodes.Class)
                        .withTypeText("App-prefixed")
                        .withPriority(80.0)
                )
            }
        }
    }

    private fun addAttributeCompletions(
        metadataService: MetadataService,
        componentName: String,
        prefix: String?,
        result: CompletionResultSet
    ) {
        val component = metadataService.getComponent(componentName) ?: return
        val lowerPrefix = prefix?.lowercase() ?: ""

        for ((name, field) in component.fields) {
            if (lowerPrefix.isEmpty() || name.lowercase().startsWith(lowerPrefix)) {
                val typeText = field.type ?: "any"
                val required = if (field.required) " (required)" else ""

                result.addElement(
                    LookupElementBuilder.create(name)
                        .withIcon(AllIcons.Nodes.Property)
                        .withTypeText("$typeText$required")
                        .withInsertHandler { ctx, _ ->
                            ctx.document.insertString(ctx.tailOffset, "=")
                            ctx.editor.caretModel.moveToOffset(ctx.tailOffset)
                        }
                        .withPriority(if (field.required) 100.0 else 90.0)
                )
            }
        }
    }

    private fun addHandlerCompletions(
        metadataService: MetadataService,
        componentName: String,
        prefix: String?,
        result: CompletionResultSet
    ) {
        val asyncMethods = metadataService.getAsyncMethods(componentName)
        val lowerPrefix = prefix?.lowercase() ?: ""

        for ((name, method) in asyncMethods) {
            if (lowerPrefix.isEmpty() || name.lowercase().startsWith(lowerPrefix)) {
                val params = method.parameters.keys.joinToString(", ")

                result.addElement(
                    LookupElementBuilder.create(name)
                        .withIcon(AllIcons.Nodes.Method)
                        .withTypeText("async ($params)")
                        .withPriority(100.0)
                )
            }
        }
    }

    private fun addEventCompletions(prefix: String?, result: CompletionResultSet) {
        val lowerPrefix = prefix?.lowercase() ?: ""

        for (event in domEvents) {
            if (lowerPrefix.isEmpty() || event.startsWith(lowerPrefix)) {
                result.addElement(
                    LookupElementBuilder.create(event)
                        .withIcon(AllIcons.Nodes.ExceptionClass)
                        .withTypeText("DOM event")
                        .withPriority(100.0)
                )
            }
        }
    }

    private fun addModifierCompletions(
        metadataService: MetadataService,
        prefix: String?,
        result: CompletionResultSet
    ) {
        val lowerPrefix = prefix?.lowercase() ?: ""

        for ((name, modifier) in metadataService.getModifiers()) {
            if (!name.startsWith("_") && (lowerPrefix.isEmpty() || name.lowercase().startsWith(lowerPrefix))) {
                result.addElement(
                    LookupElementBuilder.create(name)
                        .withIcon(AllIcons.Nodes.Annotationtype)
                        .withTypeText(modifier.description)
                        .withTailText(if (modifier.hasArgument) " (requires argument)" else "", true)
                        .withPriority(100.0)
                )
            }
        }
    }

    private fun addSlotCompletions(
        metadataService: MetadataService,
        componentName: String,
        prefix: String?,
        result: CompletionResultSet
    ) {
        val component = metadataService.getComponent(componentName) ?: return
        val lowerPrefix = prefix?.lowercase() ?: ""

        for ((name, slot) in component.slots) {
            if (lowerPrefix.isEmpty() || name.lowercase().startsWith(lowerPrefix)) {
                val required = if (slot.required) " (required)" else ""

                result.addElement(
                    LookupElementBuilder.create(name)
                        .withIcon(AllIcons.Nodes.Field)
                        .withTypeText("slot$required")
                        .withPriority(if (slot.required) 100.0 else 90.0)
                )
            }
        }
    }

    private fun countFields(component: ComponentMetadata): Int = component.fields.size

    private fun LookupElementBuilder.withPriority(priority: Double): LookupElementBuilder {
        return PrioritizedLookupElement.withPriority(this, priority) as LookupElementBuilder
    }
}
