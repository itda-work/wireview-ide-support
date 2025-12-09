package com.itdawork.wireview.services

import com.intellij.notification.NotificationGroupManager
import com.intellij.notification.NotificationType
import com.intellij.openapi.application.ApplicationManager
import com.intellij.openapi.components.Service
import com.intellij.openapi.diagnostic.logger
import com.intellij.openapi.project.Project
import com.intellij.openapi.vfs.LocalFileSystem
import com.itdawork.wireview.models.ComponentMetadata
import com.itdawork.wireview.models.ModifierInfo
import com.itdawork.wireview.models.WireviewMetadata
import com.itdawork.wireview.settings.WireviewSettings
import kotlinx.serialization.json.Json
import java.io.File
import java.time.Instant
import java.time.format.DateTimeFormatter

@Service(Service.Level.PROJECT)
class MetadataService(private val project: Project) {
    private val log = logger<MetadataService>()
    private val json = Json { ignoreUnknownKeys = true }

    private var cachedMetadata: WireviewMetadata? = null
    private var lastLoadTime: Instant? = null
    private var isRefreshing = false

    val isLoaded: Boolean get() = cachedMetadata != null

    fun getMetadata(): WireviewMetadata? = cachedMetadata

    fun getComponent(name: String): ComponentMetadata? {
        val metadata = cachedMetadata ?: return null

        // Direct lookup
        metadata.components[name]?.let { return it }

        // Search by FQN or app_key
        return metadata.components.values.find { it.fqn == name || it.appKey == name }
    }

    fun getAllComponents(): Map<String, ComponentMetadata> {
        return cachedMetadata?.components ?: emptyMap()
    }

    fun getModifiers(): Map<String, ModifierInfo> {
        return cachedMetadata?.modifiers ?: emptyMap()
    }

    fun getModifier(name: String): ModifierInfo? {
        return cachedMetadata?.modifiers?.get(name)
    }

    fun getAsyncMethods(componentName: String): Map<String, com.itdawork.wireview.models.MethodInfo> {
        val component = getComponent(componentName) ?: return emptyMap()
        return component.methods.filter { (name, method) ->
            method.isAsync && !EXCLUDED_METHODS.contains(name)
        }
    }

    fun load(): Boolean {
        val metadataPath = getMetadataPath() ?: return false
        val file = File(metadataPath)

        if (!file.exists()) {
            log.debug("Metadata file not found: $metadataPath")
            return false
        }

        return try {
            val content = file.readText()
            cachedMetadata = json.decodeFromString<WireviewMetadata>(content)
            lastLoadTime = Instant.now()
            log.info("Loaded wireview metadata: ${cachedMetadata?.components?.size} components")
            true
        } catch (e: Exception) {
            log.error("Failed to parse metadata: ${e.message}", e)
            false
        }
    }

    fun refresh(callback: ((Boolean) -> Unit)? = null) {
        if (isRefreshing) {
            callback?.invoke(false)
            return
        }

        val settings = WireviewSettings.getInstance()

        // Try to load from cache first
        if (load() && isCacheValid()) {
            log.debug("Using cached metadata")
            callback?.invoke(true)
            return
        }

        val managePy = findManagePy() ?: run {
            log.warn("manage.py not found")
            notifyError("manage.py not found in project")
            callback?.invoke(false)
            return
        }

        val outputPath = getMetadataPath() ?: run {
            callback?.invoke(false)
            return
        }

        // Ensure output directory exists
        File(outputPath).parentFile?.mkdirs()

        val command = mutableListOf(
            settings.pythonPath,
            managePy,
            "wireview_lsp",
            "--output", outputPath
        )

        if (settings.djangoSettings.isNotBlank()) {
            command.add("--settings")
            command.add(settings.djangoSettings)
        }

        isRefreshing = true

        ApplicationManager.getApplication().executeOnPooledThread {
            try {
                val processBuilder = ProcessBuilder(command)
                processBuilder.directory(File(project.basePath ?: "."))

                if (settings.djangoSettings.isNotBlank()) {
                    processBuilder.environment()["DJANGO_SETTINGS_MODULE"] = settings.djangoSettings
                }

                val process = processBuilder.start()
                val exitCode = process.waitFor()

                ApplicationManager.getApplication().invokeLater {
                    isRefreshing = false

                    if (exitCode == 0) {
                        val success = load()
                        if (success) {
                            notifyInfo("Wireview metadata refreshed")
                        }
                        callback?.invoke(success)
                    } else {
                        val stderr = process.errorStream.bufferedReader().readText()
                        log.error("Python extractor failed: $stderr")
                        notifyError("Failed to refresh metadata: $stderr")
                        callback?.invoke(false)
                    }
                }
            } catch (e: Exception) {
                ApplicationManager.getApplication().invokeLater {
                    isRefreshing = false
                    log.error("Failed to run Python extractor: ${e.message}", e)
                    notifyError("Failed to run wireview_lsp: ${e.message}")
                    callback?.invoke(false)
                }
            }
        }
    }

    private fun isCacheValid(): Boolean {
        val metadata = cachedMetadata ?: return false
        val settings = WireviewSettings.getInstance()

        return try {
            val generatedAt = Instant.from(DateTimeFormatter.ISO_INSTANT.parse(metadata.generatedAt))
            val now = Instant.now()
            val age = java.time.Duration.between(generatedAt, now).seconds
            age < settings.cacheTtl
        } catch (e: Exception) {
            false
        }
    }

    private fun getMetadataPath(): String? {
        val basePath = project.basePath ?: return null
        val settings = WireviewSettings.getInstance()
        return "$basePath/${settings.metadataPath}"
    }

    private fun findManagePy(): String? {
        val basePath = project.basePath ?: return null

        val candidates = listOf(
            "manage.py",
            "src/manage.py",
            "backend/manage.py",
            "server/manage.py",
            "app/manage.py",
            "tests/manage.py",
            "example/manage.py",
            "examples/manage.py"
        )

        for (candidate in candidates) {
            val file = File("$basePath/$candidate")
            if (file.exists()) {
                return file.absolutePath
            }
        }

        return null
    }

    private fun notifyInfo(message: String) {
        NotificationGroupManager.getInstance()
            .getNotificationGroup("Wireview Notifications")
            .createNotification(message, NotificationType.INFORMATION)
            .notify(project)
    }

    private fun notifyError(message: String) {
        NotificationGroupManager.getInstance()
            .getNotificationGroup("Wireview Notifications")
            .createNotification(message, NotificationType.ERROR)
            .notify(project)
    }

    companion object {
        fun getInstance(project: Project): MetadataService {
            return project.getService(MetadataService::class.java)
        }

        val EXCLUDED_METHODS = setOf(
            // Component base methods
            "joined", "leaving", "notification", "mutation", "params_changed",
            "handle_hook_event", "broadcast", "deffer", "destroy", "focus_on",
            "skip_render", "force_render", "freeze", "dom", "stream",
            "stream_insert", "stream_delete", "assign_async", "allow_upload",
            "cancel_upload", "consume_uploads",
            // Pydantic methods
            "model_copy", "model_dump", "model_dump_json", "model_json_schema",
            "model_parametrized_name", "model_post_init", "model_rebuild",
            "model_validate", "model_validate_json", "model_validate_strings",
            "model_construct", "copy", "dict", "json", "parse_obj", "parse_raw",
            "parse_file", "from_orm", "construct", "new"
        )
    }
}
