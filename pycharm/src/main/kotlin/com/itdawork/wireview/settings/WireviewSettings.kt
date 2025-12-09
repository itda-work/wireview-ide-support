package com.itdawork.wireview.settings

import com.intellij.openapi.application.ApplicationManager
import com.intellij.openapi.components.PersistentStateComponent
import com.intellij.openapi.components.Service
import com.intellij.openapi.components.State
import com.intellij.openapi.components.Storage

@Service(Service.Level.APP)
@State(
    name = "WireviewSettings",
    storages = [Storage("wireview.xml")]
)
class WireviewSettings : PersistentStateComponent<WireviewSettings.State> {
    private var myState = State()

    data class State(
        var pythonPath: String = "python",
        var djangoSettings: String = "",
        var metadataPath: String = ".wireview/metadata.json",
        var autoRefresh: Boolean = true,
        var refreshOnSave: Boolean = true,
        var cacheTtl: Int = 300
    )

    var pythonPath: String
        get() = myState.pythonPath
        set(value) { myState.pythonPath = value }

    var djangoSettings: String
        get() = myState.djangoSettings
        set(value) { myState.djangoSettings = value }

    var metadataPath: String
        get() = myState.metadataPath
        set(value) { myState.metadataPath = value }

    var autoRefresh: Boolean
        get() = myState.autoRefresh
        set(value) { myState.autoRefresh = value }

    var refreshOnSave: Boolean
        get() = myState.refreshOnSave
        set(value) { myState.refreshOnSave = value }

    var cacheTtl: Int
        get() = myState.cacheTtl
        set(value) { myState.cacheTtl = value }

    override fun getState(): State = myState

    override fun loadState(state: State) {
        myState = state
    }

    companion object {
        fun getInstance(): WireviewSettings {
            return ApplicationManager.getApplication().getService(WireviewSettings::class.java)
        }
    }
}
