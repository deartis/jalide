package com.example.jalide

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.jalide/termux"
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "pickSafDirectory" -> {
                        pendingResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                        }
                        startActivityForResult(intent, 1001)
                    }
                    
                    // ... (outros métodos permanecem iguais, vou abreviar aqui para o replace_file_content funcionar melhor se necessário, 
                    // mas vou colocar o arquivo completo para garantir)
                    "runTermuxCommand" -> {
                        val script = call.argument<String>("script") ?: ""
                        try {
                            val intent = Intent().apply {
                                action = "com.termux.RUN_COMMAND"
                                setClassName("com.termux", "com.termux.app.RunCommandService")
                                putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/bash")
                                putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-c", script))
                                putExtra("com.termux.RUN_COMMAND_WORKDIR", "/data/data/com.termux/files/home")
                                putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
                            }
                            startService(intent)
                            result.success(true)
                        } catch (e: Exception) { result.error("TERMUX_ERROR", e.message, null) }
                    }

                    "takeSafPermission" -> {
                        val uriString = call.argument<String>("uri") ?: return@setMethodCallHandler result.error("NO_URI", "No URI", null)
                        try {
                            val uri = Uri.parse(uriString)
                            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                            contentResolver.takePersistableUriPermission(uri, flags)
                            result.success(true)
                        } catch (e: Exception) { result.error("SAF_PERM_ERROR", e.message, null) }
                    }

                    "listSafDirectory" -> {
                        val uriString = call.argument<String>("uri") ?: return@setMethodCallHandler result.error("NO_URI", "No URI", null)
                        try {
                            val uri = Uri.parse(uriString)
                            val isDocument = DocumentsContract.isDocumentUri(this, uri)
                            
                            val treeUri = if (isDocument) {
                                // Se for um Document URI, reconstrói o Tree URI base
                                val treeId = DocumentsContract.getTreeDocumentId(uri)
                                DocumentsContract.buildTreeDocumentUri(uri.authority, treeId)
                            } else {
                                uri
                            }

                            val docId = if (isDocument) {
                                DocumentsContract.getDocumentId(uri)
                            } else {
                                DocumentsContract.getTreeDocumentId(uri)
                            }

                            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, docId)
                            val files = mutableListOf<HashMap<String, Any>>()
                            val cursor = contentResolver.query(
                                childrenUri,
                                arrayOf(
                                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                                    DocumentsContract.Document.COLUMN_MIME_TYPE
                                ), null, null, null
                            )
                            cursor?.use {
                                while (it.moveToNext()) {
                                    val childDocId = it.getString(0) ?: continue
                                    val name = it.getString(1) ?: continue
                                    val mimeType = it.getString(2) ?: ""
                                    val isDir = mimeType == DocumentsContract.Document.MIME_TYPE_DIR
                                    
                                    // SEMPRE use buildDocumentUriUsingTree para manter a permissão da árvore
                                    val fileUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, childDocId)
                                    
                                    files.add(hashMapOf("name" to name, "uri" to fileUri.toString(), "isDir" to isDir))
                                }
                            }
                            files.sortWith(compareBy({ !(it["isDir"] as Boolean) }, { it["name"] as String }))
                            result.success(files)
                        } catch (e: Exception) { result.error("SAF_LIST_ERROR", e.message, null) }
                    }

                    "readSafFile" -> {
                        val uriString = call.argument<String>("uri") ?: return@setMethodCallHandler result.error("NO_URI", "No URI", null)
                        try {
                            val uri = Uri.parse(uriString)
                            val content = contentResolver.openInputStream(uri)?.bufferedReader()?.readText() ?: ""
                            result.success(content)
                        } catch (e: Exception) { result.error("SAF_READ_ERROR", e.message, null) }
                    }

                    "writeSafFile" -> {
                        val uriString = call.argument<String>("uri") ?: return@setMethodCallHandler result.error("NO_URI", "No URI", null)
                        val content = call.argument<String>("content") ?: ""
                        try {
                            val uri = Uri.parse(uriString)
                            contentResolver.openOutputStream(uri, "wt")?.use { it.write(content.toByteArray(Charsets.UTF_8)) }
                            result.success(true)
                        } catch (e: Exception) { result.error("SAF_WRITE_ERROR", e.message, null) }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1001 && resultCode == RESULT_OK) {
            val uri = data?.data ?: return
            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            contentResolver.takePersistableUriPermission(uri, flags)
            pendingResult?.success(uri.toString())
        } else if (requestCode == 1001) {
            pendingResult?.success(null)
        }
        pendingResult = null
    }
}
