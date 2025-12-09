package com.itdawork.wireview.actions

import com.intellij.openapi.actionSystem.AnAction
import com.intellij.openapi.actionSystem.AnActionEvent
import com.intellij.openapi.ui.Messages
import com.itdawork.wireview.services.MetadataService
import com.itdawork.wireview.settings.WireviewSettings

class ShowStatusAction : AnAction() {
    override fun actionPerformed(e: AnActionEvent) {
        val project = e.project ?: return
        val metadataService = MetadataService.getInstance(project)
        val settings = WireviewSettings.getInstance()

        val status = buildString {
            appendLine("Wireview Status")
            appendLine("===============")
            appendLine()
            appendLine("Configuration:")
            appendLine("  Python path: ${settings.pythonPath}")
            appendLine("  Django settings: ${settings.djangoSettings.ifEmpty { "(not set)" }}")
            appendLine("  Metadata path: ${settings.metadataPath}")
            appendLine("  Auto refresh: ${if (settings.autoRefresh) "enabled" else "disabled"}")
            appendLine("  Refresh on save: ${if (settings.refreshOnSave) "enabled" else "disabled"}")
            appendLine("  Cache TTL: ${settings.cacheTtl}s")
            appendLine()
            appendLine("Metadata:")
            if (metadataService.isLoaded) {
                val metadata = metadataService.getMetadata()
                appendLine("  Status: loaded")
                appendLine("  Components: ${metadata?.components?.size ?: 0}")
                appendLine("  Modifiers: ${metadata?.modifiers?.size ?: 0}")
                appendLine("  Generated at: ${metadata?.generatedAt ?: "unknown"}")
            } else {
                appendLine("  Status: not loaded")
                appendLine("  Use Tools > Wireview > Refresh Metadata to load")
            }
        }

        Messages.showInfoMessage(project, status, "Wireview Status")
    }

    override fun update(e: AnActionEvent) {
        e.presentation.isEnabledAndVisible = e.project != null
    }
}
