package com.itdawork.wireview.settings

import com.intellij.openapi.options.Configurable
import com.intellij.ui.components.JBCheckBox
import com.intellij.ui.components.JBLabel
import com.intellij.ui.components.JBTextField
import com.intellij.util.ui.FormBuilder
import javax.swing.JComponent
import javax.swing.JPanel
import javax.swing.JSpinner
import javax.swing.SpinnerNumberModel

class WireviewConfigurable : Configurable {
    private var panel: JPanel? = null
    private val pythonPathField = JBTextField()
    private val djangoSettingsField = JBTextField()
    private val metadataPathField = JBTextField()
    private val autoRefreshCheckbox = JBCheckBox("Auto refresh on startup")
    private val refreshOnSaveCheckbox = JBCheckBox("Refresh on Python file save")
    private val cacheTtlSpinner = JSpinner(SpinnerNumberModel(300, 60, 3600, 60))

    override fun getDisplayName(): String = "django-wireview"

    override fun createComponent(): JComponent {
        panel = FormBuilder.createFormBuilder()
            .addLabeledComponent(JBLabel("Python path:"), pythonPathField, 1, false)
            .addLabeledComponent(JBLabel("Django settings module:"), djangoSettingsField, 1, false)
            .addLabeledComponent(JBLabel("Metadata path:"), metadataPathField, 1, false)
            .addComponent(autoRefreshCheckbox, 1)
            .addComponent(refreshOnSaveCheckbox, 1)
            .addLabeledComponent(JBLabel("Cache TTL (seconds):"), cacheTtlSpinner, 1, false)
            .addComponentFillVertically(JPanel(), 0)
            .panel
        return panel!!
    }

    override fun isModified(): Boolean {
        val settings = WireviewSettings.getInstance()
        return pythonPathField.text != settings.pythonPath ||
                djangoSettingsField.text != settings.djangoSettings ||
                metadataPathField.text != settings.metadataPath ||
                autoRefreshCheckbox.isSelected != settings.autoRefresh ||
                refreshOnSaveCheckbox.isSelected != settings.refreshOnSave ||
                (cacheTtlSpinner.value as Int) != settings.cacheTtl
    }

    override fun apply() {
        val settings = WireviewSettings.getInstance()
        settings.pythonPath = pythonPathField.text
        settings.djangoSettings = djangoSettingsField.text
        settings.metadataPath = metadataPathField.text
        settings.autoRefresh = autoRefreshCheckbox.isSelected
        settings.refreshOnSave = refreshOnSaveCheckbox.isSelected
        settings.cacheTtl = cacheTtlSpinner.value as Int
    }

    override fun reset() {
        val settings = WireviewSettings.getInstance()
        pythonPathField.text = settings.pythonPath
        djangoSettingsField.text = settings.djangoSettings
        metadataPathField.text = settings.metadataPath
        autoRefreshCheckbox.isSelected = settings.autoRefresh
        refreshOnSaveCheckbox.isSelected = settings.refreshOnSave
        cacheTtlSpinner.value = settings.cacheTtl
    }

    override fun disposeUIResources() {
        panel = null
    }
}
