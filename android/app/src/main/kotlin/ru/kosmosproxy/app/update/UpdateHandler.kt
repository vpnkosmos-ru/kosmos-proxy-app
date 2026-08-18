package ru.kosmosproxy.app.update

import android.content.Intent
import android.content.pm.PackageManager
import android.app.DownloadManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.util.Log
import androidx.core.content.FileProvider
import com.android.apksig.ApkVerifier
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class UpdateHandler : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.binding = binding
        channel = MethodChannel(binding.binaryMessenger, "kosmos_proxy/update")
        channel.setMethodCallHandler(this)
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { channel.setMethodCallHandler(null) }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = binding.applicationContext
        when (call.method) {
            "canRequestPackageInstalls" -> result.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.O || context.packageManager.canRequestPackageInstalls())
            "requestInstallPermission" -> { if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startActivity(Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); result.success(null) }
            "verifyArchive" -> try {
                val path = call.argument<String>("path") ?: return result.error("invalid", "missing path", null)
                val file = File(path); if (!file.isFile) return result.error("invalid", "file missing", null)
                val pm = context.packageManager
                @Suppress("DEPRECATION")
                // These flags are mutually exclusive on Android 10.  The
                // modern signing API is the authoritative path; certificate()
                // retains a legacy fallback for older platform releases.
                val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
                @Suppress("DEPRECATION")
                val archive = pm.getPackageArchiveInfo(path, flags) ?: return result.error("invalid_apk", "archive unreadable", null)
                @Suppress("DEPRECATION")
                val current = pm.getPackageInfo(context.packageName, flags)
                val archiveVersion = if (Build.VERSION.SDK_INT >= 28) archive.longVersionCode else @Suppress("DEPRECATION") archive.versionCode.toLong()
                val currentVersion = if (Build.VERSION.SDK_INT >= 28) current.longVersionCode else @Suppress("DEPRECATION") current.versionCode.toLong()
                // Do not use PackageManager's archive signing result here:
                // Samsung Android 10 can parse the manifest from private app
                // storage but omits archive SigningInfo.  ApkVerifier reads
                // the v2/v3 signing block directly and validates it first.
                val verified = ApkVerifier.Builder(file).build().verify()
                val archiveCertBytes = verified.signerCertificates.firstOrNull()?.encoded
                val archiveCert = archiveCertBytes?.let { MessageDigest.getInstance("SHA-256").digest(it).joinToString("") { b -> "%02x".format(b) } }
                val currentCert = certificate(current)
                result.success(mapOf("valid" to (verified.isVerified && archive.packageName == context.packageName && archiveVersion > currentVersion && archiveCert != null && archiveCert == currentCert), "packageName" to archive.packageName, "versionCode" to archiveVersion, "certificateSha256" to archiveCert))
            } catch (e: Exception) {
                // Do not expose paths or signatures to UI; the class name is a
                // safe diagnostic for logcat only.
                Log.w("KosmosUpdate", "archive verification failed: ${e.javaClass.simpleName}")
                result.error("invalid_apk", "archive validation failed", null)
            }
            "enqueueDownload" -> try {
                val url = call.argument<String>("url") ?: return result.error("invalid", "missing url", null)
                val versionCode = call.argument<Int>("versionCode") ?: return result.error("invalid", "missing version", null)
                val uri = Uri.parse(url)
                if (uri.scheme != "https") return result.error("invalid", "untrusted url", null)
                val name = "Kosmos-Proxy-$versionCode.apk"
                val target = File(context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "updates/$name")
                target.parentFile?.mkdirs()
                if (target.exists()) target.delete()
                val request = DownloadManager.Request(uri)
                    .setTitle("Обновление Kosmos Proxy")
                    .setDescription("Скачивание обновления")
                    .setMimeType("application/vnd.android.package-archive")
                    .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
                    .setDestinationInExternalFilesDir(context, Environment.DIRECTORY_DOWNLOADS, "updates/$name")
                val id = (context.getSystemService(android.content.Context.DOWNLOAD_SERVICE) as DownloadManager).enqueue(request)
                result.success(mapOf("id" to id, "path" to target.absolutePath))
            } catch (e: Exception) {
                Log.w("KosmosUpdate", "download enqueue failed: ${e.javaClass.simpleName}")
                result.error("download", "download unavailable", null)
            }
            "queryDownload" -> try {
                val id = call.argument<Number>("id")?.toLong() ?: return result.error("invalid", "missing id", null)
                val dm = context.getSystemService(android.content.Context.DOWNLOAD_SERVICE) as DownloadManager
                dm.query(DownloadManager.Query().setFilterById(id)).use { cursor ->
                    if (!cursor.moveToFirst()) return result.success(mapOf("status" to "missing"))
                    val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                    val downloaded = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                    val total = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                    val value = when (status) {
                        DownloadManager.STATUS_SUCCESSFUL -> "success"
                        DownloadManager.STATUS_FAILED -> "failed"
                        else -> "running"
                    }
                    result.success(mapOf("status" to value, "downloaded" to downloaded, "total" to total))
                }
            } catch (e: Exception) { result.error("download", "download query failed", null) }
            "cancelDownload" -> try {
                val id = call.argument<Number>("id")?.toLong() ?: return result.error("invalid", "missing id", null)
                (context.getSystemService(android.content.Context.DOWNLOAD_SERVICE) as DownloadManager).remove(id)
                result.success(null)
            } catch (e: Exception) { result.error("download", "download cancel failed", null) }
            "installArchive" -> try {
                val path = call.argument<String>("path") ?: return result.error("invalid", "missing path", null)
                val uri = FileProvider.getUriForFile(context, "${context.packageName}.updates", File(path))
                context.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK))
                result.success(null)
            } catch (e: Exception) { result.error("installer", "installer unavailable", null) }
            else -> result.notImplemented()
        }
    }
    private fun certificate(info: android.content.pm.PackageInfo): String {
        val bytes = if (Build.VERSION.SDK_INT >= 28) {
            info.signingInfo?.apkContentsSigners?.firstOrNull()?.toByteArray()
                ?: legacyCertificate(info)
        } else legacyCertificate(info)
        return MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
    }

    @Suppress("DEPRECATION")
    private fun legacyCertificate(info: android.content.pm.PackageInfo): ByteArray =
        info.signatures?.firstOrNull()?.toByteArray()
            ?: throw IllegalArgumentException("archive has no signing certificate")
}
