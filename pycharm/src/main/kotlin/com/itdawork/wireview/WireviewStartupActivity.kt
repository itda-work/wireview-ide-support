package com.itdawork.wireview

import com.intellij.openapi.diagnostic.logger
import com.intellij.openapi.project.Project
import com.intellij.openapi.startup.ProjectActivity
import com.itdawork.wireview.services.MetadataService
import com.itdawork.wireview.settings.WireviewSettings

class WireviewStartupActivity : ProjectActivity {
    private val log = logger<WireviewStartupActivity>()

    override suspend fun execute(project: Project) {
        val settings = WireviewSettings.getInstance()

        if (settings.autoRefresh) {
            log.info("Wireview: Auto-refreshing metadata on startup")
            val metadataService = MetadataService.getInstance(project)
            metadataService.refresh()
        }
    }
}
