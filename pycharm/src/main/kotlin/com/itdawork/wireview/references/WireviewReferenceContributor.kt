package com.itdawork.wireview.references

import com.intellij.openapi.project.Project
import com.intellij.openapi.util.TextRange
import com.intellij.patterns.PlatformPatterns
import com.intellij.psi.*
import com.intellij.util.ProcessingContext
import com.itdawork.wireview.parser.CursorPosition
import com.itdawork.wireview.parser.TemplateParser
import com.itdawork.wireview.services.MetadataService
import java.io.File

class WireviewReferenceContributor : PsiReferenceContributor() {
    override fun registerReferenceProviders(registrar: PsiReferenceRegistrar) {
        registrar.registerReferenceProvider(
            PlatformPatterns.psiElement(),
            WireviewReferenceProvider()
        )
    }
}

class WireviewReferenceProvider : PsiReferenceProvider() {
    override fun getReferencesByElement(
        element: PsiElement,
        context: ProcessingContext
    ): Array<PsiReference> {
        val project = element.project
        val metadataService = MetadataService.getInstance(project)

        if (!metadataService.isLoaded) {
            return PsiReference.EMPTY_ARRAY
        }

        val file = element.containingFile ?: return PsiReference.EMPTY_ARRAY
        val text = file.text
        val offset = element.textOffset

        val cursorContext = TemplateParser.getCursorContextFromString(text, offset)

        if (!cursorContext.inWireviewTag) {
            return PsiReference.EMPTY_ARRAY
        }

        return when (cursorContext.position) {
            CursorPosition.COMPONENT_NAME -> {
                cursorContext.currentValue?.let { componentName ->
                    arrayOf(WireviewComponentReference(element, componentName, project))
                } ?: PsiReference.EMPTY_ARRAY
            }
            CursorPosition.HANDLER_NAME -> {
                val componentName = cursorContext.componentName
                val handlerName = cursorContext.currentValue
                if (componentName != null && handlerName != null) {
                    arrayOf(WireviewHandlerReference(element, componentName, handlerName, project))
                } else {
                    PsiReference.EMPTY_ARRAY
                }
            }
            else -> PsiReference.EMPTY_ARRAY
        }
    }
}

class WireviewComponentReference(
    element: PsiElement,
    private val componentName: String,
    private val project: Project
) : PsiReferenceBase<PsiElement>(element, TextRange(0, element.textLength)) {

    override fun resolve(): PsiElement? {
        val metadataService = MetadataService.getInstance(project)
        val component = metadataService.getComponent(componentName) ?: return null

        val filePath = component.filePath
        val lineNumber = component.lineNumber

        return findPsiElement(project, filePath, lineNumber)
    }

    override fun getVariants(): Array<Any> = emptyArray()
}

class WireviewHandlerReference(
    element: PsiElement,
    private val componentName: String,
    private val handlerName: String,
    private val project: Project
) : PsiReferenceBase<PsiElement>(element, TextRange(0, element.textLength)) {

    override fun resolve(): PsiElement? {
        val metadataService = MetadataService.getInstance(project)
        val component = metadataService.getComponent(componentName) ?: return null
        val method = component.methods[handlerName] ?: return null

        val filePath = component.filePath
        val lineNumber = method.lineNumber ?: component.lineNumber

        return findPsiElement(project, filePath, lineNumber)
    }

    override fun getVariants(): Array<Any> = emptyArray()
}

private fun findPsiElement(project: Project, filePath: String, lineNumber: Int): PsiElement? {
    val file = File(filePath)
    if (!file.exists()) return null

    val virtualFile = com.intellij.openapi.vfs.LocalFileSystem.getInstance()
        .findFileByPath(filePath) ?: return null

    val psiFile = PsiManager.getInstance(project).findFile(virtualFile) ?: return null

    // Find element at line
    val document = PsiDocumentManager.getInstance(project).getDocument(psiFile) ?: return null

    if (lineNumber < 1 || lineNumber > document.lineCount) {
        return psiFile
    }

    val lineStartOffset = document.getLineStartOffset(lineNumber - 1)
    return psiFile.findElementAt(lineStartOffset) ?: psiFile
}
