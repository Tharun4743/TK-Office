package com.tk.tk_office

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.concurrent.Executor

class MainActivity : FlutterFragmentActivity() {
    private val SHARE_CHANNEL = "com.tk.tk_office/share"
    private val INTENT_CHANNEL = "com.tk.tk_office/intent"
    private val STORAGE_CHANNEL = "com.tk.tk_office/storage"
    private val AUTH_CHANNEL = "com.tk.tk_office/auth"

    private var pendingIntentData: Map<String, Any?>? = null
    private var intentMethodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent)
        pendingIntentData?.let { data ->
            intentMethodChannel?.invokeMethod("onIntentReceived", data)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Share Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "shareFile") {
                val filePath = call.argument<String>("filePath")
                val title = call.argument<String>("title") ?: "Share Document"
                if (filePath != null) {
                    try {
                        val file = File(filePath)
                        val uri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "*/*"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            putExtra(Intent.EXTRA_SUBJECT, file.name)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(intent, title))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_PATH", "File path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // 2. Intent Channel for Open With & Notification Permissions
        intentMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_CHANNEL)
        intentMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialIntent" -> {
                    result.success(pendingIntentData)
                    pendingIntentData = null
                }
                "checkNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        result.success(true)
                    }
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            1001
                        )
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("URL_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_URL", "URL is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 3. Storage Channel for Real Android MANAGE_EXTERNAL_STORAGE
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkStoragePermission" -> {
                    val isGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        Environment.isExternalStorageManager()
                    } else {
                        ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.READ_EXTERNAL_STORAGE
                        ) == PackageManager.PERMISSION_GRANTED
                    }
                    result.success(isGranted)
                }
                "requestStoragePermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        } catch (e: Exception) {
                            val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                            startActivity(intent)
                        }
                    } else {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(
                                Manifest.permission.READ_EXTERNAL_STORAGE,
                                Manifest.permission.WRITE_EXTERNAL_STORAGE
                            ),
                            1002
                        )
                    }
                    result.success(true)
                }
                "getRootStoragePath" -> {
                    val root = Environment.getExternalStorageDirectory().absolutePath
                    result.success(root)
                }
                "getAccessibleFolders" -> {
                    val root = Environment.getExternalStorageDirectory()
                    val folders = mutableListOf<Map<String, String>>()
                    
                    val commonNames = listOf(
                        "Download" to "Download",
                        "Documents" to "Documents",
                        "Pictures" to "Pictures",
                        "DCIM" to "Camera & Photos",
                        "Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents" to "WhatsApp Documents",
                        "WhatsApp/Media/WhatsApp Documents" to "WhatsApp Documents",
                        "Documents/TK Office" to "TK Office"
                    )

                    for ((relPath, label) in commonNames) {
                        val dir = File(root, relPath)
                        if (dir.exists() && dir.isDirectory) {
                            folders.add(mapOf("name" to label, "path" to dir.absolutePath))
                        }
                    }
                    result.success(folders)
                }
                else -> result.notImplemented()
            }
        }

        // 4. Biometric Auth Channel (100% offline, native AndroidX BiometricPrompt)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canAuthenticate" -> {
                    val biometricManager = BiometricManager.from(this)
                    val authenticators = BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL
                    val canAuth = biometricManager.canAuthenticate(authenticators) == BiometricManager.BIOMETRIC_SUCCESS
                    result.success(canAuth)
                }
                "authenticate" -> {
                    val title = call.argument<String>("title") ?: "Unlock TK Office"
                    val subtitle = call.argument<String>("subtitle") ?: "Verify your identity to proceed"
                    val executor: Executor = ContextCompat.getMainExecutor(this)

                    val promptInfo = BiometricPrompt.PromptInfo.Builder()
                        .setTitle(title)
                        .setSubtitle(subtitle)
                        .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL)
                        .build()

                    val biometricPrompt = BiometricPrompt(this, executor, object : BiometricPrompt.AuthenticationCallback() {
                        override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                            super.onAuthenticationSucceeded(authResult)
                            result.success(true)
                        }

                        override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                            super.onAuthenticationError(errorCode, errString)
                            result.success(false)
                        }

                        override fun onAuthenticationFailed() {
                            super.onAuthenticationFailed()
                        }
                    })

                    biometricPrompt.authenticate(promptInfo)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun handleIncomingIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action

        if (Intent.ACTION_VIEW == action) {
            val uri: Uri? = intent.data
            if (uri != null) {
                val localPath = resolveAndCopyUri(uri)
                if (localPath != null) {
                    pendingIntentData = mapOf(
                        "action" to "VIEW",
                        "filePath" to localPath,
                        "mimeType" to intent.type,
                        "fileName" to File(localPath).name
                    )
                }
            }
        } else if (Intent.ACTION_SEND == action) {
            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
            }
            if (uri != null) {
                val localPath = resolveAndCopyUri(uri)
                if (localPath != null) {
                    pendingIntentData = mapOf(
                        "action" to "SEND",
                        "filePath" to localPath,
                        "mimeType" to intent.type,
                        "fileName" to File(localPath).name
                    )
                }
            }
        } else if (Intent.ACTION_SEND_MULTIPLE == action) {
            val uris: ArrayList<Uri>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
            }
            if (uris != null && uris.isNotEmpty()) {
                val paths = ArrayList<String>()
                for (u in uris) {
                    val p = resolveAndCopyUri(u)
                    if (p != null) paths.add(p)
                }
                if (paths.isNotEmpty()) {
                    pendingIntentData = mapOf(
                        "action" to "SEND_MULTIPLE",
                        "filePaths" to paths,
                        "mimeType" to intent.type
                    )
                }
            }
        }
    }

    private fun resolveAndCopyUri(uri: Uri): String? {
        try {
            var fileName = "imported_document"
            if (uri.scheme == "content") {
                val cursor = contentResolver.query(uri, null, null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex >= 0) {
                            fileName = it.getString(nameIndex) ?: fileName
                        }
                    }
                }
            } else if (uri.scheme == "file") {
                fileName = uri.lastPathSegment ?: fileName
            }

            // Create working directory
            val workingDir = File(cacheDir, "tk_working_files")
            if (!workingDir.exists()) workingDir.mkdirs()

            val targetFile = File(workingDir, fileName)
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            if (inputStream != null) {
                FileOutputStream(targetFile).use { output ->
                    inputStream.copyTo(output)
                }
                inputStream.close()
                return targetFile.absolutePath
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }
}
